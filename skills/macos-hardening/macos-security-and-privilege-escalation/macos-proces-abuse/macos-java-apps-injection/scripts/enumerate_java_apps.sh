#!/bin/bash
# macOS Java Application Enumerator
# Finds Java applications by searching for java. in Info.plist files

set -e

APP_DIR="${1:-/Applications}"

echo "=== macOS Java Application Enumerator ==="
echo "Searching in: $APP_DIR"
echo ""

# Search for Info.plist files containing java.
JAVA_APPS=$(find "$APP_DIR" -name 'Info.plist' -exec grep -l "java\." {} \; 2>/dev/null || true)

if [ -z "$JAVA_APPS" ]; then
    echo "No Java applications found in $APP_DIR"
    exit 0
fi

echo "Found Java applications:"
echo "------------------------"

for plist in $JAVA_APPS; do
    app_path=$(dirname "$plist")
    app_name=$(basename "$app_path")
    
    # Check if it's an .app bundle
    if [[ "$app_path" == *.app/Contents/Info.plist ]]; then
        app_bundle=$(dirname "$app_path")
        echo ""
        echo "Application: $app_bundle"
        echo "Info.plist: $plist"
        
        # Extract Java-related parameters
        echo "Java parameters found:"
        grep -i "java\." "$plist" 2>/dev/null | head -10 || echo "  (none found)"
        
        # Check for JavaApplicationStub
        stub_path="$app_bundle/Contents/MacOS/JavaApplicationStub"
        if [ -f "$stub_path" ]; then
            echo "JavaApplicationStub: $stub_path"
        fi
    fi
done

echo ""
echo "=== Complete ==="
