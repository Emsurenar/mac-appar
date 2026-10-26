import AppKit
import SwiftUI

/// The last things you copied. Clicking one copies it again and pastes it.
struct ClipboardTab: View {
    @Environment(IslandModel.self) private var model

    var body: some View {
        Group {
            if model.clipboard.items.isEmpty {
                emptyState
            } else {
                itemList
            }
        }
        .padding(.top, 4)
    }

    private var itemList: some View {
        let clipboard = model.clipboard
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Clipboard")
                Spacer()
                Button("Clear") { withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { clipboard.clear() } }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.45))
            .frame(height: IslandLayout.sectionHeaderHeight, alignment: .bottom)

            Group {
                if clipboard.items.count > IslandLayout.maxClipboardRows {
                    ScrollView(.vertical) { rows }
                        .scrollIndicators(.never)
                } else {
                    rows
                }
            }
            .frame(height: CGFloat(min(clipboard.items.count, IslandLayout.maxClipboardRows)) * IslandLayout.clipboardRowHeight,
                   alignment: .top)
            .padding(.horizontal, -6)
        }
    }

    private var rows: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(spacing: 0) {
                ForEach(Array(model.clipboard.items.enumerated()), id: \.element.id) { index, item in
                    ClipboardRow(item: item, isCurrent: index == 0, now: context.date,
                                 onSelect: { model.useClipboardItem(item) },
                                 onRemove: { model.clipboard.remove(item) })
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Nothing copied yet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Copy text or an image and it shows up here.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(height: IslandLayout.clipboardEmptyHeight - 34)
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    /// The item that is on the pasteboard right now.
    let isCurrent: Bool
    let now: Date
    let onSelect: () -> Void
    let onRemove: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                preview
                Spacer(minLength: 8)
                if isHovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(.white.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                    .help("Remove")
                    .transition(.opacity)
                } else {
                    Text(relativeTime)
                        .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(isCurrent ? 0.75 : 0.4))
                }
            }
            .padding(.horizontal, 6)
            .frame(height: IslandLayout.clipboardRowHeight)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.white.opacity(isHovering ? 0.08 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .help(ClipboardService.canPaste ? "Paste" : "Copy")
    }

    @ViewBuilder private var preview: some View {
        HStack(spacing: 10) {
            sourceIcon
            switch item.content {
            case .text(let text):
                Text(singleLine(text))
                    .font(.system(size: 13, weight: isCurrent ? .semibold : .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            case .image(let data):
                if let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    Text("Image · \(Int(image.size.width))×\(Int(image.size.height))")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    @ViewBuilder private var sourceIcon: some View {
        if let id = item.sourceBundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 20, height: 20)
        }
    }

    private func singleLine(_ text: String) -> String {
        // Only the start is ever visible, so long copies are cut before they are split.
        text.prefix(300).split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ⏎ ")
    }

    private var relativeTime: String {
        let seconds = now.timeIntervalSince(item.date)
        if seconds < 60 { return "Now" }
        if seconds < 3600 { return "\(Int(seconds / 60)) min" }
        return item.date.formatted(date: .omitted, time: .shortened)
    }
}
