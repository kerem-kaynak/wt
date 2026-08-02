# wt — plain-git worktrees under $WT_ROOT/<repo>/. No daemons involved.
#
#   wt <new-branch> [base]   create branch off base (default: origin's default branch)
#   wt -b <branch>           check out an existing branch
#   wt -p <n>                check out PR #n (needs the GitHub CLI)
#   wt ls | wt cd <match> | wt log <match> | wt main | wt rm <match>
#
# After creating a worktree, wt runs the repo's setup script in the background
# (log: <worktree>.setup.log, desktop notification on finish). The script is
# $WT_SETUP (resolved relative to the repo root) if that file exists, else
# .wt-setup.sh at the repo root; if neither exists, wt warns and leaves the
# worktree bare. The script runs with the new worktree as cwd and the main
# checkout's path as $1, so it can copy over untracked files (env files,
# local settings) and install dependencies.
#
# Source this file from your .zshrc or .bashrc. Works in zsh and bash.
# Sourcing also registers tab completion: subcommands for the first word,
# worktree names after cd/log/rm (zsh: compinit must have run first).
# Config: WT_ROOT (default ~/worktrees), WT_SETUP (default .wt-setup.sh).
# shellcheck shell=bash

wt() {
  # NB: never name a local "path" — zsh ties it to PATH, so localizing it
  # empties PATH inside the function.
  local wtroot root repo dir branch base start hook log runner
  case "$1" in
    ""|-h|--help)
      cat >&2 <<'EOF'
