# Git Configuration Scripts

Bash scripts for setting up Git on my Linux machines.

They cover the basic global Git config, SSH authentication, SSH commit signing, useful defaults, and the repository remotes.

## Contents

| Script | Purpose |
|---|---|
| `configure-git.sh` | Configures global Git identity, SSH authentication, SSH commit signing, and Git defaults |
| `configure-remotes.sh` | Configures the GitHub remote for `sysadmin-notes` |

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
```

If a key doesn't exist yet, create it first, for example:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_gitauth -C "git authentication"
ssh-keygen -t ed25519 -f ~/.ssh/id_gitsigh -C "git signing"
```

Then add the public keys to GitHub: the authentication key as an authentication key, and the signing key as a signing key.

## Usage

Configure Git (run once per machine):

```bash
./configure-git.sh
```

Configure the remotes (run from inside the repository):

```bash
cd ~/gitrepos/sysadmin-notes
/path/to/configure-remotes.sh
```

`configure-git.sh` manages its own block in `~/.ssh/config`, marked with `BEGIN/END SYSADMIN-NOTES GIT CONFIG`. Running it again replaces that block instead of duplicating it.

## What `configure-git.sh` sets

| Setting | Value | Why |
|---|---|---|
| `gpg.format` | `ssh` | Sign commits with an SSH key instead of GPG |
| `commit.gpgsign` | `true` | Sign every commit by default |
| `init.defaultBranch` | `main` | Consistent default branch name |
| `fetch.prune` | `true` | Remove references to deleted remote branches |
| `pull.rebase` | `true` | Avoid unnecessary merge commits when pulling |
| `rerere.enabled` | `true` | Reuse recorded conflict resolutions |
| `color.ui` | `auto` | Coloured output in the terminal |

## Pushing

```bash
git push origin main
```

## Notes

- The scripts contain my own name, email, and remote URLs. Change the variables at the top of each script before using them for another account.
