#!/bin/bash
# vmoptions File Finder
# Locates vmoptions files for Java applications on macOS

set -e

APP_NAME="${1:-}"

echo "=== vmoptions File Finder ==="

if [ -n "$APP_NAME" ]; then
    echo "Searching for: $APP_NAME"
    
    # Common vmoptions locations for specific app
    CHECK_PATHS=(
        "/Applications/$APP_NAME.app/Contents/bin/$APP_NAME.vmoptions"
        "/Applications/$APP_NAME.app/Contents/bin/studio.vmoptions"
        "/Applications/$APP_NAME.app.vmoptions"
        "~/Library/Application Support/Google/$APP_NAME/*.vmoptions"
        "~/Library/Application Support/$APP_NAME/*.vmoptions"
    )
    
    for path in "${CHECK_PATHS[@]}"; do
        # Expand ~ and check if file exists
        expanded_path=$(eval echo "$path")
        if [ -f "$expanded_path" ]; then
            echo ""
            echo "Found: $expanded_path"
            echo "Contents:"
            cat "$expanded_path" 2>/dev/null | head -20
            echo "..."
        fi
    done
else
    echo "Searching all common vmoptions locations..."
    echo ""
    
    # Search common locations
    COMMON_PATTERNS=(
        "/Applications/*.app/Contents/bin/*.vmoptions"
        "/Applications/*.app.vmoptions"
        "~/Library/Application Support/**/*.vmoptions"
    )
    
    for pattern in "${COMMON_PATTERNS[@]}"; do
        files=$(find $(eval echo "$pattern") -name "*.vmoptions" 2>/dev/null || true)
        if [ -n "$files" ]; then
            echo "Pattern: $pattern"
            echo "$files"
            echo ""
        fi
    done
fi

echo "=== Complete ==="
