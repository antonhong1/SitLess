import FocusCore
import SwiftUI

private enum PanelPage {
  case timer, settings, stats
}

struct PanelView: View {
  @Bindable var store: TimerStore
  @State private var page: PanelPage = .timer
  @State private var pendingPhase: Phase?
  private var accent: Color { store.state.phase == .focus ? .orange : .teal }

  private var title: String {
    switch page {
    case .timer: "SitLess"
    case .settings: "Settings"
    case .stats: "Stats"
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Image(systemName: page == .stats ? "chart.bar.fill" : "timer").foregroundStyle(accent)
        Text(title).font(.system(size: 14, weight: .semibold))
        Spacer()
        Button {
          page = page == .timer ? .settings : .timer
        } label: {
          Image(systemName: page == .timer ? "gearshape" : "xmark")
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(page == .timer ? "Settings" : "Back to timer")
        .help(page == .timer ? "Settings" : "Back to timer")
      }
      .padding(.horizontal, 16).frame(height: 44)
      Divider()
      switch page {
      case .timer: timerView
      case .settings: settingsView
      case .stats: statsView
      }
      Divider()
      HStack {
        Button {
          page = page == .stats ? .timer : .stats
        } label: {
          HStack(spacing: 5) {
            Label(
              "\(store.state.completedToday(at: store.now)) completed today",
              systemImage: "checkmark.circle"
            )
            Image(systemName: page == .stats ? "chevron.down" : "chevron.right")
              .font(.system(size: 8, weight: .semibold))
          }
          .font(.system(size: 11))
          .foregroundStyle(page == .stats ? accent : .secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(page == .stats ? "Back to timer" : "Open focus stats")
        Spacer()
        Button("Quit") {
          store.persist()
          NSApplication.shared.terminate(nil)
        }
        .buttonStyle(.borderless).font(.system(size: 11))
        .keyboardShortcut("q")
      }
      .padding(.horizontal, 16).frame(height: 40)
    }
    .frame(width: 340)
    .background {
      ZStack {
        Rectangle().fill(.regularMaterial)
        Color.white.opacity(0.58)
      }
    }
    .tint(accent)
    .alert(
      "Replace this session?",
      isPresented: Binding(get: { pendingPhase != nil }, set: { if !$0 { pendingPhase = nil } })
    ) {
      Button("Cancel", role: .cancel) { pendingPhase = nil }
      Button("Switch", role: .destructive) {
        if let phase = pendingPhase { store.select(phase) }
        pendingPhase = nil
      }
    } message: {
      Text("The current countdown will be reset. Completed sessions are kept.")
    }
    .alert(
      "SitLess",
      isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
  }

  private var timerView: some View {
    VStack(spacing: 22) {
      Picker(
        "Session",
        selection: Binding(
          get: { store.state.phase },
          set: {
            guard $0 != store.state.phase else { return }
            if store.state.hasStarted { pendingPhase = $0 } else { store.select($0) }
          })
      ) {
        Text("Focus").tag(Phase.focus)
        Text("Short break").tag(Phase.shortBreak)
        Text("Long break").tag(Phase.longBreak)
      }.pickerStyle(.segmented).labelsHidden()

      ZStack {
        Circle().stroke(accent.opacity(0.12), lineWidth: 5)
        Circle().trim(from: 0, to: store.progress)
          .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
          .rotationEffect(.degrees(-90))
        VStack(spacing: 7) {
          Text(store.timeText)
            .font(.system(size: 44, weight: .light, design: .rounded)).monospacedDigit()
            .contentTransition(.identity)
            .accessibilityLabel("\(store.timeText) remaining")
          Text(
            store.state.isRunning
              ? store.state.phase == .focus ? "One thing at a time" : "Take a breath"
              : store.state.hasStarted ? "Paused" : "Ready when you are"
          )
          .font(.system(size: 12)).foregroundStyle(.secondary)
        }
      }.frame(width: 196, height: 196)

      HStack(spacing: 7) {
        ForEach(0..<4) { index in
          Circle().fill(
            index < store.state.completedInCycle ? accent : Color.secondary.opacity(0.18)
          )
          .frame(width: 7, height: 7)
        }
        Text("\(store.state.completedInCycle) of 4 focus sessions")
          .font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 4)
      }.accessibilityElement(children: .combine)

      VStack(spacing: 10) {
        Button(action: { store.toggle() }) {
          Label(store.actionTitle, systemImage: store.state.isRunning ? "pause.fill" : "play.fill")
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity).frame(height: 30)
        }
        .buttonStyle(.borderedProminent).controlSize(.large)
        .keyboardShortcut(.space, modifiers: [])
        HStack {
          Button("Reset", action: { store.reset() }).keyboardShortcut("r")
          Spacer()
          Button("Skip", action: { store.skip() }).keyboardShortcut("s")
        }.buttonStyle(.borderless).font(.system(size: 12)).foregroundStyle(.secondary)
      }
      Text(store.message ?? "A long break after every four focus sessions.")
        .font(.system(size: 11)).foregroundStyle(.secondary)
        .multilineTextAlignment(.center).frame(height: 28)
    }.padding(20)
  }

  private var settingsView: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 12) {
        Text("SESSION LENGTHS").font(.system(size: 10, weight: .semibold)).foregroundStyle(
          .secondary)
        durationRow("Focus", value: $store.preferences.focusMinutes, range: 1...180)
        durationRow("Short break", value: $store.preferences.shortBreakMinutes, range: 1...60)
        durationRow("Long break", value: $store.preferences.longBreakMinutes, range: 1...120)
        Text("Changes apply to the next session or after Reset.")
          .font(.system(size: 11)).foregroundStyle(.secondary)
      }
      Divider()
      Toggle("Play sound when a session ends", isOn: $store.preferences.sound)
      Toggle(
        "Do Not Disturb during focus", isOn: $store.preferences.doNotDisturbDuringFocus)
      Toggle(
        "Launch at login", isOn: Binding(get: { store.loginEnabled }, set: { store.setLogin($0) }))
      Divider()
      VStack(alignment: .leading, spacing: 6) {
        Text("Space to start or pause · ⌘R to reset")
        Text("Shortcuts work while this panel is open.")
        Text("SitLess 1.0 · Built on your Mac")
      }.font(.system(size: 11)).foregroundStyle(.secondary)
    }
    .toggleStyle(.switch).font(.system(size: 12))
    .padding(20)
    .onChange(of: store.preferences) { _, _ in store.updatePreferences() }
  }

  private var statsView: some View {
    let calendar = Calendar.current
    let counts = store.state.completionCountsByDay(calendar: calendar)
    let days = activityDates(calendar: calendar)

    return VStack(alignment: .leading, spacing: 18) {
      Text("FOCUS SUMMARY")
        .sectionLabelStyle()
      HStack(spacing: 0) {
        statColumn("Lifetime", value: store.state.completedLifetime)
        Divider().frame(height: 38)
        statColumn("This week", value: store.state.completedThisWeek(at: store.now))
        Divider().frame(height: 38)
        statColumn("Current streak", value: store.state.currentStreak(at: store.now), suffix: "d")
        Divider().frame(height: 38)
        statColumn("Longest streak", value: store.state.longestStreak(), suffix: "d")
      }

      Divider()

      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text("ACTIVITY")
            .sectionLabelStyle()
          Spacer()
          Text(activityRange(days))
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        HStack(spacing: 4) {
          ForEach(0..<16, id: \.self) { week in
            VStack(spacing: 4) {
              ForEach(0..<7, id: \.self) { weekday in
                let date = days[week * 7 + weekday]
                activityCell(date: date, count: counts[date, default: 0], calendar: calendar)
              }
            }
          }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus activity over the last 16 weeks")
        HStack(spacing: 4) {
          Spacer()
          Text("Less")
          ForEach(0..<4, id: \.self) { level in
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
              .fill(activityColor(for: level))
              .frame(width: 10, height: 10)
          }
          Text("More")
        }
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      }

      Divider()

      HStack(spacing: 0) {
        statColumn("Today", value: store.state.completedToday(at: store.now))
        Divider().frame(height: 38)
        statColumn("This month", value: store.state.completedThisMonth(at: store.now))
        Divider().frame(height: 38)
        statColumn("Active days", value: counts.count)
      }
    }
    .padding(20)
  }

  private func statColumn(_ label: String, value: Int, suffix: String = "") -> some View {
    VStack(spacing: 3) {
      Text("\(value)\(suffix)")
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .monospacedDigit()
      Text(label)
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label), \(value)\(suffix)")
  }

  private func activityDates(calendar: Calendar) -> [Date] {
    let today = calendar.startOfDay(for: store.now)
    let currentWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    let start = calendar.date(byAdding: .weekOfYear, value: -15, to: currentWeek) ?? currentWeek
    return (0..<(16 * 7)).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
  }

  private func activityRange(_ days: [Date]) -> String {
    guard let first = days.first, let last = days.last else { return "" }
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("MMM")
    return "\(formatter.string(from: first)) – \(formatter.string(from: min(last, store.now)))"
  }

  @ViewBuilder
  private func activityCell(date: Date, count: Int, calendar: Calendar) -> some View {
    let isFuture = date > calendar.startOfDay(for: store.now)
    RoundedRectangle(cornerRadius: 3, style: .continuous)
      .fill(isFuture ? Color.clear : activityColor(for: count))
      .frame(width: 14, height: 14)
      .help(isFuture ? "" : "\(date.formatted(date: .abbreviated, time: .omitted)): \(count) focus sessions")
  }

  private func activityColor(for count: Int) -> Color {
    switch count {
    case 0: Color.secondary.opacity(0.1)
    case 1: accent.opacity(0.32)
    case 2: accent.opacity(0.52)
    case 3: accent.opacity(0.74)
    default: accent
    }
  }

  private func durationRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>)
    -> some View
  {
    Stepper(value: value, in: range) {
      HStack {
        Text(title)
        Spacer()
        Text("\(value.wrappedValue) min").monospacedDigit().foregroundStyle(.secondary)
      }
    }
  }
}

private extension View {
  func sectionLabelStyle() -> some View {
    font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
  }
}
