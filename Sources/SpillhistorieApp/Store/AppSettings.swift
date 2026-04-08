import SwiftUI

@MainActor
@Observable
final class AppSettings {
    enum FontStyle: String, CaseIterable, Identifiable {
        case standard
        case rounded
        case serif

        var id: String { rawValue }

        var title: String {
            switch self {
            case .standard: return "Standard"
            case .rounded: return "Rounded"
            case .serif: return "Serif"
            }
        }

        var design: Font.Design {
            switch self {
            case .standard: return .default
            case .rounded: return .rounded
            case .serif: return .serif
            }
        }
    }

    private enum Keys {
        static let darkModeEnabled = "settings.darkModeEnabled"
        static let fontStyle = "settings.fontStyle"
    }

    var darkModeEnabled: Bool {
        didSet { UserDefaults.standard.set(darkModeEnabled, forKey: Keys.darkModeEnabled) }
    }

    var fontStyle: FontStyle {
        didSet { UserDefaults.standard.set(fontStyle.rawValue, forKey: Keys.fontStyle) }
    }

    init(defaults: UserDefaults = .standard) {
        darkModeEnabled = defaults.bool(forKey: Keys.darkModeEnabled)
        fontStyle = FontStyle(rawValue: defaults.string(forKey: Keys.fontStyle) ?? "") ?? .standard
    }

    var preferredColorScheme: ColorScheme? {
        darkModeEnabled ? .dark : .light
    }
}
