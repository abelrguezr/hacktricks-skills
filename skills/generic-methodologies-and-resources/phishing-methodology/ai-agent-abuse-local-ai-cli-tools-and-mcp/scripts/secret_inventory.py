#!/usr/bin/env python3
"""Authorized Secrets Inventory Scanner

Scan for potential secrets and credentials in authorized environments.
For security testing and authorized audits only.

Usage:
    python secret_inventory.py --depth 3 --output /tmp/inventory.txt
    python secret_inventory.py --paths ~/.ssh ~/.aws --output secrets.json
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import List, Dict, Any


class SecretInventory:
    """Scan for potential secrets in authorized environments"""
    
    # File patterns to match
    SECRET_PATTERNS = [
        # SSH keys
        "id_rsa", "id_dsa", "id_ecdsa", "id_ed25519",
        "*.pem", "*.key",
        
        # AWS/Cloud credentials
        "credentials", "config",  # .aws/
        "config.json",  # gcloud, azure
        
        # Environment files
        ".env", ".env.*", "*.env",
        
        # Crypto wallets
        "keystore.json", "wallet.json",
        
        # Git credentials
        "credentials", "config",  # .git/
        
        # Browser data
        "Login Data", "Login Data-journal",
        "Web Data", "Cookies",
        
        # GPG
        "private-keys-v1.d",
        
        # Kubernetes
        "kubeconfig", "config",  # .kube/
        
        # Docker
        "config.json",  # .docker/
        
        # NPM/Yarn
        ".npmrc", ".yarnrc",
        
        # Python
        "pip.conf", "pip.ini",
        
        # General secrets
        "secrets", "secret", "password", "passwd",
        "private", "private_key",
    ]
    
    # Directories to scan
    DEFAULT_DIRS = [
        "~/.ssh",
        "~/.aws",
        "~/.kube",
        "~/.gnupg",
        "~/.docker",
        "~/.npm",
        "~/.config",
        "~/.local/share",
    ]
    
    # Paths to skip
    SKIP_PATHS = [
        "/proc", "/sys", "/dev", "/run",
        "/tmp", "/var/tmp",
    ]
    
    def __init__(self, paths: List[str] = None, max_depth: int = 3, 
                 output_path: str = None, verbose: bool = False):
        self.paths = [Path(p).expanduser() for p in (paths or self.DEFAULT_DIRS)]
        self.max_depth = max_depth
        self.output_path = output_path
        self.verbose = verbose
        self.findings: List[Dict[str, Any]] = []
        self.start_time = time.time()
    
    def _should_skip(self, path: Path) -> bool:
        """Check if path should be skipped"""
        path_str = str(path)
        for skip in self.SKIP_PATHS:
            if path_str.startswith(skip):
                return True
        return False
    
    def _get_depth(self, path: Path, base: Path) -> int:
        """Calculate depth from base path"""
        try:
            return len(path.relative_to(base).parts)
        except ValueError:
            return 0
    
    def _matches_pattern(self, name: str) -> bool:
        """Check if filename matches secret patterns"""
        name_lower = name.lower()
        for pattern in self.SECRET_PATTERNS:
            pattern_lower = pattern.lower()
            if pattern_lower.startswith("*"):
                # Wildcard pattern
                if name_lower.endswith(pattern_lower[1:]):
                    return True
            elif pattern_lower in name_lower:
                return True
        return False
    
    def scan_path(self, path: Path) -> List[Dict[str, Any]]:
        """Scan a single path for secrets"""
        if not path.exists():
            if self.verbose:
                print(f"[-] Path does not exist: {path}")
            return []
        
        if self._should_skip(path):
            if self.verbose:
                print(f"[-] Skipping protected path: {path}")
            return []
        
        findings = []
        
        try:
            for item in path.iterdir():
                current_depth = self._get_depth(item, path)
                
                if current_depth > self.max_depth:
                    continue
                
                if self._should_skip(item):
                    continue
                
                if item.is_file() and self._matches_pattern(item.name):
                    finding = {
                        "type": "file",
                        "path": str(item.absolute()),
                        "name": item.name,
                        "size": item.stat().st_size,
                        "modified": item.stat().st_mtime
                    }
                    findings.append(finding)
                    
                    if self.verbose:
                        print(f"[+] Found: {item.absolute()}")
                
                elif item.is_dir() and self._matches_pattern(item.name):
                    finding = {
                        "type": "directory",
                        "path": str(item.absolute()),
                        "name": item.name
                    }
                    findings.append(finding)
                    
                    if self.verbose:
                        print(f"[+] Found directory: {item.absolute()}")
                    
                    # Recurse into matching directories
                    if current_depth < self.max_depth:
                        findings.extend(self.scan_path(item))
        
        except PermissionError:
            if self.verbose:
                print(f"[-] Permission denied: {path}")
        except Exception as e:
            if self.verbose:
                print(f"[-] Error scanning {path}: {e}")
        
        return findings
    
    def scan(self) -> List[Dict[str, Any]]:
        """Scan all configured paths"""
        print(f"[*] Starting secrets inventory scan...")
        print(f"[*] Paths: {len(self.paths)}")
        print(f"[*] Max depth: {self.max_depth}")
        print()
        
        for path in self.paths:
            if self.verbose:
                print(f"[*] Scanning: {path}")
            findings = self.scan_path(path)
            self.findings.extend(findings)
        
        duration = time.time() - self.start_time
        print(f"\n[*] Scan complete. Found {len(self.findings)} potential secrets in {duration:.2f}s")
        
        return self.findings
    
    def save_inventory(self) -> None:
        """Save inventory to output file"""
        if not self.output_path:
            return
        
        # Handle backup if file exists
        output = Path(self.output_path)
        if output.exists():
            backup = Path(f"{self.output_path}.bak-{int(time.time())}")
            output.rename(backup)
            print(f"[+] Backed up existing inventory to {backup}")
        
        # Save as JSON
        report = {
            "scan_time": time.strftime("%Y-%m-%d %H:%M:%S"),
            "paths_scanned": [str(p) for p in self.paths],
            "max_depth": self.max_depth,
            "total_findings": len(self.findings),
            "findings": self.findings
        }
        
        with open(output, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"[+] Inventory saved to {self.output_path}")
    
    def print_summary(self) -> None:
        """Print summary of findings"""
        if not self.findings:
            print("[+] No potential secrets found")
            return
        
        print(f"\n{'='*60}")
        print(f"SECRETS INVENTORY SUMMARY")
        print(f"{'='*60}")
        
        # Group by type
        by_type = {"file": [], "directory": []}
        for finding in self.findings:
            ftype = finding.get("type", "unknown")
            if ftype in by_type:
                by_type[ftype].append(finding)
        
        print(f"\nFiles: {len(by_type['file'])}")
        for finding in by_type["file"][:10]:  # Show first 10
            print(f"  - {finding['path']}")
        if len(by_type["file"]) > 10:
            print(f"  ... and {len(by_type['file']) - 10} more")
        
        print(f"\nDirectories: {len(by_type['directory'])}")
        for finding in by_type["directory"]:
            print(f"  - {finding['path']}")
        
        print(f"\n{'='*60}")
        print(f"Total: {len(self.findings)} items")
        print(f"{'='*60}")


def main():
    parser = argparse.ArgumentParser(
        description="Authorized Secrets Inventory Scanner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
WARNING: This tool is for authorized security testing only.
Ensure you have explicit permission before scanning any systems.

Examples:
    python secret_inventory.py --depth 3 --output /tmp/inventory.txt
    python secret_inventory.py --paths ~/.ssh ~/.aws --output secrets.json
    python secret_inventory.py --verbose
        """
    )
    
    parser.add_argument("--paths", nargs="*", help="Paths to scan (default: common secret locations)")
    parser.add_argument("--depth", type=int, default=3, help="Maximum recursion depth (default: 3)")
    parser.add_argument("--output", "-o", help="Output file path")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    
    args = parser.parse_args()
    
    scanner = SecretInventory(
        paths=args.paths,
        max_depth=args.depth,
        output_path=args.output,
        verbose=args.verbose
    )
    
    scanner.scan()
    scanner.print_summary()
    scanner.save_inventory()


if __name__ == "__main__":
    main()
