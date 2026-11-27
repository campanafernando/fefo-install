#!/bin/sh
# fefo-install bootstrap: needs zsh and curl or wget. Args go to install.zsh.
set -eu
command -v zsh >/dev/null 2>&1 || { echo "fefo-install: zsh is required (Linux or macOS)" >&2; exit 1; }
# Use a neighbouring install.zsh only when run as a real install.sh file (a clone);
# piped (curl | sh) $0 is the shell, so never pick up files from the current directory.
case $0 in
  install.sh|*/install.sh)
    here=$(cd "$(dirname "$0")" 2>/dev/null && pwd) || here=
    if [ -f "$0" ] && [ -n "$here" ] && [ -f "$here/install.zsh" ]; then
      exec zsh "$here/install.zsh" "$@"
    fi
    ;;
esac
url=${FEFO_INSTALL_TARBALL:-https://codeload.github.com/campanafernando/fefo-install/tar.gz/${FEFO_INSTALL_REF:-main}}
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT INT TERM
if command -v curl >/dev/null 2>&1; then curl -fsSL "$url" -o "$tmp/src.tgz"
elif command -v wget >/dev/null 2>&1; then wget -qO "$tmp/src.tgz" "$url"
else echo "fefo-install: curl or wget is required" >&2; exit 1; fi
mkdir "$tmp/src" && tar -xzf "$tmp/src.tgz" -C "$tmp/src" --strip-components=1
zsh "$tmp/src/install.zsh" "$@"
