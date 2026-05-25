import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CaskListViewModel()

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailColumn
        }
        .frame(minWidth: 800, minHeight: 560)
        .task {
            await viewModel.loadCasks()
        }
        .alert("Uninstall selected apps?", isPresented: $viewModel.showUninstallConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Uninstall", role: .destructive) {
                Task { await viewModel.uninstallSelected() }
            }
        } message: {
            uninstallAlertMessage
        }
        .alert("Update selected apps?", isPresented: $viewModel.showUpgradeConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Update") {
                Task { await viewModel.upgradeSelected() }
            }
        } message: {
            upgradeAlertMessage
        }
        .alert("Run destructive command?", isPresented: $viewModel.showRunCommandConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.pendingCommand = nil
            }
            Button("Run", role: .destructive) {
                Task { await viewModel.runPendingCommand() }
            }
        } message: {
            if let command = viewModel.pendingCommand {
                Text("This will run:\n\n\(command.displayCommand(brewPath: viewModel.brewPathDisplay))")
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "wineglass.fill")
                    .foregroundStyle(.purple)
                Text("Go Home You're Drunk")
                    .font(.headline)
            }
            .padding()

            Text("Manage Homebrew cask apps with a GUI.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 8)

            Divider()

            if viewModel.isLoading && viewModel.casks.isEmpty {
                Spacer()
                ProgressView("Loading casks…")
                Spacer()
            } else if let error = viewModel.errorMessage, viewModel.casks.isEmpty {
                Spacer()
                ContentUnavailableView {
                    Label("Could not load apps", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        Task { await viewModel.loadCasks() }
                    }
                }
                Spacer()
            } else {
                caskList
            }
        }
        .navigationSplitViewColumnWidth(min: 320, ideal: 380)
        .toolbar { sidebarToolbar }
    }

    private var caskList: some View {
        List(viewModel.filteredCasks, selection: $viewModel.selection) { cask in
            CaskRowView(cask: cask, icon: viewModel.icon(for: cask))
                .tag(cask.id)
        }
        .listStyle(.inset)
        .searchable(text: $viewModel.searchText, prompt: "Search apps")
        .overlay {
            if !viewModel.isLoading && viewModel.filteredCasks.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
    }

    @ToolbarContentBuilder
    private var sidebarToolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                Task { await viewModel.loadCasks() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isBusy)

            Button {
                viewModel.confirmUpgrade()
            } label: {
                Label("Update", systemImage: "arrow.down.circle")
            }
            .disabled(viewModel.selection.isEmpty || viewModel.isBusy)

            Button(role: .destructive) {
                viewModel.confirmUninstall()
            } label: {
                Label("Uninstall", systemImage: "trash")
            }
            .disabled(viewModel.selection.isEmpty || viewModel.isBusy)

            Button {
                viewModel.log.isVisible.toggle()
            } label: {
                Label("Log", systemImage: viewModel.log.isVisible ? "terminal.fill" : "terminal")
            }
        }
    }

    private var detailColumn: some View {
        VStack(spacing: 0) {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if viewModel.log.isVisible {
                Divider()
                BrewLogPanelView(log: viewModel.log)
            } else if viewModel.isRunningCommand || !viewModel.log.text.isEmpty {
                Divider()
                HStack {
                    Button {
                        viewModel.log.isVisible = true
                    } label: {
                        Label("Show live log", systemImage: "terminal")
                    }
                    .buttonStyle(.link)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.bar)
            }

            bottomBar
        }
    }

    private var detailContent: some View {
        Group {
            if viewModel.isRunningCommand && viewModel.selectedCasks.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Running brew…")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.selectedCasks.count == 1, let cask = viewModel.selectedCasks.first {
                CaskDetailView(
                    cask: cask,
                    icon: viewModel.icon(for: cask),
                    commands: viewModel.selectedCommands,
                    brewPath: viewModel.brewPathDisplay,
                    isBusy: viewModel.isBusy,
                    onCopy: viewModel.copyCommand,
                    onRun: { viewModel.confirmRun(command: $0) }
                )
            } else if viewModel.selectedCasks.count > 1 {
                MultiSelectionDetailView(
                    count: viewModel.selectedCasks.count,
                    casks: viewModel.selectedCasks,
                    commands: viewModel.selectedCommands,
                    brewPath: viewModel.brewPathDisplay,
                    isBusy: viewModel.isBusy,
                    onCopy: viewModel.copyCommand,
                    onRun: { viewModel.confirmRun(command: $0) }
                )
            } else {
                ContentUnavailableView {
                    Label("Select an app", systemImage: "cursorarrow.click")
                } description: {
                    Text("Choose one or more Homebrew cask apps to see details, available brew commands, update, or uninstall.")
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Toggle("Also remove support files (--zap)", isOn: $viewModel.zapOnUninstall)
                    .font(.caption)

                Spacer()

                if let error = viewModel.errorMessage, !viewModel.casks.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .frame(maxWidth: 280, alignment: .trailing)
                }

                if viewModel.hasOutdatedSelection {
                    Text("Update available")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text("\(viewModel.casks.count) cask\(viewModel.casks.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    @ViewBuilder
    private var uninstallAlertMessage: some View {
        let count = viewModel.selectedCasks.count
        let names = viewModel.selectedCasks.prefix(3).map(\.displayName).joined(separator: ", ")
        let suffix = count > 3 ? " and \(count - 3) more" : ""

        if viewModel.zapOnUninstall {
            Text("Runs `brew uninstall --cask --zap` for \(count) app\(count == 1 ? "" : "s"): \(names)\(suffix). Output streams to the live log.")
        } else {
            Text("Runs `brew uninstall --cask` for \(count) app\(count == 1 ? "" : "s"): \(names)\(suffix). Output streams to the live log.")
        }
    }

    @ViewBuilder
    private var upgradeAlertMessage: some View {
        let count = viewModel.selectedCasks.count
        let names = viewModel.selectedCasks.prefix(3).map(\.displayName).joined(separator: ", ")
        let suffix = count > 3 ? " and \(count - 3) more" : ""
        Text("Runs `brew upgrade --cask` for \(count) app\(count == 1 ? "" : "s"): \(names)\(suffix). Output streams to the live log.")
    }
}

struct CaskDetailView: View {
    let cask: BrewCaskInfo
    let icon: NSImage
    let commands: [BrewCaskCommand]
    let brewPath: String
    let isBusy: Bool
    let onCopy: (BrewCaskCommand) -> Void
    let onRun: (BrewCaskCommand) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(cask.displayName)
                            .font(.largeTitle.bold())
                        Text(cask.token)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                if let description = cask.desc {
                    GroupBox("Description") {
                        Text(description)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                GroupBox("Install info") {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        if let version = cask.installedVersion {
                            detailRow("Installed", version)
                        }
                        if let latest = cask.version {
                            detailRow("Latest", latest)
                        }
                        if let path = cask.applicationPath {
                            detailRow("Application", path)
                        }
                        if cask.outdated == true {
                            detailRow("Status", "Update available via Homebrew")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                CaskCommandsView(
                    commands: commands,
                    brewPath: brewPath,
                    isBusy: isBusy,
                    onCopy: onCopy,
                    onRun: onRun
                )
            }
            .padding(24)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}

struct MultiSelectionDetailView: View {
    let count: Int
    let casks: [BrewCaskInfo]
    let commands: [BrewCaskCommand]
    let brewPath: String
    let isBusy: Bool
    let onCopy: (BrewCaskCommand) -> Void
    let onRun: (BrewCaskCommand) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("\(count) apps selected")
                    .font(.title.bold())

                Text("Use Update or Uninstall in the toolbar, or run individual commands below.")
                    .foregroundStyle(.secondary)

                GroupBox("Selected") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(casks) { cask in
                            HStack {
                                Text(cask.displayName)
                                Spacer()
                                if cask.outdated == true {
                                    Text("Update available")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            Text(cask.token)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                CaskCommandsView(
                    commands: commands,
                    brewPath: brewPath,
                    isBusy: isBusy,
                    onCopy: onCopy,
                    onRun: onRun
                )
            }
            .padding(24)
        }
    }
}
