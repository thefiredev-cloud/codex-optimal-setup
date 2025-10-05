# Codex Global Setup (ported from Claude Code optimal setup)

This folder mirrors key pieces of your Claude Code configuration for use with Codex CLI. Hooks here are optional helpers you can call manually during tasks.

## Contents

- `hooks/pre_tool_validation.js` — Validate risky bash/edit inputs and warn/block common mistakes.
- `hooks/ide_diagnostics.js` — If the project has ESLint/TypeScript configured, run them after edits.
- `hooks/git_commit.js` — Create a semantic commit (do not auto-commit; suggested usage only).
- `hooks/context_injector.js` — Emit extra context (git branch/status, project hints) from a given cwd.
- `hooks/notification_sound.js` — Play a completion sound cross‑platform.
- `hooks/statusline.sh` — Render a compact status line when given JSON input.
- `hooks/agent-control.sh` — Simple flag‑based on/off control for agents (informational here).
- `hooks/session-start.sh` — Print useful context at the start/resume of a session.

## Usage Examples

Run diagnostics (skip if not configured):

```bash
node ~/.codex/hooks/ide_diagnostics.js <<'JSON'
{ "tool_input": { "file_path": "src/index.ts" }, "cwd": "." }
JSON
```

Validate a bash command before running (non-blocking in Codex by default):

```bash
node ~/.codex/hooks/pre_tool_validation.js <<'JSON'
{ "tool_name": "Bash", "tool_input": { "command": "rm -rf /" } }
JSON
```

Draft a semantic commit after diagnostics:

```bash
node ~/.codex/hooks/git_commit.js <<'JSON'
{ "tool_input": {}, "cwd": "." }
JSON
```

Render statusline (example minimal payload):

```bash
printf '%s' '{"model": {"display_name": "Codex"}, "workspace": {"current_dir": "."}, "cost": {"total_api_duration_ms": 0, "total_cost_usd": 0}}' \
  | bash ~/.codex/hooks/statusline.sh
```

Note: Codex CLI does not auto‑execute hooks. These helpers are available for manual or scripted use when they add value.

