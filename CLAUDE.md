# Working in this repo

These files are the source of truth for real, live files in `$HOME`. `./bootstrap.sh`
rsyncs the repo over the home directory.

## Never apply changes to `$HOME`

Make changes in the working tree only. Applying them is the user's step, always — even
when the task description says to run `./bootstrap.sh`. Do not run:

- `./bootstrap.sh` (with or without `--force`)
- `./brew.sh`, `./.macos`
- any `rsync` into `~` that is not a dry run

`--force` skips the fzf review, which is the user's approval gate. Never use it.

The expected way to finish a change is a dry run — reuse the exclude list from
`showDiff()` in `bootstrap.sh` with `--dry-run --itemize-changes`, report the files
that would change, and stop there for the user to apply.

## Editing

- Edit files in the repo. Never edit the installed copy in `$HOME`.
- Verifying against the live shell is fine as long as it is read-only (e.g. sourcing a
  changed rc file in a throwaway subshell or pty). Don't write to `$HOME` to test.
- Commit when asked, with a conventional-commit prefix (`fix:`/`feat:`/`ci:`/`chore:`).
  Commits are SSH-signed. Don't push unless asked.

## Note

`CLAUDE.md` is excluded from the rsync in `bootstrap.sh`, like `README.md` — it is repo
documentation and must not land in `$HOME`, where it would be picked up as user-level
context.
