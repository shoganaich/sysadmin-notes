# Common Windows Commands

## System Information

```powershell
systeminfo
hostname
whoami
ver
```

## Service and Process Management

```powershell
Get-Service
Get-Process
Stop-Service "Spooler"
Restart-Service "wuauserv"
```

## Networking

```powershell
ipconfig /all
Get-NetTCPConnection
Test-NetConnection google.com -Port 443
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
diskpart
wmic diskdrive list brief
Get-Volume
Get-ChildItem C:\
```

## Event Logs

```powershell
Get-EventLog -LogName System -Newest 20
Get-WinEvent -LogName "Application" -MaxEvents 10
```

