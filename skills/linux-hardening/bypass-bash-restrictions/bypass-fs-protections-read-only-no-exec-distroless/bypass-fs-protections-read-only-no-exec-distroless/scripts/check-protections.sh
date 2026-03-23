#!/bin/bash
# Check filesystem protections on current system

echo "=== Filesystem Protection Check ==="
echo ""

# Check mount options
echo "Mount options for /:"
mount | grep " on / "

# Check /dev/shm
echo ""
echo "Mount options for /dev/shm:"
mount | grep "/dev/shm"

# Check if we can write to /tmp
echo ""
echo "Write test to /tmp:"
touch /tmp/test_write 2>/dev/null && echo "✓ Can write to /tmp" || echo "✗ Cannot write to /tmp"
rm -f /tmp/test_write 2>/dev/null

# Check if we can write to /dev/shm
echo ""
echo "Write test to /dev/shm:"
touch /dev/shm/test_write 2>/dev/null && echo "✓ Can write to /dev/shm" || echo "✗ Cannot write to /dev/shm"
rm -f /dev/shm/test_write 2>/dev/null

# Check available interpreters
echo ""
echo "Available interpreters:"
for lang in sh bash python python3 perl ruby node php; do
    which $lang 2>/dev/null && echo "✓ $lang available" || echo "✗ $lang not found"
done

# Check if we can execute from /dev/shm
echo ""
echo "Execution test from /dev/shm:"
echo '#!/bin/sh
echo test' > /dev/shm/test_exec.sh 2>/dev/null
chmod +x /dev/shm/test_exec.sh 2>/dev/null
/dev/shm/test_exec.sh 2>/dev/null && echo "✓ Can execute from /dev/shm" || echo "✗ Cannot execute from /dev/shm (noexec)"
rm -f /dev/shm/test_exec.sh 2>/dev/null

echo ""
echo "=== Check Complete ==="
