# Windows Network Port Cheatsheet

Quick reference sheet for common Windows ports used for Active Directory, DNS, DHCP, remote support, web services, databases, and infrastructure.

## Workstation and Remote Support

| Port | Protocol | Service | Typical Use |
| ---: | :---: | --- | --- |
| 135 | TCP | RPC Endpoint Mapper | Remote management, WMI, and service control |
| 445 | TCP | SMB | File shares, administrative shares, and Group Policy |
| 3389 | TCP/UDP | Remote Desktop | RDP connections |
| 5985 | TCP | WinRM HTTP | PowerShell remoting |
| 5986 | TCP | WinRM HTTPS | Encrypted PowerShell remoting |
| 49152-65535 | TCP | Dynamic RPC | WMI, MMC consoles, and service management |

> Modern Windows uses `49152-65535` as the default dynamic RPC range. A successful connection to TCP port `135` confirms the RPC Endpoint Mapper is reachable, but it does not guarantee remote RPC operations will succeed.

## DNS and DHCP

| Port | Protocol | Service | Typical Use |
| ---: | :---: | --- | --- |
| 53 | TCP/UDP | DNS | Name resolution and DNS zone transfers |
| 67 | UDP | DHCP Server | Receives DHCP client and relay requests |
| 68 | UDP | DHCP Client | Receives DHCP offers and acknowledgements |

> DHCP normally uses broadcasts or DHCP relay agents. A normal TCP port test cannot accurately validate UDP ports `67` and `68`.
>
> For DHCP troubleshooting, query the DHCP servers and lease information directly instead.

## Active Directory

| Port | Protocol | Service | Typical Use |
| ---: | :---: | --- | --- |
| 53 | TCP/UDP | DNS | Domain controller discovery and name resolution |
| 88 | TCP/UDP | Kerberos | Domain authentication |
| 123 | UDP | Windows Time / NTP | Time synchronization |
| 135 | TCP | RPC Endpoint Mapper | Active Directory and Windows RPC |
| 389 | TCP/UDP | LDAP | Directory queries |
| 445 | TCP | SMB | SYSVOL, Group Policy, and logon scripts |
| 464 | TCP/UDP | Kerberos password change | Password changes |
| 636 | TCP | LDAPS | LDAP over TLS |
| 3268 | TCP | Global Catalog | Forest-wide directory queries |
| 3269 | TCP | Secure Global Catalog | Global Catalog protected with TLS |
| 9389 | TCP | Active Directory Web Services | AD PowerShell module and AD Administrative Center |
| 49152-65535 | TCP | Dynamic RPC | AD replication and other RPC operations |

> Not every port is required for Active Directory operations. For example, ports `636` and `3269` are only needed when LDAP or Global Catalog over TLS is configured and used.

> A successful connection to TCP port `445` only confirms the SMB service is reachable. It does not confirm authentication, share permissions, NTFS permissions, or access to specific shares.

## Web Services

| Port | Protocol | Service | Typical Use |
| ---: | :---: | --- | --- |
| 80 | TCP | HTTP | Standard web traffic |
| 443 | TCP | HTTPS | Secure web traffic |
| 8080 | TCP | Alternate HTTP | Common app dev or proxy port |
| 8443 | TCP | Alternate HTTPS | Common app dev or proxy port |

## File Transfer and Remote Shell

| Port | Protocol | Service | Typical Use |
| ---: | :---: | --- | --- |
| 20 | TCP | FTP data | FTP file transfers |
| 21 | TCP | FTP control | FTP control channel |
| 22 | TCP | SSH and SFTP | Secure shell and secure file transfer |
| 23 | TCP | Telnet | Legacy unencrypted remote shell |
| 69 | UDP | TFTP | Simple file transfer |
| 137 | TCP/UDP | NetBIOS name service | Legacy name lookup |
| 138 | UDP | NetBIOS datagram | Legacy broadcast traffic |
| 139 | TCP | NetBIOS session | Legacy SMB session traffic |

> Telnet is unencrypted and should never be used if possible; use only in explicitly authorized legacy environments with no more secure alternative.

> Windows environments typically use direct SMB over TCP port `445` rather than NetBIOS ports `137-139`.

## Email

| Port | Protocol | Service | Typical Use |
| ---: | :---: | --- | --- |
| 25 | TCP | SMTP server-to-server | Mail relay and server communication |
| 110 | TCP | POP3 | Mail retrieval |
| 143 | TCP | IMAP | Mail retrieval |
| 465 | TCP | SMTP over implicit TLS | Secure SMTP |
| 587 | TCP | Authenticated SMTP submission | Mail client submission |
| 993 | TCP | IMAP over TLS | Secure IMAP |
| 995 | TCP | POP3 over TLS | Secure POP3 |

