#!/usr/bin/env python3
"""
Query Google Drive SQLite databases for forensic analysis

Usage:
    python query_gdrive_db.py <database-path> <table-name> [query]

Common tables:
    - cloud_graph_entry: File names, modified time, size, MD5 checksum
    - sync_config: Account email, shared folder paths, version info

Examples:
    python query_gdrive_db.py Cloud_graph.db cloud_graph_entry
    python query_gdrive_db.py Sync_config.db sync_config "SELECT * FROM sync_config"
"""

import sqlite3
import sys
import argparse
from pathlib import Path
import json


def list_tables(db_path: str) -> list[str]:
    """
    List all tables in a SQLite database
    
    Args:
        db_path: Path to SQLite database
        
    Returns:
        List of table names
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [row[0] for row in cursor.fetchall()]
    
    conn.close()
    return tables


def query_table(db_path: str, table_name: str, query: str = None) -> list[dict]:
    """
    Query a table in a SQLite database
    
    Args:
        db_path: Path to SQLite database
        table_name: Name of table to query
        query: Optional custom SQL query (defaults to SELECT *)
        
    Returns:
        List of dictionaries representing rows
    """
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    if query:
        sql = query
    else:
        sql = f"SELECT * FROM {table_name}"
    
    try:
        cursor.execute(sql)
        columns = [description[0] for description in cursor.description]
        rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
    except sqlite3.OperationalError as e:
        print(f"Error executing query: {e}", file=sys.stderr)
        conn.close()
        sys.exit(1)
    
    conn.close()
    return rows


def show_table_schema(db_path: str, table_name: str) -> None:
    """
    Show the schema of a table
    
    Args:
        db_path: Path to SQLite database
        table_name: Name of table
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute(f"PRAGMA table_info({table_name})")
    columns = cursor.fetchall()
    
    print(f"\nTable: {table_name}")
    print("-" * 60)
    print(f"{'Column':<25} {'Type':<15} {'Not Null':<10} {'Default'}")
    print("-" * 60)
    
    for col in columns:
        cid, name, col_type, not_null, default, pk = col
        print(f"{name:<25} {col_type:<15} {str(not_null):<10} {default}")
    
    conn.close()


def export_to_json(rows: list[dict], output_path: str) -> None:
    """
    Export query results to JSON file
    
    Args:
        rows: Query results as list of dictionaries
        output_path: Path to output JSON file
    """
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(rows, f, indent=2, default=str)
    print(f"Exported {len(rows)} rows to {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description='Query Google Drive SQLite databases'
    )
    parser.add_argument(
        'db_path',
        help='Path to SQLite database (e.g., Cloud_graph.db or Sync_config.db)'
    )
    parser.add_argument(
        'table_name',
        nargs='?',
        help='Table name to query (optional, lists tables if not provided)'
    )
    parser.add_argument(
        '--query', '-q',
        help='Custom SQL query (defaults to SELECT *)'
    )
    parser.add_argument(
        '--schema', '-s',
        action='store_true',
        help='Show table schema instead of data'
    )
    parser.add_argument(
        '--json', '-j',
        metavar='OUTPUT',
        help='Export results to JSON file'
    )
    parser.add_argument(
        '--limit', '-l',
        type=int,
        default=100,
        help='Limit number of rows to display (default: 100)'
    )
    
    args = parser.parse_args()
    
    db_path = Path(args.db_path)
    
    if not db_path.exists():
        print(f"Error: Database not found: {args.db_path}", file=sys.stderr)
        sys.exit(1)
    
    # List tables if no table specified
    if not args.table_name:
        tables = list_tables(str(db_path))
        print(f"Tables in {db_path.name}:")
        for table in tables:
            print(f"  - {table}")
        return
    
    # Show schema if requested
    if args.schema:
        show_table_schema(str(db_path), args.table_name)
        return
    
    # Query the table
    rows = query_table(str(db_path), args.table_name, args.query)
    
    if not rows:
        print(f"No data found in table '{args.table_name}'")
        return
    
    # Display results
    display_rows = rows[:args.limit]
    
    if display_rows:
        columns = list(display_rows[0].keys())
        
        # Print header
        print(f"\nTable: {args.table_name} ({len(rows)} total rows, showing {len(display_rows)})")
        print("-" * 80)
        print(" | ".join(columns[:5]))  # Show first 5 columns
        print("-" * 80)
        
        # Print rows
        for row in display_rows:
            values = [str(row.get(col, ''))[:20] for col in columns[:5]]
            print(" | ".join(values))
        
        if len(rows) > args.limit:
            print(f"\n... and {len(rows) - args.limit} more rows")
    
    # Export to JSON if requested
    if args.json:
        export_to_json(rows, args.json)


if __name__ == '__main__':
    main()
