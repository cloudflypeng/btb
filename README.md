# BTB

BTB 是一个原生 macOS 哔哩哔哩桌面客户端 MVP：界面使用 SwiftUI，数据与登录能力来自同级的 Go 核心 [bbcore](../bbcore)。bbcore 以子进程方式嵌入，通过 stdio 上的 NDJSON JSON-RPC 与 App 通信，不需要启动本地端口。

## 功能

- 首页推荐流、热门和全站排行榜，并覆盖 B 站全部分区（番剧、电影、国创、电视剧、综艺、纪录片、动画、游戏、鬼畜、音乐、舞蹈、影视、娱乐、知识、科技数码、资讯、美食、小剧场、汽车、时尚美妆、体育运动等）
- 左侧「最近更新」UP 主列表，点击进入 UP 详情页：资料、粉丝/投稿数、视频网格和关注
- 「我」的独立页面：我的主页、我的投稿、历史记录、播放列表、稍后再看
- 收藏夹管理：新建/编辑/删除收藏夹，公开/私密、简介与封面；批量移动、取消收藏、清空收藏夹
- 历史记录管理：单条删除、清空历史、暂停/恢复记录
- 稍后再看：逐条移除与清空
- 下载与离线播放：视频详情页一键下载，暂停/继续/断点续传、删除与磁盘空间统计，完成后可断网播放
- 设置：深浅色主题、播放默认清晰度/编码/倍速/自动连播、弹幕样式、下载清晰度/并发/限速、账号切换与退出、版本与隐私说明
- 搜索：综合/视频/用户/番剧/影视/直播/专栏类型页，排序、时长、分区筛选，搜索建议、热搜与本地搜索历史，结果分页
- 发现：全站排行榜、每周必看历史期数、全分区入口、专栏排行榜、话题广场与话题动态流
- 专栏阅读页：原生渲染正文、图片与作者/数据信息
- 视频详情页：内嵌原生播放器、UP 主信息、点赞/稍后再看/分享、相关推荐、评论区
- 评论热门/最新排序，楼中楼完整回复展开与分页，登录后可发表评论并加载更多
- 哔哩哔哩手机客户端扫码登录
- 多账号保存、切换和退出
- 个人主页：资料、关注/粉丝数、最近投稿、最近观看；关注分组筛选、关注内搜索、粉丝列表与特别关注标记
- UP 页关系操作：关注/取消关注、拉黑与解除拉黑
- 消息中心：回复我的、@我的、收到的赞、系统通知，侧栏未读角标与滚动分页
- 原生 macOS 工具栏、应用图标与 Liquid Glass 浮层组件，播放和浏览始终在当前窗口内完成

## 架构

```text
┌──────────────────────────────┐
│ BTB.app (SwiftUI, native)    │
│  Toolbar / Sidebar           │
│  Home tabs / Search          │
│  UP space / My library       │
│  VideoDetail + Comments      │
│  InlinePlayer + AVPlayerView │
└──────────────┬───────────────┘
               │ NDJSON JSON-RPC 2.0 over stdio
┌──────────────▼───────────────┐
│ bbcore (Go sidecar)          │
│  auth / video / user / search│
│  WBI / APP signing / gRPC    │
│  HLS gateway (127.0.0.1)     │
└──────────────┬───────────────┘
               │ HTTPS / WebSocket / Range
               ▼
          bilibili.com CDN
```

Swift 侧分为共享核心与薄客户端：`Shared/` 放 AppModel、数据模型、JSON-RPC 传输、事件总线和主题；`Mac/` 与 `Mobile/` 只保留平台入口、传输实现和交互界面（`Mac/Views`、`Mobile`）。网络、鉴权、签名和账号持久化都在 bbcore。App 构建时会自动编译同级目录的 `../bbcore`，并把 `bbcore` 可执行文件放进 `BTB.app/Contents/Resources/`。

