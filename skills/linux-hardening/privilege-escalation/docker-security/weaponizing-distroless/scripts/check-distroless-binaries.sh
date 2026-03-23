#!/bin/bash
# Check for exploitable binaries in a distroless container
# Usage: Run this inside a container to identify available tools

echo "=== Distroless Container Binary Check ==="
echo ""

# Check common exploitable binaries
BINARIES=("openssl" "python" "python3" "perl" "ruby" "node" "java" "php" "lua")

for binary in "${BINARIES[@]}"; do
    if command -v $binary &> /dev/null; then
        echo "[+] Found: $binary"
        case $binary in
            openssl)
                echo "    Version: $(openssl version 2>/dev/null)"
                ;;
            python|python3)
                echo "    Version: $($binary --version 2>/dev/null)"
                ;;
            perl)
                echo "    Version: $(perl -v 2>/dev/null | head -1)"
                ;;
            ruby)
                echo "    Version: $(ruby --version 2>/dev/null)"
                ;;
            node)
                echo "    Version: $(node --version 2>/dev/null)"
                ;;
            java)
                echo "    Version: $(java -version 2>&1 | head -1)"
                ;;
            php)
                echo "    Version: $(php -v 2>/dev/null | head -1)"
                ;;
            lua)
                echo "    Version: $(lua -v 2>/dev/null)"
                ;;
        esac
    fi
done

echo ""
echo "=== Checking /usr/bin/ ==="
ls -la /usr/bin/ 2>/dev/null | head -20

echo ""
echo "=== Checking /bin/ ==="
ls -la /bin/ 2>/dev/null | head -20

echo ""
echo "=== Filesystem Mounts ==="
mount 2>/dev/null | grep -E '(/dev/shm|/tmp|/proc|/sys)' || echo "mount command not available"

echo ""
echo "=== /dev/shm permissions ==="
ls -la /dev/shm/ 2>/dev/null || echo "/dev/shm not accessible"

echo ""
echo "=== Check complete ==="
