import Foundation
import Combine

@Observable
class ReadingTimerService {
    enum TimerState: Equatable {
        case idle
        case running(secondsRemaining: Int)
        case finished

        static func == (lhs: TimerState, rhs: TimerState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case let (.running(a), .running(b)): return a == b
            case (.finished, .finished): return true
            default: return false
            }
        }
    }

    private(set) var state: TimerState = .idle
    let presets: [Int] = [5, 10, 15, 20, 30]

    private var timerCancellable: AnyCancellable?

    var isIdle: Bool {
        if case .idle = state { return true }
        return false
    }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    var isFinished: Bool {
        if case .finished = state { return true }
        return false
    }

    var secondsRemaining: Int {
        if case let .running(seconds) = state { return seconds }
        return 0
    }

    var formattedTimeRemaining: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func start(minutes: Int) {
        guard minutes > 0 else { return }
        let totalSeconds = minutes * 60
        state = .running(secondsRemaining: totalSeconds)

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
        state = .idle
    }

    func dismiss() {
        state = .idle
    }

    private func tick() {
        guard case let .running(seconds) = state else {
            timerCancellable?.cancel()
            timerCancellable = nil
            return
        }

        if seconds <= 1 {
            timerCancellable?.cancel()
            timerCancellable = nil
            state = .finished
        } else {
            state = .running(secondsRemaining: seconds - 1)
        }
    }
}
