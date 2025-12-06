#!/usr/bin/env python3
"""
quickMemoApp Backup Data Extractor

This script scans iPhone/iPad backups on Mac to find and extract
quickMemoApp data (memos and categories).

Usage:
    python3 extract_backup_data.py [--backup-path PATH] [--output OUTPUT_DIR]

Requirements:
    - Python 3.7+
    - plistlib (standard library)
    - sqlite3 (standard library)
"""

import os
import sys
import json
import plistlib
import sqlite3
import hashlib
import argparse
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, List, Any


# Default backup locations on Mac
DEFAULT_BACKUP_PATHS = [
    Path.home() / "Library" / "Application Support" / "MobileSync" / "Backup",
]

# App identifiers to search for
APP_IDENTIFIERS = [
    "yokAppDev.quickMemoApp",
    "group.yokAppDev.quickMemoApp",
]

# Domain prefixes to check
DOMAINS = [
    "AppDomain-yokAppDev.quickMemoApp",
    "AppDomainGroup-group.yokAppDev.quickMemoApp",
    "HomeDomain",
]


def find_backups(backup_base_path: Path) -> List[Dict[str, Any]]:
    """Find all iOS/iPadOS backups in the specified directory."""
    backups = []

    if not backup_base_path.exists():
        print(f"Backup directory not found: {backup_base_path}")
        return backups

    for backup_dir in backup_base_path.iterdir():
        if not backup_dir.is_dir():
            continue

        info_plist = backup_dir / "Info.plist"
        manifest_db = backup_dir / "Manifest.db"

        if info_plist.exists():
            try:
                with open(info_plist, 'rb') as f:
                    info = plistlib.load(f)

                backup_info = {
                    "path": backup_dir,
                    "device_name": info.get("Device Name", "Unknown"),
                    "product_name": info.get("Product Name", "Unknown"),
                    "last_backup": info.get("Last Backup Date", None),
                    "ios_version": info.get("Product Version", "Unknown"),
                    "has_manifest_db": manifest_db.exists(),
                    "is_encrypted": info.get("IsEncrypted", False),
                }
                backups.append(backup_info)
            except Exception as e:
                print(f"Error reading {info_plist}: {e}")

    return backups


def get_file_hash(domain: str, relative_path: str) -> str:
    """Calculate the SHA1 hash used as filename in iOS backups."""
    full_path = f"{domain}-{relative_path}"
    return hashlib.sha1(full_path.encode()).hexdigest()


def search_manifest_db(manifest_db_path: Path, search_terms: List[str]) -> List[Dict[str, str]]:
    """Search the Manifest.db for files matching the search terms."""
    results = []

    try:
        conn = sqlite3.connect(str(manifest_db_path))
        cursor = conn.cursor()

        # Build search query
        where_clauses = []
        params = []
        for term in search_terms:
            where_clauses.append("(domain LIKE ? OR relativePath LIKE ?)")
            params.extend([f"%{term}%", f"%{term}%"])

        query = f"""
            SELECT fileID, domain, relativePath, flags
            FROM Files
            WHERE {' OR '.join(where_clauses)}
        """

        cursor.execute(query, params)

        for row in cursor.fetchall():
            file_id, domain, relative_path, flags = row
            results.append({
                "file_id": file_id,
                "domain": domain,
                "relative_path": relative_path,
                "is_directory": flags == 2,
            })

        conn.close()
    except Exception as e:
        print(f"Error searching Manifest.db: {e}")

    return results


def read_plist_from_backup(backup_path: Path, file_id: str) -> Optional[Dict]:
    """Read a plist file from the backup using its file ID."""
    # Files are stored in subdirectories based on first 2 chars of hash
    file_path = backup_path / file_id[:2] / file_id

    if not file_path.exists():
        # Try the old flat structure
        file_path = backup_path / file_id

    if not file_path.exists():
        return None

    try:
        with open(file_path, 'rb') as f:
            return plistlib.load(f)
    except Exception as e:
        print(f"Error reading plist {file_path}: {e}")
        return None


def extract_quickmemo_data(plist_data: Dict) -> Dict[str, Any]:
    """Extract quickMemoApp data from a plist dictionary."""
    result = {
        "categories": [],
        "memos": [],
        "categories_backup": [],
        "archived_memos": [],
    }

    # Look for our keys
    keys_to_check = {
        "categories": "categories",
        "categories_backup": "categories_backup",
        "quick_memos": "memos",
        "archived_memos": "archived_memos",
    }

    for plist_key, result_key in keys_to_check.items():
        if plist_key in plist_data:
            data = plist_data[plist_key]
            if isinstance(data, bytes):
                try:
                    # Data is JSON encoded
                    decoded = json.loads(data.decode('utf-8'))
                    result[result_key] = decoded
                except:
                    try:
                        # Try as plist
                        decoded = plistlib.loads(data)
                        result[result_key] = decoded
                    except:
                        pass
            elif isinstance(data, list):
                result[result_key] = data

    return result


