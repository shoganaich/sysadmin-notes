# Roadmap System Administration

## Goal

Develop a nice skillset for advancing on the carrer.

---

## Phase 1: Networking Fundamentals

**Goal:** Understand how devices communicate.

### Learn

- IPv4
- Subnetting
- DNS
- DHCP
- NAT
- Routing
- VLANs
- TCP vs UDP

### Be able to answer

- What happens when I open google.com?
- What is DNS?
- What is DHCP?
- Why can one device reach the internet and another cannot?

### Practice

#### Linux

```bash
ip addr
ping
traceroute
dig
nslookup
curl
```

#### Windows

```cmd
ipconfig
ping
tracert
nslookup
```

### Result

You can troubleshoot basic network problems without guessing.

---

## Phase 2: Windows Fundamentals

**Goal:** Understand how Windows works internally.

### Learn

- Services
- Event Viewer
- Windows Updates
- Scheduled Tasks
- Registry
- Local Users and Groups

### Practice

#### PowerShell

```powershell
Get-Service
Get-Process
Get-WinEvent
Get-ComputerInfo
```

### Result

You understand how Windows works beyond the GUI.

---

## Phase 3: Active Directory

**Goal:** Learn the bread and butter of Windows administration.

### Learn

#### Users

- Create users
- Disable users
- Unlock users
- Reset passwords

#### Groups

- Security groups
- Permissions

#### Organizational Units (OUs)

- Structure
- Delegation

#### Authentication

- Kerberos
- LDAP basics

### Learn to answer

- Why can't a user log in?
- Why isn't a permission applying?
- Why is a user locked out?

### Result

Performing actual sysadmin tasks.

---

## Phase 4: DNS & DHCP

**Goal:** Master the two most common causes of weird issues.

### DNS

Learn:

- A records
- CNAME
- PTR
- Forwarders

### DHCP

Learn:

- Scopes
- Reservations
- Leases

### Practice

#### Windows

```cmd
nslookup
ipconfig /flushdns
ipconfig /renew
```

#### Linux

```bash
dig
host
resolvectl status
```

### Result

You stop blaming random things for DNS problems.

---

## Phase 5: PowerShell

**Goal:** Automating tasks intead of manually doing things.

### Learn

#### Basics

```powershell
if
foreach
switch
functions
arrays
```

#### Commands

```powershell
Get-Service
Get-Process
Get-ChildItem
Get-Content
Export-Csv
```

### Projects

- User report
- Disk report
- Service monitor
- Event log report

### Result

You become more efficient than people doing everything manually.

---

## Phase 6: Linux Administration

**Goal:** Formalize what is already know.

### Learn

#### Users

```bash
useradd
usermod
passwd
groups
```

#### Services

```bash
systemctl
journalctl
```

#### Storage

```bash
lsblk
mount
df -h
```

#### Permissions

```bash
chmod
chown
```

#### Networking

```bash
ss -tulpn
ip addr
ip route
```

### Result

Confidently administer Linux systems.

---

## Phase 7: Backups

**Goal:** Learn the skill everyone ignores until disaster strikes.

### Learn

- Backup strategies
- Retention policies
- Restore procedures

### Practice

1. Backup something.
2. Delete it.
3. Restore it.

### Rule

> A backup doesn't exist until you've tested a restore.

### Result

Understand real-world disaster recovery.

---

## Phase 8: Monitoring

**Goal:** Know when systems are sick before users do.

### Learn

- CPU usage
- Memory usage
- Disk usage
- Network traffic

### Tools

- Grafana
- Uptime Kuma
- Prometheus

### Result

Learn how to observe systems properly.

---

## Phase 9: Azure

**Goal:** Become relevant in modern infrastructure.

### Start With

#### AZ-900

Learn:

- Cloud basics
- Azure services
- Pricing
- Security concepts

### Continue With

#### AZ-104

Learn:

- VMs
- Storage
- Networking
- Entra ID
- RBAC
- Backups

### Result

You're no longer only an on-prem administrator.

---

## Phase 10: Git

**Goal:** Track changes and manage configurations.

### Learn

```bash
git clone
git add
git commit
git push
git pull
```

### Create

```text
github.com/yourname/sysadmin-notes
```

Store:

- Scripts
- Notes
- Troubleshooting guides
- Docker files

### Result

Building a portfolio/Wiki/Materials

---

## Phase 11: Ansible

**Goal:** Manage many systems at once.

### Learn

- Inventory
- Playbooks
- Variables

#### Example

```text
Install package on 20 servers
Restart service on 20 servers
Update configuration on 20 servers
```

### Result

You start thinking at scale.

---

## Phase 12: Docker

**Goal:** Understand containers services.

### Learn

- Images
- Containers
- Volumes
- Networks
- Compose

### Practice

Deploy:

- Nginx
- Grafana
- Uptime Kuma

### Result

You understand containerized services.

---

## Phase 13: Terraform

**Goal:** Infrastructure as Code.

### Learn

- Providers
- Variables
- Resources
- State

### Result

You can create infrastructure using code.

---

## Phase 14: CI/CD

**Goal:** Automate deployments.

### Learn

- GitHub Actions
- Azure DevOps

### Result

Approach DevOps territory.

---

## Daily Habit

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

## Priority Order

