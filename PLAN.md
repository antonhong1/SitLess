# SitLess implementation plan

Build a personal, native macOS 14+ menu-bar Pomodoro timer from local Swift source.

1. Pure timer model: deadline-based countdown, pause/resume/reset/skip, 25/5/15-minute defaults, long break every four completed focus sessions, daily count, Codable persistence.
2. SwiftUI popover hosted by AppKit: segmented session selection, progress ring, countdown, accessible native controls, keyboard shortcuts, settings and completion messages. Confirm replacing active sessions.
3. macOS integration: menu-bar countdown, wake refresh, completion sound, optional ServiceManagement launch at login. No network, accounts, or third-party packages.
4. Validation: deterministic timer regression tests, debug and optimized builds, native UI interaction checks, screenshots, and installed bundle signature checks.
5. Delivery: locally ad-hoc signed `/Applications/SitLess.app`, complete source, and repeatable build instructions. Apple notarization and distribution are outside this personal build.

Session completion never starts another timer automatically. An expired timer recovered after sleep/relaunch counts once. Paused timers remain paused. Changing duration affects the next/reset session.
