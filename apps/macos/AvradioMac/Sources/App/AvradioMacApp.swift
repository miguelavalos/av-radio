import AppKit
import SwiftUI

@main
struct AvradioMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var libraryStore = LibraryStore()
    @StateObject private var audioPlayer = AudioPlayerService()

    var body: some Scene {
        WindowGroup("AV Radio Mac") {
            ContentView()
                .environmentObject(libraryStore)
                .environmentObject(audioPlayer)
                .frame(minWidth: 1080, minHeight: 720)
        }
        .defaultSize(width: 1280, height: 820)

        Settings {
            SettingsView()
                .environmentObject(libraryStore)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
