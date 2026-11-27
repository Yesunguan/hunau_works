import HunauWorksCore
import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (77, 163, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: 1.0
        )
    }
}

enum GlassPalette {
    static func urgencyColor(_ level: UrgencyLevel) -> Color {
        switch level {
        case .overdue: return Color(hex: "#FF4D5E")
        case .critical24h: return Color(hex: "#FF9438")
        case .soon3Days: return Color(hex: "#F5C043")
        case .comfortable: return Color(hex: "#4DA3FF")
        case .completed: return Color(hex: "#34D399")
        }
    }

    static func bucketColor(_ bucket: HomeworkBucket) -> Color {
        switch bucket {
        case .overdue: return Color(hex: "#FF4D5E")
        case .today: return Color(hex: "#FF9438")
        case .within3Days: return Color(hex: "#F5C043")
        case .later: return Color(hex: "#4DA3FF")
        }
    }

    static func priorityColor(_ priority: HomeworkPriority) -> Color {
        switch priority {
        case .high: return Color(hex: "#FF5E6C")
        case .medium: return Color(hex: "#FBBF24")
        case .low: return Color(hex: "#60A5FA")
        }
    }
}

/// Crisp translucent surface for content cards inside a native NSGlassEffectView window.
/// Follows Apple's macOS 26 Liquid Glass hierarchy: outer shell & navigation use real Liquid Glass,
/// while inner content cards use high-contrast specular frosted layers so text stays razor-sharp.
struct GlassContentCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = 14
    var isSelected: Bool = false
    var accent: Color? = nil

    func body(content: Content) -> some View {
        let isDark = colorScheme == .dark
        let fillOpacity: Double = isSelected
            ? (isDark ? 0.19 : 0.34)
            : (isDark ? 0.11 : 0.22)
        let baseFill = isDark
            ? Color.white.opacity(fillOpacity)
            : Color.white.opacity(fillOpacity + 0.16)
        let tintOverlay = (accent ?? .clear).opacity(isSelected ? 0.14 : 0.0)

        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(baseFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tintOverlay)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        isSelected ? (accent ?? .white).opacity(0.65) : Color.white.opacity(isDark ? 0.28 : 0.65),
                                        Color.white.opacity(isDark ? 0.06 : 0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 1.2 : 0.8
                            )
                    }
            }
    }
}

extension View {
    func glassContentCard(
        cornerRadius: CGFloat = 14,
        isSelected: Bool = false,
        accent: Color? = nil
    ) -> some View {
        modifier(GlassContentCardModifier(cornerRadius: cornerRadius, isSelected: isSelected, accent: accent))
    }
}

struct SubtleResizeGrip: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let strokeColor = (colorScheme == .dark ? Color.white : Color.black).opacity(0.24)
            for idx in 0..<3 {
                let offset = CGFloat(idx) * 4.0
                var path = Path()
                path.move(to: CGPoint(x: size.width - 2, y: size.height - 11 + offset))
                path.addLine(to: CGPoint(x: size.width - 11 + offset, y: size.height - 2))
                context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
        }
        .frame(width: 14, height: 14)
        .allowsHitTesting(false)
    }
}
