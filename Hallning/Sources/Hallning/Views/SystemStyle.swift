import SwiftUI

// The building blocks of System Settings and Control Center, so the app reads as part of macOS.

/// The coloured rounded square System Settings uses for sidebar items, rows and pane headers.
struct SettingsIcon<Glyph: View>: View {
    var color: Color
    var size: CGFloat = 20
    @ViewBuilder var glyph: Glyph

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
            .fill(LinearGradient(colors: [color.mix(with: .white, by: 0.12), color],
                                 startPoint: .top, endPoint: .bottom))
            .overlay { glyph.foregroundStyle(.white) }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.15), radius: 0.5, y: 0.5)
    }
}

extension SettingsIcon where Glyph == SymbolGlyph {
    init(_ symbol: String, color: Color, size: CGFloat = 20) {
        self.init(color: color, size: size) { SymbolGlyph(symbol: symbol, size: size) }
    }
}

struct SymbolGlyph: View {
    var symbol: String
    var size: CGFloat

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .medium))
            .symbolRenderingMode(.monochrome)
    }
}

/// The app's own icon: the seated figure on teal, coloured by status when given one.
struct FigureIcon: View {
    var slouch: Double = 0
    var color: Color = .teal
    var size: CGFloat = 20

    var body: some View {
        SettingsIcon(color: color, size: size) {
            PostureFigure(slouch: slouch)
                .fill(.white)
                .padding(size * 0.18)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: slouch)
    }
}

/// The first group of a System Settings pane: a large icon, the title, a short
/// description and an optional control on the trailing edge.
struct PaneHeader<Icon: View, Detail: View, Trailing: View>: View {
    var title: String
    @ViewBuilder var icon: Icon
    @ViewBuilder var detail: Detail
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .contentTransition(.opacity)
                detail
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.vertical, 6)
    }
}

extension PaneHeader where Trailing == EmptyView {
    init(title: String, @ViewBuilder icon: () -> Icon, @ViewBuilder detail: () -> Detail) {
        self.init(title: title, icon: icon, detail: detail, trailing: { EmptyView() })
    }
}

/// A form row label with a small settings icon, as in System Settings lists.
struct IconLabel: View {
    var title: String
    var symbol: String
    var color: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            SettingsIcon(symbol, color: color, size: 20)
        }
    }
}

// MARK: - Control Center

/// A grey section title inside a menu bar window.
struct MenuSectionTitle: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
    }
}

/// A full-width menu row that highlights under the pointer, like the rows in Control Center.
struct MenuRow<Trailing: View>: View {
    var title: String
    var symbol: String?
    var action: () -> Void
    @ViewBuilder var trailing: Trailing

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 16)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.system(size: 13))
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(isHovering && isEnabled ? 0.09 : 0))
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

extension MenuRow where Trailing == EmptyView {
    init(_ title: String, symbol: String? = nil, action: @escaping () -> Void) {
        self.init(title: title, symbol: symbol, action: action, trailing: { EmptyView() })
    }
}

/// The thin separator between groups in a menu bar window.
struct MenuDivider: View {
    var body: some View {
        Divider().padding(.horizontal, 8).padding(.vertical, 5)
    }
}
