#!/usr/bin/env bash

set -euo pipefail

# Git Configuration

GIT_NAME="shoganaich"
GIT_EMAIL="shoganaich@tutanota.com"

SSH_DIR="$HOME/.ssh"
AUTH_KEY="$SSH_DIR/id_gitauth"
SIGN_KEY="$SSH_DIR/id_gitsigh"
SSH_CONFIG="$SSH_DIR/config"

echo "==> Configuring Git"
echo

# Verify if SSH keys exist on the .ssh

if [[ ! -f "$AUTH_KEY" ]]; then
    echo "ERROR: SSH authentication key not found:"
    echo "  $AUTH_KEY"
    exit 1
fi

if [[ ! -f "$AUTH_KEY.pub" ]]; then
    echo "ERROR: SSH authentication public key not found:"
    echo "  $AUTH_KEY.pub"
    exit 1
fi

if [[ ! -f "$SIGN_KEY" ]]; then
    echo "ERROR: SSH signing key not found:"
    echo "  $SIGN_KEY"
    exit 1
fi

if [[ ! -f "$SIGN_KEY.pub" ]]; then
    echo "ERROR: SSH signing public key not found:"
    echo "  $SIGN_KEY.pub"
    exit 1
fi

# Setup SSH directory permissions

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

chmod 600 "$AUTH_KEY"
chmod 644 "$AUTH_KEY.pub"

chmod 600 "$SIGN_KEY"
chmod 644 "$SIGN_KEY.pub"

# Configure SSH Git auth

echo "==> Configuring SSH"

touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

# Remove existing blocks managed by this script
sed -i '/# BEGIN SYSADMIN-NOTES GIT CONFIG/,/# END SYSADMIN-NOTES GIT CONFIG/d' "$SSH_CONFIG"

cat >> "$SSH_CONFIG" <<EOF

# BEGIN SYSADMIN-NOTES GIT CONFIG

Host github.com
    HostName github.com
    User git
    IdentityFile $AUTH_KEY
    IdentitiesOnly yes

Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile $AUTH_KEY
    IdentitiesOnly yes

Host git.wyrmnet.link
    HostName git.wyrmnet.link
    Port 222
    User git
    IdentityFile $AUTH_KEY
    IdentitiesOnly yes

# END SYSADMIN-NOTES GIT CONFIG
EOF

# Git identity

echo "==> Configuring Git identity"

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

# Configuring the SSH commit signing

echo "==> Configuring SSH commit signing"

git config --global gpg.format ssh
git config --global user.signingkey "$SIGN_KEY.pub"
git config --global commit.gpgsign true

# Configuring some useful Git defaults

echo "==> Configuring Git defaults"

git config --global init.defaultBranch main
git config --global fetch.prune true
git config --global pull.rebase true
git config --global rerere.enabled true
git config --global color.ui auto

# Display configuration

echo
echo "========================================"
echo " Git configuration complete"
echo "========================================"
echo

echo "Git identity:"
git config --global user.name
git config --global user.email

echo
echo "Commit signing:"
git config --global gpg.format
git config --global user.signingkey
git config --global commit.gpgsign

echo
echo "SSH authentication:"
echo "  $AUTH_KEY"

echo
echo "SSH signing:"
echo "  $SIGN_KEY"

echo
echo "Done."
