import SwiftUI

struct MobilePartitionsView: View {
    @Environment(AppModel.self) private var model
    @Environment(MobileRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private var filters: [HomeFilter] {
        HomeFilter.allCases.filter { $0 != .all }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filters) { filter in
                    Button {
                        open(filter)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AppTheme.secondary(scheme))
                                .frame(width: 24)

                            Text(filter.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.text(scheme))

                            Spacer(minLength: 8)

                            if model.homeFilter == filter {
                                Text("当前")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppTheme.secondary(scheme))
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.tertiary(scheme))
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(filter.title)

                    Divider()
                        .opacity(0.5)
                        .padding(.leading, 52)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
        .navigationTitle("分区")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func open(_ filter: HomeFilter) {
        model.homeFilter = filter
        dismiss()
        router.selectedTab = .home
        Task { await model.selectHomeFilter(filter) }
    }
}
