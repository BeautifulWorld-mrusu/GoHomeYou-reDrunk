import Foundation

struct BrewInfoResponse: Decodable {
    let casks: [BrewCaskInfo]
}

struct BrewCaskInfo: Decodable, Identifiable, Hashable {
    let token: String
    let name: [String]
    let desc: String?
    let version: String?
    let installed: String?
    let outdated: Bool?
    let artifacts: [BrewArtifact]?

    var id: String { token }

    var displayName: String {
        name.first ?? token
    }

    var installedVersion: String? {
        installed ?? version
    }

    var applicationPath: String? {
        guard let artifacts else { return nil }
        for artifact in artifacts {
            if case .app(let apps) = artifact {
                if let app = apps.first {
                    if app.hasPrefix("/") {
                        return app
                    }
                    return "/Applications/\(app)"
                }
            }
        }
        return nil
    }
}

enum BrewArtifact: Decodable, Hashable {
    case app([String])
    case other

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        if container.contains(.app) {
            self = .app(try container.decode([String].self, forKey: .app))
        } else {
            self = .other
        }
    }

    private enum DynamicCodingKeys: String, CodingKey {
        case app
    }
}
