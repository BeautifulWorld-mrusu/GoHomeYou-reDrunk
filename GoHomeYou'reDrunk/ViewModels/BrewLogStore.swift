import Foundation

@MainActor
final class BrewLogStore: ObservableObject {
    @Published private(set) var text = ""
    @Published var isVisible = true

    func clear() {
        text = ""
    }

    func logCommand(brewPath: String, arguments: [String]) {
        append("$ \(brewPath) \(arguments.joined(separator: " "))\n")
    }

    func append(_ chunk: String, isStderr: Bool = false) {
        guard !chunk.isEmpty else { return }
        text += chunk
    }

    func appendStatus(_ message: String) {
        append("→ \(message)\n")
    }

    func appendError(_ message: String) {
        append("✗ \(message)\n", isStderr: true)
    }

    func appendSuccess(_ message: String) {
        append("✓ \(message)\n")
    }
}
