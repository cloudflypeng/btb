# BTB 组件与优雅交互契约

> 目标：把 macOS、iOS、Android 三端的 UI 收敛到一套可审计的抽象。组件只描述“是什么 + 何时用”，交互只描述“用户做了什么 + 系统如何反馈”。平台原生导航与系统手势不强行统一。

## 0. 审计结论

审计前，三端各自实现了一套相似但互不复用的 UI：

| 重复项 | 位置 | 结论 |
| --- | --- | --- |
| `InfiniteScrollFooter` | `Mac/Views/Components.swift`、`Mobile/MobileComponents.swift` | 合并为 Swift 共享组件 `BtbInfiniteScrollFooter` |
| `SectionHeader` / `MobileSectionHeader` | Mac、Mobile 各一份 | 合并为 `BtbSectionHeader`，支持图标与右侧动作 |
| `AvatarView` | Mac、Mobile 各一份 | 合并为 `BtbAvatar`，基于共享 `RemoteImage` |
| `EmptyHint` / `MobileEmptyState` / `ErrorBanner` / `MobileErrorBanner` | Mac、Mobile 各一套 | 共用 `BtbStateView` 的 page / banner 两种形态 |
| `RemoteImage` + 图片缓存 | Mac 自建 NSImage 缓存，Mobile 用 AsyncImage | 合并为跨平台缓存图片组件 |
| 加载骨架 | Mac 有详情骨架、Mobile 有 feed 骨架，Android 只有转圈 | 提取 `SkeletonBlock`，三端复用同一形态语言 |
| 自适应详情布局 | Android 首页 / 动态 / 消息各写一遍 | 提取 `AdaptiveDetailLayout` |
| 加载更多 footer + 触底加载 | Android 三个页面各写一遍 | 提取 `LoadMoreFooter` / `LoadMoreEffect` |
| 内容状态分支 | Android 三个页面重复 `when { loading / error / empty / login }` | 提取 `ContentState` + `ContentStateView` |
| 图片加载 | Android 各处裸用 `AsyncImage` | 统一 `BtbImage`，占位、失败、淡入一致 |
| 弹幕层 | Mac/iOS/Android 各自实现但契约一致 | 保留平台实现，统一契约与开关位置 |

审计后只保留一套**分层抽象**。任何新页面只允许组合下列组件，不允许再造同义组件。

## 1. 分层模型

```
Tokens        颜色 / 间距 / 圆角 / 动效 / 字体
Atoms         BtbImage · Avatar · Badge · Skeleton · Pill · IconButton
Molecules     SectionHeader · StateView · InlineNotice · FilterPillRow · PagedFooter
Organisms     MediaCard · CommentThread · PlayerChrome · DanmakuLayer · MessageRow
Layouts       FeedGrid / FeedList · AdaptiveDetailLayout · NavigationShell
Interactions  Refresh · InfiniteScroll · OptimisticToggle · PressFeedback · PlayerGestures · AuthGate
```

抽象原则：

1. **一个视觉契约只允许一个组件名。** 平台差异放在参数或内部实现，不复制组件。
2. **交互必须闭环。** 任何写操作都要有进行中、成功、失败（回滚 + 重试）三种反馈。
3. **内容态优先。** 页面先定义 loading / empty / error / login 四种内容态，再谈内容。
4. **动效克制。** 只使用 tokens 中的时长；`reduce motion` 下只保留透明度变化。
5. **列表是虚拟化的。** 不允许用 `Column` 渲染无限内容；分页阈值统一 3 个屏幕项。

## 2. 组件契约

### C01 Design Tokens

- 间距：4 / 6 / 8 / 10 / 12 / 14 / 16 / 20 / 24 / 32。
- 圆角：4（角标）/ 8（小卡）/ 12（媒体卡）/ 16（面板）/ 20（大面板）/ Capsule。
- 动效：`fast 0.16s`、`base 0.22s`、`slow 0.34s`；桌面弹簧用于详情过渡。
- 颜色：`brand #FF0033`、`accent #3EA6FF`，其余取平台语义色。
- 字体：标题 15–17 semibold，正文 13–15，辅助 11–12。

实现：Swift `Shared/UI/DesignSystem.swift`；Android `ui/theme/Theme.kt` 的 `BtbMotion` / `BtbDimens`。

### C02 MediaImage

输入 `url`、`contentScale`、失败图标、是否淡入。行为：先占位底色，加载成功淡入，失败显示语义图标，尺寸由调用方约束。禁止空 `<img>` 造成布局跳动。

实现：Swift `RemoteImage`；Android `BtbImage`。

### C03 Avatar

圆形媒体图 + 失败人像 + 0.5pt 分隔描边。尺寸由调用方给出，默认 32。

实现：Swift `BtbAvatar`；Android `Avatar`。

### C04 Skeleton

`SkeletonBlock` / `SkeletonCircle` / `FeedSkeleton` / `DetailSkeleton`。所有骨架只表达结构，不表达内容；`reduce motion` 时停止呼吸动画。

