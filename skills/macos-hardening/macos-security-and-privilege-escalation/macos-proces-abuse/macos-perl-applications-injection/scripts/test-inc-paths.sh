#!/bin/bash
# Test @INC Paths for Module Hijacking Vulnerabilities
# Usage: ./test-inc-paths.sh

echo "=== @INC Path Module Hijacking Test ==="
echo ""

# Get @INC paths
INC_PATHS=$(perl -e 'print join("\n", @INC)')

# Check each path
echo "Checking @INC paths for writability and existence:"
echo ""

while IFS= read -r path; do
  if [ -d "$path" ]; then
    if [ -w "$path" ]; then
      echo "[CRITICAL] Writable: $path"
      echo "  This path could be used for module hijacking!"
      echo ""
    else
      echo "[OK] Read-only: $path"
    fi
  else
    echo "[N/A] Does not exist: $path"
  fi
done <<< "$INC_PATHS"

echo ""
echo "=== Module Hijacking Test ==="
echo ""

# Test if we can create a test module in writable paths
TEST_MODULE="TestInjectionModule"
TEST_FILE="/tmp/${TEST_MODULE}.pm"

# Create test module
cat > "$TEST_FILE" << 'EOF'
package TestInjectionModule;
print "[INJECTION DETECTED] Module loaded from: $0\n";
1;
EOF

echo "Test module created at: $TEST_FILE"
echo ""

# Try to load it via PERL5LIB
echo "Testing module loading via PERL5LIB:"
PERL5LIB=/tmp/ perl -MTestInjectionModule -e 'print "Script executed\n"'
echo ""

# Cleanup
rm -f "$TEST_FILE"

echo "=== Test Complete ==="
echo ""
echo "If you saw '[INJECTION DETECTED]' above, module hijacking is possible."
echo "Review writable @INC paths and restrict permissions."
