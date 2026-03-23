#!/bin/bash
# Shellcode Analysis Helper Script
# Provides quick reference for shellcode analysis tools

set -e

if [ $# -lt 1 ]; then
    echo "=== Shellcode Analysis Tools ==="
    echo ""
    echo "Usage: $0 <shellcode_file> [options]"
    echo ""
    echo "Options:"
    echo "  --scdbg     Run scdbg analysis"
    echo "  --dump      Dump decoded shellcode"
    echo "  --info      Show tool information"
    echo ""
    echo "Available Tools:"
    echo ""
    echo "1. Blobrunner - Allocate and debug shellcode"
    echo "   - Allocates shellcode in memory"
    echo "   - Shows memory address"
    echo "   - Stops execution for debugger attachment"
    echo "   - Download: https://github.com/OALabs/BlobRunner/releases"
    echo ""
    echo "2. jmp2it - Alternative allocator"
    echo "   - Similar to Blobrunner"
    echo "   - Uses eternal loop technique"
    echo "   - Download: https://github.com/adamkramer/jmp2it/releases"
    echo ""
    echo "3. scdbg - Analysis and deobfuscation"
    echo "   - Shows which functions shellcode uses"
    echo "   - Detects self-decoding"
    echo "   - Can dump decoded shellcode"
    echo "   - Download: http://sandsprite.com/blogs/index.php?uid=7&pid=152"
    echo ""
    echo "4. Cutter - Emulation and inspection"
    echo "   - GUI for radare2"
    echo "   - Can emulate shellcode"
    echo "   - View stack in hex dump"
    echo "   - Download: https://github.com/rizinorg/cutter/releases"
    echo ""
    echo "5. CyberChef - Disassembly"
    echo "   - Online tool"
    echo "   - Recipe: To Hex → Disassemble x86"
    echo "   - URL: https://gchq.github.io/CyberChef/"
    echo ""
    exit 0
fi

SHELLCODE="$1"
shift

if [ ! -f "$SHELLCODE" ]; then
    echo "Error: File not found: $SHELLCODE"
    exit 1
fi

echo "=== Shellcode Analysis for: $SHELLCODE ==="
echo ""

while [ $# -gt 0 ]; do
    case "$1" in
        --scdbg)
            echo "Running scdbg analysis..."
            echo ""
            echo "Commands to run (if scdbg is installed):"
            echo "  scdbg.exe -f $SHELLCODE                    # Basic info"
            echo "  scdbg.exe -f $SHELLCODE -r                 # With report"
            echo "  scdbg.exe -f $SHELLCODE -i -r              # Interactive + report"
            echo "  scdbg.exe -f $SHELLCODE -d                 # Dump decoded"
            echo "  scdbg.exe -f $SHELLCODE /findsc            # Find start offset"
            echo ""
            if command -v scdbg.exe &> /dev/null; then
                echo "Running: scdbg.exe -f $SHELLCODE -r"
                scdbg.exe -f "$SHELLCODE" -r
            else
                echo "Note: scdbg.exe not found in PATH"
                echo "Download from: http://sandsprite.com/blogs/index.php?uid=7&pid=152"
            fi
            ;;
        --dump)
            echo "To dump decoded shellcode:"
            echo "  scdbg.exe -f $SHELLCODE -d"
            echo ""
            echo "Or use the scdbg GUI:"
            echo "  - Open scdbg"
            echo "  - Load $SHELLCODE"
            echo "  - Click 'Create Dump'"
            ;;
        --info)
            echo "File: $SHELLCODE"
            echo "Size: $(stat -c%s "$SHELLCODE" 2>/dev/null || stat -f%z "$SHELLCODE" 2>/dev/null) bytes"
            echo "Type: $(file "$SHELLCODE")"
            echo ""
            echo "Recommended workflow:"
            echo "1. Run scdbg for initial analysis"
            echo "2. Use Blobrunner or jmp2it to allocate in memory"
            echo "3. Attach x64dbg or IDA to the process"
            echo "4. Set breakpoint at allocation address"
            echo "5. Resume and debug"
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

echo ""
echo "=== Analysis Complete ==="
