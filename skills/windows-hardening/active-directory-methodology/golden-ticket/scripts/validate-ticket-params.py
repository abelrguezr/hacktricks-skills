#!/usr/bin/env python3
"""
Golden Ticket Parameter Validator
Validates parameters for Golden Ticket creation to ensure correctness and OpSec best practices.
"""

import re
import sys
import json
from typing import Dict, List, Tuple


def validate_sid(sid: str) -> Tuple[bool, str]:
    """Validate Domain SID format."""
    pattern = r'^S-1-5-21-\d+-\d+-\d+$'
    if re.match(pattern, sid):
        return True, "Valid SID format"
    return False, f"Invalid SID format: {sid}. Expected: S-1-5-21-XXXXXXXXXX-XXXXXXXXXX-XXXXXXXXXX"


def validate_ntlm_hash(hash_value: str) -> Tuple[bool, str]:
    """Validate NTLM hash format (32 hex characters)."""
    pattern = r'^[a-fA-F0-9]{32}$'
    if re.match(pattern, hash_value):
        return True, "Valid NTLM hash format"
    return False, f"Invalid NTLM hash: {hash_value}. Expected 32 hexadecimal characters"


def validate_aes_key(key: str, key_type: str = "AES256") -> Tuple[bool, str]:
    """Validate AES key format."""
    if key_type == "AES256":
        pattern = r'^[a-fA-F0-9]{64}$'
        expected_len = 64
    elif key_type == "AES128":
        pattern = r'^[a-fA-F0-9]{32}$'
        expected_len = 32
    else:
        return False, f"Unknown key type: {key_type}"
    
    if re.match(pattern, key):
        return True, f"Valid {key_type} key format"
    return False, f"Invalid {key_type} key: expected {expected_len} hex characters"


def validate_lifetime(lifetime_minutes: int) -> Tuple[bool, str, str]:
    """Validate and provide OpSec feedback on ticket lifetime."""
    if lifetime_minutes <= 0:
        return False, "Lifetime must be positive", "Invalid lifetime"
    
    # OpSec recommendations
    if lifetime_minutes > 1440:  # More than 24 hours
        return True, f"Lifetime: {lifetime_minutes} minutes ({lifetime_minutes/60:.1f} hours)", \
            "WARNING: Long ticket lifetime increases detection risk. Consider 600 minutes (10 hours) or less."
    elif lifetime_minutes > 480:  # More than 8 hours
        return True, f"Lifetime: {lifetime_minutes} minutes ({lifetime_minutes/60:.1f} hours)", \
            "CAUTION: Consider reducing lifetime for better OpSec."
    else:
        return True, f"Lifetime: {lifetime_minutes} minutes ({lifetime_minutes/60:.1f} hours)", \
            "Good: Reasonable ticket lifetime for OpSec."


def validate_renewmax(renewmax_minutes: int, lifetime_minutes: int) -> Tuple[bool, str]:
    """Validate renewal maximum."""
    if renewmax_minutes <= 0:
        return False, "Renewmax must be positive"
    
    if renewmax_minutes < lifetime_minutes:
        return False, f"Renewmax ({renewmax_minutes} min) should be >= lifetime ({lifetime_minutes} min)"
    
    return True, f"Renewmax: {renewmax_minutes} minutes ({renewmax_minutes/60:.1f} hours)"


def validate_rid(rid: int) -> Tuple[bool, str]:
    """Validate RID and provide context."""
    if rid <= 0:
        return False, "RID must be positive"
    
    known_rids = {
        500: "Administrator",
        501: "Guest",
        502: "KRBTGT",
        512: "Domain Admins",
        513: "Domain Users",
        519: "Enterprise Admins",
        520: "Domain Computers",
        521: "Domain Controllers",
        525: "Schema Admins",
        526: "Enterprise Admins",
    }
    
    name = known_rids.get(rid, "Custom RID")
    return True, f"RID: {rid} ({name})"


def validate_groups(groups: str) -> Tuple[bool, str]:
    """Validate group RIDs."""
    if not groups:
        return True, "No groups specified"
    
    group_rids = [g.strip() for g in groups.split(',')]
    valid = True
    details = []
    
    for rid in group_rids:
        try:
            rid_int = int(rid)
            if rid_int <= 0:
                valid = False
                details.append(f"Invalid RID: {rid}")
            else:
                details.append(f"Group RID: {rid}")
        except ValueError:
            valid = False
            details.append(f"Invalid group RID: {rid}")
    
    return valid, "; ".join(details)


