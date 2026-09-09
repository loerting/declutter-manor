---
name: shell-pkill-matches-self
description: pkill/pgrep -f inside a Bash tool call matches the call's own command line, including heredoc text — it killed the calling shell three times in one session
metadata:
  type: feedback
---

`pkill -f PATTERN` or `for p in $(pgrep -f PATTERN)` inside a Bash tool call matches the
wrapper shell that is running that very call, because the whole command text — heredoc bodies
included — is the wrapper's command line. Exit code 144 with nothing done is the symptom.

**Why:** Three background render batches died this way on 2026-09-09: once from a plain
`pkill -f manor.sh`, twice from a "safe" split pattern (`'House''View.tscn'`) that was defeated
because a heredoc later in the same call spelled the name out in full.

**How to apply:** Kill in its own Bash call containing nothing else, and split the pattern
(`pgrep -f 'House''View.tscn'`) so the calling shell's text cannot match it. Never combine a
kill with a heredoc that mentions the target. Also: `until ! pgrep -f X` loops match
themselves and never exit — and they can match another project's Godot too (a
BouncingBallPhysicsGame probe was running in parallel). Related: [[shell-cp-is-interactive]].
