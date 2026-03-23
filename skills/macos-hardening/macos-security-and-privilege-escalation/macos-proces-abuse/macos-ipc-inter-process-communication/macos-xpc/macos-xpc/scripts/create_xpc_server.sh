#!/bin/bash
# XPC Test Server Generator (C version)
# Creates a basic XPC server for testing and research

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
    echo "Example: $0 com.example.test.service"
    exit 1
fi

SERVICE_NAME="$1"
OUTPUT_DIR="xpc_test_servers"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo -e "${GREEN}=== XPC Test Server Generator ===${NC}"
echo "Service: $SERVICE_NAME"
echo "Output: $OUTPUT_DIR/"
echo ""

# Generate C server code
echo -e "${GREEN}[+] Generating C server code...${NC}"

cat > "$OUTPUT_DIR/xpc_server.c" << 'EOF'
#include <xpc/xpc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

// Global flag for graceful shutdown
static volatile sig_atomic_t running = 1;

void signal_handler(int sig) {
    printf("\n[*] Received signal, shutting down...\n");
    running = 0;
}

static void handle_message(xpc_object_t message, xpc_connection_t connection) {
    printf("[+] Received message:\n");
    
    // Log message type
    xpc_type_t type = xpc_get_type(message);
    printf("    Type: %d", type);
    
    switch (type) {
        case XPC_TYPE_DICTIONARY:
            printf(" (dictionary)");
            
            // Extract and log action
            const char* action = xpc_dictionary_get_string(message, "action");
            if (action) {
                printf("\n    Action: %s", action);
            }
            
            // Log all keys
            printf("\n    Keys:");
            xpc_dictionary_apply(message, ^(xpc_object_t key, xpc_object_t value) {
                const char *key_str = xpc_copy_string(key);
                const char *value_str = xpc_copy_description(value);
                printf("\n      %s: %s", 
                       key_str ? key_str : "(unknown)", 
                       value_str ? value_str : "(null)");
                if (key_str) free((void*)key_str);
                if (value_str) free((void*)value_str);
            });
            
            // Create response based on action
            xpc_object_t response = xpc_dictionary_create(NULL, NULL, 0);
            
            if (action) {
                if (strcmp(action, "ping") == 0) {
                    xpc_dictionary_set_string(response, "status", "ok");
                    xpc_dictionary_set_string(response, "message", "pong");
                } else if (strcmp(action, "get_info") == 0) {
                    xpc_dictionary_set_string(response, "status", "ok");
                    xpc_dictionary_set_string(response, "service", "SERVICE_NAME_PLACEHOLDER");
                    xpc_dictionary_set_string(response, "version", "1.0.0");
                    xpc_dictionary_set_int64(response, "pid", getpid());
                } else if (strcmp(action, "echo") == 0) {
                    xpc_dictionary_set_string(response, "status", "ok");
                    const char* input = xpc_dictionary_get_string(message, "input");
                    if (input) {
                        xpc_dictionary_set_string(response, "echo", input);
                    }
                } else {
                    xpc_dictionary_set_string(response, "status", "unknown_action");
                    xpc_dictionary_set_string(response, "action", action);
                }
            } else {
                xpc_dictionary_set_string(response, "status", "ok");
                xpc_dictionary_set_string(response, "message", "received");
            }
            
            xpc_connection_send_message(connection, response);
            xpc_release(response);
            break;
            
        case XPC_TYPE_STRING:
            printf(" (string)");
            const char* str_val = xpc_copy_string(message);
            if (str_val) {
                printf(" = %s", str_val);
                free((void*)str_val);
            }
            
            // Respond to string with dictionary
            xpc_object_t response = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_string(response, "status", "ok");
            xpc_dictionary_set_string(response, "received_type", "string");
            xpc_connection_send_message(connection, response);
            xpc_release(response);
            break;
            
        case XPC_TYPE_INT64:
            printf(" (int64)");
            int64_t int_val = xpc_int64_get_value(message);
            printf(" = %ld", int_val);
            
            xpc_object_t response = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_string(response, "status", "ok");
            xpc_dictionary_set_string(response, "received_type", "int64");
            xpc_dictionary_set_int64(response, "value", int_val);
            xpc_connection_send_message(connection, response);
            xpc_release(response);
            break;
            
        default:
            printf(" (unknown)");
            
            xpc_object_t response = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_string(response, "status", "ok");
            xpc_dictionary_set_string(response, "received_type", "unknown");
            xpc_dictionary_set_int64(response, "type_code", type);
            xpc_connection_send_message(connection, response);
            xpc_release(response);
            break;
    }
    
    printf("\n");
}

