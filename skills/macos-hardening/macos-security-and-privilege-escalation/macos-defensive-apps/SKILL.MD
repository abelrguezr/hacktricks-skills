---
name: macos-defensive-apps
description: How to deploy and use macOS defensive security applications including firewalls (Little Snitch, LuLu), persistence detection tools (KnockKnock, BlockBlock), and keylogger detection (ReiKey). Use this skill whenever the user mentions macOS security, defensive tools, firewall setup, malware detection, persistence monitoring, keylogger protection, or wants to harden their Mac against threats. Also trigger when users ask about Objective-See tools, network monitoring on Mac, or how to detect suspicious connections.
---

# macOS Defensive Apps

This skill helps you deploy and use essential macOS defensive security applications. These tools provide visibility into network connections, persistence mechanisms, and potential keyloggers on your Mac.

## Quick Start

If you want to get started quickly, run the helper script to check which tools are installed and get installation guidance:

```bash
./scripts/check-defensive-apps.sh
```

## Firewalls

Firewalls monitor and control network connections made by applications on your Mac.

### Little Snitch

**What it does:** Monitors every connection made by each process and shows alerts for new connections. Features a comprehensive GUI for viewing connection data.

**Modes:**
- Silent allow connections
- Silent deny connections  
- Alert mode (shows popup for each new connection)

**Best for:** Users who want detailed visibility and granular control over all network traffic.

**Installation:**
```bash
# Download from https://www.obdev.at/products/littlesnitch/index.html
# Install the .pkg file and restart your Mac
```

**Usage tips:**
- Start in "alert" mode to learn about your apps' network behavior
- Create rules to allow/block specific apps or destinations
- Use the GUI to review historical connection data
- Consider the paid version for advanced features

### LuLu

**What it does:** Free, open-source firewall from Objective-See that alerts you for suspicious outbound connections.

**Best for:** Users who want basic outbound connection monitoring without cost.

**Installation:**
```bash
# Download from https://objective-see.org/products/lulu.html
# Install the .pkg file
```

**Usage tips:**
- Less feature-rich than Little Snitch but completely free
- Focuses on blocking suspicious outbound connections
- Good baseline protection for most users
- Check the GUI regularly for blocked connection attempts

## Persistence Detection

These tools help you identify how malware might maintain access to your system across reboots.

### KnockKnock

**What it does:** Scans multiple locations where malware could establish persistence. It's a one-shot tool (not continuous monitoring).

**What it checks:**
- LaunchAgents and LaunchDaemons
- Login items
- Kernel extensions
- Other persistence locations

**Best for:** Periodic security audits, investigating suspicious behavior, or after a potential compromise.

**Installation:**
```bash
# Download from https://objective-see.org/products/knockknock.html
# Run the application (no installation required)
```

**Usage tips:**
- Run regularly (weekly or monthly) to establish a baseline
- Save reports to track changes over time
- Review unfamiliar items and research them
- Use after any suspicious activity to check for persistence

### BlockBlock

**What it does:** Continuously monitors for processes that create persistence mechanisms. Alerts you when something tries to establish persistence.

**Best for:** Continuous monitoring of persistence attempts, catching malware as it tries to establish itself.

**Installation:**
```bash
# Download from https://objective-see.org/products/blockblock.html
# Install the .pkg file
```

**Usage tips:**
- Runs in the background monitoring for persistence changes
- Alerts when new persistence mechanisms are created
- Review alerts to determine if they're legitimate or suspicious
- Works well alongside KnockKnock for comprehensive coverage

## Keylogger Detection

### ReiKey

**What it does:** Detects keyloggers that install keyboard "event taps" to capture keystrokes.

**Best for:** Detecting active keylogging attempts, especially after potential compromise or when using public/shared Macs.

**Installation:**
```bash
# Download from https://objective-see.org/products/reikey.html
# Run the application (no installation required)
```

**Usage tips:**
- Run when you suspect keylogging
- Check after installing software from untrusted sources
- Use on shared or public Macs before entering sensitive information
- Review the list of event taps and research unfamiliar ones

## Recommended Setup

For comprehensive macOS defense, consider this layered approach:

1. **Always-on protection:**
   - LuLu (free) or Little Snitch (paid) for network monitoring
   - BlockBlock for persistence monitoring

2. **Periodic checks:**
   - KnockKnock weekly or monthly
   - ReiKey when suspicious activity is suspected

3. **After potential compromise:**
   - Run all tools immediately
   - Save reports for analysis
   - Compare against your baseline

## Objective-See Tools

Most of these tools are from Objective-See, a respected security research company. Their tools are:
- Free and open-source
- Regularly updated
- Well-documented
- Trusted by security professionals

Visit https://objective-see.org/ for more information and updates.

## Troubleshooting

**Tools not appearing in menu bar:**
- Check System Preferences > Security & Privacy > Privacy
- Ensure the tool has necessary permissions
- Restart the application

**Alerts not showing:**
- Verify the tool is running (check menu bar)
- Check for macOS security settings blocking the tool
- Review the tool's documentation for permission requirements

**False positives:**
- Legitimate apps may trigger alerts (especially during updates)
- Research unfamiliar items before blocking
- Create allow rules for trusted applications

## Next Steps

After deploying these tools:
1. Establish a baseline of normal behavior
2. Set up a regular review schedule
3. Document any unusual findings
4. Consider additional hardening measures (see other security skills)

---

**Note:** These tools provide visibility and defense but are not a complete security solution. Combine with good security practices, regular updates, and caution when installing software.
