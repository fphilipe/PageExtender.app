import Foundation
import os

// This class is used to read and write the URL for the CSS and JS folders.
//
// The user configures the paths using the standard open dialog in the host
// application. The extension then reads these configs when loading the CSS and
// JS files.
//
// Essentially, we need the host application as a mechanism to ship the
// extension while also serving as the UI for configuring the extension. The
// configured URLs need to be accessible by the extension. Getting this to work
// with macOS's sandboxing is a bit tricky.
//
// The host and extension are part of an app suite, i.e. they can access
// a shared sandbox. Initially the host was creating a bookmark for the URLs
// without any security flags. This bookmark was stored in a shared user
// defaults such that the extension could read and resolve the bookmark. To my
// surprise this worked even though the documentation states that bookmarks for
// sanboxed apps should use this flag.
//
// Unfortunately, after a reboot the bookmarks would be stale, making reading
// files from the folders impossible. The user had to reset the folders in the
// host in order to make the resolution work again.
//
// Assuming that they were becoming stale due to the lack of security flags,
// I subsequently added these to the creation and resolution process. Alas, this
// caused the bookmark resolution to fail in the extension.
//
// The workaround to this rather annoying state of affairs is to use
// a combination of both non-secure bookmarks and secure bookmarks. The host
// writes the non-secure bookmarks into a shared user defaults. The extension
// then reads these URLs from the shared user defaults, creates secure bookmarks
// for them and stores them in its standard user defaults, resulting in
// bookmarks that can still be resolved after a reboot. The only downside of
// this is that the creation of the secure bookmarks have to happen before
// a restart. Otherwise the bookmark creation fails.
//
// See also the discussion in the Apple forums:
// https://forums.developer.apple.com/thread/66259
// Specifically the following post:
// https://forums.developer.apple.com/thread/66259#278355
struct Config {
    enum FileType: String, CaseIterable {
        case js
        case css
    }

    static let shared: Config = {
        let suiteName = Bundle.main.object(forInfoDictionaryKey: "SuiteName")! as! String
        let suiteUserDefaults = UserDefaults(suiteName: suiteName)!
        return Config(userDefaults: suiteUserDefaults, secure: false)
    }()

    private let userDefaults: UserDefaults
    private let isSecure: Bool

    init(userDefaults: UserDefaults, secure isSecure: Bool) {
        self.userDefaults = userDefaults
        self.isSecure = isSecure
    }

    private var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        if isSecure {
            return [.withSecurityScope, .withoutUI]
        } else {
            return []
        }
    }

    private var bookmarkCreationOptions: URL.BookmarkCreationOptions {
        if isSecure {
            return [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
        } else {
            return []
        }
    }

    func url(for fileType: FileType) -> URL? {
        guard let data = userDefaults.data(forKey: fileType.rawValue) else { return nil }

        var isBookmarkStale: Bool = true
        let url = try? URL(
            resolvingBookmarkData: data,
            options: bookmarkResolutionOptions,
            relativeTo: nil,
            bookmarkDataIsStale: &isBookmarkStale
        )

        if isBookmarkStale {
            os_log("Bookmark %{public}@ for %{public}@ is stale", url?.absoluteString ?? "<nil>", fileType.rawValue)
            return nil
        } else {
            return url
        }
    }

    func set(_ url: URL?, for fileType: FileType) throws {
        if let url = url {
            let bookmark = try url.bookmarkData(
                options: bookmarkCreationOptions,
                includingResourceValuesForKeys: [.isDirectoryKey],
                relativeTo: nil
            )
            userDefaults.set(bookmark, forKey: fileType.rawValue)
        } else {
            userDefaults.removeObject(forKey: fileType.rawValue)
        }
    }
}