static void handle_connection(xpc_connection_t connection) {
    printf("[+] New connection established\n");
    
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
        if (running) {
            handle_message(event, connection);
        }
    });
    
    xpc_connection_set_error_handler(connection, ^(xpc_connection_t conn, error_t err) {
        printf("[-] Connection error: %d\n", err);
    });
    
    xpc_connection_resume(connection);
}

int main(int argc, const char *argv[]) {
    const char *service_name = "SERVICE_NAME_PLACEHOLDER";
    
    // Set up signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    printf("[*] Starting XPC server: %s\n", service_name);
    printf("[*] PID: %d\n", getpid());
    printf("[*] Press Ctrl+C to stop\n\n");
    
    // Create the service connection
    xpc_connection_t service = xpc_connection_create_mach_service(
        service_name,
        dispatch_get_main_queue(),
        XPC_CONNECTION_MACH_SERVICE_LISTENER
    );
    
    if (!service) {
        fprintf(stderr, "[-] Failed to create XPC service\n");
        return EXIT_FAILURE;
    }
    
    printf("[+] XPC service created\n");
    
    // Set up the event handler for new connections
    xpc_connection_set_event_handler(service, ^(xpc_object_t event) {
        xpc_type_t type = xpc_get_type(event);
        if (type == XPC_TYPE_CONNECTION && running) {
            handle_connection(event);
        }
    });
    
    // Set up error handler
    xpc_connection_set_error_handler(service, ^(xpc_connection_t conn, error_t err) {
        printf("[-] Service error: %d\n", err);
    });
    
    printf("[+] Service ready, waiting for connections...\n\n");
    
    // Resume the service
    xpc_connection_resume(service);
    
    // Run the event loop
    dispatch_main();
    
    printf("[*] Server shutdown complete\n");
    return 0;
}
EOF

# Replace placeholder
sed -i "s/SERVICE_NAME_PLACEHOLDER/$SERVICE_NAME/g" "$OUTPUT_DIR/xpc_server.c"

echo -e "${GREEN}[+] Generating plist for service registration...${NC}"

# Generate plist
cat > "$OUTPUT_DIR/${SERVICE_NAME}.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$SERVICE_NAME</string>
    <key>MachServices</key>
    <dict>
        <key>$SERVICE_NAME</key>
        <true/>
    </dict>
    <key>Program</key>
    <string>/tmp/xpc_server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/tmp/xpc_server</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

echo -e "${GREEN}[+] Generating build and deployment scripts...${NC}"

# Generate build script
cat > "$OUTPUT_DIR/build.sh" << 'EOF'
#!/bin/bash
# Build XPC test server

set -e

echo "[*] Building XPC server..."
gcc -o xpc_server xpc_server.c

if [[ $? -eq 0 ]]; then
    echo "[+] Build successful: xpc_server"
    echo ""
    echo "To deploy:"
    echo "  1. Copy binary: cp xpc_server /tmp/"
    echo "  2. Copy plist: sudo cp <service>.plist /Library/LaunchDaemons/"
    echo "  3. Load service: sudo launchctl load /Library/LaunchDaemons/<service>.plist"
    echo ""
    echo "To test:"
    echo "  Use the XPC client from create_xpc_client.sh"
    echo ""
    echo "To stop:"
    echo "  sudo launchctl unload /Library/LaunchDaemons/<service>.plist"
else
    echo "[-] Build failed"
    exit 1
fi
EOF

chmod +x "$OUTPUT_DIR/build.sh"

# Generate deployment script
cat > "$OUTPUT_DIR/deploy.sh" << EOF
#!/bin/bash
# Deploy XPC test server

set -e

SERVICE_NAME="$SERVICE_NAME"

