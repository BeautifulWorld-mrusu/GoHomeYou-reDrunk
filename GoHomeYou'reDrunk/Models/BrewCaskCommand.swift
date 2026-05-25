import Foundation

struct BrewCaskCommand: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let arguments: [String]
    let isDestructive: Bool

    func displayCommand(brewPath: String = "brew") -> String {
        ([brewPath] + arguments).joined(separator: " ")
    }

    static func commands(for cask: BrewCaskInfo) -> [BrewCaskCommand] {
        let token = cask.token
        return [
            BrewCaskCommand(
                id: "info",
                title: "Info",
                summary: "Show cask metadata, versions, and install location.",
                arguments: ["info", "--cask", token],
                isDestructive: false
            ),
            BrewCaskCommand(
                id: "upgrade",
                title: "Upgrade",
                summary: "Upgrade this cask to the latest version offered by Homebrew.",
                arguments: ["upgrade", "--cask", token],
                isDestructive: false
            ),
            BrewCaskCommand(
                id: "reinstall",
                title: "Reinstall",
                summary: "Reinstall the cask using the same options as the original install.",
                arguments: ["reinstall", "--cask", token],
                isDestructive: false
            ),
            BrewCaskCommand(
                id: "outdated",
                title: "Check outdated",
                summary: "Print whether this cask has a newer version available.",
                arguments: ["outdated", "--cask", token],
                isDestructive: false
            ),
            BrewCaskCommand(
                id: "uninstall",
                title: "Uninstall",
                summary: "Remove the cask application.",
                arguments: ["uninstall", "--cask", token],
                isDestructive: true
            ),
            BrewCaskCommand(
                id: "uninstall-zap",
                title: "Uninstall and zap",
                summary: "Uninstall and remove leftover support files defined by the cask.",
                arguments: ["uninstall", "--cask", "--zap", token],
                isDestructive: true
            ),
        ]
    }

    static func commands(for casks: [BrewCaskInfo]) -> [BrewCaskCommand] {
        guard let first = casks.first else { return [] }
        if casks.count == 1 {
            return commands(for: first)
        }

        let tokens = casks.map(\.token)
        var upgradeArgs = ["upgrade", "--cask"]
        upgradeArgs.append(contentsOf: tokens)

        var uninstallArgs = ["uninstall", "--cask"]
        uninstallArgs.append(contentsOf: tokens)

        var zapArgs = ["uninstall", "--cask", "--zap"]
        zapArgs.append(contentsOf: tokens)

        return [
            BrewCaskCommand(
                id: "upgrade-selected",
                title: "Upgrade selected",
                summary: "Upgrade all selected casks in one command.",
                arguments: upgradeArgs,
                isDestructive: false
            ),
            BrewCaskCommand(
                id: "uninstall-selected",
                title: "Uninstall selected",
                summary: "Uninstall all selected casks.",
                arguments: uninstallArgs,
                isDestructive: true
            ),
            BrewCaskCommand(
                id: "uninstall-zap-selected",
                title: "Uninstall and zap selected",
                summary: "Uninstall selected casks and remove their support files.",
                arguments: zapArgs,
                isDestructive: true
            ),
            BrewCaskCommand(
                id: "outdated-all",
                title: "Check outdated (all casks)",
                summary: "List every installed cask that has an update available.",
                arguments: ["outdated", "--cask"],
                isDestructive: false
            ),
            BrewCaskCommand(
                id: "info-first",
                title: "Info (\(first.displayName))",
                summary: "Select a single app to see its full command list. Showing info for the first selection.",
                arguments: ["info", "--cask", first.token],
                isDestructive: false
            ),
        ]
    }
}
