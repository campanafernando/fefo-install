#!/usr/bin/env zsh
# fefo-install tests. Plain zsh; isolated HOME/XDG; no writes outside temp dirs.
emulate -L zsh
setopt extended_glob
R=${0:A:h:h}
FEFO_SRC=${FEFO_SRC:-/home/fefo/FEFO}
PASS=0 FAIL=0
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
t() { local n=$1; shift
  if eval "$@"; then ((PASS++)); print "PASS $n"; else ((FAIL++)); print "FAIL $n" >&2; fi; }

# fresh isolated env per scenario: sets HOME and XDG vars under $T/$1
env_for() {
  export HOME=$T/$1/home XDG_DATA_HOME=$T/$1/home/.local/share XDG_CONFIG_HOME=$T/$1/home/.config
  export XDG_CACHE_HOME=$T/$1/home/.cache
  unset XDG_BIN_HOME FEFO_DIR FEFO_MODE FEFO_MODEL FEFO_AGENTS
  mkdir -p $HOME
}
export PATH=$R/tests/shims:$PATH FEFO_INSTALL_DRY=1 FEFO_SKIP_UPDATE_CHECK=1 FEFO_YES=1
IN="--yes --cheap --default-agents --with-all"

for f in $R/install.zsh $R/fefo.zsh $R/tests/install.zsh; do
  t "zsh -n ${f:t}" "zsh -n $f"
done
t "sh -n install.sh" "sh -n $R/install.sh"
t "install.sh <=30 lines" '(( $(wc -l < $R/install.sh) <= 30 ))'
t "no <| garbage" '! grep -n "<|" $R/install.sh $R/install.zsh $R/fefo.zsh $R/README.md'

# 1. --from checkout
env_for a
zsh $R/install.zsh --from $FEFO_SRC ${=IN} >$T/a.out 2>&1
H=$XDG_DATA_HOME/fefo-install
t "from: link to checkout" '[[ $(readlink $HOME/.local/bin/fefo) == $FEFO_SRC/bin/fefo ]]'
t "from: helper copied" '[[ -f $H/fefo.zsh ]]'
t "from: zshrc sources helper" 'grep -q "source \"$H/fefo.zsh\"" $HOME/.zshrc'
t "from: dry components" 'grep -q "^DRY: .*browse" $T/a.out'
t "from: config written" 'grep -qx "subagents cheap" $XDG_CONFIG_HOME/fefo/config.zsh && grep -qx "agents default" $XDG_CONFIG_HOME/fefo/config.zsh'
t "from: nothing copied to data dir" '[[ ! -e $XDG_DATA_HOME/fefo ]]'
zsh $R/install.zsh --from $FEFO_SRC ${=IN} >/dev/null 2>&1
t "twice: one zshrc block" '(( $(grep -c "^# >>> fefo >>>" $HOME/.zshrc) == 1 ))'
t "helper functions load" 'zsh -c "source $H/fefo.zsh; whence -w cmg bng doit" | grep -c ":" | grep -q 3'

# cmg/bng/doit with shim
G=$T/a/repo; mkdir -p $G; git -C $G init -q; print x > $G/f.txt; git -C $G add f.txt
out=$(cd $G && zsh -c "source $H/fefo.zsh; cmg" 2>&1)
t "cmg suggests commit" '[[ $out == *"git commit -m"* ]]'
out=$(cd $G && zsh -c "source $H/fefo.zsh; bng" 2>&1)
t "bng makes branch" '[[ $out == *"→"* ]]'
out=$(cd $G && zsh -c "source $H/fefo.zsh; doit -C $G do-it" 2>&1)
t "doit runs" '[[ $out == *"doit: opencode model="* ]]'

# 2. piped install.sh (curl | sh shape): downloads fefo-install as a tarball (local file:// here)
env_for b; mkdir -p $T/b/cwd $T/b/pkg/fefo-install
cp -R $R/install.sh $R/install.zsh $R/fefo.zsh $T/b/pkg/fefo-install/
tar -czf $T/b/fi.tgz -C $T/b/pkg fefo-install
# a decoy install.zsh in the current directory must never run when piped
print -r -- 'touch "$HOME/DECOY_RAN"' > $T/b/cwd/install.zsh
(cd $T/b/cwd && cat $R/install.sh | FEFO_INSTALL_TARBALL=file://$T/b/fi.tgz sh -s -- --from $FEFO_SRC --dir $T/b/fefo ${=IN} >/dev/null 2>&1)
t "piped sh install" '[[ -L $HOME/.local/bin/fefo && -f $XDG_DATA_HOME/fefo-install/fefo.zsh ]]'
t "piped sh ignores cwd install.zsh" '[[ ! -e $HOME/DECOY_RAN ]]'

# 3. tarball download (network)
env_for c
zsh $R/install.zsh --ref main --dir $T/c/fefo ${=IN} >$T/c.out 2>&1
t "tarball: bin/fefo exists" '[[ -f $T/c/fefo/bin/fefo ]]'
t "tarball: no .git" '[[ ! -e $T/c/fefo/.git ]]'
t "tarball: link to downloaded" '[[ $(readlink $HOME/.local/bin/fefo) == $T/c/fefo/bin/fefo ]]'
zsh $R/install.zsh --ref main --dir $T/c/fefo ${=IN} >/dev/null 2>&1
t "tarball: re-install ok, no leftovers" '[[ -f $T/c/fefo/bin/fefo && ! -e $T/c/fefo.old ]]'
zsh $R/install.zsh --uninstall --yes >/dev/null 2>&1
t "uninstall: downloaded FEFO removed" '[[ ! -e $T/c/fefo ]]'
t "uninstall: link, block, helper gone" '[[ ! -e $HOME/.local/bin/fefo && ! -e $XDG_DATA_HOME/fefo-install ]] && ! grep -q ">>> fefo" $HOME/.zshrc'

# uninstall keeps --from checkout
env_for a
zsh $R/install.zsh --uninstall --yes >/dev/null 2>&1
t "uninstall: --from checkout kept" '[[ -f $FEFO_SRC/bin/fefo ]]'
t "uninstall: from link/block/helper gone" '[[ ! -e $HOME/.local/bin/fefo && ! -e $XDG_DATA_HOME/fefo-install ]] && ! grep -q ">>> fefo" $HOME/.zshrc'

print "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
