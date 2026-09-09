---
description: Declutter Manor — strict Godot 4.x rules for a fully procedural 3D game. Enforces the agent protocol, component-based design, strict typing, and the modelling rules that keep procedural props from reading as fake.
globs: **/*.gd, **/*.tscn, **/*.tres
---

# Declutter Manor

Read `docs/VISION.md` before making any design decision, `docs/ARCHITECTURE.md` before writing
any script, and `docs/PACING.md` before touching any number the player feels.

## Phase 0: Agent Protocol

- **0.1 Setup check.** For non-trivial tasks, judge whether the current model/effort level fits.
  If it does not, STOP, state the recommendation, wait. Skip for trivial edits.
- **0.2 Delegate on volume, not on difficulty.** Measured on What the Buck (2026-08-20): a handoff
  pays for the whole context a second time — authoring the prompt, the other window reading itself
  in cold, and the re-verification on top. Default is **do it in this window**. Delegate only when
  the work would not fit here (a 60-file content batch) or is pure enumerated conveyor-belt work
  whose value is in the listing, not the doing. "This is a lot of work" is not a reason;
  "I would have to hold all of it at once" is. Say explicitly when you delegate and why.
- **0.3 Absolute honesty.** Never claim something works unless a probe, a test or a render proves
  it. Flag untested code as untested. **This project's product is a visual one: geometry, lighting
  and layout are NOT verified by code passing.** Every art claim must either come with a render the
  user can look at, or be explicitly marked "needs human verification". Never invent a file, path,
  API or licence.
- **0.4 Verify every finding yourself.** Whether it comes from a subagent, a probe or your own
  earlier reasoning, answer three separate questions before acting: (a) does the code really say
  that? (b) is that path reachable? (c) is the claimed magnitude measured or guessed? A frequency
  is almost always guessed. An agent's "this is clean" is worth exactly as much as its "this is
  broken" — both get re-checked.
- **0.5 Diff-only output.** Never restate a whole file for a small change. Show the changed
  functions or a unified diff.
- **0.6 Token economy.** Keep replies lean, skip conversational preamble, do not re-derive settled
  context. Suggest `/compact` after a complex task and `/clear` before an unrelated one.
- **0.7 Memory and handover.** At every natural breakpoint, update `.claude/memory/current-status.md`
  (what just finished, the next concrete step, open loops) and any memory whose facts went stale —
  without being asked — then suggest `/clear`. `.claude/memory/` in the repo is a mirror of
  `~/.claude/projects/-home-alexander-Dokumente-declutter-manor/memory/`; the home directory is the
  truth during a session, the repo copy is what travels between machines. Sync it before any commit
  that changes the project's state.
- **0.8 English.** Replies, docs, comments, commit messages and player-facing text are English.
- **0.9 Git.** Stage files explicitly by name, never `git add -A`. Commit and push only when asked.
  Review the diff for secrets before staging.

## The 10 Holy Rules of Godot Development

1. **Godot 4 syntax only.** Annotations (`@export`, `@onready`), direct `Callable`s, typed signals
   (`hit.emit()`, `hit.connect(fn)`). Strings for signals/methods and any Godot 3 idiom are banned.
2. **Strict typing.** Type every variable, argument and return (`-> void`). Use `:=` for inference
   and `as` for safe casts, followed by a null check where the cast can fail.
   - 2.1 Never iterate an untyped array. Use `Array[ItemDef]`, not `Array`.
3. **Composition.** Flat hierarchies with encapsulated component children (`CarryComponent`,
   `ContainerComponent`), never deep inheritance.
4. **Signal up, call down.** Children emit, parents call child methods. `get_parent()` is banned.
5. **Dependency injection.** No hardcoded relative node paths. Scene-unique nodes (`%`) internally,
   `@export`/`initialize()` across boundaries.
6. **Data is Resources, state is an FSM.** No giant `match` blocks of content, no boolean flag chains.
7. **Polymorphism over duck typing.** `has_method()`, `get_node_or_null()` and friends are banned.
8. **Guard clauses.** Early return instead of nesting. Skip redundant null checks where safety is
   contextually guaranteed; assert instead.
   - 8.1 No chatty intros or outros around a code change. Deliver the technical result.
9. **Assert dependencies in `_ready()`.** Every dynamically created node is either `add_child`ed or
   `queue_free`d — no orphans.
10. **Scene tree for wiring, code for geometry.** This project generates its meshes and its house at
    runtime, and that is deliberate — rule 10 does *not* mean hand-placing props in `.tscn` files.
    It means: node structure, signal wiring and component composition live in scenes; only geometry
    and instancing live in code. Every magic number becomes a `const` in `Balance.gd` or a field on
    a Resource.

## The 5 Modelling Rules

Proven in the style test; every one of them fixed a prop that read as fake.

1. **One physical object = one connected mesh.** A fork's tines and its head are one surface, not two
   meshes overlapped until they touch. See `Props.dished`.
2. **A recess is geometry, not a dark decal.** If you can see into it, it is hollow. See the toaster.
3. **Sheet goods have two sides and an edge.** Never rely on `CULL_DISABLED`; nothing in this repo does.
4. **Parts that carry load must touch.** Shades need a harp, tops need aprons, doors need reveals.
5. **Nothing intersects the floor and nothing floats above it.**

### Winding, normals, tangents, scale — the four traps

- Godot renders a triangle front-facing when its right-hand-rule cross product points *into* the
  solid. `SurfaceTool.generate_normals()` follows the same convention. Two generators shipped
  inside-out before this was understood. **Run `dev/Diag.gd` after touching any generator.**
- **Every new generator returns through `Props.with_tangents()`.** Triplanar ignores UV1 when
  sampling but still builds its normal-map frame from the mesh tangent, and `SurfaceTool` cannot
  make tangents without UVs.
- **Triplanar works in metres.** Every texture slot carries the real-world tile size from its
  source's published dimensions. That physical scale is most of what separates a scene that reads
  as real from one that reads as plastic. Deviate only deliberately, and say so in the manifest.
- **Godot only enables mipmaps for textures it sees assigned in the editor.** Runtime-assigned
  materials never trigger `detect_3d`, so `tools/fetch_textures.py` writes the `.import` settings
  itself. Never hand-edit `assets/textures/**/*.import`.

## Licensing

Every texture is CC0 and nothing requires attribution in a shipped build. `ATTRIBUTION.md` records
every asset and, more importantly, **why the rejected sources were rejected**. Textures.com and
FreePBR are NOT CC0 and must not be added without a licence review. Keep `ATTRIBUTION.md` in step
with `assets/textures.json` in the same commit.

## No AI-slop copy

Player-facing text that describes what a thing does states the mechanical fact and nothing else.
No flavour sentence restating the number, no design commentary, no justification of a value.

- Good: `Cushions. 3 of 8 returned.`
- Bad: `Cushions. 3 of 8 returned — the soft ones always end up in the strangest places, don't they?`

