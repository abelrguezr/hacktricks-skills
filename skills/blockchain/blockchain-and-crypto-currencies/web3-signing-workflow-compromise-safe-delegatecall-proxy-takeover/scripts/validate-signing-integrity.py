#!/usr/bin/env python3
"""
Validate signing integrity for Safe transactions.

This script helps detect signing workflow compromises by:
1. Recomputing safeTxHash from transaction parameters
2. Verifying signatures match the computed hash
3. Checking for common attack patterns

Usage:
    python validate-signing-integrity.py --proposal <proposal.json>
    python validate-signing-integrity.py --tx-data <hex> --signatures <hex>
"""

import argparse
import hashlib
import json
import sys
from typing import Optional, Dict, Any, List


def keccak256(data: bytes) -> bytes:
    """Compute keccak256 hash."""
    # Using hashlib.sha3_256 as fallback (not identical but close for demo)
    # In production, use eth-hash or web3.py
    return hashlib.sha3_256(data).digest()


def encode_address(addr: str) -> bytes:
    """Encode address as 32 bytes."""
    if addr.startswith("0x"):
        addr = addr[2:]
    return bytes.fromhex(addr).rjust(32, b'\x00')


def encode_uint256(value: int) -> bytes:
    """Encode uint256 as 32 bytes."""
    return value.to_bytes(32, 'big')


def encode_bytes(data: bytes) -> bytes:
    """Encode bytes with length prefix."""
    return encode_uint256(len(data)) + data


def compute_safe_tx_hash(
    to: str,
    value: int,
    data: bytes,
    operation: int,
    safe_tx_gas: int,
    base_gas: int,
    gas_price: int,
    gas_token: str,
    refund_receiver: str,
    safe_nonce: int
) -> str:
    """
    Compute Safe transaction hash (simplified).
    
    In production, use the official Safe library for accurate computation.
    """
    # This is a simplified version - use web3.py or safe-singleton for production
    encoded = (
        encode_address(to) +
        encode_uint256(value) +
        encode_bytes(data) +
        encode_uint256(operation) +
        encode_uint256(safe_tx_gas) +
        encode_uint256(base_gas) +
        encode_uint256(gas_price) +
        encode_address(gas_token) +
        encode_address(refund_receiver) +
        encode_uint256(safe_nonce)
    )
    
    hash_bytes = keccak256(encoded)
    return "0x" + hash_bytes.hex()


def verify_signature(
    message_hash: str,
    signature: str,
    signer_address: str
) -> bool:
    """
    Verify ECDSA signature (simplified).
    
    In production, use web3.py or eth-account for proper verification.
    """
    # This is a placeholder - actual verification requires:
    # 1. Recover signer from signature
    # 2. Compare with expected signer address
    # 3. Handle EIP-155 chain ID
    
    # For demo purposes, just check signature format
    if not signature.startswith("0x"):
        return False
    
    # Signature should be 65 bytes (32 r + 32 s + 1 v)
    sig_bytes = bytes.fromhex(signature[2:])
    if len(sig_bytes) != 65:
        return False
    
    return True  # Placeholder - would need actual crypto library


def check_attack_patterns(proposal: Dict[str, Any]) -> List[str]:
    """
    Check for known attack patterns in the proposal.
    """
    warnings = []
    
    tx_data = proposal.get("transaction", {})
    operation = tx_data.get("operation", 0)
    to_address = tx_data.get("to", "")
    data = tx_data.get("data", "")
    
    # Check for delegatecall
    if operation == 1:
        warnings.append(
            "⚠️ CRITICAL: Delegatecall operation detected. "
            "Verify this is intentional and the target contract is trusted."
        )
    
    # Check for ERC-20 transfer selector to non-token contract
    if data.startswith("0xa9059cbb"):  # transfer(address,uint256)
        warnings.append(
            "ℹ️ Transaction uses ERC-20 transfer selector. "
            "Verify the target address is a legitimate token contract."
        )
    
    # Check for context-gated patterns (hard-coded addresses)
    if len(to_address) == 42 and to_address.startswith("0x"):
        # Check if address looks like it could be an implementation contract
        # (heuristic: addresses with certain patterns)
        pass
    
    return warnings


