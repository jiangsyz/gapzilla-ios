import SwiftUI

enum GapStyle {
    static let canvas = Color(red: 251 / 255, green: 250 / 255, blue: 248 / 255)
    static let surface = Color.white
    static let surfaceStrong = Color(red: 36 / 255, green: 36 / 255, blue: 33 / 255)
    static let surfaceSoft = Color(red: 241 / 255, green: 240 / 255, blue: 236 / 255)
    static let ink = Color(red: 36 / 255, green: 36 / 255, blue: 33 / 255)
    static let secondary = Color(red: 110 / 255, green: 108 / 255, blue: 102 / 255)
    static let placeholder = Color(red: 170 / 255, green: 166 / 255, blue: 158 / 255)
    static let line = Color(red: 221 / 255, green: 218 / 255, blue: 211 / 255)
    static let slip = Color(red: 207 / 255, green: 78 / 255, blue: 95 / 255)
    static let slipSoft = Color(red: 250 / 255, green: 236 / 255, blue: 239 / 255)
    static let urge = Color(red: 47 / 255, green: 125 / 255, blue: 90 / 255)
    static let urgeSoft = Color(red: 235 / 255, green: 245 / 255, blue: 239 / 255)
    static let danger = slip
    static let info = Color(red: 62 / 255, green: 111 / 255, blue: 152 / 255)
    static let infoSoft = Color(red: 237 / 255, green: 243 / 255, blue: 247 / 255)
    static let warning = Color(red: 154 / 255, green: 104 / 255, blue: 28 / 255)
    static let warningSoft = Color(red: 255 / 255, green: 244 / 255, blue: 216 / 255)
    static let radius: CGFloat = 10
    static let cardRadius: CGFloat = 12
}

struct LogoMark: View {
    var size: CGFloat = 44

    var body: some View {
        Image("GapzillaMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: GapStyle.ink.opacity(0.10), radius: 8, y: 4)
            .accessibilityHidden(true)
    }
}

struct BrandLockup: View {
    var compact = false

    var body: some View {
        HStack(spacing: 11) {
            LogoMark(size: compact ? 38 : 46)
            VStack(alignment: .leading, spacing: 0) {
                Text("Gapzilla")
                    .font(.system(compact ? .headline : .title3, design: .default, weight: .bold))
                    .foregroundStyle(GapStyle.ink)
                if !compact {
                    Text("记录间隔，让它变长。")
                        .font(.caption)
                        .foregroundStyle(GapStyle.secondary)
                }
            }
        }
    }
}

struct SoftCardModifier: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: GapStyle.cardRadius, style: .continuous)

        content
            .padding(padding)
            .background(GapStyle.surface, in: shape)
            .clipShape(shape)
            .overlay {
                shape
                    .stroke(GapStyle.line, lineWidth: 1)
            }
            .shadow(color: GapStyle.ink.opacity(0.035), radius: 8, y: 2)
    }
}

extension View {
    func softCard(padding: CGFloat = 18) -> some View {
        modifier(SoftCardModifier(padding: padding))
    }
}

struct PageBackground: View {
    var body: some View {
        GapStyle.canvas.ignoresSafeArea()
    }
}

struct SectionTitle: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?

    init(_ title: String, eyebrow: String? = nil, subtitle: String? = nil) {
        self.title = title
        self.eyebrow = eyebrow
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GapStyle.info)
            }
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(GapStyle.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(GapStyle.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(GapStyle.surface)
            .background(
                configuration.isPressed ? GapStyle.ink.opacity(0.86) : GapStyle.surfaceStrong,
                in: RoundedRectangle(cornerRadius: GapStyle.radius, style: .continuous)
            )
            .opacity(isEnabled ? 1 : 0.55)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(GapStyle.ink)
            .background(
                configuration.isPressed ? GapStyle.surfaceSoft : GapStyle.surface,
                in: RoundedRectangle(cornerRadius: GapStyle.radius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: GapStyle.radius, style: .continuous)
                    .stroke(GapStyle.line, lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.55)
    }
}
