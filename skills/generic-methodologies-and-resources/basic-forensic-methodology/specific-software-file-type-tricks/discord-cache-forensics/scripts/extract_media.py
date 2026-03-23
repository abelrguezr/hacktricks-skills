#!/usr/bin/env python3
"""Extract and carve media files from Discord cache."""

import os
import sys
import hashlib
import argparse
from pathlib import Path
from datetime import datetime
import json

# Magic bytes for common media formats
MAGIC_BYTES = {
    'image/jpeg': [b'\xff\xd8\xff'],
    'image/png': [b'\x89PNG\r\n\x1a\n'],
    'image/gif': [b'GIF87a', b'GIF89a'],
    'image/webp': [b'RIFF' + b'\x00\x00\x00\x00WEBP'],
    'video/mp4': [b'\x00\x00\x00\x1cftypmp4', b'\x00\x00\x00\x1cftypisom'],
    'video/webm': [b'\x1a\x45\xdf\xa3'],
}


def find_media_in_file(file_path):
    """Scan a file for media content using magic bytes."""
    media_found = []
    
    try:
        with open(file_path, 'rb') as f:
            content = f.read()
        
        for media_type, signatures in MAGIC_BYTES.items():
            for sig in signatures:
                start = 0
                while True:
                    pos = content.find(sig, start)
                    if pos == -1:
                        break
                    
                    # Extract media starting from magic bytes
                    media_data = content[pos:]
                    
                    # Try to find end of media (simple heuristic: look for next magic byte or end)
                    # For now, just extract to end of file
                    
                    # Calculate hash
                    sha256 = hashlib.sha256(media_data).hexdigest()
                    
                    media_found.append({
                        "media_type": media_type,
                        "offset": pos,
                        "size": len(media_data),
                        "sha256": sha256,
                        "source_file": str(file_path)
                    })
                    
                    start = pos + 1
    
    except Exception as e:
        print(f"Error scanning {file_path}: {e}")
    
    return media_found


def extract_media(media_info, output_dir):
    """Extract media file to output directory."""
    try:
        source_path = Path(media_info['source_file'])
        
        with open(source_path, 'rb') as f:
            f.seek(media_info['offset'])
            media_data = f.read(media_info['size'])
        
        # Determine file extension
        ext_map = {
            'image/jpeg': '.jpg',
            'image/png': '.png',
            'image/gif': '.gif',
            'image/webp': '.webp',
            'video/mp4': '.mp4',
            'video/webm': '.webm'
        }
        ext = ext_map.get(media_info['media_type'], '.bin')
        
        # Create output filename
        output_name = f"{media_info['sha256'][:16]}{ext}"
        output_path = output_dir / output_name
        
        with open(output_path, 'wb') as f:
            f.write(media_data)
        
        return str(output_path)
    
    except Exception as e:
        print(f"Error extracting media: {e}")
        return None


def main():
    parser = argparse.ArgumentParser(description='Extract media files from Discord cache')
    parser.add_argument('--cache', required=True, help='Path to Cache_Data directory')
    parser.add_argument('--output', required=True, help='Output directory for extracted media')
    args = parser.parse_args()
    
    cache_dir = Path(args.cache)
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    if not cache_dir.exists():
        print(f"Error: Cache directory not found: {cache_dir}")
        sys.exit(1)
    
    print(f"Scanning for media in: {cache_dir}")
    print(f"Output directory: {output_dir}")
    print()
    
    # Scan all files
    all_media = []
    files_scanned = 0
    
    for file_path in cache_dir.glob('*'):
        if file_path.is_file():
            files_scanned += 1
            media = find_media_in_file(file_path)
            all_media.extend(media)
    
    print(f"Scanned {files_scanned} files")
    print(f"Found {len(all_media)} media instances")
    
    # Extract unique media (by SHA256)
    seen_hashes = set()
    unique_media = []
    
    for media in all_media:
        if media['sha256'] not in seen_hashes:
            seen_hashes.add(media['sha256'])
            unique_media.append(media)
    
    print(f"Unique media files: {len(unique_media)}")
    
    # Extract media
    extracted = []
    for media in unique_media:
        output_path = extract_media(media, output_dir)
        if output_path:
            media['output_path'] = output_path
            extracted.append(media)
            print(f"  Extracted: {media['media_type']} -> {output_path}")
    
    # Write manifest
    manifest_path = output_dir / 'media_manifest.json'
    with open(manifest_path, 'w') as f:
        json.dump(extracted, f, indent=2)
    print(f"\nManifest saved to: {manifest_path}")
    
    # Summary by type
    print("\n=== Extraction Summary ===")
    type_counts = {}
    for m in extracted:
        t = m['media_type']
        type_counts[t] = type_counts.get(t, 0) + 1
    
    for media_type, count in sorted(type_counts.items()):
        print(f"  {media_type}: {count}")


if __name__ == '__main__':
    main()
