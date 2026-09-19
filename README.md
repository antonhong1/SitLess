# SitLess

## How it works

Start a focus session and work until the timer ends.

SitLess then prepares a short break. Use that time to stand up, stretch, get some water, or walk around.

After four focus sessions, SitLess prepares a longer break.

Nothing starts automatically. You decide when you are ready to begin the next timer.

The default timers are 25 minutes for focus, 5 minutes for a short break, and 15 minutes for a long break. You can change these times in the app.

## Features

- Focus, short-break, and long-break timers
- Pause, resume, reset, and skip controls
- Adjustable timer lengths
- Optional completion sounds
- Optional launch at login
- Timer recovery after sleep or restart

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Start or pause | Space |
| Reset | Command-R |
| Skip | Command-S |
| Quit | Command-Q |

The shortcuts work while the SitLess panel is open.

## Privacy

SitLess runs entirely on your Mac.

The app has no account, analytics, advertising, or cloud service. It does not make network requests.

Your timer and preferences stay on your computer.

## Build from source

SitLess requires macOS 14 or later and Swift 6.2 or later.

```sh
swift run FocusCoreChecks
bash scripts/build.sh
```

The finished app appears at `dist/SitLess.app`. Move it to `/Applications` and open it.
