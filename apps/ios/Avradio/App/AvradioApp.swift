import SwiftData
import SwiftUI

@main
struct AvradioApp: App {
    private let persistenceController: PersistenceController
    @StateObject private var audioPlayer = AudioPlayerService()
    @StateObject private var languageController = AppLanguageController()
    @StateObject private var libraryStore: LibraryStore
    @StateObject private var accessController: AccessController

    init() {
        AppConfig.configureAVAppsAccountIfPossible()
        let persistenceController = PersistenceController.shared
        self.persistenceController = persistenceController
        _libraryStore = StateObject(wrappedValue: LibraryStore(container: persistenceController.container))
        _accessController = StateObject(wrappedValue: AccessController())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                RootView()
                    .environmentObject(accessController)
                    .environmentObject(languageController)
                    .environment(\.locale, languageController.locale)
                    .environmentObject(audioPlayer)
                    .environmentObject(libraryStore)
            }
        }
        .modelContainer(persistenceController.container)
    }
}
