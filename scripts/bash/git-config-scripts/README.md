# Git Configuration Scripts

This directory contains small Bash scripts for configuring Git and related repository settings in a consistent way.

## Contents

- `git-config.sh` — sets the default Git editor and global user identity.
- `git-config-ssh.sh` — configures SSH-related Git settings and key usage helpers.
- `git-config-commit.sh` — sets commit-related defaults such as templates or hooks.
- `git-config-rules.sh` — applies repository rules and standard configuration preferences.
- `git-config-branch.sh` — configures branch naming and branch-related defaults.

## Purpose

These scripts are intended to simplify the setup of standard Git configuration for local machines or servers, especially when aligning environments to a common workflow.

## Typical usage

Run any script directly:

```bash
./git-config.sh
```

Or source it if it is designed to export environment variables or shell helpers:

```bash
source ./git-config.sh
```

## Notes

- Review each script before running it, especially if it changes global Git settings.
- Some scripts may require permissions or additional setup such as SSH keys or repository initialization.
- These scripts are meant to be simple and modular, making it easy to reuse or adjust individual configuration steps.
