# fefo-install (retired)

FEFO now installs itself:

```sh
curl -fsSL https://raw.githubusercontent.com/campanafernando/FEFO/main/install.zsh | zsh
```

`install.sh` in this repository only forwards to that script (flags included), so
old one-liners such as `curl -fsSL …/fefo-install/main/install.sh | sh` keep
working. FEFO needs zsh on Linux or macOS and the latest OpenCode; Windows and
PowerShell are no longer supported.

See [FEFO](https://github.com/campanafernando/FEFO) for everything else.
