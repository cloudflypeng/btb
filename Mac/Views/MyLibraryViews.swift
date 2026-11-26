import AppKit
import SwiftUI

struct MyUploadsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if !model.hasAccount {
                LoginRequiredView(
                    title: "我的投稿",
                    message: "登录后可以查看自己发布的视频。"
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        LibraryHeader(
                            title: "我的投稿",
                            subtitle: "共 \(model.myUploads.count) 个视频"
                        )

                        if let error = model.myUploadsError {
                            ErrorBanner(text: error) {
                                Task { await model.loadMyUploads(force: true) }
                            }
                        }

                        if model.isLoadingMyUploads && model.myUploads.isEmpty {
                            LibrarySkeletonGrid()
                        } else if model.myUploads.isEmpty {
                            EmptyHint(
                                icon: "video",
                                title: "还没有投稿",
                                message: "你发布的视频会出现在这里。"
                            )
                            .padding(.top, 50)
                        } else {
                            LibraryVideoGrid(videos: model.myUploads)

                            InfiniteScrollFooter(
                                isLoading: model.isLoadingMyUploads || model.uploadsPager.isLoadingMore,
                                hasMore: model.uploadsPager.hasMore,
                                failed: model.uploadsPager.failed
                            ) {
                                Task { await model.loadMoreMyUploads() }
                            }
                        }
                    }
                    .libraryPagePadding()
                }
                .scrollIndicators(.hidden)
                .task { await model.loadMyUploads() }
            }
        }
        .background(AppTheme.background(scheme))
    }
}

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    @State private var isClearPresented = false
    @State private var isPauseBusy = false

    var body: some View {
        Group {
            if !model.hasAccount {
                LoginRequiredView(
                    title: "历史记录",
                    message: "登录后可以查看最近看过的视频。"
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        header

                        if model.historyPaused {
                            pausedBanner
                        }

                        if let error = model.historyError {
                            ErrorBanner(text: error) {
                                Task { await model.loadHistoryVideos(force: true) }
                            }
                        }

                        if model.isLoadingHistory && model.history.isEmpty {
                            LibrarySkeletonGrid()
                        } else if model.history.isEmpty {
                            EmptyHint(
                                icon: "clock.arrow.circlepath",
                                title: "还没有观看记录",
                                message: "看过的视频会出现在这里。"
                            )
                            .padding(.top, 50)
                        } else {
                            VStack(spacing: 2) {
                                ForEach(model.history) { video in
                                    historyRow(video)

                                    Rectangle()
                                        .fill(AppTheme.divider(scheme))
                                        .frame(height: 1)
                                        .padding(.leading, 178)
                                }
                            }

                            InfiniteScrollFooter(
                                isLoading: model.isLoadingHistory || model.historyPager.isLoadingMore,
                                hasMore: model.historyPager.hasMore,
                                failed: model.historyPager.failed
                            ) {
                                Task { await model.loadMoreHistory() }
                            }
                        }
                    }
                    .libraryPagePadding()
                }
                .scrollIndicators(.hidden)
                .task {
                    await model.loadHistoryVideos()
                    await model.loadHistoryStatus()
                }
            }
        }
        .background(AppTheme.background(scheme))
        .confirmationDialog(
            "清空全部历史记录？",
            isPresented: $isClearPresented,
            titleVisibility: .visible
        ) {
            Button("清空历史记录", role: .destructive) {
                Task { await clearHistory() }
            }
        } message: {
            Text("此操作会删除全部观看记录，且无法撤销。")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            LibraryHeader(
                title: "历史记录",
                subtitle: model.historyPaused ? "已暂停记录" : "最近观看"
            )

            Spacer(minLength: 12)

            Button {
                Task { await togglePause() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: model.historyPaused ? "play.circle.fill" : "pause.circle")
                        .font(.system(size: 12, weight: .semibold))
                    Text(model.historyPaused ? "恢复记录" : "暂停记录")
                        .font(.system(size: 12.5, weight: .medium))
                }
                .foregroundStyle(model.historyPaused ? AppTheme.brand : AppTheme.text(scheme))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(AppTheme.surface(scheme), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            model.historyPaused ? AppTheme.brand.opacity(0.4) : AppTheme.divider(scheme),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isPauseBusy)
            .help(model.historyPaused ? "恢复记录观看历史" : "暂停记录观看历史")

            if !model.history.isEmpty {
                Button {
                    isClearPresented = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                        Text("清空历史")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(AppTheme.surface(scheme), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.red.opacity(0.28), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var pausedBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.brand)
            Text("历史记录已暂停，新观看的视频不会记录。")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.text(scheme))
            Spacer(minLength: 8)
            Button("恢复") {
                Task { await togglePause() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(AppTheme.brand)
            .disabled(isPauseBusy)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            AppTheme.brand.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private func historyRow(_ video: VideoItem) -> some View {
        HStack(spacing: 4) {
            Button {
                model.openVideo(video)
            } label: {
                HistoryRow(video: video)
            }
            .buttonStyle(.plain)

            Button {
                Task { await delete(video) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                    .frame(width: 30, height: 30)
                    .background(AppTheme.chip(scheme), in: Circle())
            }
            .buttonStyle(.plain)
            .help("删除这条观看记录")
        }
        .contextMenu {
            Button("删除这条记录", role: .destructive) {
                Task { await delete(video) }
            }
        }
    }

    private func togglePause() async {
        guard !isPauseBusy else { return }
        isPauseBusy = true
        defer { isPauseBusy = false }
        do {
            try await model.setHistoryPaused(!model.historyPaused)
        } catch {
            model.showToast(error.localizedDescription)
        }
    }

    private func delete(_ video: VideoItem) async {
        do {
            try await model.deleteHistoryEntry(video)
        } catch {
            model.showToast(error.localizedDescription)
        }
    }

    private func clearHistory() async {
        do {
            try await model.clearHistory()
        } catch {
            model.showToast(error.localizedDescription)
        }
    }
}

struct WatchLaterView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    @State private var isClearPresented = false

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 420), spacing: 16, alignment: .top)
    ]

    var body: some View {
        Group {
            if !model.hasAccount {
                LoginRequiredView(
                    title: "稍后再看",
                    message: "登录后可以把想看的视频留到以后。"
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        header

                        if let error = model.laterError {
                            ErrorBanner(text: error) {
                                Task { await model.loadWatchLater(force: true) }
                            }
                        }

                        if model.isLoadingLater && model.laterVideos.isEmpty {
                            LibrarySkeletonGrid()
                        } else if model.laterVideos.isEmpty {
                            EmptyHint(
                                icon: "bookmark",
                                title: "稍后再看是空的",
                                message: "在视频详情页点「稍后再看」即可添加。"
                            )
                            .padding(.top, 50)
                        } else {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
                                ForEach(model.laterVideos) { video in
                                    laterCard(video)
                                }
                            }

                            InfiniteScrollFooter(
                                isLoading: model.isLoadingLater || model.laterPager.isLoadingMore,
                                hasMore: model.laterPager.hasMore,
                                failed: model.laterPager.failed
                            ) {
                                Task { await model.loadMoreWatchLater() }
                            }
                        }
                    }
                    .libraryPagePadding()
                }
                .scrollIndicators(.hidden)
                .task { await model.loadWatchLater() }
            }
        }
        .background(AppTheme.background(scheme))
        .confirmationDialog(
            "清空稍后再看？",
            isPresented: $isClearPresented,
            titleVisibility: .visible
        ) {
            Button("清空稍后再看", role: .destructive) {
                Task { await clearLater() }
            }
        } message: {
            Text("会移除稍后再看中的全部视频，此操作无法撤销。")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            LibraryHeader(
                title: "稍后再看",
                subtitle: model.laterTotal > 0 ? "共 \(model.laterTotal) 个视频" : "还没有视频"
            )

            Spacer(minLength: 12)

            if !model.laterVideos.isEmpty {
                Button {
                    isClearPresented = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                        Text("清空")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(AppTheme.surface(scheme), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.red.opacity(0.28), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func laterCard(_ video: VideoItem) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                model.openVideo(video)
            } label: {
                VideoCard(video: video)
            }
            .buttonStyle(.plain)

            Button {
                Task { await remove(video) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(8)
            .help("从稍后再看移除")
        }
        .contextMenu {
            Button("从稍后再看移除", role: .destructive) {
                Task { await remove(video) }
            }
        }
    }

    private func remove(_ video: VideoItem) async {
        do {
            try await model.removeFromWatchLater(video)
        } catch {
            model.showToast(error.localizedDescription)
        }
    }

    private func clearLater() async {
        do {
            try await model.clearWatchLater()
        } catch {
            model.showToast(error.localizedDescription)
        }
    }
}

struct PlaylistsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    @State private var isEditorPresented = false
    @State private var editingFolder: FavFolder?
    @State private var pendingDelete: FavFolder?
    @State private var pendingClean: FavFolder?
    @State private var isMovePresented = false
    @State private var moveSelection: [VideoItem] = []
    @State private var isSelectionMode = false
    @State private var selectedVideoIDs: Set<String> = []

    private let folderColumns = [
        GridItem(.adaptive(minimum: 210, maximum: 280), spacing: 16, alignment: .top)
    ]
    private let videoColumns = [
        GridItem(.adaptive(minimum: 260, maximum: 420), spacing: 16, alignment: .top)
    ]

    var body: some View {
        Group {
            if !model.hasAccount {
                LoginRequiredView(
                    title: "播放列表",
                    message: "登录后可以查看和管理收藏夹。"
                )
            } else {
                ScrollView {
                    if let folder = model.selectedFolder {
                        folderDetail(folder)
                    } else {
                        folderList
                    }
                }
                .scrollIndicators(.hidden)
                .task {
                    await model.loadPlaylists()
#if DEBUG
                    runDebugHooks()
#endif
                }
            }
        }
        .background(AppTheme.background(scheme))
        .sheet(isPresented: $isEditorPresented) {
            FolderEditorSheet(folder: editingFolder)
        }
        .sheet(isPresented: $isMovePresented) {
            MoveFolderSheet(videos: moveSelection) {
                selectedVideoIDs = []
                isSelectionMode = false
            }
        }
        .confirmationDialog(
            "删除「\(pendingDelete?.title ?? "")」？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除收藏夹", role: .destructive) {
                guard let folder = pendingDelete else { return }
                pendingDelete = nil
                Task { await delete(folder) }
            }
        } message: {
            Text("收藏夹内的视频不会被删除，仍会保留在 B 站。")
        }
        .confirmationDialog(
            "清空「\(pendingClean?.title ?? "")」？",
            isPresented: Binding(
                get: { pendingClean != nil },
                set: { if !$0 { pendingClean = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("清空收藏夹", role: .destructive) {
                guard let folder = pendingClean else { return }
                pendingClean = nil
                Task { await clean(folder) }
            }
        } message: {
            Text("会取消收藏夹内的全部视频，此操作无法撤销。")
        }
    }

    private var folderList: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                LibraryHeader(
                    title: "播放列表",
                    subtitle: "\(model.favoriteFolders.count) 个收藏夹"
                )

                Spacer(minLength: 12)

                Button {
                    editingFolder = nil
                    isEditorPresented = true
                } label: {
                    Label("新建收藏夹", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(AppTheme.brand, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if let error = model.playlistsError {
                ErrorBanner(text: error) {
                    Task { await model.loadPlaylists(force: true) }
                }
            }

            if model.isLoadingPlaylists && model.favoriteFolders.isEmpty {
                LibrarySkeletonGrid()
            } else if model.favoriteFolders.isEmpty {
                EmptyHint(
                    icon: "list.bullet.rectangle",
                    title: "还没有收藏夹",
                    message: "点右上角「新建收藏夹」创建第一个收藏夹。"
                )
                .padding(.top, 50)
            } else {
                LazyVGrid(columns: folderColumns, alignment: .leading, spacing: 20) {
                    ForEach(model.favoriteFolders) { folder in
                        Button {
                            selectedVideoIDs = []
                            isSelectionMode = false
                            Task { await model.loadFolderVideos(folder) }
                        } label: {
                            FolderCard(folder: folder)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("编辑收藏夹") {
                                editingFolder = folder
                                isEditorPresented = true
                            }
                            if !folder.isDefault {
                                Button("清空收藏夹") {
                                    pendingClean = folder
                                }
                                Divider()
                                Button("删除收藏夹", role: .destructive) {
                                    pendingDelete = folder
                                }
                            }
                        }
                    }
                }
            }
        }
        .libraryPagePadding()
    }

    private func folderDetail(_ folder: FavFolder) -> some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    exitSelection()
                    model.closeFolder()
                    Task { await model.loadPlaylists(force: true) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .frame(width: 32, height: 32)
                        .background(AppTheme.chip(scheme), in: Circle())
                }
                .buttonStyle(.plain)
                .help("返回播放列表")

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(folder.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(1)
                        if folder.isDefault {
                            FolderBadge(title: "默认", isOverlay: false)
                        }
                        if folder.isPrivate {
                            FolderBadge(title: "私密", icon: "lock.fill", isOverlay: false)
                        }
                    }
                    Text(folderSubtitle(folder))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                if isSelectionMode {
                    FolderActionButton(title: "完成", icon: "checkmark") {
                        exitSelection()
                    }
                } else {
                    FolderActionButton(
                        title: "管理",
                        icon: "checkmark.circle",
                        isEnabled: !model.folderVideos.isEmpty
                    ) {
                        isSelectionMode = true
                    }
                    FolderActionButton(title: "编辑", icon: "pencil") {
                        editingFolder = folder
                        isEditorPresented = true
                    }
                    if !folder.isDefault {
                        FolderActionButton(title: "清空", icon: "trash") {
                            pendingClean = folder
                        }
                    }
                }
            }

            if isSelectionMode {
                selectionToolbar(folder)
            }

            if let error = model.folderError {
                ErrorBanner(text: error) {
                    Task { await model.loadFolderVideos(folder) }
                }
            }

            if model.isLoadingFolderVideos && model.folderVideos.isEmpty {
                LibrarySkeletonGrid()
            } else if model.folderVideos.isEmpty {
                EmptyHint(
                    icon: "list.bullet.rectangle",
                    title: "这个收藏夹是空的",
                    message: "收藏视频后会显示在这里。"
                )
                .padding(.top, 50)
            } else if isSelectionMode {
                LazyVGrid(columns: videoColumns, alignment: .leading, spacing: 28) {
                    ForEach(model.folderVideos) { video in
                        Button {
                            toggleSelection(video)
                        } label: {
                            VideoCard(video: video)
                                .overlay(alignment: .topLeading) {
                                    selectionMark(isSelected: selectedVideoIDs.contains(video.bvid))
                                        .padding(8)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                InfiniteScrollFooter(
                    isLoading: model.isLoadingFolderVideos || model.folderPager.isLoadingMore,
                    hasMore: model.folderPager.hasMore,
                    failed: model.folderPager.failed
                ) {
                    Task { await model.loadMoreFolderVideos() }
                }
            } else {
                LibraryVideoGrid(videos: model.folderVideos)

                InfiniteScrollFooter(
                    isLoading: model.isLoadingFolderVideos || model.folderPager.isLoadingMore,
                    hasMore: model.folderPager.hasMore,
                    failed: model.folderPager.failed
                ) {
                    Task { await model.loadMoreFolderVideos() }
                }
            }
        }
        .libraryPagePadding()
        .task(id: folder.id) {
            await model.loadFolderVideos(folder)
        }
    }

    private func selectionToolbar(_ folder: FavFolder) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleSelectAll()
            } label: {
                Text(selectedVideoIDs.count == model.folderVideos.count ? "取消全选" : "全选")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(AppTheme.surface(scheme), in: Capsule())
            }
            .buttonStyle(.plain)

            Text("已选 \(selectedVideoIDs.count) 项")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(AppTheme.secondary(scheme))
                .monospacedDigit()

            Spacer(minLength: 8)

            FolderActionButton(
                title: "移动…",
                icon: "folder",
                isEnabled: !selectedVideoIDs.isEmpty
            ) {
                moveSelection = model.folderVideos.filter {
                    selectedVideoIDs.contains($0.bvid)
                }
                isMovePresented = true
            }

            FolderActionButton(
                title: "取消收藏",
                icon: "trash",
                isEnabled: !selectedVideoIDs.isEmpty,
                isDestructive: true
            ) {
                Task { await removeSelected(from: folder) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            AppTheme.chip(scheme),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func selectionMark(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? AppTheme.brand : Color.black.opacity(0.5))
                .frame(width: 22, height: 22)
            Image(systemName: isSelected ? "checkmark" : "circle")
                .font(.system(size: isSelected ? 11 : 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func folderSubtitle(_ folder: FavFolder) -> String {
        var parts = ["\(folder.count) 个视频", folder.isPrivate ? "仅自己可见" : "公开"]
        let intro = folder.intro.trimmingCharacters(in: .whitespacesAndNewlines)
        if !intro.isEmpty {
            parts.append(intro)
        }
        return parts.joined(separator: " · ")
    }

    private func toggleSelection(_ video: VideoItem) {
        if selectedVideoIDs.contains(video.bvid) {
            selectedVideoIDs.remove(video.bvid)
        } else {
            selectedVideoIDs.insert(video.bvid)
        }
    }

    private func toggleSelectAll() {
        if selectedVideoIDs.count == model.folderVideos.count {
            selectedVideoIDs = []
        } else {
            selectedVideoIDs = Set(model.folderVideos.map(\.bvid))
        }
    }

    private func exitSelection() {
        isSelectionMode = false
        selectedVideoIDs = []
    }

    private func removeSelected(from folder: FavFolder) async {
        let videos = model.folderVideos.filter { selectedVideoIDs.contains($0.bvid) }
        guard !videos.isEmpty else { return }
        do {
            try await model.removeFavoriteVideos(videos, from: folder)
            exitSelection()
        } catch {
            model.showToast(error.localizedDescription)
        }
    }

    private func delete(_ folder: FavFolder) async {
        do {
            try await model.deleteFavoriteFolder(folder)
        } catch {
            model.showToast(error.localizedDescription)
        }
    }

    private func clean(_ folder: FavFolder) async {
        do {
            try await model.cleanFavoriteFolder(folder)
        } catch {
            model.showToast(error.localizedDescription)
        }
    }

#if DEBUG
    private func runDebugHooks() {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["BTB_OPEN_FOLDER"],
           let folderID = Int64(raw),
           let folder = model.favoriteFolders.first(where: { $0.id == folderID }) {
            Task {
                await model.loadFolderVideos(folder)
                if env["BTB_FOLDER_SELECT"] == "1" {
                    isSelectionMode = true
                    selectedVideoIDs = Set(model.folderVideos.prefix(2).map(\.bvid))
                }
            }
        }
        if let raw = env["BTB_FOLDER_EDITOR"] {
            if raw == "new" {
                editingFolder = nil
                isEditorPresented = true
            } else if let folderID = Int64(raw),
                      let folder = model.favoriteFolders.first(where: { $0.id == folderID }) {
                editingFolder = folder
                isEditorPresented = true
            }
        }
    }
#endif
}

private struct LibraryHeader: View {
    let title: String
    let subtitle: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondary(scheme))
        }
    }
}

private struct LoginRequiredView: View {
    let title: String
    let message: String

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(AppTheme.secondary(scheme))
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondary(scheme))
            Button {
                model.presentLogin()
            } label: {
                Text("登录")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 34)
                    .background(AppTheme.brand, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background(scheme))
    }
}

private struct LibraryVideoGrid: View {
    let videos: [VideoItem]

    @Environment(AppModel.self) private var model

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 420), spacing: 16, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
            ForEach(videos) { video in
                Button {
                    model.openVideo(video)
                } label: {
                    VideoCard(video: video)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct LibrarySkeletonGrid: View {
    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 420), spacing: 16, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
            ForEach(0..<8, id: \.self) { _ in
                VideoCardSkeleton()
            }
        }
        .allowsHitTesting(false)
    }
}

private struct FolderCard: View {
    let folder: FavFolder

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let url = folder.coverURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 5) {
                    if folder.isDefault {
                        FolderBadge(title: "默认")
                    }
                    if folder.isPrivate {
                        FolderBadge(title: "私密", icon: "lock.fill")
                    }
                }
                .padding(7)
            }
            .overlay(alignment: .bottomTrailing) {
                Text("\(folder.count) 个视频")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 5))
                    .padding(7)
            }

            Text(folder.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            let intro = folder.intro.trimmingCharacters(in: .whitespacesAndNewlines)
            if !intro.isEmpty {
                Text(intro)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(8)
        .background(
            isHovering ? AppTheme.hover(scheme) : Color.clear,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    private var placeholder: some View {
        ZStack {
            AppTheme.surface(scheme)
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(AppTheme.tertiary(scheme))
        }
    }
}

private struct FolderBadge: View {
    let title: String
    var icon: String?
    var isOverlay: Bool = true

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
            }
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
        }
        .foregroundStyle(isOverlay ? Color.white : AppTheme.brand)
        .padding(.horizontal, 6)
        .frame(height: 18)
        .background(
            isOverlay ? Color.black.opacity(0.55) : AppTheme.brand.opacity(0.12),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(
                    isOverlay ? Color.white.opacity(0.25) : AppTheme.brand.opacity(0.3),
                    lineWidth: 1
                )
        )
    }
}

