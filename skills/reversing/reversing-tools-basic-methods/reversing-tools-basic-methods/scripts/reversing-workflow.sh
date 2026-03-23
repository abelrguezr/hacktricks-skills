#!/bin/bash
# Reversing Workflow Helper
# Guides you through the reverse engineering process

set -e

echo "=== Reverse Engineering Workflow Guide ==="
echo ""

# Function to display section
show_section() {
    echo ""
    echo "=== $1 ==="
    echo ""
}

# Function to wait for user
wait_for_user() {
    echo ""
    read -p "Press Enter to continue..."
}

show_section "Step 1: Identify Target Type"

echo "What type of binary are you analyzing?"
echo ""
echo "1. .NET assembly (.dll, .exe)"
echo "2. Java (.jar, .class)"
echo "3. Shellcode"
echo "4. Wasm (.wasm)"
echo "5. GBA game (.gba)"
echo "6. Delphi binary"
echo "7. Golang binary"
echo "8. Rust binary"
echo "9. Other native binary"
echo ""

read -p "Enter choice (1-9): " TARGET_TYPE

case $TARGET_TYPE in
    1)
        show_section ".NET Analysis"
        echo "Recommended tools:"
        echo "  - dnSpy/dnSpyEx: Decompile, modify, recompile"
        echo "  - ILSpy: Quick decompilation (VSCode extension available)"
        echo "  - dotPeek: Examine assemblies, save as VS project"
        echo ""
        echo "Debugging setup:"
        echo "  1. Modify assembly attributes to disable optimizations"
        echo "  2. Compile and save module"
        echo "  3. Attach to w3wp.exe if running under IIS"
        echo "  4. Load all modules in Assembly Explorer"
        ;;
    2)
        show_section "Java Analysis"
        echo "Recommended tools:"
        echo "  - JADX: https://github.com/skylot/jadx"
        echo "  - JD-GUI: https://github.com/java-decompiler/jd-gui/releases"
        echo ""
        echo "Workflow:"
        echo "  1. Open .jar or .class file"
        echo "  2. Browse decompiled source"
        echo "  3. Search for key functions"
        ;;
    3)
        show_section "Shellcode Analysis"
        echo "Recommended tools:"
        echo "  - Blobrunner: Allocate and debug"
        echo "  - jmp2it: Alternative allocator"
        echo "  - scdbg: Analyze functions and deobfuscate"
        echo "  - Cutter: Emulate and inspect"
        echo "  - CyberChef: Disassemble online"
        echo ""
        echo "Workflow:"
        echo "  1. Run scdbg for initial analysis"
        echo "  2. Use Blobrunner to allocate in memory"
        echo "  3. Attach debugger (x64dbg or IDA)"
        echo "  4. Set breakpoint at allocation address"
        echo "  5. Resume and debug"
        ;;
    4)
        show_section "Wasm Analysis"
        echo "Recommended tools:"
        echo "  - wasm2wat: https://webassembly.github.io/wabt/demo/wasm2wat/"
        echo "  - wat2wasm: https://webassembly.github.io/wabt/demo/wat2wasm/"
        echo "  - Jeb: https://www.pnfsoftware.com/jeb/demo"
        echo "  - wasmdec: https://github.com/wwwg/wasmdec"
        echo ""
        echo "Workflow:"
        echo "  1. Convert wasm to wat (text format)"
        echo "  2. Read and analyze wat code"
        echo "  3. Modify if needed"
        echo "  4. Convert back to wasm"
        ;;
    5)
        show_section "GBA Game Analysis"
        echo "Recommended tools:"
        echo "  - no\$gba: GUI debugger"
        echo "  - mgba: CLI debugger"
        echo "  - gba-ghidra-loader: Ghidra plugin"
        echo "  - GhidraGBA: Ghidra plugin"
        echo ""
        echo "Key input values:"
        echo "  A=1, B=2, SELECT=4, START=8"
        echo "  RIGHT=16, LEFT=32, UP=64, DOWN=128"
        echo "  R=256, L=512"
        echo ""
        echo "Look for KEYINPUT at address 0x4000130"
        ;;
    6)
        show_section "Delphi Analysis"
        echo "Recommended tools:"
        echo "  - IDR: https://github.com/crypto2020/IDR"
        echo "  - IDA-For-Delphi: https://github.com/Coldzer0/IDA-For-Delphi"
        echo ""
        echo "Workflow:"
        echo "  1. Load binary in IDA"
        echo "  2. Press ALT+F7 to import Python plugin"
        echo "  3. Select IDA-For-Delphi plugin"
        echo "  4. Start debugging (F9)"
        echo "  5. Breakpoint hits at real code start"
        ;;
    7)
        show_section "Golang Analysis"
        echo "Recommended tools:"
        echo "  - IDAGolangHelper: https://github.com/sibears/IDAGolangHelper"
        echo ""
        echo "Workflow:"
        echo "  1. Load binary in IDA"
        echo "  2. Press ALT+F7 to import Python plugin"
        echo "  3. Select IDAGolangHelper"
        echo "  4. Function names will be resolved"
        ;;
    8)
        show_section "Rust Analysis"
        echo "Recommended approach:"
        echo "  1. Search for functions containing ::main"
        echo "  2. Identify main function from binary name"
        echo "  3. Search function names online for documentation"
        echo "  4. Analyze inputs and outputs"
        ;;
    9)
        show_section "Native Binary Analysis"
        echo "Recommended tools:"
        echo "  - IDA Pro: Comprehensive disassembler"
        echo "  - Ghidra: Free NSA disassembler"
        echo "  - x64dbg/x32dbg: Windows debugger"
        echo "  - GDB: Linux debugger"
        echo "  - Cutter: radare2 GUI"
        echo ""
        echo "For DLL debugging:"
        echo "  - Load rundll32.exe in debugger"
        echo "  - Set command line: rundll32.exe path\to\dll.dll,FunctionName"
        echo "  - Enable DLL Entry breakpoint"
        ;;
    *)
        echo "Invalid choice. Please run the script again."
        exit 1
        ;;
