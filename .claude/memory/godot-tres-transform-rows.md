---
name: godot-tres-transform-rows
description: "In .tres text, Transform3D(...) lists the basis ROW by row, not column by column — scripts that write tres must transpose"
metadata: 
  node_type: memory
  type: reference
  originSessionId: f6ecb723-ec95-4513-bc14-46c3964660c9
  modified: 2026-09-15T19:48:57.824Z
---

`Transform3D(a, b, c, d, e, f, g, h, i, ox, oy, oz)` in a `.tres` is the basis by rows: `(a, b, c)` is
row 0. A script writing column 0 first writes the inverse rotation.

Measured 2026-09-15: `scratchpad/b4/furn.py` wrote a pitch of -90 column-wise and the wrenches on the
workbench hooks hung ring-end down; written row-wise they hang ring-end up. Quarter and half yaws on
symmetric items (hangers, dumbbells, books in batches 2-3) never showed it.

**How to apply:** any generator of `.tres`/`.tscn` text (piece writers, ContentImport-like tools) writes
`basis.x.x, basis.y.x, basis.z.x, basis.x.y, …`; check one asymmetric item in a render before trusting a
rotation. Related: [[current-status]].
