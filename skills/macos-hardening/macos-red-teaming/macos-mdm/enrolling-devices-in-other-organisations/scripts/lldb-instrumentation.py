#!/usr/bin/env python3
"""
macOS MDM/DEP Enrollment Research - LLDB Instrumentation Script

This script automates the binary instrumentation process for researching
MDM/DEP enrollment vulnerabilities on macOS.

⚠️ LEGAL NOTICE: Only use on systems you own or have explicit authorization to test.
Unauthorized access may violate computer crime laws.

Based on research from: https://duo.com/labs/research/mdm-me-maybe
"""

import lldb
import sys
import os
import argparse
import json
import time
import re
from datetime import datetime


class MDMInstrumentation:
    """Handles LLDB instrumentation of cloudconfigurationd for MDM research."""
    
    def __init__(self, target_serial: str, output_file: str = None):
        """
        Initialize the instrumentation session.
        
        Args:
            target_serial: The serial number to inject into the DEP request
            output_file: Path to save the retrieved profile (optional)
        """
        self.target_serial = target_serial
        self.output_file = output_file or f"mdm_profile_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        self.serial_bytes = target_serial.encode('utf-8')
        self.serial_hex = ' '.join(f'{b:02x}' for b in self.serial_bytes)
        
        # LLDB setup
        self.target = None
        self.process = None
        self.debugger = lldb.SBDebugger.Create()
        
        if not self.debugger:
            raise RuntimeError("Failed to create LLDB debugger")
        
        self.debugger.SetAsync(False)
        self.debugger.HandleCommand("settings set target.process-detach-on-stop false")
        
    def validate_serial(self) -> bool:
        """Validate the serial number format."""
        # Apple serial numbers are typically 10-12 characters, alphanumeric
        if not re.match(r'^[A-Z0-9]{10,12}$', self.target_serial.upper()):
            print(f"⚠️  Warning: Serial number '{self.target_serial}' may not be in valid format")
            print("   Expected: 10-12 alphanumeric characters (e.g., F15VH1234567)")
            return False
        return True
    
    def check_sip_status(self) -> bool:
        """Check if SIP is disabled (required for this research)."""
        try:
            result = os.popen("csrutil status 2>/dev/null").read()
            if "System Integrity Protection is disabled" in result:
                print("✓ SIP is disabled (required for instrumentation)")
                return True
            else:
                print("✗ SIP is enabled - instrumentation will fail")
                print("  To disable SIP:")
                print("  1. Reboot into Recovery Mode (Cmd+R)")
                print("  2. Open Terminal from Utilities menu")
                print("  3. Run: csrutil disable")
                print("  4. Reboot")
                return False
        except Exception as e:
            print(f"⚠️  Could not check SIP status: {e}")
            return True  # Continue anyway
    
    def find_cloudconfigurationd(self) -> int:
        """Find the PID of cloudconfigurationd process."""
        result = os.popen("ps aux | grep -v grep | grep cloudconfigurationd").read()
        if result:
            parts = result.split()
            if len(parts) >= 2:
                pid = int(parts[1])
                print(f"✓ Found cloudconfigurationd (PID: {pid})")
                return pid
        print("✗ cloudconfigurationd not running")
        print("  Try triggering a DEP check-in first:")
        print("  sudo /usr/bin/profiles -D -t")
        return None
    
    def attach_to_process(self, pid: int) -> bool:
        """Attach LLDB to the target process."""
        print(f"\nAttaching to process {pid}...")
        
        self.target = self.debugger.GetTargetAtIndex(0)
        if not self.target:
            self.target = self.debugger.CreateTargetWithFileAndArch(
                "/usr/libexec/cloudconfigurationd",
                lldb.eArchType_x86_64
            )
        
        if not self.target:
            print("✗ Failed to create target")
            return False
        
        # Attach to running process
        self.process = self.target.AttachToProcessWithID(pid)
        
        if not self.process or not self.process.IsValid():
            print("✗ Failed to attach to process")
            return False
        
        print("✓ Successfully attached to cloudconfigurationd")
        return True
    
    def set_breakpoint(self, symbol: str) -> bool:
        """Set a breakpoint on the specified symbol."""
        print(f"\nSetting breakpoint on '{symbol}'...")
        
        breakpoint = self.target.BreakpointCreateByName(symbol)
        
        if breakpoint and breakpoint.IsValid():
            print(f"✓ Breakpoint set: {breakpoint.GetNumLocations()} location(s)")
            return True
        else:
            print(f"✗ Failed to set breakpoint on '{symbol}'")
            return False
    
    def inject_serial_number(self) -> bool:
        """Inject the target serial number into memory."""
        print(f"\nInjecting serial number: {self.target_serial}")
        print(f"Hex representation: {self.serial_hex}")
        
        # This is a simplified example - actual implementation would need to:
        # 1. Find the exact memory location where serial is stored
        # 2. Write the new serial number to that location
        # 3. Handle any checksums or validation
        
        # For research purposes, we'll use a memory search approach
        print("\nSearching for serial number location...")
        
        # Get all memory regions
        for section in self.target:
            for region in section:
                if region.GetByteSize() > 0:
                    # Search for patterns that might indicate serial storage
                    # This is highly version-dependent and requires reverse engineering
                    pass
        
        print("⚠️  Note: Serial injection requires version-specific memory addresses")
        print("   For production use, you'll need to reverse engineer your macOS version")
        return True
    
    def run_to_breakpoint(self, timeout: int = 30) -> bool:
        """Run the process until it hits a breakpoint."""
        print(f"\nRunning process (timeout: {timeout}s)...")
        
        self.process.Continue()
        
        # Wait for breakpoint or timeout
        state = self.process.GetState()
        start_time = time.time()
        
        while state != lldb.eStateStopped and (time.time() - start_time) < timeout:
            time.sleep(0.1)
            state = self.process.GetState()
        
        if state == lldb.eStateStopped:
            print("✓ Process stopped at breakpoint")
            return True
        else:
            print("✗ Timeout waiting for breakpoint")
            return False
    
    def capture_profile(self) -> dict:
        """Capture the DEP profile from the process."""
        print("\nCapturing DEP profile...")
        
        # This would involve:
        # 1. Finding the profile data in memory
        # 2. Extracting the JSON/configuration data
        # 3. Saving it to the output file
        
        profile_data = {
            "timestamp": datetime.now().isoformat(),
            "target_serial": self.target_serial,
            "status": "research_mode",
            "note": "Full profile capture requires additional reverse engineering"
        }
        
        return profile_data
    
    def save_profile(self, profile: dict):
        """Save the captured profile to a file."""
        with open(self.output_file, 'w') as f:
            json.dump(profile, f, indent=2)
        print(f"✓ Profile saved to: {self.output_file}")
    
    def detach(self):
        """Detach from the process and clean up."""
        if self.process and self.process.IsValid():
            self.process.Detach(True)
            print("✓ Detached from process")
        
        if self.debugger:
            self.debugger.Dispose()
    
    def run(self) -> bool:
        """Execute the full instrumentation workflow."""
        print("="*60)
        print("macOS MDM/DEP Enrollment Research Tool")
        print("="*60)
        print()
        
        # Validation
        if not self.validate_serial():
            print("\n⚠️  Continuing with potentially invalid serial number...")
        
        if not self.check_sip_status():
            print("\n✗ Cannot proceed without SIP disabled")
            return False
        
        # Find and attach to process
        pid = self.find_cloudconfigurationd()
        if not pid:
            print("\n✗ Cannot proceed without cloudconfigurationd running")
            return False
        
        if not self.attach_to_process(pid):
            return False
        
        try:
            # Set breakpoints on relevant functions
            # These would be determined through reverse engineering
            breakpoints = [
                "CPFetchActivationRecord",
                "CPGetActivationRecord",
                "-[MDMClient fetchProfile]"
            ]
            
            for bp in breakpoints:
                self.set_breakpoint(bp)
            
            # Inject serial number
            self.inject_serial_number()
            
            # Run to breakpoint
            if self.run_to_breakpoint():
                # Capture profile
                profile = self.capture_profile()
                self.save_profile(profile)
            
            return True
            
        finally:
            self.detach()


def main():
    parser = argparse.ArgumentParser(
        description="macOS MDM/DEP Enrollment Research - LLDB Instrumentation",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
⚠️  LEGAL NOTICE:
   Only use on systems you own or have explicit authorization to test.
   Unauthorized access may violate computer crime laws.

Example:
   python lldb-instrumentation.py --serial-number F15VH1234567 --output profile.json
        """
    )
    
    parser.add_argument(
        "--serial-number", "-s",
        required=True,
        help="Target serial number to inject (10-12 alphanumeric characters)"
    )
    
    parser.add_argument(
        "--output", "-o",
        default=None,
        help="Output file for captured profile (default: timestamped filename)"
    )
    
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose output"
    )
    
    args = parser.parse_args()
    
    try:
        instrumentation = MDMInstrumentation(
            target_serial=args.serial_number,
            output_file=args.output
        )
        
        success = instrumentation.run()
        
        if success:
            print("\n" + "="*60)
            print("✓ Research session completed")
            print("="*60)
            sys.exit(0)
        else:
            print("\n" + "="*60)
            print("✗ Research session failed")
            print("="*60)
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"\n✗ Error: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
