import SwiftUI

extension MobileTab: CaseIterable, Identifiable {
    var id: Self { self }

    static var allCases: [MobileTab] {
        [.home, .dynamic, .discover, .messages, .profile]
    }

    var title: String {
        switch self {
        case .home: "首页"
        case .dynamic: "动态"
        case .discover: "发现"
        case .messages: "消息"
        case .profile: "我的"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .dynamic: "bolt.horizontal"
        case .discover: "safari"
        case .messages: "bell"
        case .profile: "person.crop.circle"
        }
    }

    var selectedIcon: String { icon + ".fill" }
}

/// The bottom bar, drawn by us instead of the system one.
///
/// The system tab bar can only be shown or hidden in one step, which read as
/// a flicker next to the header's slide. Owning the view means the bar leaves
/// the screen on the same spring the header uses, at the moment the feed
/// starts scrolling down.
struct MobileTabBar: View {
    let selection: MobileTab
    var badge: Int = 0
    var hidden = false
    var onSelect: (MobileTab) -> Void

    @Environment(\.colorScheme) private var scheme

    private let barHeight: CGFloat = 54

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MobileTab.allCases) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    item(tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: barHeight)
        .modifier(MobileGlassBarBackground())
        .padding(.horizontal, 10)
        .offset(y: hidden ? barHeight + 60 : 0)
        .opacity(hidden ? 0 : 1)
        // Short and damped: the bar should look carried away by the scroll,
        // not animated on its own schedule.
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: hidden)
        .allowsHitTesting(!hidden)
        .accessibilityHidden(hidden)
    }

    private func item(_ tab: MobileTab) -> some View {
        let selected = tab == selection
        return VStack(spacing: 2) {
            Image(systemName: selected ? tab.selectedIcon : tab.icon)
                .font(.system(size: 19, weight: selected ? .semibold : .regular))
                .frame(width: 30, height: 22)
                .overlay(alignment: .topTrailing) {
                    if tab == .messages, badge > 0 {
                        Text(badge > 99 ? "99+" : "\(badge)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .frame(minWidth: 14, minHeight: 14)
                            .background(AppTheme.brand, in: Capsule())
                            .offset(x: 9, y: -5)
                    }
                }
            Text(tab.title)
                .font(.system(size: 10, weight: selected ? .semibold : .medium))
        }
        .foregroundStyle(selected ? AppTheme.text(scheme) : AppTheme.secondary(scheme))
        .frame(maxWidth: .infinity)
        .frame(height: barHeight - 6)
        .contentShape(Rectangle())
    }
}

private struct MobileGlassBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
        }
    }
}