## Databases

| Port | Protocol | Service | Typical Use |
| ---: | :---: | --- | --- |
| 1433 | TCP | Microsoft SQL Server | SQL Server client connections |
| 1434 | UDP | SQL Server Browser | SQL instance discovery |
| 1521 | TCP | Oracle Database | Oracle listener |
| 3306 | TCP | MySQL and MariaDB | MySQL client traffic |
| 5432 | TCP | PostgreSQL | PostgreSQL client traffic |
| 6379 | TCP | Redis | In-memory cache |
| 27017 | TCP | MongoDB | MongoDB traffic |

## Monitoring and Infrastructure

| Port | Protocol | Service | Typical Use |
| ---: | :---: | --- | --- |
| 161 | UDP | SNMP queries | Monitoring queries |
| 162 | UDP | SNMP traps | Monitoring alerts |
| 514 | TCP/UDP | Syslog | Centralized log collection |
| 3000 | TCP | Grafana default | Metrics dashboards |
| 9090 | TCP | Prometheus default | Time-series metrics |
| 10050 | TCP | Zabbix agent | Agent communications |
| 10051 | TCP | Zabbix server | Server communications |

## Containers and Kubernetes

| Port | Protocol | Service | Typical Use |
| ---: | :---: | --- | --- |
| 2375 | TCP | Docker API without TLS | Unsecured Docker API |
| 2376 | TCP | Docker API with TLS | Secured Docker API |
| 6443 | TCP | Kubernetes API | Kubernetes control plane |

> Never publicly expose TCP port `2375`. A typical Docker API configuration on this port is not encrypted and may not require authentication, which can introduce security risk.

## PowerShell Useful Commands

### Test a TCP port

```powershell
Test-NetConnection -ComputerName "COMPUTER-01" -Port 445
```

### Return a short result

```powershell
Test-NetConnection -ComputerName "COMPUTER-01" -Port 445 | Select-Object ComputerName,RemoteAddress,RemotePort,TcpTestSucceeded
```

### Test several TCP ports

```powershell
$ComputerName="COMPUTER-01"; 135,445,3389,5985,5986 | ForEach-Object { $r=Test-NetConnection -ComputerName $ComputerName -Port $_ -WarningAction SilentlyContinue; [PSCustomObject]@{Computer=$ComputerName;Port=$_;Open=$r.TcpTestSucceeded} }
```

### Test a domain controller

```powershell
$DC="DC01"; 53,88,135,389,445,464,636,3268,3269,9389 | ForEach-Object { $r=Test-NetConnection -ComputerName $DC -Port $_ -WarningAction SilentlyContinue; [PSCustomObject]@{DomainController=$DC;Port=$_;Open=$r.TcpTestSucceeded} }
```

### Show listening ports with process names

```powershell
Get-NetTCPConnection -State Listen | ForEach-Object { [PSCustomObject]@{LocalAddress=$_.LocalAddress;LocalPort=$_.LocalPort;ProcessName=(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName;PID=$_.OwningProcess} } | Sort-Object LocalPort
```

### Find the process listening on a specific port

```powershell
$Port=445; Get-NetTCPConnection -State Listen -LocalPort $Port | ForEach-Object { [PSCustomObject]@{Port=$_.LocalPort;Process=(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName;PID=$_.OwningProcess} }
```

### CMD alternative

```cmd
netstat -ano
```

Filter the result by port:

```cmd
netstat -ano | findstr ":445"
```

## Recommended Workstation Test

For an ordinary domain PC or laptop, test:

```text
Ping
RPC TCP/135
SMB TCP/445
RDP TCP/3389
WinRM HTTP TCP/5985
WinRM HTTPS TCP/5986
```

## Recommended Domain Controller Test

For a domain controller, test:

```text
DNS TCP/53
Kerberos TCP/88
RPC TCP/135
LDAP TCP/389
SMB TCP/445
Kerberos Password TCP/464
LDAPS TCP/636
Global Catalog TCP/3268
Secure Global Catalog TCP/3269
Active Directory Web Services TCP/9389
```

## Important Limitations

An open TCP port only confirms that a service accepted a TCP connection.

It does not confirm:

- Successful authentication
- Application health
- Valid certificates
- Correct authorization
- UDP availability
- Full RPC functionality
- Correct DNS or DHCP configuration

This reference is intended as a quick operational checklist, not a substitute for deeper service validation or application-specific testing.