# Common Windows Commands

Quick reference for Windows and domain support, organized by the problem you are trying to solve.

**Conventions**

- `PC01`, `jdoe`, `contoso.local`, and `\\fileserver\share` are placeholders. Replace them with real names.
- 🛡️ = run from an elevated (Administrator) prompt.
- ⚠️ = changes something or interrupts the user. Check before running.
- Commands marked **RSAT** need the Active Directory PowerShell module (Remote Server Administration Tools).
- PowerShell can run every command on this page, including the classic CMD tools like `ipconfig` and `nltest`.

Related notes: [Network Port Cheatsheet](network-port-cheatsheet.md) for port tests, and the [AD Toolkit](../scripts/powershell/ad-toolkit/) for menu-driven versions of the AD checks.

---

## Contents

1. [Quick system overview](#1-quick-system-overview)
2. [User can't sign in or is locked out](#2-user-cant-sign-in-or-is-locked-out)
3. [New permissions or group membership not applying](#3-new-permissions-or-group-membership-not-applying)
4. [Domain trust relationship failed](#4-domain-trust-relationship-failed)
5. [No network or can't reach a share](#5-no-network-or-cant-reach-a-share)
6. [PC is slow or low on disk space](#6-pc-is-slow-or-low-on-disk-space)
7. [Services and printing](#7-services-and-printing)
8. [Updates, installed software, and pending restarts](#8-updates-installed-software-and-pending-restarts)
9. [Working on a remote computer](#9-working-on-a-remote-computer)
10. [Event logs](#10-event-logs)
11. [Commands to be careful with](#11-commands-to-be-careful-with)

---

## 1. Quick system overview

The first things to check on almost any ticket.

```powershell
hostname                         # Computer name
whoami                           # Signed-in account (DOMAIN\user)
whoami /upn                      # User principal name (user@domain)
systeminfo                       # OS, build, domain, last boot, installed hotfixes (slow)

# OS, version, build, and domain in one line
Get-ComputerInfo | Select-Object CsName, OsName, OsVersion, OsBuildNumber, CsDomain

# Last boot time. "Have you restarted?" Check this instead of asking.
(Get-CimInstance Win32_OperatingSystem).LastBootUpTime

# Model and serial number (for warranty and asset records)
Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model
(Get-CimInstance Win32_BIOS).SerialNumber
```

---

## 2. User can't sign in or is locked out

Work out *why* first. Unlocking without finding the cause usually means another lockout within minutes.

### Check the account

```powershell
# Works without RSAT. Shows active, expiry, password last set, lockout
net user jdoe /domain

# RSAT: the key fields at once
Get-ADUser jdoe -Properties Enabled, LockedOut, PasswordExpired, PasswordLastSet, LastBadPasswordAttempt, BadLogonCount, AccountExpirationDate |
    Select-Object Name, Enabled, LockedOut, PasswordExpired, PasswordLastSet, LastBadPasswordAttempt, BadLogonCount, AccountExpirationDate

# RSAT: every locked-out account in the domain
Search-ADAccount -LockedOut | Select-Object Name, SamAccountName, LastLogonDate
```

### Find where the lockout came from

Lockout event `4740` is logged on the domain controller holding the PDC emulator role. `CallerComputerName` (in the event's `Properties[1]`) is the device that sent the bad password.

```powershell
# RSAT + permission to read the DC Security log
$PDC = (Get-ADDomain).PDCEmulator
Get-WinEvent -ComputerName $PDC -FilterHashtable @{ LogName = 'Security'; Id = 4740 } -MaxEvents 50 |
    Where-Object { $_.Properties[0].Value -eq 'jdoe' } |
    Select-Object TimeCreated, @{ Name = 'Source'; Expression = { $_.Properties[1].Value } }
```

### Common causes on the user's side

```powershell
cmdkey /list                         # Saved credentials. Old passwords here are a classic lockout cause
cmdkey /delete:TargetName            # ⚠️ Remove one saved credential (use the Target shown by /list)
control /name Microsoft.CredentialManager   # Credential Manager GUI
```

Also check: phone or tablet mail apps, mapped drives using saved credentials, scheduled tasks or services running as the user, and a second signed-in session on another PC (see [Who is signed in](#who-is-signed-in)).

### Unlock and reset

```powershell
Unlock-ADAccount jdoe                                    # ⚠️ RSAT
Set-ADAccountPassword jdoe -Reset -NewPassword (Read-Host -AsSecureString "New password")   # ⚠️ RSAT
Set-ADUser jdoe -ChangePasswordAtLogon $true             # ⚠️ RSAT. Fails if "password never expires" is set
```

---

## 3. New permissions or group membership not applying

Group membership is read at sign-in, into the user's Kerberos ticket. Adding someone to a group does nothing for their *current* session until the ticket is refreshed.

```powershell
whoami /groups                       # Groups in the CURRENT session token
Get-ADPrincipalGroupMembership jdoe | Select-Object Name   # RSAT: groups the account has in AD

klist                                # Show Kerberos tickets
klist purge                          # Discard tickets. New ones are requested on next access (no sign-out needed for file shares)
```

If `whoami /groups` still doesn't show the group after `klist purge`, the user needs to sign out and back in. That's also true for anything that applies at sign-in, such as drive mappings.

### Group Policy

```powershell
gpupdate /force                      # Re-apply policy now instead of waiting about 90 minutes
gpresult /r                          # Applied and filtered GPOs for the current user and computer
gpresult /r /scope user              # User policies only (/scope computer for computer policies)
gpresult /h "$env:TEMP\gpresult.html" /f ; start "$env:TEMP\gpresult.html"   # 🛡️ Full HTML report (elevated to include computer policies)
```

Some policies (software installation, folder redirection) only apply at restart or sign-in. `gpupdate /force` will tell you when one is needed.

---

## 4. Domain trust relationship failed

Symptom: *"The trust relationship between this workstation and the primary domain failed."* The computer account password in AD no longer matches the one stored on the PC. This often happens after restoring a snapshot or image.

```powershell
Test-ComputerSecureChannel -Verbose                       # True = trust OK (Windows PowerShell 5.1 only, not PowerShell 7)
nltest /sc_verify:contoso.local                           # Same check, CMD tool, more detail
nltest /dsgetdc:contoso.local                             # Which DC the PC is using. Fails = DNS or network problem first

# 🛡️ ⚠️ Repair the trust without leaving the domain. Run on the affected PC
# with an account allowed to reset computer accounts.
Test-ComputerSecureChannel -Repair -Credential (Get-Credential)
```

Sign in with a local admin account (or LAPS) to run the repair if domain sign-in no longer works. Rejoining the domain is the fallback, not the first step.

### Time sync

Kerberos fails if the clock is more than 5 minutes off from the domain controller, which looks like random authentication errors.

```powershell
w32tm /query /status                 # Time source, last sync, offset
w32tm /query /source                 # Where the PC gets its time from
w32tm /resync                        # 🛡️ Force a sync now
```

---

## 5. No network or can't reach a share

Work from the bottom up: adapter → IP address → gateway → DNS → the service itself.

### Adapter and IP

```powershell
Get-NetAdapter                       # Up/Down, link speed. "Disconnected" = cable, Wi-Fi, or driver
ipconfig /all                        # IP, gateway, DNS servers, DHCP server, lease times
Get-NetIPConfiguration               # Same information, cleaner output
```

A `169.254.x.x` address means the PC didn't get an answer from DHCP.

```powershell
ipconfig /release ; ipconfig /renew  # ⚠️ Request a new DHCP lease (drops the connection, so don't run it over RDP)
```

### Reachability and DNS

```powershell
Test-NetConnection 8.8.8.8                       # Basic reachability (ICMP may be blocked, which doesn't always mean it's down)
Test-NetConnection fileserver -Port 445          # Can we reach SMB on the file server?
Test-NetConnection fileserver -TraceRoute        # Where along the path it stops

Resolve-DnsName fileserver                       # What the name resolves to
Resolve-DnsName fileserver -Server 10.0.0.10     # Ask a specific DNS server, to compare answers
Get-DnsClientCache | Where-Object Entry -like "*fileserver*"   # What this PC has cached

ipconfig /flushdns                   # Clear the DNS cache (after a DNS record was fixed)
ipconfig /registerdns                # 🛡️ Re-register this PC's own DNS record
```

### Shares and mapped drives

```powershell
net use                              # Mapped drives and their status (OK, Disconnected, Unavailable)
Get-SmbMapping                       # Same, PowerShell version
Test-Path \\fileserver\share         # Can this user see the share at all?
net use Z: /delete                   # ⚠️ Remove a broken mapping
net use Z: \\fileserver\share /persistent:yes   # ⚠️ Map it again
```

For which ports to test for each service, see the [Network Port Cheatsheet](network-port-cheatsheet.md).

---

## 6. PC is slow or low on disk space

```powershell
# Free space per drive
Get-Volume | Where-Object DriveLetter |
    Select-Object DriveLetter, FileSystemLabel,
        @{ Name = 'SizeGB'; Expression = { [math]::Round($_.Size / 1GB, 1) } },
        @{ Name = 'FreeGB'; Expression = { [math]::Round($_.SizeRemaining / 1GB, 1) } }

# Top 10 processes by CPU time, then by memory
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, Id, CPU
Get-Process | Sort-Object WorkingSet64 -Descending |
    Select-Object -First 10 Name, Id, @{ Name = 'MemMB'; Expression = { [math]::Round($_.WorkingSet64 / 1MB) } }

# Current CPU load, sampled 5 times
Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 5

# Disk health as reported by the drive
Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus, Size
```

Check uptime too (section 1). Weeks without a restart is a common cause of slowness.

For freeing space, follow the [cleanup procedure](procedures/windows-cleanup.md) or use the [cleanup script](../scripts/powershell/windows-cleanup/).

---

## 7. Services and printing

```powershell
Get-Service -Name Spooler            # Status of one service
Get-Service *update*                 # Find services by name

# Automatic services that aren't running. Often the real cause of a "broken" app
Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" |
    Select-Object Name, DisplayName, State

# Start mode and the account a service runs as
Get-CimInstance Win32_Service -Filter "Name='Spooler'" | Select-Object Name, StartMode, State, StartName

Restart-Service Spooler              # 🛡️ ⚠️
```

Some services (like `wuauserv`) are "Automatic (Trigger Start)" and are normally stopped until needed, so a stopped service isn't always a problem.

### Stuck print queue

```powershell
Get-Printer | Select-Object Name, PrinterStatus, PortName, DriverName
Get-PrintJob -PrinterName "PrinterName"

# 🛡️ ⚠️ Clear ALL print jobs for ALL printers on this PC
Stop-Service Spooler -Force
Remove-Item "$env:SystemRoot\System32\spool\PRINTERS\*" -Force
Start-Service Spooler
```

---

## 8. Updates, installed software, and pending restarts

```powershell
# Most recent updates
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10 HotFixID, Description, InstalledOn

# Is a restart pending? Either key existing means yes
Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
```

### Installed software

```powershell
# Reads the Uninstall registry keys: fast and safe (64-bit and 32-bit apps)
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' |
    Where-Object DisplayName |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
    Sort-Object DisplayName
```

Avoid `Get-WmiObject Win32_Product` / `Get-CimInstance Win32_Product`. Querying it makes Windows run a consistency check on every MSI-installed program. It's slow and can trigger repair installs.

Per-user apps (installed only for one user) are under the same path in `HKCU:` instead of `HKLM:`.

---

## 9. Working on a remote computer

### Who is signed in

```powershell
quser                                # Sessions on this PC
quser /server:PC01                   # Sessions on a remote PC (ID, state, idle time)
logoff 2 /server:PC01                # ⚠️ Sign off session ID 2. Unsaved work is lost
```

### Remote connections

```powershell
mstsc /v:PC01                        # Remote Desktop
Enter-PSSession PC01                 # Interactive PowerShell on PC01 (WinRM, TCP 5985). Exit-PSSession to leave
Invoke-Command -ComputerName PC01 -ScriptBlock { Get-Service Spooler }   # Run one command remotely

# Most Get-CimInstance queries work remotely too
Get-CimInstance Win32_OperatingSystem -ComputerName PC01 | Select-Object CSName, LastBootUpTime

Restart-Computer -ComputerName PC01  # ⚠️ Fails if a user is signed in. Add -Force only when agreed with the user
```

If remoting fails, check WinRM is reachable with `Test-NetConnection PC01 -Port 5985`, and that the account is an admin on the target.

---

## 10. Event logs

Use `Get-WinEvent` with `-FilterHashtable`. It filters on the source and is much faster than piping everything into `Where-Object`.

```powershell
Get-WinEvent -LogName System -MaxEvents 20
Get-WinEvent -LogName Application -MaxEvents 20

# Errors and critical events from the last 24 hours (Level 1 = Critical, 2 = Error, 3 = Warning)
Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2; StartTime = (Get-Date).AddDays(-1) }

# Unexpected shutdowns and crashes
Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 41, 6008, 1001 } -MaxEvents 10

# Same queries against another computer
Get-WinEvent -ComputerName PC01 -FilterHashtable @{ LogName = 'System'; Level = 1, 2 } -MaxEvents 20
```

| Event ID | Log | Meaning |
|---|---|---|
| 41 | System | Kernel-Power: the PC restarted without shutting down cleanly |
| 6008 | System | The previous shutdown was unexpected |
| 1001 | System | BugCheck: blue screen (includes the stop code) |
| 4624 / 4625 | Security | Successful / failed sign-in |
| 4740 | Security (DC) | Account locked out (see [Find where the lockout came from](#find-where-the-lockout-came-from)) |
| 7036 | System | A service started or stopped |

`Get-EventLog` still appears in many guides. It only works in Windows PowerShell 5.1 and only reads the classic logs. Use `Get-WinEvent`.

---

## 11. Commands to be careful with

| Command | Why |
|---|---|
| `diskpart` | Selecting the wrong disk and running `clean`, `format`, or `delete` destroys data with no confirmation. Always `list disk` and `detail disk` first. |
| `ipconfig /release` | Drops the network connection. Over RDP or a remote session you lose access to the PC. |
| `Restart-Computer -Force`, `shutdown /r /t 0` | Unsaved work is lost. Agree on timing with the user. |
| `logoff` | Same: unsaved work in that session is lost. |
| `Stop-Service -Force` | Also stops services that depend on it. |
| `Remove-Item -Recurse -Force` | No Recycle Bin. Check the path with `Get-ChildItem` first. |
| `Win32_Product` queries | Can trigger MSI repair installs (see [Installed software](#installed-software)). |
| `wmic` | Deprecated and removed by default on recent Windows 11 builds. Use `Get-CimInstance`. |