实现：Swift `Shared/UI/Skeleton.swift`；Android `ui/components/Skeleton.kt`。

### C05 ContentState

四种状态：`loading`、`empty`、`error`、`loginRequired`。每种状态包含图标、标题、说明、可选动作。页面级为居中大态，列表内为紧凑态；错误必须可重试。

实现：Swift `BtbStateView`；Android `ContentState` + `ContentStateView`。

### C06 InlineNotice

页面内联提示：警告 / 错误 / 信息，支持重试与关闭。用于“评论点赞失败”“切换清晰度失败”等局部错误，不打断用户。

实现：Swift `BtbNoticeBanner`；Android `InlineNotice`。

### C07 SectionHeader

标题 + 可选计数 + 可选右侧动作。所有“评论 125”“相关推荐 更多”都使用它，禁止裸 Text 模拟。

实现：Swift `BtbSectionHeader`；Android `SectionHeader`。

### C08 FilterPillRow

单选的胶囊筛选行，支持未读角标、横向滚动、选中态反色。用于首页推荐/热门/排行、动态分类、消息分类、评论排序。

实现：Swift `BtbPill` / `BtbFilterRow`；Android `FilterPillRow`。

### C09 PagedFooter / LoadMore

统一“加载中 / 没有更多 / 加载失败点击重试 / 空占位”四种尾巴，并提供触底触发策略：距末尾 3 项时触发，加载中不重复触发，失败后需用户重试。

实现：Swift `BtbInfiniteScrollFooter`；Android `LoadMoreFooter` + `LoadMoreEffect`。

### C10 AdaptiveDetailLayout

- 宽度 < 840dp：列表 + 底部 sheet；
- 宽度 ≥ 840dp：列表 + 右侧详情栏（400–560dp）；
- 桌面：沿用整窗详情覆盖层与 spring 过渡，不重构为侧栏。

规则：打开详情不重排列表，关闭详情回到原滚动位置；紧凑态支持返回手势，宽屏态支持 Esc / 返回键关闭。

实现：Swift 既有 `RootView` 覆盖层与 Mobile sheet；Android `AdaptiveDetailLayout`。

### C11 PlayerChrome

播放器外壳统一包含：视频表面、弹幕层、控制层、错误/加载浮层、顶部动作区（清晰度、倍速、弹幕开关）、底部进度条。

交互：单击显示/隐藏控制；双击左/中/右分别快退、播放暂停、快进；控制层 3.5s 自动隐藏；错误态只保留重试。

实现：三端既有播放器；Android 本轮补手势与震动反馈。

### C12 CommentThread

评论列表统一包含：排序切换、头像/昵称/UP 标记、正文、时间/点赞/回复数、最多 2 条楼中楼预览、加载更多。

交互：点赞为乐观更新（立即变色 + 计数变化，失败回滚并提示），点赞成功/失败有轻触反馈。

实现：Mac `CommentThreadView`、iOS `MobilePlayerView.commentsSection`、Android `CommentsSection`。

## 3. 交互契约

| ID | 交互 | 契约 |
| --- | --- | --- |
| I01 | 下拉刷新 | 保留当前内容，顶部指示器；成功后替换第一页并回到顶部；失败保留旧内容并显示 notice。 |
| I02 | 触底加载 | 距末尾 3 项触发；`loading` 时不再触发；失败显示可点击重试；没有更多时显示结束文案。 |
| I03 | 乐观切换 | 点赞/关注/收藏先改 UI，再发请求；失败回滚并给轻提示；同一目标防抖。 |
| I04 | 按压反馈 | 可点击卡片按下缩放 0.97–0.99；移动端触发轻触觉；桌面用 hover 高亮与 0.16s 过渡。 |
| I05 | 播放器手势 | 单击切换控制层；双击左/右 1/3 快退/快进 10s，双击中间播放/暂停；操作后显示 0.7s 浮层反馈并触发轻震动。 |
| I06 | 自适应切换 | 窗口跨过 840dp 时自动在 sheet 与侧栏之间切换，不丢失选中视频与列表位置；返回键/下滑可关闭。 |
| I07 | 登录门禁 | 未登录时内容态显示登录说明与按钮；登录成功后自动刷新当前页并保留页面位置。 |
| I08 | 骨架加载 | 首屏使用骨架而不是空白/单个转圈；骨架与真实布局同尺寸，避免加载完成跳动。 |
| I09 | 错误恢复 | 任何首屏错误都有重试；分页错误不覆盖已有内容；错误文案不包含签名 URL 或凭据。 |
| I10 | 动效与触觉尊重系统设置 | `reduce motion` 时取消缩放/弹簧，仅保留淡入淡出；触觉仅在移动端触发，可被系统关闭。 |
| I11 | 未读角标 | 导航栏消息入口显示总数，>99 显示 99+；进入消息页并加载后更新；无账号不显示。 |
| I12 | 状态保持 | 旋转、窗口缩放、前后台切换后保留 tab、详情选中项、列表位置；播放器会话按平台生命周期恢复。 |

