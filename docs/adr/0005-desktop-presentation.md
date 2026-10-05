# ADR 0005: Desktop presentation mode — a window below the icon layer

## Decision

Implement desktop presentation mode as a borderless, non-activating
window per display, at
`CGWindowLevelForKey(.desktopIconWindow) - 1`, with
`[.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]`, that
**does** accept mouse events so the globe stays interactive.

Describe it in the UI and the documentation as a desktop *companion*
mode, not as a wallpaper replacement.

## The constraint

macOS has no public API that makes a third-party app the wallpaper. There
is no supported way to guarantee a third-party window sits beneath the
desktop icons on every Space, display and Stage Manager configuration.

The techniques that get closer — private APIs, process injection,
Accessibility automation, screen recording — are all excluded by the
product requirements, and all of them would mean asking the user for
permissions the app has no honest reason to want. None was used.

## What was chosen, and why each part

- **Below the desktop icon layer.** This is the public window level that
  puts the globe behind everything the user works in. It also resolves
  what first looked like a conflict: because the icons are *above* the
  window, they keep receiving their own clicks, so the globe can be
  interactive without making the desktop unusable.
- **Mouse events accepted.** An earlier version set
  `ignoresMouseEvents = true` so that clicks passed through to anything
  behind. That made the globe a picture. The project owner asked for it
  to stay draggable and selectable on the desktop, and the window level
  above makes that safe.
- **`canBecomeKey` true, `canBecomeMain` false, never activated.** The
  window can take keyboard focus when the user deliberately clicks it,
  which is what makes scroll and keyboard input work, but it is never
  made key by the app and never becomes the main window. Entering the
  mode does not take focus from whatever the user is doing.
- **`acceptsFirstMouse` on the globe view.** Without it the first click
  on an inactive window is consumed by activating it, so a drag would
  need two clicks.
- **One window per display**, rebuilt on
  `didChangeScreenParameters`, so displays can be added, removed or
  rearranged while the mode is active.
- **Always reversible.** ⌃⌥⌘D, the View menu, and the menu-bar item all
  exit. The menu-bar item matters most: it works even if the main window
  has been closed.

## Evidence

Verified by screenshot on macOS 26: with the mode entered via
`--enter-presentation`, the globe renders full-screen at desktop level,
visible behind Finder windows and behind the Dock, while the app is not
active.

**Not yet verified**, and listed in docs/TESTING.md as open: behaviour
under Stage Manager, across multiple physical displays, in Mission
Control, alongside full-screen apps, and whether desktop icons remain
clickable in practice. Each needs a person at the machine.

## Trade-offs

- The presentation globe is a second scene with its own camera; it does
  not share a view with the main window.
- Each presentation window prepares its own rendering resources, so the
  mode costs additional memory per display.
- Behaviour at this window level is not contractual. Apple can change how
  the window server treats it; the mode is described accordingly, and
  normal-window mode always remains available.

## Trigger to revisit

If Apple publishes a supported wallpaper or desktop-widget API, move to
it. If a macOS release changes how this window level behaves, the whole
decision is contained in `PresentationModeController`.
