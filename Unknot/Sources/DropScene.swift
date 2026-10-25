import SwiftUI

/// The top of a Mac screen, drawn like Dynamic Island's screenshots: the wallpaper, the menu bar, the camera
/// notch, and a break growing out of it.
struct DropScene: View {
    @ObservedObject var session: ReminderSession
    /// Where the island is in its animation; nil while it's still inside the notch.
    var frame: NotchDrop.Frame?
    var mood: MenuBarIcon.Mood = .awake

    static let size = CGSize(width: 880, height: 232)
    static let menuBar: CGFloat = 32
    static let notch = CGRect(x: (size.width - 186) / 2, y: 0, width: 186, height: menuBar)

    /// The island's path through the scene, the same as the real window's.
    static var drop: NotchDrop {
        let island = ReminderView.size(topInset: menuBar, sideInset: Island.earRadius)
        return NotchDrop(start: notch, island: CGRect(x: (size.width - island.width) / 2, y: 0,
                                                      width: island.width, height: island.height))
    }

    var body: some View {
        let island = Self.drop.island
        ZStack(alignment: .topLeading) {
            Island.wallpaper
            menuBarView
            Path(Island.outline(Self.notch, ear: 0, bottom: 8)).fill(Color.black)

            if let frame {
                let outline = Path(frame.outline)
                outline.fill(Color.black)
                    .shadow(color: .black.opacity(0.45 * frame.shadow), radius: 18, y: 8)
                ReminderView(s: session, topInset: Self.menuBar, sideInset: Island.earRadius)
                    .frame(width: island.width, height: island.height)
                    .offset(x: island.minX, y: island.minY)
                    .mask(outline)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    private var menuBarView: some View {
        HStack(spacing: 18) {
            Image(systemName: "apple.logo").font(.system(size: 14, weight: .medium))
            Text(verbatim: "Finder").font(.system(size: 13, weight: .bold))
            ForEach(["File", "Edit", "View"], id: \.self) { Text(verbatim: $0).font(.system(size: 13)) }
            Spacer()
            Image(nsImage: MenuBarIcon.image(mood)).renderingMode(.template)
            Image(systemName: "wifi").font(.system(size: 13))
            Image(systemName: "battery.75percent").font(.system(size: 15))
            Text(verbatim: "Wed 10:40").font(.system(size: 13))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(width: Self.size.width, height: Self.menuBar)
    }
}
