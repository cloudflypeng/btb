import SwiftUI

struct BtbSectionHeader: View {
    let title: String
    var systemImage: String?
    var count: Int?
    var actionTitle: String?
    var action: (() -> Void)?

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
            }
            .foregroundStyle(AppTheme.text(scheme))

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
                .buttonStyle(BtbPressableStyle(scale: 0.96, haptic: false))
            }
        }
    }
}

struct BtbPill: View {
    let title: String
    let isSelected: Bool
    var systemImage: String?
    var badge: String?
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10.5, weight: .semibold))
                }
                Text(title)
                if let badge, !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(AppTheme.brand, in: Capsule())
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isSelected ? AppTheme.selectedText(scheme) : AppTheme.text(scheme))
            .padding(.horizontal, 14)
            .frame(height: BtbDimens.controlHeight)
            .background(
                isSelected
                    ? AppTheme.selected(scheme)
                    : (isHovering ? AppTheme.surfaceHover(scheme) : AppTheme.chip(scheme)),
                in: Capsule()
            )
            .contentShape(Capsule())
        }
        .buttonStyle(BtbPressableStyle(scale: 0.96, haptic: false))
        .animation(BtbMotion.curve(BtbMotion.fast), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

struct BtbFilterOption: Identifiable, Hashable {
    let id: String
    let title: String
    var badge: String?

    init(id: String, title: String, badge: String? = nil) {
        self.id = id
        self.title = title
        self.badge = badge
    }
}

struct BtbFilterRow: View {
    let options: [BtbFilterOption]
    let selectedID: String
    var onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options) { option in
                    BtbPill(
                        title: option.title,
                        isSelected: option.id == selectedID,
                        badge: option.badge
                    ) {
                        onSelect(option.id)
                    }
                }
            }
            .padding(.horizontal, 14)
        }
    }
}

struct BtbInfiniteScrollFooter: View {
    let isLoading: Bool
    let hasMore: Bool
    let failed: Bool
    var endText: String = "没有更多了"
    var height: CGFloat = btbInfiniteScrollFooterHeight
    let loadMore: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if failed {
                Button {
                    loadMore()
                } label: {
                    Text("加载失败，点击重试")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
                .buttonStyle(.plain)
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if !hasMore {
                Text(endText)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.tertiary(scheme))
            } else {
                Color.clear
                    .frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .onAppear(perform: trigger)
        .onChange(of: isLoading) { _, loading in
            if !loading {
                trigger()
            }
        }
    }

    private func trigger() {
        guard hasMore, !isLoading, !failed else { return }
        loadMore()
    }
}

private var btbInfiniteScrollFooterHeight: CGFloat {
    #if os(macOS)
    46
    #else
    52
    #endif
}
