#!/bin/bash
# Query TCC database with filters
# Usage: ./query-tcc-database.sh [user|system] [service] [client] [auth_value]

set -e

DB_TYPE="${1:-user}"
SERVICE="${2:-}"
CLIENT="${3:-}"
AUTH_VALUE="${4:-}"

# Determine database path
case "$DB_TYPE" in
  user)
    DB_PATH="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
    ;;
  system)
    DB_PATH="/Library/Application Support/com.apple.TCC/TCC.db"
    ;;
  *)
    echo "Unknown database type: $DB_TYPE"
    echo "Usage: $0 [user|system] [service] [client] [auth_value]"
    exit 1
    ;;
esac

# Check if database exists
if [[ ! -f "$DB_PATH" ]]; then
  echo "Database not found: $DB_PATH"
  exit 1
fi

# Build query
QUERY="SELECT service, client, client_type, auth_value, auth_reason FROM access WHERE 1=1"

if [[ -n "$SERVICE" ]]; then
  QUERY="$QUERY AND service LIKE '%$SERVICE%'"
fi

if [[ -n "$CLIENT" ]]; then
  QUERY="$QUERY AND client LIKE '%$CLIENT%'"
fi

if [[ -n "$AUTH_VALUE" ]]; then
  QUERY="$QUERY AND auth_value=$AUTH_VALUE"
fi

QUERY="$QUERY ORDER BY service, client;"

echo "Querying $DB_TYPE TCC database: $DB_PATH"
echo "Query: $QUERY"
echo ""
echo "Service | Client | Type | Auth | Reason"
echo "--------|--------|------|------|--------"

# Run query
sqlite3 -separator " | " "$DB_PATH" "$QUERY" | while IFS='|' read -r service client ctype auth auth_reason; do
  # Format client_type
  case "$ctype" in
    0) ctype="Bundle ID" ;;
    1) ctype="Path" ;;
    *) ctype="Unknown" ;;
  esac
  
  # Format auth_value
  case "$auth" in
    0) auth="Denied" ;;
    1) auth="Unknown" ;;
    2) auth="Allowed" ;;
    3) auth="Limited" ;;
    *) auth="Unknown" ;;
  esac
  
  # Format auth_reason
  case "$auth_reason" in
    1) reason="Error" ;;
    2) reason="User Consent" ;;
    3) reason="User Set" ;;
    4) reason="System Set" ;;
    5) reason="Service Policy" ;;
    6) reason="MDM Policy" ;;
    7) reason="Override Policy" ;;
    8) reason="Missing usage" ;;
    9) reason="Prompt Timeout" ;;
    10) reason="Preflight Unknown" ;;
    11) reason="Entitled" ;;
    12) reason="App Type Policy" ;;
    *) reason="Unknown" ;;
  esac
  
  printf "%-15s | %-30s | %-8s | %-8s | %s\n" "$service" "$client" "$ctype" "$auth" "$reason"
done

echo ""
echo "Total results: $(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM access WHERE 1=1" "$SERVICE" "$CLIENT" "$AUTH_VALUE" 2>/dev/null || echo 0)"
