#!/usr/bin/env python3
"""
Check and decode macOS code signing flags.
"""

import sys
import json

# Code signing flag definitions
CS_FLAGS = {
    0x00000001: 'CS_VALID',
    0x00000002: 'CS_ADHOC',
    0x00000004: 'CS_GET_TASK_ALLOW',
    0x00000008: 'CS_INSTALLER',
    0x00000010: 'CS_FORCED_LV',
    0x00000020: 'CS_INVALID_ALLOWED',
    0x00000100: 'CS_HARD',
    0x00000200: 'CS_KILL',
    0x00000400: 'CS_CHECK_EXPIRATION',
    0x00000800: 'CS_RESTRICT',
    0x00001000: 'CS_ENFORCEMENT',
    0x00002000: 'CS_REQUIRE_LV',
    0x00004000: 'CS_ENTITLEMENTS_VALIDATED',
    0x00008000: 'CS_NVRAM_UNRESTRICTED',
    0x00010000: 'CS_RUNTIME',
    0x00020000: 'CS_LINKER_SIGNED',
    0x00100000: 'CS_EXEC_SET_HARD',
    0x00200000: 'CS_EXEC_SET_KILL',
    0x00400000: 'CS_EXEC_SET_ENFORCEMENT',
    0x00800000: 'CS_EXEC_INHERIT_SIP',
    0x01000000: 'CS_KILLED',
    0x02000000: 'CS_NO_UNTRUSTED_HELPERS',
    0x04000000: 'CS_PLATFORM_BINARY',
    0x08000000: 'CS_PLATFORM_PATH',
    0x10000000: 'CS_DEBUGGED',
    0x20000000: 'CS_SIGNED',
    0x40000000: 'CS_DEV_CODE',
    0x80000000: 'CS_DATAVAULT_CONTROLLER',
}

# Flag descriptions
CS_FLAG_DESCRIPTIONS = {
    'CS_VALID': 'Signature is dynamically valid',
    'CS_ADHOC': 'Ad hoc signed (not with developer certificate)',
    'CS_GET_TASK_ALLOW': 'Has get-task-allow entitlement (allows task port access)',
    'CS_INSTALLER': 'Has installer entitlement',
    'CS_FORCED_LV': 'Library Validation required by Hardened System Policy',
    'CS_INVALID_ALLOWED': 'Page invalidation allowed by task port policy (macOS only)',
    'CS_HARD': 'Don\'t load invalid pages',
    'CS_KILL': 'Kill process if it becomes invalid',
    'CS_CHECK_EXPIRATION': 'Force expiration checking',
    'CS_RESTRICT': 'Tell dyld to treat as restricted',
    'CS_ENFORCEMENT': 'Require enforcement',
    'CS_REQUIRE_LV': 'Require library validation',
    'CS_ENTITLEMENTS_VALIDATED': 'Code signature permits restricted entitlements',
    'CS_NVRAM_UNRESTRICTED': 'Has rootless restricted-nvram-variables.heritable entitlement',
    'CS_RUNTIME': 'Apply hardened runtime policies',
    'CS_LINKER_SIGNED': 'Automatically signed by the linker',
    'CS_EXEC_SET_HARD': 'Set CS_HARD on any exec\'ed process',
    'CS_EXEC_SET_KILL': 'Set CS_KILL on any exec\'ed process',
    'CS_EXEC_SET_ENFORCEMENT': 'Set CS_ENFORCEMENT on any exec\'ed process',
    'CS_EXEC_INHERIT_SIP': 'Set CS_INSTALLER on any exec\'ed process',
    'CS_KILLED': 'Was killed by kernel for invalidity',
    'CS_NO_UNTRUSTED_HELPERS': 'Kernel did not load non-platform dyld or Rosetta',
    'CS_PLATFORM_BINARY': 'This is a platform binary (trusted)',
    'CS_PLATFORM_PATH': 'Platform binary by path (macOS only)',
    'CS_DEBUGGED': 'Process is/was debugged and allowed invalid pages',
    'CS_SIGNED': 'Process has a signature (may have gone invalid)',
    'CS_DEV_CODE': 'Code is dev signed',
    'CS_DATAVAULT_CONTROLLER': 'Has Data Vault controller entitlement',
}


def decode_flags(flags_value):
    """Decode a flags value into individual flags."""
    if isinstance(flags_value, str):
        # Handle hex string
        if flags_value.startswith('0x'):
            flags_value = int(flags_value, 16)
        else:
            flags_value = int(flags_value)
    
    decoded = []
    remaining = flags_value
    
    for flag_value, flag_name in sorted(CS_FLAGS.items(), reverse=True):
        if flags_value & flag_value:
            decoded.append({
                'name': flag_name,
                'value': hex(flag_value),
                'description': CS_FLAG_DESCRIPTIONS.get(flag_name, 'Unknown flag')
            })
            remaining &= ~flag_value
    
    if remaining != 0:
        decoded.append({
            'name': 'UNKNOWN',
            'value': hex(remaining),
            'description': 'Unknown flag bits'
        })
    
    return decoded


def analyze_flags(flags_value):
    """Analyze flags and provide security implications."""
    decoded = decode_flags(flags_value)
    
    implications = []
    
    flag_names = [f['name'] for f in decoded]
    
    # Security implications
    if 'CS_PLATFORM_BINARY' in flag_names:
        implications.append('HIGH: Platform binary - has special OS protections and trust')
    
    if 'CS_GET_TASK_ALLOW' in flag_names:
        implications.append('MEDIUM: Has get-task-allow - allows task port access (debugging/privilege escalation risk)')
    
    if 'CS_HARD' in flag_names:
        implications.append('INFO: CS_HARD enabled - won\'t load invalid pages')
    
    if 'CS_KILL' in flag_names:
        implications.append('INFO: CS_KILL enabled - process killed if signature becomes invalid')
    
    if 'CS_RESTRICT' in flag_names:
        implications.append('INFO: Restricted mode - dyld treats as restricted')
    
    if 'CS_RUNTIME' in flag_names:
        implications.append('INFO: Hardened runtime enabled - additional security policies apply')
    
    if 'CS_ADHOC' in flag_names:
        implications.append('INFO: Ad hoc signed - not signed with developer certificate')
    
    if 'CS_VALID' not in flag_names:
        implications.append('WARNING: Signature not marked as valid')
    
    return {
        'flags_value': hex(flags_value) if isinstance(flags_value, int) else flags_value,
        'decoded_flags': decoded,
        'security_implications': implications
    }


def main():
    if len(sys.argv) < 2:
        print("Usage: python check_cs_flags.py <flags_value>")
        print("Example: python check_cs_flags.py 0x00000001")
        print("Example: python check_cs_flags.py 1")
        sys.exit(1)
    
    flags_value = sys.argv[1]
    
    result = analyze_flags(flags_value)
    
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
