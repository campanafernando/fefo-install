#!/usr/bin/env zsh
# fefo-install: installs FEFO (tarball) and the cmg/bng/doit shell helpers. zsh only.
emulate -L zsh
setopt extended_glob

autoload -Uz is-at-least

data=${XDG_DATA_HOME:-$HOME/.local/share}
helper_dir=$data/fefo-install
dir=${FEFO_DIR:-$data/fefo}
ref=${FEFO_REF:-main}
cheap=0
model_flag=${FEFO_MODEL:-}
fallback_flag=
yes=0
with_all=0
uninstall=0
from_dir=
ai_agents=0
default_agents=0
explicit=0

while (( $# > 0 )); do
  case $1 in
    --dir) dir=$2; explicit=1; shift 2 ;;
    --ref) ref=$2; explicit=1; shift 2 ;;
    --cheap) cheap=1; shift ;;
    --model) model_flag=$2; shift 2 ;;
    --fallback) fallback_flag=$2; shift 2 ;;
    --yes) yes=1; shift ;;
    --with-all) with_all=1; shift ;;
    --uninstall) uninstall=1; shift ;;
    --from) from_dir=$2; shift 2 ;;
    --ai-agents) ai_agents=1; shift ;;
    --default-agents) default_agents=1; shift ;;
    *) print "fefo-install: unknown flag: $1" >&2; exit 2 ;;
  esac
done

dry=0
[[ ${FEFO_INSTALL_DRY:-0} == 1 ]] && dry=1

is-at-least 5.8 || { print "fefo: zsh >= 5.8 required (found $ZSH_VERSION)" >&2; exit 1; }

script_dir=${0:A:h}
marker=$helper_dir/downloaded

_has_tty() { [[ -t 0 ]] || { [[ -r /dev/tty ]] && ( : </dev/tty ) 2>/dev/null; }; }
_read_line() {
  if [[ -t 0 ]]; then
    printf '%s' "$1" >&2
    read -r REPLY
  elif [[ -r /dev/tty ]] && ( : </dev/tty ) 2>/dev/null; then
    printf '%s' "$1" >/dev/tty 2>/dev/null
    read -r REPLY </dev/tty 2>/dev/null || REPLY=""
  else
    REPLY=""
  fi
}
_confirm() {
  (( yes == 1 || ${FEFO_YES:-0} == 1 )) && return 0
  if _has_tty; then
    _read_line "$1 [y/N] "
    [[ $REPLY == [yY]* ]]
  else
    return 1
  fi
}
_remove_zshrc_block() {
  local rc=$1
  [[ -f $rc ]] || return 0
  local tmp=${rc}.fefo.tmp
  awk '
    $0 ~ /^# >>> fefo >>>$/ { skip=1; next }
    $0 ~ /^# <<< fefo <<<$/ { skip=0; next }
    !skip { print }
  ' "$rc" > "$tmp" && mv "$tmp" "$rc"
}
_bin_dir=${XDG_BIN_HOME:-$HOME/.local/bin}

if (( uninstall == 0 )) && ! whence -p opencode >/dev/null 2>&1; then
  print "opencode not found. Install the latest OpenCode first:" >&2
  print "  curl -fsSL https://opencode.ai/install | bash" >&2
  exit 1
fi

