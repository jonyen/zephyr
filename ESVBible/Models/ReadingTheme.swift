import SwiftUI
import AppKit

enum ReadingTheme: String, CaseIterable {
    case system
    case light
    case dark
    case sepia
    case black

    var displayName: String {
        switch self {
        case .system: return "System (Light/Dark)"
        case .light:  return "Light"
        case .dark:   return "Dark"
        case .sepia:  return "Sepia"
        case .black:  return "Black"
        }
    }

    /// Passed to `.preferredColorScheme()`. nil = follow the OS.
    var colorScheme: ColorScheme? {
        switch self {
        case .system:         return nil
        case .light:          return .light
        case .dark:           return .dark
        case .sepia:          return .light
        case .black:          return .dark
        }
    }

    /// SwiftUI background fill. Clear for system/light/dark (OS handles it).
    var backgroundColor: Color {
        switch self {
        case .system: return .clear
        case .light:  return .white
        case .dark:   return Color(NSColor.windowBackgroundColor)
        case .sepia:  return Color(red: 0.957, green: 0.925, blue: 0.847) // #F4ECD8
        case .black:  return .black
        }
    }

    /// Primary text color for NSTextView attributed strings.
    var nsTextColor: NSColor {
        switch self {
        case .system, .light, .dark:
            return .labelColor           // adaptive — resolves correctly for forced appearance
        case .sepia:
            return NSColor(red: 0.231, green: 0.165, blue: 0.102, alpha: 1) // #3B2A1A
        case .black:
            return NSColor(white: 0.8, alpha: 1) // #CCCCCC
        }
    }

    /// Secondary text color used for verse numbers.
    var nsSecondaryColor: NSColor {
        switch self {
        case .system, .light, .dark:
            return .secondaryLabelColor  // adaptive
        case .sepia:
            return NSColor(red: 0.482, green: 0.388, blue: 0.282, alpha: 1) // #7B6348
        case .black:
            return NSColor(white: 0.533, alpha: 1) // #888888
        }
    }

    /// Fill color for the small swatch circle in the settings picker.
    var swatchFill: Color {
        switch self {
        case .system: return Color(NSColor.windowBackgroundColor)
        case .light:  return .white
        case .dark:   return Color(NSColor(white: 0.2, alpha: 1))
        case .sepia:  return Color(red: 0.957, green: 0.925, blue: 0.847)
        case .black:  return .black
        }
    }

    /// Border color for the swatch circle.
    var swatchBorder: Color {
        switch self {
        case .system, .light: return .black.opacity(0.25)
        case .dark:           return .white.opacity(0.25)
        case .sepia:          return Color(red: 0.231, green: 0.165, blue: 0.102).opacity(0.5)
        case .black:          return .white.opacity(0.2)
        }
    }
}
