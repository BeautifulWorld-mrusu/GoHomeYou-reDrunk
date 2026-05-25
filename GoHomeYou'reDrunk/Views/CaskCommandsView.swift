import SwiftUI

struct CaskCommandsView: View {
    let commands: [BrewCaskCommand]
    let brewPath: String
    let isBusy: Bool
    let onCopy: (BrewCaskCommand) -> Void
    let onRun: (BrewCaskCommand) -> Void

    var body: some View {
        GroupBox("Available commands") {
            if commands.isEmpty {
                Text("Select a cask to see related brew commands.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("These are the brew invocations for the current selection. Run them here to stream output in the live log, or copy to use in Terminal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(commands) { command in
                        commandRow(command)
                        if command.id != commands.last?.id {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func commandRow(_ command: BrewCaskCommand) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(command.title)
                    .font(.headline)
                if command.isDestructive {
                    Text("Destructive")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }
            }

            Text(command.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(command.displayCommand(brewPath: brewPath))
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack(spacing: 8) {
                Button("Copy") {
                    onCopy(command)
                }

                Button("Run") {
                    onRun(command)
                }
                .disabled(isBusy)
            }
            .controlSize(.small)
        }
    }
}
