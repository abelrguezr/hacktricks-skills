#!/usr/bin/env python3
"""
Find all cloud storage artifacts on a Windows system

Usage:
    python list_cloud_artifacts.py <user-profile-path> [options]

Scans for OneDrive, Google Drive, and Dropbox artifacts.

Examples:
    python list_cloud_artifacts.py "C:\\Users\\john"
    python list_cloud_artifacts.py "C:\\Users\\john" --service onedrive
    python list_cloud_artifacts.py "C:\\Users\\john" --output artifacts.json
"""

import os
import sys
import argparse
from pathlib import Path
import json
from typing import Dict, List


class CloudArtifactScanner:
    """Scanner for cloud storage artifacts on Windows systems"""
    
    # Known artifact patterns for each service
    ARTIFACT_PATTERNS = {
        'onedrive': {
            'base_path': r'AppData\Local\Microsoft\OneDrive',
            'files': [
                r'logs\Personal\SyncDiagnostics.log',
                r'logs\Personal\*.log',
                r'*.ini',
                r'*.dat',
            ],
            'description': 'Microsoft OneDrive synchronization artifacts'
        },
        'googledrive': {
            'base_path': r'AppData\Local\Google\Drive',
            'files': [
                r'user_default\Sync_log.log',
                r'user_default\Cloud_graph\Cloud_graph.db',
                r'user_default\Sync_config.db',
                r'user_default\*.db',
            ],
            'description': 'Google Drive for Desktop artifacts'
        },
        'dropbox': {
            'base_path': r'AppData\Local\Dropbox',
            'files': [
                r'*.dbx',
                r'Instance*\*.dbx',
                r'AppData\Roaming\Dropbox\*.dbx',
            ],
            'description': 'Dropbox encrypted database artifacts'
        }
    }
    
    def __init__(self, user_profile: str):
        """
        Initialize scanner for a user profile
        
        Args:
            user_profile: Path to user profile directory
        """
        self.user_profile = Path(user_profile)
        self.results: Dict[str, List[Dict]] = {}
    
    def scan_service(self, service: str) -> List[Dict]:
        """
        Scan for artifacts of a specific cloud service
        
        Args:
            service: Service name ('onedrive', 'googledrive', 'dropbox')
            
        Returns:
            List of found artifacts with metadata
        """
        if service not in self.ARTIFACT_PATTERNS:
            print(f"Unknown service: {service}", file=sys.stderr)
            return []
        
        pattern = self.ARTIFACT_PATTERNS[service]
        base_path = self.user_profile / pattern['base_path']
        artifacts = []
        
        print(f"\nScanning {pattern['description']}...")
        print(f"Base path: {base_path}")
        
        if not base_path.exists():
            print(f"  Not found: {base_path}")
            return []
        
        print(f"  Found base directory")
        
        # Scan for each file pattern
        for file_pattern in pattern['files']:
            search_path = base_path / file_pattern
            
            # Handle wildcards
            if '*' in file_pattern:
                # Use glob for wildcard patterns
                matched = list(base_path.rglob(file_pattern.replace('\\', os.sep)))
            else:
                matched = [search_path] if search_path.exists() else []
            
            for artifact_path in matched:
                if artifact_path.exists():
                    stat = artifact_path.stat()
                    artifact_info = {
                        'path': str(artifact_path),
                        'size_bytes': stat.st_size,
                        'modified_time': stat.st_mtime,
                        'type': 'file' if artifact_path.is_file() else 'directory'
                    }
                    artifacts.append(artifact_info)
                    print(f"  Found: {artifact_path.relative_to(self.user_profile)}")
        
        return artifacts
    
    def scan_all(self) -> Dict[str, List[Dict]]:
        """
        Scan for all cloud service artifacts
        
        Returns:
            Dictionary mapping service names to artifact lists
        """
        for service in self.ARTIFACT_PATTERNS:
            self.results[service] = self.scan_service(service)
        
        return self.results
    
    def get_summary(self) -> Dict:
        """
        Get summary of scan results
        
        Returns:
            Summary dictionary with counts and paths
        """
        summary = {
            'user_profile': str(self.user_profile),
            'services': {}
        }
        
        for service, artifacts in self.results.items():
            summary['services'][service] = {
                'count': len(artifacts),
                'total_size_bytes': sum(a['size_bytes'] for a in artifacts),
                'paths': [a['path'] for a in artifacts]
            }
        
        return summary
    
    def export_json(self, output_path: str) -> None:
        """
        Export results to JSON file
        
        Args:
            output_path: Path for output JSON file
        """
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(self.results, f, indent=2, default=str)
        print(f"\nExported results to {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description='Find cloud storage artifacts on Windows systems'
    )
    parser.add_argument(
        'user_profile',
        help='Path to user profile directory (e.g., C:\\Users\\john)'
    )
    parser.add_argument(
        '--service', '-s',
        choices=['onedrive', 'googledrive', 'dropbox', 'all'],
        default='all',
        help='Specific service to scan (default: all)'
    )
    parser.add_argument(
        '--output', '-o',
        metavar='FILE',
        help='Export results to JSON file'
    )
    parser.add_argument(
        '--quiet', '-q',
        action='store_true',
        help='Suppress progress output'
    )
    
    args = parser.parse_args()
    
    user_profile = Path(args.user_profile)
    
    if not user_profile.exists():
        print(f"Error: User profile not found: {args.user_profile}", file=sys.stderr)
        sys.exit(1)
    
    scanner = CloudArtifactScanner(str(user_profile))
    
    if args.service == 'all':
        results = scanner.scan_all()
    else:
        results = {args.service: scanner.scan_service(args.service)}
    
    # Print summary
    if not args.quiet:
        print("\n" + "=" * 60)
        print("SCAN SUMMARY")
        print("=" * 60)
        
        summary = scanner.get_summary()
        
        for service, data in summary['services'].items():
            if data['count'] > 0:
                print(f"\n{service.upper()}:")
                print(f"  Artifacts found: {data['count']}")
                print(f"  Total size: {data['total_size_bytes']:,} bytes")
    
    # Export if requested
    if args.output:
        scanner.export_json(args.output)


if __name__ == '__main__':
    main()
