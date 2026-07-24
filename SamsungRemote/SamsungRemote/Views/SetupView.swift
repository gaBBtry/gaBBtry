import SwiftUI

struct SetupView: View {

    /// Fourni quand la vue est présentée en feuille, pour se refermer après le choix.
    let onDone: (() -> Void)?

    @EnvironmentObject private var store: TVStore
    @EnvironmentObject private var client: SamsungTVClient

    @StateObject private var discovery = TVDiscovery()

    @State private var manualHost = ""
    @State private var manualError: String?
    @State private var isCheckingManualHost = false

    var body: some View {
        List {
            if !store.devices.isEmpty {
                Section("Mes téléviseurs") {
                    ForEach(store.devices) { device in
                        deviceRow(device, isKnown: true)
                    }
                    .onDelete { offsets in
                        for device in offsets.map({ store.devices[$0] }) {
                            store.remove(device)
                        }
                    }
                }
            }

            Section {
                if discovery.isScanning {
                    HStack {
                        ProgressView(value: discovery.progress)
                        Text("\(Int(discovery.progress * 100)) %")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(discovery.devices.filter { found in
                    !store.devices.contains { $0.id == found.id }
                }) { device in
                    deviceRow(device, isKnown: false)
                }

                Button {
                    discovery.scan()
                } label: {
                    Label(discovery.isScanning ? "Recherche en cours…" : "Rechercher sur le Wi-Fi",
                          systemImage: "antenna.radiowaves.left.and.right")
                }
                .disabled(discovery.isScanning)

                if let message = discovery.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Découverte")
            } footer: {
                Text("La TV doit être allumée et sur le même réseau Wi-Fi que l'iPhone.")
            }

            Section {
                HStack {
                    TextField("192.168.1.25", text: $manualHost)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if isCheckingManualHost {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Ajouter") { addManualHost() }
                            .disabled(!LocalNetwork.isValidIPv4(manualHost))
                    }
                }

                if let manualError {
                    Text(manualError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Adresse IP manuelle")
            } footer: {
                Text("Sur la TV : Paramètres › Général › Réseau › État du réseau › Paramètres IP.")
            }

            if let selected = store.selectedDevice, selected.isPaired {
                Section {
                    Button("Oublier l'appairage", role: .destructive) {
                        store.forgetToken(for: selected.id)
                        client.reconnect()
                    }
                } footer: {
                    Text("La TV redemandera une autorisation à la prochaine connexion.")
                }
            }
        }
        .task {
            if store.devices.isEmpty && discovery.devices.isEmpty {
                discovery.scan()
            }
        }
    }

    private func deviceRow(_ device: TVDevice, isKnown: Bool) -> some View {
        Button {
            store.select(device)
            onDone?()
        } label: {
            HStack {
                Image(systemName: "tv")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.displayName)
                        .foregroundStyle(.primary)
                    Text(device.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if store.selectedID == device.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                } else if isKnown && device.isPaired {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
    }

    private func addManualHost() {
        let host = manualHost.trimmingCharacters(in: .whitespaces)
        guard LocalNetwork.isValidIPv4(host) else {
            manualError = "Adresse IPv4 invalide."
            return
        }

        manualError = nil
        isCheckingManualHost = true

        Task {
            let found = await discovery.lookUp(host: host)
            isCheckingManualHost = false

            // Si la TV ne répond pas à l'API d'information (certains modèles la
            // désactivent), on l'ajoute quand même : le canal de commande peut marcher.
            let device = found ?? TVDevice(id: host,
                                           name: "TV Samsung",
                                           modelName: nil,
                                           host: host,
                                           macAddress: nil,
                                           token: nil)
            store.select(device)
            manualHost = ""
            onDone?()
        }
    }
}

#Preview {
    NavigationStack {
        SetupView(onDone: nil)
            .environmentObject(TVStore())
            .environmentObject(SamsungTVClient())
    }
}
