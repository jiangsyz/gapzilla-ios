import SwiftUI

enum GapStyle {
    static let coral = Color(red: 1.00, green: 0.23, blue: 0.38)
    static let coralSoft = Color(red: 1.00, green: 0.93, blue: 0.95)
    static let plum = Color(red: 0.38, green: 0.24, blue: 0.34)
    static let plumSoft = Color(red: 0.96, green: 0.92, blue: 0.95)
    static let ink = Color(red: 0.15, green: 0.14, blue: 0.25)
    static let secondary = Color(red: 0.40, green: 0.43, blue: 0.51)
    static let line = Color(red: 0.89, green: 0.90, blue: 0.93)
    static let canvas = Color(red: 0.985, green: 0.98, blue: 0.99)
}

struct LogoMark: View {
    var size: CGFloat = 44

    var body: some View {
        Image("GapzillaMark")
            .resizable()
            .scaledToFit()
        .frame(width: size, height: size)
        .shadow(color: GapStyle.plum.opacity(0.16), radius: 14, y: 8)
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
                    .font(.system(compact ? .headline : .title3, design: .rounded, weight: .bold))
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
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        content
            .padding(padding)
            .background(.white.opacity(0.94), in: shape)
            .clipShape(shape)
            .overlay {
                shape
                    .stroke(GapStyle.line.opacity(0.8), lineWidth: 1)
            }
            .shadow(color: GapStyle.plum.opacity(0.07), radius: 20, y: 10)
    }
}

extension View {
    func softCard(padding: CGFloat = 18) -> some View {
        modifier(SoftCardModifier(padding: padding))
    }
}

struct GlowBackground: View {
    var body: some View {
        ZStack {
            GapStyle.canvas
            Circle()
                .fill(GapStyle.coral.opacity(0.11))
                .frame(width: 330, height: 330)
                .blur(radius: 75)
                .offset(x: 170, y: -260)
            Circle()
                .fill(GapStyle.plum.opacity(0.07))
                .frame(width: 260, height: 260)
                .blur(radius: 85)
                .offset(x: -180, y: 310)
        }
        .ignoresSafeArea()
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
                Text(eyebrow.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(GapStyle.coral)
            }
            Text(title)
                .font(.title2.weight(.bold))
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
