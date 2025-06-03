# AGENTS.md

## 🤖 Codex Chat GPT Agent: Bash Script Assistant

### Overview

This GitHub-integrated AI agent assists developers, SREs, and DevOps engineers with writing, reviewing, debugging, and optimizing **Bash scripts** directly within your repository. It is part of the AI tooling ecosystem designed to support infrastructure automation and scripting tasks via natural language interaction.

---

### 🔧 Capabilities

- Generate shell scripts from natural language descriptions
- Debug broken scripts and suggest minimal, POSIX-compliant fixes
- Annotate and explain Bash lines, blocks, or full scripts
- Improve script reliability with idiomatic practices:
  - `set -euo pipefail`
  - Quoting and input validation
  - Meaningful exit codes
- Recommend usage of standard tooling (`find`, `xargs`, `awk`, etc.)
- Create GitHub Actions-compatible shell steps

---

### 🔐 Security and Compliance

- Applies hardening guidelines aligned with CIS Benchmarks and ShellCheck suggestions
- Detects unsafe practices like:
  - `eval` misuse
  - Unquoted variable expansion
  - Unsafe file operations
- Encourages use of `mktemp`, `read -r`, and strict IFS control
- Warns against insecure download-execute patterns

---

### ✅ GitHub Use Cases

- **Script development in PRs:** Auto-generate or review shell scripts in feature branches
- **CI/CD pipelines:** Write or improve `bash` blocks in GitHub Actions workflows (`.github/workflows/*.yml`)
- **Automation hooks:** Create shell scripts for GitHub webhooks, pre-commit, or post-merge hooks
- **Documentation support:** Embed examples in `README.md` or `/docs` with annotated Bash code

---

### 🧠 Prompt Examples

Use the agent in issues, pull requests, or discussions like so:

- “Create a Bash script that backs up `/etc` to S3 and logs output.”
- “Explain what this snippet does: `while read -r line; do echo "$line"; done < file`”
- “Make this GitHub Action shell step secure and POSIX-compliant.”
- “Why is this script breaking on filenames with spaces?”

---

### ⚠️ Limitations

- This agent does **not execute code** — all suggestions should be reviewed and tested locally or in CI
- Assumes Linux shell environment unless specified (`#!/bin/bash`)
- Cannot infer repository secrets or GitHub context unless provided explicitly (e.g., via workflow inputs)

---

### 🧩 Integration Tips

- **Link Bash files in issues** using:
  ```markdown
  [script.sh](./scripts/script.sh)
