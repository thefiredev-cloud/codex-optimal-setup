# codex-optimal-setup

Sanitized export of a Codex CLI setup: scripts, hooks, and a config template.

## What’s included
- `.codex/bin/*` — helper scripts used during Codex sessions
- `.codex/hooks/*` — optional helpers (diagnostics, commit drafting, statusline, etc.)
- `.codex/README.md` — usage notes for the helpers
- `config.example.toml` — template with placeholders (no secrets)

## What’s intentionally excluded
- `.codex/config.toml` — contains real tokens; use the example instead
- `.codex/auth.json`, `.codex/history.jsonl`, `.codex/log/`, `.codex/sessions/`

## Setup
1. Copy the `.codex` folder to your home directory (or symlink it):
   ```bash
   rsync -a .codex/ ~/.codex/
   ```
2. Create your real config from the template:
   ```bash
   cp config.example.toml ~/.codex/config.toml
   ```
3. Fill in tokens in `~/.codex/config.toml` or set them as environment variables.

## Safety
This repo avoids committing any secrets. Do not add `~/.codex/config.toml` or `~/.codex/auth.json` to source control.
