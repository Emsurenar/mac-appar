import AppKit
import SwiftUI

/// Apple Home scenes and accessories — or any other shortcut — as tiles.
struct HomeTab: View {
    @Environment(IslandModel.self) private var model

    var body: some View {
        ZStack(alignment: .top) {
            if model.isChoosingShortcuts {
                ShortcutPicker()
                    .transition(.islandContent(scale: 0.97))
            } else if model.home.shortcuts.isEmpty {
                emptyState
                    .transition(.islandContent(scale: 0.97))
            } else {
                tiles
                    .transition(.islandContent(scale: 0.97))
            }
        }
    }

    private enum Item: Identifiable {
        case shortcut(HomeShortcut)
        case add

        var id: String {
            switch self {
            case .shortcut(let shortcut): shortcut.id
            case .add: "add"
            }
        }
    }

    private var tiles: some View {
        let home = model.home
        let columns = IslandLayout.homeColumns
        let items = home.shortcuts.map(Item.shortcut) + [.add]
        let rows = stride(from: 0, to: items.count, by: columns).map {
            Array(items[$0..<min($0 + columns, items.count)])
        }
        let grid = VStack(spacing: IslandLayout.homeTileSpacing) {
            ForEach(rows, id: \.first?.id) { row in
                HStack(spacing: IslandLayout.homeTileSpacing) {
                    ForEach(row) { item in
                        switch item {
                        case .shortcut(let shortcut):
                            HomeTile(shortcut: shortcut,
                                     state: home.runStates[shortcut.id] ?? .idle,
                                     isOn: home.toggleStates[shortcut.id],
                                     tint: home.color(for: shortcut)) {
                                home.run(shortcut)
                            }
                            .contextMenu {
                                Button("Choose Color…") { home.chooseColor(for: shortcut) }
                                if home.tileColors[shortcut.id] != nil {
                                    Button("Remove Color") { home.setColor(nil, for: shortcut) }
                                }
                                Divider()
                                if home.isPinned(shortcut) {
                                    Button("Remove from Island") { home.togglePin(shortcut) }
                                }
                                Button("Edit in Shortcuts") { home.reveal(shortcut) }
                            }
                        case .add:
                            AddTile { model.setChoosingShortcuts(true) }
                        }
                    }
                    ForEach(row.count..<columns, id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
                .frame(height: IslandLayout.homeTileHeight)
            }
        }

        return Group {
            if rows.count > IslandLayout.maxHomeRows {
                ScrollView(.vertical) { grid }.scrollIndicators(.never)
            } else {
                grid
            }
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        let hasShortcuts = !model.home.allShortcuts.isEmpty
        return HStack(spacing: 16) {
            Group {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.shortcuts") {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
                } else {
                    Image(systemName: "square.stack.3d.up.fill").font(.system(size: 26)).foregroundStyle(.pink)
                }
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 3) {
                Text(hasShortcuts ? "Run shortcuts from here" : "No shortcuts yet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(hasShortcuts
                     ? "Pick the shortcuts you want as tiles – for example ones that set a Home scene."
                     : "Create a shortcut in Shortcuts – for example one that controls your Home – and pick it here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if hasShortcuts {
                        CapsuleButton(title: "Choose Shortcuts", isProminent: true) { model.setChoosingShortcuts(true) }
                    }
                    CapsuleButton(title: "Open Shortcuts") { HomeService.openShortcutsApp() }
                }
                .padding(.top, 7)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }
}

/// Every shortcut in the Shortcuts app, with a checkmark for the ones that have a tile.
private struct ShortcutPicker: View {
    @Environment(IslandModel.self) private var model

    var body: some View {
        let home = model.home
        let visibleRows = min(max(home.allShortcuts.count, 1), IslandLayout.maxVisibleDevices)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Choose Shortcuts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                CapsuleButton(title: "Done", isProminent: true) { model.setChoosingShortcuts(false) }
            }
            .frame(height: IslandLayout.sectionHeaderHeight)

            Group {
                if home.allShortcuts.count > IslandLayout.maxVisibleDevices {
                    ScrollView(.vertical) { list }.scrollIndicators(.never)
                } else {
                    list
                }
            }
            .frame(height: CGFloat(visibleRows) * IslandLayout.deviceRowHeight, alignment: .top)
            .padding(.horizontal, -6)
        }
        .padding(.top, 4)
    }

    private var list: some View {
        let home = model.home
        return VStack(spacing: 0) {
            if home.allShortcuts.isEmpty {
                Text("No shortcuts found")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, minHeight: IslandLayout.deviceRowHeight)
            }
            ForEach(home.allShortcuts) { shortcut in
                ShortcutPickerRow(shortcut: shortcut, isPinned: home.isPinned(shortcut),
                                  isInFolder: home.isInFolder(shortcut)) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { home.togglePin(shortcut) }
                }
            }
        }
    }
}

