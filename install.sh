#!/bin/sh
# FEFO installer: downloads the FEFO workspace template and links the fefo CLI.
# Linux, macOS and WSL. Windows uses install.ps1.
set -eu

REPO=${FEFO_REPO:-campanafernando/FEFO}
REF=${FEFO_REF:-main}
INSTALL_DIR=${FEFO_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/fefo}
BIN_DIR=${FEFO_BIN_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}
URL=${FEFO_TARBALL_URL:-https://codeload.github.com/$REPO/tar.gz/$REF}
PYTHON=${PYTHON:-python3}

fail() {
  printf 'fefo-install: %s\n' "$*" >&2
  exit 1
}

case "$INSTALL_DIR" in
  ""|"/"|"$HOME") fail "refusing unsafe install dir: $INSTALL_DIR" ;;
esac

command -v "$PYTHON" >/dev/null 2>&1 || fail "python3 not found; install Python 3.10+"
"$PYTHON" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' \
  || fail "Python 3.10+ is required"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/fefo-install.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

case "$URL" in
  file://*)
    cp "${URL#file://}" "$tmp/fefo.tar.gz" || fail "could not read $URL"
    ;;
  /*)
    cp "$URL" "$tmp/fefo.tar.gz" || fail "could not read $URL"
    ;;
  *)
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL "$URL" -o "$tmp/fefo.tar.gz" || fail "download failed: $URL"
    elif command -v wget >/dev/null 2>&1; then
      wget -q "$URL" -O "$tmp/fefo.tar.gz" || fail "download failed: $URL"
    else
      fail "curl or wget is required"
    fi
    ;;
esac

tar -xzf "$tmp/fefo.tar.gz" -C "$tmp" || fail "could not extract FEFO"
src=
for dir in "$tmp"/*; do
  if [ -d "$dir" ]; then
    src=$dir
    break
  fi
done
[ -n "$src" ] || fail "unexpected archive layout"

rm -rf "$INSTALL_DIR"
mkdir -p "$(dirname "$INSTALL_DIR")" "$BIN_DIR"
mv "$src" "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/bin/fefo" 2>/dev/null || true
ln -sf "$INSTALL_DIR/bin/fefo" "$BIN_DIR/fefo"

if [ "${FEFO_NO_MODIFY_PATH:-0}" != "1" ]; then
  case ":${PATH:-}:" in
    *":$BIN_DIR:"*) ;;
    *)
      shell_name=$(basename "${SHELL:-sh}")
      rc="$HOME/.profile"
      [ "$shell_name" = "zsh" ] && rc="$HOME/.zshrc"
      [ "$shell_name" = "bash" ] && rc="$HOME/.bashrc"
      line="export PATH=\"$BIN_DIR:\$PATH\""
      if [ -f "$rc" ] && grep -qF "$line" "$rc"; then
        :
      else
        printf '\n# fefo\n%s\n' "$line" >> "$rc"
      fi
      printf 'Added %s to PATH in %s. Open a new terminal or run:\n  %s\n' "$BIN_DIR" "$rc" "$line"
      ;;
  esac
fi

"$BIN_DIR/fefo" --help >/dev/null 2>&1 || fail "installed CLI did not run"

cat <<EOF

FEFO installed.
  CLI:  $BIN_DIR/fefo
  Home: $INSTALL_DIR

Next:
  mkdir -p ~/EXEMPLO && cd ~/EXEMPLO
  git clone <repository> exemplo-api
  git clone <repository> exemplo-web
  fefo build

Helpers:
  fefo cmg             suggest a Conventional Commit message
  fefo bng             suggest and create a branch
  fefo doit "task"     run a task through OpenCode
EOF
