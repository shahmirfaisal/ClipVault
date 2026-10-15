import SwiftUI
import AppKit
import ImageIO
import QuickLookThumbnailing

struct HistoryView: View {
    @EnvironmentObject var controller: PanelController
    @EnvironmentObject var monitor: ClipboardMonitor
    @FocusState private var searchFocused: Bool

    var body: some View {
        let items = controller.filteredItems

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Picker("", selection: $controller.showPinnedOnly) {
                    Text("History").tag(false)
                    Text("Pinned").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 170)
                .onChange(of: controller.showPinnedOnly) { controller.selectedIndex = 0 }

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Type to search", text: $controller.query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .onChange(of: controller.query) { controller.selectedIndex = 0 }
                }
                .frame(maxWidth: 320)

                Spacer()

                Text("↩ paste · ⌘C copy · ⌘P pin · ⌘⌫ delete · ⇥ pinned · esc close")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Button { controller.openSettings() } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Settings (⌘,)")
            }
            .padding(.horizontal, 20)

            if items.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 14) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                ClipCard(item: item,
                                         index: index,
                                         isSelected: index == controller.selectedIndex)
                                    .id(item.id)
                                    .onTapGesture(count: 2) { controller.paste(item) }
                                    .onTapGesture { controller.selectedIndex = index }
                                    .contextMenu { menu(for: item) }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                    .onChange(of: controller.selectedIndex) { _, new in
                        guard items.indices.contains(new) else { return }
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(items[new].id, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .onAppear { searchFocused = true }
    }

    private var emptyMessage: String {
        if !controller.query.isEmpty { return "No matches" }
        if controller.showPinnedOnly { return "No pinned items yet — select a card and press ⌘P" }
        return "Nothing copied yet"
    }

    @ViewBuilder
    private func menu(for item: ClipItem) -> some View {
        Button("Paste") { controller.paste(item) }
        Button("Copy") { controller.copyOnly(item) }
        Button(item.isPinned ? "Unpin" : "Pin") { controller.togglePin(item) }
        if item.kind == .link, let text = item.text, let url = URL(string: text) {
            Button("Open Link") { controller.hide(); NSWorkspace.shared.open(url) }
        }
        if item.kind == .file, let paths = item.filePaths {
            Button("Show in Finder") {
                controller.hide()
                NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: $0) })
            }
        }
        Divider()
        Button("Delete", role: .destructive) { controller.delete(item) }
    }
}

struct ClipCard: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Text(footer)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding([.horizontal, .bottom], 10)
        }
        .frame(width: 220, height: 220)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.1),
                        lineWidth: isSelected ? 3 : 1)
        )
        .contentShape(Rectangle())
    }

    // Source app + time
    private var header: some View {
        HStack(spacing: 8) {
            if let path = item.sourceAppPath {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 22, height: 22)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.sourceAppName ?? kindName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(item.date, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.accentColor.opacity(isSelected ? 0.25 : 0.08))
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text:
            Text(item.text ?? "")
                .font(.system(size: 12))
                .lineLimit(9)
                .padding(10)

        case .link:
            VStack(alignment: .leading, spacing: 6) {
                Label(URL(string: item.text ?? "")?.host ?? "Link", systemImage: "link")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                Text(item.text ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
            }
            .padding(10)

        case .image:
            if let name = item.imageFile, let image = ThumbnailCache.image(named: name) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
            } else {
                Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .file:
            let paths = item.filePaths ?? []
            VStack(spacing: 8) {
                if let first = paths.first {
                    FileThumbnail(path: first)
                }
                Text(paths.count == 1 ? (paths[0] as NSString).lastPathComponent : "\(paths.count) files")
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(10)
        }
    }

    private var kindName: String {
        switch item.kind {
        case .text: "Text"
        case .link: "Link"
        case .image: "Image"
        case .file: "File"
        }
    }

    private var footer: String {
        switch item.kind {
        case .text: return "\(item.text?.count ?? 0) characters"
        case .link: return "Link"
        case .image:
            if let w = item.imageWidth, let h = item.imageHeight { return "\(w) × \(h) pixels" }
            return "Image"
        case .file:
            let paths = item.filePaths ?? []
            return paths.count == 1
                ? (paths[0] as NSString).deletingLastPathComponent
                : "\(paths.count) items"
        }
    }
}

/// Small downscaled previews so big screenshots don't slow the panel down.
enum ThumbnailCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(named name: String) -> NSImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        let url = HistoryStore.imageURL(name)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 440,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        cache.setObject(image, forKey: name as NSString)
        return image
    }
}

/// Shows a Quick Look preview (like Finder) for images, PDFs, videos and documents,
/// falling back to the file's icon.
struct FileThumbnail: View {
    let path: String
    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 190, maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 64, height: 64)
            }
        }
        .task(id: path) {
            thumbnail = await FileThumbnailCache.thumbnail(for: path)
        }
    }
}

enum FileThumbnailCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func thumbnail(for path: String) async -> NSImage? {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        let request = QLThumbnailGenerator.Request(
            fileAt: URL(fileURLWithPath: path),
            size: CGSize(width: 380, height: 240),
            scale: 2,
            representationTypes: .thumbnail // real previews only, not generic icons
        )
        guard let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return nil
        }
        let image = rep.nsImage
        cache.setObject(image, forKey: path as NSString)
        return image
    }
}
