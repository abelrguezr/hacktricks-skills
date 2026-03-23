#!/bin/bash
# Token Deriver Script
# Derives cloud config tokens from device IDs

set -e

usage() {
    echo "Usage: $0 <device_id> <static_key> [options]"
    echo ""
    echo "Derives cloud configuration tokens using MD5(deviceId || staticKey)"
    echo ""
    echo "Options:"
    echo "  -a <algorithm>  Algorithm: md5 (default), sha1, sha256"
    echo "  -u             Lowercase output (default is uppercase)"
    echo "  -h             Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 d88b00112233 cf50deadbeefcafebabe"
    echo "  $0 d88b00112233 cf50deadbeef -a sha256"
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

DEVICE_ID="$1"
STATIC_KEY="$2"
ALGORITHM="md5"
UPPERCASE=true

while getopts "a:uh" opt; do
    case $opt in
        a) ALGORITHM="$OPTARG" ;;
        u) UPPERCASE=false ;;
        h) usage ;;
        *) usage ;;
    esac
done

echo "=== Token Deriver ==="
echo "Device ID: $DEVICE_ID"
echo "Static Key: $STATIC_KEY"
echo "Algorithm: $ALGORITHM"
echo ""

# Derive token
case $ALGORITHM in
    md5)
        TOKEN=$(printf "%s" "${DEVICE_ID}${STATIC_KEY}" | md5sum | awk '{print $1}')
        ;;
    sha1)
        TOKEN=$(printf "%s" "${DEVICE_ID}${STATIC_KEY}" | sha1sum | awk '{print $1}')
        ;;
    sha256)
        TOKEN=$(printf "%s" "${DEVICE_ID}${STATIC_KEY}" | sha256sum | awk '{print $1}')
        ;;
    *)
        echo "Error: Unknown algorithm: $ALGORITHM"
        echo "Supported: md5, sha1, sha256"
        exit 1
        ;;
esac

# Convert to uppercase if requested
if [ "$UPPERCASE" = true ]; then
    TOKEN=$(echo "$TOKEN" | tr '[:lower:]' '[:upper:]')
fi

echo "Derived Token: $TOKEN"
echo ""

# Generate cloud config URL template
echo "Cloud Config URL Template:"
echo "  https://<api-host>/pf/${DEVICE_ID}/${TOKEN}"
echo ""

# Show curl command template
echo "Curl command to fetch config:"
echo "  curl -sS 'https://<api-host>/pf/${DEVICE_ID}/${TOKEN}' | jq ."
echo ""

# Show MQTT subscription template
echo "MQTT subscription template:"
echo "  mosquitto_sub -h <broker> -p <port> -V mqttv311 \\"
echo "    -i <client_id> -u <username> -P <password> \\"
echo "    -t '<topic_prefix>/${DEVICE_ID}/admin' -v"
