---
name: security-tools-lookup
description: A comprehensive reference for security testing tools and resources. Use this skill whenever the user mentions security tools, penetration testing, bug bounty hunting, OSINT gathering, web security testing, Windows/Active Directory exploitation, firmware analysis, or any cybersecurity reconnaissance task. Trigger on keywords like: pentest, bug bounty, OSINT, recon, vulnerability scanning, web security, AD exploitation, firmware analysis, C2, lateral movement, or when users ask for tool recommendations for security work.
---

# Security Tools Reference

A curated collection of security testing tools organized by domain. Use this to quickly find the right tool for your security testing task.

## How to Use This Skill

1. **Identify your task** - What are you trying to accomplish? (recon, exploitation, analysis, etc.)
2. **Find the relevant category** - Match your task to one of the sections below
3. **Select appropriate tools** - Choose tools based on your specific needs
4. **Check prerequisites** - Some tools require specific environments or permissions

---

## 🔵 Blue Team / Defense

Tools for defensive security, monitoring, and detection.

| Tool | Purpose | Link |
|------|---------|------|
| **attack_monitor** | Attack monitoring and detection | https://github.com/yarox24/attack_monitor |
| **BLUESPAWN** | Blue team training platform | https://github.com/ION28/BLUESPAWN |
| **lil-pwny** | Check disclosed accounts | https://github.com/PaperMtn/lil-pwny |
| **DeTTECT** | Detection engineering toolkit | https://github.com/rabobank-cdc/DeTTECT |

**Resources:**
- Rootkit detection guide: https://capsule8.com/blog/dont-get-kicked-out-a-tale-of-rootkits-and-other-backdoors/

---

## 🔍 OSINT (Open Source Intelligence)

Tools for gathering publicly available information.

### Search Engines & Databases

| Tool | Purpose | Link |
|------|---------|------|
| **Shodan** | Internet-connected device search | https://www.shodan.io |
| **Censys** | Certificate and service enumeration | https://censys.io |
| **Greynoise** | Noise filtering for security | https://viz.greynoise.io/table |
| **ZoomEye** | Cyber asset search engine | https://www.zoomeye.org |
| **FOFA** | Asset search (Chinese) | https://fofa.so |
| **Onyphe** | Vulnerable device search | https://www.onyphe.io |
| **BinaryEdge** | OSINT platform | https://app.binaryedge.io |
| **Hunter.io** | Email finder | https://hunter.io |
| **Wigle** | WiFi network mapping | https://wigle.net |
| **BuiltWith** | Technology profiler | https://builtwith.com |
| **Oshadan** | Shodan alternative | https://www.oshadan.com |

### Tools & Scripts

| Tool | Purpose | Link |
|------|---------|------|
| **kamerka** | Webcam enumeration | https://github.com/3vangel1st/kamerka |
| **google_dork_list** | Google dork collection | https://github.com/BullsEye0/google_dork_list |
| **lure** | OSINT automation | https://github.com/highmeh/lure |
| **SpiderFoot** | Automated OSINT | https://www.spiderfoot.net |
| **gitleaks** | Secret detection in repos | https://github.com/zricethezav/gitleaks |
| **Subdomain Finder** | 8 subdomain tools | https://www.nmmapper.com/sys/tools/subdomainfinder/ |
| **GhostProject** | OSINT platform | https://ghostproject.fr |

---

## 🌐 Web Security

Tools for web application testing and vulnerability discovery.

### Scanners & Recon

| Tool | Purpose | Link |
|------|---------|------|
| **ATSCAN** | Web vulnerability scanner | https://github.com/AlisamTechnology/ATSCAN |
| **skipfish** | Web app security scanner | https://github.com/spinkham/skipfish |
| **Trishul** | Burp plugin for vuln detection | https://github.com/gauravnarwani97/Trishul |
| **XRCross** | Multi-vuln scanner (XSS, SSRF, CORS, etc.) | https://github.com/pikpikcu/xrcross |
| **Monitorizer** | Web monitoring | https://github.com/BitTheByte/Monitorizer/ |
| **masscan** | Fast port scanner | https://github.com/robertdavidgraham/masscan |
| **httprobe** | Check web server accessibility | https://github.com/tomnomnom/httprobe |

### Subdomain Discovery

