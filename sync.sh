#!/usr/bin/env bash
# Symlink dotfile packages into $HOME using GNU stow.
set -euo pipefail

if ! command -v stow >/dev/null 2>&1; then
  echo "error: GNU stow is not installed (try: brew install stow)" >&2
  exit 1
fi

PACKAGES=(claude kitty)

# Run from the repo root; stow uses the current directory as its package dir.
stow --target="$HOME" --verbose "${PACKAGES[@]}"
