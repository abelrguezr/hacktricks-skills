#!/bin/bash
# BloodHound CE Deployment Script
# Deploys BloodHound with Neo4j and the web UI

set -e

BLOODHOUND_DIR="${1:-bloodhound}"

echo "[+] Deploying BloodHound CE to $BLOODHOUND_DIR"

# Create directory
mkdir -p "$BLOODHOUND_DIR"
cd "$BLOODHOUND_DIR"

# Download and deploy
echo "[+] Fetching BloodHound CE deployment..."
curl -L https://ghst.ly/getbhce | docker compose -f - up -d

echo ""
echo "[+] BloodHound is starting..."
echo "[+] Wait 30 seconds for Neo4j to initialize"
sleep 30

# Extract password from logs
echo "[+] Extracting admin password from logs..."
ADMIN_PASSWORD=$(docker compose logs neo4j 2>&1 | grep -oP 'password: \K[a-zA-Z0-9]+' | head -1)

if [ -z "$ADMIN_PASSWORD" ]; then
    echo "[!] Could not extract password automatically. Check logs with:"
    echo "    docker compose logs neo4j"
    ADMIN_PASSWORD="(check logs)"
fi

echo ""
echo "========================================"
echo "BloodHound CE is ready!"
echo "========================================"
echo "Web UI: http://localhost:8080"
echo "Username: admin"
echo "Password: $ADMIN_PASSWORD"
echo "========================================"
echo ""
echo "To stop: cd $BLOODHOUND_DIR && docker compose down"
echo "To view logs: docker compose logs -f"
