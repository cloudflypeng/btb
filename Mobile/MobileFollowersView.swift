import SwiftUI

struct MobileFollowersView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if !model.hasAccount {
                MobileLoginPrompt(title: "登录后查看粉丝", message: "登录后可以看到关注你的用户。")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        if let error = model.followersError {
                            MobileErrorBanner(text: error) {
                                Task { await model.loadFollowers(force: true) }
                            }
                        }

                        if model.isLoadingFollowers && model.followers.isEmpty {
                            ProgressView()
                                .tint(AppTheme.brand)
                                .padding(.top, 60)
                        } else if model.followers.isEmpty {
                            MobileEmptyState(
                                icon: "person.2",
                                title: "还没有粉丝",
                                message: "多发点内容，吸引大家关注你吧"
                            )
                        } else {
                            if model.followersTotal > 0 {
                                HStack {
                                    Text("共 \(MobileFormat.count(model.followersTotal)) 位粉丝")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.secondary(scheme))
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                            }

                            ForEach(model.followers) { follower in
                                NavigationLink {
                                    MobileUPView(route: MobileUPRoute(
                                        mid: follower.mid,
                                        name: follower.name,
                                        avatarURL: follower.avatarURL
                                    ))
                                } label: {
                                    MobileFollowingRow(up: follower)
                                }
                                .buttonStyle(.plain)
                            }

                            InfiniteScrollFooter(
                                isLoading: model.isLoadingFollowers || model.followersPager.isLoadingMore,
                                hasMore: model.followersPager.hasMore,
                                failed: model.followersPager.failed
                            ) {
                                Task { await model.loadMoreFollowers() }
                            }
                        }
                    }
                    .padding(12)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await model.loadFollowers(force: true)
                }
            }
        }
        .background(AppTheme.background(scheme))
        .navigationTitle("我的粉丝")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await model.loadFollowers()
        }
    }
}
