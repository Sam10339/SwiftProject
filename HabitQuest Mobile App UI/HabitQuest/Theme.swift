import SwiftUI

struct QuestGradientSet: Hashable {
    let startHex: UInt
    let endHex: UInt

    var colors: [Color] {
        [Color(hex: startHex), Color(hex: endHex)]
    }

    var linear: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var horizontal: LinearGradient {
        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
}

enum QuestPalette {
    static let purple = Color(hex: 0xA855F7)
    static let purpleDark = Color(hex: 0x7E22CE)
    static let purpleSoft = Color(hex: 0xF3E8FF)
    static let indigo = Color(hex: 0x6366F1)
    static let blue = Color(hex: 0x3B82F6)
    static let orange = Color(hex: 0xF97316)
    static let orangeSoft = Color(hex: 0xFFF7ED)
    static let red = Color(hex: 0xEF4444)
    static let green = Color(hex: 0x10B981)
    static let greenSoft = Color(hex: 0xF0FDF4)
    static let yellow = Color(hex: 0xFBBF24)
    static let gray50 = Color(hex: 0xF9FAFB)
    static let gray100 = Color(hex: 0xF3F4F6)
    static let gray200 = Color(hex: 0xE5E7EB)
    static let gray300 = Color(hex: 0xD1D5DB)
    static let gray400 = Color(hex: 0x9CA3AF)
    static let gray500 = Color(hex: 0x6B7280)
    static let gray700 = Color(hex: 0x374151)
    static let gray900 = Color(hex: 0x111827)

    static let outerBackground = LinearGradient(
        colors: [Color(hex: 0xFAF5FF), Color(hex: 0xEFF6FF), Color(hex: 0xEEF2FF)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryGradient = QuestGradientSet(startHex: 0xA855F7, endHex: 0x6366F1)
    static let purplePinkGradient = QuestGradientSet(startHex: 0xA855F7, endHex: 0xEC4899)
    static let blueGradient = QuestGradientSet(startHex: 0x6366F1, endHex: 0x2563EB)
    static let orangeGradient = QuestGradientSet(startHex: 0xF97316, endHex: 0xEF4444)
    static let yellowGradient = QuestGradientSet(startHex: 0xFBBF24, endHex: 0xF97316)
    static let greenGradient = QuestGradientSet(startHex: 0x10B981, endHex: 0x059669)
    static let cyanGradient = QuestGradientSet(startHex: 0x3B82F6, endHex: 0x06B6D4)
}

enum QuestLayout {
    static let cardRadius: CGFloat = 24
    static let buttonRadius: CGFloat = 18
    static let contentPadding: CGFloat = 24
    static let maxPhoneWidth: CGFloat = 393
    static let maxPhoneHeight: CGFloat = 852
}

enum QuestFormatters {
    static let dayHeader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let weekdayShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension View {
    func questCardStyle(
        background: AnyShapeStyle = AnyShapeStyle(Color.white),
        border: Color = QuestPalette.gray100,
        shadowColor: Color = Color.black.opacity(0.06),
        shadowRadius: CGFloat = 14,
        shadowY: CGFloat = 8
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: QuestLayout.cardRadius, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: QuestLayout.cardRadius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }
}