private struct FolderActionButton: View {
    let title: String
    let icon: String
    var isEnabled: Bool = true
    var isDestructive: Bool = false
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(
                isDestructive
                    ? Color.red.opacity(isEnabled ? 1 : 0.4)
                    : AppTheme.text(scheme).opacity(isEnabled ? 1 : 0.4)
            )
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                isHovering && isEnabled
                    ? AppTheme.surfaceHover(scheme)
                    : AppTheme.surface(scheme),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(AppTheme.divider(scheme), lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { isHovering = $0 }
    }
}

private struct FolderEditorSheet: View {
    let folder: FavFolder?

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var title = ""
    @State private var intro = ""
    @State private var isPrivate = false
    @State private var cover = ""
    @State private var isSaving = false
    @State private var error: String?

    private var isEditing: Bool { folder != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: isEditing ? "pencil" : "folder.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.brand)
                Text(isEditing ? "编辑收藏夹" : "新建收藏夹")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
            }

            field("名称") {
                TextField("收藏夹名称", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.text(scheme))
            }

            field("简介") {
                TextField("一句话介绍（可选）", text: $intro)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.text(scheme))
            }

            field("封面") {
                TextField("封面图片链接（可选）", text: $cover)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.text(scheme))
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("私密收藏夹")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                    Text("开启后仅自己可见")
                        .font(.system(size: 11.5))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
                Spacer()
                Toggle("", isOn: $isPrivate)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(
                AppTheme.chip(scheme),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )

            if let error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.secondary(scheme))
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(AppTheme.chip(scheme), in: Capsule())
                .disabled(isSaving)

                Button {
                    Task { await save() }
                } label: {
                    Text(isSaving ? "保存中…" : "保存")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 34)
                        .background(
                            AppTheme.brand.opacity(canSave ? 1 : 0.45),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
        }
        .padding(22)
        .frame(width: 420)
        .background(AppTheme.background(scheme))
        .onAppear {
            guard let folder else { return }
            title = folder.title
            intro = folder.intro
            isPrivate = folder.isPrivate
            cover = folder.cover
        }
    }

    private var canSave: Bool {
        !isSaving && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func field<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.secondary(scheme))
            content()
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(
                    AppTheme.chip(scheme),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
        }
    }

    private func save() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !isSaving else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            let trimmedIntro = intro.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedCover = cover.trimmingCharacters(in: .whitespacesAndNewlines)
            if let folder {
                try await model.updateFavoriteFolder(
                    folder,
                    title: trimmedTitle,
                    intro: trimmedIntro,
                    privacy: isPrivate ? 1 : 0,
                    cover: trimmedCover
                )
            } else {
                _ = try await model.createFavoriteFolder(
                    title: trimmedTitle,
                    intro: trimmedIntro,
                    privacy: isPrivate ? 1 : 0,
                    cover: trimmedCover
                )
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct MoveFolderSheet: View {
    let videos: [VideoItem]
    let onMoved: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var movingFolderID: Int64?
    @State private var error: String?

    private var candidates: [FavFolder] {
        model.favoriteFolders.filter { $0.id != model.selectedFolder?.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.brand)
                Text("移动到收藏夹")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                Spacer()
                if movingFolderID != nil {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text("将 \(videos.count) 个视频移动到：")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.secondary(scheme))

            if let error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if candidates.isEmpty {
                EmptyHint(
                    icon: "folder.badge.plus",
                    title: "没有其他收藏夹",
                    message: "先新建一个收藏夹，再回来移动视频。"
                )
                .padding(.vertical, 30)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(candidates) { folder in
                            Button {
                                Task { await move(to: folder) }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: folder.isPrivate ? "lock.fill" : "folder")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppTheme.brand)
                                        .frame(width: 28, height: 28)
                                        .background(AppTheme.chip(scheme), in: Circle())
                                    Text(folder.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.text(scheme))
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    Text("\(folder.count) 个视频")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(AppTheme.tertiary(scheme))
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 46)
                                .background(
                                    AppTheme.surface(scheme),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(movingFolderID != nil)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.secondary(scheme))
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(AppTheme.chip(scheme), in: Capsule())
                .disabled(movingFolderID != nil)
            }
        }
        .padding(22)
        .frame(width: 400, height: 430)
        .background(AppTheme.background(scheme))
    }

    private func move(to target: FavFolder) async {
        guard let source = model.selectedFolder, movingFolderID == nil else { return }
        movingFolderID = target.id
        error = nil
        defer { movingFolderID = nil }
        do {
            try await model.moveFavoriteVideos(videos, from: source, to: target)
            onMoved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private extension View {
    func libraryPagePadding() -> some View {
        padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 48)
            .frame(maxWidth: 1600, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
