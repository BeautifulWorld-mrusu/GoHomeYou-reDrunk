import SwiftUI

struct CaskRowView: View {
    let cask: BrewCaskInfo
    let icon: NSImage

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(cask.displayName)
                    .font(.headline)
                Text(cask.token)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let description = cask.desc, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if let version = cask.installedVersion {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(version)
                        .font(.caption.monospaced())
                    if cask.outdated == true {
                        Text("Update available")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
