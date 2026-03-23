#!/bin/bash
# Dump a specific keychain file
# Usage: ./dump_keychain.sh [keychain_path]
# Default: ~/Library/Keychains/login.keychain-db

KEYCHAIN_PATH="${1:-~/Library/Keychains/login.keychain-db}"

echo "Dumping keychain: $KEYCHAIN_PATH"
security dump-keychain "$KEYCHAIN_PATH"
