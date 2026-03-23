#!/usr/bin/env python3
"""analyze-uiaccess-manifest.py

Analyze Windows executable manifests for UIAccess settings and security properties.

Usage:
    python analyze-uiaccess-manifest.py <path-to-exe>
    python analyze-uiaccess-manifest.py --scan <directory>
    python analyze-uiaccess-manifest.py --check-uiaccess <path-to-exe>
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Optional, List


@dataclass
class ManifestInfo:
    """Information extracted from a Windows executable manifest."""
    path: str
    has_manifest: bool
    ui_access: bool
    requested_execution_level: Optional[str]
    supported_os: List[str]
    error: Optional[str] = None


@dataclass
class FileSignature:
    """Code signature information for a Windows executable."""
    path: str
    is_signed: bool
    signer: Optional[str]
    timestamp: Optional[str]
    error: Optional[str] = None


def extract_embedded_manifest(exe_path: str) -> Optional[str]:
    """Extract embedded manifest from a Windows executable.
    
    Uses resource hacking or direct binary parsing to extract the manifest.
    """
    # Try using signtool or similar if available
    try:
        # Check for external manifest first
        manifest_path = exe_path + ".manifest"
        if os.path.exists(manifest_path):
            with open(manifest_path, 'r', encoding='utf-8', errors='ignore') as f:
                return f.read()
    except Exception:
        pass
    
    # Try to extract embedded manifest using Python's struct
    try:
        with open(exe_path, 'rb') as f:
            data = f.read()
        
        # Look for manifest in resources (simplified approach)
        # In production, use proper PE parsing library like pefile
        manifest_marker = b'<assembly xmlns='
        if manifest_marker in data:
            start = data.find(manifest_marker)
            end = data.find(b'</assembly>', start) + len(b'</assembly>')
            if start != -1 and end != -1:
                return data[start:end].decode('utf-8', errors='ignore')
    except Exception as e:
        return None
    
    return None


def parse_manifest(manifest_content: str) -> ManifestInfo:
    """Parse manifest XML and extract relevant fields."""
    if not manifest_content:
        return ManifestInfo(
            path="",
            has_manifest=False,
            ui_access=False,
            requested_execution_level=None,
            supported_os=[],
            error="No manifest content"
        )
    
    ui_access = False
    execution_level = None
    supported_os = []
    
    # Check for uiAccess="true"
    ui_access_match = re.search(r'uiAccess=["\']true["\']', manifest_content, re.IGNORECASE)
    ui_access = ui_access_match is not None
    
    # Check for requestedExecutionLevel
    exec_level_match = re.search(
        r'<requestedExecutionLevel[^>]*level=["\']([^"\']+)["\']',
        manifest_content,
        re.IGNORECASE
    )
    if exec_level_match:
        execution_level = exec_level_match.group(1)
    
    # Check for supportedOS
    os_matches = re.findall(
        r'<supportedOS[^>]*{[^}]*}[^>]*>',
        manifest_content,
        re.IGNORECASE
    )
    for os_match in os_matches:
        os_id = re.search(r'\{([^}]+)\}', os_match)
        if os_id:
            supported_os.append(os_id.group(1))
    
    return ManifestInfo(
        path="",
        has_manifest=True,
        ui_access=ui_access,
        requested_execution_level=execution_level,
        supported_os=supported_os
    )


def check_file_signature(exe_path: str) -> FileSignature:
    """Check if a file is code-signed.
    
    Uses signtool if available, otherwise performs basic checks.
    """
    try:
        # Try signtool (Windows)
        result = subprocess.run(
            ['signtool', 'verify', '/v', exe_path],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            # Parse signer from output
            signer = None
            for line in result.stdout.split('\n'):
                if 'Signer' in line or 'Issuer' in line:
                    signer = line.split(':')[-1].strip()
                    break
            
            return FileSignature(
                path=exe_path,
                is_signed=True,
                signer=signer,
                timestamp=None
            )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    
    # Fallback: check for signature block in PE file
    try:
        with open(exe_path, 'rb') as f:
            data = f.read()
        
        # Look for Authenticode signature marker (simplified)
        if b'Authenticode' in data or b'PKCS#7' in data:
            return FileSignature(
                path=exe_path,
                is_signed=True,
                signer="Unknown (signature block detected)",
                timestamp=None
            )
    except Exception:
        pass
    
    return FileSignature(
        path=exe_path,
        is_signed=False,
        signer=None,
        timestamp=None
    )


def analyze_executable(exe_path: str) -> dict:
    """Analyze a single executable for UIAccess properties."""
    result = {
        'path': exe_path,
        'exists': os.path.exists(exe_path),
        'is_executable': exe_path.lower().endswith(('.exe', '.dll')),
        'manifest': None,
        'signature': None,
        'risk_assessment': None
    }
    
    if not result['exists']:
        result['risk_assessment'] = 'File does not exist'
        return result
    
    # Extract and parse manifest
    manifest_content = extract_embedded_manifest(exe_path)
    manifest_info = parse_manifest(manifest_content or '')
    manifest_info.path = exe_path
    result['manifest'] = asdict(manifest_info)
    
    # Check signature
    sig_info = check_file_signature(exe_path)
    sig_info.path = exe_path
    result['signature'] = asdict(sig_info)
    
    # Risk assessment
    risks = []
    if manifest_info.ui_access and not sig_info.is_signed:
        risks.append('UIAccess enabled but not signed - HIGH RISK')
    elif manifest_info.ui_access and sig_info.is_signed:
        risks.append('UIAccess enabled and signed - verify signer trust')
    
    if manifest_info.requested_execution_level == 'requireAdministrator':
        risks.append('Requests administrator privileges')
    
    result['risk_assessment'] = '; '.join(risks) if risks else 'No immediate risks detected'
    
    return result


def scan_directory(directory: str, recursive: bool = True) -> List[dict]:
    """Scan a directory for executables with UIAccess manifests."""
    results = []
    
    for root, dirs, files in os.walk(directory) if recursive else os.walk(directory, topdown=True):
        if not recursive and root != directory:
            break
        
        for file in files:
            if file.lower().endswith(('.exe', '.dll')):
                file_path = os.path.join(root, file)
                results.append(analyze_executable(file_path))
    
    return results


def main():
    parser = argparse.ArgumentParser(
        description='Analyze Windows executables for UIAccess manifest properties'
    )
    parser.add_argument('path', nargs='?', help='Path to executable or directory')
    parser.add_argument('--scan', action='store_true', help='Scan directory recursively')
    parser.add_argument('--check-uiaccess', action='store_true', help='Check only for UIAccess setting')
    parser.add_argument('--output', '-o', help='Output file for JSON results')
    parser.add_argument('--json', action='store_true', help='Output as JSON')
    
    args = parser.parse_args()
    
    if not args.path:
        parser.print_help()
        sys.exit(1)
    
    path = Path(args.path).resolve()
    
    if path.is_dir():
        results = scan_directory(str(path), recursive=args.scan)
    else:
        results = [analyze_executable(str(path))]
    
    # Filter for UIAccess if requested
    if args.check_uiaccess:
        results = [r for r in results if r.get('manifest', {}).get('ui_access', False)]
    
    # Output results
    if args.json:
        output = json.dumps(results, indent=2)
        if args.output:
            with open(args.output, 'w') as f:
                f.write(output)
        else:
            print(output)
    else:
        for result in results:
            print(f"\n{'='*60}")
            print(f"File: {result['path']}")
            print(f"Exists: {result['exists']}")
            
            if result.get('manifest'):
                m = result['manifest']
                print(f"Has Manifest: {m['has_manifest']}")
                print(f"UIAccess: {m['ui_access']}")
                print(f"Execution Level: {m['requested_execution_level']}")
            
            if result.get('signature'):
                s = result['signature']
                print(f"Signed: {s['is_signed']}")
                print(f"Signer: {s['signer']}")
            
            print(f"Risk: {result['risk_assessment']}")
    
    # Summary
    uiaccess_count = sum(1 for r in results if r.get('manifest', {}).get('ui_access'))
    print(f"\n{'='*60}")
    print(f"Summary: {len(results)} files analyzed, {uiaccess_count} with UIAccess enabled")


if __name__ == '__main__':
    main()
