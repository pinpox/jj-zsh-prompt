#!/usr/bin/env zsh
# jj-zsh-prompt: Async Jujutsu (jj) and Git prompt for zsh
# https://github.com/pinpox/jj-zsh-prompt

# Enable debug mode with: export JJ_DEBUG=1
typeset -g JJ_DEBUG="${JJ_DEBUG:-0}"

_jj_debug() {
  [[ $JJ_DEBUG -eq 1 ]] && echo "[JJ-DEBUG] $*" >&2
}

_jj_debug "Starting jj-zsh-prompt initialization"

# Check for zsh-async - REQUIRED
_jj_async_found=0

# Try to find zsh-async in common locations
if [[ -f /usr/share/zsh-async/async.zsh ]]; then
  _jj_debug "Found zsh-async at /usr/share/zsh-async/async.zsh"
  source /usr/share/zsh-async/async.zsh
  _jj_async_found=1
elif [[ -f ~/.config/zsh/plugins/zsh-async/async.zsh ]]; then
  _jj_debug "Found zsh-async at ~/.config/zsh/plugins/zsh-async/async.zsh"
  source ~/.config/zsh/plugins/zsh-async/async.zsh
  _jj_async_found=1
elif [[ -f ~/.zsh/zsh-async/async.zsh ]]; then
  _jj_debug "Found zsh-async at ~/.zsh/zsh-async/async.zsh"
  source ~/.zsh/zsh-async/async.zsh
  _jj_async_found=1
elif (( $+functions[async_init] )); then
  _jj_debug "zsh-async already loaded (async_init function found)"
  _jj_async_found=1
fi

if [[ $_jj_async_found -eq 0 ]]; then
  echo "ERROR: zsh-async is required but not found." >&2
  echo "Please install zsh-async before using jj-zsh-prompt." >&2
  echo "See: https://github.com/mafredri/zsh-async" >&2
  return 1
fi

_jj_debug "zsh-async found and loaded"

# Enable prompt substitution
setopt prompt_subst

# Color configuration - users can override these
typeset -g JJ_COLOR_CHANGE_ID="${JJ_COLOR_CHANGE_ID:-%F{magenta}}"       # Unique prefix of change ID
typeset -g JJ_COLOR_CHANGE_REST="${JJ_COLOR_CHANGE_REST:-%F{240}}"       # Rest of change ID (grey)
typeset -g JJ_COLOR_COMMIT_ID="${JJ_COLOR_COMMIT_ID:-%F{cyan}}"          # Unique prefix of commit ID
typeset -g JJ_COLOR_COMMIT_REST="${JJ_COLOR_COMMIT_REST:-%F{240}}"       # Rest of commit ID (grey)
typeset -g JJ_COLOR_STATUS="${JJ_COLOR_STATUS:-%F{red}}"
typeset -g JJ_COLOR_BOOKMARK="${JJ_COLOR_BOOKMARK:-%F{magenta}}"
typeset -g JJ_COLOR_STATS="${JJ_COLOR_STATS:-%F{blue}}"
typeset -g JJ_COLOR_GIT_BRANCH="${JJ_COLOR_GIT_BRANCH:-%F{240}}"         # Git branch (grey)
typeset -g JJ_COLOR_GIT_ARROWS="${JJ_COLOR_GIT_ARROWS:-%F{cyan}}"        # Git ahead/behind arrows
typeset -g JJ_COLOR_RESET="%f"

# Global variables for async
typeset -g _jj_display=""
typeset -g _jj_last_workspace=""
typeset -g _jj_expected_workspace=""  # Workspace we're waiting for results from

