#!/usr/bin/env python3
"""Recover PhotoPrism manual albums and private flags by original file hashes."""

from __future__ import annotations

import argparse
import datetime as dt
import os
import sqlite3
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

DEFAULT_OLD_DB = Path("/media/large/server-backup/photoprism/index.db")
DEFAULT_CURRENT_DB = Path("/var/lib/photoprism/index.db")
REQUIRED_TABLES = {"albums", "files", "photos", "photos_albums", "versions"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Recover manual PhotoPrism albums and private photo flags after reimporting "
            "files at new paths. Files are matched by SHA-1 content hash, never by path "
            "or PhotoPrism UID. The default mode is read-only."
        )
    )
    parser.add_argument("--old-db", type=Path, default=DEFAULT_OLD_DB)
    parser.add_argument("--current-db", type=Path, default=DEFAULT_CURRENT_DB)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="write the recovered albums and memberships; PhotoPrism must be stopped",
    )
    parser.add_argument(
        "--allow-partial",
        action="store_true",
        help="apply even when some old album memberships cannot be mapped",
    )
    parser.add_argument(
        "--backup",
        type=Path,
        help="backup destination used before --apply (default: beside the current database)",
    )
    parser.add_argument("--service", default="photoprism.service")
    return parser.parse_args()


def fail(message: str) -> None:
    raise SystemExit(f"error: {message}")


def open_database(path: Path, *, writable: bool) -> sqlite3.Connection:
    if not path.is_file():
        fail(f"database does not exist: {path}")
    mode = "rw" if writable else "ro"
    try:
        connection = sqlite3.connect(f"file:{path.resolve()}?mode={mode}", uri=True)
    except sqlite3.Error as error:
        fail(f"cannot open {path}: {error}")
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA busy_timeout = 5000")
    return connection


def table_names(connection: sqlite3.Connection) -> set[str]:
    return {
        row[0]
        for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        )
    }


def columns(connection: sqlite3.Connection, table: str) -> list[str]:
    return [row[1] for row in connection.execute(f'PRAGMA table_info("{table}")')]


def version(connection: sqlite3.Connection) -> str:
    row = connection.execute(
        "SELECT version FROM versions ORDER BY id DESC LIMIT 1"
    ).fetchone()
    return str(row[0]) if row else "unknown"


def check_database(connection: sqlite3.Connection, label: str) -> None:
    missing = REQUIRED_TABLES - table_names(connection)
    if missing:
        fail(f"{label} database is missing tables: {', '.join(sorted(missing))}")
    result = connection.execute("PRAGMA quick_check").fetchone()[0]
    if result != "ok":
        fail(f"{label} database failed quick_check: {result}")


def require_compatible_schema(
    old: sqlite3.Connection, current: sqlite3.Connection
) -> list[str]:
    old_columns = columns(old, "albums")
    current_columns = columns(current, "albums")
    if set(old_columns) != set(current_columns):
        missing_current = sorted(set(old_columns) - set(current_columns))
        only_current = sorted(set(current_columns) - set(old_columns))
        fail(
            "album schemas have different columns; refusing a direct migration\n"
            f"  missing from current: {', '.join(missing_current) or 'none'}\n"
            f"  only in current:      {', '.join(only_current) or 'none'}"
        )
    membership_columns = columns(old, "photos_albums")
    if set(membership_columns) != set(columns(current, "photos_albums")):
        fail("photos_albums schemas have different columns; refusing a direct migration")
    required_photo_columns = {"photo_uid", "photo_private", "deleted_at", "updated_at"}
    for label, connection in (("backup", old), ("current", current)):
        missing = required_photo_columns - set(columns(connection, "photos"))
        if missing:
            fail(
                f"{label} photos table is missing columns: "
                + ", ".join(sorted(missing))
            )
    return [name for name in old_columns if name != "id"]


def service_state(service: str) -> str:
    result = subprocess.run(
        ["systemctl", "is-active", service],
        text=True,
        capture_output=True,
        check=False,
    )
    return result.stdout.strip() or "unknown"


