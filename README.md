# fefo-install

Separate installer for [FEFO](https://github.com/campanafernando/FEFO). FEFO is
the workspace reference and the source of the generator, agents and skills; this
repository only distributes it and links the `fefo` CLI.

## Install

Linux, macOS and WSL:

```sh
curl -fsSL https://raw.githubusercontent.com/campanafernando/fefo-install/main/install.sh | sh
```

Windows PowerShell (`cmd.exe` uses the same `fefo.cmd` shim afterwards):

```powershell
irm https://raw.githubusercontent.com/campanafernando/fefo-install/main/install.ps1 | iex
```

Requirements: Git, Python 3.10+, OpenCode 2.3.0+. The installer is per-user and
needs no `sudo`.

## What it does

- Downloads FEFO to `~/.local/share/fefo` (`%LOCALAPPDATA%\fefo` on Windows).
- Links `fefo` into `~/.local/bin` (`%USERPROFILE%\.local\bin\fefo.cmd`).
- Adds that directory to PATH when needed (zsh: `~/.zshrc`, bash: `~/.bashrc`).
- Verifies the CLI runs.

Re-running the installer replaces the downloaded template. Workspaces keep their
own `.fefo/workspace.json`, `opencode.json`, vault and Git history.

## Use

```sh
mkdir -p ~/EXEMPLO && cd ~/EXEMPLO
git clone <repository> exemplo-api
git clone <repository> exemplo-web
fefo build
```

`fefo build` (or `fefo .`) copies the agents/skills skeleton into the current
directory, scans the direct Git children, infers role, stack and commands, and
writes the OpenCode, Claude, Cursor and Copilot adapters.

Other commands:

```sh
fefo status
fefo add ../worker --role data
fefo sync --check
fefo doctor
fefo cmg
fefo bng
fefo doit "task"
```

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `FEFO_REF` | `main` | Branch, tag or commit of FEFO to install |
| `FEFO_REPO` | `campanafernando/FEFO` | GitHub repository |
| `FEFO_INSTALL_DIR` | `~/.local/share/fefo` / `%LOCALAPPDATA%\fefo` | Download target |
| `FEFO_BIN_DIR` | `~/.local/bin` / `%USERPROFILE%\.local\bin` | CLI shim location |
| `FEFO_TARBALL_URL` / `FEFO_ZIP_URL` | GitHub archive | Mirror or local archive |
| `FEFO_NO_MODIFY_PATH` | unset | Set to `1` to skip PATH changes |
| `PYTHON` | `python3` | Python interpreter (Unix) |

Pin a release:

```sh
FEFO_REF=v0.5.0 curl -fsSL https://raw.githubusercontent.com/campanafernando/fefo-install/main/install.sh | sh
```

## Why a separate repository

The installer changes more often than the workspace contract. Keeping it apart
lets the one-liner, PATH handling, Windows shim and release pinning evolve
without touching the template that existing workspaces depend on. FEFO remains a
single source of truth; this repository downloads it.

## License

MIT. See [LICENSE](LICENSE).
