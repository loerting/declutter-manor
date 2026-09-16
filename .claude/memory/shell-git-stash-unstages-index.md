---
name: shell-git-stash-unstages-index
description: Never git stash in declutter-manor — pop brings the worktree back but un-stages the curated index
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f6ecb723-ec95-4513-bc14-46c3964660c9
  modified: 2026-09-15T13:18:22.187Z
---

Never run `git stash` (or anything that round-trips the worktree through a stash) in this repo. The
index is curated on purpose — it holds exactly the approved house + steps fix while Phase 3/4 work
stays unstaged ([[current-status]]) — and a plain `git stash pop` restores the files but not what was
staged: every `M ` / `MM` entry comes back as ` M`.

**Why:** 2026-09-15 a stash was used to probe the committed Props.gd. Recovered exactly with
`git read-tree <stash>^2` (the stash's index commit) after checking `git diff <stash>` was empty, but
only because the hash was written down before the pop.

**How to apply:** to test old code, copy the one file aside with python (`cp` is interactive,
[[shell-cp-is-interactive]]) or read it with `git show HEAD:path`, never stash. If a stash happens
anyway, record `git rev-parse stash@{0}` before popping.
