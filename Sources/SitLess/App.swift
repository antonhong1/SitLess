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

private func statusImage(time: String?) -> NSImage {
  let iconSize: CGFloat = 15
  let spacing: CGFloat = time == nil ? 0 : 4
  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.48)
  shadow.shadowBlurRadius = 1.5
  shadow.shadowOffset = NSSize(width: 0, height: -1)
  let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
    .foregroundColor: NSColor.white,
    .shadow: shadow,
  ]
  let title = NSAttributedString(string: time ?? "", attributes: attributes)
  let titleSize = time == nil ? .zero : title.size()
  let imageSize = NSSize(width: iconSize + spacing + ceil(titleSize.width), height: 18)
  let image = NSImage(size: imageSize, flipped: false) { rect in
    let iconRect = NSRect(x: 0, y: (rect.height - iconSize) / 2, width: iconSize, height: iconSize)
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
    if let icon = NSImage(systemSymbolName: "timer", accessibilityDescription: "SitLess")?
      .withSymbolConfiguration(symbolConfig)
    {
      icon.draw(in: iconRect)
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current?.compositingOperation = .sourceIn
      NSColor.white.setFill()
      NSBezierPath(rect: iconRect).fill()
      NSGraphicsContext.restoreGraphicsState()
    }
    if time != nil {
      title.draw(at: NSPoint(x: iconSize + spacing, y: (rect.height - titleSize.height) / 2))
    }
    return true
  }
  image.isTemplate = false
  return image
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?
  private weak var statusButton: NSStatusBarButton?
  private var renderedStatusTime: String?
  private var panel: SitLessPanel?
  private var hostingController: PanelHostingController?
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
      button.imagePosition = .imageOnly
      button.title = ""
      button.target = self
      button.action = #selector(togglePanel)
      statusButton = button
    }
    configurePanel(for: store)
    store.onChange = { [weak self] in self?.updateStatus() }
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
    updateStatus()
    let firstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunched")
    UserDefaults.standard.set(true, forKey: "hasLaunched")
    if firstLaunch || CommandLine.arguments.contains("--show") { showPanel() }
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
    panel.level = .popUpMenu
    panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
    panel.contentViewController = hostingController
    hostingController.onFittingSizeChange = { [weak self] size in
      self?.resizeVisiblePanel(to: size)
    }
    self.hostingController = hostingController
    self.panel = panel

    let keeperController = NSViewController()
    keeperController.view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    menuBarKeeper.animates = false
    menuBarKeeper.behavior = .applicationDefined
    menuBarKeeper.contentSize = NSSize(width: 1, height: 1)
    menuBarKeeper.contentViewController = keeperController
  }

  private func updateStatus() {
    guard let store, let statusItem, let statusButton else { return }
    let accessibilityText =
      "SitLess, \(store.state.phase.title), \(store.timeText)\(store.state.isRunning ? " running" : " ready")"
    let displayTime = store.state.hasStarted ? store.timeText : nil
    if statusButton.image == nil || displayTime != renderedStatusTime {
      let image = statusImage(time: displayTime)
      statusButton.image = image
      statusItem.length = image.size.width + 12
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

  func applicationDidResignActive(_ notification: Notification) { hidePanel() }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showPanel()
    return true
  }
  func applicationWillTerminate(_ notification: Notification) { store?.persist() }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard let store else { return .terminateNow }
    Task {
      await store.prepareForTermination()
      sender.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }
}
