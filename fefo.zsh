# fefo-install shell helpers: cmg, bng, doit, and `fefo` completion.
if ! command -v timeout >/dev/null 2>&1 && command -v gtimeout >/dev/null 2>&1; then
  alias timeout=gtimeout
fi
unalias cmg 2>/dev/null
unalias doit 2>/dev/null
unalias bng 2>/dev/null

_fefo_mtime() {
  emulate -L zsh; setopt local_options extended_glob no_unset pipe_fail
  zmodload -F zsh/stat b:zstat 2>/dev/null
  local m; m=$(zstat +mtime "$1" 2>/dev/null) || m=0
  [[ -z "$m" ]] && m=0
  printf '%s\n' "$m"
}

_fefo_shell_model() {
  emulate -L zsh; setopt local_options extended_glob no_unset pipe_fail
  local requested="${1:-${FEFO_SHELL_MODEL:-}}"
  [[ -n "$requested" ]] && { printf '%s\n' "$requested"; return 0; }
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/fefo"
  local cache_file="$cache_dir/shell-model" ttl=86400
  if [[ -f "$cache_file" ]]; then
    local mtime now age cached
    mtime=$(_fefo_mtime "$cache_file"); now=$(date +%s); age=$(( now - mtime ))
    if (( age >= 0 && age < ttl )); then
      cached="${$(<"$cache_file")%%$'\n'*}"
      [[ -n "$cached" ]] && { printf '%s\n' "$cached"; return 0; }
    fi
  fi
  mkdir -p "$cache_dir" 2>/dev/null
  local picked
  picked=$(timeout 3 opencode models 2>/dev/null | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g' | grep -- '-free' | head -n 1)
  picked=$(printf '%s' "$picked" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ -n "$picked" ]] || picked="opencode/big-pickle"
  printf '%s\n' "$picked" > "$cache_file"
  printf '%s\n' "$picked"
}

