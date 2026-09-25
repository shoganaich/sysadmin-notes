> This README is a temporary reference page while the repository is being organized. Commands and troubleshooting notes will gradually be moved into their relevant topic files.

# Windows Notes

This folder contains notes, commands, and reference material for managing Windows systems.

## Purpose

Use this folder as a quick reference for:

- Windows Server administration
- Active Directory and identity tasks
- User, group, and permission management
- Service, process, and performance troubleshooting
- Networking and firewall configuration
- Security hardening and patching
- Remote management and automation

## Common Windows Commands

### System Information

```powershell
systeminfo
hostname
whoami
ver
```

### Service and Process Management

```powershell
Get-Service
Get-Process
Stop-Service "Spooler"
Restart-Service "wuauserv"
```

### Networking

```powershell
ipconfig /all
Get-NetTCPConnection
Test-NetConnection google.com -Port 443
netstat -ano
```

### User and Group Management

```powershell
net user
net localgroup
Get-LocalUser
Get-LocalGroupMember -Group "Administrators"
```

### Disk and Filesystem

```powershell
diskpart
wmic diskdrive list brief
Get-Volume
Get-ChildItem C:\
```

### Event Logs

```powershell
Get-EventLog -LogName System -Newest 20
Get-WinEvent -LogName "Application" -MaxEvents 10
```

## Typical Sysadmin Tasks

- Check Windows Update status and patch compliance
- Review event logs for service failures or security issues
- Verify disk health and free space
- Manage local users, administrators, and group policy implications
- Monitor CPU, memory, and network utilization
- Validate firewall rules and network connectivity
- Troubleshoot startup, login, or service startup problems
- Check scheduled tasks and installed software

## Security Notes

- Keep systems patched and updated
- Restrict local administrator access
- Enable auditing and log collection
- Review service accounts and permissions
- Protect SMB and remote management endpoints
- Apply least-privilege principles

## Troubleshooting Checklist

1. Confirm the system time and domain connectivity
2. Check service state and event logs
3. Validate network configuration and DNS
4. Review recent patches and restarts
5. Confirm permissions and group membership
6. Check disk health and free space
7. Review antivirus, firewall, and endpoint protection status

## Useful References

- Windows Server documentation
- PowerShell documentation
- Active Directory and Group Policy references
- Microsoft security baselines and update guidance

## Notes

This folder is intended to be a living collection of practical notes. It will be added troubleshooting steps, scripts, commands, and configuration examples here as needed.