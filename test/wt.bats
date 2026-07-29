#!/usr/bin/env bats
# Tests for wt. Run from the repo root:
#
#   bats test                    # exercises wt under bash
#   WT_TEST_SHELL=zsh bats test  # exercises wt under zsh
#
# Each test gets a throwaway repo and WT_ROOT under mktemp.

WT_SH="$BATS_TEST_DIRNAME/../wt.sh"

setup() {
  TMP="$(mktemp -d)"
  TMP="$(cd "$TMP" && pwd -P)" # git prints physical paths; compare apples to apples
  export WT_ROOT="$TMP/worktrees"
  REPO="$TMP/repo"
  git init -q -b main "$REPO"
  git -C "$REPO" -c user.name=wt -c user.email=wt@test commit -q --allow-empty -m init
}

teardown() {
  rm -rf "$TMP"
}

# Run $1 in the shell under test, with wt sourced and cwd at the main checkout.
wt_run() {
  run "${WT_TEST_SHELL:-bash}" -c "source '$WT_SH'; cd '$REPO' || exit 1; $1"
}

add_setup_script() {
  printf '%s\n' "$1" > "$REPO/.wt-setup.sh"
  chmod +x "$REPO/.wt-setup.sh"
}

# Poll up to ~5s for a file to appear (background setup is asynchronous).
wait_for() {
  for _ in $(seq 50); do
    [ -e "$1" ] && return 0
    sleep 0.1
  done
  return 1
}

@test "wt <branch> creates a worktree and cds into it" {
  wt_run 'wt feature >/dev/null 2>&1; pwd; git branch --show-current'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$WT_ROOT/repo/feature" ]
  [ "${lines[1]}" = "feature" ]
}

@test "branch slashes are flattened in the worktree dir" {
  wt_run 'wt feat/login >/dev/null 2>&1; pwd; git branch --show-current'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$WT_ROOT/repo/feat-login" ]
  [ "${lines[1]}" = "feat/login" ]
}

@test "wt -b checks out an existing branch" {
  git -C "$REPO" branch other
  wt_run 'wt -b other >/dev/null 2>&1; pwd; git branch --show-current'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$WT_ROOT/repo/other" ]
  [ "${lines[1]}" = "other" ]
}

@test "setup script runs in background: worktree cwd, main checkout as \$1, logged" {
  add_setup_script '#!/bin/sh
echo "main checkout: $1"
touch setup-ran'
  wt_run 'wt withsetup >/dev/null 2>&1'
  [ "$status" -eq 0 ]
  wait_for "$WT_ROOT/repo/withsetup/setup-ran"
  grep -q "main checkout: $REPO" "$WT_ROOT/repo/withsetup.setup.log"
}

@test "no setup script: warns but still creates the worktree" {
  wt_run 'wt bare'
  [ "$status" -eq 0 ]
  [[ "$output" == *"no setup script"* ]]
  [ -d "$WT_ROOT/repo/bare" ]
}

@test "wt main returns to the main checkout" {
  wt_run 'wt feature >/dev/null 2>&1; wt main; pwd'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$REPO" ]
}

@test "wt cd matches case-insensitive substrings" {
  wt_run 'wt feature-x >/dev/null 2>&1; wt main; wt cd FEATURE-X; pwd'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$WT_ROOT/repo/feature-x" ]
}

@test "wt cd without a match argument errors" {
  wt_run 'wt cd'
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage: wt cd <match>"* ]]
}

@test "wt cd with no matching worktree errors" {
  wt_run 'wt cd nope'
  [ "$status" -eq 1 ]
  [[ "$output" == *"no worktree matching"* ]]
}

@test "wt rm removes the worktree, deletes the branch, steps out" {
  wt_run 'wt gone >/dev/null 2>&1; wt rm gone >/dev/null; pwd'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$REPO" ]
  [ ! -d "$WT_ROOT/repo/gone" ]
  run git -C "$REPO" rev-parse -q --verify refs/heads/gone
  [ "$status" -ne 0 ]
}

@test "wt rm refuses while setup is still running" {
  add_setup_script '#!/bin/sh
sleep 5'
  wt_run 'wt busy >/dev/null 2>&1; wt rm busy'
  [ "$status" -eq 1 ]
  [[ "$output" == *"setup still running"* ]]
  [ -d "$WT_ROOT/repo/busy" ]
}
