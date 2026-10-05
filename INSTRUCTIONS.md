# Testing this branch (milestone-1-renderer-spike)

## What this is
Milestone 1 (renderer decision) per docs/IMPLEMENTATION_PLAN.md: a
SceneKit scene with a sphere and two placeholder outline shapes,
pushed through the real pipeline shape (coordinates → projection →
GPU geometry). **The two shapes are NOT real country borders** — see
the warning at the top of `PlaceholderOutlines.swift`. Decision and
reasoning are in `docs/adr/0002-renderer-choice.md`.

Still not compiled by me — no Swift/macOS toolchain in my sandbox.
Check the PR's CI status first (this time I'll merge it myself once
it's green, instead of leaving that step to you).

## 1. Pull the branch
```bash
git fetch origin
git checkout milestone-1-renderer-spike
```

## 2. Build and test
```bash
swift build
swift test
```
Expect `swift test` to run the existing Core tests plus 4 new
`SphereProjectionTests`, all passing.

## 3. Run it
```bash
swift run AtlasDesktopApp
```
Expect: a window with a dark sphere and two yellow wireframe-ish
outline shapes on its surface. Drag with the mouse to rotate
(SceneKit's built-in camera control — not the real interaction model,
that's Milestone 3).

## If something fails
Paste the exact `swift build` / `swift test` error output back to me
— not a summary, not "it didn't work." I need the compiler's actual
diagnostic to fix the right thing.

## What I'm doing differently this time
Last round, my branch passed CI but sat unmerged while `main` stayed
red, so you (reasonably) had Copilot fix `main` directly on a separate
branch — which orphaned my work. This time: once CI is green on this
PR, I'll merge it myself rather than leaving `main` in a state that
needs a second, independent fix.