cmg() {
  emulate -L zsh; setopt local_options extended_glob no_unset pipe_fail
  local state="" type="chore" scope="root" files="" diff_output="" file_count=0
  local src_branch="" dst_branch="" inc_commits="" commit_msg="" fallback_msg=""
  local cmg_model; cmg_model=$(_fefo_shell_model "${CMG_MODEL:-}")
  [[ -n "$cmg_model" ]] || cmg_model="opencode/big-pickle"
  local -a diff_args
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "cmg: not inside a git repository" >&2; return 1
  fi
  if git rev-parse --verify MERGE_HEAD >/dev/null 2>&1; then
    state="merge"; type="merge"
    src_branch=$(git rev-parse --abbrev-ref MERGE_HEAD 2>/dev/null | sed 's|remotes/origin/||')
    dst_branch=$(git rev-parse --abbrev-ref HEAD)
    inc_commits=$(git log --oneline HEAD..MERGE_HEAD 2>/dev/null)
    files=$(git diff MERGE_HEAD --name-only 2>/dev/null)
    diff_args=(MERGE_HEAD)
    diff_output=$(git diff "${diff_args[@]}" --stat 2>/dev/null)
  elif git rev-parse --verify REBASE_HEAD >/dev/null 2>&1; then
    state="rebase"; type="rebase"
    files=$(git diff REBASE_HEAD --name-only 2>/dev/null)
    diff_args=(REBASE_HEAD)
    diff_output=$(git diff "${diff_args[@]}" --stat 2>/dev/null)
  elif git rev-parse --verify CHERRY_PICK_HEAD >/dev/null 2>&1; then
    state="cherry-pick"; type="cherry-pick"
    files=$(git diff CHERRY_PICK_HEAD --name-only 2>/dev/null)
    diff_args=(CHERRY_PICK_HEAD)
    diff_output=$(git diff "${diff_args[@]}" --stat 2>/dev/null)
  fi
  if [[ -z "$state" ]]; then
    files=$(git diff --cached --name-only 2>/dev/null)
    if [[ -n "$files" ]]; then
      state="staged"; diff_args=(--cached)
      diff_output=$(git diff "${diff_args[@]}" --stat 2>/dev/null)
    else
      state="unstaged"; files=$(git diff --name-only 2>/dev/null); diff_args=()
      diff_output=$(git diff --stat 2>/dev/null)
    fi
  fi
  if [[ -n "$files" ]]; then
    file_count=$(printf '%s\n' "$files" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
  else
    file_count=0
  fi
  if [[ "$file_count" -eq 0 ]]; then
    echo "cmg: no staged or unstaged changes found" >&2; return 1
  fi
  if [[ "$type" == "chore" ]]; then
    if printf '%s\n' "$files" | grep -q '/test_\|/tests/\|test_factories\|test_runner'; then type="test"
    elif printf '%s\n' "$files" | grep -q '/migrations/'; then type="feat"; scope="migrations"
    elif printf '%s\n' "$files" | grep -qi 'fix\|hotfix'; then type="fix"
    elif printf '%s\n' "$files" | grep -q '^docs/\|README\|\.md$'; then type="docs"
    elif printf '%s\n' "$files" | grep -q '\.py$' && ! printf '%s\n' "$files" | grep -q 'test'; then
      if printf '%s\n' "$files" | grep -q 'service\|selector\|view\|model\|serializer'; then type="feat"; else type="refactor"; fi
    fi
  fi
  if [[ "$type" != "merge" ]]; then
    scope=$(printf '%s\n' "$files" | grep -v '^\.' | sed 's|/.*||' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
    [[ -z "$scope" ]] && scope=$(printf '%s\n' "$files" | grep '^[a-z]' | sed 's|/.*||' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
    [[ -z "$scope" ]] && scope="root"
    if [[ "$type" == "docs" ]]; then
      local docs_scope
      docs_scope=$(printf '%s\n' "$files" | sed -n 's|^docs/\([^/]*\)/.*|\1|p' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
      [[ -n "$docs_scope" ]] && scope="$docs_scope"
    fi
  fi
  echo ""
  echo "┌─ Commit Preview ─────────────────────────────"
  [[ "$state" == "merge" ]] && { echo "│ Merge branch '$src_branch' → '$dst_branch'"; [[ -n "$inc_commits" ]] && { echo "│"; printf '%s\n' "$inc_commits" | while IFS= read -r line; do echo "│  • $line"; done; echo "│"; }; }
  echo "│ Type: $type  Scope: $scope  State: $state  Files: $file_count"
  echo "├──────────────────────────────────────────────"
  [[ -n "$files" ]] && printf '%s\n' "$files" | head -30 | while IFS= read -r f; do [[ -n "$f" ]] && echo "│  $f"; done
  local remaining=$((file_count - 30)); (( remaining > 0 )) 2>/dev/null && echo "│  ... +$remaining more files"
  echo "├─ Diff ───────────────────────────────────────"
  [[ -n "$diff_output" ]] && printf '%s\n' "$diff_output" | head -20 | while IFS= read -r line; do echo "│ $line"; done
  local diff_lines; diff_lines=$(printf '%s\n' "$diff_output" | wc -l | tr -d ' ')
  (( diff_lines > 20 )) 2>/dev/null && echo "│ ... ($((diff_lines - 20)) more lines)"
  echo "└──────────────────────────────────────────────"
  echo ""
  if [[ "$state" == "merge" || "$type" == "merge" ]]; then
    fallback_msg="merge: $src_branch into $dst_branch"
  elif [[ -n "$scope" && "$scope" != "root" ]]; then
    fallback_msg="$type($scope): update changes"
  else
    fallback_msg="$type: update changes"
  fi
  commit_msg="$fallback_msg"
  if [[ "$type" != "merge" ]] && command -v opencode >/dev/null 2>&1; then
    local cmg_context cmg_prompt ai_msg cmg_diff_lines
    cmg_context=$(mktemp "${TMPDIR:-/tmp}/cmg.XXXXXX") || return 1
    cmg_diff_lines="${CMG_DIFF_LINES:-400}"
    [[ "$cmg_diff_lines" =~ '^[0-9]+$' ]] || cmg_diff_lines=400
    {
      printf '# Commit context\n\n'
      printf 'State: %s\nType: %s\nScope: %s\nFiles: %s\n\n' "$state" "$type" "$scope" "$file_count"
      printf 'Preferred prefix: %s\n\n' "${fallback_msg%% update changes}"
      printf '## Git status\n'; git status --short 2>/dev/null
      printf '\n## Changed files\n%s\n\n' "$files"
      printf '## Diff stat\n%s\n\n' "$diff_output"
      printf '## Diff (first %s lines)\n' "$cmg_diff_lines"
      git diff "${diff_args[@]}" --no-ext-diff --unified=3 2>/dev/null | sed -n "1,${cmg_diff_lines}p"
    } > "$cmg_context"
    cmg_prompt="Generate one Conventional Commit message for the attached git diff. Return exactly one line, no markdown, no quotes, and no git command. Use English. Prefer the provided prefix unless the diff clearly needs a better type or scope. Summarize the actual change, not the file list. Keep it under 100 characters. Valid types: feat, fix, docs, refactor, test, chore, build, ci, perf, style, revert."
    echo "Generating commit message with $cmg_model..."
    ai_msg=$(timeout "${CMG_TIMEOUT:-120}" opencode run -m "$cmg_model" --archived --title cmg "$cmg_prompt" --file "$cmg_context" 2>/dev/null | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g' | sed '/^$/d;/^> /d' | tail -1)
    rm -f "$cmg_context"
    ai_msg=$(printf '%s\n' "$ai_msg" | sed -E 's/^```[a-zA-Z]*$//' | sed -E 's/^[[:space:]"`]+//;s/[[:space:]"`]+$//' | grep -E '^(feat|fix|docs|refactor|test|chore|build|ci|perf|style|revert)(\([a-zA-Z0-9._-]+\))?: .+' | tail -1)
    if [[ "$ai_msg" =~ '^(feat|fix|docs|refactor|test|chore|build|ci|perf|style|revert)(\([a-zA-Z0-9._-]+\))?: .+' ]]; then
      commit_msg="$ai_msg"
    else
      echo "cmg: AI did not return a valid Conventional Commit; using fallback." >&2
    fi
  fi
  local commit_msg_for_shell=${commit_msg//\\/\\\\}
  commit_msg_for_shell=${commit_msg_for_shell//\"/\\\"}
  echo "Suggested:"
  printf '  git commit -m "%s"\n' "$commit_msg_for_shell"
  echo ""
}

doit() {
  emulate -L zsh; setopt local_options extended_glob no_unset pipe_fail
  local doit_model; doit_model=$(_fefo_shell_model "${DOIT_MODEL:-}")
  [[ -n "$doit_model" ]] || doit_model="opencode/big-pickle"
  local doit_dir="$PWD" doit_skip_permissions="${DOIT_SKIP_PERMISSIONS:-0}" doit_interactive=0
  local user_request="" doit_prompt="" doit_context="" doit_status=0
  local -a doit_args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ask|--safe|--no-auto-allow) doit_skip_permissions=0; shift ;;
      --allow|--auto-allow|--yes) doit_skip_permissions=1; shift ;;
      -i|--interactive) doit_interactive=1; shift ;;
      -C|--dir)
        shift
        if [[ $# -eq 0 || -z "$1" ]]; then echo "doit: --dir requires a directory" >&2; return 2; fi
        doit_dir="$1"; shift ;;
      --dir=*) doit_dir="${1#--dir=}"; shift ;;
      -m|--model)
        shift
        if [[ $# -eq 0 || -z "$1" ]]; then echo "doit: --model requires provider/model" >&2; return 2; fi
        doit_model="$1"; shift ;;
      --model=*) doit_model="${1#--model=}"; shift ;;
      -h|--help)
        cat <<'EOF'
Usage: doit [options] "task"
Options: --ask/--safe, --allow/--auto-allow, -C/--dir DIR, -m/--model MODEL, -i/--interactive, -h/--help
Env: DOIT_MODEL, DOIT_SKIP_PERMISSIONS
EOF
        return 0 ;;
      --) shift; break ;;
      -*) echo "doit: unknown option: $1" >&2; return 2 ;;
      *) break ;;
    esac
  done
  if [[ $# -eq 0 ]]; then echo "doit: missing task" >&2; return 2; fi
  if ! command -v opencode >/dev/null 2>&1; then echo "doit: opencode not found in PATH" >&2; return 1; fi
  if [[ ! -d "$doit_dir" ]]; then echo "doit: directory does not exist: $doit_dir" >&2; return 1; fi
  user_request="$*"
  doit_context=$(mktemp "${TMPDIR:-/tmp}/doit.XXXXXX") || return 1
  {
    printf 'You are the automation agent behind the user'\''s doit shell command.\n\n'
    printf 'User request:\n%s\n\n' "$user_request"
    printf 'Starting directory:\n%s\n\n' "$doit_dir"
    printf 'Operate end-to-end from this directory. Be careful with destructive operations.\n'
  } > "$doit_context"
  doit_prompt="Execute the task described in the attached doit context."
  doit_args=(run -m "$doit_model" --title doit)
  [[ "$doit_skip_permissions" != "0" ]] && doit_args+=(--auto)
  echo "doit: opencode model=$doit_model dir=$doit_dir"
  if [[ "$doit_skip_permissions" != "0" ]]; then echo "doit: auto-allow enabled"; fi
  if [[ "$doit_interactive" == "1" ]]; then
    ( cd "$doit_dir" && opencode --prompt "$doit_prompt"$'\n\n'"$(<"$doit_context")" )
  else
    ( cd "$doit_dir" && opencode "${doit_args[@]}" --archived "$doit_prompt" --file "$doit_context" )
  fi
  doit_status=$?
  rm -f "$doit_context"
  return "$doit_status"
}

bng() {
  emulate -L zsh; setopt local_options extended_glob no_unset pipe_fail
  local bng_model; bng_model=$(_fefo_shell_model "${BNG_MODEL:-}")
  [[ -n "$bng_model" ]] || bng_model="opencode/big-pickle"
  local -a diff_args=()
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "bng: not inside a git repository" >&2; return 1
  fi
  local files
  files=$(git diff --cached --name-only 2>/dev/null)
  if [[ -n "$files" ]]; then diff_args=(--cached)
  else files=$(git diff --name-only 2>/dev/null); diff_args=(); fi
  if [[ -z "$files" ]]; then echo "bng: no staged or unstaged changes found" >&2; return 1; fi
  local bng_context
  bng_context=$(mktemp "${TMPDIR:-/tmp}/bng.XXXXXX") || return 1
  {
    printf '# Diff\n```diff\n'
    git diff "${diff_args[@]}" --no-ext-diff --unified=3 2>/dev/null | head -2000
    printf '\n```\n'
  } > "$bng_context"
  local bng_prompt="Generate a short git branch name (kebab-case, max 40 chars) for the attached diff. Return exactly one line: the branch name only, no markdown, no quotes, no explanation. Prefix with feat/ fix/ refactor/ chore/ test/ docs/ based on the change type. Examples: feat/add-login-page, fix/null-pointer-crash, refactor/simplify-auth."
  echo "Generating branch name with $bng_model..."
  local ai_name
  ai_name=$(timeout "${BNG_TIMEOUT:-120}" opencode run -m "$bng_model" --archived --title bng "$bng_prompt" --file "$bng_context" 2>/dev/null | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g' | sed '/^$/d;/^> /d' | tail -1)
  rm -f "$bng_context"
  ai_name=$(printf '%s\n' "$ai_name" | sed -E 's/^```[a-zA-Z]*$//' | sed -E 's/^[[:space:]"`]+//;s/[[:space:]"`]+$//' | sed '/^$/d' | tail -1)
  local branch_name
  if [[ -n "$ai_name" && ${#ai_name} -le 60 ]]; then branch_name="$ai_name"
  else branch_name="branch-$(date +%Y%m%d-%H%M%S)"; echo "bng: AI did not return a valid branch name; using fallback." >&2; fi
  echo "→ $branch_name"
  git checkout -b "$branch_name"
}

alias cmg='noglob cmg'
alias doit='noglob doit'
alias bng='noglob bng'

_fefo() {
  emulate -L zsh; setopt local_options extended_glob no_unset pipe_fail
  local -a subcmds
  subcmds=(
    'init:create workspace' 'add:add repo' 'remove:remove repo' 'sync:regenerate managed files'
    'status:show workspace status' 'index:index repos' 'doctor:diagnose workspace'
    'mcp:manage MCP servers' 'model:set model policy' 'handoff:create handoff task'
    'graph:show vault graph' 'agents:install agents' 'version:show version' 'help:show help'
  )
  _describe 'fefo subcommand' subcmds
}

if (( $+functions[compdef] )); then
  compdef _fefo fefo
fi