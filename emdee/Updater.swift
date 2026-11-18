#if os(macOS)
import Sparkle
import SwiftUI

/// Sparkle, reading the feed in Info.plist (`SUFeedURL`, signed with `SUPublicEDKey`). Debug
/// builds (the Dev scheme, com.bailycase.emdee.dev) never update: every release would look newer
/// than build 1, and none can install over the Dev bundle id.
@MainActor enum Updater {
    #if DEBUG
    static let controller: SPUStandardUpdaterController? = nil
    #else
    static let controller: SPUStandardUpdaterController? = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    #endif
}

struct UpdateCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            if let controller = Updater.controller {
                Button("Check for Updates…") { controller.checkForUpdates(nil) }
            }
        }
    }
}
#endif