# Async worker function - this runs in background
_jj_async_worker() {
  local workspace=$1
  _jj_debug "Worker: started with workspace=$workspace"

  # Check if jj is installed
  if ! command -v jj &>/dev/null; then
    _jj_debug "Worker: jj command not found"
    echo ""
    return
  fi
  _jj_debug "Worker: jj command found"

  # Change to the workspace directory so jj commands run in the correct repo
  cd "$workspace" || {
    _jj_debug "Worker: failed to cd to workspace"
    echo ""
    return
  }
  _jj_debug "Worker: in jj workspace"

  # Get change/commit IDs and other info in parseable format
  # Format: shortest_change|short4_change|shortest_commit|short4_commit|empty|description
  local jj_data=$(jj log --ignore-working-copy --no-graph --color never -r @ -T '
    change_id.shortest() ++ "|" ++
    change_id.short(4) ++ "|" ++
    commit_id.shortest() ++ "|" ++
    commit_id.short(4) ++ "|" ++
    if(empty, "empty", "nonempty") ++ "|" ++
    if(description, description.first_line(), "(no description)")
  ' 2>/dev/null | head -n 1)

  if [[ -z $jj_data ]]; then
    _jj_debug "Worker: jj_data is empty"
    echo ""
    return
  fi
  _jj_debug "Worker: got jj_data: $jj_data"

  # Parse the data
  local -a parts
  parts=("${(@s:|:)jj_data}")

  local change_shortest="${parts[1]}"
  local change_short4="${parts[2]}"
  local commit_shortest="${parts[3]}"
  local commit_short4="${parts[4]}"
  local is_empty="${parts[5]}"
  local description="${parts[6]}"

  # Get the length of shortest prefix
  local change_len=${#change_shortest}
  local commit_len=${#commit_shortest}

  # Build formatted output with bold unique prefix
  # Format: bold magenta/cyan(unique) + grey(rest of 4 chars)
  local change_rest="${change_short4:$change_len}"
  local commit_rest="${commit_short4:$commit_len}"

  # Use %B for bold in zsh
  # Change ID: magenta bold unique prefix + grey rest
  local jj_output="${JJ_COLOR_CHANGE_ID}%B${change_shortest}%b${JJ_COLOR_RESET}"
  jj_output+="${JJ_COLOR_CHANGE_REST}${change_rest}${JJ_COLOR_RESET} "

  # Commit ID: cyan bold unique prefix + grey rest
  jj_output+="${JJ_COLOR_COMMIT_ID}%B${commit_shortest}%b${JJ_COLOR_RESET}"
  jj_output+="${JJ_COLOR_COMMIT_REST}${commit_rest}${JJ_COLOR_RESET} "

  # Add empty marker if needed
  if [[ $is_empty == "empty" ]]; then
    jj_output+="${JJ_COLOR_STATUS}(empty) ${JJ_COLOR_RESET}"
  fi

  # Add description in italic (using ANSI escape codes)
  # %{...%} wraps escape codes so zsh doesn't count them in prompt width
  jj_output+="%{\e[3m%}${description}%{\e[23m%}"

  # Get bookmark info
  local bookmark=$(jj log --ignore-working-copy --no-graph --color never -r @ -T 'bookmarks' 2>/dev/null | head -n 1 | tr -d '[:space:]')

  # Build prompt
  local result="$jj_output"

  # Add bookmark if present (magenta and bold)
  if [[ -n $bookmark && $bookmark != "" ]]; then
    result="$result %F{magenta}%B$bookmark%b$JJ_COLOR_RESET"
  fi

  # Get ahead count if we have a bookmark
  if [[ -n $bookmark && $bookmark != "" ]]; then
    local ahead=$(jj log --ignore-working-copy --no-graph --color never -r "$bookmark..@" 2>/dev/null | wc -l)
    if [[ $ahead -gt 1 ]]; then
      result="$result $JJ_COLOR_STATS⇡$((ahead - 1))$JJ_COLOR_RESET"
    fi
  fi

  # Get file stats
  local stats=$(jj diff --ignore-working-copy --stat --color never -r @ 2>/dev/null | tail -n 1)
  if [[ -n $stats ]]; then
    # Parse stats
    local files_changed=$(echo "$stats" | grep -oE '^[0-9]+' | head -n 1)
    local insertions=$(echo "$stats" | grep -oE '[0-9]+ insertion' | grep -oE '^[0-9]+')
    local deletions=$(echo "$stats" | grep -oE '[0-9]+ deletion' | grep -oE '^[0-9]+')

    # Build colored stats: changed=yellow, added=green, removed=red
    local stats_str=""
    [[ -n $files_changed && $files_changed -gt 0 ]] && stats_str="$stats_str %F{yellow}±$files_changed%f"
    [[ -n $insertions && $insertions -gt 0 ]] && stats_str="$stats_str %F{green}+$insertions%f"
    [[ -n $deletions && $deletions -gt 0 ]] && stats_str="$stats_str %F{red}-$deletions%f"

    if [[ -n $stats_str ]]; then
      result="$result$stats_str"
    fi
  fi

  _jj_debug "Worker: final result: $result"
  # Prepend workspace path (separated by newline) so callback can validate
  echo "$workspace"
  echo "$result"
}

# Async callback - receives the result from the worker
_jj_async_callback() {
  local job=$1
  local return_code=$2
  local output=$3

  # Parse output: first line is workspace, rest is the prompt
  local -a lines
  lines=("${(@f)output}")  # Split by newlines
  local worker_workspace="${lines[1]}"
  local prompt_content="${lines[2]}"

  # Get the current workspace (callback runs in main shell, so this is fast)
  local current_workspace=$(jj workspace root --ignore-working-copy 2>/dev/null)

  _jj_debug "Callback: worker workspace='$worker_workspace', current workspace='$current_workspace'"

  # Only update display if we're still in the workspace the worker processed
  if [[ "$worker_workspace" == "$current_workspace" ]]; then
    _jj_debug "Callback: workspaces match, updating display"
    _jj_display=$prompt_content
    _jj_last_workspace=$current_workspace

    _jj_debug "Callback: updated _jj_display='$_jj_display', triggering prompt redraw"
    # Trigger prompt redraw
    zle && zle reset-prompt
  else
    _jj_debug "Callback: workspace changed (worker='$worker_workspace' current='$current_workspace'), discarding stale result"
  fi
}

# Function to show git info when not in jj repo
_prompt_git() {
  # Check if we're in a git repository
  if ! git rev-parse --git-dir &>/dev/null; then
    return
  fi

  # Get current branch name
  local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
  if [[ -z $branch ]]; then
    return
  fi

  # Check for changes (modified, added, deleted, untracked)
  local dirty=""
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null || [[ -n $(git ls-files --others --exclude-standard 2>/dev/null) ]]; then
    dirty="*"
  fi

  # Check for upstream tracking and ahead/behind status
  local arrows=""
  local upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null)
  if [[ -n $upstream ]]; then
    local ahead=$(git rev-list --count @{upstream}..HEAD 2>/dev/null)
    local behind=$(git rev-list --count HEAD..@{upstream} 2>/dev/null)

    [[ $ahead -gt 0 ]] && arrows+="⇡"
    [[ $behind -gt 0 ]] && arrows+="⇣"
  fi

  # Display: branch name and dirty marker in grey, arrows in cyan
  local result=" ${JJ_COLOR_GIT_BRANCH}${branch}${dirty}${JJ_COLOR_RESET}"
  [[ -n $arrows ]] && result+="${JJ_COLOR_GIT_ARROWS}${arrows}${JJ_COLOR_RESET}"
  echo -n "$result"
}

# Main prompt function - displays cached result and triggers async update
prompt_jj() {
  _jj_debug "prompt_jj: called"

  # Check if jj is installed
  if ! command -v jj &>/dev/null; then
    _jj_debug "prompt_jj: jj not found, trying git"
    _prompt_git
    return
  fi

  # Quick check if we're in a jj workspace
  local workspace=$(jj workspace root --ignore-working-copy 2>/dev/null)
  _jj_debug "prompt_jj: workspace=$workspace"

  if [[ -z $workspace ]]; then
    _jj_debug "prompt_jj: not in jj workspace, trying git"
    _jj_display=""
    _jj_last_workspace=""
    _jj_expected_workspace=""
    _prompt_git
    return
  fi

  # If workspace changed, clear cache and expected workspace
  if [[ $workspace != $_jj_last_workspace ]]; then
    _jj_debug "prompt_jj: workspace changed (old='$_jj_last_workspace' new='$workspace'), clearing cache"
    _jj_display=""
    _jj_expected_workspace=""
  fi

  # Always update last workspace
  _jj_last_workspace=$workspace

  # Display cached result (may be empty on first run)
  _jj_debug "prompt_jj: displaying cached result: $_jj_display"
  echo -n "$_jj_display"
}

# Precmd hook - triggers async update before each prompt
_jj_precmd() {
  _jj_debug "precmd: called"

  # Check if in jj workspace
  local workspace=$(jj workspace root --ignore-working-copy 2>/dev/null)
  _jj_debug "precmd: workspace=$workspace"

  if [[ -z $workspace ]]; then
    _jj_debug "precmd: not in jj workspace, skipping async job"
    _jj_expected_workspace=""
    return
  fi

  # Store the workspace we're expecting results for
  _jj_expected_workspace=$workspace

  # Start async job
  _jj_debug "precmd: starting async job with workspace=$workspace"
  async_job jj_worker _jj_async_worker "$workspace"
}

# Initialize async
_jj_debug "Initializing async worker"
async_init
async_start_worker jj_worker -n
async_register_callback jj_worker _jj_async_callback
_jj_debug "Async worker initialized"

# Add precmd hook
_jj_debug "Adding precmd hook"
autoload -Uz add-zsh-hook
add-zsh-hook precmd _jj_precmd
_jj_debug "Precmd hook added"

# Setup function - call this to use the default prompt
jj_prompt_setup() {
  # Use JJ_PROMPT_CHAR environment variable, default to ➜
  typeset -g JJ_PROMPT_CHAR="${JJ_PROMPT_CHAR:-➜}"

  # %(1j.text.) shows text if there's at least 1 background job
  # %j shows the number of jobs
  # %(?.green.red) shows green if last command succeeded (exit 0), red otherwise
  PROMPT='%F{blue}%~%f$(prompt_jj)%(1j. %F{yellow}[%j]%f.)
%(?.%F{green}.%F{red})${JJ_PROMPT_CHAR}%f '
}

_jj_debug "jj-zsh-prompt loaded successfully"

# Auto-setup if JJ_PROMPT_AUTO_SETUP is set
if [[ ${JJ_PROMPT_AUTO_SETUP:-1} -eq 1 ]]; then
  jj_prompt_setup
fi
