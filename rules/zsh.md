## Shell: zsh rules for the Bash tool

The Bash tool runs the login shell of the user. If that shell is zsh, follow the rules below.
To check, look at the `Shell:` line of the environment, or run `echo $0`. If the shell is bash,
ignore this section.

Write commands so they work the first time.

- Prefer the Grep, Glob, and Read tools over shell `grep`, `find`, `ls`, and `cat`.
- Quote every pattern that a program must receive as text: `--include='*.ts'`,
  `-name '*.py'`, `'foo[extra]'`, `'https://host/path?a=1&b=2'`.
- Quote arguments that contain `*`, `?`, `[`, `]`, `^`, `~`, or `#`.
- If a glob must expand and can match nothing, add the `(N)` qualifier: `ls *.log(N)`.
- Do not rely on word splitting of an unquoted `$var`. zsh does not split it. Use an array
  or `${=var}`.
- Arrays start at index 1. `shopt`, `read -p`, `${arr[@]:0:1}`, and `declare -A` are
  bash-only.
- If a command needs bash semantics, run it as `bash -c '...'` or write a script with
  `#!/usr/bin/env bash`.
