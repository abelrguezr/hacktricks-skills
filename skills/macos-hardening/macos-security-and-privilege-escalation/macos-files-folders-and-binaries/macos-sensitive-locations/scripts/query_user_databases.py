#!/usr/bin/env python3
"""
Query macOS user databases for forensic analysis
Usage: python3 query_user_databases.py [--messages|--notes|--notifications] [--user <username>]
"""

import sqlite3
import sys
import os
from pathlib import Path

def get_user_home(username=None):
    """Get user home directory"""
    if username:
        return Path(f"/Users/{username}")
    return Path.home()

def query_messages_db(user_home):
    """Query Messages database"""
    db_path = user_home / "Library/Messages/chat.db"
    
    if not db_path.exists():
        print(f"Messages database not found: {db_path}", file=sys.stderr)
        return
    
    print(f"\n=== Messages Database: {db_path} ===")
    
    try:
        conn = sqlite3.connect(str(db_path))
        cursor = conn.cursor()
        
        # List tables
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = cursor.fetchall()
        print(f"\nTables: {[t[0] for t in tables]}")
        
        # Recent messages
        print("\n--- Recent Messages (last 10) ---")
        cursor.execute("""
            SELECT message, guid, date, handle_id, is_from_me 
            FROM message 
            ORDER BY date DESC 
            LIMIT 10
        """)
        for row in cursor.fetchall():
            print(f"  {row}")
        
        # Attachments
        print("\n--- Attachments (last 10) ---")
        cursor.execute("""
            SELECT filename, transfer_name, total_bytes, is_download_complete 
            FROM attachment 
            ORDER BY date_added DESC 
            LIMIT 10
        """)
        for row in cursor.fetchall():
            print(f"  {row}")
        
        # Deleted messages
        print("\n--- Deleted Messages (last 10) ---")
        cursor.execute("""
            SELECT message, guid, date, handle_id 
            FROM deleted_messages 
            ORDER BY date DESC 
            LIMIT 10
        """)
        for row in cursor.fetchall():
            print(f"  {row}")
        
        conn.close()
        
    except sqlite3.Error as e:
        print(f"SQLite error: {e}", file=sys.stderr)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)

def query_notes_db(user_home):
    """Query Notes database"""
    db_path = user_home / "Library/Group Containers/group.com.apple.notes/NoteStore.sqlite"
    
    if not db_path.exists():
        print(f"Notes database not found: {db_path}", file=sys.stderr)
        return
    
    print(f"\n=== Notes Database: {db_path} ===")
    
    try:
        conn = sqlite3.connect(str(db_path))
        cursor = conn.cursor()
        
        # List tables
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = cursor.fetchall()
        print(f"\nTables: {[t[0] for t in tables]}")
        
        # Note count
        cursor.execute("SELECT COUNT(*) FROM ZICNOTEDATA;")
        count = cursor.fetchone()[0]
        print(f"\nTotal notes: {count}")
        
        # Recent notes (metadata only)
        print("\n--- Recent Notes (last 10) ---")
        cursor.execute("""
            SELECT Z_PK, ZCREATEDATE, ZMODIFICATIONDATE 
            FROM ZICNOTEDATA 
            ORDER BY ZMODIFICATIONDATE DESC 
            LIMIT 10
        """)
        for row in cursor.fetchall():
            print(f"  ID: {row[0]}, Created: {row[1]}, Modified: {row[2]}")
        
        conn.close()
        
    except sqlite3.Error as e:
        print(f"SQLite error: {e}", file=sys.stderr)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)

def query_notifications_db(user_home):
    """Query Notifications database"""
    # Try multiple possible locations
    possible_paths = [
        user_home / "Library/Preferences/com.apple.notificationcenter/db2/db",
        Path(f"/var/folders/{os.getuid()}/0/com.apple.notificationcenter/db2/db"),
    ]
    
    db_path = None
    for path in possible_paths:
        if path.exists():
            db_path = path
            break
    
    if not db_path:
        print("Notifications database not found in expected locations", file=sys.stderr)
        print("\nTry finding it manually:")
        print("  find ~/Library -name 'db' -path '*notificationcenter*' 2>/dev/null")
        return
    
    print(f"\n=== Notifications Database: {db_path} ===")
    
    try:
        conn = sqlite3.connect(str(db_path))
        cursor = conn.cursor()
        
        # List tables
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = cursor.fetchall()
        print(f"\nTables: {[t[0] for t in tables]}")
        
        # Try to get recent notifications
        for table in tables:
            table_name = table[0]
            try:
                cursor.execute(f"SELECT COUNT(*) FROM {table_name};")
                count = cursor.fetchone()[0]
                print(f"\n--- {table_name} ({count} rows) ---")
                
                cursor.execute(f"SELECT * FROM {table_name} LIMIT 5;")
                for row in cursor.fetchall():
                    print(f"  {row}")
            except sqlite3.Error:
                continue
        
        conn.close()
        
    except sqlite3.Error as e:
        print(f"SQLite error: {e}", file=sys.stderr)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)

def main():
    # Parse arguments
    query_type = "all"
    username = None
    
    i = 1
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg in ["--messages", "--notes", "--notifications"]:
            query_type = arg[2:]  # Remove --
        elif arg == "--user" and i + 1 < len(sys.argv):
            username = sys.argv[i + 1]
            i += 1
        i += 1
    
    user_home = get_user_home(username)
    
    print(f"Analyzing user databases for: {user_home}")
    print("=" * 60)
    
    if query_type == "all" or query_type == "messages":
        query_messages_db(user_home)
    
    if query_type == "all" or query_type == "notes":
        query_notes_db(user_home)
    
    if query_type == "all" or query_type == "notifications":
        query_notifications_db(user_home)

if __name__ == "__main__":
    main()
