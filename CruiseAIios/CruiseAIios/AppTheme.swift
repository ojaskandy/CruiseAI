//
//  AppTheme.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/7/25.
//

import SwiftUI

// This file defines the AppTheme enum for the application
// It provides consistent theming across the app

public enum AppTheme: String, CaseIterable, Identifiable {
    case midnight
    case ocean
    case sunset
    case forest
    
    public var id: String { self.rawValue }
    
    public var accentColor: Color {
        switch self {
        case .midnight: return Color(hex: "00B4FF")
        case .ocean: return Color(hex: "00E5FF")
        case .sunset: return Color(hex: "FF9500")
        case .forest: return Color(hex: "00C853")
        @unknown default: return Color(hex: "00B4FF")
        }
    }
    
    public var gradientColors: [Color] {
        switch self {
        case .midnight: return [Color(hex: "0A0A23"), Color(hex: "151538")]
        case .ocean: return [Color(hex: "004D7A"), Color(hex: "008793")]
        case .sunset: return [Color(hex: "4A2480"), Color(hex: "CB2D3E")]
        case .forest: return [Color(hex: "134E5E"), Color(hex: "71B280")]
        @unknown default: return [Color(hex: "0A0A23"), Color(hex: "151538")]
        }
    }
    
    public var name: String {
        switch self {
        case .midnight: return "Midnight"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .forest: return "Forest"
        @unknown default: return "Unknown"
        }
    }
    
    public var glassOpacity: Double {
        switch self {
        case .midnight: return 0.3
        case .ocean: return 0.25
        case .sunset: return 0.35
        case .forest: return 0.3
        @unknown default: return 0.3
        }
    }
    
    public var glassBlur: Double {
        switch self {
        case .midnight: return 10
        case .ocean: return 8
        case .sunset: return 12
        case .forest: return 10
        @unknown default: return 10
        }
    }
    
    public var glassBorderColor: Color {
        switch self {
        case .midnight: return .white.opacity(0.2)
        case .ocean: return .white.opacity(0.15)
        case .sunset: return .white.opacity(0.25)
        case .forest: return .white.opacity(0.2)
        @unknown default: return .white.opacity(0.2)
        }
    }
    
    public var glassBorderWidth: CGFloat {
        switch self {
        case .midnight: return 1
        case .ocean: return 0.5
        case .sunset: return 1.5
        case .forest: return 1
        @unknown default: return 1
        }
    }
    
    public var shadowColor: Color {
        switch self {
        case .midnight: return .black.opacity(0.3)
        case .ocean: return .black.opacity(0.25)
        case .sunset: return .black.opacity(0.35)
        case .forest: return .black.opacity(0.3)
        @unknown default: return .black.opacity(0.3)
        }
    }
    
    public var shadowRadius: CGFloat {
        switch self {
        case .midnight: return 8
        case .ocean: return 6
        case .sunset: return 10
        case .forest: return 8
        @unknown default: return 8
        }
    }
    
    public var shadowX: CGFloat {
        switch self {
        case .midnight: return 0
        case .ocean: return 0
        case .sunset: return 1
        case .forest: return 0
        @unknown default: return 0
        }
    }
    
    public var shadowY: CGFloat {
        switch self {
        case .midnight: return 4
        case .ocean: return 3
        case .sunset: return 5
        case .forest: return 4
        @unknown default: return 4
        }
    }
    
    public var textColor: Color {
        switch self {
        case .midnight, .ocean, .sunset, .forest:
            return .white
        default:
            return .white
        }
    }
    
    public var secondaryTextColor: Color {
        switch self {
        case .midnight, .ocean, .sunset, .forest:
            return .white.opacity(0.7)
        default:
            return .white.opacity(0.7)
        }
    }
}

// Extension to Color for hex initialization
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
            break
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