B 站 UGC 返回的是分离的 DASH/fMP4 流，AVPlayer 不能直接播放。`stream.start` 会解析 `sidx` 索引，生成本机 HLS 播放列表，并在 bbcore 内启动只监听 `127.0.0.1` 的 Range 代理；App 拿到的 `master.m3u8` 直接交给 `AVPlayer`，播放结束调用 `stream.stop` 释放会话。

## 环境要求

- macOS 14 或更新版本（运行时）
- Xcode 26 或更新版本（AppIcon 使用 Icon Composer `.icon` 资源，构建阶段由 `actool` 编译）
- Go 1.22+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
```

## 构建与运行

先确保 bbcore 位于 BTB 同级目录：

```text
meanc/
├── bbcore/
└── btb/
```

然后在 `btb` 目录执行：

```bash
make project   # 生成 BTB.xcodeproj
make build     # 构建 App，并自动编译、打包 bbcore
make run       # 构建并打开 App
```

也可以直接打开 `BTB.xcodeproj` 运行。构建阶段的 `Bundle bbcore` 脚本会调用：

```bash
cd ../bbcore && CGO_ENABLED=0 go build -trimpath -o ... ./cmd/bbcore
```

如果 bbcore 不在同级目录，用预编译好的二进制覆盖：

```bash
BBCORE_BIN=/path/to/bbcore make build
```

也可以单独先构建核心：

```bash
make core      # 输出到 .build/bbcore
```

## 手机版（iOS，实验性）

BTB 同时提供一个 iOS 17+ 的 SwiftUI 版本（Xcode scheme `BTBMobile`），界面按手机单列信息流重新设计：底部五栏（首页 / 动态 / 发现 / 消息 / 我的）、大图信息流、从底部弹出的播放页、UP 空间、关注列表、收藏与稍后再看、扫码登录。

iOS 不允许 App 启动子进程，因此 bbcore 以 gomobile XCFramework 的形式链接进 App，在进程内运行同一套 JSON-RPC 服务：

```bash
make core-ios      # 交叉编译 Frameworks/BTBCore.xcframework（真机 + 模拟器）
make mobile        # 构建并在模拟器运行 BTBMobile scheme（会自动构建 XCFramework）
```

需要 Go 1.26+ 与 Xcode；`core-ios` 使用 bbcore 仓库 `go.mod` 里 `tool` 指令固定的 gomobile 版本，源码变化后自动重建。App 的数据目录默认为沙盒内 `Library/Application Support/bbcore`（文件保护 `CompleteUntilFirstUserAuthentication`、排除 iCloud 备份）；播放用的 HLS 网关仍只绑定 `127.0.0.1`。

调试时仍可改用 Mac 上的 HTTP 核心：先运行 `make core-http`，再给 Debug 构建设置 `BBCORE_HTTP_URL`（默认 `http://127.0.0.1:8787`）。该变量只在 Debug 构建中生效；`BBCORE_DATA_DIR` 同理，可临时指向本地测试数据目录。

## 安卓（Kotlin + Compose）

Android 客户端位于 `Android/`，使用原生 Kotlin + Jetpack Compose，一套代码同时适配手机和平板：

- 手机：底部导航 + 单列信息流；视频详情从底部 sheet 打开并在页内播放
- 平板/折叠屏：NavigationRail 或侧栏导航，首页按窗口宽度显示 2–4 列网格；窗口宽度 ≥840dp 时视频详情以右侧双栏展示（约占 40% 宽度）
- 首页已接入推荐、热门、排行榜；视频详情接入 `player.resolve` / `stream.start`，由 Media3 ExoPlayer 播放 bbcore 的本机 HLS，支持播放/暂停、拖动、分段进度、清晰度与编码切换、多分P、续播点，以及 15 秒 `player.progress` 心跳；切换清晰度会保留播放位置，关闭详情或切换分P会释放 `stream` 会话
- 「我的」页接入账号体系：手机号验证码登录（含 Geetest 安全验证）、扫码登录、多账号切换与移除、退出登录；登录后 `player.progress` 自动按当前账号上报
- bbcore 通过 gomobile Android AAR 在进程内运行，数据目录为 `noBackupFilesDir/bbcore`；HLS 网关仍只绑定 `127.0.0.1`

