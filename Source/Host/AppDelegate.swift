import Cocoa
import os
import SafariServices

private let extensionBundleID = Bundle.main.object(forInfoDictionaryKey: "ExtensionBundleID")! as! String

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet private var window: NSWindow!

    @IBOutlet private var statusEnabledView: NSView!
    @IBOutlet private var statusDisabledView: NSView!

    @IBOutlet private var cssPathLabel: NSTextField!
    @IBOutlet private var jsPathLabel: NSTextField!

    @IBOutlet private var cssPathButton: NSButton!
    @IBOutlet private var jsPathButton: NSButton!

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        return true
    }

    override func awakeFromNib() {
        Config.FileType.allCases.forEach(configure(fileType:))
        configureStatusView(extensionEnabled: false)
    }

    func applicationWillBecomeActive(_: Notification) {
        checkExtensionState()
    }

    private func checkExtensionState() {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionBundleID) { state, error in
            guard error == nil else { return }
            let isEnabled = state?.isEnabled ?? false
            DispatchQueue.main.async {
                self.configureStatusView(extensionEnabled: isEnabled)
            }
        }
    }

    private func configureStatusView(extensionEnabled isEnabled: Bool) {
        statusEnabledView.isHidden = !isEnabled
        statusDisabledView.isHidden = isEnabled
    }

    private func configure(fileType: Config.FileType) {
        let url = Config.shared.url(for: fileType)

        let label = self.label(for: fileType)
        label.stringValue = url?.relativePath ?? ""
        label.isHidden = url == nil

        let button = self.button(for: fileType)
        button.title = url == nil ? "Set" : "Change"
    }

    private func label(for fileType: Config.FileType) -> NSTextField {
        switch fileType {
        case .css: return cssPathLabel
        case .js: return jsPathLabel
        }
    }

    private func button(for fileType: Config.FileType) -> NSButton {
        switch fileType {
        case .css: return cssPathButton
        case .js: return jsPathButton
        }
    }

    private func fileType(for button: NSButton) -> Config.FileType? {
        if button == cssPathButton {
            return .css
        } else if button == jsPathButton {
            return .js
        } else {
            return nil
        }
    }

    @IBAction private func setUp(_ sender: Any) {
        guard
            let button = sender as? NSButton,
            let fileType = fileType(for: button)
        else { return }

        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        openPanel.beginSheetModal(for: window) {
            guard $0 == .OK, let url = openPanel.urls.first else { return }

            try? Config.shared.set(url, for: fileType)
            self.configure(fileType: fileType)
        }
    }

    @IBAction private func showSafariPreferences(_: Any) {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionBundleID)
    }

    @IBAction private func showHelp(_: Any) {
        let url = URL(string: "https://phili.pe/posts/introducing-page-extender-for-safari/")!
        NSWorkspace.shared.open(url)
    }
}
