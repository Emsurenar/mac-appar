import SwiftUI

/// The top of a Mac screen, drawn: wallpaper, menu bar, the camera notch, and a break coming out of it.
struct DropScene: View {
    @ObservedObject var session: ReminderSession
    var t: CGFloat
    var mood: MenuBarIcon.Mood = .awake
    var dark = false

    static let size = CGSize(width: 720, height: 236)
    private let menuBar: CGFloat = 30

    var body: some View {
        let notch = CGRect(x: (Self.size.width - 186) / 2, y: 0, width: 186, height: menuBar)
        let panel = CGRect(x: (Self.size.width - ReminderView.size.width) / 2, y: menuBar + 10,
                           width: ReminderView.size.width, height: ReminderView.size.height)
        let f = NotchDrop(start: notch, panel: panel, fromNotch: true, cornerRadius: ReminderView.cornerRadius).frame(at: t)
        let outline = Path(f.outline)

        ZStack(alignment: .topLeading) {
            LinearGradient(colors: dark ? [Color(hex: 0x2B3036), Color(hex: 0x1B1D21)] : [Color(hex: 0xE6DCD0), Color(hex: 0xC9CDD2)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            // Soft hills, so the glass has something to sit on
            Path { p in
                p.move(to: CGPoint(x: 0, y: 170))
                p.addCurve(to: CGPoint(x: 720, y: 150), control1: CGPoint(x: 220, y: 110), control2: CGPoint(x: 480, y: 210))
                p.addLine(to: CGPoint(x: 720, y: 236)); p.addLine(to: CGPoint(x: 0, y: 236)); p.closeSubpath()
            }
            .fill(dark ? Color(hex: 0x3A4048).opacity(0.7) : Color(hex: 0xB9AFA5).opacity(0.45))

            menuBarView
            // The notch, with the small flares where it meets the top of the screen
            Path(NotchDrop.outline(notch, top: 0, bottom: 10)).fill(Color.black)

            Group {
                outline.fill(dark ? Color(hex: 0x2C2B2B) : Color(hex: 0xF6F5F3))
                    .shadow(color: .black.opacity((dark ? 0.5 : 0.22) * f.shadow), radius: 14, y: 6)
                let stops = NotchDrop.inkStops(f.ink)
                outline.fill(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: stops.solid),
                                                    .init(color: .black.opacity(0), location: stops.clear)],
                                            startPoint: UnitPoint(x: 0.5, y: f.outline.boundingBoxOfPath.minY / Self.size.height),
                                            endPoint: UnitPoint(x: 0.5, y: f.outline.boundingBoxOfPath.maxY / Self.size.height)))
                ReminderView(s: session)
                    .frame(width: panel.width, height: panel.height)
                    .opacity(f.content)
                    .offset(x: panel.minX, y: panel.minY + f.contentOffset)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
        .environment(\.colorScheme, dark ? .dark : .light)
    }

    private var menuBarView: some View {
        let text = dark ? Color.white.opacity(0.9) : Color.black.opacity(0.82)
        return HStack(spacing: 18) {
            Image(systemName: "apple.logo").font(.system(size: 13, weight: .medium))
            Text(verbatim: "Finder").font(.system(size: 13, weight: .bold))
            ForEach(["File", "Edit", "View", "Go"], id: \.self) { Text(verbatim: $0).font(.system(size: 13)) }
            Spacer()
            Image(nsImage: MenuBarIcon.image(mood)).renderingMode(.template)
            Image(systemName: "wifi").font(.system(size: 13))
            Image(systemName: "battery.75percent").font(.system(size: 15))
            Text(verbatim: "Wed 10:40").font(.system(size: 13))
        }
        .foregroundStyle(text)
        .padding(.horizontal, 16)
        .frame(width: Self.size.width, height: menuBar)
        .background(dark ? Color.black.opacity(0.25) : Color.white.opacity(0.35))
    }
}
