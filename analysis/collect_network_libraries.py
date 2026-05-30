#!/usr/bin/env python3
"""Collect network-facing Nix package/library dependency metadata for fern/eisen.

The script intentionally starts from explicit service-facing roots instead of the
full NixOS closure. The full closure includes desktop/session packages and base
system plumbing that are not meaningfully "reachable through network".
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import deque
from pathlib import Path
from typing import Any


REPO = Path(__file__).resolve().parents[1]
OUT = REPO / "analysis"
HTTP_TIMEOUT = 8


# Higher numbers are processed first. These are the Internet/LAN/Tailscale-facing
# services and containers configured by servers/fern and servers/eisen.
ROOTS = [
    (100, "fern", "service", "caddy", "config.services.caddy.package"),
    (98, "fern", "service", "openssh", "config.programs.ssh.package"),
    (97, "fern", "service", "llama-swap", "config.services.llama-swap.package"),
    (96, "fern", "service", "llama-cpp-server", "pkgs.llama-cpp"),
    (94, "fern", "service", "nix-serve", "config.services.nix-serve.package"),
    (92, "fern", "service", "steam-network-runtime", "config.programs.steam.package"),
    (90, "fern", "service", "kdeconnect", "pkgs.kdePackages.kdeconnect-kde"),
    (88, "fern", "service", "openrgb", "config.services.hardware.openrgb.package"),
    (86, "fern", "service", "docker", "config.virtualisation.docker.package"),
    (100, "eisen", "service", "caddy", "config.services.caddy.package"),
    (99, "eisen", "service", "tailscale", "config.services.tailscale.package"),
    (98, "eisen", "service", "openssh", "config.programs.ssh.package"),
    (97, "eisen", "service", "jellyfin", "config.services.jellyfin.package"),
    (96, "eisen", "service", "sonarr", "config.services.sonarr.package"),
    (95, "eisen", "service", "radarr", "config.services.radarr.package"),
    (94, "eisen", "service", "prowlarr", "config.services.prowlarr.package"),
    (93, "eisen", "service", "karakeep", "config.services.karakeep.package"),
    (92, "eisen", "service", "uptime-kuma", "config.services.uptime-kuma.package"),
    (91, "eisen", "service", "grafana", "config.services.grafana.package"),
    (90, "eisen", "service", "prometheus", "config.services.prometheus.package"),
    (89, "eisen", "service", "prometheus-node-exporter", "pkgs.prometheus-node-exporter"),
    (88, "eisen", "service", "exportarr-sonarr", "pkgs.exportarr"),
    (87, "eisen", "service", "exportarr-radarr", "pkgs.exportarr"),
    (86, "eisen", "service", "exportarr-prowlarr", "pkgs.exportarr"),
    (85, "eisen", "service", "glance", "config.services.glance.package"),
    (84, "eisen", "service", "dnsmasq", "config.services.dnsmasq.package"),
    (83, "eisen", "service", "docker", "config.virtualisation.docker.package"),
    (82, "eisen", "service", "llama-swap-exporter", "pkgs.callPackage ./servers/eisen/llama-swap-exporter/default.nix { }"),
]

CONTAINER_ROOTS = [
    (80, "eisen", "container", "gluetun", "qmcgaw/gluetun"),
    (79, "eisen", "container", "qbittorrent", "lscr.io/linuxserver/qbittorrent"),
    (78, "eisen", "container", "jackett", "lscr.io/linuxserver/jackett"),
    (77, "eisen", "container", "prometheus-qb", "ghcr.io/esanchezm/prometheus-qbittorrent-exporter"),
    (76, "eisen", "container", "tolgee", "tolgee/tolgee"),
]

GITHUB_RE = re.compile(r"github\.com[:/](?P<owner>[^/]+)/(?P<repo>[^/#?]+?)(?:\.git|/|#|\?|$)")
STORE_HASH_PREFIX_RE = re.compile(r"^[0-9a-z]{32}-(?P<name>.+)$")


def run(cmd: list[str], *, timeout: int = 120) -> str:
    proc = subprocess.run(
        cmd,
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"command failed: {' '.join(cmd)}\n{proc.stderr}")
    return proc.stdout


def write_json_atomic(path: Path, data: dict[str, Any]) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    tmp.replace(path)


def nix_string(s: str) -> str:
    return json.dumps(s)


def root_expr() -> str:
    rows = []
    for priority, host, kind, name, expr in ROOTS:
        cfg = "flake.nixosConfigurations.fern" if host == "fern" else "flake.colmenaHive.nodes.eisen"
        rows.append(
            "(let node = "
            + cfg
            + "; config = node.config; pkgs = node.pkgs; pkg = "
            + expr
            + "; in mkRoot "
            + str(priority)
            + " "
            + nix_string(host)
            + " "
            + nix_string(kind)
            + " "
            + nix_string(name)
            + " pkg)"
        )

    return """
