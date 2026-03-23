#!/usr/bin/env python3
"""
Extract Indicators of Compromise (IOCs) from mobile malware analysis.
Usage: python extract_iocs.py <apk-file> [--output <json-file>]
"""

import sys
import zipfile
import re
import json
import hashlib
from pathlib import Path
from datetime import datetime


def extract_strings(apk_path: str) -> list:
    """Extract strings from APK."""
    strings = []
    
    try:
        with zipfile.ZipFile(apk_path, 'r') as apk:
            # Extract from classes.dex
            for name in apk.namelist():
                if name.endswith('.dex') or name.endswith('.xml'):
                    content = apk.read(name)
                    # Extract URLs
                    urls = re.findall(r'https?://[\w\-._~:/?#\[\]@!$&\'()*+,;=%]+', content.decode('latin-1', errors='ignore'))
                    strings.extend(urls)
                    
                    # Extract IP addresses
                    ips = re.findall(r'\b(?:\d{1,3}\.){3}\d{1,3}\b', content.decode('latin-1', errors='ignore'))
                    strings.extend(ips)
                    
                    # Extract email addresses
                    emails = re.findall(r'[\w\.-]+@[\w\.-]+\.\w+', content.decode('latin-1', errors='ignore'))
                    strings.extend(emails)
    
    except Exception as e:
        print(f"Warning: Could not extract strings: {e}")
    
    return list(set(strings))


def extract_endpoints(strings: list) -> dict:
    """Categorize extracted strings as potential C2 endpoints."""
    endpoints = {
        "c2_paths": [],
        "upload_paths": [],
        "config_paths": [],
        "domains": [],
        "ips": [],
        "emails": []
    }
    
    suspicious_paths = [
        'upload', 'check', 'code', 'config', 'cmd', 'control',
        'beacon', 'callback', 'exfil', 'data', 'sms', 'contact'
    ]
    
    for s in strings:
        # Check for suspicious paths
        if any(path in s.lower() for path in suspicious_paths):
            if 'upload' in s.lower():
                endpoints['upload_paths'].append(s)
            elif 'check' in s.lower() or 'code' in s.lower():
                endpoints['config_paths'].append(s)
            else:
                endpoints['c2_paths'].append(s)
        
        # Extract domain from URL
        url_match = re.match(r'https?://([^/]+)', s)
        if url_match:
            endpoints['domains'].append(url_match.group(1))
        
        # Check for IP
        if re.match(r'\b(?:\d{1,3}\.){3}\d{1,3}\b', s):
            endpoints['ips'].append(s)
        
        # Check for email
        if '@' in s:
            endpoints['emails'].append(s)
    
    # Deduplicate
    for key in endpoints:
        endpoints[key] = list(set(endpoints[key]))
    
    return endpoints


def calculate_hashes(apk_path: str) -> dict:
    """Calculate file hashes."""
    hashes = {}
    
    try:
        with open(apk_path, 'rb') as f:
            content = f.read()
            hashes['md5'] = hashlib.md5(content).hexdigest()
            hashes['sha1'] = hashlib.sha1(content).hexdigest()
            hashes['sha256'] = hashlib.sha256(content).hexdigest()
            hashes['sha512'] = hashlib.sha512(content).hexdigest()
            hashes['size'] = len(content)
    except Exception as e:
        print(f"Error calculating hashes: {e}")
    
    return hashes