def load_photo_map(
    old: sqlite3.Connection, current: sqlite3.Connection
) -> tuple[dict[str, str], set[str]]:
    current_hashes: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for row in current.execute(
        """
        SELECT file_hash, file_name, photo_uid
          FROM files
         WHERE file_root = '/'
           AND file_hash IS NOT NULL AND file_hash <> ''
           AND photo_uid IS NOT NULL AND photo_uid <> ''
           AND COALESCE(file_missing, 0) = 0
           AND deleted_at IS NULL
        """
    ):
        current_hashes[str(row["file_hash"])].append(
            (str(row["photo_uid"]), Path(str(row["file_name"])).name)
        )

    candidates: dict[str, set[str]] = defaultdict(set)
    for row in old.execute(
        """
        SELECT file_hash, file_name, photo_uid
          FROM files
         WHERE file_root = '/'
           AND file_hash IS NOT NULL AND file_hash <> ''
           AND photo_uid IS NOT NULL AND photo_uid <> ''
           AND COALESCE(file_missing, 0) = 0
           AND deleted_at IS NULL
        """
    ):
        matches = current_hashes.get(str(row["file_hash"]), ())
        hash_uids = {uid for uid, _ in matches}
        if len(hash_uids) > 1:
            old_name = Path(str(row["file_name"])).name
            name_uids = {uid for uid, name in matches if name == old_name}
            if len(name_uids) == 1:
                hash_uids = name_uids
        candidates[str(row["photo_uid"])].update(hash_uids)

    mapped = {
        old_uid: next(iter(current_uids))
        for old_uid, current_uids in candidates.items()
        if len(current_uids) == 1
    }
    ambiguous = {
        old_uid for old_uid, current_uids in candidates.items() if len(current_uids) > 1
    }
    return mapped, ambiguous


def recovery_plan(
    old: sqlite3.Connection, current: sqlite3.Connection
) -> dict[str, Any]:
    albums = list(
        old.execute(
            """
            SELECT *
              FROM albums
             WHERE album_type = 'album' AND deleted_at IS NULL
             ORDER BY album_title, album_uid
            """
        )
    )
    memberships = list(
        old.execute(
            """
            SELECT pa.*
              FROM photos_albums AS pa
              JOIN albums AS a ON a.album_uid = pa.album_uid
             WHERE a.album_type = 'album' AND a.deleted_at IS NULL
            """
        )
    )
    photo_map, ambiguous_photos = load_photo_map(old, current)

    mapped_memberships = []
    missing_by_album: dict[str, int] = defaultdict(int)
    ambiguous_by_album: dict[str, int] = defaultdict(int)
    for membership in memberships:
        old_photo_uid = str(membership["photo_uid"])
        if old_photo_uid in photo_map:
            values = dict(membership)
            values["photo_uid"] = photo_map[old_photo_uid]
            mapped_memberships.append(values)
        elif old_photo_uid in ambiguous_photos:
            ambiguous_by_album[str(membership["album_uid"])] += 1
        else:
            missing_by_album[str(membership["album_uid"])] += 1
    old_private_uids = {
        str(row["photo_uid"])
        for row in old.execute(
            """
            SELECT photo_uid
              FROM photos
             WHERE photo_private = 1 AND deleted_at IS NULL
            """
        )
    }
    mapped_private_old = {
        old_uid for old_uid in old_private_uids if old_uid in photo_map
    }
    mapped_private_uids = {photo_map[old_uid] for old_uid in mapped_private_old}
    ambiguous_private = len(old_private_uids & ambiguous_photos)
    missing_private = len(old_private_uids - mapped_private_old - ambiguous_photos)
    current_private_uids = {
        str(row["photo_uid"])
        for row in current.execute(
            """
            SELECT photo_uid
              FROM photos
             WHERE photo_private = 1 AND deleted_at IS NULL
            """
        )
    }
    private_to_set = mapped_private_uids - current_private_uids

    current_albums = {
        str(row["album_uid"]): str(row["album_type"])
        for row in current.execute(
            "SELECT album_uid, album_type FROM albums WHERE album_uid IS NOT NULL"
        )
    }
    conflicts = [
        str(album["album_uid"])
        for album in albums
        if str(album["album_uid"]) in current_albums
        and current_albums[str(album["album_uid"])] != "album"
    ]
    if conflicts:
        fail(
            "manual album UIDs collide with non-album records in the current database: "
            + ", ".join(conflicts)
        )

    return {
        "albums": albums,
        "memberships": memberships,
        "mapped_memberships": mapped_memberships,
        "missing_by_album": missing_by_album,
        "ambiguous_by_album": ambiguous_by_album,
        "existing_album_uids": {
            uid for uid, album_type in current_albums.items() if album_type == "album"
        },
        "old_private_count": len(old_private_uids),
        "mapped_private_count": len(mapped_private_old),
        "mapped_private_uids": mapped_private_uids,
        "already_private_count": len(mapped_private_uids & current_private_uids),
        "private_to_set": private_to_set,
        "missing_private": missing_private,
        "ambiguous_private": ambiguous_private,
    }


