---
name: declutter-manor-workflow
description: How the author wants Claude to work on Declutter Manor — in-window implementation, delegate on volume only, ported from the What the Buck rules.
metadata:
  type: feedback
---

Asked on 2026-09-09 to port the workflow from his two 2D Godot projects
(`~/Dokumente/whatthebuck`, `~/Dokumente/BouncingBallPhysicsGame`) and improve it. He chose:
**implement in this window; delegate only on volume, never on difficulty** — his own measured
2026-08-20 finding that a handoff pays for the whole context twice. This replaces the
prompt-handoff regime he used on What the Buck.

**Why:** he runs token-lean and had measured that handoffs cost more than they save for
anything short of a genuine bulk batch.

**How to apply:** `CLAUDE.md` Phase 0 carries the full protocol — absolute honesty with visual
work explicitly needing human verification, verify every finding yourself (including your own),
diff-only output, English replies, stage git files by name, and update
`.claude/memory/current-status.md` at every breakpoint before suggesting `/clear`. The repo
mirror `.claude/memory/` exists for laptop portability; home is the truth during a session.

See [[game-vision-declutter-manor]].
