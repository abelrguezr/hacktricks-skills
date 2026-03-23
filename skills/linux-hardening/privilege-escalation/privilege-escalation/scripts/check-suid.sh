#!/bin/bash
# Check for SUID/SGID binary vulnerabilities

echo "=== SUID/SGID Binary Check ==="
echo ""

# Find SUID binaries
echo "SUID binaries found:"
SUID_BINARIES=$(find / -perm -4000 -type f 2>/dev/null)
echo "$SUID_BINARIES" | while read binary; do
  if [ -n "$binary" ]; then
    echo "  $binary"
    
    # Check if writable
    if [ -w "$binary" ]; then
      echo "    [!] Writable - HIGH RISK"
    fi
    
    # Check for custom library paths
    if command -v readelf &> /dev/null; then
      RPATH=$(readelf -d "$binary" 2>/dev/null | grep -iE 'RPATH|RUNPATH')
      if [ -n "$RPATH" ]; then
        echo "    [!] Custom library path: $RPATH"
      fi
    fi
    
    # Check what libraries it loads
    if command -v ldd &> /dev/null; then
      LIBS=$(ldd "$binary" 2>/dev/null | grep -v "not found" | head -5)
      if [ -n "$LIBS" ]; then
        echo "    Libraries:"
        echo "$LIBS" | sed 's/^/      /'
      fi
    fi
  fi
done

echo ""
echo "SGID binaries found:"
SGID_BINARIES=$(find / -perm -2000 -type f 2>/dev/null)
echo "$SGID_BINARIES" | while read binary; do
  if [ -n "$binary" ]; then
    echo "  $binary"
    if [ -w "$binary" ]; then
      echo "    [!] Writable - HIGH RISK"
    fi
  fi
done

echo ""
echo "Checking for known vulnerable SUID binaries..."
for binary in $SUID_BINARIES; do
  if [ -n "$binary" ]; then
    basename_binary=$(basename "$binary")
    case "$basename_binary" in
      vim|vi|nano|less|more|find|awk|python*|perl|ruby|bash|sh)
        echo "  [!] $binary - Known exploitable binary"
        ;;
    esac
  fi
done

echo ""
echo "Recommendations:"
echo "- Check GTFOBins (https://gtfobins.github.io/) for exploitation methods"
echo "- Test if writable SUID binaries can be replaced"
echo "- Check for custom library paths that could be hijacked"
