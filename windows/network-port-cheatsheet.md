# Network Port Cheatsheet

Quick reference for the ports behind common Windows, Active Directory, and infrastructure services, and how to test them.

`PC01`, `DC01`, and `fileserver` are placeholders. Replace them with real names.

Related notes: [Common Windows Commands](common-commands.md) for DNS, share, and domain troubleshooting.

---

## Contents

1. [Start here: symptom to port](#1-start-here-symptom-to-port)
2. [Testing ports](#2-testing-ports)
3. [Firewall and listening ports](#3-firewall-and-listening-ports)
4. [Port reference](#4-port-reference)
5. [Recommended test sets](#5-recommended-test-sets)
6. [Important limitations](#6-important-limitations)

---

## 1. Start here: symptom to port

| Symptom | Test these | Notes |
|---|---|---|
| Can't map a drive or open `\\server\share` | TCP 445 | Open port only proves SMB is reachable, not permissions |
| Remote Desktop fails | TCP 3389 | Also check the user is in *Remote Desktop Users* on the target |
| `Enter-PSSession` / `Invoke-Command` fails | TCP 5985 (or 5986 for HTTPS) | WinRM must be enabled on the target |
| Can't manage services, event logs, or WMI remotely | TCP 135 + dynamic 49152-65535 | 135 alone isn't enough |
| Domain sign-in fails or slow | TCP/UDP 53, 88, 389, TCP 445 to a DC | Check DNS first: the PC must use the DC's DNS |
| GPOs not applying | TCP 445 and 389 to a DC | GPOs are read from SYSVOL over SMB |
| Printer not printing | TCP 9100, 631, or 445 | Depends on the port type the printer was added with |
| Windows won't activate (KMS) | TCP 1688 to the KMS host | |
| Updates not downloading (WSUS) | TCP 8530 or 8531 to the WSUS server | |
| VPN won't connect | Depends on VPN type (see [VPN](#vpn)) | Many SSL VPNs only need TCP 443 |
| Teams calls have poor audio/video | UDP 3478-3481 outbound | Without UDP, media falls back to slower TCP |
| Time is wrong, Kerberos errors | UDP 123 to the DC | |

---

## 2. Testing ports

### TCP: the standard way

```powershell
Test-NetConnection PC01 -Port 445
Test-NetConnection PC01 -Port 445 -InformationLevel Quiet    # Just True/False
```

`Test-NetConnection` is slow when a port is closed or filtered: it waits for its own timeout, about 20 seconds. When testing many ports or computers, use the fast version below.

### TCP: fast one-liner with a 1-second timeout

```powershell
$c = New-Object Net.Sockets.TcpClient; try { $c.ConnectAsync('PC01', 445).Wait(1000) } catch { $false }; $c.Close()
```

Returns `True` if the port accepted a connection within 1 second, `False` otherwise.

### Several ports on one computer

```powershell
$PC = 'PC01'; 135,445,3389,5985,5986 | ForEach-Object { $c = New-Object Net.Sockets.TcpClient; $open = try { $c.ConnectAsync($PC, $_).Wait(1000) } catch { $false }; $c.Close(); [PSCustomObject]@{ Computer = $PC; Port = $_; Open = $open } }
```

### One port on several computers

```powershell
'PC01','PC02','PC03' | ForEach-Object { $c = New-Object Net.Sockets.TcpClient; $open = try { $c.ConnectAsync($_, 3389).Wait(1000) } catch { $false }; $c.Close(); [PSCustomObject]@{ Computer = $_; Port = 3389; Open = $open } }
```

### UDP

UDP has no handshake, so a simple connection test can't tell you if a UDP port is open. Test the service instead:

```powershell
Resolve-DnsName google.com -Server DC01                          # DNS (UDP 53)
w32tm /stripchart /computer:DC01 /samples:3 /dataonly            # NTP (UDP 123)
```

For other UDP ports, use Microsoft's **PortQry** tool, which sends real protocol queries for services like LDAP, DNS, and RPC:

```cmd
portqry -n DC01 -e 389 -p UDP
portqry -n DC01 -e 88 -p BOTH
```

### From Linux

```bash
nc -zv -w 2 PC01 445                     # One TCP port, 2-second timeout
nc -zv -w 2 PC01 3389 5985 445           # Several TCP ports
nmap -p 53,88,135,389,445,3389 DC01      # TCP scan (install nmap)
sudo nmap -sU -p 53,88,123,389 DC01      # UDP scan (needs root, slower, less certain)
```

Only scan hosts you're authorized to scan. Port scanning can trigger security alerts.

---

## 3. Firewall and listening ports

### Is anything listening on the target?

Run these **on the target computer**. If nothing is listening, the problem is the service, not the network.

```powershell
# All listening TCP ports with process names
Get-NetTCPConnection -State Listen | Select-Object LocalAddress, LocalPort, OwningProcess, @{ Name = 'Process'; Expression = { (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName } } | Sort-Object LocalPort

# What is using one specific port
Get-NetTCPConnection -LocalPort 445 -State Listen | Select-Object LocalPort, OwningProcess, @{ Name = 'Process'; Expression = { (Get-Process -Id $_.OwningProcess).ProcessName } }

# UDP endpoints
Get-NetUDPEndpoint | Select-Object LocalAddress, LocalPort, OwningProcess | Sort-Object LocalPort
```

```cmd
netstat -ano | findstr ":445"
```

`netstat -ano` shows the PID in the last column. Find the process with `tasklist /fi "PID eq 1234"`.

### Is the Windows Firewall blocking it?

```powershell
# Is the firewall on, per profile?
Get-NetFirewallProfile | Select-Object Name, Enabled

# Which profile is the network using? "Public" blocks most inbound traffic
Get-NetConnectionProfile | Select-Object InterfaceAlias, Name, NetworkCategory

# Firewall rules for a specific port
Get-NetFirewallPortFilter | Where-Object LocalPort -eq 3389 | Get-NetFirewallRule | Select-Object DisplayName, Enabled, Direction, Action, Profile
```

A domain PC on the office network should show `DomainAuthenticated`. If it shows `Public`, it couldn't reach a domain controller when the network connected, so domain firewall rules aren't applied.

### Dynamic RPC range

```cmd
netsh int ipv4 show dynamicport tcp
```

Default on modern Windows: start port `49152`, `16384` ports (up to `65535`).

---

## 4. Port reference

### Workstation and remote support

| Port | Protocol | Service | Typical use |
| ---: | :---: | --- | --- |
| 135 | TCP | RPC Endpoint Mapper | Remote management, WMI, service control |
| 445 | TCP | SMB | File shares, admin shares (`C$`), Group Policy |
| 3389 | TCP/UDP | Remote Desktop | RDP (UDP improves performance, TCP is enough to connect) |
| 5985 | TCP | WinRM HTTP | PowerShell remoting (traffic is still encrypted in a domain) |
| 5986 | TCP | WinRM HTTPS | PowerShell remoting over TLS |
| 5900 | TCP | VNC | Third-party remote control |
| 49152-65535 | TCP | Dynamic RPC | WMI, MMC consoles, service management |
| 137 | UDP | NetBIOS name service | Legacy name lookup |
| 138 | UDP | NetBIOS datagram | Legacy browsing and broadcasts |
| 139 | TCP | NetBIOS session | Legacy SMB over NetBIOS |

> A successful connection to TCP `135` only proves the RPC Endpoint Mapper is reachable. The actual RPC traffic then uses a dynamic port, which may be blocked.
>
> Modern Windows uses SMB directly over TCP `445`. NetBIOS ports `137-139` are only needed by very old systems and are often disabled.

### Active Directory

| Port | Protocol | Service | Typical use |
| ---: | :---: | --- | --- |
| 53 | TCP/UDP | DNS | DC discovery and name resolution |
| 88 | TCP/UDP | Kerberos | Authentication |
| 123 | UDP | Windows Time (NTP) | Time sync. Kerberos fails if clocks differ by more than 5 minutes |
| 135 | TCP | RPC Endpoint Mapper | AD replication and management |
| 389 | TCP/UDP | LDAP | Directory queries. UDP 389 (CLDAP) is used to find a DC |
| 445 | TCP | SMB | SYSVOL, Group Policy, logon scripts |
| 464 | TCP/UDP | Kerberos password change | Password changes |
| 636 | TCP | LDAPS | LDAP over TLS |
| 3268 | TCP | Global Catalog | Forest-wide queries |
| 3269 | TCP | Global Catalog over TLS | Secure forest-wide queries |
| 9389 | TCP | AD Web Services | AD PowerShell module, AD Administrative Center |
| 49152-65535 | TCP | Dynamic RPC | Replication, other RPC operations |

> Ports `636` and `3269` are only used when LDAP or Global Catalog over TLS is configured.
>
> If the AD PowerShell module (RSAT) fails but other tools work, check TCP `9389` to the DC.

### DNS and DHCP

| Port | Protocol | Service | Typical use |
| ---: | :---: | --- | --- |
| 53 | TCP/UDP | DNS | Name resolution (TCP for large responses and zone transfers) |
| 67 | UDP | DHCP server | Receives client and relay requests |
| 68 | UDP | DHCP client | Receives offers and acknowledgements |

> DHCP uses broadcasts or relay agents and can't be tested with a port test. Query the DHCP server and leases directly instead.

### Windows services

| Port | Protocol | Service | Typical use |
| ---: | :---: | --- | --- |
| 1688 | TCP | KMS | Volume license activation |
| 8530 | TCP | WSUS HTTP | Windows Update from a WSUS server |
| 8531 | TCP | WSUS HTTPS | Same, over TLS |
| 1812 / 1813 | UDP | RADIUS (NPS) | Wi-Fi and VPN authentication / accounting |

### Printing

| Port | Protocol | Service | Typical use |
| ---: | :---: | --- | --- |
| 9100 | TCP | RAW / JetDirect | Most direct-to-printer TCP/IP ports |
| 631 | TCP | IPP / IPPS | Internet Printing Protocol |
| 515 | TCP | LPD | Legacy line printer daemon |
| 445 | TCP | SMB | Printers shared from a print server |
| 161 | UDP | SNMP | Printer status (toner, errors) |

> To see which port a printer uses: `Get-Printer -Name "PrinterName" | Select-Object Name, PortName` then `Get-PrinterPort -Name "<PortName>"`.

### VPN

| Port | Protocol | Service | Typical use |
| ---: | :---: | --- | --- |
| 443 | TCP | SSL VPN / SSTP | Most vendor SSL VPN clients, Windows SSTP |
| 500 | UDP | IKE | IPsec / IKEv2 key exchange |
| 4500 | UDP | IPsec NAT-T | IPsec through NAT (most home networks) |
| 1701 | UDP | L2TP | L2TP/IPsec (with 500 and 4500) |
| 1194 | UDP | OpenVPN | OpenVPN default |
| 51820 | UDP | WireGuard | WireGuard default |

> Hotel, guest, and mobile networks often block UDP 500/4500. SSL VPNs on TCP 443 usually still work there.

### Microsoft 365 and Teams

| Port | Protocol | Service | Typical use |
| ---: | :---: | --- | --- |
| 443 | TCP | HTTPS | All Microsoft 365 services |
| 80 | TCP | HTTP | Certificate revocation checks, some redirects |
| 3478-3481 | UDP | Teams media | Calls, meetings, screen sharing |

### Web

| Port | Protocol | Service | Typical use |
| ---: | :---: | --- | --- |
| 80 | TCP | HTTP | Web traffic |
| 443 | TCP | HTTPS | Secure web traffic |
| 8080 | TCP | Alternate HTTP | App servers, proxies |
| 8443 | TCP | Alternate HTTPS | App servers, admin consoles |

### File transfer and remote shell

| Port | Protocol | Service | Typical use |
| ---: | :---: | --- | --- |
| 20 / 21 | TCP | FTP | Data / control (unencrypted) |
| 22 | TCP | SSH, SFTP, SCP | Secure shell and file transfer |
| 23 | TCP | Telnet | Legacy unencrypted shell |
| 69 | UDP | TFTP | Network boot (PXE), switch configs |
| 2049 | TCP | NFS | Network File System |

> Avoid Telnet and FTP. Credentials travel in plain text. Use them only in authorized legacy environments with no secure alternative.

### Email

| Port | Protocol | Service | Typical use |
| ---: | :---: | --- | --- |
| 25 | TCP | SMTP | Server-to-server mail, internal relays |
| 587 | TCP | SMTP submission | Mail clients and devices sending mail (STARTTLS) |
| 465 | TCP | SMTP over TLS | Secure submission |
| 143 / 993 | TCP | IMAP / IMAPS | Mail retrieval |
| 110 / 995 | TCP | POP3 / POP3S | Mail retrieval |

> Scan-to-email on copiers usually uses `587` or `25`. Many ISPs block outbound `25`.

### Databases

| Port | Protocol | Service | Typical use |
| ---: | :---: | --- | --- |
| 1433 | TCP | Microsoft SQL Server | Default instance |
| 1434 | UDP | SQL Server Browser | Named instance discovery |
| 1521 | TCP | Oracle | Listener |
| 3306 | TCP | MySQL / MariaDB | Client connections |
| 5432 | TCP | PostgreSQL | Client connections |
| 6379 | TCP | Redis | Cache |
| 27017 | TCP | MongoDB | Client connections |

> SQL Server named instances usually use a dynamic port. The client asks SQL Server Browser on UDP `1434` which one.

### Monitoring and infrastructure

| Port | Protocol | Service | Typical use |
| ---: | :---: | --- | --- |
| 161 | UDP | SNMP | Monitoring queries |
| 162 | UDP | SNMP traps | Alerts sent by devices |
| 514 | UDP/TCP | Syslog | Central log collection |
| 3000 | TCP | Grafana | Dashboards |
| 9090 | TCP | Prometheus | Metrics server |
| 9100 | TCP | Prometheus node exporter | Linux host metrics (same number as RAW printing) |
| 10050 / 10051 | TCP | Zabbix | Agent / server |

### Containers

| Port | Protocol | Service | Typical use |
| ---: | :---: | --- | --- |
| 2375 | TCP | Docker API (no TLS) | Unsecured remote Docker API |
| 2376 | TCP | Docker API (TLS) | Secured remote Docker API |
| 6443 | TCP | Kubernetes API | Cluster control plane |

> Never expose TCP `2375` to a network you don't fully control. Anyone who can reach it effectively has root on the host.

---

## 5. Recommended test sets

Copy and change the computer name.

### Domain workstation

```powershell
$PC = 'PC01'; 135,445,3389,5985 | ForEach-Object { $c = New-Object Net.Sockets.TcpClient; $open = try { $c.ConnectAsync($PC, $_).Wait(1000) } catch { $false }; $c.Close(); [PSCustomObject]@{ Computer = $PC; Port = $_; Open = $open } }
```

### Domain controller

```powershell
$DC = 'DC01'; 53,88,135,389,445,464,636,3268,3269,9389 | ForEach-Object { $c = New-Object Net.Sockets.TcpClient; $open = try { $c.ConnectAsync($DC, $_).Wait(1000) } catch { $false }; $c.Close(); [PSCustomObject]@{ DC = $DC; Port = $_; Open = $open } }
```

Then test UDP the service way: `Resolve-DnsName contoso.local -Server DC01` for DNS and `w32tm /stripchart /computer:DC01 /samples:3 /dataonly` for time.

`636` and `3269` showing closed is normal if LDAPS isn't configured.

### Print server or printer

```powershell
$P = 'printer01'; 9100,631,515,445 | ForEach-Object { $c = New-Object Net.Sockets.TcpClient; $open = try { $c.ConnectAsync($P, $_).Wait(1000) } catch { $false }; $c.Close(); [PSCustomObject]@{ Printer = $P; Port = $_; Open = $open } }
```

---

## 6. Important limitations

An open TCP port only confirms that something accepted a TCP connection.

It does **not** confirm:

- Successful authentication
- Correct permissions or authorization
- Application health
- Valid certificates
- UDP availability
- Full RPC functionality (dynamic ports may still be blocked)
- Correct DNS or DHCP configuration

A **closed** port can mean: the service isn't running, a firewall (on the target, the network, or your own PC) is blocking it, or the name resolved to the wrong IP address. Check DNS first, then [what is listening](#is-anything-listening-on-the-target) on the target, then the [firewall](#is-the-windows-firewall-blocking-it).

This is a quick operational reference, not a substitute for proper service-specific testing.