Before writing any description string, ask whether the sentence adds a fact the number does not.
If not, cut it. This applies retroactively: when auditing slop, delete rather than rephrase.

## Single sources of truth — search before you write

Creating a local variant of something that already exists globally is the worst failure mode in a
codebase this size. The table lives in `docs/ARCHITECTURE.md` and is authoritative. Never
re-hardcode a value that appears in `Balance.gd`, a slot cost that appears on an `ItemDef`, a room
boundary that appears in the floor plan, or a colour/material that appears in `Mats.gd`.

## Verification — never say "it works" without one of these

    dev/tests/run_tests.sh                                   # the only real pass/fail exit code
    dev/tests/check_export.sh                                # proves the export ships no dev content
    godot --headless --path . --script res://dev/Diag.gd     # mesh winding + normals
    godot --headless --path . --import                       # after adding any class_name
    godot --headless --path . --script res://dev/PlanProbe.gd # house consistency, interior vs exterior
    godot --path . -- --view=<name> --screenshot=<abs path>   # the only proof of anything visual

A headless boot exits 0 even when a script failed to compile — always grep the log for
`SCRIPT ERROR` and `Parse Error`. After adding a new `class_name`, run `--import` first or it fails
with "Could not find type X" even though the script is fine. A script that fails to parse never
reaches its own `quit()`, so anything scripted around Godot needs a `timeout`.

**A green suite is not evidence until it can go red.** Before trusting a test on anything
load-bearing, break the source deliberately and prove the test fails. This is how the save
guarantees were verified in Phase 0, and it is not optional for save, economy or set-tracking code.
