#!/bin/bash
# Extract browser history from Firefox, Chrome, Edge, or Safari
# Usage: ./extract-browser-history.sh <browser> <profile_path> [limit]
#
# Browsers: firefox, chrome, edge, safari
# Default limit: 100

set -e

BROWSER="$1"
PROFILE_PATH="$2"
LIMIT="${3:-100}"

if [ -z "$BROWSER" ] || [ -z "$PROFILE_PATH" ]; then
    echo "Usage: $0 <browser> <profile_path> [limit]"
    echo "Browsers: firefox, chrome, edge, safari"
    exit 1
fi

case "$BROWSER" in
    firefox)
        DB_FILE="$PROFILE_PATH/places.sqlite"
        if [ ! -f "$DB_FILE" ]; then
            echo "Error: places.sqlite not found at $PROFILE_PATH"
            exit 1
        fi
        echo "Extracting Firefox history from $DB_FILE"
        sqlite3 "$DB_FILE" "SELECT datetime(visit_date/1000000000, 'unixepoch') as timestamp, url FROM moz_historyvisits h JOIN moz_places p ON h.place_id = p.id ORDER BY visit_date DESC LIMIT $LIMIT;"
        ;;
    chrome)
        DB_FILE="$PROFILE_PATH/History"
        if [ ! -f "$DB_FILE" ]; then
            echo "Error: History not found at $PROFILE_PATH"
            exit 1
        fi
        echo "Extracting Chrome history from $DB_FILE"
        sqlite3 "$DB_FILE" "SELECT datetime(last_visit_time/1000000-11644473600, 'unixepoch') as timestamp, url, title FROM urls ORDER BY last_visit_time DESC LIMIT $LIMIT;"
        ;;
    safari)
        DB_FILE="$PROFILE_PATH/History.db"
        if [ ! -f "$DB_FILE" ]; then
            echo "Error: History.db not found at $PROFILE_PATH"
            exit 1
        fi
        echo "Extracting Safari history from $DB_FILE"
        sqlite3 "$DB_FILE" "SELECT datetime(visit_time+978307200, 'unixepoch') as timestamp, url FROM history_visits v JOIN history_items i ON v.history_item = i.id ORDER BY visit_time DESC LIMIT $LIMIT;"
        ;;
    edge)
        echo "Edge uses ESE database format. Use ESEDatabaseView or IECacheView for analysis."
        echo "WebCache location: C:\\Users\\XX\\AppData\\Local\\Microsoft\\Windows\\WebCache\\WebCacheV01.dat"
        exit 0
        ;;
    *)
        echo "Unknown browser: $BROWSER"
        echo "Supported: firefox, chrome, edge, safari"
        exit 1
        ;;
esac