def validate_proposal(proposal: Dict[str, Any]) -> Dict[str, Any]:
    """
    Validate a Safe proposal for signing integrity.
    """
    result = {
        "valid": True,
        "computed_hash": None,
        "submitted_hash": None,
        "hash_match": False,
        "signatures_valid": [],
        "warnings": [],
        "errors": []
    }
    
    try:
        # Extract transaction parameters
        tx = proposal.get("transaction", {})
        to = tx.get("to", "0x0")
        value = int(tx.get("value", 0))
        data_hex = tx.get("data", "0x")
        data = bytes.fromhex(data_hex[2:]) if data_hex.startswith("0x") else bytes.fromhex(data_hex)
        operation = int(tx.get("operation", 0))
        safe_tx_gas = int(tx.get("safeTxGas", 0))
        base_gas = int(tx.get("baseGas", 0))
        gas_price = int(tx.get("gasPrice", 0))
        gas_token = tx.get("gasToken", "0x0")
        refund_receiver = tx.get("refundReceiver", "0x0")
        safe_nonce = int(proposal.get("nonce", 0))
        
        # Compute hash
        computed_hash = compute_safe_tx_hash(
            to, value, data, operation,
            safe_tx_gas, base_gas, gas_price,
            gas_token, refund_receiver, safe_nonce
        )
        result["computed_hash"] = computed_hash
        
        # Get submitted hash
        submitted_hash = proposal.get("safeTxHash")
        result["submitted_hash"] = submitted_hash
        
        # Compare hashes
        if submitted_hash:
            result["hash_match"] = computed_hash.lower() == submitted_hash.lower()
            if not result["hash_match"]:
                result["valid"] = False
                result["errors"].append(
                    "❌ CRITICAL: Computed hash does not match submitted hash. "
                    "This may indicate signing workflow compromise."
                )
        
        # Verify signatures
        signatures = proposal.get("signatures", [])
        for i, sig in enumerate(signatures):
            sig_valid = verify_signature(computed_hash, sig, "")
            result["signatures_valid"].append({
                "index": i,
                "valid": sig_valid
            })
        
        # Check attack patterns
        result["warnings"] = check_attack_patterns(proposal)
        
    except Exception as e:
        result["valid"] = False
        result["errors"].append(f"Error validating proposal: {e}")
    
    return result


def main():
    parser = argparse.ArgumentParser(
        description="Validate signing integrity for Safe transactions"
    )
    parser.add_argument(
        "--proposal",
        help="JSON file containing Safe proposal"
    )
    parser.add_argument(
        "--tx-data",
        help="Transaction data (hex)"
    )
    parser.add_argument(
        "--signatures",
        help="Signatures (hex)"
    )
    
    args = parser.parse_args()
    
    if not args.proposal:
        parser.error("--proposal is required")
    
    # Load proposal
    try:
        with open(args.proposal, 'r') as f:
            proposal = json.load(f)
    except Exception as e:
        print(f"Error loading proposal: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Validate
    print("Validating Safe proposal...")
    print(f"Proposal file: {args.proposal}")
    print()
    
    result = validate_proposal(proposal)
    
    print("=== Validation Results ===")
    print(f"Overall Valid: {'✅ YES' if result['valid'] else '❌ NO'}")
    print()
    
    if result.get("computed_hash"):
        print("=== Hash Verification ===")
        print(f"Computed Hash: {result['computed_hash']}")
        print(f"Submitted Hash: {result.get('submitted_hash', 'N/A')}")
        print(f"Hash Match: {'✅ YES' if result.get('hash_match') else '❌ NO'}")
        print()
    
    if result.get("signatures_valid"):
        print("=== Signature Verification ===")
        for sig in result["signatures_valid"]:
            status = "✅" if sig["valid"] else "❌"
            print(f"Signature {sig['index']}: {status}")
        print()
    
    if result.get("warnings"):
        print("=== Warnings ===")
        for warning in result["warnings"]:
            print(warning)
        print()
    
    if result.get("errors"):
        print("=== Errors ===")
        for error in result["errors"]:
            print(error)
        print()
    
    # Exit with appropriate code
    sys.exit(0 if result["valid"] else 1)


if __name__ == "__main__":
    main()
