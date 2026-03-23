@echo off
REM Windows Credential Protections Checker (Batch)
REM Run as Administrator

echo === Windows Credential Protections Audit ===
echo.

REM WDigest Status
echo [1] WDigest Protection
echo.
reg query HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest /v UseLogonCredential 2>nul | findstr /i "0x1" >nul
if %errorlevel% equ 0 (
    echo   Status: ENABLED (INSECURE - plain text passwords in memory)
) else (
    echo   Status: DISABLED (secure)
)
echo.

REM LSA PPL Status
echo [2] LSA PPL Protection
echo.
reg query HKLM\SYSTEM\CurrentControlSet\Control\LSA /v RunAsPPL 2>nul | findstr /i "0x1" >nul
if %errorlevel% equ 0 (
    echo   Status: ENABLED (LSASS is PPL protected)
) else (
    echo   Status: DISABLED (LSASS is unprotected)
)
echo.

REM Credential Guard Status
echo [3] Credential Guard
echo.
reg query HKLM\System\CurrentControlSet\Control\LSA /v LsaCfgFlags 2>nul | findstr /i "0x1" >nul
if %errorlevel% equ 0 (
    echo   Status: ENABLED with UEFI lock
) else (
    reg query HKLM\System\CurrentControlSet\Control\LSA /v LsaCfgFlags 2>nul | findstr /i "0x2" >nul
    if %errorlevel% equ 0 (
        echo   Status: ENABLED without UEFI lock
    ) else (
        echo   Status: DISABLED
    )
)
echo.

REM Cached Logons Count
echo [4] Cached Credentials
echo.
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v CachedLogonsCount 2>nul
echo.

echo === Audit Complete ===
