import Foundation

enum BrewStreamEvent: Sendable {
    case output(String, isStderr: Bool)
    case finished(exitCode: Int32)
}
