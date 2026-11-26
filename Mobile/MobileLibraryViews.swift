import SwiftUI

struct MobileLoginPrompt: View {
    let title: String
    let message: String
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(AppTheme.brand)
            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            Text(message)
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.secondary(scheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button {
                model.presentLogin()
            } label: {
                Text("扫码登录")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 42)
                    .background(AppTheme.brand, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background(scheme))
    }
}

struct MobileUploadsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if !model.hasAccount {
                MobileLoginPrompt(title: "登录后查看投稿", message: "登录后可以管理你发布的视频。")
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if let error = model.myUploadsError {
                            MobileErrorBanner(text: error) {
                                Task { await model.loadMyUploads(force: true) }
                            }
                        }

                        if model.isLoadingMyUploads && model.myUploads.isEmpty {
                            ProgressView().padding(.top, 50)
                        } else if model.myUploads.isEmpty {
                            emptyState
                        } else {
                            ForEach(model.myUploads) { video in
                                MobileVideoLink(video: video) {
                                    MobileVideoRow(video: video)
                                }
                            }

                            InfiniteScrollFooter(
                                isLoading: model.isLoadingMyUploads || model.uploadsPager.isLoadingMore,
                                hasMore: model.uploadsPager.hasMore,
                                failed: model.uploadsPager.failed
                            ) {
                                Task { await model.loadMoreMyUploads() }
                            }
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await model.loadMyUploads(force: true)
                }
            }
        }
        .background(AppTheme.background(scheme))
        .navigationTitle("我的投稿")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if model.hasAccount {
                await model.loadMyUploads()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "video")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(AppTheme.tertiary(scheme))
            Text("还没有投稿")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct MobileHistoryView: View {
    var hidesTabBar = false
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var isClearPresented = false

    var body: some View {
        Group {
            if !model.hasAccount {
                MobileLoginPrompt(title: "登录后查看历史", message: "登录后可以同步你的观看记录。")
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if let error = model.historyError {
                            MobileErrorBanner(text: error) {
                                Task { await model.loadHistoryVideos(force: true) }
                            }
                        }

                        if model.isLoadingHistory && model.history.isEmpty {
                            ProgressView().padding(.top, 50)
                        } else if model.history.isEmpty {
                            emptyState
                        } else {
                            if model.historyPaused {
                                HStack(spacing: 6) {
                                    Image(systemName: "pause.circle")
                                    Text("历史记录已暂停")
                                    Spacer()
                                }
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.secondary(scheme))
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }

                            ForEach(model.history) { video in
                                MobileVideoLink(video: video) {
                                    MobileVideoRow(video: video)
                                }
                                .contextMenu {
                                    Button("删除这条记录", role: .destructive) {
                                        Task {
                                            do {
                                                try await model.deleteHistoryEntry(video)
                                            } catch {
                                                model.showToast("删除失败：\(error.localizedDescription)")
                                            }
                                        }
                                    }
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
                    .padding(16)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await model.loadHistoryVideos(force: true)
                    await model.loadHistoryStatus(force: true)
                }
            }
        }
        .background(AppTheme.background(scheme))
        .navigationTitle("历史记录")
        .navigationBarTitleDisplayMode(hidesTabBar ? .inline : .large)
        .toolbar(hidesTabBar ? .hidden : .automatic, for: .tabBar)
        .toolbar {
            if model.hasAccount && !model.history.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task {
                                do {
                                    try await model.setHistoryPaused(!model.historyPaused)
                                } catch {
                                    model.showToast("设置失败：\(error.localizedDescription)")
                                }
                            }
                        } label: {
                            Label(model.historyPaused ? "恢复记录历史" : "暂停记录历史",
                                  systemImage: model.historyPaused ? "play.circle" : "pause.circle")
                        }
                        Button("清空历史记录", role: .destructive) {
                            isClearPresented = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.text(scheme))
                    }
                }
            }
        }
        .confirmationDialog("清空全部历史记录？", isPresented: $isClearPresented, titleVisibility: .visible) {
            Button("清空历史", role: .destructive) {
                Task {
                    do {
                        try await model.clearHistory()
                    } catch {
                        model.showToast("清空失败：\(error.localizedDescription)")
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作会删除账号下的全部观看记录，无法撤销。")
        }
        .task {
            if model.hasAccount {
                await model.loadHistoryVideos()
                await model.loadHistoryStatus()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(AppTheme.tertiary(scheme))
            Text("还没有观看记录")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct MobileWatchLaterView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var isClearPresented = false

    var body: some View {
        Group {
            if !model.hasAccount {
                MobileLoginPrompt(title: "登录后使用稍后再看", message: "在视频上点“稍后看”即可保存到这里。")
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if let error = model.laterError {
                            MobileErrorBanner(text: error) {
                                Task { await model.loadWatchLater(force: true) }
                            }
                        }

                        if model.isLoadingLater && model.laterVideos.isEmpty {
                            ProgressView().padding(.top, 50)
                        } else if model.laterVideos.isEmpty {
                            emptyState
                        } else {
                            ForEach(model.laterVideos) { video in
                                MobileVideoLink(video: video) {
                                    MobileVideoRow(video: video)
                                }
                                .contextMenu {
                                    Button("移出稍后再看", role: .destructive) {
                                        Task {
                                            do {
                                                try await model.removeFromWatchLater(video)
                                            } catch {
                                                model.showToast("移除失败：\(error.localizedDescription)")
                                            }
                                        }
                                    }
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
                    .padding(16)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await model.loadWatchLater(force: true)
                }
            }
        }
        .background(AppTheme.background(scheme))
        .navigationTitle("稍后再看")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if model.hasAccount && !model.laterVideos.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isClearPresented = true
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.text(scheme))
                    }
                }
            }
        }
        .confirmationDialog("清空稍后再看？", isPresented: $isClearPresented, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                Task {
                    do {
                        try await model.clearWatchLater()
                    } catch {
                        model.showToast("清空失败：\(error.localizedDescription)")
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("稍后再看中的全部视频会被移除，不会影响收藏夹。")
        }
        .task {
            if model.hasAccount {
                await model.loadWatchLater()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bookmark")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(AppTheme.tertiary(scheme))
            Text("这里还是空的")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct MobilePlaylistsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var editorTarget: MobileFolderEditorTarget?
    @State private var folderToDelete: FavFolder?

    var body: some View {
        Group {
            if !model.hasAccount {
                MobileLoginPrompt(title: "登录后查看收藏", message: "登录后可以浏览你的收藏夹与播放列表。")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let error = model.playlistsError {
                            MobileErrorBanner(text: error) {
                                Task { await model.loadPlaylists(force: true) }
                            }
                        }

                        if model.isLoadingPlaylists && model.favoriteFolders.isEmpty {
                            ProgressView().padding(.top, 50)
                        } else {
                            ForEach(model.favoriteFolders) { folder in
                                NavigationLink {
                                    MobileFolderView(folder: folder)
                                } label: {
                                    folderRow(folder)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("编辑收藏夹") {
                                        editorTarget = MobileFolderEditorTarget(folder: folder)
                                    }
                                    if !folder.isDefault {
                                        Button("删除收藏夹", role: .destructive) {
                                            folderToDelete = folder
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await model.loadPlaylists(force: true)
                }
            }
        }
        .background(AppTheme.background(scheme))
        .navigationTitle("收藏与播放列表")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if model.hasAccount {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorTarget = MobileFolderEditorTarget(folder: nil)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                    }
                }
            }
        }
        .sheet(item: $editorTarget) { target in
            MobileFolderEditorSheet(folder: target.folder)
                .environment(model)
        }
        .confirmationDialog("删除这个收藏夹？", isPresented: Binding(
            get: { folderToDelete != nil },
            set: { if !$0 { folderToDelete = nil } }
        ), titleVisibility: .visible) {
            if let folder = folderToDelete {
                Button("删除", role: .destructive) {
                    Task {
                        do {
                            try await model.deleteFavoriteFolder(folder)
                        } catch {
                            model.showToast("删除失败：\(error.localizedDescription)")
                        }
                    }
                    folderToDelete = nil
                }
            }
            Button("取消", role: .cancel) { folderToDelete = nil }
        } message: {
            if let folder = folderToDelete {
                Text("「\(folder.title)」及其中的收藏会被删除，此操作无法撤销。")
            }
        }
        .task {
            if model.hasAccount {
                await model.loadPlaylists()
            }
        }
    }

    private func folderRow(_ folder: FavFolder) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: folder.coverURL)
                .frame(width: 116, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(folder.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text("\(folder.count) 个视频")
                    if folder.isPrivate {
                        Label("私密", systemImage: "lock.fill")
                            .font(.system(size: 10.5))
                    }
                }
                .font(.system(size: 11.5))
                .foregroundStyle(AppTheme.secondary(scheme))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.tertiary(scheme))
        }
        .contentShape(Rectangle())
    }
}

struct MobileFolderEditorTarget: Identifiable {
    let id = UUID()
    let folder: FavFolder?
}

struct MobileFolderEditorSheet: View {
    let folder: FavFolder?

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var intro: String
    @State private var isPrivate: Bool
    @State private var isSaving = false
    @State private var errorText: String?

    init(folder: FavFolder?) {
        self.folder = folder
        _title = State(initialValue: folder?.title ?? "")
        _intro = State(initialValue: folder?.intro ?? "")
        _isPrivate = State(initialValue: folder?.isPrivate ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    TextField("收藏夹名称", text: $title)
                        .textInputAutocapitalization(.never)
                }
                Section("简介") {
                    TextField("一句话介绍（可选）", text: $intro, axis: .vertical)
                        .lineLimit(1...3)
                }
                Section {
                    Toggle("私密收藏夹", isOn: $isPrivate)
                        .tint(AppTheme.brand)
                } footer: {
                    Text("私密收藏夹仅自己可见。")
                }
                if let errorText {
                    Section {
                        Text(errorText)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(folder == nil ? "新建收藏夹" : "编辑收藏夹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("保存").font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() async {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSaving else { return }
        isSaving = true
        errorText = nil
        defer { isSaving = false }
        do {
            if let folder {
                try await model.updateFavoriteFolder(
                    folder,
                    title: name,
                    intro: intro.trimmingCharacters(in: .whitespaces),
                    privacy: isPrivate ? 1 : 0,
                    cover: folder.cover
                )
            } else {
                _ = try await model.createFavoriteFolder(
                    title: name,
                    intro: intro.trimmingCharacters(in: .whitespaces),
                    privacy: isPrivate ? 1 : 0,
                    cover: ""
                )
            }
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct MobileFolderView: View {
    let folder: FavFolder
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var isSelecting = false
    @State private var selected = Set<String>()
    @State private var editorTarget: MobileFolderEditorTarget?
    @State private var isMovePresented = false
    @State private var isClearPresented = false
    @State private var isDeletePresented = false

    private var currentFolder: FavFolder {
        if let selected = model.selectedFolder, selected.id == folder.id { return selected }
        return folder
    }

    private var selectedVideos: [VideoItem] {
        model.folderVideos.filter { selected.contains($0.bvid) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let error = model.folderError {
                    MobileErrorBanner(text: error) {
                        Task { await model.loadFolderVideos(folder) }
                    }
                }

                if model.isLoadingFolderVideos && model.folderVideos.isEmpty {
                    ProgressView().padding(.top, 50)
                } else if model.folderVideos.isEmpty {
                    Text("这个收藏夹还没有视频")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .padding(.top, 60)
                } else {
                    ForEach(model.folderVideos) { video in
                        if isSelecting {
                            Button {
                                toggle(video)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selected.contains(video.bvid) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundStyle(selected.contains(video.bvid) ? AppTheme.brand : AppTheme.tertiary(scheme))
                                    MobileVideoRow(video: video)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            MobileVideoLink(video: video) {
                                MobileVideoRow(video: video)
                            }
                            .contextMenu {
                                Button("取消收藏", role: .destructive) {
                                    Task {
                                        do {
                                            try await model.removeFavoriteVideos([video], from: currentFolder)
                                        } catch {
                                            model.showToast("取消收藏失败：\(error.localizedDescription)")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    InfiniteScrollFooter(
                        isLoading: model.isLoadingFolderVideos || model.folderPager.isLoadingMore,
                        hasMore: model.folderPager.hasMore,
                        failed: model.folderPager.failed
                    ) {
                        Task { await model.loadMoreFolderVideos() }
                    }
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
        .navigationTitle(currentFolder.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !model.folderVideos.isEmpty {
                    Button(isSelecting ? "完成" : "选择") {
                        withAnimation(.snappy(duration: 0.2)) {
                            isSelecting.toggle()
                            selected.removeAll()
                        }
                    }
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                }
                if !isSelecting {
                    Menu {
                        Button("编辑收藏夹") {
                            editorTarget = MobileFolderEditorTarget(folder: currentFolder)
                        }
                        Button("清空收藏夹", role: .destructive) {
                            isClearPresented = true
                        }
                        if !currentFolder.isDefault {
                            Button("删除收藏夹", role: .destructive) {
                                isDeletePresented = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.text(scheme))
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                selectionBar
            }
        }
        .sheet(item: $editorTarget) { target in
            MobileFolderEditorSheet(folder: target.folder)
                .environment(model)
        }
        .sheet(isPresented: $isMovePresented) {
            MobileFolderPickerSheet(
                folders: model.favoriteFolders.filter { $0.id != currentFolder.id }
            ) { target in
                Task { await moveSelected(to: target) }
            }
            .environment(model)
        }
        .confirmationDialog("清空这个收藏夹？", isPresented: $isClearPresented, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                Task {
                    do {
                        try await model.cleanFavoriteFolder(currentFolder)
                    } catch {
                        model.showToast("清空失败：\(error.localizedDescription)")
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("「\(currentFolder.title)」中的视频会被全部移除。")
        }
        .confirmationDialog("删除这个收藏夹？", isPresented: $isDeletePresented, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                Task {
                    do {
                        try await model.deleteFavoriteFolder(currentFolder)
                        dismiss()
                    } catch {
                        model.showToast("删除失败：\(error.localizedDescription)")
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("收藏夹及其中的收藏会被删除，此操作无法撤销。")
        }
        .task(id: folder.id) {
            await model.loadFolderVideos(folder)
        }
        .refreshable {
            await model.loadFolderVideos(folder)
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 10) {
            Text("已选 \(selected.count) 个")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.secondary(scheme))
            Spacer(minLength: 8)
            Button {
                isMovePresented = true
            } label: {
                Text("移动")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(AppTheme.brand, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty)

            Button {
                Task { await removeSelected() }
            } label: {
                Text("取消收藏")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(AppTheme.chip(scheme), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.surface(scheme))
    }

    private func toggle(_ video: VideoItem) {
        if selected.contains(video.bvid) {
            selected.remove(video.bvid)
        } else {
            selected.insert(video.bvid)
        }
    }

    private func removeSelected() async {
        let videos = selectedVideos
        guard !videos.isEmpty else { return }
        do {
            try await model.removeFavoriteVideos(videos, from: currentFolder)
            selected.removeAll()
            isSelecting = false
        } catch {
            model.showToast("取消收藏失败：\(error.localizedDescription)")
        }
    }

    private func moveSelected(to target: FavFolder) async {
        let videos = selectedVideos
        guard !videos.isEmpty else { return }
        do {
            try await model.moveFavoriteVideos(videos, from: currentFolder, to: target)
            selected.removeAll()
            isSelecting = false
            isMovePresented = false
        } catch {
            model.showToast("移动失败：\(error.localizedDescription)")
        }
    }
}

struct MobileFolderPickerSheet: View {
    let folders: [FavFolder]
    let onPick: (FavFolder) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            List {
                if folders.isEmpty {
                    Text("没有其他收藏夹")
                        .foregroundStyle(AppTheme.secondary(scheme))
                } else {
                    ForEach(folders) { folder in
                        Button {
                            onPick(folder)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                RemoteImage(url: folder.coverURL)
                                    .frame(width: 56, height: 34)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(AppTheme.text(scheme))
                                        .lineLimit(1)
                                    Text("\(folder.count) 个视频")
                                        .font(.system(size: 11))
                                        .foregroundStyle(AppTheme.secondary(scheme))
                                }
                                Spacer()
                                if folder.isPrivate {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(AppTheme.tertiary(scheme))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("移动到收藏夹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}


struct MobileFollowingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if !model.hasAccount {
                MobileLoginPrompt(title: "登录后查看关注", message: "登录后可以看到你关注的 UP 主。")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        if let error = model.followTagsError {
                            MobileErrorBanner(text: error) {
                                Task { await model.loadFollowTags(force: true) }
                            }
                        }

                        if !model.followTags.isEmpty {
                            tagBar
                        }

                        if let error = model.followingError {
                            MobileErrorBanner(text: error) {
                                Task { await model.loadFollowing(force: true) }
                            }
                        }

                        if model.isLoadingFollowing && model.followingUPs.isEmpty {
                            ProgressView()
                                .tint(AppTheme.brand)
                                .padding(.top, 50)
                        } else if model.followingUPs.isEmpty {
                            MobileEmptyState(
                                icon: "person.2",
                                title: emptyTitle,
                                message: emptyMessage
                            )
                        } else {
                            ForEach(model.followingUPs) { up in
                                NavigationLink {
                                    MobileUPView(route: MobileUPRoute(mid: up.mid, name: up.name, avatarURL: up.avatarURL))
                                } label: {
                                    MobileFollowingRow(up: up)
                                }
                                .buttonStyle(.plain)
                            }

                            InfiniteScrollFooter(
                                isLoading: model.isLoadingFollowing || model.followingPager.isLoadingMore,
                                hasMore: model.followingPager.hasMore,
                                failed: model.followingPager.failed
                            ) {
                                Task { await model.loadMoreFollowing() }
                            }
                        }
                    }
                    .padding(12)
                }
                .scrollIndicators(.hidden)
                .searchable(
                    text: searchBinding,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "搜索我关注的 UP 主"
                )
                .onSubmit(of: .search) {
                    Task { await model.searchFollowing() }
                }
                .refreshable {
                    await model.loadFollowTags(force: true)
                    await model.loadFollowing(force: true)
                }
            }
        }
        .background(AppTheme.background(scheme))
        .navigationTitle("我的关注")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await model.loadFollowTags()
            await model.loadFollowing()
        }
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { model.followSearchInput },
            set: { value in
                model.followSearchInput = value
                if value.isEmpty, !model.followSearchKeyword.isEmpty {
                    Task { await model.clearFollowingSearch() }
                }
            }
        )
    }

    private var tagBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MobilePill(
                    title: "全部",
                    isSelected: model.followSearchKeyword.isEmpty && model.selectedFollowTagID == nil
                ) {
                    Task { await model.selectFollowTag(nil) }
                }

                ForEach(model.followTags) { tag in
                    MobilePill(
                        title: tag.isSpecial ? "特别关注" : tag.name,
                        isSelected: model.followSearchKeyword.isEmpty && model.selectedFollowTagID == tag.tagid
                    ) {
                        Task { await model.selectFollowTag(tag.tagid) }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .padding(.bottom, 2)
    }

    private var emptyTitle: String {
        if !model.followSearchKeyword.isEmpty {
            return "没有找到相关 UP 主"
        }
        if model.selectedFollowTagID != nil {
            return "该分组暂无关注"
        }
        return "还没有关注任何人"
    }

    private var emptyMessage: String {
        if !model.followSearchKeyword.isEmpty {
            return "换个关键词试试"
        }
        return "去发现页看看感兴趣的内容"
    }
}

struct MobileFollowingRow: View {
    let up: FollowingUP
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: up.avatarURL, size: 46)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(up.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(1)

                    if up.isSpecial {
                        Text("特别关注")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(AppTheme.brand)
                            .padding(.horizontal, 6)
                            .frame(height: 16)
                            .background(AppTheme.brand.opacity(0.12), in: Capsule())
                    }

                    if up.isMutual {
                        Text("互关")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .padding(.horizontal, 6)
                            .frame(height: 16)
                            .background(AppTheme.chip(scheme), in: Capsule())
                    }

                    if !up.officialDesc.isEmpty {
                        Text(up.officialDesc)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .frame(height: 16)
                            .background(AppTheme.chip(scheme), in: Capsule())
                    }
                }

                Text(verbatim: up.sign.isEmpty ? "UP 主 · UID \(up.mid)" : up.sign)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.tertiary(scheme))
        }
        .padding(.horizontal, 12)
        .frame(height: 68)
        .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
    }
}

struct MobileUPView: View {
    let route: MobileUPRoute

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var isBlockConfirmPresented = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error = model.upError {
                    MobileErrorBanner(text: error) {
                        Task { await model.loadUP(mid: route.mid) }
                    }
                }

                header

                Divider()

                if model.isLoadingUP && model.upVideos.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                } else if model.upVideos.isEmpty {
                    Text("还没有投稿")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                        ForEach(model.upVideos) { video in
                            MobileVideoLink(video: video) {
                                MobileGridCard(video: video)
                            }
                        }
                    }

                    InfiniteScrollFooter(
                        isLoading: model.isLoadingUP || model.upPager.isLoadingMore,
                        hasMore: model.upPager.hasMore,
                        failed: model.upPager.failed
                    ) {
                        Task { await model.loadMoreUP() }
                    }
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: route.mid) {
            model.openUP(mid: route.mid, name: route.name, avatarURL: route.avatarURL)
            await model.loadUP(mid: route.mid)
        }
        .refreshable {
            await model.loadUP(mid: route.mid)
        }
        .confirmationDialog(
            "拉黑「\(up?.name ?? route.name)」？",
            isPresented: $isBlockConfirmPresented,
            titleVisibility: .visible
        ) {
            Button("拉黑", role: .destructive) {
                Task { await model.setUPBlocked(true) }
            }
        } message: {
            Text("拉黑后你们将无法互相关注、评论或发送消息。")
        }
    }

    private var up: UPProfile? {
        if model.activeUP?.mid == route.mid { return model.activeUP }
        return nil
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 14) {
                AvatarView(url: up?.avatarURL ?? route.avatarURL, size: 66)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(up?.name ?? route.name)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(1)

                        if up?.isBlocked == true {
                            Text("已拉黑")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 7)
                                .frame(height: 18)
                                .background(Color.red.opacity(0.12), in: Capsule())
                        }
                    }

                    HStack(spacing: 10) {
                        if let follower = up?.follower, follower > 0 {
                            Text("\(MobileFormat.count(follower))粉丝")
                        }
                        if let count = up?.archiveCount, count > 0 {
                            Text("\(MobileFormat.count(count))投稿")
                        }
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.secondary(scheme))

                    if let sign = up?.sign, !sign.isEmpty {
                        Text(sign)
                            .font(.system(size: 11.5))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }

            if let up {
                HStack(spacing: 8) {
                    Button {
                        Task { await model.toggleUPFollow() }
                    } label: {
                        Text(up.isFollowed ? "已关注" : "关注")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(up.isFollowed ? AppTheme.text(scheme) : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                up.isFollowed ? AppTheme.chip(scheme) : AppTheme.brand,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isUpFollowBusy)

                    Menu {
                        if up.isBlocked {
                            Button("解除拉黑") {
                                Task { await model.setUPBlocked(false) }
                            }
                        } else {
                            Button("拉黑该 UP 主", role: .destructive) {
                                isBlockConfirmPresented = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .frame(width: 36, height: 36)
                            .background(AppTheme.chip(scheme), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isUpFollowBusy)
                }
            }
        }
    }
}

struct MobileGridCard: View {
    let video: VideoItem
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            RemoteImage(url: video.coverURL)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if !video.durationText.isEmpty {
                        Text(video.durationText)
                            .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(height: 15)
                            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .padding(4)
                    }
                }

            Text(video.title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(AppTheme.text(scheme))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if video.viewCount > 0 {
                Text("\(video.viewText)次观看")
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppTheme.tertiary(scheme))
            }
        }
    }
}
