#!/bin/bash
# Verify cracked credentials against target
# Usage: ./verify_credentials.sh <service> <target> <username> <password>

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo -e "${GREEN}Credential Verifier${NC}"
    echo "Usage: $0 <service> <target> <username> <password>"
    echo ""
    echo "Services: ssh, ftp, mysql, postgres, mongodb, mssql, redis"
    echo ""
    echo "Examples:"
    echo "  $0 ssh 192.168.1.1 admin password123"
    echo "  $0 mysql 10.0.0.5 root secret"
}

if [ $# -ne 4 ]; then
    echo -e "${RED}Error: Service, target, username, and password required${NC}"
    show_help
    exit 1
fi

SERVICE="$1"
TARGET="$2"
USERNAME="$3"
PASSWORD="$4"

echo -e "${GREEN}=== Credential Verification ===${NC}"
echo "Service: $SERVICE"
echo "Target: $TARGET"
echo "Username: $USERNAME"
echo ""

verify_credentials() {
    case $SERVICE in
        ssh)
            echo -e "${BLUE}Testing SSH connection...${NC}"
            if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                "$USERNAME@$TARGET" "exit" 2>/dev/null; then
                echo -e "${GREEN}✓ SSH credentials valid${NC}"
                return 0
            else
                echo -e "${RED}✗ SSH credentials invalid${NC}"
                return 1
            fi
            ;;
        
        ftp)
            echo -e "${BLUE}Testing FTP connection...${NC}"
            if echo "quit" | ftp -n -i "$TARGET" 2>/dev/null | grep -q "230"; then
                echo -e "${GREEN}✓ FTP credentials valid${NC}"
                return 0
            else
                echo -e "${RED}✗ FTP credentials invalid${NC}"
                return 1
            fi
            ;;
        
        mysql)
            echo -e "${BLUE}Testing MySQL connection...${NC}"
            if mysql -h "$TARGET" -u "$USERNAME" -p"$PASSWORD" -e "SELECT 1" 2>/dev/null; then
                echo -e "${GREEN}✓ MySQL credentials valid${NC}"
                return 0
            else
                echo -e "${RED}✗ MySQL credentials invalid${NC}"
                return 1
            fi
            ;;
        
        postgres)
            echo -e "${BLUE}Testing PostgreSQL connection...${NC}"
            if PGPASSWORD="$PASSWORD" psql -h "$TARGET" -U "$USERNAME" -c "SELECT 1" 2>/dev/null; then
                echo -e "${GREEN}✓ PostgreSQL credentials valid${NC}"
                return 0
            else
                echo -e "${RED}✗ PostgreSQL credentials invalid${NC}"
                return 1
            fi
            ;;
        
        mongodb)
            echo -e "${BLUE}Testing MongoDB connection...${NC}"
            if mongosh --host "$TARGET" -u "$USERNAME" -p "$PASSWORD" --eval "db.adminCommand('ping')" 2>/dev/null; then
                echo -e "${GREEN}✓ MongoDB credentials valid${NC}"
                return 0
            else
                echo -e "${RED}✗ MongoDB credentials invalid${NC}"
                return 1
            fi
            ;;
        
        mssql)
            echo -e "${BLUE}Testing MSSQL connection...${NC}"
            if /opt/mssql-tools18/bin/sqlcmd -S "$TARGET" -U "$USERNAME" -P "$PASSWORD" -Q "SELECT 1" 2>/dev/null; then
                echo -e "${GREEN}✓ MSSQL credentials valid${NC}"
                return 0
            else
                echo -e "${RED}✗ MSSQL credentials invalid${NC}"
                return 1
            fi
            ;;
        
        redis)
            echo -e "${BLUE}Testing Redis connection...${NC}"
            if redis-cli -h "$TARGET" -a "$PASSWORD" PING 2>/dev/null | grep -q "PONG"; then
                echo -e "${GREEN}✓ Redis credentials valid${NC}"
                return 0
            else
                echo -e "${RED}✗ Redis credentials invalid${NC}"
                return 1
            fi
            ;;
        
        *)
            echo -e "${RED}Error: Unknown service: $SERVICE${NC}"
            exit 1
            ;;
    esac
}

if verify_credentials; then
    echo ""
    echo -e "${GREEN}=== Verification Successful ===${NC}"
    echo "Credentials for $USERNAME@$TARGET are valid"
    exit 0
else
    echo ""
    echo -e "${RED}=== Verification Failed ===${NC}"
    echo "Credentials may be invalid or service may be unreachable"
    exit 1
fi
