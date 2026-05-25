import Foundation

enum BrewServiceError: LocalizedError {
    case brewNotFound
    case commandFailed(String)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .brewNotFound:
            return "Homebrew was not found. Install it from https://brew.sh or ensure it is on your PATH."
        case .commandFailed(let message):
            return message
        case .invalidOutput:
            return "Homebrew returned unexpected output."
        }
    }
}

actor BrewService {
    static let shared = BrewService()

    private var cachedBrewURL: URL?
    private let infoBatchSize = 25

    func brewExecutable() throws -> URL {
        if let cachedBrewURL {
            return cachedBrewURL
        }

        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
        ]

        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            let url = URL(fileURLWithPath: path)
            cachedBrewURL = url
            return url
        }

        if let path = Self.pathFromShell() {
            let url = URL(fileURLWithPath: path)
            cachedBrewURL = url
            return url
        }

        throw BrewServiceError.brewNotFound
    }

    func brewPathForDisplay() async -> String {
        (try? brewExecutable().path) ?? "brew"
    }

    func listInstalledCasks() async throws -> [BrewCaskInfo] {
        let tokens = try await runBrew(arguments: ["list", "--cask"])
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        guard !tokens.isEmpty else { return [] }

        var allCasks: [BrewCaskInfo] = []
        allCasks.reserveCapacity(tokens.count)

        for batchStart in stride(from: 0, to: tokens.count, by: infoBatchSize) {
            let batchEnd = min(batchStart + infoBatchSize, tokens.count)
            let batch = Array(tokens[batchStart..<batchEnd])
            let casks = try await fetchCaskInfo(tokens: batch)
            allCasks.append(contentsOf: casks)
        }

        return allCasks.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func runBrewStreaming(arguments: [String]) -> AsyncThrowingStream<BrewStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let brew = try await self.brewExecutable()
                    try await Self.streamProcess(
                        executable: brew,
                        arguments: arguments,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func fetchCaskInfo(tokens: [String]) async throws -> [BrewCaskInfo] {
        var arguments = ["info", "--cask", "--json=v2"]
        arguments.append(contentsOf: tokens)

        let output = try await runBrew(arguments: arguments, treatNonZeroAsError: true)
        guard let data = output.data(using: .utf8) else {
            throw BrewServiceError.invalidOutput
        }

        let response = try JSONDecoder().decode(BrewInfoResponse.self, from: data)
        return response.casks
    }

    private func runBrew(arguments: [String], treatNonZeroAsError: Bool = false) async throws -> String {
        let brew = try brewExecutable()

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try Self.runProcess(executable: brew, arguments: arguments)
                    if treatNonZeroAsError, result.exitCode != 0 {
                        let message = result.stderr.isEmpty ? result.stdout : result.stderr
                        continuation.resume(throwing: BrewServiceError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines)))
                        return
                    }
                    continuation.resume(returning: result.stdout)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func streamProcess(
        executable: URL,
        arguments: [String],
        continuation: AsyncThrowingStream<BrewStreamEvent, Error>.Continuation
    ) async throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        let readGroup = DispatchGroup()

        func streamHandle(_ handle: FileHandle, isStderr: Bool) {
            readGroup.enter()
            handle.readabilityHandler = { activeHandle in
                let data = activeHandle.availableData
                if data.isEmpty {
                    activeHandle.readabilityHandler = nil
                    readGroup.leave()
                    return
                }
                if let chunk = String(data: data, encoding: .utf8) {
                    continuation.yield(.output(chunk, isStderr: isStderr))
                }
            }
        }

        streamHandle(stdoutHandle, isStderr: false)
        streamHandle(stderrHandle, isStderr: true)

        try process.run()

        readGroup.notify(queue: .global(qos: .userInitiated)) {
            process.waitUntilExit()
            continuation.yield(.finished(exitCode: process.terminationStatus))
            if process.terminationStatus != 0 {
                continuation.finish(throwing: BrewServiceError.commandFailed("brew exited with status \(process.terminationStatus)"))
            } else {
                continuation.finish()
            }
        }
    }

    private static func runProcess(executable: URL, arguments: [String]) throws -> (stdout: String, stderr: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return (stdout, stderr, process.terminationStatus)
    }

    private static func pathFromShell() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "command -v brew"]
        process.environment = ProcessInfo.processInfo.environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else {
                return nil
            }
            return path
        } catch {
            return nil
        }
    }
}
