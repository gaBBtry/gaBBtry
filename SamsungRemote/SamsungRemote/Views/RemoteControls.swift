import SwiftUI
import UIKit

// MARK: - Retour haptique

@MainActor
enum Haptics {
    private static let generator = UIImpactFeedbackGenerator(style: .light)

    static func tap() {
        generator.impactOccurred(intensity: 0.7)
    }

    static func prepare() {
        generator.prepare()
    }
}

// MARK: - Bouton rond

struct RemoteButton: View {

    enum Style {
        case standard
        case power
        case accent

        var background: Color {
            switch self {
            case .standard: Color.white.opacity(0.10)
            case .power: Color.red.opacity(0.22)
            case .accent: Color.accentColor.opacity(0.22)
            }
        }

        var foreground: Color {
            switch self {
            case .standard: .white
            case .power: .red
            case .accent: .accentColor
            }
        }
    }

    var symbol: String?
    var text: String?
    var caption: String?
    var style: Style = .standard
    var diameter: CGFloat = 62
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button {
                Haptics.tap()
                action()
            } label: {
                ZStack {
                    Circle().fill(style.background)
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: diameter * 0.36, weight: .medium))
                    } else if let text {
                        Text(text)
                            .font(.system(size: diameter * 0.34, weight: .semibold, design: .rounded))
                    }
                }
                .frame(width: diameter, height: diameter)
                .foregroundStyle(style.foreground)
                .contentShape(Circle())
            }
            .buttonStyle(PressedButtonStyle())
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.35)

            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(caption ?? text ?? symbol ?? "")
    }
}

/// Léger enfoncement à l'appui, comme sur une vraie télécommande.
struct PressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Bascule verticale (volume, chaînes)

struct RockerControl: View {

    let label: String
    let topSymbol: String
    let bottomSymbol: String
    var isEnabled: Bool = true
    let onTop: () -> Void
    let onBottom: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            rockerButton(symbol: topSymbol, action: onTop)

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.vertical, 2)

            rockerButton(symbol: bottomSymbol, action: onBottom)
        }
        .padding(.vertical, 8)
        .frame(width: 78)
        .background(Color.white.opacity(0.08), in: Capsule())
        .opacity(isEnabled ? 1 : 0.35)
    }

    private func rockerButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressedButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel("\(label) \(symbol.contains("up") || symbol.contains("plus") ? "plus" : "moins")")
    }
}

// MARK: - Croix directionnelle

struct DirectionPad: View {

    var isEnabled: Bool = true
    let onKey: (RemoteKey) -> Void

    private let cell: CGFloat = 84

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: cell * 3, height: cell * 3)

            VStack(spacing: 0) {
                arrow(.up, symbol: "chevron.up")
                HStack(spacing: 0) {
                    arrow(.left, symbol: "chevron.left")
                    okButton
                    arrow(.right, symbol: "chevron.right")
                }
                arrow(.down, symbol: "chevron.down")
            }
        }
        .opacity(isEnabled ? 1 : 0.35)
    }

    private func arrow(_ key: RemoteKey, symbol: String) -> some View {
        Button {
            Haptics.tap()
            onKey(key)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: cell, height: cell)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressedButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel(for: key))
    }

    private var okButton: some View {
        Button {
            Haptics.tap()
            onKey(.enter)
        } label: {
            ZStack {
                Circle().fill(Color.white.opacity(0.14))
                Text("OK")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: cell - 10, height: cell - 10)
            .contentShape(Circle())
        }
        .buttonStyle(PressedButtonStyle())
        .disabled(!isEnabled)
        .frame(width: cell, height: cell)
    }

    private func accessibilityLabel(for key: RemoteKey) -> String {
        switch key {
        case .up: "Haut"
        case .down: "Bas"
        case .left: "Gauche"
        case .right: "Droite"
        default: "Valider"
        }
    }
}
