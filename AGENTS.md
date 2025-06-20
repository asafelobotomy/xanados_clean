# AGENTS Repository Guide

This repository provides documentation and examples for the
`xanadOS_clean.sh` script. The instructions below apply to all contributions.

The repository does not contain the `xanadOS_clean.sh` script itself;
use these files as a reference for your own copy.

## Documentation Layout

- `AGENTS_CI.md` &ndash; explains ShellCheck and GitHub Actions linting.
- `AGENTS_SYSTEM.md` &ndash; lists required system utilities.
- `AGENTS_SECURITY.md` &ndash; describes security and backup tools.

Refer to these files if you need details about dependencies or CI features.

## Contribution Workflow

1. **Create small commits** using present-tense summaries
   (e.g. `Add root AGENTS guide`).
2. **Include a brief body** if the commit needs more context.
3. **Run relevant checks** before committing:
   - If `xanadOS_clean.sh` exists, execute `shellcheck xanadOS_clean.sh`.
4. **Open a Pull Request** summarising what changed and what checks were run.

## Pull Request Body

- State the motivation for the change.
- Mention any tests or ShellCheck runs.
- Reference the AGENTS files when appropriate.

---

This `AGENTS.md` is the entry point for instructions.
Other AGENTS files provide additional context.
