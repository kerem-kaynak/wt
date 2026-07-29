# Contributing

wt is deliberately small: one sourceable shell function, no dependencies
beyond git. Bug fixes and small improvements are welcome. For anything that
grows the surface area (new commands, config options, dependencies), please
open an issue first so we can talk it over before you spend time on it.

## Checks

Both run in CI (Linux and macOS) on every push and PR:

```sh
shellcheck wt.sh examples/wt-setup.sh
bats test                    # needs bats-core; tests run wt under bash
WT_TEST_SHELL=zsh bats test  # ...and under zsh
```

`brew install shellcheck bats-core` (or your package manager's equivalents)
gets you both. Keep `wt.sh` compatible with bash and zsh, and keep ShellCheck
clean; use a targeted `# shellcheck disable=` with a reason if a finding is
intentional.

## Releasing (maintainers)

Tag and push (`git tag vX.Y.Z && git push origin vX.Y.Z`), create a GitHub
release from the tag, then bump the formula in
[kerem-kaynak/homebrew-tap](https://github.com/kerem-kaynak/homebrew-tap).
