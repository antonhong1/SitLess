import FocusCore
import Foundation

struct TimerStateTests {
  let start = Date(timeIntervalSince1970: 1_000_000)
  let preferences = Preferences()

  func pauseAndResumePreserveRemainingTime() {
    var timer = TimerState()
    timer.start(at: start)
    timer.pause(at: start.addingTimeInterval(90))
    expect(timer.remaining == 1410)
    expect(!timer.isRunning)
    timer.start(at: start.addingTimeInterval(600))
    expect(timer.secondsLeft(at: start.addingTimeInterval(630)) == 1380)
  }

  func fourCompletedFocusSessionsGiveLongBreak() {
    var timer = TimerState()
    for index in 1...4 {
      timer.start(at: start)
      expect(
        timer.finishIfDue(at: start.addingTimeInterval(1500), preferences: preferences) == .focus)
      expect(timer.phase == (index == 4 ? .longBreak : .shortBreak))
      expect(!timer.isRunning)
      timer.skip(preferences: preferences)
    }
    expect(timer.completedInCycle == 0)
    expect(timer.completedDates.count == 4)
  }

  func wakingAfterHoursCompletesOnlyOneInterval() {
    var timer = TimerState()
    timer.start(at: start)
    let wake = start.addingTimeInterval(30_000)
    expect(timer.finishIfDue(at: wake, preferences: preferences) == .focus)
    expect(timer.finishIfDue(at: wake, preferences: preferences) == nil)
    expect(timer.completedDates.count == 1)
    expect(timer.remaining == 300)
    expect(!timer.isRunning)
  }

  func skipDoesNotCountAsCompletion() {
    var timer = TimerState()
    timer.start(at: start)
    timer.skip(preferences: preferences)
    expect(timer.phase == .shortBreak)
    expect(timer.completedDates.isEmpty)
    expect(timer.completedInCycle == 0)
  }

  func resetUsesNewDurationWithoutAwardingCompletion() {
    var timer = TimerState()
    var updated = preferences
    updated.focusMinutes = 50
    timer.start(at: start)
    timer.reset(preferences: updated)
    expect(timer.remaining == 3000)
    expect(!timer.hasStarted)
    expect(timer.completedDates.isEmpty)
  }

  func persistenceRetainsDeadlineAndPausedState() throws {
    var timer = TimerState()
    timer.start(at: start)
    let restored = try JSONDecoder().decode(TimerState.self, from: JSONEncoder().encode(timer))
    expect(restored.secondsLeft(at: start.addingTimeInterval(60)) == 1440)
    timer.pause(at: start.addingTimeInterval(120))
    let paused = try JSONDecoder().decode(TimerState.self, from: JSONEncoder().encode(timer))
    expect(paused.remaining == 1380)
    expect(!paused.isRunning)
    expect(paused.hasStarted)
  }

  func todayCountRespectsDayBoundary() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let day = Date(timeIntervalSince1970: 1_728_000)
    var timer = TimerState()
    timer.start(at: day)
    timer.finishIfDue(at: day.addingTimeInterval(1500), preferences: preferences)
    expect(timer.completedToday(at: day.addingTimeInterval(1600), calendar: calendar) == 1)
    expect(timer.completedToday(at: day.addingTimeInterval(86400), calendar: calendar) == 0)
  }

  func weekAndMonthCountsRespectCalendarBoundaries() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 2
    let now = calendar.date(from: DateComponents(year: 2024, month: 9, day: 18, hour: 12))!
    let starts = [
      calendar.date(from: DateComponents(year: 2024, month: 9, day: 18, hour: 9))!,
      calendar.date(from: DateComponents(year: 2024, month: 9, day: 16, hour: 9))!,
      calendar.date(from: DateComponents(year: 2024, month: 9, day: 5, hour: 9))!,
      calendar.date(from: DateComponents(year: 2024, month: 8, day: 25, hour: 9))!,
    ]
    var timer = TimerState()
    for start in starts {
      timer.start(at: start)
      timer.finishIfDue(at: start.addingTimeInterval(1500), preferences: preferences)
      timer.skip(preferences: preferences)
    }
    expect(timer.completedToday(at: now, calendar: calendar) == 1)
    expect(timer.completedThisWeek(at: now, calendar: calendar) == 2)
    expect(timer.completedThisMonth(at: now, calendar: calendar) == 3)
  }

  func boundsPreventInvalidDurations() {
    var p = preferences
    p.focusMinutes = -1
    p.shortBreakMinutes = 10000
    expect(p.duration(for: .focus) == 60)
    expect(p.duration(for: .shortBreak) == 10800)
  }

  func noCompletionBeforeDeadlineAndStartIsIdempotent() {
    var timer = TimerState()
    timer.start(at: start)
    timer.start(at: start.addingTimeInterval(30))
    expect(timer.deadline == start.addingTimeInterval(1500))
    expect(timer.finishIfDue(at: start.addingTimeInterval(1499), preferences: preferences) == nil)
    expect(timer.secondsLeft(at: start.addingTimeInterval(9999)) == 0)
  }

  func completedBreakReturnsToFocusWithoutCredit() {
    var timer = TimerState()
    timer.select(.longBreak, preferences: preferences)
    timer.start(at: start)
    expect(
      timer.finishIfDue(at: start.addingTimeInterval(900), preferences: preferences) == .longBreak)
    expect(timer.phase == .focus)
    expect(timer.remaining == 1500)
    expect(timer.completedDates.isEmpty)
  }
}

func expect(_ condition: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
  precondition(condition(), "Check failed", file: file, line: line)
}

@main struct RunChecks {
  static func main() throws {
    let tests = TimerStateTests()
    tests.pauseAndResumePreserveRemainingTime()
    print("PASS pauseAndResumePreserveRemainingTime")
    tests.fourCompletedFocusSessionsGiveLongBreak()
    print("PASS fourCompletedFocusSessionsGiveLongBreak")
    tests.wakingAfterHoursCompletesOnlyOneInterval()
    print("PASS wakingAfterHoursCompletesOnlyOneInterval")
    tests.skipDoesNotCountAsCompletion()
    print("PASS skipDoesNotCountAsCompletion")
    tests.resetUsesNewDurationWithoutAwardingCompletion()
    print("PASS resetUsesNewDurationWithoutAwardingCompletion")
    try tests.persistenceRetainsDeadlineAndPausedState()
    print("PASS persistenceRetainsDeadlineAndPausedState")
    tests.todayCountRespectsDayBoundary()
    print("PASS todayCountRespectsDayBoundary")
    tests.weekAndMonthCountsRespectCalendarBoundaries()
    print("PASS weekAndMonthCountsRespectCalendarBoundaries")
    tests.boundsPreventInvalidDurations()
    print("PASS boundsPreventInvalidDurations")
    tests.noCompletionBeforeDeadlineAndStartIsIdempotent()
    print("PASS noCompletionBeforeDeadlineAndStartIsIdempotent")
    tests.completedBreakReturnsToFocusWithoutCredit()
    print("PASS completedBreakReturnsToFocusWithoutCredit")
    print("11 timer regression checks passed")
  }
}
