#!/usr/bin/env bash

GITHUB_REMOTE="git@github.com:shoganaich/sysadmin-notes.git"
GITLAB_REMOTE="git@gitlab.com:shoganaich/sysadmin-notes.git"

echo "Configuring Git remotes..."

# Remove existing remotes if present
git remote remove origin 2>/dev/null || true
git remote remove gitlab 2>/dev/null || true

# Add remotes
git remote add github "$GITHUB_REMOTE"
git remote add gitlab "$GITLAB_REMOTE"

echo
echo "Remotes configured:"
git remote -v

echo
echo "Done."
echo
echo "Push to GitHub:"
echo "  git push github main"
echo
echo "Push to GitLab:"
echo "  git push gitlab main"
echo
echo "Push to both:"
echo "  git push github main && git push gitlab main"
