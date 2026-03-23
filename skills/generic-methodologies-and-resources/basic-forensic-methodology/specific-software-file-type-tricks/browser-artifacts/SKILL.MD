---
name: browser-forensics
description: How to extract and analyze browser artifacts for forensic investigations. Use this skill whenever investigating browser history, recovering deleted browsing data, analyzing cookies, extracting login credentials, examining cache data, or analyzing any web browser artifacts on Windows, Linux, or macOS systems. Make sure to use this skill for any incident response, digital forensics, or security investigation involving web browsers.
---

# Browser Forensics

A comprehensive guide to extracting and analyzing browser artifacts across all major browsers and operating systems.

## Quick Reference

| Browser | Primary Data Format | Key Files |
|---------|-------------------|----------|
| Firefox | SQLite | places.sqlite, cookies.sqlite, logins.json |
| Chrome | SQLite | History, Cookies, Login Data, Web Data |
| Edge | ESE/SQLite | WebCacheV01.dat, spartan.edb |
| Safari | SQLite/PLIST | History.db, Bookmarks.plist |
| Opera | SQLite | Same as Chrome |
| IE11 | ESE | WebCacheVX.data, TypedURLs registry |

## Artifact Types

- **Navigation History**: User visits to websites
- **Autocomplete Data**: Search suggestions
- **Bookmarks**: Saved sites
- **Extensions/Add-ons**: Installed browser plugins
- **Cache**: Stored web content (images, JS files)
- **Logins**: Stored credentials
- **Favicons**: Website icons
- **Sessions**: Open browser sessions
- **Downloads**: Downloaded file records
- **Form Data**: Autofill information
- **Thumbnails**: Website preview images
- **Custom Dictionary**: User-added words

## Firefox

### Profile Locations

| OS | Path |
|----|------|
| Linux | `~/.mozilla/firefox/` |
| macOS | `/Users/$USER/Library/Application Support/Firefox/Profiles/` |
| Windows | `%userprofile%\AppData\Roaming\Mozilla\Firefox\Profiles\` |

### Profile Discovery

```bash
# Find Firefox profiles
cat ~/.mozilla/firefox/profiles.ini | grep -E "^(Path|Default)="
```

### Key Files in Profile Directory

| File | Purpose | Analysis Tool |
|------|---------|---------------|
| places.sqlite | History, bookmarks, downloads | sqlite3, BrowsingHistoryView |
| cookies.sqlite | Cookie storage | MZCookiesView |
| formhistory.sqlite | Web form data | sqlite3 |
| logins.json | Encrypted credentials | firefox_decrypt |
| key4.db / key3.db | Encryption keys | firefox_decrypt |
| favicons.sqlite | Website icons | sqlite3 |
| prefs.js | User settings | grep, cat |
| addons.json | Extension info | cat, jq |
| cache2/entries | Cache data | MozillaCacheView |
| persdict.dat | Custom dictionary | cat |

### Common Queries

```bash
# Extract browsing history
sqlite3 places.sqlite "SELECT datetime(visit_date/1000000000, 'unixepoch'), url FROM moz_historyvisits h JOIN moz_places p ON h.place_id = p.id ORDER BY visit_date DESC LIMIT 100;"

# Extract downloads
sqlite3 places.sqlite "SELECT datetime(last_modified_date/1000000000, 'unixepoch'), url, filename FROM moz_downloads;"

# Check anti-phishing settings
grep 'browser.safebrowsing' prefs.js
```

### Password Decryption

```bash
# Install firefox_decrypt
pip install firefox_decrypt

# Decrypt saved passwords
firefox_decrypt --profile /path/to/profile

# Brute force master password
./scripts/firefox-brute.sh /path/to/passwords.txt /path/to/profile
```

## Google Chrome

### Profile Locations

| OS | Path |
|----|------|
| Linux | `~/.config/google-chrome/` |
| macOS | `/Users/$USER/Library/Application Support/Google/Chrome/` |
| Windows | `C:\Users\XXX\AppData\Local\Google\Chrome\User Data\` |

### Profile Structure

Profiles are in `Default/`, `Profile 1/`, `Profile 2/`, etc. within the User Data directory.

### Key Files

| File | Purpose | Analysis Tool |
|------|---------|---------------|
| History | URLs, downloads, searches | ChromeHistoryView, sqlite3 |
| Cookies | Cookie storage | ChromeCookiesView, sqlite3 |
| Cache | Cached data | ChromeCacheView |
| Bookmarks | Saved sites | cat, jq |
| Web Data | Form history | sqlite3 |
| Login Data | Credentials | ChromePasswordView, sqlite3 |
| Preferences | Settings, extensions | cat, jq, grep |
| Current Session | Active tabs | cat, jq |
| Last Session | Previous session | cat, jq |
| Thumbnails | Website previews | cat |

### Common Queries

```bash
# Extract browsing history
sqlite3 History "SELECT datetime(last_visit_time/1000000-11644473600, 'unixepoch'), url, title FROM urls ORDER BY last_visit_time DESC LIMIT 100;"

# Extract downloads
sqlite3 History "SELECT datetime(last_visit_time/1000000-11644473600, 'unixepoch'), url, filename FROM downloads;"

