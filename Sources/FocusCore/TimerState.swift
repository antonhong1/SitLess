import Foundation

public enum Phase: String, Codable, CaseIterable, Sendable {
  case focus, shortBreak, longBreak
  public var title: String {
    switch self {
    case .focus: "Focus"
    case .shortBreak: "Short break"
    case .longBreak: "Long break"
    }
  }
}

public struct Preferences: Codable, Equatable, Sendable {
  public var focusMinutes = 25
  public var shortBreakMinutes = 5
  public var longBreakMinutes = 15
  public var sound = true
  public var notifications = false
  public init() {}
  public func duration(for phase: Phase) -> TimeInterval {
    let minutes =
      switch phase {
      case .focus: focusMinutes
      case .shortBreak: shortBreakMinutes
      case .longBreak: longBreakMinutes
      }
    return Double(min(180, max(1, minutes))) * 60
  }
}

public struct TimerState: Codable, Sendable {
  public private(set) var phase: Phase = .focus
  public private(set) var deadline: Date?
  public private(set) var remaining: TimeInterval = 25 * 60
  public private(set) var total: TimeInterval = 25 * 60
  public private(set) var completedInCycle = 0
  public private(set) var completedDates: [Date] = []
  public private(set) var hasStarted = false
  public var isRunning: Bool { deadline != nil }

  public init(preferences: Preferences = Preferences()) {
    remaining = preferences.duration(for: .focus)
    total = remaining
  }

  public func secondsLeft(at now: Date) -> TimeInterval {
    max(0, deadline.map { $0.timeIntervalSince(now) } ?? remaining)
  }

  public mutating func start(at now: Date) {
    guard !isRunning else { return }
    deadline = now.addingTimeInterval(remaining)
    hasStarted = true
  }

  public mutating func pause(at now: Date) {
    guard isRunning else { return }
    remaining = secondsLeft(at: now)
    deadline = nil
  }

  public mutating func reset(preferences: Preferences) {
    deadline = nil
    hasStarted = false
    remaining = preferences.duration(for: phase)
    total = remaining
  }

  public mutating func select(_ phase: Phase, preferences: Preferences) {
    self.phase = phase
    reset(preferences: preferences)
  }

  public mutating func skip(preferences: Preferences) {
    phase = phase == .focus ? .shortBreak : .focus
    reset(preferences: preferences)
  }

  /// Complete at most one interval, even after a long sleep or relaunch.
  @discardableResult
  public mutating func finishIfDue(at now: Date, preferences: Preferences) -> Phase? {
    guard let deadline, now >= deadline else { return nil }
    let finished = phase
    if phase == .focus {
      completedInCycle += 1
      completedDates.append(deadline)
      completedDates = Array(completedDates.suffix(1000))
      phase = completedInCycle >= 4 ? .longBreak : .shortBreak
      if completedInCycle >= 4 { completedInCycle = 0 }
    } else {
      phase = .focus
    }
    reset(preferences: preferences)
    return finished
  }

  public func completedToday(at now: Date, calendar: Calendar = .current) -> Int {
    completedDates.filter { calendar.isDate($0, inSameDayAs: now) }.count
  }
}
