---
name: kiosk-escape
description: Techniques for escaping restricted kiosk, locked-down, or single-application environments on Windows, iPad, and browsers. Use this skill whenever the user mentions kiosk mode, locked-down devices, restricted desktops, Citrix/RDS/VDI environments, single-app mode, or needs to break out of a GUI application to access the underlying OS. Also use when the user asks about physical device access, keyboard shortcuts for escape, or bypassing application restrictions.
---

# Kiosk Escape Techniques

This skill provides techniques for breaking out of restricted environments like kiosks, locked-down workstations, Citrix/RDS/VDI sessions, and single-application modes.

## Physical Layer Checks

Start here if you have physical access to the device:

| Component | Action |
|-----------|--------|
| **Power button** | Turn device off/on to potentially expose the start screen |
| **Power cable** | Briefly cut power to check if device reboots to a different state |
| **USB ports** | Connect a physical keyboard for additional shortcuts |
| **Ethernet** | Network scan or sniffing may enable further exploitation |

## GUI Application Layer

### Common Dialog Exploitation

Many applications offer dialogs that provide full Explorer functionality. Look for:

- Close/Close as
- Open/Open with
- Print
- Export/Import
- Search
- Scan

**What to try in these dialogs:**
- Modify or create new files
- Create symbolic links
- Access restricted areas
- Execute other applications

### Command Execution via "Open With"

Use "Open with" to launch shells:

