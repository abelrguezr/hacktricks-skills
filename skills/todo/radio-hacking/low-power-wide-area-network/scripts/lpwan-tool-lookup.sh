#!/bin/bash
# LPWAN Security Tool Lookup
# Usage: ./lpwan-tool-lookup.sh [tool_name]

TOOL="${1:-all}"

case "$TOOL" in
    "laf"|"LAF"|"LoRaWAN Auditing Framework")
        echo "=== LoRaWAN Auditing Framework (LAF) ==="
        echo "Purpose: Craft/parse/attack LoRaWAN frames, DB-backed analyzers, brute-forcer"
        echo "Features:"
        echo "  - Docker-based deployment"
        echo "  - Semtech UDP input support"
        echo "  - Frame crafting and parsing"
        echo "  - Database-backed analysis"
        echo "  - Brute-force capabilities"
        echo ""
        echo "Installation:"
        echo "  docker pull ioactive/laf"
        echo ""
        echo "Repository: https://github.com/IOActive/laf"
        ;;
    "lorapwn"|"LoRaPWN")
        echo "=== LoRaPWN (Trend Micro) ==="
        echo "Purpose: Brute OTAA, generate downlinks, decrypt payloads"
        echo "Features:"
        echo "  - Python utility"
        echo "  - SDR-agnostic"
        echo "  - OTAA brute-forcing"
        echo "  - Downlink generation"
        echo "  - Payload decryption"
        echo ""
        echo "Installation:"
        echo "  git clone https://github.com/TrendMicro/lorapwn"
        echo "  cd lorapwn && pip install -r requirements.txt"
        echo ""
        echo "Repository: https://github.com/TrendMicro/lorapwn"
        ;;
    "lorattack"|"LoRAttack")
        echo "=== LoRAttack ==="
        echo "Purpose: Multi-channel sniffer + replay with USRP"
        echo "Features:"
        echo "  - Multi-channel capture"
        echo "  - Replay capability"
        echo "  - USRP support"
        echo "  - PCAP/LoRaTap export"
        echo "  - Wireshark integration"
        echo ""
        echo "Installation:"
        echo "  git clone https://github.com/IOActive/lorattack"
        echo "  cd lorattack && pip install -e ."
        echo ""
        echo "Repository: https://github.com/IOActive/lorattack"
        ;;
    "gr-lora"|"gr-lorawan"|"GNU Radio")
        echo "=== GNU Radio LoRa Blocks ==="
        echo "Purpose: Baseband TX/RX for custom attacks"
        echo "Features:"
        echo "  - gr-lora: Physical layer blocks"
        echo "  - gr-lorawan: MAC layer blocks"
        echo "  - Foundation for custom attack development"
        echo "  - Full signal processing control"
        echo ""
        echo "Installation:"
        echo "  # gr-lora"
        echo "  git clone https://github.com/bastibl/gr-lora"
        echo "  # gr-lorawan"
        echo "  git clone https://github.com/bastibl/gr-lorawan"
        echo ""
        echo "Requires: GNU Radio, SDR hardware support"
        ;;
    "all")
        echo "=== LPWAN Security Tools Overview ==="
        echo ""
        echo "| Tool | Purpose | Best For |"
        echo "|------|---------|----------|"
        echo "| LAF | Full framework | Comprehensive assessments |"
        echo "| LoRaPWN | Python utility | Quick OTAA brute-force |"
        echo "| LoRAttack | Sniffer/replay | Traffic analysis & replay |"
        echo "| gr-lora | GNU Radio blocks | Custom attack development |"
        echo ""
        echo "Use: ./lpwan-tool-lookup.sh [tool_name]"
        echo "Available: laf, lorapwn, lorattack, gr-lora"
        ;;
    *)
        echo "Unknown tool: $TOOL"
        echo "Available tools: laf, lorapwn, lorattack, gr-lora, all"
        exit 1
        ;;
esac
