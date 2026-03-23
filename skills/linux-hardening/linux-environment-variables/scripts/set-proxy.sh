#!/bin/bash
# Configure proxy settings with validation

usage() {
    echo "Usage: $0 <proxy_url> [no_proxy_list]"
    echo "Example: $0 http://10.10.10.10:8080 localhost,127.0.0.1"
    echo ""
    echo "Proxy types:"
    echo "  http:// - HTTP proxy"
    echo "  socks5h:// - SOCKS5 proxy (all protocols)"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

PROXY_URL="$1"
NO_PROXY="${2:-localhost,127.0.0.1}"

# Validate URL format
if [[ ! "$PROXY_URL" =~ ^(http|https|socks5h):// ]]; then
    echo "Error: Invalid proxy URL format. Must start with http://, https://, or socks5h://"
    exit 1
fi

echo "Configuring proxy: $PROXY_URL"
echo "No proxy for: $NO_PROXY"

# Set proxy variables
if [[ "$PROXY_URL" =~ ^socks5h:// ]]; then
    export all_proxy="$PROXY_URL"
    export ALL_PROXY="$PROXY_URL"
    echo "Set SOCKS5 proxy"
else
    export http_proxy="$PROXY_URL"
    export https_proxy="$PROXY_URL"
    export HTTP_PROXY="$PROXY_URL"
    export HTTPS_PROXY="$PROXY_URL"
    echo "Set HTTP/HTTPS proxy"
fi

export no_proxy="$NO_PROXY"
export NO_PROXY="$NO_PROXY"

echo ""
echo "Current proxy settings:"
echo "  http_proxy=$http_proxy"
echo "  https_proxy=$https_proxy"
echo "  all_proxy=${all_proxy:-not set}"
echo "  no_proxy=$no_proxy"
echo ""
echo "To make permanent, add these to ~/.bashrc:"
echo "  export http_proxy=\"$PROXY_URL\""
echo "  export https_proxy=\"$PROXY_URL\""
echo "  export no_proxy=\"$NO_PROXY\""
