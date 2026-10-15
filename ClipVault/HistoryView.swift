import SwiftUI
import AppKit

struct HistoryView: View {
    @EnvironmentObject var controller: PanelController
    @EnvironmentObject var monitor: ClipboardMonitor
    @FocusState private var searchFocused: Bool

    var body: some View {
        let items = controller.filteredItems

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Type to search", text: $controller.query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onChange(of: controller.query) { controller.selectedIndex = 0 }
                Spacer()
                Text("←/→ select · Return paste · Esc close")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            if items.isEmpty {
                Text(monitor.items.isEmpty ? "Nothing copied yet" : "No matches")
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
}

struct ClipCard: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: source app + time
            HStack(spacing: 8) {
                if let path = item.sourceAppPath {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable()
                        .frame(width: 22, height: 22)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.sourceAppName ?? "Text")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(item.date, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if index < 9 {
                    Text("⌘\(index + 1)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(Color.accentColor.opacity(isSelected ? 0.25 : 0.08))

            Text(item.text)
                .font(.system(size: 12))
                .lineLimit(9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)

            Text("\(item.text.count) characters")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding([.horizontal, .bottom], 10)
        }
        .frame(width: 220, height: 220)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.1),
                        lineWidth: isSelected ? 3 : 1)
        )
        .contentShape(Rectangle())
    }
}
