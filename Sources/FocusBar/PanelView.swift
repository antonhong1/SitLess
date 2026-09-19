import FocusCore
import SwiftUI

struct PanelView: View {
  @Bindable var store: TimerStore
  @State private var settings = false
  @State private var pendingPhase: Phase?
  private var accent: Color { store.state.phase == .focus ? .orange : .teal }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Image(systemName: "timer").foregroundStyle(accent)
        Text(settings ? "Settings" : "FocusBar").font(.system(size: 14, weight: .semibold))
        Spacer()
        Button {
          settings.toggle()
        } label: {
          Image(systemName: settings ? "xmark" : "gearshape")
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(settings ? "Close settings" : "Settings")
        .help(settings ? "Back to timer" : "Settings")
      }
      .padding(.horizontal, 16).frame(height: 44)
      Divider()
      if settings { settingsView } else { timerView }
      Divider()
      HStack {
        Label(
          "\(store.state.completedToday(at: store.now)) completed today",
          systemImage: "checkmark.circle"
        )
        .font(.system(size: 11)).foregroundStyle(.secondary)
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
    .background(.regularMaterial)
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
      "FocusBar",
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
      VStack(alignment: .leading, spacing: 5) {
        Toggle(
          "Show notifications",
          isOn: Binding(
            get: { store.preferences.notifications }, set: { store.setNotifications($0) }))
        Text(store.notificationStatus).font(.system(size: 11)).foregroundStyle(.secondary)
      }
      Toggle(
        "Launch at login", isOn: Binding(get: { store.loginEnabled }, set: { store.setLogin($0) }))
      Divider()
      VStack(alignment: .leading, spacing: 6) {
        Text("Space to start or pause · ⌘R to reset")
        Text("Shortcuts work while this panel is open.")
        Text("FocusBar 1.0 · Built on your Mac")
      }.font(.system(size: 11)).foregroundStyle(.secondary)
    }
    .toggleStyle(.switch).font(.system(size: 12))
    .padding(20)
    .onChange(of: store.preferences) { _, _ in store.updatePreferences() }
    .onAppear { store.refreshNotificationStatus() }
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
