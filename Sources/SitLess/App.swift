import AppKit
import SwiftUI

@main
struct SitLessMain {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
  }
}

private final class SitLessPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

private struct PopoverArrow: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      path.move(to: CGPoint(x: rect.midX, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
      path.closeSubpath()
    }
  }
}

private struct PanelSurface: View {
  @Bindable var store: TimerStore
  let dismiss: () -> Void

  var body: some View {
    VStack(spacing: -1) {
      ZStack {
        PopoverArrow().fill(.regularMaterial)
        PopoverArrow().fill(.white.opacity(0.58))
      }
      .frame(width: 22, height: 11)
      PanelView(store: store)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .fixedSize()
    .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
    .onExitCommand(perform: dismiss)
  }
}

private final class PanelHostingController: NSHostingController<PanelSurface> {
  var onFittingSizeChange: ((NSSize) -> Void)?
  private var lastFittingSize = NSSize.zero

  override func viewDidLayout() {
    super.viewDidLayout()
    let size = view.fittingSize
    guard abs(size.width - lastFittingSize.width) > 0.5
      || abs(size.height - lastFittingSize.height) > 0.5
    else { return }
    lastFittingSize = size
    onFittingSizeChange?(size)
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?
  private weak var statusButton: NSStatusBarButton?
  private var renderedStatusTime: String?
  private var panel: SitLessPanel?
  private var hostingController: PanelHostingController?
  private var outsideClickMonitor: Any?
  private let menuBarKeeper = NSPopover()
  private var store: TimerStore?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Opening an installed copy while a dev copy runs reuses the existing app.
    let others = NSRunningApplication.runningApplications(
      withBundleIdentifier: "app.sitless.mac"
    )
    .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    if let existing = others.first {
      existing.activate()
      NSApp.terminate(nil)
      return
    }
    let store = TimerStore()
    self.store = store
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem = item
    if let button = item.button {
      let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
      let image = NSImage(systemSymbolName: "timer", accessibilityDescription: "SitLess")?
        .withSymbolConfiguration(symbolConfig)
      image?.isTemplate = true
      button.image = image
      button.imageScaling = .scaleProportionallyDown
      button.imagePosition = .imageOnly
      button.title = ""
      button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
      button.target = self
      button.action = #selector(togglePanel)
      statusButton = button
    }
    configurePanel(for: store)
    store.onChange = { [weak self] in self?.updateStatus() }
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
    updateStatus()
    showPanel()
  }

  private func configurePanel(for store: TimerStore) {
    let hostingController = PanelHostingController(
      rootView: PanelSurface(store: store) { [weak self] in self?.hidePanel() })
    hostingController.sizingOptions = [.intrinsicContentSize]
    let panel = SitLessPanel(
      contentRect: NSRect(x: 0, y: 0, width: 340, height: 560),
      styleMask: [.borderless], backing: .buffered, defer: false)
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.level = .popUpMenu
    panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
    panel.contentViewController = hostingController
    hostingController.onFittingSizeChange = { [weak self] size in
      self?.resizeVisiblePanel(to: size)
    }
    self.hostingController = hostingController
    self.panel = panel

    outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] _ in
      DispatchQueue.main.async {
        guard self?.panel?.isVisible == true else { return }
        self?.hidePanel()
      }
    }

    let keeperController = NSViewController()
    keeperController.view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    menuBarKeeper.animates = false
    menuBarKeeper.behavior = .applicationDefined
    menuBarKeeper.contentSize = NSSize(width: 1, height: 1)
    menuBarKeeper.contentViewController = keeperController
  }

  private func updateStatus() {
    guard let store, let statusItem, let statusButton else { return }
    let activity = store.state.isRunning ? "running" : store.state.hasStarted ? "paused" : "ready"
    let accessibilityText =
      "SitLess, \(store.state.phase.title), \(store.timeText), \(activity)"
    let displayTime = store.state.hasStarted ? store.timeText : nil
    if displayTime != renderedStatusTime {
      statusButton.title = displayTime ?? ""
      statusButton.imagePosition = displayTime == nil ? .imageOnly : .imageLeading
      statusItem.length = NSStatusItem.variableLength
      renderedStatusTime = displayTime
    }
    statusButton.toolTip = "SitLess · \(store.state.phase.title) · \(store.timeText)"
    statusButton.setAccessibilityLabel(accessibilityText)
  }

  @objc private func woke() { store?.tick() }
  @objc private func togglePanel() {
    if panel?.isVisible == true { hidePanel() } else { showPanel() }
  }

  private func showPanel() {
    guard let statusButton, let statusWindow = statusButton.window,
      let panel, let hostingController
    else { return }
    NSApp.activate(ignoringOtherApps: true)
    hostingController.view.layoutSubtreeIfNeeded()
    let size = hostingController.view.fittingSize
    panel.setContentSize(size)

    if !menuBarKeeper.isShown {
      menuBarKeeper.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
    }
    positionPanel(panel, size: size, below: statusButton, in: statusWindow)
    panel.orderFrontRegardless()
    panel.makeKey()
  }

  private func hidePanel() {
    panel?.orderOut(nil)
    menuBarKeeper.performClose(nil)
  }

  private func resizeVisiblePanel(to size: NSSize) {
    guard let panel, panel.isVisible, let statusButton, let statusWindow = statusButton.window,
      size.width > 0, size.height > 0,
      abs(panel.frame.width - size.width) > 0.5 || abs(panel.frame.height - size.height) > 0.5
    else { return }
    positionPanel(panel, size: size, below: statusButton, in: statusWindow)
  }

  private func positionPanel(
    _ panel: NSPanel, size: NSSize, below statusButton: NSStatusBarButton,
    in statusWindow: NSWindow
  ) {
    let anchor = statusWindow.convertToScreen(statusButton.convert(statusButton.bounds, to: nil))
    let visibleFrame = (statusWindow.screen ?? NSScreen.main)?.visibleFrame ?? anchor
    let x = min(
      max(anchor.midX - size.width / 2, visibleFrame.minX + 6),
      visibleFrame.maxX - size.width - 6)
    let y = max(
      visibleFrame.minY + 6, min(anchor.minY - size.height, visibleFrame.maxY - size.height))
    panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showPanel()
    return true
  }
  func applicationWillTerminate(_ notification: Notification) {
    store?.persist()
    if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard let store else { return .terminateNow }
    Task {
      await store.prepareForTermination()
      sender.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }
}
