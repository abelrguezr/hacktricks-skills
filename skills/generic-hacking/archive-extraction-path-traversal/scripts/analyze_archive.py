#!/usr/bin/env python3
"""Analyze archive files for path traversal vulnerabilities.

Usage:
    python analyze_archive.py --file suspicious.zip
    python analyze_archive.py --directory ./downloads/
    python analyze_archive.py --file archive.zip --verbose
"""

import argparse
import zipfile
import os
import sys
from pathlib import Path
from typing import List, Dict, Any


class ArchiveAnalyzer:
    """Analyze archives for path traversal vulnerabilities."""
    
    DANGEROUS_PATTERNS = [
        ('../', 'Parent directory traversal'),
        ('..\\', 'Parent directory traversal (Windows)'),
        ('/..', 'Path traversal variant'),
        ('\\..', 'Path traversal variant (Windows)'),
    ]
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.results: List[Dict[str, Any]] = []
    
    def check_path(self, path: str) -> List[Dict[str, Any]]:
        """Check a path for dangerous patterns."""
        issues = []
        
        # Check for traversal sequences
        for pattern, description in self.DANGEROUS_PATTERNS:
            if pattern in path:
                issues.append({
                    'type': 'traversal',
                    'pattern': pattern,
                    'description': description,
                    'path': path,
                    'severity': 'HIGH'
                })
        
        # Check for absolute paths (Unix)
        if path.startswith('/'):
            issues.append({
                'type': 'absolute_path',
                'pattern': '/',
                'description': 'Absolute Unix path',
                'path': path,
                'severity': 'HIGH'
            })
        
        # Check for absolute paths (Windows)
        if len(path) > 1 and path[1] == ':' and path[0].isalpha():
            issues.append({
                'type': 'absolute_path',
                'pattern': 'C:',
                'description': 'Absolute Windows path',
                'path': path,
                'severity': 'HIGH'
            })
        
        # Check for UNC paths
        if path.startswith('\\\\'):
            issues.append({
                'type': 'unc_path',
                'pattern': '\\\\',
                'description': 'UNC network path',
                'path': path,
                'severity': 'MEDIUM'
            })
        
        # Check for null bytes (obfuscation)
        if '\x00' in path:
            issues.append({
                'type': 'null_byte',
                'pattern': '\x00',
                'description': 'Null byte obfuscation',
                'path': path,
                'severity': 'MEDIUM'
            })
        
        return issues
    
    def analyze_zip(self, zip_path: str) -> List[Dict[str, Any]]:
        """Analyze a ZIP file for path traversal."""
        issues = []
        
        try:
            with zipfile.ZipFile(zip_path, 'r') as zf:
                for entry in zf.infolist():
                    entry_issues = self.check_path(entry.filename)
                    
                    # Check for symlinks
                    if entry.external_attr >> 16 & 0xA000:
                        entry_issues.append({
                            'type': 'symlink',
                            'pattern': 'symlink',
                            'description': 'Symlink entry (may traverse)',
                            'path': entry.filename,
                            'severity': 'MEDIUM'
                        })
                    
                    for issue in entry_issues:
                        issue['entry'] = entry.filename
                        issues.append(issue)
        except zipfile.BadZipFile:
            issues.append({
                'type': 'error',
                'description': 'Invalid or corrupted ZIP file',
                'severity': 'ERROR'
            })
        except Exception as e:
            issues.append({
                'type': 'error',
                'description': f'Error reading ZIP: {str(e)}',
                'severity': 'ERROR'
            })
        
        return issues
    
    def analyze_directory(self, directory: str) -> Dict[str, List[Dict[str, Any]]]:
        """Analyze all archives in a directory."""
        results = {}
        archive_extensions = {'.zip', '.rar', '.tar', '.gz', '.7z'}
        
        for root, _, files in os.walk(directory):
            for filename in files:
                ext = os.path.splitext(filename)[1].lower()
                if ext in archive_extensions:
                    filepath = os.path.join(root, filename)
                    if ext == '.zip':
                        results[filepath] = self.analyze_zip(filepath)
                    else:
                        results[filepath] = [{
                            'type': 'unsupported',
                            'description': f'Format {ext} not yet supported',
                            'severity': 'INFO'
                        }]
        
        return results
    
    def print_results(self, issues: List[Dict[str, Any]], filename: str = ''):
        """Print analysis results."""
        if not issues:
            print(f"✓ {filename}: No path traversal issues detected")
            return
        
        print(f"\n{'='*60}")
        print(f"Analysis Results: {filename}")
        print(f"{'='*60}")
        
        severity_order = {'ERROR': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3, 'INFO': 4}
        sorted_issues = sorted(issues, key=lambda x: severity_order.get(x.get('severity', 'INFO'), 5))
        
        for i, issue in enumerate(sorted_issues, 1):
            severity = issue.get('severity', 'INFO')
            icon = {'ERROR': '✗', 'HIGH': '⚠', 'MEDIUM': '!', 'LOW': 'i', 'INFO': '•'}.get(severity, '•')
            
            print(f"\n{i}. [{severity}] {icon} {issue.get('type', 'unknown')}")
            print(f"   Description: {issue.get('description', 'N/A')}")
            
            if 'path' in issue:
                print(f"   Path: {issue['path']}")
            if 'entry' in issue:
                print(f"   Entry: {issue['entry']}")
            if 'pattern' in issue:
                print(f"   Pattern: {repr(issue['pattern'])}")
        
        print(f"\nTotal issues: {len(issues)}")
        high_count = sum(1 for i in issues if i.get('severity') == 'HIGH')
        if high_count > 0:
            print(f"⚠ HIGH severity issues: {high_count}")


def main():
    parser = argparse.ArgumentParser(
        description='Analyze archive files for path traversal vulnerabilities'
    )
    
    file_group = parser.add_mutually_exclusive_group(required=True)
    file_group.add_argument('--file', '-f', help='Single archive file to analyze')
    file_group.add_argument('--directory', '-d', help='Directory to scan for archives')
    
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    parser.add_argument('--json', action='store_true', help='Output as JSON')
    
    args = parser.parse_args()
    
    analyzer = ArchiveAnalyzer(verbose=args.verbose)
    
    if args.file:
        issues = analyzer.analyze_zip(args.file)
        if args.json:
            import json
            print(json.dumps({'file': args.file, 'issues': issues}, indent=2))
        else:
            analyzer.print_results(issues, args.file)
    elif args.directory:
        results = analyzer.analyze_directory(args.directory)
        if args.json:
            import json
            print(json.dumps(results, indent=2))
        else:
            for filepath, issues in results.items():
                analyzer.print_results(issues, filepath)


if __name__ == '__main__':
    main()
