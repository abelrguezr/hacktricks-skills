#!/bin/bash
# D-Bus Monitor and Capture Script
# Monitors D-Bus traffic or captures to pcap file

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script requires root privileges${NC}"
    echo -e "${YELLOW}Run with: sudo $0${NC}"
    exit 1
fi

# Check for required tools
if ! command -v busctl &> /dev/null; then
    echo -e "${RED}Error: busctl not found${NC}"
    exit 1
fi

show_help() {
    echo -e "${BLUE}=== D-Bus Monitor/Capture ===${NC}"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  monitor [service]     Monitor D-Bus traffic (real-time)"
    echo "  capture <output.pcap> Capture traffic to pcap file"
    echo "  filter <rule>         Monitor with filter rule"
    echo "  help                Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 monitor                    # Monitor all system bus traffic"
    echo "  $0 monitor org.freedesktop.hostname1  # Monitor specific service"
    echo "  $0 capture /tmp/dbus.pcap    # Capture to file"
    echo "  $0 filter \"type=method_call\"   # Filter by type"
    echo ""
    echo -e "${YELLOW}Note: Requires root privileges${NC}"
}

case "${1:-help}" in
    monitor)
        service="${2:-}"
        
        echo -e "${GREEN}[*] Starting D-Bus monitor...${NC}"
        echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
        echo ""
        
        if [[ -n "$service" ]]; then
            echo -e "${BLUE}Monitoring service: $service${NC}"
            busctl monitor "$service"
        else
            echo -e "${BLUE}Monitoring all system bus traffic${NC}"
            busctl monitor
        fi
        ;;
    
    capture)
        output_file="${2:-/tmp/dbus_capture_$(date +%F_%H%M%S).pcap}"
        
        echo -e "${GREEN}[*] Capturing D-Bus traffic to: $output_file${NC}"
        echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
        echo ""
        
        busctl capture --output="$output_file"
        
        echo ""
        echo -e "${GREEN}[+] Capture saved to: $output_file${NC}"
        echo -e "${BLUE}Tip: Open with Wireshark for analysis${NC}"
        ;;
    
    filter)
        filter_rule="${2:-}"
        
        if [[ -z "$filter_rule" ]]; then
            echo -e "${RED}Error: Filter rule required${NC}"
            echo ""
            echo "Example filter rules:"
            echo "  \"type=method_call\""
            echo "  \"type=error\""
            echo "  \"sender=org.freedesktop.hostname1\""
            echo "  \"type=signal,sender='org.gnome.TypingMonitor'\""
            exit 1
        fi
        
        echo -e "${GREEN}[*] Monitoring with filter: $filter_rule${NC}"
        echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
        echo ""
        
        dbus-monitor "$filter_rule"
        ;;
    
    help|*)
        show_help
        ;;
esac