esac

wait_for_user

show_section "Step 2: Check for Obfuscation"

echo "Is the binary obfuscated?"
echo ""
echo "Common obfuscators:"
echo "  - Movfuscator: All instructions become 'mov'"
echo "  - Custom packers: Compressed/encrypted sections"
echo "  - Control flow obfuscation: Complex jump patterns"
echo ""

read -p "Do you suspect obfuscation? (y/n): " OBFUSCATED

if [ "$OBFUSCATED" = "y" ] || [ "$OBFUSCATED" = "Y" ]; then
    echo ""
    echo "For movfuscator:"
    echo "  - Try demovfuscator: https://github.com/kirschju/demovfuscator"
    echo "  - Install: apt-get install libcapstone-dev libz3-dev cmake"
    echo "  - CTF workaround: https://dustri.org/b/defeating-the-recons-movfuscator-crackme.html"
    echo ""
    echo "For shellcode obfuscation:"
    echo "  - Use scdbg to detect self-decoding"
    echo "  - Dump decoded version with: scdbg.exe -f shellcode -d"
fi

wait_for_user

show_section "Step 3: Static Analysis"

echo "Before dynamic analysis:"
echo "  1. Decompile/disassemble the binary"
    echo "  2. Identify key functions and entry points"
    echo "  3. Map out control flow"
    echo "  4. Document important addresses and strings"
    echo "  5. Look for hardcoded values or keys"
    echo ""

wait_for_user

show_section "Step 4: Dynamic Analysis"

echo "During debugging:"
echo "  1. Set breakpoints at key locations"
    echo "  2. Trace execution flow"
    echo "  3. Monitor memory and registers"
    echo "  4. Test hypotheses by modifying code"
    echo "  5. Verify changes work as expected"
    echo ""

wait_for_user

show_section "Step 5: Documentation"

echo "Document your findings:"
echo "  - Function names and purposes"
    echo "  - Key memory addresses"
    echo "  - Logic flow diagrams"
    echo "  - Important strings and values"
    echo "  - Modifications made and results"
    echo ""

echo "=== Workflow Complete ==="
echo ""
echo "Remember:"
echo "  - Start simple, then go deeper"
    echo "  - Document as you go"
    echo "  - Test your hypotheses"
    echo "  - Use the right tool for the job"
    echo ""
