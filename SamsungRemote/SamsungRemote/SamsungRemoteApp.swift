import SwiftUI

@main
struct SamsungRemoteApp: App {

    @StateObject private var store = TVStore()
    @StateObject private var client = SamsungTVClient()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(client)
                .preferredColorScheme(.dark)
                .tint(.accentColor)
        }
    }
}