def extract_iocs(apk_path: str) -> dict:
    """Extract all IOCs from APK."""
    iocs = {
        "metadata": {
            "filename": Path(apk_path).name,
            "analysis_date": datetime.now().isoformat(),
            "tool": "mobile-phishing-analysis"
        },
        "file_hashes": calculate_hashes(apk_path),
        "network_iocs": {},
        "behavioral_iocs": [],
        "strings_of_interest": []
    }
    
    # Extract strings and endpoints
    strings = extract_strings(apk_path)
    iocs['network_iocs'] = extract_endpoints(strings)
    
    # Check for behavioral indicators
    try:
        with zipfile.ZipFile(apk_path, 'r') as apk:
            # Check for embedded payloads
            for name in apk.namelist():
                if name.endswith('.apk') and 'assets' in name:
                    iocs['behavioral_iocs'].append({
                        "type": "dropper",
                        "description": "Embedded APK in assets directory",
                        "path": name
                    })
            
            # Check manifest for suspicious permissions
            if 'AndroidManifest.xml' in apk.namelist():
                manifest = apk.read('AndroidManifest.xml').decode('latin-1', errors='ignore')
                
                if 'AccessibilityService' in manifest:
                    iocs['behavioral_iocs'].append({
                        "type": "accessibility_abuse",
                        "description": "Accessibility service detected"
                    })
                
                if 'DeviceAdminReceiver' in manifest:
                    iocs['behavioral_iocs'].append({
                        "type": "device_admin",
                        "description": "Device Admin receiver detected"
                    })
                
                if 'PackageInstaller' in manifest:
                    iocs['behavioral_iocs'].append({
                        "type": "package_installer",
                        "description": "Package Installer API usage detected"
                    })
    
    except Exception as e:
        print(f"Warning: Could not check behavioral IOCs: {e}")
    
    return iocs


def main():
    if len(sys.argv) < 2:
        print("Usage: python extract_iocs.py <apk-file> [--output <json-file>]")
        sys.exit(1)
    
    apk_path = sys.argv[1]
    output_file = None
    
    if len(sys.argv) >= 4 and sys.argv[2] == '--output':
        output_file = sys.argv[3]
    
    if not Path(apk_path).exists():
        print(f"Error: File not found: {apk_path}")
        sys.exit(1)
    
    print(f"\nExtracting IOCs from: {apk_path}")
    print("=" * 60)
    
    iocs = extract_iocs(apk_path)
    
    # Display results
    print(f"\n📁 FILE INFO:")
    print(f"  Filename: {iocs['metadata']['filename']}")
    print(f"  Size: {iocs['file_hashes'].get('size', 'N/A')} bytes")
    print(f"  SHA256: {iocs['file_hashes'].get('sha256', 'N/A')}")
    
    if iocs['network_iocs']['domains']:
        print(f"\n🌐 DOMAINS ({len(iocs['network_iocs']['domains'])}):")
        for domain in iocs['network_iocs']['domains'][:10]:
            print(f"  - {domain}")
        if len(iocs['network_iocs']['domains']) > 10:
            print(f"  ... and {len(iocs['network_iocs']['domains']) - 10} more")
    
    if iocs['network_iocs']['c2_paths']:
        print(f"\n🎯 POTENTIAL C2 PATHS ({len(iocs['network_iocs']['c2_paths'])}):")
        for path in iocs['network_iocs']['c2_paths'][:10]:
            print(f"  - {path}")
    
    if iocs['network_iocs']['upload_paths']:
        print(f"\n⬆️  UPLOAD PATHS ({len(iocs['network_iocs']['upload_paths'])}):")
        for path in iocs['network_iocs']['upload_paths'][:10]:
            print(f"  - {path}")
    
    if iocs['behavioral_iocs']:
        print(f"\n⚠️  BEHAVIORAL IOCs ({len(iocs['behavioral_iocs'])}):")
        for ioc in iocs['behavioral_iocs']:
            print(f"  - {ioc['type']}: {ioc['description']}")
    
    # Save to file if requested
    if output_file:
        with open(output_file, 'w') as f:
            json.dump(iocs, f, indent=2)
        print(f"\n✓ IOCs saved to: {output_file}")
    
    # Summary
    print("\n" + "=" * 60)
    print("IOC SUMMARY:")
    print(f"  Domains: {len(iocs['network_iocs']['domains'])}")
    print(f"  C2 Paths: {len(iocs['network_iocs']['c2_paths'])}")
    print(f"  Upload Paths: {len(iocs['network_iocs']['upload_paths'])}")
    print(f"  Behavioral IOCs: {len(iocs['behavioral_iocs'])}")


if __name__ == "__main__":
    main()