| Tool | Purpose | Link |
|------|---------|------|
| **Sublist3r** | Subdomain enumeration | https://github.com/aboul3la/Sublist3r |
| **aiodnsbrute** | Async DNS brute force | https://github.com/blark/aiodnsbrute |
| **crt.sh** | Certificate transparency search | https://crt.sh |
| **github-subdomains** | Subdomains from GitHub | https://github.com/gwen001/github-search/blob/master/github-subdomains.py |
| **JSFinder** | Subdomains from JS files | https://github.com/Threezh1/JSFinder |
| **hakrawler** | Asset discovery | https://github.com/hakluke/hakrawler |

### Burp Suite Extensions

| Tool | Purpose | Link |
|------|---------|------|
| **Autorize** | Auth testing automation | https://github.com/Quitten/Autorize |
| **Dr. Watson** | Offline domain analysis | https://github.com/prodigysml/Dr.-Watson |
| **Bookmarks** | Repeater tab management | https://github.com/TypeError/Bookmarks/blob/master/README.md |

### Other Web Tools

| Tool | Purpose | Link |
|------|---------|------|
| **KeyFinder** | API key discovery | https://github.com/momenbasel/KeyFinder |
| **XSpear** | XSS testing | https://github.com/hahwul/XSpear |
| **google-dorker** | Google dork automation | https://github.com/izo30/google-dorker |
| **dom-red** | Open redirect checker | https://github.com/Naategh/dom-red |
| **postMessage-tracker** | postMessage analysis | https://github.com/fransr/postMessage-tracker |
| **MyFuzzingDict** | Web fuzzing dictionary | https://github.com/C1h2e1/MyFuzzingDict |
| **WebHackersWeapons** | Tool collection | https://github.com/hahwul/WebHackersWeapons |

### Checklists & Resources

- Bug bounty checklist: https://github.com/sehno/Bug-bounty/blob/master/bugbounty_checklist.md
- Beginner resources: https://github.com/nahamsec/Resources-for-Beginner-Bug-Bounty-Hunters/

---

## 🪟 Windows & Active Directory

Tools for Windows security testing and AD exploitation.

### Lateral Movement & Persistence

| Tool | Purpose | Link |
|------|---------|------|
| **PoisonHandler** | Lateral movement | https://github.com/Mr-Un1k0d3r/PoisonHandler |
| **injection** | Process injection techniques | https://github.com/odzhan/injection |
| **Red_Team** | Red team scripts | https://github.com/BankSecurity/Red_Team |

### AD & GPO

| Tool | Purpose | Link |
|------|---------|------|
| **Grouper2** | AD GPO misconfiguration finder | https://github.com/l0ss/Grouper2 |
| **AD Exploitation Cheat Sheet** | AD attack reference | https://github.com/Integration-IT/Active-Directory-Exploitation-Cheat-Sheet |

### Evasion & Obfuscation

| Tool | Purpose | Link |
|------|---------|------|
| **TRIX** | LOLBins reference | https://freddiebarrsmith.com/trix/trix.html |
| **xencrypt** | PowerShell encryption | https://github.com/the-xentropy/xencrypt |
| **SecureString obfuscation** | PS obfuscation guide | https://www.wietzebeukema.nl/blog/powershell-obfuscation-using-securestring |

### Techniques & Resources

- Persistence (IFEO): https://gist.github.com/netbiosX/ee35fcd3722e401a38136cff7b751d79
- Parent PID spoofing: https://pentestlab.blog/2020/02/24/parent-pid-spoofing/
- Windows Internals: https://windows-internals.com/faxing-your-way-to-system/
- Stealth C2: https://shells.systems/introducing-ninja-c2-the-c2-built-for-stealth-red-team-operations/
- Document tracking: https://bestestredteam.com/2018/10/02/tracking-pixel-in-microsoft-office-document/

---

## 🔧 Firmware & IoT

Tools for firmware analysis and IoT security testing.

### Automated Analysis

| Tool | Purpose | Link |
|------|---------|------|
| **firmwalker** | Firmware analysis | https://github.com/craigz28/firmwalker |
| **FACT_core** | Firmware analysis platform | https://github.com/fkie-cad/FACT_core |
| **bytesweep-go** | Firmware scanning | https://gitlab.com/bytesweep/bytesweep-go |
| **FIRMADYNE** | Firmware emulation | https://github.com/firmadyne/firmadyne/ |

