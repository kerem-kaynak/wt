# wt

**Git worktrees, ready for your agents. One shell function, no fluff.**

`wt feature-x` creates a worktree under `~/worktrees/<repo>/`, drops you into
it, and runs your repo's setup script in the background — env files copied,
dependencies installing — so you (or the agent you're about to unleash) start
on a branch that already works.

![demo](demo.gif)

## Why

Worktrees are the right way to run parallel work: a branch per task, a branch
per agent, no stashing, no waiting for `node_modules` to reshuffle. But raw
git makes each one a chore:

```sh
git worktree add ../myrepo-feature-x -b feature-x
cd ../myrepo-feature-x
cp ../myrepo/.env .
cp ../myrepo/apps/api/.env.local apps/api/
npm install        # ...wait
```

With wt:

```sh
wt feature-x
```

No daemon, no binary, no config file — one sourceable shell function you can
read before trusting.

## Install

```sh
brew install kerem-kaynak/tap/wt
```

then add the line brew prints to your `~/.zshrc` or `~/.bashrc` (wt has to be
sourced — it `cd`s your shell, which no binary can do). Without brew:

```sh
git clone https://github.com/kerem-kaynak/wt.git ~/wt
echo 'source ~/wt/wt.sh' >> ~/.zshrc
```

Requires git; the GitHub CLI (`gh`) only for `wt -p`. Works in zsh and bash.

## Usage

Run it from anywhere inside a repo (including from another worktree):

```
wt <new-branch> [base]   create a branch off base (default: origin's default branch)
wt -b <branch>           check out an existing branch
wt -p <n>                check out PR #n
wt ls                    list this repo's worktrees
wt cd <match>            jump to the worktree matching <match> (substring, case-insensitive)
wt main                  jump back to the main checkout
wt log <match>           follow a worktree's setup log
wt rm <match>            remove a worktree and delete its branch
```

`wt rm` is careful: it refuses while setup is still running, `git worktree
remove` refuses on uncommitted changes, and the branch is only deleted after
the worktree is gone.

## The setup script

A fresh worktree is a clean checkout — no `.env` files, no `node_modules`,
none of the untracked local files your app needs. Your setup script is where
your repo fixes that, and writing it is your job — `wt` just runs it.

After creating a worktree, `wt` runs the first of these that exists, in the
background:

1. the path in `$WT_SETUP`, resolved relative to the repo root
2. `.wt-setup.sh` at the repo root

If neither exists, `wt` warns and leaves the worktree bare.

The script runs with the new worktree as its working directory and one
argument: the path to the main checkout. Typical job: copy untracked local
files from the main checkout, then install dependencies. It logs to
`<worktree>.setup.log` next to the worktree, and you get a desktop
notification (macOS or Linux) when it finishes or fails. Watch it live with
`wt log <match>`.

Start from [`examples/wt-setup.sh`](examples/wt-setup.sh) — or don't write it
at all:

## Let your agent write the setup script

wt ships with a [Claude Code skill](skills/wt-setup-script/SKILL.md). Copy it
into `~/.claude/skills/` (or your repo's `.claude/skills/`) and ask your agent
to "set up wt for this repo" — it finds the env files and install steps your
repo needs and writes `.wt-setup.sh` for you:

```sh
cp -r "$(brew --prefix)/share/wt/skills/wt-setup-script" ~/.claude/skills/
```

## Configuration

Two environment variables, set in your shell rc next to the `source` line:

| Variable | What | Default |
| --- | --- | --- |
| `WT_ROOT` | where worktrees live | `~/worktrees` |
| `WT_SETUP` | setup script path, relative to the repo root | `.wt-setup.sh` |

Worktrees are named after the branch with `/` flattened to `-`
(`feat/login` → `~/worktrees/myrepo/feat-login`), PR checkouts as `pr-<n>`.

## License

MIT