usage:
  wt <new-branch> [base]   create a worktree on a new branch (base: origin's default)
  wt -b <branch>           create a worktree for an existing branch
  wt -p <n>                create a worktree for PR #n (needs the GitHub CLI)
  wt ls                    list this repo's worktrees
  wt cd <match>            jump into a worktree (substring match, tab-completes)
  wt main                  jump back to the main checkout
  wt log <match>           follow a worktree's setup log
  wt rm <match>            remove a worktree and delete its branch
EOF
      return 1 ;;
  esac
  wtroot="${WT_ROOT:-$HOME/worktrees}"
  root="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")" || return 1
  repo="$(basename "$root")"
  case "$1" in
    ls)
      git worktree list
      echo "wt: jump in with wt cd <match> (tab-completes)" >&2 ;;
    main) cd "$root" || return 1 ;;
    cd|log|rm)
      if [ -z "$2" ]; then echo "usage: wt $1 <match>" >&2; return 1; fi
      dir=$(git worktree list --porcelain | awk '/^worktree /{sub(/^worktree /,""); print}' | grep -i -- "$2" | head -1)
      if [ -z "$dir" ]; then echo "wt: no worktree matching '$2'" >&2; return 1; fi
      case "$1" in
        cd) cd "$dir" || return 1 ;;
        log)
          if [ ! -f "$dir.setup.log" ]; then echo "wt: no setup log for $dir" >&2; return 1; fi
          tail -n 40 -f "$dir.setup.log" ;;
        rm)
          if [ -f "$dir.setup.pid" ] && kill -0 "$(cat "$dir.setup.pid")" 2>/dev/null; then
            echo "wt: setup still running for $dir — watch: wt log $2, abort: kill $(cat "$dir.setup.pid")" >&2
            return 1
          fi
          branch=$(git -C "$dir" branch --show-current)
          # step out first if we're standing in the worktree being removed
          # (compare physical paths — git prints canonicalized ones)
          case "$(pwd -P)/" in "$dir"/*) cd "$root" || return 1 ;; esac
          # remove refuses on uncommitted changes, guarding the branch -D
          git worktree remove "$dir" &&
            { [ -z "$branch" ] || git branch -D "$branch"; } &&
            rm -f -- "$dir.setup.log" "$dir.setup.pid" ;;
      esac ;;
    *)
      mkdir -p "$wtroot/$repo"
      if [ "$1" = -p ]; then
        if ! command -v gh >/dev/null 2>&1; then echo "wt: -p needs the GitHub CLI (gh)" >&2; return 1; fi
        dir="$wtroot/$repo/pr-$2"
        git worktree add --detach "$dir" || return 1
        (cd "$dir" && gh pr checkout "$2") || return 1
      elif [ "$1" = -b ]; then
        dir="$wtroot/$repo/${2//\//-}"
        git fetch -q origin 2>/dev/null
        git worktree add "$dir" "$2" || return 1
      else
        base="${2:-$(git symbolic-ref -q --short refs/remotes/origin/HEAD)}"
        base="${base#origin/}"; base="${base:-main}"
        git fetch -q origin "$base" 2>/dev/null
        if git rev-parse -q --verify "origin/$base" >/dev/null; then start="origin/$base"; else start="$base"; fi
        dir="$wtroot/$repo/${1//\//-}"
        git worktree add --no-track -b "$1" "$dir" "$start" || return 1
      fi

      hook=""
      if [ -n "$WT_SETUP" ]; then
        case "$WT_SETUP" in /*) [ -f "$WT_SETUP" ] && hook="$WT_SETUP" ;; *) [ -f "$root/$WT_SETUP" ] && hook="$root/$WT_SETUP" ;; esac
      fi
      [ -z "$hook" ] && [ -f "$root/.wt-setup.sh" ] && hook="$root/.wt-setup.sh"
      if [ -z "$hook" ]; then
        echo "wt: warning: no setup script (${WT_SETUP:-.wt-setup.sh}) — worktree created without setup" >&2
        cd "$dir" && echo "wt: $(git branch --show-current) @ $dir"
        return
      fi

      log="$dir.setup.log"
      # shellcheck disable=SC2016  # the runner is a template for `sh -c`; $1-$4 expand there
      runner='
        cd "$3" || exit 1
        "$4" "$1"
        rc=$?
        if [ $rc -eq 0 ]; then msg="worktree setup done"; else msg="worktree setup FAILED (exit $rc)"; fi
        printf "\n== wt: %s ==\n" "$msg"
        if command -v osascript >/dev/null 2>&1; then
          osascript -e "display notification \"$2\" with title \"$msg\"" >/dev/null 2>&1
        elif command -v notify-send >/dev/null 2>&1; then
          notify-send "$msg" "$2" >/dev/null 2>&1
        fi
        rm -f "$3.setup.pid"
        exit $rc
      '
      # spawn from a subshell so the interactive shell never job-controls the
      # setup job — no "[1] 1234"/"done" notices in the prompt, nothing to disown
      ( nohup sh -c "$runner" wt-setup "$root" "$(basename "$dir")" "$dir" "$hook" > "$log" 2>&1 & echo $! > "$dir.setup.pid" )
      cd "$dir" && echo "wt: $(git branch --show-current) @ $dir  (setup in background — wt log $(basename "$dir"))"
      ;;
  esac
}

# Completion candidates for wt cd/log/rm: this repo's worktree dir names.
_wt_worktrees() {
  git worktree list --porcelain 2>/dev/null |
    awk '/^worktree /{sub(/.*\//,""); print}'
}

if [ -n "$ZSH_VERSION" ]; then
  # CURRENT and words are set by zsh's completion system (1-based arrays)
  # shellcheck disable=SC2154,SC2207
  _wt() {
    local -a names
    if [ "$CURRENT" -eq 2 ]; then
      compadd -- ls cd main log rm -b -p
    elif [ "$CURRENT" -eq 3 ]; then
      case "${words[2]}" in
        cd|log|rm)
          names=($(_wt_worktrees))
          compadd -- "${names[@]}" ;;
      esac
    fi
  }
  # compdef appears once compinit has run; without it zsh has no completion
  if command -v compdef >/dev/null 2>&1; then compdef _wt wt; fi
elif [ -n "$BASH_VERSION" ]; then
  _wt_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [ "$COMP_CWORD" -eq 1 ]; then
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "ls cd main log rm -b -p" -- "$cur"))
    elif [ "$COMP_CWORD" -eq 2 ]; then
      case "${COMP_WORDS[1]}" in
        cd|log|rm)
          # shellcheck disable=SC2207
          COMPREPLY=($(compgen -W "$(_wt_worktrees)" -- "$cur")) ;;
      esac
    fi
  }
  complete -F _wt_complete wt
fi