**Windows binaries:**
- `cmd.exe`, `command.com`
- `Powershell`, `Powershell ISE`
- `mmc.exe`, `at.exe`, `taskschd.msc`
- See [LOLBAS Project](https://lolbas-project.github.io/) for more

**\*NIX shells:**
- `bash`, `sh`, `zsh`
- See [GTFOBins](https://gtfobins.github.io/) for more

---

## Windows Techniques

### Bypassing Path Restrictions

**Environment variables** - These point to accessible paths:

| Variable | Description |
|----------|-------------|
| `%ALLUSERSPROFILE%` | All users profile directory |
| `%APPDATA%` | Current user's application data |
| `%TEMP%`, `%TMP%` | Temporary files directory |
| `%USERPROFILE%` | Current user's profile |
| `%SYSTEMROOT%`, `%WINDIR%` | Windows directory |
| `%PROGRAMFILES%` | Program files directory |
| `%COMPUTERNAME%` | Computer name |
| `%COMSPEC%` | Command interpreter path |

**Other protocols to try:**
- `about:`, `data:`, `ftp:`, `file:`, `mailto:`, `news:`, `res:`, `telnet:`, `view-source:`

**Symbolic links** - Create links to restricted areas

**UNC paths** - Connect to shared folders:
- `\\127.0.0.1\c$\Windows\System32` (local C$ share)

### Shell URIs

Type these in address bars or file dialogs:

```
shell:Administrative Tools
shell:DocumentsLibrary
shell:Libraries
shell:UserProfiles
shell:Personal
shell:SearchHomeFolder
shell:System
shell:NetworkPlacesFolder
shell:SendTo
shell:Common Administrative Tools
shell:MyComputerFolder
shell:InternetFolder
shell:ControlPanelFolder
shell:Windows
shell:ProgramFiles
shell:Profile
```

**GUID-based shell URIs:**
```
shell:::{21EC2020-3AEA-1069-A2DD-08002B30309D}  → Control Panel
shell:::{20D04FE0-3AEA-1069-A2D8-08002B30309D}  → My Computer
shell:::{208D2C60-3AEA-1069-A2D7-08002B30309D}  → My Network Places
shell:::{871C5380-42A0-1069-A2EA-08002B30309D}  → Internet Explorer
```

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `CTRL+N` | Open new session |
| `CTRL+R` | Execute commands |
| `CTRL+SHIFT+ESC` | Task Manager |
| `Windows+E` | Open Explorer |
| `Windows+R` | Run dialog |
| `Windows+D` | Show desktop |
| `Windows+F1` | Windows Search |
| `Windows+U` | Ease of Access Centre |
| `SHIFT+F10` | Context menu |
| `CTRL+ALT+DEL` | Security screen |
| `CTRL+ALT+F8` | Hidden admin menu (RDP) |
| `CTRL+ESC+F9` | Hidden admin menu (RDP) |
| `F11` | Toggle fullscreen (IE) |
| `CTRL+H` | History |
| `CTRL+O` | Open file dialog |
| `CTRL+S` | Save dialog |

### Accessibility Shortcuts

| Shortcut | Action |
|----------|--------|
| `SHIFT` ×5 | Sticky Keys |
| `SHIFT+ALT+NUMLOCK` | Mouse Keys |
| `SHIFT+ALT+PRINTSCN` | High Contrast |
| `NUMLOCK` (hold 5s) | Toggle Keys |
| `Right SHIFT` (hold 12s) | Filter Keys |

### Restricted Desktop Breakouts (Citrix/RDS/VDI)

**Dialog-box pivoting:**
- Use Open/Save/Print dialogs as Explorer-lite
- Try `*.*` or `*.exe` in filename fields
- Right-click folders → "Open in new window"
- Use Properties → "Open file location"

**Create execution paths:**
- Create `.CMD` or `.BAT` files
- Create shortcuts pointing to `%WINDIR%\System32\cmd.exe`
- Drag-and-drop files onto `cmd.exe` to launch a prompt

**Task Scheduler bypass:**
- If interactive shells are blocked but scheduling is allowed:
- Use `taskschd.msc` or `schtasks.exe` to create a task running `cmd.exe`

**Weak allowlists:**
- If execution allowed by filename/extension: rename payload to permitted name
- If allowed by directory: copy payload into allowed program folder

**Find writable staging paths:**
```cmd
echo %TEMP%
accesschk.exe -uwdqs Users c:\
accesschk.exe -uwdqs "Authenticated Users" c:\
```

### Accessing Filesystem from Browser

Try these path formats in browser address bars:

```
file:/C:/windows
file:/C:/windows/
file:/C:/windows\
file://C:/windows
file://C:/windows/
C:/windows
C:/windows/
C:\windows
C:\windows\
%WINDIR%
%TMP%
%TEMP%
%SYSTEMDRIVE%
%SYSTEMROOT%
%APPDATA%
%HOMEDRIVE%
```

### Downloadable Tools

- **Console:** https://sourceforge.net/projects/console/
- **Explorer++:** https://sourceforge.net/projects/explorerplus/files/Explorer%2B%2B/
- **Registry editor:** https://sourceforge.net/projects/uberregedit/

---

## Browser Tricks

### JavaScript File Dialog

Create a file input dialog using JavaScript:
```javascript
document.write('<input type=file>')
```

### Internet Explorer Image Toolbar

Click on images to reveal toolbar with:
- Save
- Print
- Mailto
- Open "My Pictures" in Explorer

### Backup iKat Versions

- http://swin.es/k/
- http://www.ikat.kronicd.net/

---

## iPad Techniques

### Gestures

| Gesture | Action |
|---------|--------|
| Swipe up with 4-5 fingers | Multitask view |
| Double-tap Home button | Multitask view |
| Swipe 4-5 fingers left/right | Switch apps |
| Pinch with 5 fingers | Go to Home |
| Swipe up from bottom (quick) | Go to Home |
| Swipe up from bottom (slow, 1-2 inches) | Show dock |
| Swipe down from top | Notifications |
| Swipe down from top-right | Control Centre (iPad Pro) |
| Swipe from left edge | Today view |
| Swipe from right edge | Action Center |
| Swipe from top edge | Show title bar (fullscreen) |
| Swipe up from bottom (fullscreen) | Show taskbar |

### Power/Screenshot

| Action | Method |
|--------|--------|
| Power off | Hold power button → slide to power off |
| Force restart | Hold power + Home buttons |
| Screenshot | Briefly press power + Home buttons |

### iPad Keyboard Shortcuts

**System shortcuts:**

| Shortcut | Action |
|----------|--------|
| `F1` | Dim screen |
| `F2` | Brighten screen |
| `F7` | Previous song |
| `F8` | Play/pause |
| `F9` | Next song |
| `F10` | Mute |
| `F11` | Decrease volume |
| `F12` | Increase volume |
| `⌘ Space` | Language selector |

**Navigation:**

| Shortcut | Action |
|----------|--------|
| `⌘H` | Go to Home |
| `⌘⇧H` | Go to Home |
| `⌘ (Space)` | Open Spotlight |
| `⌘⇥` | List last 10 apps |
| `⌘~` | Go to last app |
| `⌘⇧3` | Screenshot |
| `⌘⇧4` | Screenshot with editor |
| `⌘⌥D` | Show dock |
| `^⌥H` | Home button |
| `^⌥H H` | Show multitask bar |
| `Escape` | Back button |
| `⌘⇧⇥` | Previous app |
| `⌘⇥` | Original app |

**Safari:**

| Shortcut | Action |
|----------|--------|
| `⌘L` | Open location bar |
| `⌘T` | New tab |
| `⌘W` | Close tab |
| `⌘R` | Refresh |
| `⌘.` | Stop loading |
| `^⇥` | Next tab |
| `^⇧⇥` | Previous tab |
| `⌘⇧T` | Reopen last closed tab |
| `⌘[` | Back in history |
| `⌘]` | Forward in history |
| `⌘⇧R` | Reader Mode |

**Mail:**

| Shortcut | Action |
|----------|--------|
| `⌘⌥F` | Search mailbox |

---

## References

- [Breaking out of Citrix and restricted desktops](https://www.pentestpartners.com/security-blog/breaking-out-of-citrix-and-other-restricted-desktop-environments/)
- [iPad gestures guide](https://www.macworld.com/article/2975857/6-only-for-ipad-gestures-you-need-to-know.html)
- [iPad shortcuts](https://www.tomsguide.com/us/ipad-shortcuts,news-18205.html)
- [Best iPad keyboard shortcuts](https://thesweetsetup.com/best-ipad-keyboard-shortcuts/)
- [iPad keyboard shortcuts](http://www.iphonehacks.com/2018/03/ipad-keyboard-shortcuts.html)
- [Show file extensions in Windows](https://www.howtohaven.com/system/show-file-extensions-in-windows-explorer.shtml)
- [LOLBAS Project](https://lolbas-project.github.io/)
- [GTFOBins](https://gtfobins.github.io/)
