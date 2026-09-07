#!/usr/bin/env python3
"""Report GUI packages declared for a Home Manager user but rarely launched.

The primary signal is DankMaterialShell's launcher history. Shell history,
notification history, and configuration references are included as secondary
signals so the report can expose likely false positives instead of silently
classifying them as unused.
"""

from __future__ import annotations

import argparse
import configparser
import datetime as dt
import json
import os
import re
import shlex
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable

TEXT_SUFFIXES = {
    "",
    ".conf",
    ".desktop",
    ".fish",
    ".ini",
    ".json",
    ".kdl",
    ".lua",
    ".nix",
    ".nu",
    ".service",
    ".sh",
    ".toml",
    ".yaml",
    ".yml",
}
SKIP_DIRS = {
    ".git",
    ".mozilla",
    "Cache",
    "GPUCache",
    "IndexedDB",
    "Local Storage",
    "Service Worker",
    "cache",
    "node_modules",
    "storage",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Find rarely launched GUI applications declared in a Home Manager profile."
    )
    parser.add_argument("--flake", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--host", default="fern")
    parser.add_argument("--user", default=os.environ.get("USER", "dan"))
    parser.add_argument(
        "--days",
        type=int,
        default=90,
        help="consider a DMS launch recent within this many days (default: 90)",
    )
    parser.add_argument(
        "--max-launches",
        type=int,
        default=3,
        help="label an app rare when its lifetime DMS count is at most this value (default: 3)",
    )
    parser.add_argument("--all", action="store_true", help="include recently used applications")
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    return parser.parse_args()


def nix_packages(flake: Path, host: str, user: str) -> list[dict[str, Any]]:
    installable = (
        f".#nixosConfigurations.{host}.config.home-manager.users.{user}.home.packages"
    )
    result = subprocess.run(
        ["nix", "eval", "--json", installable],
        cwd=flake,
        text=True,
        capture_output=True,
    )
    if result.returncode:
        sys.stderr.write(result.stderr)
        raise SystemExit(result.returncode)
    return [
        {
            "name": Path(out_path).name,
            "pname": None,
            "version": None,
            "outPath": out_path,
        }
        for out_path in json.loads(result.stdout)
    ]


def normalize(value: str) -> str:
    value = value.casefold().removesuffix(".desktop")
    return re.sub(r"[^a-z0-9]+", "", value)


def executable_from(exec_line: str) -> str:
    try:
        words = shlex.split(exec_line)
    except ValueError:
        words = exec_line.split()
    words = [word for word in words if not word.startswith("%")]
    while words and ("=" in words[0] or words[0] in {"env", "nohup"}):
        words.pop(0)
    return Path(words[0]).name if words else ""


def desktop_entry(path: Path) -> dict[str, str] | None:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        parser.read(path, encoding="utf-8")
        entry = parser["Desktop Entry"]
    except (OSError, UnicodeError, KeyError, configparser.Error):
        return None
    if entry.get("Type", "Application") != "Application":
        return None
    if entry.getboolean("Hidden", fallback=False) or entry.getboolean(
        "NoDisplay", fallback=False
    ):
        return None
    return {
        "id": path.stem,
        "name": entry.get("Name", path.stem),
        "exec": executable_from(entry.get("Exec", "")),
        "wm_class": entry.get("StartupWMClass", ""),
        "desktop_file": str(path),
    }


def package_key(store_name: str) -> str:
    name = re.sub(r"^[a-z0-9]{32}-", "", store_name)
    parts = name.split("-")
    for index, part in enumerate(parts[1:], start=1):
        if re.match(r"v?\d", part):
            return "-".join(parts[:index]).casefold()
    return name.casefold()


def active_gui_packages(
    home: Path, user: str, declared_packages: list[dict[str, Any]]
) -> tuple[list[dict[str, Any]], int]:
    profile = Path("/etc/profiles/per-user") / user
    if not profile.exists():
        profile = home / ".nix-profile"
    applications = profile / "share/applications"
    declared_keys = {package_key(package["name"]) for package in declared_packages}
    grouped: dict[Path, list[dict[str, str]]] = defaultdict(list)
    skipped = 0
    for path in applications.glob("*.desktop"):
        try:
            resolved = path.resolve(strict=True)
            owner = Path(*resolved.parts[:4])
        except OSError:
            continue
        if package_key(owner.name) not in declared_keys:
            skipped += 1
            continue
        entry = desktop_entry(path)
        if entry:
            grouped[owner].append(entry)
    return (
        [
            {
                "name": re.sub(r"^[a-z0-9]{32}-", "", owner.name),
                "pname": package_key(owner.name),
                "version": None,
                "outPath": str(owner),
                "entries": entries,
            }
            for owner, entries in grouped.items()
        ],
        skipped,
    )


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return {}


def usage_index(path: Path) -> tuple[dict[str, Any], dict[str, list[str]]]:
    records = load_json(path).get("appUsageRanking", {})
    indexes: dict[str, list[str]] = defaultdict(list)
    for key, record in records.items():
        for value in (key, record.get("name", ""), executable_from(record.get("exec", ""))):
            token = normalize(str(value))
            if token and key not in indexes[token]:
                indexes[token].append(key)
    return records, indexes


def entry_tokens(entry: dict[str, str]) -> set[str]:
    return {
        token
        for token in (
            normalize(entry["id"]),
            normalize(entry["name"]),
            normalize(entry["exec"]),
            normalize(entry["wm_class"]),
        )
        if len(token) >= 3
    }


def match_usage_keys(entry: dict[str, str], index: dict[str, list[str]]) -> set[str]:
    matches: set[str] = set()
    for token in entry_tokens(entry):
        matches.update(index.get(token, []))
    return matches


def notification_counts(path: Path) -> dict[str, int]:
    data = load_json(path)
    notifications = data if isinstance(data, list) else data.get("notifications", [])
    counts: dict[str, int] = defaultdict(int)
    for item in notifications if isinstance(notifications, list) else []:
        if not isinstance(item, dict):
            continue
        for field in ("desktopEntry", "appName"):
            token = normalize(str(item.get(field, "")))
            if token:
                counts[token] += 1
    return counts


def history_text(home: Path) -> str:
    chunks: list[str] = []
    for path in (
        home / ".local/share/fish/fish_history",
        home / ".config/nushell/history.txt",
    ):
        try:
            chunks.append(path.read_text(encoding="utf-8", errors="ignore"))
        except OSError:
            pass
    return "\n".join(chunks).casefold()


def iter_config_files(roots: Iterable[Path]) -> Iterable[Path]:
    seen: set[Path] = set()
    for root in roots:
        if not root.is_dir():
            continue
        for current, dirs, files in os.walk(root):
            dirs[:] = [name for name in dirs if name not in SKIP_DIRS]
            for name in files:
                path = Path(current) / name
                if path in seen or path.suffix.casefold() not in TEXT_SUFFIXES:
                    continue
                seen.add(path)
                try:
                    if path.stat().st_size <= 1_000_000:
                        yield path
                except OSError:
                    continue


def config_references(
    roots: Iterable[Path],
    home_config: Path,
    token_to_packages: dict[str, set[int]],
) -> dict[int, list[str]]:
    references: dict[int, list[str]] = defaultdict(list)
    searchable = sorted(
        (token for token in token_to_packages if len(token) >= 4),
        key=len,
        reverse=True,
    )
    if not searchable:
        return references
    pattern = re.compile(
        r"(?<![A-Za-z0-9])(?:"
        + "|".join(re.escape(token) for token in searchable)
        + r")(?![A-Za-z0-9])",
        re.IGNORECASE,
    )
    for path in iter_config_files(roots):
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        matched_packages: set[int] = set()
        for match in pattern.finditer(text):
            matched_packages.update(token_to_packages.get(match.group(0).casefold(), set()))
        for package_id in matched_packages:
            references[package_id].append(str(path))

    normalized_tokens: dict[str, set[int]] = defaultdict(set)
    for token, package_ids in token_to_packages.items():
        normalized_tokens[normalize(token)].update(package_ids)
    try:
        config_children = list(home_config.iterdir())
    except OSError:
        config_children = []
    for path in config_children:
        for package_id in normalized_tokens.get(normalize(path.name), set()):
            path_string = str(path)
            if path_string not in references[package_id]:
                references[package_id].append(path_string)
    return references


def iso_time(timestamp_ms: int | float | None) -> str | None:
    if not timestamp_ms:
        return None
    return dt.datetime.fromtimestamp(float(timestamp_ms) / 1000, dt.timezone.utc).isoformat(
        timespec="seconds"
    )


def analyze(args: argparse.Namespace) -> dict[str, Any]:
    home = Path.home() if args.user == os.environ.get("USER") else Path("/home") / args.user
    dms_state = home / ".local/state/DankMaterialShell/appusage.json"
    records, usage_by_token = usage_index(dms_state)
    notifications = notification_counts(home / ".cache/DankMaterialShell/notification_history.json")
    shell_history = history_text(home)

    declared_packages = nix_packages(args.flake, args.host, args.user)
    gui_packages, skipped_profile_entries = active_gui_packages(
        home, args.user, declared_packages
    )

    token_to_packages: dict[str, set[int]] = defaultdict(set)
    raw_tokens: dict[int, set[str]] = defaultdict(set)
    for package_id, package in enumerate(gui_packages):
        for entry in package["entries"]:
            for raw in (entry["id"], entry["exec"], entry["wm_class"]):
                token = raw.casefold().strip()
                if len(token) >= 4:
                    raw_tokens[package_id].add(token)
                    token_to_packages[token].add(package_id)

    config_refs = config_references(
        (args.flake / ".config",),
        home / ".config",
        token_to_packages,
    )
    cutoff = dt.datetime.now(dt.timezone.utc).timestamp() * 1000 - args.days * 86_400_000
    report: list[dict[str, Any]] = []

    for package_id, package in enumerate(gui_packages):
        usage_keys: set[str] = set()
        app_names: list[str] = []
        notify_count = 0
        for entry in package["entries"]:
            usage_keys.update(match_usage_keys(entry, usage_by_token))
            app_names.append(entry["name"])
            notify_count += sum(notifications.get(token, 0) for token in entry_tokens(entry))

        launches = sum(int(records[key].get("usageCount", 0)) for key in usage_keys)
        last_used_ms = max(
            (float(records[key].get("lastUsed", 0)) for key in usage_keys), default=0
        )
        history_hits = sum(shell_history.count(token) for token in raw_tokens[package_id])
        recent = last_used_ms >= cutoff
        if recent:
            status = "recent"
        elif last_used_ms:
            status = (
                "stale-rare"
                if launches <= args.max_launches
                else "stale-frequent"
            )
        else:
            status = "configured-only" if config_refs[package_id] else "never"

        report.append(
            {
                "package": package.get("pname") or package["name"],
                "version": package.get("version"),
                "applications": sorted(set(app_names)),
                "status": status,
                "dms_launches": launches,
                "last_dms_launch": iso_time(last_used_ms),
                "shell_history_hits": history_hits,
                "notification_hits": notify_count,
                "config_references": sorted(config_refs[package_id]),
            }
        )

    order = {
        "never": 0,
        "configured-only": 1,
        "stale-rare": 2,
        "stale-frequent": 3,
        "recent": 4,
    }
    report.sort(
        key=lambda row: (
            order[row["status"]],
            row["dms_launches"],
            row["last_dms_launch"] or "",
            row["package"].casefold(),
        )
    )
    return {
        "host": args.host,
        "user": args.user,
        "window_days": args.days,
        "dms_usage_file": str(dms_state),
        "gui_package_count": len(gui_packages),
        "unmatched_profile_entry_count": skipped_profile_entries,
        "applications": report if args.all else [row for row in report if row["status"] != "recent"],
    }


def print_report(result: dict[str, Any]) -> None:
    rows = result["applications"]
    print(
        f"{result['host']} GUI package usage: {len(rows)} shown / "
        f"{result['gui_package_count']} detected "
        f"({result['window_days']}-day DMS window)"
    )
    print("STATUS           LAUNCHES  LAST DMS LAUNCH    HIST  NOTIF  CONFIG  PACKAGE / APPLICATIONS")
    for row in rows:
        last = row["last_dms_launch"][:10] if row["last_dms_launch"] else "never"
        apps = ", ".join(row["applications"])
        print(
            f"{row['status']:<16} {row['dms_launches']:>8}  {last:<17} "
            f"{row['shell_history_hits']:>5}  {row['notification_hits']:>5}  "
            f"{len(row['config_references']):>6}  {row['package']} / {apps}"
        )
    print("\nDMS launches are authoritative only for apps opened through the DMS launcher.")
    print("HIST, NOTIF, and CONFIG are secondary evidence; inspect them before removing a package.")


def main() -> None:
    args = parse_args()
    result = analyze(args)
    if args.json:
        json.dump(result, sys.stdout, indent=2)
        print()
    else:
        print_report(result)


if __name__ == "__main__":
    main()
