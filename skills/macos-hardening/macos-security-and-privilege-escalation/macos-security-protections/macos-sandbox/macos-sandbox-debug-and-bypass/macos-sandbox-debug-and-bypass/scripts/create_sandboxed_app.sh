#!/bin/bash
# Create a test sandboxed macOS application
# Usage: ./create_sandboxed_app.sh [app_name]

APP_NAME="${1:-sandbox_test}"
CERT_NAME="${2:-"-"}"

echo "Creating sandboxed test application: $APP_NAME"

# Create source file
cat > ${APP_NAME}.c << 'EOF'
#include <stdlib.h>
#include <stdio.h>

int main() {
    printf("Testing sandbox access...\n");
    system("cat ~/Desktop/del.txt");
    return 0;
}
EOF

# Create entitlements
cat > entitlements.xml << 'EOF'
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>com.apple.security.app-sandbox</key>
<true/>
</dict>
</plist>
EOF

# Create Info.plist
cat > Info.plist << EOF
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.hacktricks.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
</dict>
</plist>
EOF

# Compile
echo "Compiling..."
gcc -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Info.plist ${APP_NAME}.c -o ${APP_NAME}

if [ $? -eq 0 ]; then
    echo "Compilation successful"
    
    # Sign with entitlements
    echo "Signing with entitlements..."
    codesign -s "$CERT_NAME" --entitlements entitlements.xml ${APP_NAME}
    
    if [ $? -eq 0 ]; then
        echo "Signing successful"
        echo ""
        echo "Test file setup:"
        echo "  echo \"Sandbox Bypassed\" > ~/Desktop/del.txt"
        echo ""
        echo "Run with lldb for debugging:"
        echo "  lldb ./${APP_NAME}"
    else
        echo "Warning: Signing failed (may need valid certificate)"
    fi
else
    echo "Compilation failed"
    exit 1
fi

echo ""
echo "Files created:"
echo "  - ${APP_NAME}.c (source)"
echo "  - entitlements.xml (sandbox entitlements)"
echo "  - Info.plist (bundle info)"
echo "  - ${APP_NAME} (binary)"
