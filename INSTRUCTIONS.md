# Testing this branch (milestone-0-bootstrap)

## What this is
Milestone 0 only: proves the project builds, links, launches, and has
a working test target. There is **no globe, no renderer, no real
country data yet** — those are Milestones 1–2. The window just shows
a placeholder screen.

**This was written and pushed without ever being compiled** — it was
authored in a Linux sandbox with no Swift/macOS toolchain. Treat
everything below as "should work" until you've actually run it.

## 1. Pull the branch
```bash
cd ~/path/to/atlas-desktop   # or: git clone https://github.com/KABEER-AHMED/atlas-desktop.git
git fetch origin
git checkout milestone-0-bootstrap
```

## 2. Build and test from the command line
```bash
swift build
swift test
```
- `swift build` should succeed with no errors.
- `swift test` should run 8 tests (CountryID + Coordinate validation),
  all passing.

If either fails, **copy the full terminal output** back to me — the
exact compiler error is what I need, not a summary.

## 3. Run the app
```bash
swift run AtlasDesktopApp
```
A small window titled "Atlas Desktop" should appear with a globe
icon and a placeholder message. Closing it should quit normally
(Cmd+Q).

## 4. Open it in Xcode (optional but recommended)
```bash
open Package.swift
```
Xcode will open it as a Swift Package. Select the `AtlasDesktopApp`
scheme and hit Run (Cmd+R). This also gives you real compiler
diagnostics inline, which is more useful than the CLI if something's
wrong.

## 5. Check CI
A PR has been opened from `milestone-0-bootstrap` into `main`. Check
the "macOS Build and Test" GitHub Action on that PR — it runs on an
actual macOS runner and is a second, independent check beyond your
own machine.

## What "pass" looks like
- [ ] `swift build` — no errors
- [ ] `swift test` — all tests pass
- [ ] `swift run AtlasDesktopApp` — window opens, no crash
- [ ] GitHub Actions check on the PR is green

## What to tell me either way
- If everything passes: say so, and I'll move on to Milestone 1
  (renderer decision — SceneKit vs Metal spike with real outlines).
- If something fails: paste the exact error output. I cannot debug a
  macOS/Swift compiler error from a vague "it didn't work."
