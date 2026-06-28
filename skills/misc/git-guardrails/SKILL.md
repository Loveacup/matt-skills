---
name: git-guardrails
description: Set up multi-platform hooks to block dangerous git commands (push, reset --hard, clean, branch -D, etc.) before they execute. Supports Hermes, Claude Code, Codex, and OMP. Use when user wants to prevent destructive git operations, add git safety hooks, or block dangerous git commands.
---

# Git Guardrails (Multi-Platform)

Blocks dangerous git commands before execution across Alex's agent platforms.

## What Gets Blocked

- `git push` (all variants including `--force`)
- `git reset --hard`
- `git clean -f` / `git clean -fd`
- `git branch -D`
- `git checkout .` / `git restore .`

When blocked, the agent sees a message telling it that this command is not authorized.

## Platform Support

| Platform | Mechanism | Priority |
|----------|-----------|----------|
| **Hermes** | SOUL.md guard rules + terminal tool hook | P0 |
| **Claude Code** | PreToolUse hook in `.claude/settings.json` | P1 |
| **Codex** | Pre-tool guard in Codex config | P2 |
| **OMP** | OMP profile guard rules | P3 |

---

## Claude Code Setup

### 1. Ask scope

Ask the user: install for **this project only** (`.claude/settings.json`) or **all projects** (`~/.claude/settings.json`)?

### 2. Copy the hook script

The bundled script is at: [scripts/block-dangerous-git.sh](scripts/block-dangerous-git.sh)

Copy it to the target location based on scope:

- **Project**: `.claude/hooks/block-dangerous-git.sh`
- **Global**: `~/.claude/hooks/block-dangerous-git.sh`

Make it executable with `chmod +x`.

### 3. Add hook to settings

**Project** (`.claude/settings.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-dangerous-git.sh"
          }
        ]
      }
    ]
  }
}
```

**Global** (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/block-dangerous-git.sh"
          }
        ]
      }
    ]
  }
}
```

If the settings file already exists, merge the hook into existing `hooks.PreToolUse` array — don't overwrite other settings.

### 4. Ask about customization

Ask if user wants to add or remove any patterns from the blocked list. Edit the copied script accordingly.

### 5. Verify

```bash
echo '{"tool_input":{"command":"git push origin main"}}' | <path-to-script>
```

Should exit with code 2 and print a BLOCKED message to stderr.

---

## Hermes Setup

Hermes enforces git guardrails via SOUL.md rules — no script installation needed. Dangerous git commands are blocked by default through:

```markdown
# In SOUL.md — already active
## 安全边界
- 未经明确授权，不要执行破坏性命令：`rm -rf`、`git reset --hard`、`git clean`...
```

For additional enforcement, add to SOUL.md:

```markdown
- git push / --force / branch -D: 永远需要明确人工授权
```

---

## Codex Setup

Add to Codex CLI config (`~/.codex/config.toml` or project `.codex.toml`):

```toml
[guardrails]
blocked_commands = [
  "git push",
  "git reset --hard",
  "git clean",
  "git branch -D",
]
```

---

## OMP Setup

OMP profiles use agent-level guard rules. See OMP profile references for the guardrail block configuration.
