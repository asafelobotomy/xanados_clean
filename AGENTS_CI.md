# AGENTS_CI.md

> **Shell Script Linting & Continuous Integration**  
> *This file documents the use of ShellCheck for linting and GitHub Actions for
automated validation of `system_maint.sh`.*

---

## 🧪 Script Linting

- **`shellcheck`**  
  A static analysis tool for shell scripts. It identifies syntax errors,
  stylistic issues, and unsafe practices in POSIX/Bash scripts.
  *Used to ensure the long-term maintainability and security of*
  `system_maint.sh`.

### Usage

To manually check your script:

```bash
shellcheck system_maint.sh
```

---

## GitHub Actions

This repository includes workflows for ShellCheck, Markdown linting, Proselint,
and YAML linting.
