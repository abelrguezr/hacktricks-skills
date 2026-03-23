#!/usr/bin/env python3
"""
Safe Class Pollution Test Harness

This script provides a controlled environment for testing class pollution
vulnerabilities. ONLY USE IN ISOLATED TEST ENVIRONMENTS.

Usage: python test_pollution_harness.py
"""

import json
import sys
from typing import Dict, Any, Optional


class TestEmployee:
    """Test class for pollution experiments."""
    
    def __init__(self):
        self.name = "Test Employee"
        self.department = "Engineering"
    
    def get_info(self) -> str:
        return f"{self.name} from {self.department}"


class TestManager(TestEmployee):
    """Inherits from TestEmployee."""
    
    def __init__(self):
        super().__init__()
        self.team_size = 5
    
    def execute_task(self, *, command: str = "echo default") -> str:
        """Task with keyword-only parameter."""
        return f"Executing: {command}"


def vulnerable_merge(src: Dict[str, Any], dst: Any) -> None:
    """
    VULNERABLE merge function for testing.
    DO NOT USE IN PRODUCTION.
    """
    for k, v in src.items():
        if hasattr(dst, '__getitem__'):
            if dst.get(k) and isinstance(v, dict):
                vulnerable_merge(v, dst.get(k))
            else:
                dst[k] = v
        elif hasattr(dst, k) and isinstance(v, dict):
            vulnerable_merge(v, getattr(dst, k))
        else:
            setattr(dst, k, v)


def safe_merge(src: Dict[str, Any], dst: Any, allowed_keys: Optional[set] = None) -> None:
    """
    Safe merge function that prevents class pollution.
    """
    dangerous_patterns = ['__class__', '__base__', '__globals__', 
                          '__init__', '__kwdefaults__', '__dict__']
    
    for k, v in src.items():
        # Block dangerous attributes
        if any(dangerous in k for dangerous in dangerous_patterns):
            print(f"[BLOCKED] Dangerous attribute: {k}")
            continue
        
        # Block if not in allowed list
        if allowed_keys and k not in allowed_keys:
            print(f"[BLOCKED] Key not allowed: {k}")
            continue
        
        if hasattr(dst, '__getitem__'):
            if dst.get(k) and isinstance(v, dict):
                safe_merge(v, dst.get(k), allowed_keys)
            else:
                dst[k] = v
        elif hasattr(dst, k) and isinstance(v, dict):
            safe_merge(v, getattr(dst, k), allowed_keys)
        else:
            setattr(dst, k, v)


def run_test(name: str, payload: Dict[str, Any], target: Any, merge_func) -> None:
    """Run a single pollution test."""
    print(f"\n{'='*60}")
    print(f"TEST: {name}")
    print(f"{'='*60}")
    print(f"Payload: {json.dumps(payload, indent=2)}")
    print(f"\nBefore merge:")
    print(f"  vars(target): {vars(target)}")
    if hasattr(target, 'execute_task'):
        print(f"  execute_task(): {target.execute_task()}")
    
    try:
        merge_func(payload, target)
        print(f"\nAfter merge:")
        print(f"  vars(target): {vars(target)}")
        if hasattr(target, 'execute_task'):
            print(f"  execute_task(): {target.execute_task()}")
        print(f"\n✓ Test completed")
    except Exception as e:
        print(f"\n✗ Test failed: {e}")


def main():
    print("="*60)
    print("CLASS POLLUTION TEST HARNESS")
    print("="*60)
    print("\n⚠️  WARNING: Only use in isolated test environments!")
    print("\nAvailable tests:")
    print("  1. Basic attribute injection")
    print("  2. Class name pollution")
    print("  3. Inheritance chain pollution")
    print("  4. Function default override")
    print("  5. Safe merge comparison")
    print("\nRunning all tests...\n")
    
    # Test 1: Basic attribute injection
    emp1 = TestEmployee()
    run_test(
        "Basic Attribute Injection",
        {"name": "Hacker", "department": "Security"},
        emp1,
        vulnerable_merge
    )
    
    # Test 2: Class name pollution
    emp2 = TestEmployee()
    run_test(
        "Class Name Pollution",
        {"__class__": {"__qualname__": "PollutedEmployee"}},
        emp2,
        vulnerable_merge
    )
    
    # Test 3: Inheritance chain pollution
    mgr1 = TestManager()
    run_test(
        "Inheritance Chain Pollution",
        {
            "__class__": {
                "__base__": {
                    "__qualname__": "PollutedEmployee"
                }
            }
        },
        mgr1,
        vulnerable_merge
    )
    
    # Test 4: Function default override
    mgr2 = TestManager()
    run_test(
        "Function Default Override",
        {
            "__class__": {
                "__init__": {
                    "__globals__": {
                        "TestManager": {
                            "execute_task": {
                                "__kwdefaults__": {
                                    "command": "echo polluted"
                                }
                            }
                        }
                    }
                }
            }
        },
        mgr2,
        vulnerable_merge
    )
    
    # Test 5: Safe merge comparison
    emp3 = TestEmployee()
    print(f"\n{'='*60}")
    print(f"TEST: Safe Merge Comparison")
    print(f"{'='*60}")
    print(f"\nUsing safe_merge with same payload:")
    safe_merge(
        {"__class__": {"__qualname__": "PollutedEmployee"}},
        emp3
    )
    print(f"\nAfter safe merge:")
    print(f"  vars(emp3): {vars(emp3)}")
    print(f"  Class name: {emp3.__class__.__qualname__}")
    print(f"\n✓ Safe merge blocked the pollution!")
    
    print(f"\n{'='*60}")
    print("All tests completed!")
    print(f"{'='*60}")


if __name__ == '__main__':
    main()
