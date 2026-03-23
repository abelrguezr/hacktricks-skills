#!/usr/bin/env python3
"""
Analyze VBA macros for form-based data hiding

Usage:
    python analyze_forms.py macros_directory/
    python analyze_forms.py macros_directory/ -o report.txt
"""

import argparse
import re
from pathlib import Path
from typing import Dict, List, Optional


class FormAnalyzer:
    """Analyzes VBA code for form-based obfuscation."""
    
    def __init__(self):
        self.form_references: List[Dict] = []
        self.text_box_data: List[Dict] = []
        self.getobject_calls: List[Dict] = []
    
    def analyze_file(self, file_path: Path) -> Dict:
        """Analyze a single VBA file for form patterns."""
        findings = {
            'form_references': [],
            'text_box_data': [],
            'getobject_calls': []
        }
        
        try:
            content = file_path.read_text(encoding='utf-8', errors='ignore')
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return findings
        
        lines = content.split('\n')
        
        for line_num, line in enumerate(lines, 1):
            line_stripped = line.strip()
            
            # Check for GetObject calls
            if self._analyze_getobject(line_stripped, line_num, file_path):
                pass  # Already added to self.getobject_calls
            
            # Check for form references
            if self._analyze_form_reference(line_stripped, line_num, file_path):
                pass  # Already added to self.form_references
            
            # Check for text box data access
            if self._analyze_text_box(line_stripped, line_num, file_path):
                pass  # Already added to self.text_box_data
        
        return findings
    
    def _analyze_getobject(self, line: str, line_num: int, file_path: Path) -> bool:
        """Analyze GetObject calls for form references."""
        # Pattern: GetObject("Forms!FormName") or GetObject(Forms!...)
        patterns = [
            r'GetObject\s*\(\s*["\']?Forms!["\']?\s*([\w]+)',
            r'GetObject\s*\(\s*["\']?UserForms!["\']?\s*([\w]+)',
            r'GetObject\s*\(\s*["\']?([\w]+)Form["\']?',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, line, re.IGNORECASE)
            if match:
                form_name = match.group(1)
                self.getobject_calls.append({
                    'line': line_num,
                    'form_name': form_name,
                    'content': line[:100],
                    'file': str(file_path)
                })
                return True
        
        return False
    
    def _analyze_form_reference(self, line: str, line_num: int, file_path: Path) -> bool:
        """Analyze direct form references."""
        patterns = [
            r'Forms!["\']?([\w]+)["\']?',
            r'UserForms!["\']?([\w]+)["\']?',
            r'\.Form([\d]+)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, line, re.IGNORECASE)
            if match:
                form_name = match.group(1)
                self.form_references.append({
                    'line': line_num,
                    'form_name': form_name,
                    'content': line[:100],
                    'file': str(file_path)
                })
                return True
        
        return False
    
    def _analyze_text_box(self, line: str, line_num: int, file_path: Path) -> bool:
        """Analyze text box data access."""
        patterns = [
            r'\.TextBox([\d]+)\s*\.Text',
            r'\.TextBox([\d]+)\s*\.Value',
            r'\.TextBox([\d]+)\s*\.Caption',
            r'\.TextBox([\d]+)\s*\.Tag',
            r'\.Label([\d]+)\s*\.Caption',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, line, re.IGNORECASE)
            if match:
                control_name = match.group(1)
                self.text_box_data.append({
                    'line': line_num,
                    'control': f"TextBox{control_name}",
                    'content': line[:100],
                    'file': str(file_path)
                })
                return True
        
        return False
    
    def analyze_directory(self, dir_path: Path) -> Dict:
        """Analyze all VBA files in a directory."""
        vba_extensions = {'.bas', '.cls', '.frm', '.vba'}
        
        for file_path in dir_path.rglob('*'):
            if file_path.suffix.lower() in vba_extensions or file_path.suffix == '':
                self.analyze_file(file_path)
        
        return {
            'form_references': self.form_references,
            'text_box_data': self.text_box_data,
            'getobject_calls': self.getobject_calls
        }
    
    def generate_report(self, results: Dict) -> str:
        """Generate a human-readable report."""
        report = []
        report.append("=" * 60)
        report.append("MACRO FORM ANALYSIS REPORT")
        report.append("=" * 60)
        report.append("")
        
        # GetObject calls
        if results['getobject_calls']:
            report.append("GetObject CALLS")
            report.append("-" * 40)
            for call in results['getobject_calls']:
                report.append(f"Line {call['line']}: {call['form_name']}")
                report.append(f"  {call['content']}")
                report.append(f"  File: {call['file']}")
                report.append("")
        else:
            report.append("GetObject CALLS: None found")
            report.append("")
        
        # Form references
        if results['form_references']:
            report.append("FORM REFERENCES")
            report.append("-" * 40)
            for ref in results['form_references']:
                report.append(f"Line {ref['line']}: {ref['form_name']}")
                report.append(f"  {ref['content']}")
                report.append(f"  File: {ref['file']}")
                report.append("")
        else:
            report.append("FORM REFERENCES: None found")
            report.append("")
        
        # Text box data
        if results['text_box_data']:
            report.append("TEXT BOX DATA ACCESS")
            report.append("-" * 40)
            for tb in results['text_box_data']:
                report.append(f"Line {tb['line']}: {tb['control']}")
                report.append(f"  {tb['content']}")
                report.append(f"  File: {tb['file']}")
                report.append("")
        else:
            report.append("TEXT BOX DATA ACCESS: None found")
            report.append("")
        
        # Summary
        report.append("SUMMARY")
        report.append("-" * 40)
        report.append(f"GetObject calls: {len(results['getobject_calls'])}")
        report.append(f"Form references: {len(results['form_references'])}")
        report.append(f"Text box accesses: {len(results['text_box_data'])}")
        
        if results['getobject_calls'] or results['form_references']:
            report.append("")
            report.append("WARNING: Form-based obfuscation detected!")
            report.append("Data may be hidden in form controls.")
        
        return "\n".join(report)


def main():
    parser = argparse.ArgumentParser(
        description='Analyze VBA macros for form-based data hiding'
    )
    parser.add_argument(
        'directory',
        type=Path,
        help='Directory containing VBA macro files'
    )
    parser.add_argument(
        '-o', '--output',
        type=Path,
        help='Output report file (default: stdout)'
    )
    
    args = parser.parse_args()
    
    if not args.directory.exists():
        print(f"Error: Directory not found: {args.directory}")
        return
    
    analyzer = FormAnalyzer()
    results = analyzer.analyze_directory(args.directory)
    report = analyzer.generate_report(results)
    
    if args.output:
        args.output.write_text(report)
        print(f"Report saved to: {args.output}")
    else:
        print(report)


if __name__ == '__main__':
    main()
