#!/bin/bash
# Create a sandboxed macOS application for security testing
# Usage: ./create-sandboxed-app.sh [--with-downloads]

set -e

APP_NAME="SandboxedShellApp"
WITH_DOWNLOADS=false

# Parse arguments
if [[ "$1" == "--with-downloads" ]]; then
    WITH_DOWNLOADS=true
fi

echo "Creating sandboxed macOS application: $APP_NAME"

# Create directory structure
mkdir -p "${APP_NAME}.app/Contents/MacOS"

# Create the main.m source file
cat > main.m << 'EOF'
#include <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        while (true) {
            char input[512];

            printf("Enter command to run (or 'exit' to quit): ");
            if (fgets(input, sizeof(input), stdin) == NULL) {
                break;
            }

            // Remove newline character
            size_t len = strlen(input);
            if (len > 0 && input[len - 1] == '\n') {
                input[len - 1] = '\0';
            }

            if (strcmp(input, "exit") == 0) {
                break;
            }

            system(input);
        }
    }
    return 0;
}
EOF

echo "Compiling application..."
clang -framework Foundation -o "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" main.m

# Create Info.plist
cat > "${APP_NAME}.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
</dict>
</plist>
EOF

# Create entitlements.plist
if [[ "$WITH_DOWNLOADS" == true ]]; then
    echo "Creating entitlements with downloads folder access..."
    cat > entitlements.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
</dict>
</plist>
EOF
else
    echo "Creating default sandbox entitlements..."
    cat > entitlements.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
</dict>
</plist>
EOF
fi

echo ""
echo "Application bundle created: ${APP_NAME}.app"
echo "Entitlements file created: entitlements.plist"
echo ""
echo "Next steps:"
echo "1. Sign the app: codesign --entitlements entitlements.plist -s \"Your Identity\" ${APP_NAME}.app"
echo "2. Run the app: ./${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
echo ""
echo "To find available signing identities:"
echo "  security find-identity -v -p codesigning"
