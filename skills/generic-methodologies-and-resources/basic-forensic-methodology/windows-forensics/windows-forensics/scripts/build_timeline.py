#!/usr/bin/env python3
"""
Build a forensic timeline from multiple Windows artifact sources.
Usage: python build_timeline.py --input <json_file> --output <output_file>

This script helps correlate timestamps from different artifact types
to build a comprehensive timeline of system activity.
"""

import argparse
import json
import os
from datetime import datetime
from collections import defaultdict

def parse_timestamp(timestamp_str):
    """Parse various timestamp formats to datetime object."""
    formats = [
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%dT%H:%M:%S.%f",
        "%Y-%m-%dT%H:%M:%SZ",
        "%m/%d/%Y %H:%M:%S",
        "%d/%m/%Y %H:%M:%S",
    ]
    
    for fmt in formats:
        try:
            return datetime.strptime(timestamp_str, fmt)
        except ValueError:
            continue
    
    # If all else fails, return the string as-is
    return timestamp_str

def load_artifact_data(input_file):
    """Load artifact data from JSON file."""
    if not os.path.exists(input_file):
        print(f"Error: Input file not found: {input_file}")
        return None
    
    with open(input_file, 'r', encoding='utf-8') as f:
        return json.load(f)

def build_timeline(artifact_data):
    """
    Build a timeline from artifact data.
    
    Expected input format:
    {
        "artifacts": [
            {
                "source": "prefetch|lnk|jumplist|event_log|registry",
                "timestamp": "2024-01-15 10:30:00",
                "event_type": "execution|access|creation",
                "details": "Program name or file path",
                "user": "username (optional)",
                "additional_info": "Any other relevant details"
            }
        ]
    }
    """
    
    timeline = []
    
    for artifact in artifact_data.get("artifacts", []):
        timestamp = parse_timestamp(artifact.get("timestamp", ""))
        
        timeline_entry = {
            "timestamp": artifact.get("timestamp", ""),
            "source": artifact.get("source", "unknown"),
            "event_type": artifact.get("event_type", "unknown"),
            "details": artifact.get("details", ""),
            "user": artifact.get("user", "unknown"),
            "additional_info": artifact.get("additional_info", ""),
        }
        
        timeline.append(timeline_entry)
    
    # Sort by timestamp
    timeline.sort(key=lambda x: x["timestamp"] if isinstance(x["timestamp"], str) else "")
    
    return timeline

def generate_timeline_report(timeline, output_file):
    """Generate a markdown timeline report."""
    
    report = []
    report.append("# Forensic Timeline Report")
    report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report.append("")
    report.append(f"Total events: {len(timeline)}")
    report.append("")
    
    # Group by source
    sources = defaultdict(list)
    for entry in timeline:
        sources[entry["source"]].append(entry)
    
    report.append("## Events by Source")
    report.append("")
    
    for source, events in sorted(sources.items()):
        report.append(f"### {source.upper()} ({len(events)} events)")
        report.append("")
        report.append("| Timestamp | Event Type | Details | User |")
        report.append("|-----------|------------|---------|------|")
        
        for event in events[:20]:  # Limit to first 20 per source
            report.append(
                f"| {event['timestamp']} | {event['event_type']} | {event['details'][:50]} | {event['user']} |"
            )
        
        if len(events) > 20:
            report.append(f"| ... | ... | {len(events) - 20} more events | ... |")
        
        report.append("")
    
    # Full timeline
    report.append("## Complete Timeline")
    report.append("")
    report.append("| Timestamp | Source | Event Type | Details | User |")
    report.append("|-----------|--------|------------|---------|------|")
    
    for entry in timeline:
        details = entry["details"][:40] + "..." if len(entry["details"]) > 40 else entry["details"]
        report.append(
            f"| {entry['timestamp']} | {entry['source']} | {entry['event_type']} | {details} | {entry['user']} |"
        )
    
    report.append("")
    report.append("## Analysis Notes")
    report.append("")
    report.append("Add your analysis and observations here:")
    report.append("")
    report.append("- Key events:")
    report.append("- Suspicious patterns:")
    report.append("- Gaps in timeline:")
    report.append("- Correlations between sources:")
    report.append("")
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(report))
    
    print(f"Timeline report saved to: {output_file}")

def generate_sample_input(output_file):
    """Generate a sample input file for testing."""
    
    sample_data = {
        "artifacts": [
            {
                "source": "prefetch",
                "timestamp": "2024-01-15 08:30:00",
                "event_type": "execution",
                "details": "C:\\Windows\\System32\\cmd.exe",
                "user": "Administrator",
                "additional_info": "First execution: 2024-01-10, Last: 2024-01-15, Count: 5"
            },
            {
                "source": "lnk",
                "timestamp": "2024-01-15 09:15:00",
                "event_type": "access",
                "details": "C:\\Users\\john\\Documents\\report.xlsx",
                "user": "john",
                "additional_info": "Link created: 2024-01-15 09:15:00"
            },
            {
                "source": "event_log",
                "timestamp": "2024-01-15 09:00:00",
                "event_type": "logon",
                "details": "Event 4624 - Successful logon",
                "user": "john",
                "additional_info": "Logon type: 2 (Interactive)"
            },
            {
                "source": "jumplist",
                "timestamp": "2024-01-15 10:00:00",
                "event_type": "access",
                "details": "C:\\Users\\john\\Desktop\\presentation.pptx",
                "user": "john",
                "additional_info": "Application: PowerPoint"
            },
            {
                "source": "registry",
                "timestamp": "2024-01-15 08:45:00",
                "event_type": "execution",
                "details": "C:\\Program Files\\Malware\\suspicious.exe",
                "user": "SYSTEM",
                "additional_info": "Found in RecentApps"
            },
        ]
    }
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(sample_data, f, indent=2)
    
    print(f"Sample input saved to: {output_file}")

def main():
    parser = argparse.ArgumentParser(
        description='Build a forensic timeline from Windows artifacts'
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Command to run')
    
    # Build timeline
    build_parser = subparsers.add_parser('build', help='Build timeline from artifact data')
    build_parser.add_argument('--input', required=True, help='Input JSON file with artifact data')
    build_parser.add_argument('--output', required=True, help='Output markdown file')
    
    # Generate sample
    sample_parser = subparsers.add_parser('sample', help='Generate sample input file')
    sample_parser.add_argument('--output', required=True, help='Output JSON file')
    
    args = parser.parse_args()
    
    if args.command == 'build':
        artifact_data = load_artifact_data(args.input)
        if artifact_data:
            timeline = build_timeline(artifact_data)
            generate_timeline_report(timeline, args.output)
    elif args.command == 'sample':
        generate_sample_input(args.output)
    else:
        parser.print_help()
        exit(1)

if __name__ == '__main__':
    main()