# Check anti-phishing settings
grep 'safebrowsing' ~/Library/Application\ Support/Google/Chrome/Default/Preferences
```

### Transition Types (History)

| Type | Meaning |
|------|----------|
| 0 | LINK | User clicked a link |
| 1 | TYPED | User typed URL |
| 2 | AUTO_BOOKMARK | Auto bookmark |
| 3 | AUTO_SUBFRAME | Subframe loaded automatically |
| 4 | FORM_SUBMIT | Form submission |
| 5 | AUTO_TILED | Tiled window |
| 6 | DOWNLOAD | Download |
| 7 | MANUALLY_CREATED | Manually created |
| 8 | GENERATED | Generated |
| 9 | EXTERNAL | External navigation |
| 10 | START_PAGE | Startup page |
| 11 | RELOAD | Page reload |

## Microsoft Edge

### Data Locations

| Data Type | Path |
|-----------|------|
| Profile | `C:\Users\XX\AppData\Local\Packages\Microsoft.MicrosoftEdge_XXX\AC` |
| History/Cookies/Downloads | `C:\Users\XX\AppData\Local\Microsoft\Windows\WebCache\WebCacheV01.dat` |
| Settings/Bookmarks | `C:\Users\XX\AppData\Local\Packages\Microsoft.MicrosoftEdge_XXX\AC\MicrosoftEdge\User\Default\DataStore\Data\nouser1\XXX\DBStore\spartan.edb` |
| Cache | `C:\Users\XXX\AppData\Local\Packages\Microsoft.MicrosoftEdge_XXX\AC#!XXX\MicrosoftEdge\Cache` |
| Last Session | `C:\Users\XX\AppData\Local\Packages\Microsoft.MicrosoftEdge_XXX\AC\MicrosoftEdge\User\Default\Recovery\Active` |

### Analysis Tools

- **ESEDatabaseView**: For WebCacheV01.dat and spartan.edb
- **IECacheView**: For cache inspection

## Safari (macOS)

### Data Location

`/Users/$User/Library/Safari/`

### Key Files

| File | Purpose | Analysis Tool |
|------|---------|---------------|
| History.db | Browsing history | sqlite3 |
| Downloads.plist | Download records | plutil |
| Bookmarks.plist | Saved bookmarks | plutil |
| TopSites.plist | Frequent sites | plutil |
| Extensions.plist | Browser extensions | plutil, pluginkit |
| UserNotificationPermissions.plist | Notification permissions | plutil |
| LastSession.plist | Previous session tabs | plutil |

### Common Queries

```bash
# Extract browsing history
sqlite3 History.db "SELECT datetime(visit_time+978307200, 'unixepoch'), url FROM history_visits v JOIN history_items i ON v.history_item = i.id ORDER BY visit_time DESC LIMIT 100;"

# Check anti-phishing settings
defaults read com.apple.Safari WarnAboutFraudulentWebsites
# Returns 1 if enabled
```

## Opera

### Data Location

`/Users/$USER/Library/Application Support/com.operasoftware.Opera/`

Opera uses the same SQLite format as Chrome for history and downloads.

### Anti-Phishing Check

```bash
grep 'fraud_protection_enabled' Preferences
# Look for "true" value
```

## Internet Explorer 11

### Data Locations

| Data Type | Path |
|-----------|------|
| Metadata | `%userprofile%\Appdata\Local\Microsoft\Windows\WebCache\WebcacheVX.data` |
| Cache | `%userprofile%\Appdata\Local\Microsoft\Windows\Temporary Internet Files\` |
| Cookies | `%userprofile%\Appdata\Roaming\Microsoft\Windows\Cookies` |
| Downloads | `%userprofile%\Appdata\Roaming\Microsoft\Windows\IEDownloadHistory` |
| History | `%userprofile%\Appdata\Local\Microsoft\Windows\History` |
| Typed URLs | Registry: `NTUSER.DAT\Software\Microsoft\InternetExplorer\TypedURLs` |

### Analysis Tools

- **ESEDatabaseView**: For WebCacheVX.data
- **IECacheView**: For cache inspection
- **IECookiesView**: For cookies
- **BrowsingHistoryView**: For history
- **photorec**: For deleted data recovery

### Registry Queries

```powershell
# Extract typed URLs
reg query "HKCU\Software\Microsoft\Internet Explorer\TypedURLs"
reg query "HKCU\Software\Microsoft\Internet Explorer\TypedURLsTime"
```

## SQLite Recovery

Both Chrome and Firefox use SQLite databases. Deleted entries can be recovered using:

- **sqlparse**: https://github.com/padfoot999/sqlparse
- **sqlparse_gui**: https://github.com/mdegrazia/SQLite-Deleted-Records-Parser/releases

```bash
# Recover deleted records
python sqlparse.py -i places.sqlite -o recovered_records.txt
```

## Recommended Tools

| Tool | Purpose | Platform |
|------|---------|----------|
| BrowsingHistoryView | History analysis | Windows |
| ChromeHistoryView | Chrome history | Windows |
| IECacheView | IE cache | Windows |
| MZCookiesView | Firefox cookies | Windows |
| ChromeCookiesView | Chrome cookies | Windows |
| ESEDatabaseView | ESE database inspection | Windows |
| firefox_decrypt | Password decryption | Cross-platform |
| sqlparse | SQLite recovery | Cross-platform |

## Workflow Recommendations

1. **Identify the browser** and OS from the investigation context
2. **Locate profile directories** using the paths above
3. **Extract SQLite databases** to a working directory (don't modify originals)
4. **Query databases** for relevant artifacts
5. **Check anti-phishing settings** to understand security posture
6. **Recover deleted data** using sqlparse if needed
7. **Decrypt credentials** using appropriate tools
8. **Document findings** with timestamps and sources

## Scripts

Use the bundled scripts for common tasks:

- `scripts/extract-browser-history.sh` - Extract history from any browser
- `scripts/check-antiphishing.sh` - Check anti-phishing across all browsers
- `scripts/firefox-brute.sh` - Brute force Firefox master password

Run with `--help` for usage information.
