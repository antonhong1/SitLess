# FocusBar

A small native macOS menu-bar Pomodoro timer, built locally for this Mac. Requires macOS 14 or later and Swift 6.2+ command-line tools to rebuild. No third-party dependencies, accounts, servers, or network requests.

## Use

Open `/Applications/FocusBar.app`, then click the timer symbol in the menu bar. Start with 25 minutes of focus, 5 minutes of short break, and 15 minutes of long break. Durations are adjustable. After four completed focus sessions the next interval is a long break. Each interval starts manually.

- Start/pause/resume, reset, and skip are in the timer panel.
- Space starts or pauses, Command-R resets, Command-S skips, and Command-Q quits while the panel is open.
- Settings includes optional completion sounds, notifications, and launch at login. Notifications and launch at login are off until enabled.
- A running timer keeps its deadline across sleep and quitting. Relaunching after expiry records exactly one completion and leaves the next session ready. Paused timers stay paused.
- Settings changes affect the next interval, or the current interval after Reset. Skipping never counts as completing a focus session.
- If notifications are denied, enable them in System Settings → Notifications → FocusBar. Sound plays when the running app observes completion; it cannot wake a sleeping Mac.

## Build and validate

```sh
swift run FocusCoreChecks
bash scripts/build.sh
specific check
specific dev --key focusbar-personal
```

The test executable has 10 deterministic timer regression cases. It uses standard Swift assertions because the installed standalone Command Line Tools do not include Swift Testing. The build produces `dist/FocusBar.app` and applies a local ad-hoc signature. It is not an Apple-notarized distributable.

To install a new build, quit FocusBar, copy `dist/FocusBar.app` to `/Applications`, and open it. No Gatekeeper setting is changed by this project. Launch at login uses Apple's SMAppService; notifications use UNUserNotificationCenter.

The preferences and timer state are local to the `local.anton.FocusBar` UserDefaults domain. Removing the app does not erase these preferences. Source lives in its own Git repository at `~/Projects/FocusBar`, independent of Feron. Build output in `dist/` and Swift build caches are ignored by Git.

Apple API references:
- https://developer.apple.com/documentation/servicemanagement/smappservice
- https://developer.apple.com/documentation/usernotifications/unusernotificationcenter
