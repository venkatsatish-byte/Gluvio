import GlucoseCore
import SwiftUI

/// Colors and backgrounds for Kid Mode, keyed by reward item IDs.
enum KidTheme {
    static func bodyColors(_ id: String) -> [Color] {
        switch id {
        case "mint": return [Color(red: 0.55, green: 0.95, blue: 0.80), Color(red: 0.20, green: 0.75, blue: 0.60)]
        case "ocean": return [Color(red: 0.55, green: 0.80, blue: 1.00), Color(red: 0.20, green: 0.45, blue: 0.95)]
        case "berry": return [Color(red: 1.00, green: 0.65, blue: 0.85), Color(red: 0.85, green: 0.30, blue: 0.60)]
        case "galaxy": return [Color(red: 0.75, green: 0.60, blue: 1.00), Color(red: 0.35, green: 0.20, blue: 0.75)]
        default: return [Color(red: 1.00, green: 0.92, blue: 0.55), Color(red: 1.00, green: 0.68, blue: 0.25)]
        }
    }

    static func background(_ id: String) -> LinearGradient {
        let colors: [Color]
        switch id {
        case "beach": colors = [Color(red: 0.55, green: 0.85, blue: 1.0), Color(red: 1.0, green: 0.90, blue: 0.65)]
        case "space": colors = [Color(red: 0.10, green: 0.08, blue: 0.30), Color(red: 0.30, green: 0.15, blue: 0.50)]
        case "snow": colors = [Color(red: 0.85, green: 0.93, blue: 1.0), Color.white]
        default: colors = [Color(red: 0.70, green: 0.90, blue: 1.0), Color(red: 0.75, green: 0.95, blue: 0.70)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    static func isDark(_ backgroundID: String) -> Bool { backgroundID == "space" }

    static let avatarColors: [Color] = [.orange, .pink, .teal, .purple, .blue, .indigo, .green, .red]

    static func avatarColor(_ style: AvatarStyle) -> Color {
        avatarColors[abs(style.colorIndex) % avatarColors.count]
    }

    static func font(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Glu: an original mascot drawn with SwiftUI shapes, a soft glowing blob.
/// Happy when in range, sleepy when low, wobbly when high. Never sad or cross.
struct GluMascot: View {
    var mood: MascotMood
    var colorID: String = "sunshine"
    var hatID: String = "none"
    var size: CGFloat = 180

    @State private var animate = false

    var body: some View {
        let colors = KidTheme.bodyColors(colorID)
        ZStack {
            // Glow
            Circle()
                .fill(colors[0].opacity(mood == .sleepy ? 0.25 : 0.45))
                .frame(width: size * 1.25, height: size * 1.25)
                .blur(radius: size * 0.12)
                .scaleEffect(animate && mood == .happy ? 1.06 : 1)

            // Body: a slightly squashed blob.
            BlobShape(wobble: mood == .wobbly ? (animate ? 0.06 : -0.06) : 0.02)
                .fill(RadialGradient(colors: colors, center: .init(x: 0.35, y: 0.3), startRadius: 4, endRadius: size * 0.75))
                .frame(width: size, height: size * 0.92)
                .shadow(color: colors[1].opacity(0.35), radius: 10, y: 6)
                .overlay(face)
                .overlay(alignment: .top) { hat.offset(y: -size * 0.28) }
                .rotationEffect(.degrees(mood == .wobbly ? (animate ? 4 : -4) : 0))
                .offset(y: mood == .happy && animate ? -size * 0.04 : 0)

            if mood == .sleepy {
                Text("z z")
                    .font(KidTheme.font(size * 0.14))
                    .foregroundStyle(.secondary)
                    .offset(x: size * 0.45, y: -size * 0.42)
                    .opacity(animate ? 1 : 0.3)
            }
        }
        .frame(width: size * 1.3, height: size * 1.3)
        .onAppear {
            withAnimation(.easeInOut(duration: mood == .wobbly ? 0.5 : 1.6).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
        .id(mood) // restart the animation when the mood changes
        .accessibilityElement()
        .accessibilityLabel("Glu, \(mood.line)")
    }

    private var face: some View {
        let eyeSize = size * 0.11
        return VStack(spacing: size * 0.06) {
            HStack(spacing: size * 0.22) {
                eye(size: eyeSize)
                eye(size: eyeSize)
            }
            mouth
                .frame(width: size * 0.26, height: size * 0.12)
        }
        .offset(y: size * 0.02)
    }

    @ViewBuilder
    private func eye(size eyeSize: CGFloat) -> some View {
        switch mood {
        case .sleepy:
            Capsule().fill(Color.black.opacity(0.75)).frame(width: eyeSize * 1.2, height: eyeSize * 0.25)
        case .curious:
            Circle().fill(Color.black.opacity(0.8)).frame(width: eyeSize * 1.1, height: eyeSize * 1.1)
                .overlay(Circle().fill(.white).frame(width: eyeSize * 0.35).offset(x: eyeSize * 0.18, y: -eyeSize * 0.18))
        default:
            Circle().fill(Color.black.opacity(0.8)).frame(width: eyeSize, height: eyeSize)
                .overlay(Circle().fill(.white).frame(width: eyeSize * 0.3).offset(x: eyeSize * 0.15, y: -eyeSize * 0.15))
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .happy:
            SmileShape(curve: 1).stroke(Color.black.opacity(0.75), style: StrokeStyle(lineWidth: size * 0.03, lineCap: .round))
        case .sleepy:
            Ellipse().fill(Color.black.opacity(0.6)).frame(width: size * 0.07, height: size * 0.05)
        case .wobbly:
            WavyShape().stroke(Color.black.opacity(0.75), style: StrokeStyle(lineWidth: size * 0.025, lineCap: .round))
        case .curious:
            Circle().stroke(Color.black.opacity(0.75), lineWidth: size * 0.025).frame(width: size * 0.07)
        }
    }

    @ViewBuilder
    private var hat: some View {
        switch hatID {
        case "cap":
            ZStack(alignment: .bottomTrailing) {
                HalfCircle().fill(Color.red).frame(width: size * 0.42, height: size * 0.2)
                Capsule().fill(Color.red.opacity(0.85)).frame(width: size * 0.26, height: size * 0.05).offset(x: size * 0.14)
            }
        case "party":
            TriangleShape().fill(LinearGradient(colors: [.pink, .purple], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.26, height: size * 0.32)
                .overlay(alignment: .top) { Circle().fill(.yellow).frame(width: size * 0.07).offset(y: -size * 0.03) }
        case "crown":
            CrownShape().fill(Color.yellow).frame(width: size * 0.36, height: size * 0.2)
                .overlay(CrownShape().stroke(Color.orange, lineWidth: 2))
        case "wizard":
            TriangleShape().fill(Color.indigo).frame(width: size * 0.3, height: size * 0.4)
                .overlay(Image(systemName: "star.fill").font(.system(size: size * 0.07)).foregroundStyle(.yellow))
        default:
            EmptyView()
        }
    }
}

struct BlobShape: Shape {
    var wobble: CGFloat

    var animatableData: CGFloat {
        get { wobble }
        set { wobble = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addCurve(to: CGPoint(x: w, y: h * (0.55 + wobble)),
                      control1: CGPoint(x: w * 0.85, y: 0), control2: CGPoint(x: w, y: h * 0.25))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h),
                      control1: CGPoint(x: w, y: h * 0.85), control2: CGPoint(x: w * 0.78, y: h))
        path.addCurve(to: CGPoint(x: 0, y: h * (0.55 - wobble)),
                      control1: CGPoint(x: w * 0.22, y: h), control2: CGPoint(x: 0, y: h * 0.85))
        path.addCurve(to: CGPoint(x: w * 0.5, y: 0),
                      control1: CGPoint(x: 0, y: h * 0.25), control2: CGPoint(x: w * 0.15, y: 0))
        path.closeSubpath()
        return path
    }
}

struct SmileShape: Shape {
    var curve: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY * 0.6))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: rect.midY * 0.6),
                          control: CGPoint(x: rect.midX, y: rect.height * (0.6 + 0.8 * curve)))
        return path
    }
}

struct WavyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        let segments = 4
        let step = rect.width / CGFloat(segments)
        for i in 0..<segments {
            let x = CGFloat(i) * step
            path.addQuadCurve(to: CGPoint(x: x + step, y: rect.midY),
                              control: CGPoint(x: x + step / 2, y: i % 2 == 0 ? rect.minY : rect.maxY))
        }
        return path
    }
}

struct HalfCircle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: rect.width / 2,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct CrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.width * 0.25, y: rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.75, y: rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A child's avatar: photo if the parent added one, otherwise a symbol.
struct ChildAvatar: View {
    var child: ChildProfile
    var size: CGFloat = 44

    var body: some View {
        Group {
            if child.hasPhoto, let image = ChildPhotoStore.load(child.id) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    KidTheme.avatarColor(child.avatar)
                    Image(systemName: child.avatar.symbol)
                        .font(.system(size: size * 0.45, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel(child.name)
    }
}
