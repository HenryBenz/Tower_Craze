import SwiftUI

enum Site {
    static let ink = Color(red: 0.17, green: 0.11, blue: 0.08)
    static let yellow = Color(red: 1.0, green: 0.76, blue: 0.1)
    static let orange = Color(red: 0.96, green: 0.45, blue: 0.14)
    static let red = Color(red: 0.91, green: 0.28, blue: 0.23)
    static let concrete = Color(red: 0.9, green: 0.87, blue: 0.8)
    static let blueprint = Color(red: 0.11, green: 0.3, blue: 0.54)
    static let sky = Color(red: 0.62, green: 0.86, blue: 1)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

/// Плоская «строительная» кнопка: толстый контур и сдвинутая тень, при нажатии кнопка опускается на тень.
struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = Site.yellow
    var text: Color = Site.ink
    var height: CGFloat = 60

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Site.font(22))
            .textCase(.uppercase)
            .foregroundColor(text)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(RoundedRectangle(cornerRadius: 10).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Site.ink, lineWidth: 4))
            .background(RoundedRectangle(cornerRadius: 10).fill(Site.ink).offset(x: configuration.isPressed ? 0 : 5, y: configuration.isPressed ? 0 : 6))
            .offset(x: configuration.isPressed ? 5 : 0, y: configuration.isPressed ? 6 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension View {
    /// Табличка на стройке: светлый бетон, толстый контур, сдвинутая тень.
    func signPanel(_ fill: Color = Site.concrete) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: 12).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Site.ink, lineWidth: 4))
            .background(RoundedRectangle(cornerRadius: 12).fill(Site.ink).offset(x: 5, y: 6))
    }
}

func siteTap() {
    Sound.shared.play("tap", volume: 0.7)
    Haptics.light()
}

struct SiteBackground: View {
    var body: some View {
        GeometryReader { geo in
            Image(uiImage: Art.image("bg_site"))
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
    }
}

/// Лента с жёлто-чёрными полосами.
struct HazardStripe: View {
    var height: CGFloat = 16
    var body: some View {
        GeometryReader { geo in
            Image(uiImage: Art.image("hazard"))
                .resizable(resizingMode: .tile)
                .frame(width: geo.size.width, height: height)
        }
        .frame(height: height)
    }
}

/// Голубая «калька чертежа» с сеткой.
struct BlueprintBackground: View {
    var body: some View {
        ZStack {
            Site.blueprint
            Canvas { ctx, size in
                var path = Path()
                var x: CGFloat = 0
                while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += 22 }
                var y: CGFloat = 0
                while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += 22 }
                ctx.stroke(path, with: .color(Color.white.opacity(0.12)), lineWidth: 1)
            }
        }
        .ignoresSafeArea()
    }
}

struct SiteHeader: View {
    let title: String
    let back: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    siteTap()
                    back()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(Site.ink)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Site.yellow))
                        .overlay(Circle().stroke(Site.ink, lineWidth: 4))
                }
                .buttonStyle(PressStyle())
                Text(title)
                    .font(Site.font(28))
                    .textCase(.uppercase)
                    .foregroundColor(.white)
                    .shadow(color: Site.ink, radius: 0, x: 2, y: 3)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            HazardStripe(height: 14)
        }
        .background(Site.ink.opacity(0.85).ignoresSafeArea(edges: .top))
    }
}

struct SiteToast: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hammer.fill").foregroundColor(Site.ink)
            Text(text).font(Site.font(16, .heavy)).foregroundColor(Site.ink)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .signPanel(Site.yellow)
        .padding(.horizontal, 24)
    }
}
