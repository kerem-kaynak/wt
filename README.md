# wt

[![CI](https://github.com/kerem-kaynak/wt/actions/workflows/ci.yml/badge.svg)](https://github.com/kerem-kaynak/wt/actions/workflows/ci.yml)

**Git worktrees, ready for your agents. One shell function, no fluff.**

`wt feature-x` creates a worktree under `~/worktrees/<repo>/`, drops you into
it, and runs your repo's setup script in the background: env files copied,
dependencies installing. You (or the agent you're about to work with) start on
a branch that already works.

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

No daemon, no binary, no config file. One sourceable shell function you can
read before trusting.

## Install

```sh
brew install kerem-kaynak/tap/wt
```

then add the line brew prints to your `~/.zshrc` or `~/.bashrc` (wt has to be
sourced, since it `cd`s your shell, which no binary can do). Without brew:

```sh
git clone https://github.com/kerem-kaynak/wt.git ~/wt
echo 'source ~/wt/wt.sh' >> ~/.zshrc
```

Requires git; the GitHub CLI (`gh`) only for `wt -p`. Works in zsh and bash.

## Set up

Two optional environment variables, set in your shell rc next to the `source`
line:

| Variable | What | Default |
| --- | --- | --- |
| `WT_ROOT` | where worktrees live | `~/worktrees` |
| `WT_SETUP` | setup script path, relative to the repo root | `.wt-setup.sh` |

Then give each repo a setup script, so its worktrees come up ready to run:

- **Write it yourself.** Save an executable `.wt-setup.sh` at the repo root
  (or wherever `WT_SETUP` points). Start from
  [`examples/wt-setup.sh`](examples/wt-setup.sh).
- **Or let your agent write it.** wt ships with a
  [Claude Code skill](skills/wt-setup-script/SKILL.md). Copy it into
  `~/.claude/skills/` (or your repo's `.claude/skills/`) and ask your agent
  to "set up wt for this repo". It finds the env files and install steps your
  repo needs and writes `.wt-setup.sh` for you.

  ```sh
  cp -r "$(brew --prefix)/share/wt/skills/wt-setup-script" ~/.claude/skills/
  ```

Repos without a setup script still work: `wt` warns and leaves the worktree
bare.

## The setup script

A fresh worktree is a clean checkout: no `.env` files, no `node_modules`,
none of the untracked local files your app needs. Your setup script is where
your repo fixes that, and writing it is your job; `wt` just runs it.

After creating a worktree, `wt` runs the first of these that exists, in the
background:

1. the path in `$WT_SETUP`, resolved relative to the repo root
2. `.wt-setup.sh` at the repo root

The script runs with the new worktree as its working directory and one
argument: the path to the main checkout. Typical job: copy untracked local
files from the main checkout, then install dependencies. It logs to
`<worktree>.setup.log` next to the worktree, and you get a desktop
notification (macOS or Linux) when it finishes or fails. Watch it live with
`wt log <match>`.

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

Worktrees are named after the branch with `/` flattened to `-`
(`feat/login` becomes `~/worktrees/myrepo/feat-login`), PR checkouts as
`pr-<n>`.

## Contributing

Bug fixes and small improvements welcome; open an issue first for anything
bigger. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to run the tests and
ShellCheck.

## How it compares

Good worktree managers exist; wt's niche is being the smallest one whose
worktrees come up ready to work in. Against the tools you'd most likely
evaluate instead:

- **[gwq](https://github.com/d-kuro/gwq)** (Go) manages worktrees across all
  your repos ghq-style, with a fuzzy finder, tmux integration, a status
  dashboard, and `copy_files`/`setup_commands` hooks in TOML. As a binary it
  can't move your shell: `gwq cd` opens a *new* shell by default, and
  changing the current one means enabling its shell-integration layer.
- **[phantom](https://github.com/aku11i/phantom)** (Node) covers post-create
  file copying and commands via `phantom.config.json`, plus fzf, tmux, and
  an MCP server so agents can drive it. You enter worktrees through a
  subshell (`phantom shell`) rather than a `cd`.
- **[wtp](https://github.com/satococoa/wtp)** (Go) is the closest in spirit:
  `.wtp.yml` hooks copy `.env` files, symlink `node_modules`, and run
  installs after create. Navigation works once you add
  `eval "$(wtp shell-init zsh)"` to your rc.
- **[Worktrunk](https://worktrunk.dev)** (Rust; also installs as `wt`) goes
  much further: an agent per worktree, LLM commit messages, CI status in
  `wt list`, a one-command squash-merge flow. A full workbench, with the
  footprint of one.

Two deliberate differences:

- **wt is the shell integration, not a binary behind one.** A child process
  can't `cd` its parent shell, which is why each tool above ships a wrapper
  function, eval hook, or subshell on top of the binary. wt skips the
  binary: it's ~100 sourced lines, so `wt feature-x` lands your actual
  shell in the new worktree. And instead of a TOML/JSON/YAML schema,
  configuration is two environment variables and one script.
- **Setup never blocks your prompt.** gwq, phantom, and wtp run their
  post-create hooks in the foreground: creation finishes when
  `npm install` does. wt backgrounds the setup script, logs to
  `<worktree>.setup.log`, and notifies you when it's done, so you (or your
  agent) start working immediately. And because setup is a plain script
  rather than config keys, it can do anything your repo needs. wt even
  ships a [Claude Code skill](skills/wt-setup-script/SKILL.md) that
  inspects your repo and writes the script for you.

## License

MIT
