import AppKit
import Foundation

@MainActor
final class CaskListViewModel: ObservableObject {
    @Published private(set) var casks: [BrewCaskInfo] = []
    @Published var selection = Set<BrewCaskInfo.ID>()
    @Published var searchText = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isRunningCommand = false
    @Published var errorMessage: String?
    @Published var showUninstallConfirmation = false
    @Published var showUpgradeConfirmation = false
    @Published var showRunCommandConfirmation = false
    @Published var pendingCommand: BrewCaskCommand?
    @Published var zapOnUninstall = false

    let log = BrewLogStore()

    @Published private(set) var brewPathDisplay = "brew"

    var filteredCasks: [BrewCaskInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return casks }
        return casks.filter { cask in
            cask.displayName.localizedCaseInsensitiveContains(query)
                || cask.token.localizedCaseInsensitiveContains(query)
                || (cask.desc?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var selectedCasks: [BrewCaskInfo] {
        casks.filter { selection.contains($0.id) }
    }

    var selectedCommands: [BrewCaskCommand] {
        BrewCaskCommand.commands(for: selectedCasks)
    }

    var hasOutdatedSelection: Bool {
        selectedCasks.contains { $0.outdated == true }
    }

    var isBusy: Bool {
        isLoading || isRunningCommand
    }

    func loadCasks() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        brewPathDisplay = await BrewService.shared.brewPathForDisplay()

        do {
            let loaded = try await BrewService.shared.listInstalledCasks()
            casks = loaded
            selection = selection.intersection(Set(loaded.map(\.id)))
        } catch {
            casks = []
            errorMessage = error.localizedDescription
        }
    }

    func confirmUninstall() {
        guard !selectedCasks.isEmpty else { return }
        showUninstallConfirmation = true
    }

    func confirmUpgrade() {
        guard !selectedCasks.isEmpty else { return }
        showUpgradeConfirmation = true
    }

    func confirmRun(command: BrewCaskCommand) {
        pendingCommand = command
        if command.isDestructive {
            showRunCommandConfirmation = true
        } else {
            Task { await runPendingCommand() }
        }
    }

    func uninstallSelected() async {
        let tokens = selectedCasks.map(\.token)
        guard !tokens.isEmpty else { return }

        showUninstallConfirmation = false

        for token in tokens {
            var arguments = ["uninstall", "--cask"]
            if zapOnUninstall {
                arguments.append("--zap")
            }
            arguments.append(token)
            await runBrewArguments(arguments, refreshAfter: false)
        }

        selection.removeAll()
        await loadCasks()
    }

    func upgradeSelected() async {
        let tokens = selectedCasks.map(\.token)
        guard !tokens.isEmpty else { return }

        showUpgradeConfirmation = false
        var arguments = ["upgrade", "--cask"]
        arguments.append(contentsOf: tokens)
        await runBrewArguments(arguments, refreshAfter: true)
    }

    func runPendingCommand() async {
        guard let command = pendingCommand else { return }
        showRunCommandConfirmation = false
        pendingCommand = nil
        await runBrewArguments(command.arguments, refreshAfter: shouldRefresh(after: command))
    }

    func copyCommand(_ command: BrewCaskCommand) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command.displayCommand(brewPath: brewPathDisplay), forType: .string)
    }

    func icon(for cask: BrewCaskInfo) -> NSImage {
        if let path = cask.applicationPath,
           FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)
            ?? NSImage(named: NSImage.applicationIconName)!
    }

    private func shouldRefresh(after command: BrewCaskCommand) -> Bool {
        let root = command.arguments.first ?? ""
        return ["upgrade", "uninstall", "reinstall"].contains(root)
    }

    private func runBrewArguments(_ arguments: [String], refreshAfter: Bool) async {
        isRunningCommand = true
        errorMessage = nil
        log.isVisible = true
        log.logCommand(brewPath: brewPathDisplay, arguments: arguments)
        defer { isRunningCommand = false }

        let stream = await BrewService.shared.runBrewStreaming(arguments: arguments)

        do {
            for try await event in stream {
                switch event {
                case .output(let chunk, let isStderr):
                    log.append(chunk, isStderr: isStderr)
                case .finished(let exitCode):
                    if exitCode == 0 {
                        log.appendSuccess("Done (exit 0)")
                    }
                }
            }
            if refreshAfter {
                log.appendStatus("Refreshing cask list…")
                await loadCasks()
            }
        } catch {
            log.appendError(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }
}
