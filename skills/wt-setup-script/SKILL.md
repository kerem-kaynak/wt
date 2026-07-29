---
name: wt-setup-script
description: Write or update a repo's .wt-setup.sh worktree setup script for the wt tool. Use when the user asks to set up wt for a repo, create a worktree setup script, or reports that fresh worktrees are missing env files, local settings, or dependencies.
---

# Write a wt setup script

`wt` runs this script in the background right after creating a git worktree,
with the **fresh worktree as the working directory** and **one argument: the
path to the main checkout**. Its job is to make the worktree runnable: copy
over local files git doesn't track, then install dependencies. stdout/stderr
go to a log the user can follow with `wt log`; a non-zero exit is reported as
a failed setup, so `set -e` is appropriate.

## Steps

1. **Find the local files the app needs but git doesn't provide.** In the main
   checkout, look for untracked-or-ignored files that a clean checkout would
   miss: env files (`.env`, `.env.local`, per-app variants), personal agent
   instructions (`CLAUDE.local.md`, `AGENTS.local.md`), editor/agent settings
   (`.claude/settings.local.json`), certificates, etc. Check `.gitignore` and
   `git status --ignored` for candidates, and per-app subdirectories in
   monorepos.

2. **Find how dependencies are installed.** Prefer what the repo itself
   advertises: a `Makefile` install target, a lockfile (`package-lock.json` →
   `npm ci`, `pnpm-lock.yaml` → `pnpm install`, `poetry.lock` →
   `poetry install`, ...), or README instructions. In monorepos, install
   wherever the user actually works, not necessarily everywhere.

3. **Write the script** to `.wt-setup.sh` at the repo root (or the path in the
   user's `WT_SETUP`, if they use one). Rules:
   - `$1` is the main checkout: copy **from** `"$1"`, **into** the current
     directory.
   - Never copy a file that git tracks — the worktree's checked-out version
     must win. Guard with
     `git -C "$1" ls-files --error-unmatch "$f" >/dev/null 2>&1 && continue`.
   - `mkdir -p` parent directories before copying; echo each copied file so
     the log shows progress.
   - Keep it idempotent and non-interactive: no prompts, no sudo.

4. **Make it executable and check it's ignored.** `chmod +x .wt-setup.sh`, and
   if the user doesn't want it committed, ensure it's in `.gitignore` (a
   tracked script is fine too — teams often want to share it).

5. **Test it.** Create a throwaway worktree with `wt <branch>`, follow
   `wt log <branch>`, confirm the copied files and install succeeded, then
   `wt rm <branch>`. Without `wt` available, at minimum run the script by hand
   from an empty checkout and `bash -n` it.

A complete example lives at `examples/wt-setup.sh` in the wt repo.