private struct ShortcutPickerRow: View {
    let shortcut: HomeShortcut
    let isPinned: Bool
    let isInFolder: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        let isSelected = isPinned || isInFolder
        Button(action: action) {
            HStack(spacing: 10) {
                Group {
                    if let emoji = shortcut.emoji {
                        Text(emoji).font(.system(size: 13))
                    } else {
                        Image(systemName: shortcut.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 26, height: 26)
                .background(Circle().fill(.white.opacity(0.14)))

                Text(shortcut.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if isInFolder {
                    Text("In folder")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer(minLength: 8)
                Group {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .font(.system(size: 17))
                .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 6)
            .frame(height: IslandLayout.deviceRowHeight)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.white.opacity(isHovering ? 0.08 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isInFolder)
        .onHover { isHovering = $0 }
        .help(isInFolder ? "Shortcuts in the folder from Settings always get a tile" : shortcut.name)
    }
}

/// The last tile: opens the shortcut picker.
private struct AddTile: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text("Add")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white.opacity(isHovering ? 0.9 : 0.55))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(isHovering ? 0.35 : 0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableTileStyle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .help("Choose shortcuts")
    }
}

private struct HomeTile: View {
    let shortcut: HomeShortcut
    let state: HomeRunState
    let isOn: Bool?
    /// The color the user picked for this tile, if any.
    var tint: NSColor? = nil
    let action: () -> Void

    @State private var isHovering = false
    @State private var successCount = 0

    var body: some View {
        let isActive = isOn == true
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                icon(isActive: isActive)
                Spacer(minLength: 0)
                Text(shortcut.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let status {
                    Text(status)
                        .font(.system(size: 11))
                        .opacity(0.6)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                }
            }
            .foregroundStyle(usesDarkText(isActive: isActive) ? Color.black : Color.white)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(background(isActive: isActive))
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableTileStyle())
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isActive)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: state)
        .animation(.easeOut(duration: 0.2), value: tint)
        .onChange(of: state) { _, newState in
            if newState == .succeeded { successCount += 1 }
        }
        .help(shortcut.name)
    }

    /// Plain tiles are translucent gray and turn white when on. A colored tile is
    /// a deep wash of its color, and fills with it when on.
    private func background(isActive: Bool) -> Color {
        if let tint {
            let color = Color(nsColor: tint)
            return isActive ? color : color.opacity(isHovering ? 0.55 : 0.42)
        }
        return isActive ? Color.white.opacity(0.94) : Color.white.opacity(isHovering ? 0.15 : 0.09)
    }

    private func usesDarkText(isActive: Bool) -> Bool {
        guard isActive else { return false }
        return tint?.isLight ?? true
    }

    private var status: String? {
        switch state {
        case .running: "Running…"
        case .failed: "Failed"
        case .succeeded: isOn.map { $0 ? "On" : "Off" } ?? "Done"
        case .idle: isOn.map { $0 ? "On" : "Off" }
        }
    }

    @ViewBuilder
    private func icon(isActive: Bool) -> some View {
        ZStack {
            Circle().fill(iconFill(isActive: isActive))
            switch state {
            case .running:
                Spinner(color: usesDarkText(isActive: isActive) ? .black : .white)
                    .frame(width: 14, height: 14)
                    .transition(.scale.combined(with: .opacity))
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                    .transition(.scale.combined(with: .opacity))
            default:
                Group {
                    if let emoji = shortcut.emoji {
                        Text(emoji).font(.system(size: 15))
                    } else {
                        Image(systemName: shortcut.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .symbolEffect(.bounce, value: successCount)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 28, height: 28)
    }

    private func iconFill(isActive: Bool) -> Color {
        if let tint {
            // On a colored tile the circle stays neutral so the tile's color carries it.
            return isActive ? Color.black.opacity(0.18) : Color(nsColor: tint).opacity(0.9)
        }
        return isActive ? accent : Color.white.opacity(0.14)
    }

    private var accent: Color {
        switch shortcut.symbol {
        case "lightbulb.fill", "lamp.floor.fill", "lamp.desk.fill", "light.recessed.fill": .orange
        case "lock.fill", "door.garage.closed": .teal
        case "thermometer.medium": .red
        case "fan.fill", "air.purifier.fill": .cyan
        case "blinds.horizontal.closed", "moon.stars.fill": .indigo
        case "tv.fill", "hifispeaker.fill": .blue
        case "poweroutlet.type.f.fill": .green
        default: .orange
        }
    }
}

private struct PressableTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct Spinner: View {
    var color: Color
    @State private var isSpinning = false

    var body: some View {
        Circle()
            .trim(from: 0.12, to: 0.82)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isSpinning)
            .onAppear { isSpinning = true }
    }
}

struct CapsuleButton: View {
    let title: String
    /// White fill for the main action, like a default button.
    var isProminent = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isProminent ? Color.black : Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(isProminent ? Color.white.opacity(isHovering ? 1 : 0.9)
                                                       : Color.white.opacity(isHovering ? 0.22 : 0.14)))
                .contentShape(Capsule())
        }
        .buttonStyle(PressableTileStyle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}
