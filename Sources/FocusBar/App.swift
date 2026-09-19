import AppKit
import SwiftUI
import UserNotifications

@main
struct FocusBarMain {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  private var statusItem: NSStatusItem?
  private let popover = NSPopover()
  private var store: TimerStore?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Opening an installed copy while a dev copy runs reuses the existing app.
    let others = NSRunningApplication.runningApplications(
      withBundleIdentifier: "local.anton.FocusBar"
    )
    .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    if let existing = others.first {
      existing.activate()
      NSApp.terminate(nil)
      return
    }
    UNUserNotificationCenter.current().delegate = self
    let store = TimerStore()
    self.store = store
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem = item
    if let button = item.button {
      button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "FocusBar")
      button.imagePosition = .imageLeading
      button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
      button.target = self
      button.action = #selector(togglePopover)
    }
    popover.behavior = .transient
    popover.contentViewController = NSHostingController(rootView: PanelView(store: store))
    store.onChange = { [weak self] in self?.updateStatus() }
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
    updateStatus()
    let firstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunched")
    UserDefaults.standard.set(true, forKey: "hasLaunched")
    if firstLaunch || CommandLine.arguments.contains("--show") { showPopover() }
  }

  private func updateStatus() {
    guard let store, let button = statusItem?.button else { return }
    button.title = store.state.hasStarted ? " \(store.timeText)" : ""
    button.alphaValue = 1
    button.toolTip = "FocusBar · \(store.state.phase.title) · \(store.timeText)"
    button.setAccessibilityLabel(
      "FocusBar, \(store.state.phase.title), \(store.timeText)\(store.state.isRunning ? " running" : " ready")"
    )
  }

  @objc private func woke() { store?.tick() }
  @objc private func togglePopover() {
    if popover.isShown { popover.performClose(nil) } else { showPopover() }
  }
  private func showPopover() {
    guard let button = statusItem?.button else { return }
    NSApp.activate(ignoringOtherApps: true)
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    popover.contentViewController?.view.window?.makeKey()
  }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showPopover()
    return true
  }
  func applicationWillTerminate(_ notification: Notification) { store?.persist() }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions { [.banner, .list] }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    await MainActor.run { self.showPopover() }
  }
}