1. Networking Fundamentals
2. Windows Fundamentals
3. Active Directory
4. DNS & DHCP
5. PowerShell
6. Linux Administration
7. Backups
8. Monitoring
9. Azure (AZ-900 → AZ-104)
10. Git
11. Ansible
12. Docker
13. Terraform
14. CI/CD

---

## Roadmap Checklist

### Phase 1: Networking Fundamentals

- [ ] Learn IPv4
- [ ] Practice subnetting
- [ ] Understand DNS
- [ ] Understand DHCP
- [ ] Understand NAT
- [ ] Learn routing basics
- [ ] Learn VLAN basics
- [ ] Understand TCP vs UDP
- [ ] Practice Linux networking commands
- [ ] Practice Windows networking commands
- [ ] Troubleshoot a basic network problem without guessing

### Phase 2: Windows Fundamentals

- [ ] Learn how Windows services work
- [ ] Use Event Viewer
- [ ] Understand Windows Updates
- [ ] Work with Scheduled Tasks
- [ ] Learn Registry basics
- [ ] Manage local users and groups
- [ ] Practice the listed PowerShell commands
- [ ] Troubleshoot Windows beyond the GUI

### Phase 3: Active Directory

- [ ] Create, disable, unlock, and update users
- [ ] Reset user passwords
- [ ] Understand security groups
- [ ] Manage permissions
- [ ] Understand Organizational Units
- [ ] Learn delegation basics
- [ ] Understand Kerberos basics
- [ ] Understand LDAP basics
- [ ] Troubleshoot login problems
- [ ] Troubleshoot permission problems
- [ ] Investigate account lockouts

### Phase 4: DNS & DHCP

- [ ] Understand A records
- [ ] Understand CNAME records
- [ ] Understand PTR records
- [ ] Learn how forwarders work
- [ ] Understand DHCP scopes
- [ ] Configure reservations
- [ ] Understand leases
- [ ] Practice Windows DNS and DHCP commands
- [ ] Practice Linux DNS commands
- [ ] Troubleshoot a DNS problem correctly

### Phase 5: PowerShell

- [ ] Learn `if` statements
- [ ] Learn `foreach` loops
- [ ] Learn `switch` statements
- [ ] Learn functions
- [ ] Learn arrays
- [ ] Practice the listed PowerShell commands
- [ ] Create a user report
- [ ] Create a disk report
- [ ] Create a service monitor
- [ ] Create an event log report

### Phase 6: Linux Administration

- [ ] Manage Linux users
- [ ] Manage Linux groups
- [ ] Manage services with `systemctl`
- [ ] Review logs with `journalctl`
- [ ] Inspect and mount storage
- [ ] Check disk usage
- [ ] Manage file permissions
- [ ] Manage file ownership
- [ ] Inspect listening services and ports
- [ ] Review IP addresses and routes
- [ ] Confidently administer a Linux system

### Phase 7: Backups

- [ ] Learn backup strategies
- [ ] Understand retention policies
- [ ] Learn restore procedures
- [ ] Back up something
- [ ] Delete the original
- [ ] Restore it successfully
- [ ] Document the restore test

### Phase 8: Monitoring

- [ ] Monitor CPU usage
- [ ] Monitor memory usage
- [ ] Monitor disk usage
- [ ] Monitor network traffic
- [ ] Try Grafana
- [ ] Try Uptime Kuma
- [ ] Try Prometheus
- [ ] Configure an alert before a user reports the issue

### Phase 9: Azure

- [ ] Learn cloud basics
- [ ] Learn core Azure services
- [ ] Understand Azure pricing
- [ ] Learn cloud security concepts
- [ ] Prepare for AZ-900
- [ ] Learn Azure virtual machines
- [ ] Learn Azure Storage
- [ ] Learn Azure networking
- [ ] Learn Entra ID
- [ ] Learn RBAC
- [ ] Learn Azure Backup
- [ ] Prepare for AZ-104

### Phase 10: Git

- [ ] Clone a repository
- [ ] Stage changes
- [ ] Commit changes
- [ ] Push changes
- [ ] Pull changes
- [ ] Create a `sysadmin-notes` repository
- [ ] Store scripts
- [ ] Store notes
- [ ] Store troubleshooting guides
- [ ] Store Docker files

### Phase 11: Ansible

- [ ] Create an inventory
- [ ] Write a playbook
- [ ] Use variables
- [ ] Install a package on multiple servers
- [ ] Restart a service on multiple servers
- [ ] Update a configuration on multiple servers

### Phase 12: Docker

- [ ] Understand images
- [ ] Run and manage containers
- [ ] Work with volumes
- [ ] Work with container networks
- [ ] Use Docker Compose
- [ ] Deploy Nginx
- [ ] Deploy Grafana
- [ ] Deploy Uptime Kuma

### Phase 13: Terraform

- [ ] Understand providers
- [ ] Use variables
- [ ] Create resources
- [ ] Understand state
- [ ] Create infrastructure using code

### Phase 14: CI/CD

- [ ] Learn GitHub Actions
- [ ] Learn Azure DevOps pipelines
- [ ] Automate a deployment

### Daily Habit

- [ ] Document every solved problem
- [ ] Save the commands used
- [ ] Save the logs analyzed
- [ ] Write down the final solution
- [ ] Keep `sysadmin-notes` updated