echo "[*] Deploying XPC service: \$SERVICE_NAME"
echo ""

# Check if running as root
if [[ \$EUID -ne 0 ]]; then
    echo "[!] This script requires root privileges"
    echo "[!] Please run: sudo \$0"
    exit 1
fi

# Copy binary
echo "[*] Copying binary to /tmp/"
cp xpc_server /tmp/
chmod +x /tmp/xpc_server

# Copy plist
echo "[*] Copying plist to /Library/LaunchDaemons/"
cp "\$SERVICE_NAME.plist" /Library/LaunchDaemons/

# Load service
echo "[*] Loading service..."
sudo launchctl load /Library/LaunchDaemons/"\$SERVICE_NAME.plist"

echo ""
echo "[+] Service deployed successfully"
echo ""
echo "To test:"
echo "  ./xpc_client (from create_xpc_client.sh)"
echo ""
echo "To stop:"
echo "  sudo ./undeploy.sh"
EOF

chmod +x "$OUTPUT_DIR/deploy.sh"

# Generate undeploy script
cat > "$OUTPUT_DIR/undeploy.sh" << EOF
#!/bin/bash
# Undeploy XPC test server

set -e

SERVICE_NAME="$SERVICE_NAME"

echo "[*] Undeploying XPC service: \$SERVICE_NAME"

# Unload service
echo "[*] Unloading service..."
sudo launchctl unload /Library/LaunchDaemons/"\$SERVICE_NAME.plist" 2>/dev/null || true

# Remove files
echo "[*] Removing files..."
sudo rm -f /Library/LaunchDaemons/"\$SERVICE_NAME.plist"
rm -f /tmp/xpc_server

echo ""
echo "[+] Service undeployed"
EOF

chmod +x "$OUTPUT_DIR/undeploy.sh"

echo -e "${GREEN}[+] Generating README...${NC}"

# Generate README
cat > "$OUTPUT_DIR/README.md" << EOF
# XPC Test Server for $SERVICE_NAME

## Overview

This is a test XPC server for research and testing purposes. It demonstrates:

- Basic XPC service setup
- Message handling for different types
- Connection management
- Graceful shutdown

## Files

- `xpc_server.c` - Server source code
- `$SERVICE_NAME.plist` - LaunchDaemon configuration
- `build.sh` - Build script
- `deploy.sh` - Deployment script (requires sudo)
- `undeploy.sh` - Cleanup script

## Building

\`\`\`bash
./build.sh
\`\`\`

## Deploying

\`\`\`bash
sudo ./deploy.sh
\`\`\`

This will:
1. Copy the binary to `/tmp/xpc_server`
2. Copy the plist to `/Library/LaunchDaemons/`
3. Load the service with launchd

## Testing

Use the XPC client from `create_xpc_client.sh`:

\`\`\`bash
# In another terminal
cd ../xpc_test_clients
./build.sh
./xpc_client
\`\`\`

## Supported Actions

| Action | Description | Response |
|--------|-------------|----------|
| `ping` | Basic connectivity test | `pong` |
| `get_info` | Get service information | Service details |
| `echo` | Echo back input | Input value |
| *(none)* | Default handling | `received` |

## Message Types

The server handles:
- Dictionaries (with action keys)
- Strings
- Integers
- Unknown types (logs and responds)

## Monitoring

\`\`\`bash
# View service status
launchctl list | grep $SERVICE_NAME

# Monitor with xpcspy
xpcspy -U -r -W $SERVICE_NAME

# View logs
log show --predicate 'process == "xpc_server"' --last 5m
\`\`\`

## Cleanup

\`\`\`bash
sudo ./undeploy.sh
\`\`\`

## Security Notes

⚠️ **This is a test server with NO security controls:**

- No client authentication
- No input validation
- No sandbox restrictions
- Runs as root (LaunchDaemon)

**Do not deploy to production systems.**

For secure XPC services, implement:
- `_AllowedClients` restrictions
- Input validation and sanitization
- Proper sandbox profiles
- Least privilege principle
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
echo "  3. sudo ./deploy.sh"
echo "  4. Test with XPC client"
echo ""
echo "Remember to undeploy when done:"
echo "  sudo ./undeploy.sh"
