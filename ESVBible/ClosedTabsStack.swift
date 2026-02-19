import Foundation

final class ClosedTabsStack {
    static let shared = ClosedTabsStack()

    private let key = "closedTabsStack"
    private let maxSize = 20
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func push(_ position: ChapterPosition) {
        var stack = load()
        stack.append(position)
        if stack.count > maxSize { stack.removeFirst(stack.count - maxSize) }
        save(stack)
    }

    func pop() -> ChapterPosition? {
        var stack = load()
        guard !stack.isEmpty else { return nil }
        let last = stack.removeLast()
        save(stack)
        return last
    }

    func clear() {
        save([])
    }

    private func load() -> [ChapterPosition] {
        guard let data = defaults.data(forKey: key),
              let stack = try? JSONDecoder().decode([ChapterPosition].self, from: data) else {
            return []
        }
        return stack
    }

    private func save(_ stack: [ChapterPosition]) {
        if let data = try? JSONEncoder().encode(stack) {
            defaults.set(data, forKey: key)
        }
    }
}
