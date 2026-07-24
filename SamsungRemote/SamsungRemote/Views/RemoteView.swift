import SwiftUI

struct RemoteView: View {

    let device: TVDevice

    @EnvironmentObject private var client: SamsungTVClient

    @State private var showingNumbers = false
    @State private var showingKeyboard = false

    private var isLive: Bool { client.state.canSendCommands }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                StatusBanner(device: device)

                topRow
                DirectionPad(isEnabled: isLive) { client.send($0) }
                navigationRow
                rockers
                playbackRow
                appsGrid
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(Color.black.ignoresSafeArea())
        .onAppear { Haptics.prepare() }
        .sheet(isPresented: $showingNumbers) {
            NumberPadSheet(isEnabled: isLive) { client.send($0) }
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingKeyboard) {
            TextInputSheet { client.sendText($0) }
                .presentationDetents([.height(220)])
        }
    }

    // MARK: - Sections

    private var topRow: some View {
        HStack(spacing: 18) {
            RemoteButton(symbol: "power", caption: "Marche", style: .power) {
                if isLive {
                    client.send(.power)
                } else {
                    client.wakeUp()
                }
            }

            RemoteButton(symbol: "rectangle.connected.to.line.below",
                         caption: "Source",
                         isEnabled: isLive) { client.send(.source) }

            RemoteButton(symbol: "speaker.slash",
                         caption: "Muet",
                         isEnabled: isLive) { client.send(.mute) }

            RemoteButton(symbol: "keyboard",
                         caption: "Clavier",
                         style: .accent,
                         isEnabled: isLive) { showingKeyboard = true }
        }
    }

    private var navigationRow: some View {
        HStack(spacing: 18) {
            RemoteButton(symbol: "arrow.uturn.backward",
                         caption: "Retour",
                         diameter: 56,
                         isEnabled: isLive) { client.send(.back) }

            RemoteButton(symbol: "house",
                         caption: "Accueil",
                         diameter: 56,
                         isEnabled: isLive) { client.send(.home) }

            RemoteButton(symbol: "slider.horizontal.3",
                         caption: "Menu",
                         diameter: 56,
                         isEnabled: isLive) { client.send(.menu) }

            RemoteButton(symbol: "list.bullet.rectangle",
                         caption: "Guide",
                         diameter: 56,
                         isEnabled: isLive) { client.send(.guide) }
        }
    }

    private var rockers: some View {
        HStack(alignment: .center, spacing: 22) {
            RockerControl(label: "VOL",
                          topSymbol: "plus",
                          bottomSymbol: "minus",
                          isEnabled: isLive,
                          onTop: { client.send(.volumeUp) },
                          onBottom: { client.send(.volumeDown) })

            VStack(spacing: 14) {
                RemoteButton(symbol: "number",
                             caption: "Chiffres",
                             diameter: 54,
                             isEnabled: isLive) { showingNumbers = true }

                RemoteButton(symbol: "info.circle",
                             caption: "Info",
                             diameter: 54,
                             isEnabled: isLive) { client.send(.info) }
            }

            RockerControl(label: "CH",
                          topSymbol: "chevron.up",
                          bottomSymbol: "chevron.down",
                          isEnabled: isLive,
                          onTop: { client.send(.channelUp) },
                          onBottom: { client.send(.channelDown) })
        }
    }

    private var playbackRow: some View {
        HStack(spacing: 18) {
            RemoteButton(symbol: "backward.fill", diameter: 54, isEnabled: isLive) {
                client.send(.rewind)
            }
            RemoteButton(symbol: "playpause.fill", style: .accent, diameter: 62, isEnabled: isLive) {
                client.send(.playPause)
            }
            RemoteButton(symbol: "forward.fill", diameter: 54, isEnabled: isLive) {
                client.send(.fastForward)
            }
            RemoteButton(symbol: "stop.fill", diameter: 54, isEnabled: isLive) {
                client.send(.stop)
            }
        }
    }

    private var appsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Applications")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                      spacing: 12) {
                ForEach(TVApp.shortcuts) { app in
                    Button {
                        Haptics.tap()
                        client.launch(app)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: app.symbol)
                                .font(.title3)
                            Text(app.name)
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(PressedButtonStyle())
                    .disabled(!isLive)
                }
            }
            .opacity(isLive ? 1 : 0.35)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Bandeau d'état

private struct StatusBanner: View {

    let device: TVDevice

    @EnvironmentObject private var client: SamsungTVClient

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(device.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if case .failed = client.state {
                Button("Réessayer") { client.reconnect() }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
            } else if client.state == .connecting || client.state == .awaitingAuthorization {
                ProgressView().controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private var title: String {
        switch client.state {
        case .idle: "Déconnecté"
        case .connecting: "Connexion…"
        case .awaitingAuthorization: "Autorise « iPhone » sur la TV"
        case .connected: "Connecté"
        case .failed(let message): message
        }
    }

    private var color: Color {
        switch client.state {
        case .connected: .green
        case .connecting, .awaitingAuthorization: .orange
        case .failed: .red
        case .idle: .gray
        }
    }
}

// MARK: - Pavé numérique

private struct NumberPadSheet: View {

    let isEnabled: Bool
    let onKey: (RemoteKey) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Chaînes")
                .font(.headline)
                .padding(.top, 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3),
                      spacing: 16) {
                ForEach(1...9, id: \.self) { digit in
                    RemoteButton(text: "\(digit)", diameter: 62, isEnabled: isEnabled) {
                        if let key = RemoteKey.digit(digit) { onKey(key) }
                    }
                }

                RemoteButton(symbol: "list.bullet", diameter: 62, isEnabled: isEnabled) {
                    onKey(.channelList)
                }
                RemoteButton(text: "0", diameter: 62, isEnabled: isEnabled) {
                    onKey(.digit0)
                }
                RemoteButton(symbol: "arrow.left.arrow.right", diameter: 62, isEnabled: isEnabled) {
                    onKey(.previousChannel)
                }
            }
            .padding(.horizontal, 40)

            Spacer(minLength: 0)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Saisie de texte

private struct TextInputSheet: View {

    let onSubmit: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saisie sur la TV")
                .font(.headline)

            Text("Place-toi d'abord dans un champ de texte sur la TV (recherche, mot de passe Wi-Fi…).")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Texte à envoyer", text: $text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isFocused)
                .onSubmit(submit)

            Button("Envoyer", action: submit)
                .buttonStyle(.borderedProminent)
                .disabled(text.isEmpty)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .background(Color.black.ignoresSafeArea())
        .onAppear { isFocused = true }
    }

    private func submit() {
        guard !text.isEmpty else { return }
        onSubmit(text)
        text = ""
        dismiss()
    }
}
