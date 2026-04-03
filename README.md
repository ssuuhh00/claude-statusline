# claude-statusline

Custom Claude Code statusline script with rate limit progress bars and reset times.

## Preview

```
multi-protocol-gateway │ Opus 4.6 │ 55k/200k

current  ━━━─────────  31%  ⟳ 2:00am
weekly   ────────────   2%  ⟳ apr 10, 9:00pm
```

- Line 1: project name │ model │ context tokens
- Line 2: 5-hour rate limit bar + reset time
- Line 3: 7-day rate limit bar + reset time
- Color-coded bars: green → orange → yellow → red

## Install

```bash
cp statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

## Requirements

- `jq`
- `bash` 4+
- Claude Code with Pro/Max subscription (for rate limit data)
