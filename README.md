# fefo-install

Installs [FEFO](https://github.com/campanafernando/FEFO) (what FEFO is and how it works lives there) and the zsh shell helpers `cmg`, `bng`, `doit`.

```sh
curl -fsSL https://raw.githubusercontent.com/campanafernando/fefo-install/main/install.sh | sh
# with flags:
curl -fsSL https://raw.githubusercontent.com/campanafernando/fefo-install/main/install.sh | sh -s -- --cheap --with-all
```

Then: `mkdir -p ~/workspace && cd ~/workspace && fefo init`.

## Requirements
zsh ≥ 5.8 on Linux or macOS, the latest [OpenCode](https://opencode.ai), git, curl or wget. [CodeGraph](https://github.com/colbymchenry/codegraph) is recommended (offered as an optional component).

## Flags
| Flag | Effect |
|---|---|
| `--dir DIR` | FEFO install dir (default `${XDG_DATA_HOME:-~/.local/share}/fefo`) |
| `--ref REF` | FEFO branch/tag/sha to download (default `main`) |
| `--from DIR` | use an existing FEFO checkout in place (linked, not copied) |
| `--cheap` / `--model M` | subagent models: cheapest free, or one chosen model (asked interactively otherwise) |
| `--fallback M` | fallback model (default `auto`) |
| `--default-agents` / `--ai-agents` | agent set: built-in default, or AI-scoped |
| `--with-all` | install optional components: codegraph, browse, ponytail plugin, caveman skill |
| `--yes` | answer yes to prompts |
| `--uninstall` | remove everything this installer added |

Env: `FEFO_INSTALL_REF` (fefo-install ref for `install.sh`), `FEFO_SKIP_UPDATE_CHECK=1`, `FEFO_INSTALL_DRY=1` (print optional-component commands instead of running them).

## What it writes
- FEFO tarball → `--dir` (replaced atomically; no git clone), unless `--from`.
- `~/.local/bin/fefo` → link to `<FEFO>/bin/fefo`.
- `${XDG_DATA_HOME:-~/.local/share}/fefo-install/fefo.zsh` (helpers) and a `downloaded` marker.
- `~/.zshrc` block `# >>> fefo >>>` … `# <<< fefo <<<` (PATH + `source` of the helpers); rewritten, never duplicated.
- `${XDG_CONFIG_HOME:-~/.config}/fefo/config.zsh`: only the `subagents`, `fallback`, `agents` (and `ai-model`) lines.
- Optional components: CodeGraph, browse, ponytail plugin, `~/.agents/skills/caveman/SKILL.md`.

## Shell helpers
- `cmg`: suggests a Conventional Commit message for the current diff.
- `bng`: creates a branch named after the diff.
- `doit "task"`: runs an OpenCode agent on a task (`doit -h`).
- `fefo` tab completion.

## Uninstall
```sh
sh install.sh --uninstall   # or: curl … | sh -s -- --uninstall
```
Removes the link, the zshrc block, the helper dir and the FEFO dir only if this installer downloaded it (a `--from` checkout is never touched).

## Tests
`zsh tests/install.zsh` (uses an isolated HOME; one test downloads FEFO from GitHub).
