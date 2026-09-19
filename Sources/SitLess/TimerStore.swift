import AppKit
import FocusCore
import Observation
import ServiceManagement

@Observable
final class TimerStore {
  var preferences: Preferences
  var state: TimerState
  var now = Date()
  var message: String?
  var error: String?
  var loginEnabled = SMAppService.mainApp.status == .enabled
  @ObservationIgnored private var ticker: Timer?
  @ObservationIgnored private let focusModeController = FocusModeController()
  @ObservationIgnored var onChange: (() -> Void)?
  private let defaults = UserDefaults.standard

  init() {
    let loaded = Self.load(Preferences.self, key: "preferences") ?? Preferences()
    preferences = loaded
    state = Self.load(TimerState.self, key: "timer") ?? TimerState(preferences: loaded)
    focusModeController.onError = { [weak self] in self?.error = $0 }
    tick()
    reconcileFocusMode()
    ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.tick() }
    }
    if let ticker { RunLoop.main.add(ticker, forMode: .common) }
  }

  private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
    guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }

  var timeText: String {
    let seconds = Int(ceil(state.secondsLeft(at: now)))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }
  var progress: Double { state.progress(at: now) }
  var actionTitle: String {
    state.isRunning
      ? "Pause" : state.hasStarted ? "Resume" : "Start \(state.phase.title.lowercased())"
  }

  func tick() {
    now = Date()
    if let finished = state.finishIfDue(at: now, preferences: preferences) {
      message =
        finished == .focus
        ? "Nice work. Time for a break." : "Break complete. Back to focus."
      if preferences.sound { NSSound(named: "Glass")?.play() }
      reconcileFocusMode()
      persist()
    }
    onChange?()
  }

  func toggle() {
    tick()
    message = nil
    if state.isRunning { state.pause(at: now) } else { state.start(at: now) }
    changed()
  }

  func reset() {
    state.reset(preferences: preferences)
    message = nil
    changed()
  }
  func skip() {
    tick()
    state.skip(at: now, preferences: preferences)
    message = nil
    changed()
  }
  func select(_ phase: Phase) {
    state.select(phase, preferences: preferences)
    message = nil
    changed()
  }
  func updatePreferences() {
    if !state.hasStarted { state.reset(preferences: preferences) }
    changed()
  }
  private func changed() {
    now = Date()
    reconcileFocusMode()
    persist()
    onChange?()
  }

  private func reconcileFocusMode() {
    focusModeController.reconcile(
      shouldEnable: preferences.doNotDisturbDuringFocus && state.isFocusSessionActive)
  }

  func prepareForTermination() async {
    await focusModeController.prepareForTermination()
  }

  func persist() {
    if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: "timer") }
    if let data = try? JSONEncoder().encode(preferences) {
      defaults.set(data, forKey: "preferences")
    }
  }

  func setLogin(_ enabled: Bool) {
    Task {
      do {
        if enabled {
          try SMAppService.mainApp.register()
        } else {
          try await SMAppService.mainApp.unregister()
        }
        loginEnabled = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval {
          error = "Approve SitLess in System Settings → General → Login Items."
          SMAppService.openSystemSettingsLoginItems()
        }
      } catch { self.error = "Could not change launch at login: \(error.localizedDescription)" }
    }
  }
}
