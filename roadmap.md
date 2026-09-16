# Roadmap System Administration

## Goal

Develop a nice skillset for advancing on the carrer.

---

## Phase 1: Networking Fundamentals

**Goal:** Understand how devices communicate.

###S Learn

- IPv4
- Subnetting
- DNS
- DHCP
- NAT
- Routing
- VLANs
- TCP vs UDP

## Be able to answer

- What happens when I open google.com?
- What is DNS?
- What is DHCP?
- Why can one device reach the internet and another cannot?

## Practice

### Linux

```bash
ip addr
ping
traceroute
dig
nslookup
curl
```

### Windows

```cmd
ipconfig
ping
tracert
nslookup
```

## Result

You can troubleshoot basic network problems without guessing.

---

# Phase 2: Windows Fundamentals

**Goal:** Understand how Windows works internally.

## Learn

- Services
- Event Viewer
- Windows Updates
- Scheduled Tasks
- Registry
- Local Users and Groups

## Practice

### PowerShell

```powershell
Get-Service
Get-Process
Get-WinEvent
Get-ComputerInfo
```

## Result

You understand how Windows works beyond the GUI.

---

# Phase 3: Active Directory

**Goal:** Learn the bread and butter of Windows administration.

## Learn

### Users

- Create users
- Disable users
- Unlock users
- Reset passwords

### Groups

- Security groups
- Permissions

### Organizational Units (OUs)

- Structure
- Delegation

### Authentication

- Kerberos
- LDAP basics

## Learn to answer

- Why can't a user log in?
- Why isn't a permission applying?
- Why is a user locked out?

## Result

Performing actual sysadmin tasks.

---

# Phase 4: DNS & DHCP

**Goal:** Master the two most common causes of weird issues.

## DNS

Learn:

- A records
- CNAME
- PTR
- Forwarders

## DHCP

Learn:

- Scopes
- Reservations
- Leases

## Practice

### Windows

```cmd
nslookup
ipconfig /flushdns
ipconfig /renew
```

### Linux

```bash
dig
host
resolvectl status
```

## Result

You stop blaming random things for DNS problems.

---

# Phase 5: PowerShell

**Goal:** Automating tasks intead of manually doing things.

## Learn

### Basics

```powershell
if
foreach
switch
functions
arrays
```

### Commands

```powershell
Get-Service
Get-Process
Get-ChildItem
Get-Content
Export-Csv
```

## Projects

- User report
- Disk report
- Service monitor
- Event log report

## Result

You become more efficient than people doing everything manually.

---

# Phase 6: Linux Administration

**Goal:** Formalize what is already know.

## Learn

### Users

```bash
useradd
usermod
passwd
groups
```

### Services

```bash
systemctl
journalctl
```

### Storage

```bash
lsblk
mount
df -h
```

### Permissions

```bash
chmod
chown
```

### Networking

```bash
ss -tulpn
ip addr
ip route
```

## Result

Confidently administer Linux systems.

---

# Phase 7: Backups

**Goal:** Learn the skill everyone ignores until disaster strikes.

## Learn

- Backup strategies
- Retention policies
- Restore procedures

## Practice

1. Backup something.
2. Delete it.
3. Restore it.

## Rule

> A backup doesn't exist until you've tested a restore.

## Result

Understand real-world disaster recovery.

---

# Phase 8: Monitoring

**Goal:** Know when systems are sick before users do.

## Learn

- CPU usage
- Memory usage
- Disk usage
- Network traffic

## Tools

- Grafana
- Uptime Kuma
- Prometheus

## Result

Learn how to observe systems properly.

---

# Phase 9: Azure

**Goal:** Become relevant in modern infrastructure.

## Start With

### AZ-900

Learn:

- Cloud basics
- Azure services
- Pricing
- Security concepts

## Continue With

### AZ-104

Learn:

- VMs
- Storage
- Networking
- Entra ID
- RBAC
- Backups

## Result

You're no longer only an on-prem administrator.

---

# Phase 10: Git

**Goal:** Track changes and manage configurations.

## Learn

```bash
git clone
git add
git commit
git push
git pull
```

## Create

```text
github.com/yourname/sysadmin-notes
```

Store:

- Scripts
- Notes
- Troubleshooting guides
- Docker files

## Result

Building a portfolio/Wiki/Materials

---

# Phase 11: Ansible

**Goal:** Manage many systems at once.

## Learn

- Inventory
- Playbooks
- Variables

### Example

```text
Install package on 20 servers
Restart service on 20 servers
Update configuration on 20 servers
```

## Result

You start thinking at scale.

---

# Phase 12: Docker

**Goal:** Understand containers services.

## Learn

- Images
- Containers
- Volumes
- Networks
- Compose

## Practice

Deploy:

- Nginx
- Grafana
- Uptime Kuma

## Result

You understand containerized services.

---

# Phase 13: Terraform

**Goal:** Infrastructure as Code.

## Learn

- Providers
- Variables
- Resources
- State

## Result

You can create infrastructure using code.

---

# Phase 14: CI/CD

**Goal:** Automate deployments.

## Learn

- GitHub Actions
- Azure DevOps

## Result

Approach DevOps territory.

---

# Daily Habit

Every time you solve a problem:

1. Document it.
2. Save commands used.
3. Save logs analyzed.
4. Write the solution.

Create:

```text
~/sysadmin-notes
```

or

```text
github.com/<yourname>/sysadmin-notes
```

> After a year you'll have your own knowledge base.

---

# Priority Order

```text
Networking
↓
Windows Fundamentals
↓
Active Directory
↓
DNS & DHCP
↓
PowerShell
↓
Linux Administration
↓
Backups
↓
Monitoring
↓
Azure (AZ-900 → AZ-104)
↓
Git