def validate_username(username: str) -> Tuple[bool, str]:
    """Validate username format."""
    if not username or len(username) > 20:
        return False, "Username must be 1-20 characters"
    
    # Check for invalid characters
    if re.search(r'[<>:"/\\|?*]', username):
        return False, "Username contains invalid characters"
    
    return True, f"Username: {username}"


def validate_domain(domain: str) -> Tuple[bool, str]:
    """Validate domain name format."""
    if not domain:
        return False, "Domain name is required"
    
    # Basic domain validation
    if re.match(r'^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)*$', domain):
        return True, f"Domain: {domain}"
    
    return False, f"Invalid domain format: {domain}"


def validate_params(params: Dict) -> Dict:
    """Validate all Golden Ticket parameters."""
    results = {
        "valid": True,
        "checks": [],
        "warnings": [],
        "errors": []
    }
    
    # Validate each parameter
    checks = [
        ("username", params.get("username", ""), validate_username),
        ("domain", params.get("domain", ""), validate_domain),
        ("sid", params.get("sid", ""), validate_sid),
        ("krbtgt", params.get("krbtgt", ""), validate_ntlm_hash),
        ("aes256", params.get("aes256", ""), lambda x: validate_aes_key(x, "AES256")),
        ("aes128", params.get("aes128", ""), lambda x: validate_aes_key(x, "AES128")),
        ("id", params.get("id", 500), validate_rid),
        ("groups", params.get("groups", "512"), validate_groups),
    ]
    
    for name, value, validator in checks:
        if value:
            valid, message = validator(value)
            results["checks"].append({"parameter": name, "valid": valid, "message": message})
            if not valid:
                results["valid"] = False
                results["errors"].append(f"{name}: {message}")
    
    # Validate lifetime
    lifetime = params.get("lifetime", 600)
    valid, message, warning = validate_lifetime(lifetime)
    results["checks"].append({"parameter": "lifetime", "valid": valid, "message": message})
    if warning.startswith("WARNING"):
        results["warnings"].append(warning)
    elif warning.startswith("CAUTION"):
        results["warnings"].append(warning)
    if not valid:
        results["valid"] = False
        results["errors"].append(f"lifetime: {message}")
    
    # Validate renewmax
    renewmax = params.get("renewmax", 10080)
    valid, message = validate_renewmax(renewmax, lifetime)
    results["checks"].append({"parameter": "renewmax", "valid": valid, "message": message})
    if not valid:
        results["valid"] = False
        results["errors"].append(f"renewmax: {message}")
    
    # Check encryption method
    has_krbtgt = bool(params.get("krbtgt"))
    has_aes256 = bool(params.get("aes256"))
    has_aes128 = bool(params.get("aes128"))
    
    if has_krbtgt and not has_aes256 and not has_aes128:
        results["warnings"].append("Using NTLM/RC4 encryption - consider AES256 for better OpSec")
    elif has_aes256:
        results["checks"].append({"parameter": "encryption", "valid": True, "message": "AES256 encryption (recommended)"})
    elif has_aes128:
        results["checks"].append({"parameter": "encryption", "valid": True, "message": "AES128 encryption (acceptable)"})
    
    return results


def main():
    """Main function."""
    if len(sys.argv) < 2:
        print("Usage: python validate-ticket-params.py <params.json>")
        print("\nExample:")
        example = {
            "username": "Administrator",
            "domain": "corp.local",
            "sid": "S-1-5-21-1234567890-1234567890-1234567890",
            "krbtgt": "25b2076cda3bfd6209161a6c78a69c1c",
            "id": 500,
            "groups": "512",
            "lifetime": 600,
            "renewmax": 10080
        }
        print(json.dumps(example, indent=2))
        sys.exit(1)
    
    try:
        with open(sys.argv[1], 'r') as f:
            params = json.load(f)
    except FileNotFoundError:
        print(f"Error: File not found: {sys.argv[1]}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON: {e}")
        sys.exit(1)
    
    results = validate_params(params)
    
    # Print results
    print("\n=== Golden Ticket Parameter Validation ===\n")
    
    for check in results["checks"]:
        status = "✓" if check["valid"] else "✗"
        color = "\033[92m" if check["valid"] else "\033[91m"
        reset = "\033[0m"
        print(f"{color}{status}{reset} {check['parameter']}: {check['message']}")
    
    if results["warnings"]:
        print("\n⚠ Warnings:")
        for warning in results["warnings"]:
            print(f"  - {warning}")
    
    if results["errors"]:
        print("\n✗ Errors:")
        for error in results["errors"]:
            print(f"  - {error}")
        print("\nValidation FAILED")
        sys.exit(1)
    else:
        print("\n✓ Validation PASSED")
        sys.exit(0)


if __name__ == "__main__":
    main()
