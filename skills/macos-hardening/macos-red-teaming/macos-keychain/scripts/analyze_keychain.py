#!/usr/bin/env python3
"""
Analyze macOS Keychain entries and their ACLs.
This script helps identify entries that can be accessed without prompts.
"""

import subprocess
import json
import sys

def run_command(cmd):
    """Run a shell command and return output."""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout, result.stderr, result.returncode
    except Exception as e:
        return "", str(e), 1

def list_keychains():
    """List all available keychains."""
    print("=== Available Keychains ===")
    stdout, stderr, code = run_command("security list-keychains")
    if code == 0:
        print(stdout)
    else:
        print(f"Error: {stderr}")

def find_generic_password(account):
    """Find generic password for an account."""
    print(f"\n=== Searching for '{account}' ===")
    stdout, stderr, code = run_command(f'security find-generic-password -a "{account}" -g')
    if code == 0:
        print(stdout)
    else:
        print(f"Error: {stderr}")

def dump_keychain(path=None):
    """Dump a keychain file."""
    keychain = path or "~/Library/Keychains/login.keychain-db"
    print(f"\n=== Dumping {keychain} ===")
    print("Warning: This may generate authentication prompts!")
    stdout, stderr, code = run_command(f'security dump-keychain "{keychain}"')
    if code == 0:
        print(stdout[:2000] + "..." if len(stdout) > 2000 else stdout)
    else:
        print(f"Error: {stderr}")

def main():
    if len(sys.argv) < 2:
        print("macOS Keychain Analyzer")
        print("Usage: python analyze_keychain.py <command> [args]")
        print("\nCommands:")
        print("  list              - List all keychains")
        print("  find <account>    - Find password for account")
        print("  dump [path]       - Dump keychain (default: login.keychain-db)")
        print("\nExamples:")
        print("  python analyze_keychain.py list")
        print("  python analyze_keychain.py find Slack")
        print("  python analyze_keychain.py dump")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "list":
        list_keychains()
    elif command == "find" and len(sys.argv) > 2:
        find_generic_password(sys.argv[2])
    elif command == "dump":
        dump_keychain(sys.argv[2] if len(sys.argv) > 2 else None)
    else:
        print(f"Unknown command: {command}")
        print("Run without arguments for usage.")
        sys.exit(1)

if __name__ == "__main__":
    main()
