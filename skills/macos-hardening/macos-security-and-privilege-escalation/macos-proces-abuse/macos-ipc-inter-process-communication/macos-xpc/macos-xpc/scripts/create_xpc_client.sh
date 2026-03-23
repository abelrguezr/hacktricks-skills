#!/bin/bash
# XPC Test Client Generator (C version)
# Creates a basic XPC client to test service connectivity

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check arguments
if [[ $# -lt 1 ]]; then
    echo -e "${RED}Usage: $0 <service-name>${NC}"
    echo ""
    echo "Example: $0 com.example.service"
    echo "         $0 xyz.hacktricks.service"
    exit 1
fi

SERVICE_NAME="$1"
OUTPUT_DIR="xpc_test_clients"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo -e "${GREEN}=== XPC Test Client Generator ===${NC}"
echo "Service: $SERVICE_NAME"
echo "Output: $OUTPUT_DIR/"
echo ""

# Generate C client code
echo -e "${GREEN}[+] Generating C client code...${NC}"

cat > "$OUTPUT_DIR/xpc_client.c" << 'EOF'
#include <xpc/xpc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void handle_response(xpc_object_t event) {
    if (xpc_get_type(event) == XPC_TYPE_DICTIONARY) {
        printf("[+] Received response:\n");
        
        // Print all keys in the response
        xpc_dictionary_apply(event, ^(xpc_object_t key, xpc_object_t value) {
            const char *key_str = xpc_copy_string(key);
            const char *value_str = xpc_copy_description(value);
            printf("    %s: %s\n", key_str ? key_str : "(unknown)", value_str ? value_str : "(null)");
            if (key_str) free((void*)key_str);
            if (value_str) free((void*)value_str);
        });
        
        // Check for common response keys
        const char* status = xpc_dictionary_get_string(event, "status");
        const char* result = xpc_dictionary_get_string(event, "result");
        const char* error = xpc_dictionary_get_string(event, "error");
        
        if (status) printf("[+] Status: %s\n", status);
        if (result) printf("[+] Result: %s\n", result);
        if (error) printf("[-] Error: %s\n", error);
    } else {
        printf("[+] Received non-dictionary response (type: %d)\n", xpc_get_type(event));
    }
}

static void handle_connection_error(xpc_connection_t connection, bool timed_out) {
    if (timed_out) {
        printf("[-] Connection timed out\n");
    } else {
        printf("[-] Connection failed\n");
    }
    exit(1);
}

int main(int argc, const char *argv[]) {
    const char *service_name = "SERVICE_NAME_PLACEHOLDER";
    
    printf("[*] Connecting to XPC service: %s\n", service_name);
    
    // Create connection (try privileged first, then regular)
    xpc_connection_t connection = xpc_connection_create_mach_service(
        service_name, 
        NULL, 
        XPC_CONNECTION_MACH_SERVICE_PRIVILEGED
    );
    
    if (!connection) {
        printf("[-] Failed to create privileged connection, trying regular...\n");
        connection = xpc_connection_create_mach_service(
            service_name, 
            NULL, 
            0  // Regular connection
        );
    }
    
    if (!connection) {
        printf("[-] Failed to create XPC connection\n");
        return 1;
    }
    
    // Set up event handler for responses
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
        handle_response(event);
    });
    
    // Set up error handler
    xpc_connection_set_error_handler(connection, ^(xpc_connection_t conn, error_t err) {
        printf("[-] Connection error: %d\n", err);
        exit(1);
    });
    
    // Set up timeout handler
    xpc_connection_set_timeout_handler(connection, ^(xpc_connection_t conn) {
        printf("[-] Connection timeout\n");
        exit(1);
    });
    
    printf("[*] Resuming connection...\n");
    xpc_connection_resume(connection);
    
    // Create test messages
    printf("[*] Sending test messages...\n");
    
    // Message 1: Simple ping
    xpc_object_t msg1 = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(msg1, "action", "ping");
    xpc_dictionary_set_string(msg1, "test", "basic_connectivity");
    xpc_connection_send_message(connection, msg1);
    xpc_release(msg1);
    printf("[+] Sent: ping\n");
    
    // Message 2: Request info
    xpc_object_t msg2 = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(msg2, "action", "get_info");
    xpc_connection_send_message(connection, msg2);
    xpc_release(msg2);
    printf("[+] Sent: get_info\n");
    
    // Message 3: Empty dictionary (fuzzing)
    xpc_object_t msg3 = xpc_dictionary_create(NULL, NULL, 0);
    xpc_connection_send_message(connection, msg3);
    xpc_release(msg3);
    printf("[+] Sent: empty_dict\n");
    
    // Message 4: String instead of dict (type confusion test)
    xpc_object_t msg4 = xpc_string_create("test_string");
    xpc_connection_send_message(connection, msg4);
    xpc_release(msg4);
    printf("[+] Sent: string_instead_of_dict\n");
    
    // Message 5: Integer (another type test)
    xpc_object_t msg5 = xpc_int64_create(42);
    xpc_connection_send_message(connection, msg5);
    xpc_release(msg5);
    printf("[+] Sent: integer_value\n");
    
    printf("[*] All test messages sent. Waiting for responses (Ctrl+C to exit)...\n");
    
    // Keep running to receive responses
    dispatch_main();
    
    return 0;
}
EOF

