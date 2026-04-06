import SwiftUI

struct ReadingTimerView: View {
    let timerService: ReadingTimerService
    @State private var showPopover = false
    @State private var customMinutes = ""

    var body: some View {
        timerButton
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                popoverContent
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleReadingTimer)) { _ in
                showPopover.toggle()
            }
    }

    @ViewBuilder
    private var timerButton: some View {
        switch timerService.state {
        case .idle:
            Button {
                showPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text("Timer")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)

        case .running:
            Button {
                showPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                    Text(timerService.formattedTimeRemaining)
                        .font(.system(size: 12, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)

        case .finished:
            Button {
                timerService.dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text("Done")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .opacity(1.0)
                .animation(
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: timerService.isFinished
                )
            }
            .buttonStyle(.plain)
            .onAppear {
                // Trigger the pulse by the state already being .finished
            }
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if timerService.isRunning {
                runningPopover
            } else {
                idlePopover
            }
        }
        .padding(16)
        .frame(width: 200)
    }

    private var idlePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set Reading Timer")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            // Preset buttons
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 6) {
                ForEach(timerService.presets, id: \.self) { minutes in
                    Button {
                        timerService.start(minutes: minutes)
                        showPopover = false
                    } label: {
                        Text("\(minutes)m")
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Custom input
            HStack(spacing: 8) {
                TextField("Min", text: $customMinutes)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(width: 60)
                    .onSubmit { startCustomTimer() }

                Button("Start") {
                    startCustomTimer()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(Int(customMinutes) == nil || Int(customMinutes)! <= 0)
            }
        }
    }

    private var runningPopover: some View {
        VStack(spacing: 12) {
            Text(timerService.formattedTimeRemaining)
                .font(.system(size: 28, weight: .light, design: .monospaced))
                .monospacedDigit()

            Text("remaining")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Cancel Timer") {
                timerService.stop()
                showPopover = false
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .font(.system(size: 13))
        }
        .frame(maxWidth: .infinity)
    }

    private func startCustomTimer() {
        guard let minutes = Int(customMinutes), minutes > 0 else { return }
        timerService.start(minutes: minutes)
        customMinutes = ""
        showPopover = false
    }
}
