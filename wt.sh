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
# Config: WT_ROOT (default ~/worktrees), WT_SETUP (default .wt-setup.sh).
# shellcheck shell=bash

wt() {
  # NB: never name a local "path" — zsh ties it to PATH, so localizing it
  # empties PATH inside the function.
  local wtroot root repo dir branch base start hook log runner
  wtroot="${WT_ROOT:-$HOME/worktrees}"
  root="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")" || return 1
  repo="$(basename "$root")"
  case "$1" in
    ""|-h|--help)
      echo "usage: wt <new-branch> [base] | wt -b <branch> | wt -p <pr> | wt ls | wt cd <match> | wt log <match> | wt main | wt rm <match>" >&2
      return 1 ;;
    ls) git worktree list ;;
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
