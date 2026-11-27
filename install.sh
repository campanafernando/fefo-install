#!/bin/sh
# fefo-install is retired: FEFO installs itself. This script only forwards old
# one-liners (curl .../fefo-install/main/install.sh | sh) to FEFO's install.zsh.
set -eu
URL=${FEFO_INSTALL_URL:-https://raw.githubusercontent.com/campanafernando/FEFO/${FEFO_REF:-main}/install.zsh}
if ! command -v zsh >/dev/null 2>&1; then
  printf 'fefo-install: FEFO needs zsh (Linux or macOS). Install zsh, then run:\n  curl -fsSL %s | zsh\n' "$URL" >&2
  exit 1
fi
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$URL" | zsh -s -- "$@"
elif command -v wget >/dev/null 2>&1; then
  wget -qO- "$URL" | zsh -s -- "$@"
else
  printf 'fefo-install: curl or wget is required\n' >&2
  exit 1
fi
