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
  public var doNotDisturbDuringFocus = false
  public init() {}

  private enum CodingKeys: String, CodingKey {
    case focusMinutes, shortBreakMinutes, longBreakMinutes, sound, doNotDisturbDuringFocus
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    focusMinutes = try values.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 25
    shortBreakMinutes = try values.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? 5
    longBreakMinutes = try values.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? 15
    sound = try values.decodeIfPresent(Bool.self, forKey: .sound) ?? true
    doNotDisturbDuringFocus =
      try values.decodeIfPresent(Bool.self, forKey: .doNotDisturbDuringFocus) ?? false
  }

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
  public var isFocusSessionActive: Bool { phase == .focus && hasStarted }

  public init(preferences: Preferences = Preferences()) {
    remaining = preferences.duration(for: .focus)
    total = remaining
  }

  public func secondsLeft(at now: Date) -> TimeInterval {
    max(0, deadline.map { $0.timeIntervalSince(now) } ?? remaining)
  }

  public func progress(at now: Date) -> Double {
    min(1, max(0, secondsLeft(at: now) / max(1, total)))
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

  public mutating func skip(at now: Date, preferences: Preferences) {
    if phase == .focus {
      completeFocus(at: now)
    } else {
      phase = .focus
    }
    reset(preferences: preferences)
  }

  /// Complete at most one interval, even after a long sleep or relaunch.
  @discardableResult
  public mutating func finishIfDue(at now: Date, preferences: Preferences) -> Phase? {
    guard let deadline, now >= deadline else { return nil }
    let finished = phase
    if phase == .focus {
      completeFocus(at: deadline)
    } else {
      phase = .focus
    }
    reset(preferences: preferences)
    start(at: now)
    return finished
  }

  private mutating func completeFocus(at date: Date) {
    completedInCycle += 1
    completedDates.append(date)
    completedDates = Array(completedDates.suffix(1000))
    phase = completedInCycle >= 4 ? .longBreak : .shortBreak
    if completedInCycle >= 4 { completedInCycle = 0 }
  }

  public func completedToday(at now: Date, calendar: Calendar = .current) -> Int {
    completedDates.filter { calendar.isDate($0, inSameDayAs: now) }.count
  }

  public func completedThisWeek(at now: Date, calendar: Calendar = .current) -> Int {
    completed(in: .weekOfYear, at: now, calendar: calendar)
  }

  public func completedThisMonth(at now: Date, calendar: Calendar = .current) -> Int {
    completed(in: .month, at: now, calendar: calendar)
  }

  public var completedLifetime: Int { completedDates.count }

  public func completionCountsByDay(calendar: Calendar = .current) -> [Date: Int] {
    Dictionary(grouping: completedDates, by: calendar.startOfDay(for:))
      .mapValues(\.count)
  }

  public func currentStreak(at now: Date, calendar: Calendar = .current) -> Int {
    let activeDays = Set(completionCountsByDay(calendar: calendar).keys)
    let today = calendar.startOfDay(for: now)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
    guard activeDays.contains(today) || yesterday.map(activeDays.contains) == true else { return 0 }

    var cursor = activeDays.contains(today) ? today : yesterday!
    var streak = 0
    while activeDays.contains(cursor) {
      streak += 1
      guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
      cursor = previous
    }
    return streak
  }

  public func longestStreak(calendar: Calendar = .current) -> Int {
    let activeDays = completionCountsByDay(calendar: calendar).keys.sorted()
    guard !activeDays.isEmpty else { return 0 }

    var longest = 1
    var current = 1
    for index in activeDays.indices.dropFirst() {
      let previous = activeDays[activeDays.index(before: index)]
      if calendar.dateComponents([.day], from: previous, to: activeDays[index]).day == 1 {
        current += 1
        longest = max(longest, current)
      } else {
        current = 1
      }
    }
    return longest
  }

  private func completed(
    in component: Calendar.Component, at now: Date, calendar: Calendar
  ) -> Int {
    guard let interval = calendar.dateInterval(of: component, for: now) else { return 0 }
    return completedDates.filter(interval.contains).count
  }
}
