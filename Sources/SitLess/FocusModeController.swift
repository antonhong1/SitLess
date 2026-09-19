import AppKit
import ApplicationServices

final class FocusModeController {
  var onError: ((String) -> Void)?
  private(set) var enabledBySitLess: Bool

  private let defaults: UserDefaults
  private var desiredEnabled = false
  private var reconciliationTask: Task<Void, Never>?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    enabledBySitLess = defaults.bool(forKey: "doNotDisturbEnabledBySitLess")
  }

  func reconcile(shouldEnable: Bool) {
    desiredEnabled = shouldEnable
    guard reconciliationTask == nil else { return }
    reconciliationTask = Task { [weak self] in
      guard let self else { return }
      await runReconciliationLoop()
    }
  }

  func prepareForTermination() async {
    desiredEnabled = false
    reconcile(shouldEnable: false)
    await reconciliationTask?.value
  }

  private func runReconciliationLoop() async {
    while true {
      let target = desiredEnabled
      await apply(target)
      guard target != desiredEnabled else { break }
    }
    reconciliationTask = nil
  }

  private func apply(_ shouldEnable: Bool) async {
    do {
      if shouldEnable {
        guard !enabledBySitLess else { return }
        try await requestAccessibilityIfNeeded()
        if try await setDoNotDisturb(enabled: true, onlyWhenNoFocusIsActive: true) {
          setEnabledBySitLess(true)
        }
      } else {
        guard enabledBySitLess else { return }
        try await requestAccessibilityIfNeeded(prompt: false)
        _ = try await setDoNotDisturb(enabled: false, onlyWhenNoFocusIsActive: false)
        setEnabledBySitLess(false)
      }
    } catch {
      onError?(error.localizedDescription)
    }
  }

  private func setEnabledBySitLess(_ enabled: Bool) {
    enabledBySitLess = enabled
    defaults.set(enabled, forKey: "doNotDisturbEnabledBySitLess")
  }

  private func requestAccessibilityIfNeeded(prompt: Bool = true) async throws {
    guard !AXIsProcessTrusted() else { return }
    if prompt {
      _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
      for _ in 0..<60 {
        try? await Task.sleep(for: .milliseconds(500))
        if AXIsProcessTrusted() { return }
      }
    }
    throw FocusModeError.accessibilityPermission
  }

  /// Returns true only when this call changed Do Not Disturb from off to on.
  private func setDoNotDisturb(
    enabled: Bool, onlyWhenNoFocusIsActive: Bool
  ) async throws -> Bool {
    guard
      let controlCenter = NSRunningApplication.runningApplications(
        withBundleIdentifier: "com.apple.controlcenter"
      ).first
    else { throw FocusModeError.controlCenterUnavailable }

    let application = AXUIElementCreateApplication(controlCenter.processIdentifier)
    guard
      let menuExtra = descendant(
        of: application, identifier: "com.apple.menuextra.controlcenter")
    else { throw FocusModeError.controlCenterUnavailable }

    if !windows(of: application).isEmpty {
      _ = AXUIElementPerformAction(menuExtra, kAXPressAction as CFString)
      _ = try? await waitFor { self.windows(of: application).isEmpty ? true : nil }
    }

    guard AXUIElementPerformAction(menuExtra, kAXPressAction as CFString) == .success else {
      throw FocusModeError.controlCenterUnavailable
    }
    defer { _ = AXUIElementPerformAction(menuExtra, kAXPressAction as CFString) }

    let window = try await waitFor { self.windows(of: application).first }
    let focusModule = try await waitFor {
      self.descendant(of: window, identifier: "controlcenter-focus-modes")
    }

    if enabled, onlyWhenNoFocusIsActive, boolValue(of: focusModule) == true {
      return false
    }

    let detailsAction = "Name:show details\nTarget:0x0\nSelector:(null)" as CFString
    guard AXUIElementPerformAction(focusModule, detailsAction) == .success else {
      throw FocusModeError.focusControlUnavailable
    }

    let doNotDisturb = try await waitFor {
      self.windows(of: application).lazy.compactMap {
        self.descendant(
          of: $0, identifier: "focus-mode-activity-com.apple.donotdisturb.mode.default")
      }.first
    }
    let isEnabled = boolValue(of: doNotDisturb) == true
    guard isEnabled != enabled else { return false }

    guard AXUIElementPerformAction(doNotDisturb, kAXPressAction as CFString) == .success else {
      throw FocusModeError.focusControlUnavailable
    }
    _ = try await waitFor { self.boolValue(of: doNotDisturb) == enabled ? true : nil }
    return enabled
  }

  private func waitFor<Value>(
    timeout: TimeInterval = 2.5, value: @escaping () -> Value?
  ) async throws -> Value {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if let value = value() { return value }
      try? await Task.sleep(for: .milliseconds(100))
    }
    throw FocusModeError.focusControlUnavailable
  }

  private func windows(of element: AXUIElement) -> [AXUIElement] {
    attribute(element, kAXWindowsAttribute as CFString) as? [AXUIElement] ?? []
  }

  private func boolValue(of element: AXUIElement) -> Bool? {
    (attribute(element, kAXValueAttribute as CFString) as? NSNumber)?.boolValue
  }

  private func descendant(
    of element: AXUIElement, identifier: String, depth: Int = 0
  ) -> AXUIElement? {
    guard depth < 10 else { return nil }
    if attribute(element, kAXIdentifierAttribute as CFString) as? String == identifier {
      return element
    }
    let children = attribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []
    for child in children {
      if let match = descendant(of: child, identifier: identifier, depth: depth + 1) {
        return match
      }
    }
    return nil
  }

  private func attribute(_ element: AXUIElement, _ name: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
    return value
  }
}

private enum FocusModeError: LocalizedError {
  case accessibilityPermission
  case controlCenterUnavailable
  case focusControlUnavailable

  var errorDescription: String? {
    switch self {
    case .accessibilityPermission:
      "Allow SitLess in System Settings → Privacy & Security → Accessibility, then resume the timer."
    case .controlCenterUnavailable:
      "SitLess could not open Control Center. Do Not Disturb was not changed."
    case .focusControlUnavailable:
      "SitLess could not change Do Not Disturb. Your existing Focus settings were left unchanged."
    }
  }
}
