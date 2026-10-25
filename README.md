<p align="center">
  <img
    src="https://capsule-render.vercel.app/api?type=venom&color=0:111827,100:374151&height=180&section=header&text=sysadmin-notes&fontSize=45&fontColor=ffffff"
    alt="sysadmin-notes"
  />
</p>

[![License](https://img.shields.io/badge/License-CC%20BY%204.0-181717.svg)](https://creativecommons.org/licenses/by/4.0/)
![Windows](https://img.shields.io/badge/Windows-0078D4?logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?logo=powershell&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=white)

Personal knowledge base for system administration: troubleshooting procedures, reference notes, and automation scripts collected from Service Desk work and my own lab.

The goal is simple: solve a problem once, document it, and never troubleshoot it from scratch again.

---

## Background

I work in IT Service Desk and I'm building towards a System Administrator role. Day to day that means:

- Windows workstation and domain troubleshooting
- Active Directory account and computer support
- Enterprise applications and vendor escalations
- Incident management

Outside work I run Linux servers, Docker containers, and self-hosted services, which is where the Linux and homelab notes will come from.

My learning plan is in [roadmap.md](roadmap.md).

---

## What's in Here

### Windows procedures

Step-by-step procedures written for real support work, with safety checks and escalation points.

| Procedure | Use it when |
|---|---|
| [Windows UEFI Boot Recovery](windows/procedures/winre-uefi-recovery.md) | Windows no longer starts on a UEFI/GPT machine |
| [UEFI Boot Recovery: Advanced Troubleshooting](windows/procedures/winre-uefi-advanced-troubleshooting.md) | The standard boot recovery didn't fix it |
| [Windows PC Cleanup and Optimization](windows/procedures/windows-cleanup.md) | A workstation is low on disk space or needs maintenance |

### Windows reference

| Note | Contents |
|---|---|
| [Network Port Cheatsheet](windows/network-port-cheatsheet.md) | Common ports for AD, DNS, DHCP, remote support, and infrastructure, plus PowerShell port tests |
| [Common Windows Commands](windows/common-commands.md) | Quick command reference |

### Scripts

| Script | Language | What it does |
|---|---|---|
| [AD Toolkit](scripts/powershell/ad-toolkit/) | PowerShell + Batch | Menu-driven toolkit for common Service Desk AD tasks: user and computer lookups, account status, unlocks, password resets, LAPS, and DNS/DHCP checks |
| [Windows Cleanup](scripts/powershell/windows-cleanup/) | PowerShell | Automated version of the cleanup procedure, with a report of what was done and how much space was recovered |
| [Service Manager](scripts/powershell/service-manager/) | PowerShell | Check, start, stop, or restart a service across many computers using number ranges like `070-085` |
| [GPS Locator](scripts/powershell/gps-locator/) | PowerShell + Batch | Reads the latest NMEA fix from a remote computer's GPS log and opens it in Google Maps |
| [Git Config Scripts](scripts/bash/git-config-scripts/) | Bash | Sets up Git identity, SSH authentication, SSH commit signing, and remotes on my Linux machines |

---

## Repository Structure

```text
sysadmin-notes/
├── README.md
├── roadmap.md
├── LICENSE
├── windows/
│   ├── common-commands.md
│   ├── network-port-cheatsheet.md
│   └── procedures/
│       ├── windows-cleanup.md
│       ├── winre-uefi-recovery.md
│       └── winre-uefi-advanced-troubleshooting.md
└── scripts/
    ├── powershell/
    │   ├── ad-toolkit/
    │   ├── gps-locator/
    │   ├── service-manager/
    │   └── windows-cleanup/
    └── bash/
        └── git-config-scripts/
```

### Planned

These sections will be added as the content is written:

- **linux/** - Linux administration and troubleshooting
- **networking/** - Networking concepts and diagnostics
- **docker/** - Docker and Docker Compose notes and examples
- **monitoring/** - Monitoring, logging, and observability
- **case-studies/** - Sanitized incident write-ups: symptom, investigation, root cause, fix
- **homelab/** - Self-hosting and personal infrastructure

---

## Resources

### Windows

- [Microsoft Learn](https://learn.microsoft.com/)
- [Windows Server Documentation](https://learn.microsoft.com/windows-server/)
- [Microsoft Troubleshooting Documentation](https://learn.microsoft.com/troubleshoot/)
- [Sysinternals](https://learn.microsoft.com/sysinternals/)
- [PowerShell Documentation](https://learn.microsoft.com/powershell/)

### Linux

- [Arch Wiki](https://wiki.archlinux.org/)
- [Debian Documentation](https://www.debian.org/doc/)
- [Red Hat Documentation](https://access.redhat.com/documentation/)
- [Ubuntu Server Documentation](https://ubuntu.com/server/docs)
- [Linux Journey](https://linuxjourney.com/)
- [TLDR Pages](https://tldr.sh/)
- [Awesome Sysadmin](https://github.com/awesome-foss/awesome-sysadmin)

### Networking

- [Practical Networking](https://www.practicalnetworking.net/)
- [Cisco Documentation](https://www.cisco.com/c/en/us/support/index.html)
- [NetworkLessons](https://networklessons.com/)
- [Cloudflare Learning Center](https://www.cloudflare.com/learning/)
- [Wireshark Documentation](https://www.wireshark.org/docs/)
- [RFC Editor](https://www.rfc-editor.org/)

### Docker & Containers

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [LinuxServer.io](https://www.linuxserver.io/)
- [Awesome Compose](https://github.com/docker/awesome-compose)
- [Podman Documentation](https://podman.io/docs)

### Monitoring

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Zabbix Documentation](https://www.zabbix.com/documentation/current/en/manual)
- [Uptime Kuma](https://uptime.kuma.pet/)
- [Netdata Documentation](https://learn.netdata.cloud/)

### Automation & Scripting

- [PowerShell Documentation](https://learn.microsoft.com/powershell/)
- [Python Documentation](https://docs.python.org/3/)
- [Real Python](https://realpython.com/)
- [Bash Guide (Greg's Wiki)](https://mywiki.wooledge.org/BashGuide)
- [ShellCheck](https://www.shellcheck.net/)

### Homelab & Self-Hosting

- [Awesome Self-Hosted](https://github.com/awesome-selfhosted/awesome-selfhosted)
- [selfh.st](https://selfh.st/)
- [LinuxServer.io](https://www.linuxserver.io/)
- [Awesome Homelab](https://github.com/awesome-foss/awesome-homelab)

### Security

- [OWASP](https://owasp.org/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)
- [Microsoft Security Documentation](https://learn.microsoft.com/security/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [Security Onion Documentation](https://docs.securityonion.net/)

---

## Disclaimer

This repository is a personal knowledge base. All examples, procedures, and configurations have been sanitized and generalized to remove sensitive or proprietary information.

Scripts and procedures are provided as-is. Review and test them in a non-production environment, and follow your organization's change-management and security policies before using them on real systems.

## License

This work is licensed under the [Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/).

You are free to share and adapt the contents of this repository for any purpose, provided appropriate credit is given.