if (( uninstall == 0 )) && [[ ${FEFO_SKIP_UPDATE_CHECK:-0} != 1 ]]; then
  installed=$(opencode --version 2>/dev/null)
  installed=${installed##* }
  installed=${installed#v}
  if [[ -z $installed ]]; then
    print "fefo: could not determine OpenCode version; run: opencode upgrade" >&2
    exit 1
  fi
  latest=$(curl -fsSL --max-time 10 https://opencode.ai/update/api/latest/cli/npm 2>/dev/null)
  if [[ $latest =~ '"version"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
    latest=$match[1]
  else
    latest=""
  fi
  if [[ -n $latest ]]; then
    if ! is-at-least "$latest" "$installed"; then
      print "OpenCode $installed is older than latest $latest." >&2
      if _confirm "Run 'opencode upgrade' now?"; then
        opencode upgrade || { print "fefo: upgrade failed" >&2; exit 1; }
      else
        print "Run: opencode upgrade" >&2
        exit 1
      fi
    fi
  else
    print "fefo: warning: could not check latest OpenCode version; continuing." >&2
  fi
fi

if (( uninstall == 0 )) && ! whence -p git >/dev/null 2>&1; then
  print "git not found" >&2
  exit 1
fi

if (( uninstall == 1 )); then
  if ! _confirm "Uninstall FEFO (remove link, zshrc block, helper dir, downloaded FEFO)?"; then
    print "cancelled"
    exit 0
  fi
  rm -f "$_bin_dir/fefo"
  _remove_zshrc_block "$HOME/.zshrc"
  # Only a FEFO dir this installer downloaded is removed; a --from checkout never is.
  if [[ -f $marker ]]; then
    dl=$(<"$marker")
    [[ -n $dl && $dl != / && $dl != $HOME ]] && rm -rf "$dl"
  fi
  rm -rf "$helper_dir"
  print "FEFO uninstalled."
  exit 0
fi

mkdir -p "$helper_dir"
if [[ -n $from_dir ]]; then
  [[ -f $from_dir/bin/fefo ]] || { print "fefo-install: --from: no bin/fefo in $from_dir" >&2; exit 1; }
  FEFO_HOME=${from_dir:A}
  : > "$marker"
else
  mkdir -p "${dir:h}"
  tmpd=$(mktemp -d "${dir:h}/.fefo.XXXXXX") || exit 1
  url=https://codeload.github.com/campanafernando/FEFO/tar.gz/$ref
  if whence -p curl >/dev/null 2>&1; then
    curl -fsSL "$url" | tar -xz --strip-components=1 -C "$tmpd"
  elif whence -p wget >/dev/null 2>&1; then
    wget -qO- "$url" | tar -xz --strip-components=1 -C "$tmpd"
  else
    rm -rf "$tmpd"; print "fefo-install: curl or wget required" >&2; exit 1
  fi
  if (( ${pipestatus[1]} != 0 || ${pipestatus[2]} != 0 )) || [[ ! -f $tmpd/bin/fefo ]]; then
    rm -rf "$tmpd"; print "fefo-install: download of FEFO ($ref) failed" >&2; exit 1
  fi
  rm -rf "$dir.old"
  [[ -e $dir ]] && mv "$dir" "$dir.old"
  mv "$tmpd" "$dir"
  rm -rf "$dir.old"
  FEFO_HOME=${dir:A}
  print -r -- "$FEFO_HOME" > "$marker"
fi

chmod +x "$FEFO_HOME/bin/fefo" 2>/dev/null || true

mkdir -p "$_bin_dir"
ln -sf "$FEFO_HOME/bin/fefo" "$_bin_dir/fefo"

cp "$script_dir/fefo.zsh" "$helper_dir/fefo.zsh"

rc="$HOME/.zshrc"
touch "$rc" 2>/dev/null || true
_remove_zshrc_block "$rc"
{
  print "# >>> fefo >>>"
  print "export PATH=\"$_bin_dir:\$PATH\""
  print "source \"$helper_dir/fefo.zsh\""
  print "# <<< fefo <<<"
} >> "$rc"

_run_component() {
  local name=$1; shift
  local cmd="$*"
  if (( dry == 1 )); then
    print "DRY: $cmd"
    return 0
  fi
  eval "$cmd"
}
_component_yes() {
  local name=$1
  if (( with_all == 1 )); then return 0; fi
  if _has_tty; then
    _read_line "Install $name? [y/N] "
    [[ $REPLY == [yY]* ]]
  else
    return 1
  fi
}

if ! whence -p codegraph >/dev/null 2>&1; then
  if _component_yes "codegraph"; then
    _run_component codegraph "curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh"
  fi
fi
if _component_yes "browse"; then
  _run_component browse "curl -fsSL https://opencode.ai/browse/install | bash"
fi
if _component_yes "ponytail"; then
  _run_component ponytail "opencode plugin add @dietrichgebert/ponytail"
fi
if _component_yes "caveman"; then
  _run_component caveman "mkdir -p \"\$HOME/.agents/skills/caveman\" && curl -fsSL https://raw.githubusercontent.com/juliusbrussee/caveman/main/skills/caveman/SKILL.md -o \"\$HOME/.agents/skills/caveman/SKILL.md\""
fi

mode=""
submodel=""
if (( cheap == 1 )); then
  mode=cheap
elif [[ -n $model_flag ]]; then
  mode=default
  submodel=$model_flag
elif [[ -n ${FEFO_MODE:-} ]]; then
  mode=${FEFO_MODE}
  [[ -n ${FEFO_MODEL:-} ]] && submodel=${FEFO_MODEL}
else
  if _has_tty; then
    print "Subagent models:" >&2
    print "[1] cheap — orchestrator picks the strongest free model (default)" >&2
    print "[2] default — you pick one model now" >&2
    _read_line "Choice [1]: "
    if [[ $REPLY == 2 ]]; then
      mode=default
      while true; do
        _read_line "Search query (Enter for all): "
        q=$REPLY
        models=$(opencode models 2>/dev/null)
        if [[ -n $q ]]; then
          matches=(${(f)"$(print -r -- "$models" | grep -i -- "$q")"})
        else
          matches=(${(f)models})
        fi
        if (( ${#matches} > 30 )); then
          matches=("${matches[1,30]}")
        fi
        if (( ${#matches} == 0 )); then
          print "no matches" >&2
          continue
        fi
        i=1
        for m in "${matches[@]}"; do
          print "  $i) $m" >&2
          (( i++ ))
        done
        _read_line "number, new search, or Enter to cancel: "
        if [[ -z $REPLY ]]; then
          mode=cheap
          break
        fi
        if [[ $REPLY == <-> ]] && (( REPLY >= 1 && REPLY <= ${#matches} )); then
          submodel=${matches[REPLY]}
          break
        fi
        q=$REPLY
      done
    else
      mode=cheap
    fi
  else
    mode=cheap
  fi
fi
[[ -z $mode ]] && mode=cheap

fallback=${fallback_flag:-}
if [[ -z $fallback ]] && _has_tty; then
  _read_line "Fallback model (Enter = auto): "
  fallback=$REPLY
fi
[[ -z $fallback ]] && fallback=auto

agents_mode=""
if (( ai_agents == 1 )); then
  agents_mode=ai
elif (( default_agents == 1 )); then
  agents_mode=default
elif [[ -n ${FEFO_AGENTS:-} ]]; then
  agents_mode=${FEFO_AGENTS}
else
  if _has_tty; then
    print "Agents: [1] default set (recommended offline) [2] AI-scoped with a free model" >&2
    _read_line "Choice [1]: "
    if [[ $REPLY == 2 ]]; then
      agents_mode=ai
    else
      agents_mode=default
    fi
  else
    agents_mode=default
  fi
fi
[[ -z $agents_mode ]] && agents_mode=default

ai_model=""
if [[ $agents_mode == ai ]]; then
  if [[ -n $submodel ]]; then
    ai_model=$submodel
  elif [[ -n ${FEFO_MODEL:-} ]]; then
    ai_model=${FEFO_MODEL}
  else
    ai_model=$(opencode models 2>/dev/null | grep -- '-free' | head -1)
  fi
fi

config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/fefo
mkdir -p "$config_dir"
config_file=$config_dir/config.zsh
touch "$config_file" 2>/dev/null || true

keys=(subagents fallback agents)
[[ -n $ai_model ]] && keys+=(ai-model)

tmp=${config_file}.tmp
: > "$tmp"
while IFS= read -r line || [[ -n $line ]]; do
  trimmed=${line#"${line%%[![:space:]]*}"}
  w=${trimmed%% *}
  skip=0
  for k in "${keys[@]}"; do
    if [[ $w == $k ]]; then skip=1; break; fi
  done
  (( skip == 0 )) && print -r -- "$line" >> "$tmp"
done < "$config_file"
mv "$tmp" "$config_file"

{
  if [[ $mode == cheap ]]; then
    print "subagents cheap"
  else
    print "subagents default $submodel"
  fi
  print "fallback $fallback"
  print "agents $agents_mode"
  [[ -n $ai_model ]] && print "ai-model $ai_model"
} >> "$config_file"

"$FEFO_HOME/bin/fefo" doctor || true

print ""
print "FEFO installed."
print "  CLI:  $_bin_dir/fefo"
print "  Home: $FEFO_HOME"
print ""
print "Next:"
print "  mkdir -p ~/workspace && cd ~/workspace"
print "  fefo init"
print ""
