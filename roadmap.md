# Roadmap: Service Desk to System Administrator

My plan for moving from IT Service Desk into System Administration.

Each phase has a goal, a checklist, and links to work in this repository that shows it in practice. Items are ticked when there is evidence for them in the repo or when I can do them confidently without notes.

To study a topic, use the [study prompt](study-prompt.md).

---

## Status

| # | Phase | Status | Evidence in this repo |
|---|---|---|---|
| 1 | [Networking fundamentals](#1-networking-fundamentals) | 🟡 In progress | [Port cheatsheet](windows/network-port-cheatsheet.md) |
| 2 | [Windows fundamentals](#2-windows-fundamentals) | 🟡 In progress | [Procedures](windows/procedures/), [Windows Cleanup](scripts/powershell/windows-cleanup/), [Common commands](windows/common-commands.md) |
| 3 | [Active Directory](#3-active-directory) | 🟡 In progress | [Service Desk Toolkit](scripts/powershell/servicedesk-toolkit/) |
| 4 | [DNS and DHCP](#4-dns-and-dhcp) | 🟡 In progress | [DNS/DHCP check](scripts/powershell/servicedesk-toolkit/scripts/check-dns-dhcp.ps1) |
| 5 | [PowerShell](#5-powershell) | 🟡 In progress | [Service Desk Toolkit](scripts/powershell/servicedesk-toolkit/), [Service Manager](scripts/powershell/service-manager/), [Shift Log](scripts/powershell/shift-log/), [GPS Locator](scripts/powershell/gps-locator/) |
| 6 | [Git](#6-git) | 🟡 In progress | This repository |
| 7 | [Entra ID, Intune, and Microsoft 365](#7-entra-id-intune-and-microsoft-365) | ⏭️ Next | |
| 8 | [Linux administration](#8-linux-administration) | 🟡 Started | [Git config scripts](scripts/bash/git-config-scripts/) |
| 9 | [Backups and recovery](#9-backups-and-recovery) | ⬜ Not started | |
| 10 | [Docker](#10-docker) | ⬜ Not started | |
| 11 | [Monitoring](#11-monitoring) | ⬜ Not started | |
| 12 | [Azure](#12-azure) | ⬜ Not started | |
| 13 | [Automation: Ansible, Terraform, CI/CD](#13-automation-ansible-terraform-cicd) | ⬜ Not started | |

**Currently working on:** finishing phases 1-5, then Entra ID and Intune.

**Certifications planned:** MD-102 (Endpoint Administrator) → AZ-900 → AZ-104.

---

## Stage 1: Foundations

The core of Service Desk and junior sysadmin work. Most tickets come down to one of these.

### 1. Networking fundamentals

**Goal:** troubleshoot network problems without guessing.

- [ ] IPv4 addressing and private vs public ranges
- [ ] Subnetting (work out network, broadcast, and host range by hand)
- [ ] Routing and default gateways
- [ ] NAT
- [ ] VLANs
- [x] TCP vs UDP, and why UDP can't be tested with a port test
- [x] Common ports and what uses them
- [ ] Explain what happens when you open `google.com`, step by step
- [ ] Explain why one device reaches the internet and another doesn't

**Practice:** `ip addr`, `ping`, `traceroute`/`tracert`, `dig`/`nslookup`, `curl`, `Test-NetConnection`

**Evidence:** [Network Port Cheatsheet](windows/network-port-cheatsheet.md), [network section of Common Commands](windows/common-commands.md#5-no-network-or-cant-reach-a-share)

### 2. Windows fundamentals

**Goal:** understand Windows beyond the GUI.

- [x] Services: start types, dependencies, remote management
- [ ] Event Viewer and reading event logs with `Get-WinEvent`
- [x] Windows Update: cache, servicing, pending restarts
- [ ] Scheduled Tasks
- [ ] Registry basics (HKLM vs HKCU, where settings live)
- [ ] Local users and groups
- [x] Boot process and recovery (WinRE, BCDBoot, offline DISM and SFC)
- [ ] BitLocker and recovery keys
- [ ] Microsoft Defender basics

**Evidence:** [UEFI boot recovery](windows/procedures/winre-uefi-recovery.md), [advanced recovery](windows/procedures/winre-uefi-advanced-troubleshooting.md), [cleanup procedure](windows/procedures/windows-cleanup.md) and [script](scripts/powershell/windows-cleanup/), [Service Manager](scripts/powershell/service-manager/)

### 3. Active Directory

**Goal:** handle everyday AD work and know why things fail.

- [x] Unlock accounts
- [x] Reset passwords
- [x] Investigate account lockouts and find the source device
- [x] Check group memberships and group owners
- [x] Read LAPS passwords
- [ ] Create and disable users
- [ ] Security groups vs distribution groups, group scopes
- [ ] Organizational Units and delegation of control
- [ ] Group Policy: linking, inheritance, filtering, `gpresult`
- [ ] Kerberos basics: tickets, time sync, why `klist purge` works
- [ ] LDAP basics
- [ ] FSMO roles and what the PDC emulator does
- [ ] Explain why a user can't sign in, or why a permission isn't applying

**Evidence:** [Service Desk Toolkit](scripts/powershell/servicedesk-toolkit/): lockout source, unlock, reset, group approver, LAPS

### 4. DNS and DHCP

**Goal:** stop blaming random things for DNS problems.

- [x] A and PTR records, forward and reverse lookups
- [ ] CNAME records
- [ ] Forwarders and conditional forwarders
- [ ] Dynamic DNS registration and scavenging
- [ ] DHCP scopes, options, and reservations
- [x] DHCP leases
- [ ] Troubleshoot a DNS problem from client to server

**Practice:** `Resolve-DnsName`, `nslookup`, `ipconfig /flushdns`, `ipconfig /registerdns`, `dig`, `resolvectl status`

**Evidence:** [DNS and DHCP check](scripts/powershell/servicedesk-toolkit/scripts/check-dns-dhcp.ps1) (cross-checks A records, PTR records, and DHCP leases)

### 5. PowerShell

**Goal:** automate tasks instead of doing them by hand.

- [x] `if`, `foreach`, `switch`, functions, arrays
- [x] Error handling with `try`/`catch`
- [x] Working with AD, CIM, and remote computers
- [x] Build a service monitor/manager
- [x] Build a disk and health report
- [ ] Build a user report exported to CSV
- [ ] Write a module (`.psm1`) and reuse code across scripts
- [ ] Write Pester tests
- [ ] Run PSScriptAnalyzer and fix its findings

**Evidence:** [Service Desk Toolkit](scripts/powershell/servicedesk-toolkit/), [Service Manager](scripts/powershell/service-manager/), [Windows Cleanup](scripts/powershell/windows-cleanup/), [Shift Log](scripts/powershell/shift-log/) (config file, search, archiving), [GPS Locator](scripts/powershell/gps-locator/) (parses NMEA data from a remote computer's log)

### 6. Git

**Goal:** track changes and keep notes and scripts versioned.

- [x] Clone, add, commit, push, pull
- [x] SSH authentication and signed commits
- [x] Conventional commit messages
- [x] Rename and move files without losing history (`git mv`)
- [ ] Branches and pull requests
- [ ] Undo mistakes safely: `restore`, `revert`, `reset`, `rebase -i`

**Evidence:** this repository and the [Git config scripts](scripts/bash/git-config-scripts/)

---

## Stage 2: Modern identity and endpoints

Most organizations now run hybrid: on-premises AD synced to Entra ID, with devices managed by Intune. This builds directly on Service Desk work.

### 7. Entra ID, Intune, and Microsoft 365

**Goal:** manage cloud identities and devices as confidently as on-premises AD.

**Entra ID**

- [ ] Users, groups, and roles
- [ ] Hybrid identity: how on-premises AD syncs to Entra ID
- [ ] MFA and self-service password reset
- [ ] Conditional Access basics: why a sign-in was blocked
- [ ] Reading sign-in logs

**Intune**

- [ ] Device enrollment and Autopilot
- [ ] Compliance policies and configuration profiles
- [ ] App deployment
- [ ] Windows Update rings
- [ ] Troubleshoot a device that isn't receiving policies

**Microsoft 365**

- [ ] Admin center basics: licenses, users, service health
- [ ] Exchange Online: mailboxes, shared mailboxes, permissions

**Certification:** MD-102 (Microsoft 365 Certified: Endpoint Administrator Associate)

---

## Stage 3: Running services

### 8. Linux administration

**Goal:** formalize what I already use at home.

- [ ] Users and groups: `useradd`, `usermod`, `passwd`, `groups`
- [ ] Services and logs: `systemctl`, `journalctl`
- [ ] Storage: `lsblk`, `mount`, `df -h`, `/etc/fstab`
- [ ] Permissions: `chmod`, `chown`, `umask`
- [ ] Networking: `ip addr`, `ip route`, `ss -tulpn`
- [ ] Package management (`apt`/`dnf`) and updates
- [ ] SSH: keys, config, hardening
- [x] Bash scripting with `set -euo pipefail`

**Evidence:** [Git config scripts](scripts/bash/git-config-scripts/)

### 9. Backups and recovery

**Goal:** learn the skill everyone ignores until disaster strikes.

> A backup doesn't exist until you've tested a restore.

- [ ] Backup strategies and the 3-2-1 rule
- [ ] Retention policies
- [ ] Back up something, delete the original, restore it
- [ ] Document the restore test as a case study

### 10. Docker

**Goal:** understand and run containerized services.

- [ ] Images, containers, volumes, networks
- [ ] Docker Compose
- [ ] Deploy Nginx, Grafana, and Uptime Kuma with Compose
- [ ] Store the Compose files in this repository (`docker/`)

### 11. Monitoring

**Goal:** know when systems are sick before users do.

- [ ] CPU, memory, disk, and network metrics
- [ ] Uptime checks with Uptime Kuma
- [ ] Metrics with Prometheus and dashboards with Grafana
- [ ] Configure an alert that fires before a user reports the problem

---

## Stage 4: Cloud and automation

### 12. Azure

**Goal:** stop being only an on-premises administrator.

- [ ] Cloud basics, core services, pricing (AZ-900)
- [ ] Virtual machines, storage, networking
- [ ] RBAC and Entra ID integration
- [ ] Azure Backup
- [ ] AZ-104 (Azure Administrator)

### 13. Automation: Ansible, Terraform, CI/CD

**Goal:** manage many systems at once and treat infrastructure as code.

- [ ] Ansible: inventory, playbooks, variables
- [ ] Ansible: install a package, restart a service, change a config on several servers
- [ ] Terraform: providers, resources, variables, state
- [ ] Terraform: create a small Azure environment
- [ ] GitHub Actions: run PSScriptAnalyzer on every push to this repository
- [ ] GitHub Actions: run Pester tests for the Service Desk Toolkit

---

## Habit: Document Every Solved Problem

Every time I solve something worth remembering, I write it up as a short case study (planned `case-studies/` folder), sanitized of names, IPs, and anything confidential:

```text
# Short title of the problem

## Symptom
What the user saw or reported.

## Investigation
What I checked, the commands I ran, and what they showed.

## Root cause
What was actually wrong.

## Fix
What solved it.

## Lesson
What I'd check first next time.
```

> After a year, this repository becomes my own knowledge base and proof of what I can do.
