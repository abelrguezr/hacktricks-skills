#!/bin/bash
# Create a test macOS installer package for security research
# WARNING: Only use for authorized security research and testing

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <package_name> [output_dir]"
    echo "Example: $0 myapp /tmp/test_packages/"
    echo ""
    echo "This creates a benign test package for security research."
    echo "DO NOT use this to create malicious packages."
    exit 1
fi

PKG_NAME="$1"
OUTPUT_DIR="${2:-/tmp/test_packages/}"
PKG_ROOT=$(mktemp -d)

echo "Creating test package: $PKG_NAME"
echo "Working directory: $PKG_ROOT"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Create package structure
mkdir -p "$PKG_ROOT/root/Applications/$PKG_NAME.app/Contents/MacOS"
mkdir -p "$PKG_ROOT/scripts"

# Create a simple test application
cat > "$PKG_ROOT/root/Applications/$PKG_NAME.app/Contents/MacOS/$PKG_NAME" << 'EOF'
#!/bin/bash
echo "Test application: $PKG_NAME"
echo "This is a benign test package for security research."
exit 0
EOF
chmod +x "$PKG_ROOT/root/Applications/$PKG_NAME.app/Contents/MacOS/$PKG_NAME"

# Create benign preinstall script
cat > "$PKG_ROOT/scripts/preinstall" << 'EOF'
#!/bin/bash
echo "Running preinstall script for test package"
echo "Installation time: $(date)"
exit 0
EOF
chmod +x "$PKG_ROOT/scripts/preinstall"

# Create benign postinstall script
cat > "$PKG_ROOT/scripts/postinstall" << 'EOF'
#!/bin/bash
echo "Running postinstall script for test package"
echo "Installation completed at: $(date)"
exit 0
EOF
chmod +x "$PKG_ROOT/scripts/postinstall"

# Create Distribution XML (benign, no JavaScript)
cat > "$PKG_ROOT/dist.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>$PKG_NAME Test Installer</title>
    <description>Benign test package for security research</description>
    <options customize="never" require-scripts="true"/>
    <choices-outline>
        <line choice="default">
            <line choice="$PKG_NAME"/>
        </line>
    </choices-outline>
    <choice id="$PKG_NAME" title="$PKG_NAME">
        <pkg-ref id="com.test.$PKG_NAME"/>
    </choice>
    <pkg-ref id="com.test.$PKG_NAME" installKBytes="100" auth="root">$PKG_NAME.pkg</pkg-ref>
</installer-gui-script>
EOF

# Create the base package
echo "Building base package..."
cd "$PKG_ROOT"
pkgbuild --root root --scripts scripts --identifier "com.test.$PKG_NAME" --version "1.0" "$PKG_NAME.pkg"

# Create final package with distribution
echo "Building final package..."
productbuild --distribution dist.xml --package-path "$PKG_NAME.pkg" "$OUTPUT_DIR/${PKG_NAME}-installer.pkg"

# Cleanup
cd /
rm -rf "$PKG_ROOT"

echo ""
echo "✓ Test package created: $OUTPUT_DIR/${PKG_NAME}-installer.pkg"
echo ""
echo "To analyze this package:"
echo "  ./scripts/extract_pkg.sh $OUTPUT_DIR/${PKG_NAME}-installer.pkg /tmp/analysis/"
echo "  ./scripts/analyze_pkg.sh /tmp/analysis/"
echo ""
echo "Note: This is a benign test package for security research only."
