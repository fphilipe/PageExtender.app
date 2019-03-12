import os
import SafariServices

private typealias Type = String
private typealias Name = String
private typealias Content = String

class SafariExtensionHandler: SFSafariExtensionHandler {
    private lazy var localConfig = Config(userDefaults: UserDefaults.standard, secure: true)

    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo _: [String: Any]?) {
        os_log("Message received: '%{public}@'", messageName)
        guard messageName == "load" else { return }

        updateConfig()

        page.getPropertiesWithCompletionHandler {
            guard let host = $0?.url?.host else { return }

            let basenames = fileBasenames(forHost: host)

            let keysWithValues = Config.FileType.allCases.map { fileType -> (Type, [Name: Content]) in
                let files: [Name: Content]
                if let url = self.localConfig.url(for: fileType) {
                    files = loadFiles(from: url, basenames: basenames, extension: fileType.rawValue)
                } else {
                    files = [:]
                }

                return (fileType.rawValue, files)
            }

            let data = Dictionary(uniqueKeysWithValues: keysWithValues)
            page.dispatchMessageToScript(withName: "onload", userInfo: data)
        }
    }

    private func updateConfig() {
        Config.FileType.allCases.forEach { fileType in
            let sharedURL = Config.shared.url(for: fileType)
            let localURL = localConfig.url(for: fileType)
            if localURL != sharedURL {
                os_log(
                    "URLs differ, updating local config: %{public}@, %{public}@",
                    localURL?.absoluteString ?? "<nil>",
                    sharedURL?.absoluteString ?? "<nil>"
                )
                try? localConfig.set(sharedURL, for: fileType)
            }
        }
    }
}

private func fileBasenames(forHost host: String) -> [String] {
    let parts = host.split(separator: ".")
    var baseNames = [String]()
    for index in parts.startIndex ..< parts.endIndex {
        baseNames.append(parts[index...].joined(separator: "."))
    }
    baseNames.append("default")
    baseNames.reverse()

    return baseNames
}

private func loadFiles(from dir: URL, basenames: [String], extension: String) -> [Name: Content] {
    let val = dir.startAccessingSecurityScopedResource()
    defer { dir.stopAccessingSecurityScopedResource() }

    let keysWithValues = basenames.compactMap { basename -> (Name, Content)? in
        let fileName = "\(basename).\(`extension`)"
        let url = dir.appendingPathComponent(fileName)

        return try? (fileName, String(contentsOf: url))
    }

    return Dictionary(uniqueKeysWithValues: keysWithValues)
}
