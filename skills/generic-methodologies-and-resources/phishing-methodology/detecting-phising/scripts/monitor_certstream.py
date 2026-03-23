#!/usr/bin/env python3
"""Monitor Certificate Transparency logs for brand keywords.

Usage:
    python monitor_certstream.py <brand-keyword> [--output FILE]
    python monitor_certstream.py paypal --output alerts.json

This script connects to CertStream and monitors for certificates
containing your brand keyword in real-time.

Note: This is a simplified version. For production use, consider
the official certstream tools or phishing_catcher.
"""

import sys
import json
import time
import ssl
import socket
from datetime import datetime


def connect_to_certstream():
    """Connect to CertStream public server."""
    # CertStream uses a WebSocket-like protocol over TLS
    # This is a simplified connection - for full functionality,
    # use the official certstream tools
    
    host = "certstream.calidog.io"
    port = 443
    
    try:
        sock = socket.create_connection((host, port), timeout=10)
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        ssock = context.wrap_socket(sock, server_hostname=host)
        return ssock
    except Exception as e:
        print(f"Error connecting to CertStream: {e}", file=sys.stderr)
        return None


def parse_certstream_message(data: bytes) -> dict:
    """Parse a CertStream message."""
    try:
        # CertStream messages are JSON
        return json.loads(data.decode('utf-8'))
    except (json.JSONDecodeError, UnicodeDecodeError):
        return None


def check_certificate(cert_data: dict, keyword: str) -> bool:
    """Check if certificate contains the brand keyword."""
    if not cert_data:
        return False
    
    # Check various fields for the keyword
    keyword_lower = keyword.lower()
    
    # Check certificate names
    names = cert_data.get('names', [])
    for name in names:
        if keyword_lower in name.lower():
            return True
    
    # Check raw certificate data
    raw = cert_data.get('raw', '')
    if keyword_lower in raw.lower():
        return True
    
    return False


def main():
    if len(sys.argv) < 2:
        print("Usage: python monitor_certstream.py <brand-keyword> [--output FILE]")
        print("Example: python monitor_certstream.py paypal --output alerts.json")
        sys.exit(1)
    
    keyword = sys.argv[1]
    output_file = None
    
    # Parse optional arguments
    i = 2
    while i < len(sys.argv):
        if sys.argv[i] == "--output" and i + 1 < len(sys.argv):
            output_file = sys.argv[i + 1]
            i += 2
        else:
            i += 1
    
    print(f"Monitoring CertStream for keyword: {keyword}")
    print("Press Ctrl+C to stop")
    print("-" * 50)
    
    alerts = []
    
    try:
        ssock = connect_to_certstream()
        if not ssock:
            sys.exit(1)
        
        print("Connected to CertStream. Monitoring...")
        print()
        
        buffer = b''
        start_time = time.time()
        
        while True:
            try:
                data = ssock.recv(4096)
                if not data:
                    break
                
                buffer += data
                
                # Process complete JSON messages
                while b'}' in buffer:
                    try:
                        end_idx = buffer.index(b'}') + 1
                        message = buffer[:end_idx]
                        buffer = buffer[end_idx:]
                        
                        cert_data = parse_certstream_message(message)
                        
                        if cert_data and check_certificate(cert_data, keyword):
                            timestamp = datetime.now().isoformat()
                            
                            alert = {
                                'timestamp': timestamp,
                                'keyword': keyword,
                                'names': cert_data.get('names', []),
                                'tags': cert_data.get('tags', []),
                                'log': cert_data.get('log', 'unknown'),
                            }
                            
                            alerts.append(alert)
                            
                            print(f"\n[ALERT] {timestamp}")
                            print(f"  Names: {alert['names']}")
                            print(f"  Tags: {alert['tags']}")
                            print(f"  Log: {alert['log']}")
                            print()
                            
                            # Save to file if specified
                            if output_file:
                                with open(output_file, 'a') as f:
                                    json.dump(alert, f)
                                    f.write('\n')
                            
                    except (ValueError, IndexError):
                        # Incomplete message, continue buffering
                        break
                        
            except socket.timeout:
                continue
            except KeyboardInterrupt:
                print("\n\nStopping monitor...")
                break
        
        print(f"\n{'=' * 50}")
        print(f"Total alerts: {len(alerts)}")
        if output_file:
            print(f"Alerts saved to: {output_file}")
        
    except KeyboardInterrupt:
        print("\n\nStopping monitor...")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