let
  flake = builtins.getFlake (toString ./.);
  clean = s: builtins.unsafeDiscardStringContext (toString s);
  listOrNull = x: if builtins.isList x then map clean x else if x == null then [] else [ (clean x) ];
  mkRoot = priority: host: kind: rootName: pkg: {
    inherit priority host kind rootName;
    packageName = pkg.name or rootName;
    pname = pkg.pname or null;
    version = pkg.version or null;
    storePath = clean pkg;
    drv = if pkg ? drvPath then clean pkg.drvPath else null;
    homepage = pkg.meta.homepage or null;
    description = pkg.meta.description or null;
    sourceUrls = listOrNull (pkg.src.urls or (pkg.src.url or null));
  };
in [
""" + "\n".join(rows) + "\n]"


def eval_roots() -> list[dict[str, Any]]:
    data = run(["nix", "eval", "--impure", "--json", "--expr", root_expr()], timeout=240)
    roots = json.loads(data)
    for priority, host, kind, name, image in CONTAINER_ROOTS:
        roots.append(
            {
                "priority": priority,
                "host": host,
                "kind": kind,
                "rootName": name,
                "packageName": image,
                "pname": name,
                "version": None,
                "storePath": None,
                "drv": None,
                "homepage": None,
                "description": "OCI image configured in virtualisation.oci-containers",
                "sourceUrls": [],
                "image": image,
            }
        )
    return sorted(roots, key=lambda r: (-int(r["priority"]), r["host"], r["rootName"]))


def derivation_show_recursive(drv: str) -> dict[str, Any]:
    data = run(["nix", "derivation", "show", "-r", drv], timeout=300)
    parsed = json.loads(data)
    # Nix 2.30+ returns {"version": 3, "derivations": {"basename.drv": ...}};
    # older Nix returned {"/nix/store/...drv": ...}. Normalize to basename keys.
    derivations = parsed.get("derivations") if isinstance(parsed, dict) else None
    if isinstance(derivations, dict):
        return derivations
    return {Path(k).name: v for k, v in parsed.items()}


def drv_meta(drv: str, all_drvs: dict[str, Any]) -> dict[str, Any]:
    item = all_drvs.get(Path(drv).name, all_drvs.get(drv, {}))
    env = item.get("env", {})
    name = clean_library_name(env.get("pname") or env.get("name") or Path(drv).name.removesuffix(".drv"))
    return {
        "name": name,
        "version": env.get("version"),
        "homepage": env.get("homepage") or env.get("meta.homepage"),
        "description": env.get("meta.description") or env.get("description"),
        "source_link": source_from_env(env),
        "language": infer_language(name, env),
    }


def clean_library_name(name: str) -> str:
    match = STORE_HASH_PREFIX_RE.match(name)
    if match:
        name = match.group("name")
    for suffix in (".nupkg", ".tar.gz", ".tar.xz", ".zip", ".drv"):
        if name.endswith(suffix):
            name = name[: -len(suffix)]
    return name


def source_from_env(env: dict[str, str]) -> str | None:
    for key in ("src", "urls", "url", "cargoDeps", "npmDeps", "goModules"):
        val = env.get(key)
        if val and ("http" in val or "github" in val):
            return val
    for key, val in env.items():
        if key.lower().endswith("url") and val and ("http" in val or "github" in val):
            return val
    return None


def infer_language(name: str, env: dict[str, str]) -> str | None:
    text = " ".join([name, env.get("nativeBuildInputs", ""), env.get("buildInputs", "")]).lower()
    if "python" in text or name.startswith("python"):
        return "Python"
    if "cargo" in text or "rustc" in text:
        return "Rust"
    if "go" in text and ("gomod" in text or "goModules" in env):
        return "Go"
    if "node" in text or "npm" in text or "pnpm" in text or "yarn" in text:
        return "JavaScript/TypeScript"
    if "cmake" in text or "gcc" in text or "clang" in text:
        return "C/C++"
    if name.startswith(("qt", "k", "lib")):
        return "C/C++"
    return None


def github_repo(*values: str | None) -> str | None:
    for value in values:
        if not value:
            continue
        match = GITHUB_RE.search(value)
        if match:
            return f"{match.group('owner')}/{match.group('repo')}"
    return None


def noisy_for_review(row: dict[str, Any]) -> bool:
    name = row["library"].lower()
    drv_path = row.get("drv_path", "").lower()
    if ".nupkg" in drv_path and not row.get("version_in_use"):
        return True
    noisy_exact = {
        "bash",
        "coreutils",
        "coreutils-full",
        "stdenv-linux",
        "install-shell-files",
        "version-check-hook",
        "writable-tmpdir-as-home-hook",
        "auto-patchelf-hook",
        "pkg-config-wrapper",
        "gcc-wrapper",
        "gnumake",
        "cmake",
        "ninja",
        "patchelf",
        "remove-references-to",
        "strip-nondeterminism",
    }
    if name in noisy_exact:
        return True
    noisy_bits = (
        "-source",
        "source-",
        "-go-modules",
        "builder.sh",
        "setup-hook",
        "-hook",
        ".patch",
        ".diff",
        "testdata",
        "fixture",
    )
    return any(bit in name for bit in noisy_bits)


def github_json(path: str) -> dict[str, Any] | None:
    req = urllib.request.Request(
        f"https://api.github.com/{path}",
        headers={"Accept": "application/vnd.github+json", "User-Agent": "dotfiles-analysis"},
    )
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as res:
            return json.loads(res.read().decode())
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError):
        return None


def http_json(url: str) -> dict[str, Any] | None:
    req = urllib.request.Request(
        url,
        headers={"Accept": "application/json", "User-Agent": "dotfiles-analysis"},
    )
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as res:
            return json.loads(res.read().decode())
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        return None


def normalize_repo_url(value: str | None) -> str | None:
    if not value:
        return None
    value = value.strip()
    if value.startswith("git+"):
        value = value[4:]
    if value.startswith("git://github.com/"):
        value = "https://github.com/" + value.removeprefix("git://github.com/")
    if value.startswith("git@github.com:"):
        value = "https://github.com/" + value.removeprefix("git@github.com:")
    if value.endswith(".git"):
        value = value[:-4]
    return value


def parse_ecosystem(row: dict[str, Any]) -> tuple[str | None, str | None, str | None]:
    name = row["library"]
    version = row.get("version_in_use") or None
    drv = row.get("drv_path", "")
    if ".nupkg" in drv or row["root_name"].lower() in ("jellyfin", "sonarr", "radarr", "prowlarr"):
        # The derivation rows have clean name/version; the raw .nupkg rows are
        # filtered from review but can still be enriched in summary/deps.
        if not version and ".nupkg" in drv:
            base = clean_library_name(Path(drv).name.removesuffix(".drv"))
            m = re.match(r"(.+)\.(\d+(?:\.\d+)+(?:[-.][0-9A-Za-z]+)*)$", base)
            if m:
                name, version = m.group(1), m.group(2)
        return "nuget", name, version
    if row["root_name"] in {"nix-serve"} and "perl5." in drv:
        return "cpan", name, version
    if name.startswith("python") or "python" in drv:
        py_name = re.sub(r"^python\d+(?:\.\d+)?-", "", name)
        return "pypi", py_name, version
    if "node_modules" in row.get("dependency_path", "") or row["root_name"] in {"karakeep", "uptime-kuma"}:
        return "npm", name, version
    if "cargo" in name.lower() or "rust" in drv.lower():
        return "crates", name, version
    return None, None, None


def release_date_from_pypi(files: list[dict[str, Any]]) -> str | None:
    dates = [f.get("upload_time_iso_8601") for f in files if f.get("upload_time_iso_8601")]
    return min(dates) if dates else None


def enrich_ecosystem(ecosystem: str, package: str, version: str | None, cache: dict[str, Any]) -> dict[str, Any]:
    key = f"{ecosystem}:{package}:{version or ''}"
    if key in cache:
        return cache[key]
    result: dict[str, Any] = {"ecosystem": ecosystem}
    quoted = urllib.parse.quote(package, safe="")

    if ecosystem == "nuget":
        result["language"] = "C#"
        if version:
            data = http_json(f"https://api.nuget.org/v3/registration5-semver1/{package.lower()}/{version.lower()}.json")
            entry = (data or {}).get("catalogEntry", {})
            if isinstance(entry, str):
                entry = http_json(entry) or {}
            repo = entry.get("repository") or {}
            repo_url = repo.get("url") if isinstance(repo, dict) else None
            repo_url = normalize_repo_url(repo_url or entry.get("repositoryUrl") or entry.get("projectUrl"))
            result.update(
                {
                    "source_link": repo_url or entry.get("projectUrl"),
                    "release_date": entry.get("published"),
                }
            )
        index = http_json(f"https://api.nuget.org/v3-flatcontainer/{package.lower()}/index.json")
        versions = (index or {}).get("versions") or []
        if versions:
            result["latest_version"] = versions[-1]

    elif ecosystem == "npm":
        data = http_json(f"https://registry.npmjs.org/{quoted}") or {}
        info = data.get("versions", {}).get(version or "", {}) if version else {}
        repo = info.get("repository") or data.get("repository") or {}
        repo_url = repo.get("url") if isinstance(repo, dict) else repo
        latest = (data.get("dist-tags") or {}).get("latest")
        result.update(
            {
                "source_link": normalize_repo_url(repo_url) or data.get("homepage"),
                "latest_version": latest,
                "release_date": (data.get("time") or {}).get(version or ""),
                "latest_release_date": (data.get("time") or {}).get(latest or ""),
                "language": "JavaScript/TypeScript",
            }
        )

    elif ecosystem == "pypi":
        data = http_json(f"https://pypi.org/pypi/{quoted}/json") or {}
        info = data.get("info", {})
        urls = info.get("project_urls") or {}
        source = urls.get("Source") or urls.get("Source Code") or urls.get("Homepage") or info.get("home_page") or info.get("package_url")
        latest = info.get("version")
        result.update(
            {
                "source_link": normalize_repo_url(source),
                "latest_version": latest,
                "release_date": release_date_from_pypi((data.get("releases") or {}).get(version or "", [])),
                "latest_release_date": release_date_from_pypi((data.get("releases") or {}).get(latest or "", [])),
                "language": "Python",
            }
        )

    elif ecosystem == "crates":
        data = http_json(f"https://crates.io/api/v1/crates/{quoted}") or {}
        crate = data.get("crate", {})
        result.update(
            {
                "source_link": normalize_repo_url(crate.get("repository") or crate.get("homepage")),
                "latest_version": crate.get("max_stable_version") or crate.get("newest_version"),
                "latest_release_date": crate.get("updated_at"),
                "language": "Rust",
            }
        )

    elif ecosystem == "cpan":
        dist = package.replace("::", "-")
        result.update(
            {
                "source_link": f"https://metacpan.org/pod/{package}",
                "language": "Perl",
            }
        )
        data = http_json(f"https://fastapi.metacpan.org/v1/release/{urllib.parse.quote(dist, safe='')}") or {}
        resources = ((data.get("metadata") or {}).get("resources") or {})
        repo = resources.get("repository") or {}
        repo_url = repo.get("url") if isinstance(repo, dict) else repo
        result.update(
            {
                "source_link": normalize_repo_url(repo_url) or result["source_link"],
                "latest_version": data.get("version"),
                "latest_release_date": data.get("date"),
            }
        )

    result["github_repo"] = github_repo(result.get("source_link"))
    cache[key] = result
    return result


def enrich_github(repo: str, cache: dict[str, Any], sleep: float) -> dict[str, Any]:
    if repo in cache:
        return cache[repo]
    data = github_json(f"repos/{repo}") or {}
    if sleep:
        time.sleep(sleep)
    latest = github_json(f"repos/{repo}/releases/latest") or {}
    if sleep:
        time.sleep(sleep)
    result = {
        "github_repo": repo,
        "github_stars": data.get("stargazers_count"),
        "language": data.get("language"),
        "source_link": data.get("html_url"),
        "latest_version": latest.get("tag_name"),
        "latest_release_date": latest.get("published_at"),
    }
    cache[repo] = result
    return result


def walk_deps(root: dict[str, Any], all_drvs: dict[str, Any], max_depth: int) -> list[dict[str, Any]]:
    start = root.get("drv")
    if not start:
        return []
    start_key = Path(start).name
    rows = []
    seen = {start_key}
    queue = deque([(start_key, [], 0)])
    while queue:
        drv, path, depth = queue.popleft()
        if depth >= max_depth:
            continue
        item = all_drvs.get(drv, {})
        input_drvs = item.get("inputDrvs") or (item.get("inputs") or {}).get("drvs") or {}
        for dep_drv in sorted(input_drvs.keys()):
            dep_key = Path(dep_drv).name
            if dep_key in seen:
                continue
            seen.add(dep_key)
            meta = drv_meta(dep_key, all_drvs)
            dep_path = path + [meta["name"]]
            rows.append(
                {
                    "host": root["host"],
                    "root_kind": root["kind"],
                    "root_name": root["rootName"],
                    "root_package": root["packageName"],
                    "library": meta["name"],
                    "version_in_use": meta["version"],
                    "dep_depth": depth + 1,
                    "dependency_path": " -> ".join([root["rootName"]] + dep_path),
                    "drv_path": dep_key,
                    "homepage": meta["homepage"],
                    "source_link": meta["source_link"],
                    "language": meta["language"],
                    "github_repo": github_repo(meta["homepage"], meta["source_link"]),
                    "github_stars": None,
                    "ecosystem": None,
                    "release_date": None,
                    "latest_version": None,
                    "latest_release_date": None,
                }
            )
            queue.append((dep_key, dep_path, depth + 1))
    return rows


def write_csv(path: Path, rows: list[dict[str, Any]], fields: list[str]) -> None:
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-roots", type=int, default=18)
    parser.add_argument("--max-depth", type=int, default=2)
    parser.add_argument("--github-limit", type=int, default=80)
    parser.add_argument("--github-sleep", type=float, default=0.1)
    parser.add_argument("--ecosystem-limit", type=int, default=400)
    args = parser.parse_args()

    OUT.mkdir(exist_ok=True)
    roots = eval_roots()
    selected = [r for r in roots if r.get("drv")][: args.max_roots]

    dep_rows: list[dict[str, Any]] = []
    for root in selected:
        print(f"walking {root['host']}:{root['rootName']} {root['packageName']}", file=sys.stderr)
        try:
            all_drvs = derivation_show_recursive(root["drv"])
        except RuntimeError as exc:
            print(exc, file=sys.stderr)
            continue
        dep_rows.extend(walk_deps(root, all_drvs, args.max_depth))

    ecosystem_cache_path = OUT / "ecosystem-cache.json"
    ecosystem_cache = json.loads(ecosystem_cache_path.read_text()) if ecosystem_cache_path.exists() else {}
    ecosystem_keys = []
    ecosystem_rows: dict[tuple[str | None, str | None, str | None], list[dict[str, Any]]] = {}
    for row in dep_rows:
        ecosystem, package, version = parse_ecosystem(row)
        if ecosystem and package:
            key = (ecosystem, package, version)
            ecosystem_rows.setdefault(key, []).append(row)
            if key not in ecosystem_keys:
                ecosystem_keys.append(key)
    for idx, (ecosystem, package, version) in enumerate(ecosystem_keys[: args.ecosystem_limit], start=1):
        if idx % 25 == 1:
            print(f"enriching ecosystem metadata {idx}/{min(len(ecosystem_keys), args.ecosystem_limit)}", file=sys.stderr)
        meta = enrich_ecosystem(ecosystem, package, version, ecosystem_cache)
        for row in ecosystem_rows.get((ecosystem, package, version), []):
            row.update({k: v for k, v in meta.items() if v is not None and (not row.get(k) or k in {"ecosystem", "release_date"})})
        if idx % 25 == 0:
            write_json_atomic(ecosystem_cache_path, ecosystem_cache)
    write_json_atomic(ecosystem_cache_path, ecosystem_cache)

    cache_path = OUT / "github-cache.json"
    cache = json.loads(cache_path.read_text()) if cache_path.exists() else {}
    repos = []
    for row in dep_rows:
        repo = row.get("github_repo")
        if repo and repo not in repos:
            repos.append(repo)
    for idx, repo in enumerate(repos[: args.github_limit], start=1):
        if idx % 25 == 1:
            print(f"enriching GitHub metadata {idx}/{min(len(repos), args.github_limit)}", file=sys.stderr)
        gh = enrich_github(repo, cache, args.github_sleep)
        for row in dep_rows:
            if row.get("github_repo") == repo:
                row.update({k: v for k, v in gh.items() if v is not None})
        if idx % 25 == 0:
            write_json_atomic(cache_path, cache)

    for root in roots:
        repo = github_repo(root.get("homepage"), " ".join(root.get("sourceUrls") or []))
        root["github_repo"] = repo
        root["github_stars"] = None
        root["ecosystem"] = "nix"
        root["release_date"] = None
        root["latest_version"] = None
        root["latest_release_date"] = None
        root["language"] = None
        if repo:
            gh = enrich_github(repo, cache, args.github_sleep)
            root.update({k: v for k, v in gh.items() if v is not None})
    write_json_atomic(cache_path, cache)

    root_fields = [
        "priority",
        "host",
        "kind",
        "rootName",
        "packageName",
        "pname",
        "version",
        "drv",
        "storePath",
        "homepage",
        "description",
        "sourceUrls",
        "image",
        "github_repo",
        "github_stars",
        "ecosystem",
        "release_date",
        "latest_version",
        "latest_release_date",
        "language",
    ]
    dep_fields = [
        "host",
        "root_kind",
        "root_name",
        "root_package",
        "library",
        "version_in_use",
        "dep_depth",
        "dependency_path",
        "drv_path",
        "homepage",
        "source_link",
        "github_repo",
        "github_stars",
        "ecosystem",
        "release_date",
        "latest_version",
        "latest_release_date",
        "language",
    ]
    write_csv(OUT / "network-package-roots.csv", roots, root_fields)
    write_csv(OUT / "network-library-deps.csv", dep_rows, dep_fields)

    # One row per library, preserving the first root/path encountered. This is
    # convenient for hand-reviewing uncommon deps before opening the full edge CSV.
    summary: dict[str, dict[str, Any]] = {}
    for row in dep_rows:
        key = row["drv_path"]
        summary.setdefault(key, row.copy())
    write_csv(
        OUT / "network-library-summary.csv",
        sorted(summary.values(), key=lambda r: (r.get("github_stars") is not None, r.get("github_stars") or 0, r["library"])),
        dep_fields,
    )
    review_rows = [r for r in summary.values() if not noisy_for_review(r)]
    write_csv(
        OUT / "network-library-review.csv",
        sorted(review_rows, key=lambda r: (r.get("github_stars") is not None, r.get("github_stars") or 0, r["library"])),
        dep_fields,
    )
    print(f"wrote {len(roots)} roots and {len(dep_rows)} dependency rows", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
