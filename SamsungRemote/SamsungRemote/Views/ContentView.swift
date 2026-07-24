import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var store: TVStore
    @EnvironmentObject private var client: SamsungTVClient
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingDevicePicker = false

    var body: some View {
        NavigationStack {
            Group {
                if let device = store.selectedDevice {
                    RemoteView(device: device)
                } else {
                    SetupView(onDone: nil)
                }
            }
            .navigationTitle(store.selectedDevice?.displayName ?? "Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if store.selectedDevice != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingDevicePicker = true
                        } label: {
                            Image(systemName: "tv.badge.wifi")
                        }
                        .accessibilityLabel("Changer de téléviseur")
                    }
                }
            }
            .sheet(isPresented: $showingDevicePicker) {
                NavigationStack {
                    SetupView(onDone: { showingDevicePicker = false })
                        .navigationTitle("Téléviseurs")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Fermer") { showingDevicePicker = false }
                            }
                        }
                }
            }
        }
        .task(id: store.selectedDevice) {
            connect()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                connect()
            case .background:
                client.disconnect()
            default:
                break
            }
        }
    }

    private func connect() {
        guard let device = store.selectedDevice else {
            client.disconnect()
            return
        }
        client.onTokenReceived = { [id = device.id] token in
            store.updateToken(token, for: id)
        }
        client.connect(to: device)
    }
}

#Preview {
    ContentView()
        .environmentObject(TVStore())
        .environmentObject(SamsungTVClient())
}
