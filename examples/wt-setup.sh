#!/usr/bin/env bash
# Example wt setup script.
#
# wt runs this in the background right after creating a worktree, with the
# fresh worktree as the working directory and one argument: the path to the
# main checkout. Save it as an executable .wt-setup.sh at your repo's root
# (or anywhere, with WT_SETUP pointing at it).
set -e

src="$1" # the main checkout — the place your untracked local files live

# Copy over files git doesn't track but the app needs to run. Tracked files
# (like .env.example) are skipped so the worktree keeps its branch's version.
files=(
  .env
  .env.local
  .claude/settings.local.json
)
for f in "${files[@]}"; do
  [ -f "$src/$f" ] || continue
  if git -C "$src" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    continue
  fi
  mkdir -p "$(dirname "$f")"
  cp "$src/$f" "$f"
  echo "copied $f"
done

# Or sweep a whole directory of untracked files instead of listing them:
# git -C "$src" ls-files --others -z -- .claude | while IFS= read -r -d '' f; do
#   mkdir -p "$(dirname "$f")" && cp "$src/$f" "$f" && echo "copied $f"
# done

# Install dependencies so the worktree is ready to run when the notification
# fires. Swap for whatever your repo uses.
npm install
