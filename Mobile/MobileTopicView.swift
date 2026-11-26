import SwiftUI

struct MobileTopicSquareView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var selected: TopicSquareItem?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            content
        }
        .background(AppTheme.background(scheme))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(item: $selected) { topic in
            MobileTopicView(topic: topic)
        }
        .task {
            await model.loadTopicSquare()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("话题")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            Spacer()
            Button {
                Task { await model.loadTopicSquare(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .frame(width: 32, height: 32)
                    .background(AppTheme.chip(scheme), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(model.isLoadingTopicSquare)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let error = model.topicSquareError, model.topicSquare.isEmpty {
                    MobileErrorBanner(text: error) {
                        Task { await model.loadTopicSquare(force: true) }
                    }
                }

                if model.isLoadingTopicSquare && model.topicSquare.isEmpty {
                    ProgressView()
                        .tint(AppTheme.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if model.topicSquare.isEmpty {
                    if model.topicSquareLoaded, model.topicSquareError == nil {
                        MobileEmptyState(
                            icon: "number",
                            title: "暂无话题",
                            message: "稍后刷新试试"
                        )
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Array(model.topicSquare.enumerated()), id: \.element.id) { index, topic in
                            Button {
                                selected = topic
                            } label: {
                                MobileTopicSquareCard(topic: topic, paletteIndex: index)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await model.loadTopicSquare(force: true)
        }
    }
}

private struct MobileTopicSquareCard: View {
    let topic: TopicSquareItem
    let paletteIndex: Int

    @Environment(\.colorScheme) private var scheme

    private static let palettes: [[Color]] = [
        [Color(hex: 0xFF5A7A), Color(hex: 0xB3154F)],
        [Color(hex: 0x5B8CFF), Color(hex: 0x2F35A8)],
        [Color(hex: 0xFFA24D), Color(hex: 0xD94A22)],
        [Color(hex: 0x43C6AC), Color(hex: 0x157C7C)],
        [Color(hex: 0x9D6BFF), Color(hex: 0x5924A8)],
        [Color(hex: 0x3EA6FF), Color(hex: 0x0A5AA8)],
    ]

    private var accent: Color {
        Self.palettes[abs(paletteIndex) % Self.palettes.count][0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: "number")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiary(scheme))
            }

            Text(topic.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if let description = topic.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            Text(topic.summaryText)
                .font(.system(size: 10.5))
                .foregroundStyle(AppTheme.tertiary(scheme))
                .lineLimit(1)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct MobileTopicView: View {
    let topic: TopicSquareItem

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var selectedCard: DynamicCard?
    @State private var selectedUP: MobileUPRoute?
    @State private var selectedAnime: MobileAnimeRoute?
    @State private var selectedLive: LiveRoom?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                feed
            }
            .padding(14)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
        .navigationTitle("话题")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .refreshable {
            await model.refreshTopic()
        }
        .navigationDestination(item: $selectedCard) { card in
            MobileDynamicDetailView(card: card)
        }
        .navigationDestination(item: $selectedUP) { route in
            MobileUPView(route: route)
        }
        .navigationDestination(item: $selectedAnime) { route in
            MobileAnimeSeasonView(seasonID: route.seasonID)
        }
        .navigationDestination(item: $selectedLive) { room in
            MobileLiveRoomView(room: room)
        }
        .task {
            if model.activeTopic?.id != topic.id {
                model.openTopic(topic)
            }
        }
        .onDisappear {
            if selectedCard == nil, selectedUP == nil, selectedAnime == nil, selectedLive == nil,
               model.activeTopic?.id == topic.id {
                model.closeTopic()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.topicDetail?.name ?? topic.name)
                        .font(.system(size: 22, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)

                    if let description = headerDescription {
                        Text(description)
                            .font(.system(size: 12.5))
                            .opacity(0.86)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                Button {
                    Task { await model.refreshTopic() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(model.isLoadingTopicFeed || model.isLoadingTopicDetail)
            }

            HStack(spacing: 14) {
                if let discuss = model.topicDetail?.discuss ?? topic.discuss, discuss > 0 {
                    headerStat("讨论", discuss)
                }
                if let view = model.topicDetail?.view ?? topic.view, view > 0 {
                    headerStat("浏览", view)
                }
                if let dynamics = model.topicDetail?.dynamics, dynamics > 0 {
                    headerStat("动态", dynamics)
                }

                Spacer()

                if model.isLoadingTopicDetail {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .background(
            headerColor,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var headerDescription: String? {
        let text = model.topicDetail?.description ?? topic.description
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }

    private var headerColor: Color {
        guard let raw = model.topicDetail?.backColor else { return AppTheme.brand }
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let hex = UInt32(value, radix: 16) else { return AppTheme.brand }
        return Color(hex: hex)
    }

    private func headerStat(_ title: String, _ value: Int) -> some View {
        HStack(spacing: 4) {
            Text(MobileFormat.count(value))
                .font(.system(size: 12.5, weight: .semibold))
            Text(title)
                .font(.system(size: 10.5))
                .opacity(0.68)
        }
    }

    @ViewBuilder
    private var feed: some View {
        HStack(spacing: 8) {
            Text("最新动态")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            if let count = model.topicDetail?.dynamics, count > 0 {
                Text(MobileFormat.count(count))
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }
            Spacer()
        }

        if let error = model.topicFeedError {
            MobileErrorBanner(text: error) {
                Task { await model.loadTopicFeed(reset: true) }
            }
        }

        if !model.topicFeedLoaded && model.topicFeedCards.isEmpty {
            ProgressView()
                .tint(AppTheme.brand)
                .frame(maxWidth: .infinity)
                .padding(.top, 50)
        } else if model.topicFeedCards.isEmpty {
            if model.topicFeedError == nil {
                MobileEmptyState(
                    icon: "text.bubble",
                    title: "暂无动态",
                    message: "这个话题下还没有内容"
                )
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(model.topicFeedCards) { card in
                    MobileDynamicCardView(card: card) {
                        selectedCard = card
                    } onOpenUP: { author in
                        guard let mid = author.mid else { return }
                        selectedUP = MobileUPRoute(mid: mid, name: author.name, avatarURL: author.avatarURL)
                    } onOpenPGC: { seasonID in
                        selectedAnime = MobileAnimeRoute(seasonID: seasonID)
                    } onOpenLive: { live in
                        selectedLive = LiveRoom(
                            roomID: live.roomID,
                            coverURL: live.coverURL,
                            title: live.title,
                            areaName: live.areaName
                        )
                    }
                }

                InfiniteScrollFooter(
                    isLoading: model.isLoadingTopicFeed,
                    hasMore: model.topicFeedHasMore,
                    failed: model.topicFeedError != nil,
                    endText: "没有更多动态了"
                ) {
                    Task { await model.loadMoreTopicFeed() }
                }
            }
        }
    }
}