def print_backup_summary(backup_info: Dict[str, Any]):
    """Print a summary of a backup."""
    print(f"\n{'='*60}")
    print(f"Device: {backup_info['device_name']}")
    print(f"Product: {backup_info['product_name']}")
    print(f"iOS Version: {backup_info['ios_version']}")
    if backup_info['last_backup']:
        print(f"Last Backup: {backup_info['last_backup']}")
    print(f"Encrypted: {'Yes' if backup_info['is_encrypted'] else 'No'}")
    print(f"Path: {backup_info['path']}")
    print(f"{'='*60}")


def print_data_summary(data: Dict[str, Any]):
    """Print a summary of extracted data."""
    print(f"\nExtracted Data:")
    print(f"  Categories: {len(data['categories'])}")
    print(f"  Categories (backup): {len(data['categories_backup'])}")
    print(f"  Memos: {len(data['memos'])}")
    print(f"  Archived Memos: {len(data['archived_memos'])}")

    if data['categories']:
        print(f"\n  Category Names:")
        for cat in data['categories'][:10]:
            if isinstance(cat, dict):
                print(f"    - {cat.get('name', 'Unknown')}")

    if data['memos']:
        print(f"\n  Recent Memos (first 5):")
        for memo in data['memos'][:5]:
            if isinstance(memo, dict):
                content = memo.get('content', '')[:50]
                print(f"    - {content}...")


def save_extracted_data(data: Dict[str, Any], output_path: Path, backup_name: str):
    """Save extracted data to JSON files."""
    output_dir = output_path / f"quickmemo_recovery_{backup_name}"
    output_dir.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    for key, items in data.items():
        if items:
            filename = output_dir / f"{key}_{timestamp}.json"
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(items, f, ensure_ascii=False, indent=2, default=str)
            print(f"  Saved: {filename}")


def main():
    parser = argparse.ArgumentParser(
        description="Extract quickMemoApp data from iPhone/iPad backups"
    )
    parser.add_argument(
        "--backup-path",
        type=Path,
        help="Path to backup directory (default: ~/Library/Application Support/MobileSync/Backup)"
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path.home() / "Desktop",
        help="Output directory for extracted data (default: ~/Desktop)"
    )
    parser.add_argument(
        "--list-only",
        action="store_true",
        help="Only list available backups, don't extract"
    )

    args = parser.parse_args()

    # Determine backup path
    if args.backup_path:
        backup_paths = [args.backup_path]
    else:
        backup_paths = DEFAULT_BACKUP_PATHS

    print("quickMemoApp Backup Data Extractor")
    print("="*40)

    all_backups = []
    for backup_path in backup_paths:
        print(f"\nSearching in: {backup_path}")
        backups = find_backups(backup_path)
        all_backups.extend(backups)

    if not all_backups:
        print("\nNo backups found!")
        print("\nPossible reasons:")
        print("  1. No iPhone/iPad backups exist on this Mac")
        print("  2. Backups are stored in a different location")
        print("  3. Backups are encrypted (this tool cannot read encrypted backups)")
        return

    print(f"\nFound {len(all_backups)} backup(s)")

    for i, backup in enumerate(all_backups):
        print(f"\n[{i+1}] {backup['device_name']} ({backup['product_name']})")
        if backup['last_backup']:
            print(f"    Last backup: {backup['last_backup']}")
        if backup['is_encrypted']:
            print(f"    ⚠️  Encrypted - cannot extract data")

    if args.list_only:
        return

    # Process each backup
    for backup in all_backups:
        print_backup_summary(backup)

        if backup['is_encrypted']:
            print("⚠️  Skipping encrypted backup")
            continue

        if not backup['has_manifest_db']:
            print("⚠️  No Manifest.db found - cannot search files")
            continue

        manifest_db = backup['path'] / "Manifest.db"

        # Search for quickMemoApp files
        print("\nSearching for quickMemoApp data...")
        files = search_manifest_db(manifest_db, APP_IDENTIFIERS)

        if not files:
            print("No quickMemoApp files found in this backup")
            continue

        print(f"Found {len(files)} related file(s)")

        # Extract data from found files
        all_data = {
            "categories": [],
            "memos": [],
            "categories_backup": [],
            "archived_memos": [],
        }

        for file_info in files:
            if file_info['is_directory']:
                continue

            if file_info['relative_path'].endswith('.plist'):
                print(f"  Reading: {file_info['relative_path']}")
                plist_data = read_plist_from_backup(backup['path'], file_info['file_id'])

                if plist_data:
                    extracted = extract_quickmemo_data(plist_data)

                    # Merge data
                    for key in all_data:
                        if extracted[key]:
                            all_data[key].extend(extracted[key])

        # Check if we found anything
        total_items = sum(len(v) for v in all_data.values())

        if total_items > 0:
            print_data_summary(all_data)

            # Save extracted data
            print(f"\nSaving extracted data to: {args.output}")
            backup_name = backup['device_name'].replace(' ', '_').replace('/', '_')
            save_extracted_data(all_data, args.output, backup_name)
        else:
            print("No quickMemoApp data found in this backup")

    print("\n" + "="*40)
    print("Extraction complete!")
    print("\nNext steps:")
    print("1. Check the extracted JSON files on your Desktop")
    print("2. If data was found, you can import it back into the app")
    print("3. For encrypted backups, you'll need to use other tools first")


if __name__ == "__main__":
    main()
