#!/usr/bin/env bash

set -euo pipefail

# Run this from inside the sysadmin-notes repository.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: Not inside a Git repository. cd into sysadmin-notes first."
    exit 1
fi

GITHUB_REMOTE="git@github.com:shoganaich/sysadmin-notes.git"

echo "Configuring Git remotes..."

# Remove existing remotes if present (github, gitlab and forgejo are old remote names no longer used)
git remote remove origin 2>/dev/null || true
git remote remove github 2>/dev/null || true
git remote remove gitlab 2>/dev/null || true
git remote remove forgejo 2>/dev/null || true

# Add remote
git remote add origin "$GITHUB_REMOTE"

echo
echo "Remotes configured:"
git remote -v

echo
echo "Done."
echo
echo "Push to GitHub:"
echo "  git push origin main"
