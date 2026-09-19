# Git Configuration Scripts

Bash scripts for setting up Git on my Linux machines.

They cover the basic git global config, SSH authentication, commit signing, aliases, and repository remotes.

## Contents

| Script | Purpose |
|---|---|
| `configure-git.sh` | Configures global Git identity, SSH, commit signing, Git defaults, and aliases |
| `configure-remotes.sh` | Configures the GitHub and GitLab remotes for `sysadmin-notes` |

## Requirements

- Git
- OpenSSH
- Bash
- An existing SSH key pair for Git authentication
- An existing SSH key pair for Git commit signing

Expected SSH keys:

```text
~/.ssh/id_gitauth
~/.ssh/id_gitauth.pub

~/.ssh/id_gitsigh
~/.ssh/id_gitsigh.pub