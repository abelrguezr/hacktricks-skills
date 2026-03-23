#!/bin/bash
# .NET Debug Setup Script
# Modifies assembly attributes to enable debugging

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <assembly.dll|exe>"
    echo "This script helps prepare .NET assemblies for debugging with dnSpy"
    exit 1
fi

ASSEMBLY="$1"

if [ ! -f "$ASSEMBLY" ]; then
    echo "Error: File not found: $ASSEMBLY"
    exit 1
fi

echo "=== .NET Debug Setup Guide ==="
echo ""
echo "Target: $ASSEMBLY"
echo ""
echo "To enable debugging in dnSpy, you need to modify the assembly attributes:"
echo ""
echo "1. Open $ASSEMBLY in dnSpy"
echo "2. Find the assembly attributes (usually in AssemblyInfo.cs or similar)"
echo "3. Change from:"
echo "   [assembly: Debuggable(DebuggableAttribute.DebuggingModes.IgnoreSymbolStoreSequencePoints)]"
echo ""
echo "4. Change to:"
echo "   [assembly: Debuggable(DebuggableAttribute.DebuggingModes.Default |"
echo "       DebuggableAttribute.DebuggingModes.DisableOptimizations |"
echo "       DebuggableAttribute.DebuggingModes.IgnoreSymbolStoreSequencePoints |"
echo "       DebuggableAttribute.DebuggingModes.EnableEditAndContinue)]"
echo ""
echo "5. Compile and save via File → Save module..."
echo ""
echo "6. If running under IIS, restart with:"
echo "   iisreset /noforce"
echo ""
echo "7. Attach debugger:"
echo "   - Debug → Attach to Process..."
echo "   - Select w3wp.exe"
echo "   - Click Attach"
echo ""
echo "8. Load modules:"
echo "   - Debug → Break All"
echo "   - Debug → Windows → Modules"
echo "   - Open All Modules"
echo "   - Sort Assemblies"
echo ""
echo "=== Ready to debug ==="
