# Credential Finder Script
# Searches for common credential storage locations

param(
    [string]$SearchPath = "C:\",
    [string]$OutputFile = "credentials-found.txt"
)

Write-Host "[*] Searching for credentials in: $SearchPath" -ForegroundColor Cyan

$credentialFiles = @(
    "*.rdg",
    "*history*",
    "httpd.conf",
    ".htpasswd",
    ".gitconfig",
    ".git-credentials",
    "Dockerfile",
    "docker-compose.yml",
    "access_tokens.db",
    "accessTokens.json",
    "azureProfile.json",
    "*.gpg",
    "*.pgp",
    "*config*.php",
    "elasticsearch.yml",
    "kibana.yml",
    "*.p12",
    "*.cer",
    "known_hosts",
    "id_rsa",
    "id_dsa",
    "*.ovpn",
    "tomcat-users.xml",
    "web.config",
    "*.kdbx",
    "KeePass.config",
    "Ntds.dit",
    "SAM",
    "SYSTEM",
    "sysprep.inf",
    "sysprep.xml",
    "*vnc*.ini",
    "php.ini",
    "my.ini",
    "my.cnf",
    "access.log",
    "error.log",
    "server.xml",
    "ConsoleHost_history.txt",
    "unattend.xml",
    "unattend.txt",
    "unattended.xml",
    "SiteList.xml"
)

$results = @()

foreach ($pattern in $credentialFiles) {
    try {
        $files = Get-ChildItem -Path $SearchPath -Filter $pattern -Recurse -ErrorAction SilentlyContinue -File | Select-Object -First 50
        foreach ($file in $files) {
            $results += [PSCustomObject]@{
                Path = $file.FullName
                Pattern = $pattern
                LastWriteTime = $file.LastWriteTime
            }
        }
    }
    catch {
        # Skip inaccessible paths
    }
}

# Output results
if ($results.Count -gt 0) {
    Write-Host "`n[!] Found $($results.Count) potential credential files:" -ForegroundColor Red
    $results | Format-Table Path, Pattern, LastWriteTime -AutoSize
    
    # Save to file
    $results | Export-Csv -Path $OutputFile -NoTypeInformation
    Write-Host "[+] Results saved to: $OutputFile" -ForegroundColor Green
} else {
    Write-Host "[+] No credential files found" -ForegroundColor Green
}

# Also check registry for common credential keys
Write-Host "`n[+] Checking Registry for Credentials" -ForegroundColor Yellow
$registryKeys = @(
    "HKCU:\Software\SimonTatham\PuTTY\Sessions",
    "HKCU:\Software\OpenSSH\Agent\Keys",
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
)

foreach ($key in $registryKeys) {
    try {
        $items = Get-ItemProperty $key -ErrorAction SilentlyContinue
        if ($items) {
            Write-Host "[+] Found: $key" -ForegroundColor Yellow
        }
    }
    catch {
        # Skip inaccessible keys
    }
}