# Replace placeholder
sed -i "s/SERVICE_NAME_PLACEHOLDER/$SERVICE_NAME/g" "$OUTPUT_DIR/xpc_client.c"

echo -e "${GREEN}[+] Generating plist for service registration...${NC}"

# Generate plist for testing (if user wants to register their own service)
cat > "$OUTPUT_DIR/test_service.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>test.$SERVICE_NAME</string>
    <key>MachServices</key>
    <dict>
        <key>$SERVICE_NAME</key>
        <true/>
    </dict>
    <key>Program</key>
    <string>/tmp/test_xpc_server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/tmp/test_xpc_server</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

echo -e "${GREEN}[+] Generating build script...${NC}"

# Generate build script
cat > "$OUTPUT_DIR/build.sh" << 'EOF'
#!/bin/bash
# Build XPC test client

set -e

echo "[*] Building XPC client..."
gcc -o xpc_client xpc_client.c -framework Foundation

if [[ $? -eq 0 ]]; then
    echo "[+] Build successful: xpc_client"
    echo ""
    echo "Usage: ./xpc_client"
    echo ""
    echo "The client will:"
    echo "  1. Connect to the XPC service"
    echo "  2. Send various test messages"
    echo "  3. Display responses"
    echo "  4. Wait for additional responses (Ctrl+C to exit)"
else
    echo "[-] Build failed"
    exit 1
fi
EOF

chmod +x "$OUTPUT_DIR/build.sh"

echo -e "${GREEN}[+] Generating usage guide...${NC}"

# Generate README
cat > "$OUTPUT_DIR/README.md" << EOF
# XPC Test Client for $SERVICE_NAME

## Files Generated

- `xpc_client.c` - C source code for the test client
- `build.sh` - Build script
- `test_service.plist` - Example plist for registering a test service

## Building

\`\`\`bash
cd xpc_test_clients
./build.sh
\`\`\`

## Running

\`\`\`bash
./xpc_client
\`\`\`

## What It Does

The test client will:

1. **Connect** to the XPC service `$SERVICE_NAME`
2. **Send test messages**:
   - Basic ping (dictionary with action key)
   - Get info request
   - Empty dictionary (fuzzing)
   - String instead of dictionary (type confusion test)
   - Integer value (another type test)
3. **Display responses** from the service
4. **Wait** for additional responses (Ctrl+C to exit)

## Interpreting Results

### Good Signs
- Connection succeeds
- Service responds to messages
- Responses are well-formed dictionaries

### Warning Signs
- Connection fails (service may not exist or be restricted)
- Service crashes (segfault in response)
- Service accepts unexpected message types
- Service returns sensitive information

### Critical Issues
- Service accepts messages from unprivileged users when it shouldn't
- Service executes commands based on input
- Service reads/writes files based on input
- Service has no input validation

## Advanced Testing

### With xpcspy

\`\`\`bash
xpcspy -U -r -W <bundle-id>
xpcspy -U <prog-name> -t 'i:$SERVICE_NAME' -t 'o:$SERVICE_NAME' -r
\`\`\`

### With DTrace

\`\`\`bash
dtrace -n 'pid\$1:::entry { trace(arg0); }' -p \$(pgrep <process>)
\`\`\`

## Cleanup

\`\`\`bash
rm -rf xpc_test_clients
\`\`\`
EOF

echo ""
echo -e "${GREEN}=== Generation Complete ===${NC}"
echo ""
echo "Files created in $OUTPUT_DIR/:"
ls -la "$OUTPUT_DIR/"
echo ""
echo "Next steps:"
echo "  1. cd $OUTPUT_DIR"
echo "  2. ./build.sh"
echo "  3. ./xpc_client"
echo ""
echo "For monitoring, use:"
echo "  xpcspy -U -r -W <bundle-id>"
echo ""