```bash
make android-core  # 生成 Android/app/libs/bbcore.aar
make android       # 构建 debug APK
```

APK 输出：`Android/app/build/outputs/apk/debug/app-debug.apk`。需要 Go 1.26+、JDK 17+、Android SDK（compileSdk 36）与 NDK；默认 SDK 为 `~/Library/Android/sdk`，可用 `ANDROID_HOME` / `ANDROID_NDK_HOME` 覆盖。

Android 目前仍在补齐搜索、动态、直播、番剧、评论、弹幕、下载、设置与离线播放。

## 数据目录

默认账号与缓存数据保存在：

```text
~/Library/Application Support/BTB/core
```

测试或迁移时可以覆盖：

```bash
BBCORE_DATA_DIR=/path/to/data \
  .build/Build/Products/Debug/BTB.app/Contents/MacOS/BTB
```

`open` 启动的 App 不继承终端的自定义环境变量；需要覆盖路径时请直接运行上面的可执行文件。

登录 Cookie 和 access key 只由 bbcore 写入本机数据目录，不进入源码仓库。App 不收集、不上传这些凭据。

## 使用说明

1. 点击工具栏右侧的账号按钮，或左侧栏底部的账号区域，用哔哩哔哩手机客户端扫码登录。
2. 登录成功后自动进入个人主页；再次点击账号区域可以切换账号或退出登录。
3. 首页顶部切换「推荐 / 热门 / 排行榜 / 分区」；分区页列出 B 站全部分区，选中后加载对应内容。
4. 左侧「最近更新」列出动态流中的 UP 主；点击进入 UP 详情页，可查看资料、粉丝/投稿数和投稿视频。
5. 左侧「我」下可以分别打开我的主页、我的投稿、历史记录、播放列表和稍后再看。
6. 点击视频卡片进入详情页，播放器在页面内原地播放；工具栏的返回按钮可以回到上一页。
7. 在详情页可以点赞、关注 UP 主、添加稍后再看、查看相关推荐和评论。

## 播放说明

- 默认优先选择 HEVC（`codecid=12`），不可用时回退 AVC（`codecid=7`）；AV1 不启用。
- 音频优先选择最高码率 AAC（通常是 30280），由 HLS master playlist 的独立音频组提供。
- 播放在详情页内完成，不打开独立窗口；离开详情页或点关闭会调用 `stream.stop`。
- HLS 网关只绑定本机回环地址，不做转码；上游 CDN 地址过期后重新起流即可。

## 当前限制

- 播放器为原生 AVPlayer + bbcore HLS 网关，目前不做转码；仅支持 UGC 的 HEVC/AVC + AAC，不含 AV1、PGC/番剧、字幕或弹幕。
- 高清晰度通常需要登录；未登录时会按账号权限返回可用画质。
- 排行榜为单次请求返回的完整榜单，不参与滚动分页。
- 匿名访问 UP 空间时 B 站可能触发风控，核心会自动改用名片接口和应用端投稿接口兜底。
- 未登录时评论区使用 B 站热门评论接口，只展示首批热门评论；登录后可以按热门/最新排序并加载更多。
- 直播、消息、番剧等能力已在 bbcore 中可用，但尚未全部接入 BTB 界面。
- 下载仅保存当前账号可解析的 UGC DASH 流；不含番剧/影视、字幕或弹幕，清晰度切换会重新下载。
- 为便于 MVP 直接拉起 Go 辅助进程，App Sandbox 和 Hardened Runtime 当前关闭；上架前需要重新设计进程模型和签名策略。
- 手机版已通过 gomobile XCFramework 在进程内运行 bbcore，不再依赖 Mac；后台播放、真机签名与分发仍在收尾。

## 后续方向

- 弹幕渲染、字幕和播放进度记忆
- 动态、直播、消息与番剧页面
- 多语言与可配置主题
- 使用原生 UI + 共享 Go 核心扩展到 iPadOS / Windows / Android
