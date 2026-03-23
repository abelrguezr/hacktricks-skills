#!/usr/bin/env python3
"""
macOS TCC Database Analyzer
Analyzes TCC database structure and contents for security research.

Usage:
    python3 tcc-database-analyzer.py [path-to-tcc.db]
    python3 tcc-database-analyzer.py --help

Note: Requires read access to TCC database (may need elevated permissions)
"""

import sqlite3
import sys
import os
from pathlib import Path
from datetime import datetime

# Default TCC database path
DEFAULT_TCC_DB = os.path.expanduser("~/Library/Application Support/com.apple.TCC/TCC.db")

def analyze_tcc_database(db_path):
    """Analyze TCC database and print findings."""
    
    db_path = os.path.expanduser(db_path)
    
    if not os.path.exists(db_path):
        print(f"Error: TCC database not found at {db_path}")
        print(f"\nExpected location: {DEFAULT_TCC_DB}")
        return
    
    print(f"=== TCC Database Analysis ===")
    print(f"Database: {db_path}")
    print(f"Size: {os.path.getsize(db_path):,} bytes")
    print(f"Modified: {datetime.fromtimestamp(os.path.getmtime(db_path))}")
    print()
    
    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
        cursor = conn.cursor()
        
        # Get table info
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = cursor.fetchall()
        
        print("=== Tables ===")
        for (table,) in tables:
            print(f"  - {table}")
        print()
        
        # Analyze access table if it exists
        if 'access' in [t[0] for t in tables]:
            print("=== Access Records ===")
            
            # Get column info
            cursor.execute("PRAGMA table_info(access);")
            columns = [row[1] for row in cursor.fetchall()]
            print(f"Columns: {', '.join(columns)}")
            print()
            
            # Count records by service
            cursor.execute("SELECT service, COUNT(*) FROM access GROUP BY service ORDER BY COUNT(*) DESC;")
            service_counts = cursor.fetchall()
            
            print("Records by Service:")
            for service, count in service_counts:
                print(f"  {service}: {count}")
            print()
            
            # Count allowed vs denied
            cursor.execute("SELECT allowed, COUNT(*) FROM access GROUP BY allowed;")
            allowed_counts = cursor.fetchall()
            
            print("Permission Status:")
            for allowed, count in allowed_counts:
                status = "Allowed" if allowed else "Denied"
                print(f"  {status}: {count}")
            print()
            
            # Show recent entries
            print("=== Recent Access Entries ===")
            cursor.execute("""
                SELECT service, client, allowed, last_used 
                FROM access 
                ORDER BY last_used DESC 
                LIMIT 10;
            """)
            
            for row in cursor.fetchall():
                service, client, allowed, last_used = row
                status = "✓" if allowed else "✗"
                print(f"  {status} {client[:50]:<50} | {service}")
            print()
            
            # Check for Full Disk Access
            print("=== Full Disk Access Apps ===")
            cursor.execute("""
                SELECT client FROM access 
                WHERE service IN ('kTCCServiceSystemPolicyAllFiles', 'kTCCServiceSystemPolicyFullDiskAccess') 
                AND allowed = 1;
            """)
            fda_apps = cursor.fetchall()
            
            if fda_apps:
                for (client,) in fda_apps:
                    print(f"  - {client}")
            else:
                print("  None found")
            print()
        
        conn.close()
        
    except sqlite3.OperationalError as e:
        print(f"Error reading database: {e}")
        print("\nNote: TCC database may be protected or require elevated permissions.")
    except Exception as e:
        print(f"Unexpected error: {e}")

def main():
    if len(sys.argv) > 1:
        db_path = sys.argv[1]
    else:
        db_path = DEFAULT_TCC_DB
    
    analyze_tcc_database(db_path)

if __name__ == "__main__":
    main()
