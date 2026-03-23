#!/bin/bash
# Find all macOS security extension kexts
# These are kexts that declare AppleSecurityExtension in their Info.plist

set -e

EXT_PATHS=(
    "/System/Library/Extensions"
    "/Library/Extensions"
    "/Library/Apple/System/Library/Extensions"
)

echo "Searching for security extension kexts..."
echo "=========================================="

for ext_path in "${EXT_PATHS[@]}"; do
    if [[ ! -d "$ext_path" ]]; then
        continue
    fi
    
    echo ""
    echo "Scanning: $ext_path"
    echo "------------------------------------------"
    
    while IFS= read -r -d '' plist; do
        if grep -q "AppleSecurityExtension" "$plist" 2>/dev/null; then
            kext_dir=$(dirname "$plist")
            kext_name=$(basename "$kext_dir")
            echo "  ✓ $kext_name"
            
            # Show the kext path
            echo "    Path: $kext_dir"
            
            # Try to get the bundle identifier
            if command -v plutil &> /dev/null; then
                bundle_id=$(plutil -extract CFBundleIdentifier raw "$plist" 2>/dev/null || echo "N/A")
                echo "    Bundle ID: $bundle_id"
            fi
            echo ""
        fi
    done < <(find "$ext_path" -name "Info.plist" -print0 2>/dev/null)
done

echo "=========================================="
echo "Done."
