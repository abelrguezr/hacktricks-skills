#!/usr/bin/env python3
"""Encode payloads for various phishing document formats."""

import argparse
import base64
import sys
import binascii


def encode_base64(payload: str) -> str:
    """Encode payload to Base64."""
    return base64.b64encode(payload.encode('utf-8')).decode('utf-8')


def encode_hex(payload: str) -> str:
    """Encode payload to hex string."""
    return binascii.hexlify(payload.encode('utf-8')).decode('utf-8')


def encode_unicode(payload: str) -> str:
    """Encode payload to Unicode escape sequences."""
    return ''.join(f'\\u{ord(c):04x}' for c in payload)


def encode_vba_friendly(payload: str) -> str:
    """Encode payload for VBA string concatenation."""
    # Split into chunks for VBA string limits
    chunk_size = 100
    chunks = [payload[i:i+chunk_size] for i in range(0, len(payload), chunk_size)]
    
    encoded_chunks = []
    for chunk in chunks:
        # Escape quotes and encode
        escaped = chunk.replace('"', '""')
        encoded_chunks.append(f'"{escaped}"')
    
    return ' & \n    '.join(encoded_chunks)


def decode_base64(encoded: str) -> str:
    """Decode Base64 payload."""
    return base64.b64decode(encoded.encode('utf-8')).decode('utf-8')


def decode_hex(encoded: str) -> str:
    """Decode hex payload."""
    return binascii.unhexlify(encoded.encode('utf-8')).decode('utf-8')


def main():
    parser = argparse.ArgumentParser(
        description='Encode/decode payloads for phishing documents'
    )
    subparsers = parser.add_subparsers(dest='action', required=True)
    
    # Encode subcommand
    encode_parser = subparsers.add_parser('encode', help='Encode payload')
    encode_parser.add_argument('payload', help='Payload to encode')
    encode_parser.add_argument('-f', '--format', default='base64',
                               choices=['base64', 'hex', 'unicode', 'vba'],
                               help='Output format')
    
    # Decode subcommand
    decode_parser = subparsers.add_parser('decode', help='Decode payload')
    decode_parser.add_argument('encoded', help='Encoded payload')
    decode_parser.add_argument('-f', '--format', default='base64',
                               choices=['base64', 'hex'],
                               help='Input format')
    
    args = parser.parse_args()
    
    if args.action == 'encode':
        if args.format == 'base64':
            result = encode_base64(args.payload)
        elif args.format == 'hex':
            result = encode_hex(args.payload)
        elif args.format == 'unicode':
            result = encode_unicode(args.payload)
        elif args.format == 'vba':
            result = encode_vba_friendly(args.payload)
        
        print(result)
    
    elif args.action == 'decode':
        if args.format == 'base64':
            result = decode_base64(args.encoded)
        elif args.format == 'hex':
            result = decode_hex(args.encoded)
        
        print(result)


if __name__ == '__main__':
    main()