### Learning & Practice

| Resource | Purpose | Link |
|----------|---------|------|
| **IoTGoat** | Vulnerable firmware for practice | https://github.com/scriptingxss/IoTGoat |
| **OWASP FSTM** | Firmware testing methodology | https://github.com/scriptingxss/owasp-fstm |
| **Minded Security Blog** | IoT pentesting guide (Part 1) | https://blog.mindedsecurity.com/2018/09/pentesting-iot-devices-part-1-static.html |
| **Minded Security Blog** | IoT pentesting guide (Part 2) | https://blog.mindedsecurity.com/2018/10/pentesting-iot-devices-part-2-dynamic.html |

### Extraction

- Firmware extraction guide: https://www.youtube.com/watch?v=Kxvpbu9STU4

---

## 📦 Other Tools & Resources

### Code Analysis

| Tool | Purpose | Link |
|------|---------|------|
| **Sourcetrail** | Static code analysis | https://github.com/CoatiSoftware/Sourcetrail |
| **jackdaw** | Mimikatz analysis | https://github.com/skelsec/jackdaw |

### Specialized Tools

| Tool | Purpose | Link |
|------|---------|------|
| **LKWA** | Various tools | https://github.com/weev3/LKWA |
| **endlessh** | SSH tarpit | https://github.com/skeeto/endlessh |
| **HomePWN** | IoT hacking (WiFi, BLE, etc.) | https://github.com/ElevenPaths/HomePWN |
| **scantron** | Automated scanning | https://github.com/rackerlabs/scantron |
| **bbrecon** | Bug bounty recon | https://github.com/serain/bbrecon |
| **Theia IDE** | Online IDE | https://theia-ide.org |

### Cloud & Infrastructure

- AWS security tools: https://github.com/toniblyx/my-arsenal-of-aws-security-tools
- IP rotation guide: https://medium.com/@lokeshdlk77/how-to-rotate-ip-address-in-brute-force-attack-e66407259212
- IFS for operations: https://www.trustwave.com/en-us/resources/blogs/spiderlabs-blog/using-the-interplanetary-file-system-for-offensive-operations/

### Learning Resources

- Learn C by creating a rootkit: https://h0mbre.github.io/Learn-C-By-Creating-A-Rootkit/
- BLE CTF: https://www.hackerdecabecera.com/2019/12/blectf-capture-flag-en-formato-hardware.html
- iOS pentesting: https://medium.com/macoclock/jailbreak-and-stuff-kickstart-tools-and-techniques-for-ios-application-pentesting-6fa53a3987ab
- Electron.js hacking: https://github.com/doyensec/awesome-electronjs-hacking
- Keywords list: https://github.com/random-robbie/keywords/blob/master/keywords.txt

---

## Quick Selection Guide

**For Bug Bounty Hunting:**
- Start with OSINT tools (Shodan, Sublist3r, SpiderFoot)
- Use web scanners (Trishul, XRCross, skipfish)
- Reference the bug bounty checklist

**For Red Team Operations:**
- Windows: PoisonHandler, Grouper2, TRIX
- Evasion: xencrypt, SecureString obfuscation
- C2: Ninja C2

**For Blue Team / Detection:**
- attack_monitor, BLUESPAWN, DeTTECT
- Check disclosed accounts with lil-pwny

**For Firmware/IoT:**
- Analysis: firmwalker, FACT_core, FIRMADYNE
- Practice: IoTGoat
- Methodology: OWASP FSTM

**For Web App Testing:**
- Recon: Sublist3r, hakrawler, JSFinder
- Scanning: ATSCAN, Trishul, XRCross
- Burp: Autorize, Dr. Watson

---

## Important Notes

1. **Legal Use Only** - All tools should only be used on systems you own or have explicit permission to test
2. **Stay Updated** - Tool repositories may be deprecated; check for active maintenance
3. **Environment Setup** - Many tools require specific dependencies; check README files
4. **Documentation** - Always read tool documentation before use
5. **Bug Bounty Rules** - Follow program rules and scope when testing

---

## Contributing

This skill is based on the HackTricks training resources. If you find tools that should be added or links that are broken, please note them for future updates.
