# Common Windows Commands

Quick reference. Run PowerShell as Administrator where needed.

## System Information

```powershell
systeminfo
hostname
whoami
whoami /groups
Get-ComputerInfo | Select-Object CsName, OsName, OsVersion, OsBuildNumber, CsDomain
```

## Service and Process Management

```powershell
Get-Service
Get-Service -Name "Spooler"
Get-Process
Stop-Service -Name "Spooler"
Restart-Service -Name "wuauserv"
Get-CimInstance Win32_Service -Filter "Name='Spooler'" | Select-Object Name, StartMode, State, StartName
```

## Networking

```powershell
ipconfig /all
Get-NetIPConfiguration
Get-NetTCPConnection -State Listen
Test-NetConnection google.com -Port 443
Resolve-DnsName google.com
netstat -ano
```

## User and Group Management

```powershell
net user
net localgroup
Get-LocalUser
Get-LocalGroupMember -Group "Administrators"
```

## Disk and Filesystem

```powershell
Get-Volume
Get-Disk
Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus, Size
Get-CimInstance Win32_DiskDrive | Select-Object Model, Size, Status
Get-ChildItem C:\
diskpart
```

> `wmic` is deprecated and is not installed by default on recent Windows 11 builds. Use `Get-CimInstance` instead.

## Event Logs

```powershell
Get-WinEvent -LogName System -MaxEvents 20
Get-WinEvent -LogName Application -MaxEvents 10

# Errors and critical events from the last 24 hours
Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2; StartTime = (Get-Date).AddDays(-1) }
```

> `Get-EventLog` only works in Windows PowerShell 5.1 and only reads classic logs. `Get-WinEvent` works everywhere and is faster with `-FilterHashtable`.
