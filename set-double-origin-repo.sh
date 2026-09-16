#!/bin/sh

echo "[*] Configuring origin to push to Forgejo and GitHub..."

# Clear exising push URLs
git config --unset-all remote.origin.pushurl 2>/dev/null || true

# Add both push targets
git remote set-url --add --push origin "https://git.wyrmnet.link/shoganaich/sysadmin-notes.git"
git remote set-url --add --push origin "https://github.com/shoganaich/sysadmin-notes.git"

echo
echo "[+] Current push URLs"
git config --get-all remote.origin.pushurl