def print_plan(plan: dict[str, Any]) -> None:
    albums = plan["albums"]
    memberships = plan["memberships"]
    mapped = plan["mapped_memberships"]
    missing_by_album = plan["missing_by_album"]
    ambiguous_by_album = plan["ambiguous_by_album"]
    album_titles = {str(row["album_uid"]): str(row["album_title"]) for row in albums}
    missing = sum(missing_by_album.values())
    ambiguous = sum(ambiguous_by_album.values())

    print(f"Manual albums in backup:       {len(albums)}")
    print(f"Already present by UID:        {len(plan['existing_album_uids'])}")
    print(f"Album memberships in backup:  {len(memberships)}")
    print(f"Recoverable by content hash:   {len(mapped)}")
    print(f"Missing current file match:    {missing}")
    print(f"Ambiguous current photo match: {ambiguous}")
    print(f"\nPrivate photos in backup:      {plan['old_private_count']}")
    print(f"Recoverable by content hash:   {plan['mapped_private_count']}")
    print(f"Already private in current DB: {plan['already_private_count']}")
    print(f"New private flags to restore:  {len(plan['private_to_set'])}")
    print(f"Missing current file match:    {plan['missing_private']}")
    print(f"Ambiguous current photo match: {plan['ambiguous_private']}")

    affected = set(missing_by_album) | set(ambiguous_by_album)
    if affected:
        print("\nAlbums with skipped memberships:")
        rows = sorted(
            (
                missing_by_album[uid] + ambiguous_by_album[uid],
                album_titles.get(uid, uid),
                missing_by_album[uid],
                ambiguous_by_album[uid],
            )
            for uid in affected
        )
        for total, title, album_missing, album_ambiguous in reversed(rows[-15:]):
            print(
                f"  {title}: {total} skipped "
                f"({album_missing} missing, {album_ambiguous} ambiguous)"
            )


def default_backup_path(current_db: Path) -> Path:
    timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return current_db.with_name(f"{current_db.name}.pre-album-recovery-{timestamp}")


