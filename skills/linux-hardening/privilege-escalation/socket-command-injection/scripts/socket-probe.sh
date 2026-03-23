#!/bin/bash
# Socket Command Injection Probe
# Tests a Unix socket for command injection vulnerabilities

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <socket_path>"
    echo "Example: $0 /tmp/socket_test.s"
    exit 1
fi

SOCKET_PATH="$1"

echo "[*] Probing socket: $SOCKET_PATH"
echo ""

# Check if socket exists
if [ ! -S "$SOCKET_PATH" ]; then
    echo "[!] Socket does not exist or is not a socket file"
    exit 1
fi

# Check socket permissions
echo "[*] Socket permissions:"
ls -la "$SOCKET_PATH"
echo ""

# Check if socat is available
if ! command -v socat &> /dev/null; then
    echo "[!] socat is required but not installed"
    echo "    Install with: apt install socat || yum install socat"
    exit 1
fi

echo "[*] Testing for command injection..."
echo ""

# Test 1: Basic command (id)
echo "[+] Test 1: Basic command injection (id)"
OUTPUT=$(echo "id" | timeout 5 socat - UNIX-CLIENT:"$SOCKET_PATH" 2>&1 || true)
if [ -n "$OUTPUT" ]; then
    echo "    Response: $OUTPUT"
    if echo "$OUTPUT" | grep -q "uid="; then
        echo "    [!] VULNERABLE: Command injection detected!"
    fi
else
    echo "    No response or timeout"
fi
echo ""

# Test 2: Whoami
echo "[+] Test 2: Whoami command"
OUTPUT=$(echo "whoami" | timeout 5 socat - UNIX-CLIENT:"$SOCKET_PATH" 2>&1 || true)
if [ -n "$OUTPUT" ]; then
    echo "    Response: $OUTPUT"
    if echo "$OUTPUT" | grep -qE "^[a-z]+"; then
        echo "    [!] VULNERABLE: Command execution confirmed!"
    fi
else
    echo "    No response or timeout"
fi
echo ""

# Test 3: Multiple commands
echo "[+] Test 3: Multiple commands (id; whoami)"
OUTPUT=$(echo "id; whoami" | timeout 5 socat - UNIX-CLIENT:"$SOCKET_PATH" 2>&1 || true)
if [ -n "$OUTPUT" ]; then
    echo "    Response: $OUTPUT"
    if echo "$OUTPUT" | grep -q "uid="; then
        echo "    [!] VULNERABLE: Command chaining works!"
    fi
else
    echo "    No response or timeout"
fi
echo ""

# Test 4: Newline injection
echo "[+] Test 4: Newline injection"
OUTPUT=$(echo -e "id\nwhoami" | timeout 5 socat - UNIX-CLIENT:"$SOCKET_PATH" 2>&1 || true)
if [ -n "$OUTPUT" ]; then
    echo "    Response: $OUTPUT"
    if echo "$OUTPUT" | grep -q "uid="; then
        echo "    [!] VULNERABLE: Newline injection works!"
    fi
else
    echo "    No response or timeout"
fi
echo ""

echo "[*] Probe complete"
echo ""
echo "[!] If any tests showed VULNERABLE, the socket accepts untrusted commands"
echo "    Review the service code for os.system(), exec(), or shell=True usage"
