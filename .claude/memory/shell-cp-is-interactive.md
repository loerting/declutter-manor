---
name: shell-cp-is-interactive
description: The user's zsh aliases cp to an interactive form; a plain cp over an existing file hangs forever waiting for confirmation.
metadata:
  type: reference
---

`cp` in this shell prompts before overwriting, so a scripted `cp src dst` over an existing file
never returns — it sits waiting for a y/n that no one will type, and the tool call times out into
the background.

**How to apply:** always `command cp -f` (or `-a`) in scripted copies, most often when mirroring
`~/.claude/projects/-home-alexander-Dokumente-declutter-manor/memory/` into the repo's
`.claude/memory/`. The same trap is recorded in the BouncingBallPhysicsGame repo, so it is the
shell, not the project.
