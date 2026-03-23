#!/bin/bash
# DDexec wrapper script for easy binary execution from memory
# Based on: https://github.com/arget13/DDexec

set -e

usage() {
    echo "Usage: $0 <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  url <url> [args...]    - Download and execute binary from URL"
    echo "  file <path> [args...]  - Execute local binary from memory"
    echo "  base64 <data> [args...] - Execute base64-encoded binary"
    echo ""
    echo "Examples:"
    echo "  $0 url https://example.com/binary arg1 arg2"
    echo "  $0 file /tmp/binary.elf arg1 arg2"
    echo "  $0 base64 $(base64 -w0 binary.elf) arg1 arg2"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

COMMAND=$1
shift

# Download DDexec if not present
if [ ! -f ddexec.sh ]; then
    echo "Downloading DDexec..."
    wget -q -O ddexec.sh https://raw.githubusercontent.com/arget13/DDexec/main/ddexec.sh
    chmod +x ddexec.sh
fi

case $COMMAND in
    url)
        if [ -z "$1" ]; then
            echo "Error: URL required"
            usage
        fi
        URL=$1
        shift
        echo "Downloading from $URL..."
        wget -q -O- "$URL" | base64 -w0 | bash ddexec.sh "$@"
        ;;
    file)
        if [ -z "$1" ]; then
            echo "Error: File path required"
            usage
        fi
        FILE=$1
        shift
        if [ ! -f "$FILE" ]; then
            echo "Error: File not found: $FILE"
            exit 1
        fi
        echo "Executing $FILE from memory..."
        base64 -w0 "$FILE" | bash ddexec.sh "$@"
        ;;
    base64)
        if [ -z "$1" ]; then
            echo "Error: Base64 data required"
            usage
        fi
        B64DATA=$1
        shift
        echo "Executing base64-encoded binary..."
        echo "$B64DATA" | bash ddexec.sh "$@"
        ;;
    *)
        echo "Error: Unknown command: $COMMAND"
        usage
        ;;
esac
