import SwiftUI

struct MobileProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if let profile = model.profile {
                    accountHeader(profile)
                    if let error = model.profileError {
                        MobileErrorBanner(text: error) {
                            Task { await model.refreshProfile() }
                        }
                    }
                    uploadsShelf
                    historyShelf
                    librarySection
                } else if model.isProfileLoading {
                    ProgressView("正在加载个人主页…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else {
                    loggedOut
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            await model.refreshProfile()
        }
    }

    private var header: some View {
        HStack {
            Text("我的")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            Spacer()
            if model.profile != nil {
                NavigationLink {
                    MobileSettingsView()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .frame(width: 36, height: 36)
                        .background(AppTheme.chip(scheme), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func accountHeader(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                AvatarView(url: profile.avatarURL, size: 66)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(profile.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(1)
                        Text("LV\(profile.level)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .frame(height: 16)
                            .background(AppTheme.brand, in: Capsule())
                    }
                    Text(verbatim: "UID \(profile.mid)")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                    if !profile.sign.isEmpty {
                        Text(profile.sign)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 24) {
                NavigationLink {
                    MobileFollowingView()
                } label: {
                    statistic("关注", value: profile.following)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    MobileFollowersView()
                } label: {
                    statistic("粉丝", value: profile.follower)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }

    private func statistic(_ title: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(MobileFormat.count(value))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
                .monospacedDigit()
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondary(scheme))
        }
    }

    @ViewBuilder
    private var uploadsShelf: some View {
        if !model.uploads.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("最近投稿")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.text(scheme))
                    Spacer()
                    NavigationLink {
                        MobileUploadsView()
                    } label: {
                        Text("查看全部")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(model.uploads.prefix(10)) { video in
                            MobileVideoLink(video: video) {
                                MobileShelfCard(video: video)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var historyShelf: some View {
        if !model.history.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("历史记录")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.text(scheme))
                    Spacer()
                    NavigationLink {
                        MobileHistoryView(hidesTabBar: true)
                    } label: {
                        Text("查看全部")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(model.history.prefix(10)) { video in
                            MobileVideoLink(video: video) {
                                MobileShelfCard(video: video)
                            }
                        }
                    }
                }
            }
        }
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("媒体库")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
                .padding(.bottom, 2)

            VStack(spacing: 0) {
                libraryRow(title: "我的投稿", icon: "video", destination: { MobileUploadsView() })
                libraryDivider
                libraryRow(title: "历史记录", icon: "clock.arrow.circlepath", destination: { MobileHistoryView(hidesTabBar: true) })
                libraryDivider
                libraryRow(title: "收藏与播放列表", icon: "list.bullet.rectangle", destination: { MobilePlaylistsView() })
                libraryDivider
                libraryRow(title: "稍后再看", icon: "bookmark", destination: { MobileWatchLaterView() })
                libraryDivider
                libraryRow(title: "下载", icon: "arrow.down.circle", destination: { MobileDownloadView() })
                libraryDivider
                libraryRow(title: "我的关注", icon: "person.2", destination: { MobileFollowingView() })
                libraryDivider
                libraryRow(title: "我的粉丝", icon: "person.2.badge.gearshape", destination: { MobileFollowersView() })
            }
            .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var libraryDivider: some View {
        Divider()
            .opacity(0.5)
            .padding(.leading, 50)
    }

    private func libraryRow<Destination: View>(
        title: String,
        icon: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                    .frame(width: 28, height: 28)
                    .background(AppTheme.background(scheme).opacity(0.62), in: Circle())
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiary(scheme))
            }
            .padding(.horizontal, 12)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var loggedOut: some View {
        VStack(spacing: 14) {
            AppMark(size: 58)
            Text("登录后查看个人主页")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            Text("同步你的投稿、收藏、关注与观看记录")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.secondary(scheme))

            if let error = model.profileError {
                Text(error)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button {
                model.presentLogin()
            } label: {
                Text("扫码登录")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26)
                    .frame(height: 42)
                    .background(AppTheme.brand, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }
}

struct MobileShelfCard: View {
    let video: VideoItem
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            RemoteImage(url: video.coverURL)
                .frame(width: 176, height: 99)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if !video.durationText.isEmpty {
                        Text(video.durationText)
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(height: 16)
                            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .padding(5)
                    }
                }

            Text(video.title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(AppTheme.text(scheme))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 176, alignment: .leading)

            Text(video.ownerName)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.secondary(scheme))
                .lineLimit(1)
                .frame(width: 176, alignment: .leading)
        }
    }
}
