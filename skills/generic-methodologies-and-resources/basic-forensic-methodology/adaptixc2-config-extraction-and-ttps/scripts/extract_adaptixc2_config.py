#!/usr/bin/env python3
"""
AdaptixC2 Configuration Extractor

Extracts and decrypts RC4-encrypted configuration blobs from AdaptixC2 beacons.

Usage:
    python extract_adaptixc2_config.py <beacon.exe>           # Extract from PE file
    python extract_adaptixc2_config.py <blob.bin> --blob-mode # Extract from pre-isolated blob
"""

import struct
import sys
import json
from typing import List, Tuple, Optional
from pathlib import Path


def rc4(key: bytes, data: bytes) -> bytes:
    """RC4 decryption/encryption (symmetric)."""
    S = list(range(256))
    j = 0
    for i in range(256):
        j = (j + S[i] + key[i % len(key)]) & 0xFF
        S[i], S[j] = S[j], S[i]
    
    i = j = 0
    out = bytearray()
    for b in data:
        i = (i + 1) & 0xFF
        j = (j + S[i]) & 0xFF
        S[i], S[j] = S[j], S[i]
        K = S[(S[i] + S[j]) & 0xFF]
        out.append(b ^ K)
    return bytes(out)


class Parser:
    """Binary parser for AdaptixC2 config format."""
    
    def __init__(self, buf: bytes):
        self.buf = buf
        self.offset = 0
    
    def u32(self) -> int:
        """Read uint32 little-endian."""
        if self.offset + 4 > len(self.buf):
            raise ValueError("Unexpected end of buffer")
        value = struct.unpack_from('<I', self.buf, self.offset)[0]
        self.offset += 4
        return value
    
    def u8(self) -> int:
        """Read uint8."""
        if self.offset + 1 > len(self.buf):
            raise ValueError("Unexpected end of buffer")
        value = self.buf[self.offset]
        self.offset += 1
        return value
    
    def string(self) -> str:
        """Read length-prefixed string (u32 length + bytes, optional trailing NUL)."""
        length = self.u32()
        if self.offset + length > len(self.buf):
            raise ValueError("Unexpected end of buffer")
        raw = self.buf[self.offset:self.offset + length]
        self.offset += length
        
        # Handle trailing NUL
        if length > 0 and raw[-1:] == b'\x00':
            raw = raw[:-1]
        
        return raw.decode('utf-8', errors='replace')


def parse_http_config(plain: bytes) -> dict:
    """Parse decrypted HTTP beacon configuration."""
    p = Parser(plain)
    cfg = {}
    
    cfg['agent_type'] = p.u32()
    cfg['use_ssl'] = bool(p.u8())
    
    servers_count = p.u32()
    cfg['servers'] = []
    cfg['ports'] = []
    for _ in range(servers_count):
        cfg['servers'].append(p.string())
        cfg['ports'].append(p.u32())
    
    cfg['http_method'] = p.string()
    cfg['uri'] = p.string()
    cfg['parameter'] = p.string()
    cfg['user_agent'] = p.string()
    cfg['http_headers'] = p.string()
    
    ans_pre_size = p.u32()
    ans_size = p.u32()
    cfg['ans_pre_size'] = ans_pre_size
    cfg['ans_size'] = ans_size + ans_pre_size
    
    cfg['kill_date'] = p.u32()
    cfg['working_time'] = p.u32()
    cfg['sleep_delay'] = p.u32()
    cfg['jitter_delay'] = p.u32()
    
    # These may not be present in all configs
    try:
        cfg['listener_type'] = p.u32()
    except ValueError:
        cfg['listener_type'] = 0
    
    try:
        cfg['download_chunk_size'] = p.u32()
    except ValueError:
        cfg['download_chunk_size'] = 0x19000
    
    return cfg


def validate_config(cfg: dict) -> bool:
    """Basic validation that config looks plausible."""
    # Check for reasonable string fields
    if not cfg.get('uri'):
        return False
    if not cfg.get('http_method'):
        return False
    if not cfg.get('user_agent'):
        return False
    
    # Check for reasonable numeric fields
    if cfg.get('sleep_delay', 0) > 86400:  # More than a day is suspicious
        return False
    
    return True


