# Testing and Verification

## Principles

Tests should be deterministic, local-first, and repeatable. No test should require an API key, account, or live network. Separate geography/domain correctness from pixel rendering so most logic can be tested without brittle screenshots.

## Automated test layers

### Unit tests
- Coordinate conversion: degrees/radians, longitude wrap, poles, sphere orientation.
- Geometry processing: rings, holes, multipolygons, malformed/degenerate geometry, antimeridian crossing.
- Country identity and metadata: stable IDs, joins, missing/duplicate IDs, unknown capital/region.
- Camera: zoom bounds, reset state, rotation updates, drag mapping.
- Selection: hit mapping, boundary tolerance, empty-space hit, selection clearing.
- Learning mode: labels hidden while interaction remains enabled.
- Preferences: defaults, round-trip persistence, invalid values, version migration.
- State machine: pause/resume, manual interaction during auto-rotation, lifecycle transitions.
- Day/night model: deterministic results for chosen inputs and documented approximation.

### Integration tests
- Load bundled data with networking unavailable.
- Verify representative countries and metadata joins.
- Confirm geometry validation and resource packaging.
- Confirm missing/corrupt resources return actionable errors.
- Verify conversion outputs are reproducible or document any deterministic constraints.

### UI tests
- App launches to a usable globe.
- Selecting a country updates the facts panel.
- Learning mode toggles labels.
- Rotation pauses/resumes; reset works.
- Settings persist after relaunch.
- Key actions have accessibility names/identifiers and keyboard access.
- Presentation mode can be exited reliably where UI automation permits.

### CI
- Use a macOS runner.
- Build and test on pushes and pull requests.
- Keep workflow permissions minimal and fail on build/test errors.
- A green CI run is not proof of real desktop window behavior or M1 performance.

## Manual acceptance matrix

Perform on the reference Apple Silicon Mac and supported macOS versions where practical.

| Scenario | Expected result |
|---|---|
| First launch offline | Globe and selection work with network disabled |
| Drag with mouse/trackpad | Smooth rotation, no accidental UI drag |
| Scroll/pinch zoom | Bounded zoom without losing the globe |
| Select country | Correct country highlighted and facts displayed |
| Select empty space | Selection clears or follows documented behavior |
| Learning mode | Labels disappear; borders and selection remain |
| Auto-rotation | Gentle motion; pause/resume is immediate |
| Reduced motion | Auto-motion disabled or minimized as specified |
| Resize window | Globe and panel adapt without corruption |
| Hide/minimize/occlude | Rendering activity is reduced or stopped |
| Sleep/wake | Renderer resumes safely |
| Multiple displays | Presentation behavior is predictable |
| Spaces/Mission Control | No stuck window level; normal mode remains recoverable |
| Full-screen app | No unexpected focus stealing or interference |
| Exit presentation mode | Menu-bar action and shortcut restore normal mode |
| Corrupt/missing data | Clear error; no unexplained blank globe/crash |
| Relaunch | Preferences persist |
| Repeated open/close | No stale tasks or persistent CPU use |

## Performance measurement procedure

Record the Mac/chip/memory, macOS version, build configuration, display resolution, window dimensions, dataset version, commit, measurement duration, and tools used. Measure:
- Cold and warm startup, including the definition of “usable”.
- Frame rate and frame pacing during auto-rotation and direct interaction.
- Resident memory after startup and after several minutes.
- Idle CPU with rotation off/on, app hidden, minimized, and occluded.
- Instruments/signposts used and any thermal or battery caveats.

PRD targets:
- Input-to-visible response under 50 ms.
- Stable 60 FPS during visible interaction at the reference size.
- Warm startup within 2 seconds.
- Resident memory below 300 MB for the normal scene.
- Negligible idle CPU when paused and not visibly rendering.

These are targets, not assumed outcomes. If not achieved, record actual measurements and fix high-impact bottlenecks before changing targets.

## Test report template

Environment:  
Commit:  
Command:  
Result:  
Passed / failed / skipped:  
Performance measurements:  
Manual scenarios completed:  
Known issues:  
Unverified due to environment limits:  

Never report a test, build, benchmark, offline test, or manual scenario as passed unless it was actually executed.
