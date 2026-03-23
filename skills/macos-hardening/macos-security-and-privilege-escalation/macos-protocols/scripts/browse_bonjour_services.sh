#!/bin/bash
# macOS Bonjour Service Discovery
# Browses for common services on the local network

SERVICE_TYPES=(
    "_ssh._tcp"
    "_http._tcp"
    "_https._tcp"
    "_printer._tcp"
    "_airplay._tcp"
    "_raop._tcp"
    "_smb._tcp"
    "_ftp._tcp"
    "_telnet._tcp"
    "_vnc._tcp"
)

echo "========================================"
echo "Bonjour Service Discovery"
echo "========================================"
echo ""
echo "Scanning for services on local network..."
echo "Press Ctrl+C to stop scanning"
echo ""

for service in "${SERVICE_TYPES[@]}"; do
    echo "----------------------------------------"
    echo "Searching for: $service"
    echo "----------------------------------------"
    
    # Browse for 3 seconds then stop
    timeout 3 dns-sd -B "$service" 2>/dev/null || true
    echo ""
done

echo "========================================"
echo "Quick Commands:"
echo "========================================"
echo "Browse SSH:     dns-sd -B _ssh._tcp"
echo "Browse HTTP:    dns-sd -B _http._tcp"
echo "Browse all:     dns-sd -B _services._dns-sd._udp.local"
echo "========================================"