def extract_from_blob(blob: bytes) -> Optional[dict]:
    """Extract config from a pre-isolated blob (size|ciphertext|key)."""
    if len(blob) < 20:  # Minimum: 4 (size) + 1 (min config) + 16 (key)
        return None
    
    # Read size
    size = struct.unpack_from('<I', blob, 0)[0]
    
    # Validate size
    if size > len(blob) - 20 or size == 0:
        return None
    
    # Extract ciphertext and key
    ciphertext = blob[4:4 + size]
    key = blob[4 + size:4 + size + 16]
    
    if len(key) != 16:
        return None
    
    # Decrypt
    try:
        plaintext = rc4(key, ciphertext)
    except Exception:
        return None
    
    # Parse
    try:
        cfg = parse_http_config(plaintext)
    except (ValueError, UnicodeDecodeError):
        return None
    
    # Validate
    if not validate_config(cfg):
        return None
    
    return cfg


def scan_pe_for_blob(data: bytes) -> Optional[dict]:
    """
    Scan PE file for AdaptixC2 config blob.
    
    The blob is typically in .rdata section with format:
    [4 bytes: size] [N bytes: ciphertext] [16 bytes: key]
    """
    # Simple heuristic: scan for plausible blob layouts
    # Look for patterns where size is reasonable and decryption produces valid strings
    
    # Common blob locations: end of .rdata, or scattered throughout
    # We'll scan with a sliding window
    
    max_size = 4096  # Reasonable max config size
    
    for offset in range(0, len(data) - 20, 4):
        # Try to read size
        if offset + 4 > len(data):
            break
        
        size = struct.unpack_from('<I', data, offset)[0]
        
        # Skip unreasonable sizes
        if size == 0 or size > max_size:
            continue
        
        # Check if we have enough data
        if offset + 4 + size + 16 > len(data):
            continue
        
        # Extract candidate blob
        ciphertext = data[offset + 4:offset + 4 + size]
        key = data[offset + 4 + size:offset + 4 + size + 16]
        
        # Try to decrypt and parse
        try:
            plaintext = rc4(key, ciphertext)
            cfg = parse_http_config(plaintext)
            
            if validate_config(cfg):
                return cfg
        except (ValueError, UnicodeDecodeError, struct.error):
            continue
    
    return None


def main():
    if len(sys.argv) < 2:
        print("Usage: python extract_adaptixc2_config.py <file> [--blob-mode]")
        print("  --blob-mode: Input is a pre-isolated blob (size|ciphertext|key)")
        sys.exit(1)
    
    filepath = Path(sys.argv[1])
    blob_mode = '--blob-mode' in sys.argv
    
    if not filepath.exists():
        print(f"Error: File not found: {filepath}")
        sys.exit(1)
    
    data = filepath.read_bytes()
    
    if blob_mode:
        # Direct blob extraction
        cfg = extract_from_blob(data)
    else:
        # Scan PE for blob
        cfg = scan_pe_for_blob(data)
    
    if cfg:
        print("Configuration extracted successfully:")
        print(json.dumps(cfg, indent=2))
        
        # Also output indicators summary
        print("\n--- Indicators ---")
        print(f"C2 Servers: {', '.join(cfg.get('servers', []))}")
        print(f"Ports: {', '.join(map(str, cfg.get('ports', [])))}")
        print(f"URI: {cfg.get('uri', 'N/A')}")
        print(f"Method: {cfg.get('http_method', 'N/A')}")
        print(f"Custom Header: {cfg.get('parameter', 'N/A')}")
        print(f"User Agent: {cfg.get('user_agent', 'N/A')[:80]}...")
        print(f"Sleep Delay: {cfg.get('sleep_delay', 'N/A')} seconds")
        print(f"Jitter Delay: {cfg.get('jitter_delay', 'N/A')} seconds")
    else:
        print("No valid AdaptixC2 configuration found.")
        print("The file may not be an AdaptixC2 beacon, or the blob location differs from expected.")
        sys.exit(1)


if __name__ == '__main__':
    main()