## 4. 三端落地清单

图例：✅ 已按契约实现；🟡 本轮抽象后逐步替换；⬜ 未实现。

| 项 | macOS | iOS | Android |
| --- | --- | --- | --- |
| C01 Tokens | ✅ `DesignSystem.swift` | ✅ 同左 | ✅ `BtbMotion` / `BtbDimens` |
| C02 MediaImage | ✅ 共享 `RemoteImage` | ✅ 共享 `RemoteImage` | ✅ `BtbImage` |
| C03 Avatar | ✅ 共享 `BtbAvatar` | ✅ 共享 `BtbAvatar` | ✅ `Avatar` |
| C04 Skeleton | ✅ 共享 primitives + 详情骨架 | ✅ 共享 primitives + feed 骨架 | ✅ `Skeleton.kt` + 首屏/评论骨架 |
| C05 ContentState | ✅ `BtbStateView` | ✅ `BtbStateView` | ✅ `ContentStateView` |
| C06 InlineNotice | ✅ `BtbNoticeBanner` | ✅ 同左 | ✅ `InlineNotice` |
| C07 SectionHeader | ✅ `BtbSectionHeader` | ✅ 同左 | ✅ `SectionHeader` |
| C08 FilterPillRow | ✅ `BtbPill`（动态/直播/消息筛选，含 hover） | ✅ `BtbPill` / `BtbFilterRow` | ✅ `FilterPillRow` |
| C09 PagedFooter | ✅ 共享 footer | ✅ 同左 | ✅ `LoadMoreFooter` + `LoadMoreEffect` |
| C10 AdaptiveDetail | ✅ 整窗覆盖层 | ✅ 底部 sheet | ✅ `AdaptiveDetailLayout` |
| C11 PlayerChrome | ✅ 既有 | ✅ 既有 | ✅ 既有 + 手势 |
| C12 CommentThread | ✅ 既有 | ✅ 既有 | ✅ 既有 + 乐观点赞 |
| I01 下拉刷新 | ✅ | ✅ | ✅ |
| I02 触底加载 | ✅ | ✅ | ✅ |
| I03 乐观切换 | ✅ | ✅ | ✅ 动态与评论 |
| I04 按压反馈 | ✅ hover | ✅ `BtbPressableStyle` | ✅ `Pressable` |
| I05 播放器手势 | ✅ 快捷键 | ✅ 系统播放器手势 | ✅ 双击快进/快退 |
| I06 自适应切换 | ✅ | ✅ | ✅ |
| I07 登录门禁 | ✅ | ✅ | ✅ |
| I08 骨架加载 | ✅ | ✅ | ✅ |
| I09 错误恢复 | ✅ | ✅ | ✅ |
| I10 动效/触觉 | ✅ | ✅ | ✅ |
| I11 未读角标 | ✅ | ✅ | ✅ |
| I12 状态保持 | ✅ | ✅ | ✅ |

## 5. 实现映射

**Swift 共享（macOS + iOS）**

- `Shared/UI/DesignSystem.swift`：tokens、动效、触觉、`BtbPressableStyle`。
- `Shared/UI/BTBImage.swift`：`RemoteImage`、`BtbAvatar`、跨平台图片缓存。
- `Shared/UI/Skeleton.swift`：骨架 primitives。
- `Shared/UI/StateViews.swift`：`BtbStateView`、`BtbNoticeBanner`。
- `Shared/UI/FeedComponents.swift`：`BtbSectionHeader`、`BtbPill`、`BtbFilterRow`、`BtbInfiniteScrollFooter`。
- 平台文件删除同名旧组件，仅保留薄包装/typealias，防止调用方大改。

**Android**

- `ui/theme/Theme.kt`：`BtbDimens`、`BtbMotion`。
- `ui/components/BtbImage.kt`：`BtbImage`。
- `ui/components/Skeleton.kt`：骨架与骨架网格。
- `ui/components/ContentState.kt`：`ContentState`、`ContentStateView`、`InlineNotice`。
- `ui/components/FeedComponents.kt`：`SectionHeader`、`FilterPillRow`、`LoadMoreFooter`、`LoadMoreEffect`。
- `ui/components/AdaptiveDetailLayout.kt`：宽屏侧栏 / 紧凑 sheet。
- `ui/interaction/Feedback.kt`：触觉、`Pressable`、reduce motion。
- `ui/playback/PlayerSurface.kt`：单击/双击手势与 seek HUD。
- `ui/detail/CommentsSection.kt`：评论乐观点赞与骨架。

## 6. 非目标

- 不把 macOS 详情改成侧栏，也不把移动详情改成独立播放器窗口。
- 不强行统一桌面 hover、iOS 系统手势、Android ripple 等平台原生反馈。
- 不为抽象而抽象：只有出现两个以上真实调用方才提取组件。
- 不在 UI 层拼装上游 URL 或凭据；所有数据来自 bbcore 语义接口。
