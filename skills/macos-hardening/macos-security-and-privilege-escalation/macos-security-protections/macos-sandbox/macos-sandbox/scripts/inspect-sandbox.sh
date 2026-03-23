#!/bin/bash
# macOS Sandbox Inspection Script
# Usage: ./inspect-sandbox.sh [pid|container-bundle-id|all]

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 [pid|container-bundle-id|all]"
    echo "  pid              - Inspect a specific process PID"
    echo "  container-bundle - Inspect a container by bundle ID"
    echo "  all              - List all containers"
    exit 1
fi

MODE="$1"

case "$MODE" in
    all)
        echo "=== All Sandbox Containers ==="
        ls -la ~/Library/Containers 2>/dev/null || echo "No containers found"
        ;;
    
    *)
        if [[ "$MODE" =~ ^[0-9]+$ ]]; then
            # PID mode
            PID="$MODE"
            echo "=== Inspecting PID $PID ==="
            
            # Check if process exists
            if ! ps -p "$PID" > /dev/null 2>&1; then
                echo "Error: Process $PID not found"
                exit 1
            fi
            
            # Get process info
            echo "Process: $(ps -p $PID -o comm=)"
            echo "Path: $(ps -p $PID -o path=)"
            
            # Try sbtool if available
            if command -v sbtool &> /dev/null; then
                echo ""
                echo "=== sbtool inspection ==="
                sbtool "$PID" inspect 2>/dev/null || echo "sbtool inspection failed"
            else
                echo "Note: sbtool not available for detailed inspection"
            fi
            
            # Check recent sandbox logs for this process
            echo ""
            echo "=== Recent sandbox logs ==="
            log show --predicate 'processImagePath contains "$(ps -p $PID -o path=)" and eventMessage contains "sandbox"' --last 5m 2>/dev/null | head -20 || echo "No recent sandbox logs"
            
        else
            # Container bundle ID mode
            BUNDLE_ID="$MODE"
            CONTAINER_PATH="~/Library/Containers/$BUNDLE_ID"
            
            echo "=== Inspecting Container: $BUNDLE_ID ==="
            
            if [ ! -d "$CONTAINER_PATH" ]; then
                echo "Error: Container not found at $CONTAINER_PATH"
                exit 1
            fi
            
            # Show container structure
            echo ""
            echo "Container contents:"
            ls -la "$CONTAINER_PATH"
            
            # Show metadata if available
            METADATA_FILE="$CONTAINER_PATH/.com.apple.containermanagerd.metadata.plist"
            if [ -f "$METADATA_FILE" ]; then
                echo ""
                echo "=== Container Metadata ==="
                plutil -convert xml1 "$METADATA_FILE" -o - 2>/dev/null | grep -A 5 "<key>" | head -40 || echo "Could not read metadata"
            fi
            
            # Show Data directory
            if [ -d "$CONTAINER_PATH/Data" ]; then
                echo ""
                echo "=== Data Directory ==="
                ls -la "$CONTAINER_PATH/Data"
            fi
        fi
        ;;
esac
