import AppKit
import FocusCore
import Observation
import ServiceManagement
import UserNotifications

@Observable
final class TimerStore {
  var preferences: Preferences
  var state: TimerState
  var now = Date()
  var message: String?
  var error: String?
  var loginEnabled = SMAppService.mainApp.status == .enabled
  var notificationStatus = "Off"
  @ObservationIgnored private var ticker: Timer?
  @ObservationIgnored var onChange: (() -> Void)?
  @ObservationIgnored private var notificationGeneration = 0
  private let defaults = UserDefaults.standard

  init() {
    let loaded = Self.load(Preferences.self, key: "preferences") ?? Preferences()
    preferences = loaded
    state = Self.load(TimerState.self, key: "timer") ?? TimerState(preferences: loaded)
    tick()
    ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.tick() }
    }
    if let ticker { RunLoop.main.add(ticker, forMode: .common) }
    refreshNotificationStatus()
    scheduleNotification()
  }

  private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
    guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }

  var timeText: String {
    let seconds = Int(ceil(state.secondsLeft(at: now)))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }
  var progress: Double { min(1, max(0, 1 - state.secondsLeft(at: now) / max(1, state.total))) }
  var actionTitle: String {
    state.isRunning
      ? "Pause" : state.hasStarted ? "Resume" : "Start \(state.phase.title.lowercased())"
  }

  func tick() {
    now = Date()
    if let finished = state.finishIfDue(at: now, preferences: preferences) {
      message =
        finished == .focus
        ? "Nice work. Your break is ready." : "Break complete. Ready when you are."
      if preferences.sound { NSSound(named: "Glass")?.play() }
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
    state.skip(preferences: preferences)
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
    persist()
    scheduleNotification()
    onChange?()
  }

  func persist() {
    if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: "timer") }
    if let data = try? JSONEncoder().encode(preferences) {
      defaults.set(data, forKey: "preferences")
    }
  }

  func setNotifications(_ enabled: Bool) {
    guard enabled else {
      preferences.notifications = false
      notificationStatus = "Off"
      changed()
      return
    }
    Task {
      do {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [
          .alert
        ])
        preferences.notifications = granted
        if !granted {
          error = "Notifications are blocked. Enable FocusBar in System Settings → Notifications."
        }
        changed()
        refreshNotificationStatus()
      } catch { self.error = "Could not enable notifications: \(error.localizedDescription)" }
    }
  }

  func refreshNotificationStatus() {
    Task {
      let settings = await UNUserNotificationCenter.current().notificationSettings()
      notificationStatus =
        preferences.notifications
        ? (settings.authorizationStatus == .authorized ? "On" : "Blocked in System Settings")
        : "Off"
    }
  }

  private func scheduleNotification() {
    notificationGeneration += 1
    let generation = notificationGeneration
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: ["interval"])
    guard preferences.notifications, let deadline = state.deadline else { return }
    let content = UNMutableNotificationContent()
    content.title = state.phase == .focus ? "Time for a break" : "Ready to focus?"
    content.body =
      state.phase == .focus
      ? "Your focus session is complete. Open FocusBar to start your break."
      : "Your break is complete. Start a new focus session when you're ready."
    let request = UNNotificationRequest(
      identifier: "interval", content: content,
      trigger: UNTimeIntervalNotificationTrigger(
        timeInterval: max(1, deadline.timeIntervalSinceNow), repeats: false))
    Task {
      guard generation == notificationGeneration else { return }
      do {
        try await center.add(request)
        // A pause/reset may have happened while the system accepted this request.
        if generation != notificationGeneration { scheduleNotification() }
      } catch { self.error = "Could not schedule notification: \(error.localizedDescription)" }
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
          error = "Approve FocusBar in System Settings → General → Login Items."
          SMAppService.openSystemSettingsLoginItems()
        }
      } catch { self.error = "Could not change launch at login: \(error.localizedDescription)" }
    }
  }
}
