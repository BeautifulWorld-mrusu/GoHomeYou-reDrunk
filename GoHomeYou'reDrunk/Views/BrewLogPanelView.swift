import SwiftUI

struct BrewLogPanelView: View {
    @ObservedObject var log: BrewLogStore
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Live log", systemImage: "terminal")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button("Clear") {
                    log.clear()
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        log.isVisible = false
                    }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .help("Hide log")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    Text(log.text.isEmpty ? "Output from brew commands will appear here." : log.text)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .id("log-bottom")
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: log.text) { _, _ in
                    proxy.scrollTo("log-bottom", anchor: .bottom)
                }
            }
        }
        .frame(minHeight: 120, idealHeight: 160, maxHeight: 280)
    }
}