def backup_database(
    connection: sqlite3.Connection, source: Path, destination: Path
) -> None:
    if destination.exists():
        fail(f"backup destination already exists: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    backup = sqlite3.connect(destination)
    try:
        connection.backup(backup)
        result = backup.execute("PRAGMA quick_check").fetchone()[0]
        if result != "ok":
            fail(f"new backup failed quick_check: {result}")
    finally:
        backup.close()
    source_stat = source.stat()
    os.chmod(destination, source_stat.st_mode & 0o777)
    os.chown(destination, source_stat.st_uid, source_stat.st_gid)
    print(f"Current database backup:      {destination}")


def apply_recovery(
    current: sqlite3.Connection,
    album_columns: list[str],
    plan: dict[str, Any],
) -> tuple[int, int, int]:
    existing = plan["existing_album_uids"]
    albums_to_insert = [
        row for row in plan["albums"] if str(row["album_uid"]) not in existing
    ]
    placeholders = ", ".join("?" for _ in album_columns)
    quoted_columns = ", ".join(f'"{name}"' for name in album_columns)
    insert_album = f"INSERT INTO albums ({quoted_columns}) VALUES ({placeholders})"

    membership_columns = [
        "photo_uid",
        "album_uid",
        "order",
        "hidden",
        "missing",
        "created_at",
        "updated_at",
    ]
    membership_placeholders = ", ".join("?" for _ in membership_columns)
    insert_membership = (
        'INSERT OR IGNORE INTO photos_albums '
        '(photo_uid, album_uid, "order", hidden, missing, created_at, updated_at) '
        f"VALUES ({membership_placeholders})"
    )

    current.execute("BEGIN IMMEDIATE")
    try:
        current.executemany(
            insert_album,
            [
                tuple(None if name == "created_by" else row[name] for name in album_columns)
                for row in albums_to_insert
            ],
        )
        before = current.total_changes
        current.executemany(
            insert_membership,
            [
                tuple(row[name] for name in membership_columns)
                for row in plan["mapped_memberships"]
            ],
        )
        inserted_memberships = current.total_changes - before
        before = current.total_changes
        current.executemany(
            """
            UPDATE photos
               SET photo_private = 1, updated_at = CURRENT_TIMESTAMP
             WHERE photo_uid = ?
               AND COALESCE(photo_private, 0) = 0
               AND deleted_at IS NULL
            """,
            [(photo_uid,) for photo_uid in plan["private_to_set"]],
        )
        restored_private = current.total_changes - before
        current.commit()
    except Exception:
        current.rollback()
        raise
    return len(albums_to_insert), inserted_memberships, restored_private


def main() -> None:
    args = parse_args()
    if args.allow_partial and not args.apply:
        fail("--allow-partial only has an effect together with --apply")

    state = service_state(args.service)
    if args.apply and state not in {"inactive", "failed"}:
        fail(
            f"{args.service} must be inactive before applying (current state: {state}); "
            f"stop it first: sudo systemctl stop {args.service}"
        )

    old = open_database(args.old_db, writable=False)
    current = open_database(args.current_db, writable=args.apply)
    try:
        check_database(old, "backup")
        check_database(current, "current")
        album_columns = require_compatible_schema(old, current)
        old_version = version(old)
        current_version = version(current)
        print(f"Backup PhotoPrism version:     {old_version}")
        print(f"Current PhotoPrism version:    {current_version}")
        if old_version != current_version:
            print("warning: versions differ, but the required table schemas are identical")

        plan = recovery_plan(old, current)
        print_plan(plan)
        skipped = (
            len(plan["memberships"])
            - len(plan["mapped_memberships"])
            + plan["missing_private"]
            + plan["ambiguous_private"]
        )
        if not args.apply:
            print("\nDry run only; no database changes were made.")
            return
        if not plan["mapped_memberships"] and not plan["mapped_private_uids"]:
            fail("no album memberships or private photos can be matched; refusing to apply")
        if skipped and not args.allow_partial:
            fail(
                f"{skipped} memberships cannot be mapped; inspect the report, then rerun "
                "with --apply --allow-partial if the partial recovery is acceptable"
            )

        backup_path = args.backup or default_backup_path(args.current_db)
        backup_database(current, args.current_db, backup_path)
        inserted_albums, inserted_memberships, restored_private = apply_recovery(
            current, album_columns, plan
        )
        check_database(current, "recovered current")
        print(f"Inserted albums:               {inserted_albums}")
        print(f"Inserted album memberships:    {inserted_memberships}")
        print(f"Restored private flags:        {restored_private}")
        print("Recovery committed. Start PhotoPrism and inspect Albums and the private view.")
    finally:
        current.close()
        old.close()


if __name__ == "__main__":
    main()
