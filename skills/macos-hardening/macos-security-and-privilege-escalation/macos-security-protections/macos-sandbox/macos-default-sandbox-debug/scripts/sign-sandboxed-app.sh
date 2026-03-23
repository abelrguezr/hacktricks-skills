#!/bin/bash
# Sign a sandboxed macOS application
# Usage: ./sign-sandboxed-app.sh <app-bundle> [identity]

set -e

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <app-bundle> [identity]"
    echo ""
    echo "Example:"
    echo "  $0 SandboxedShellApp.app"
    echo "  $0 SandboxedShellApp.app \"Apple Development: John Doe\""
    echo ""
    echo "To find available identities:"
    echo "  security find-identity -v -p codesigning"
    exit 1
fi

APP_BUNDLE="$1"
IDENTITY="${2:-}"

# Check if app bundle exists
if [[ ! -d "${APP_BUNDLE}" ]]; then
    echo "Error: App bundle not found: $APP_BUNDLE"
    exit 1
fi

# Check if entitlements.plist exists
if [[ ! -f "entitlements.plist" ]]; then
    echo "Error: entitlements.plist not found in current directory"
    echo ""
    echo "Create entitlements.plist with sandbox configuration first."
    exit 1
fi

# List available identities if none specified
if [[ -z "$IDENTITY" ]]; then
    echo "Available signing identities:"
    security find-identity -v -p codesigning
    echo ""
    echo "Please specify an identity:"
    echo "  $0 $APP_BUNDLE \"Your Identity Name\""
    exit 1
fi

echo "Signing $APP_BUNDLE with identity: $IDENTITY"
echo "Using entitlements: entitlements.plist"

codesign --entitlements entitlements.plist -s "$IDENTITY" "$APP_BUNDLE"

echo ""
echo "App signed successfully!"
echo ""
echo "To run the app:"
echo "  ./${APP_BUNDLE}/Contents/MacOS/$(basename ${APP_BUNDLE%.*})"
echo ""
echo "To remove signature (if needed):"
echo "  codesign --remove-signature $APP_BUNDLE"
