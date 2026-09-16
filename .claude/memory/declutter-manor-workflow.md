---
name: declutter-manor-workflow
description: "How the author wants Claude to work on Declutter Manor — in-window implementation, delegate on volume only, ported from the What the Buck rules."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f6ecb723-ec95-4513-bc14-46c3964660c9
  modified: 2026-09-15T02:48:16.206Z
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

**Measured 2026-09-15:** a Workflow of 7 parallel modelling agents (each reading Props/Mats/docs
cold) hit the author's session limit in 20 minutes at 1M tokens with 2 of 18 families half-done.
The same 18 families were then finished in-window in one session. For Phase 4 content batches keep
modelling in-window; if a fan-out is ever worth it, cap it at 2-3 agents and give each the toolkit
signatures in the prompt instead of "read Props.gd in full".

See [[game-vision-declutter-manor]] and [[current-status]].
