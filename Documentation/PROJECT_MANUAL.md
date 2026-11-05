# Anchor 项目说明书

写给之后接手这个项目的 agent 和开发者。读完这份，你应该知道 Anchor 是什么、数据怎么流动、每块代码在哪。要动手改代码，接着读 [修改指南](CHANGE_GUIDE.md)。

快照日期：2026-11-05，基于 main 的 `19d22bb`。代码和这份文档不一致时，以代码为准，并顺手更新文档。

## 1. Anchor 是什么

Anchor 是一对原生 app：iPhone 和 Mac。

要解决的问题是：一个人同时用多个 AI agent（Codex、Claude Code 等）推进多个项目时，不知道下一步该做什么，也看不清每个 agent 在干什么，被打断后更是忘了当初为什么开始、接下来要做什么。

核心循环：

1. 在 iPhone 上「投下一枚锚」：写下一个任务的名字和自己的计划步骤。
2. Mac 读取本机 agent 的日志，把对话自动归到对应的任务下。
3. iPhone 竖着是日常模式（首页），横放在 Mac 旁边是工作模式（桌面看板）。
4. 蓝牙断开超过 5 分钟算离开；连回来时，回归页告诉你每个任务走到哪了。

Anchor 明确不做的事：

- 不替人回答 agent、不做决定、不恢复或操作外部工具。Mac 只观察。
- 不追踪普通 app 或浏览器活动。app 开着不等于有任务在跑。
- agent 跑完不等于步骤完成。只有人能勾掉步骤。

## 2. 术语表

代码里的名字和产品里的叫法不一样，也有历史遗留的名字，这张表最常用。

| 叫法 | 代码 | 含义 |
| --- | --- | --- |
| 任务 / 锚 | `AnchorSession` | 人在 iPhone 上创建的一个工作单位，含目标、计划、对话和历史 |
| 目标 | `AnchorGoal` | 任务名、可选的完成标准和备注、计划 |
| 计划 / 步骤 | `AnchorUserPlan` / `Step` | 人自己写的步骤，只有人能勾 |
| 对话 / 进程 | `AnchorProcess` | 任务下的一行工作，通常是一个 agent 对话，也可能是终端命令 |
| 托管任务 | `hostedSessions` | 还开着的任务，最多 3 个（`HomeTaskLimit`） |
| 当前任务 | `projection.session` | 被选中的那个；其余在 `additionalSessions` |
| 投影 | `SessionProjection` | 某台设备当前状态的完整快照，所有界面都读它 |
| 来源 | `ProcessSource` | 观察适配器，比如读某个日志文件或 CLI 收件箱 |
| 方言 | `ConversationDialect` | 日志是哪个 agent 写的：Codex / Claude Code / DeepSeek Harness / WorkBuddy |
| 在场状态 | `PresenceStatus` | 在桌前 / 离开 / 回来，由 `PresenceReducer` 判定 |
| 首页 | `PortraitDashboard` | iPhone 竖屏 |
| 桌面 / 工作台 | `LandscapeAmbientDashboard` | iPhone 横屏 |
| 任务进程库 | `DeskTaskLibrary` | 桌面右侧的文件夹区 |
| 任务锚定库 | `HomeTaskLibrary` | 首页的任务卡片面板 |
| 回溯卡 / 召回卡 | `DeskRecallCard` | 点桌面对话卡打开的卡片，内容来自 `ConversationDigest` |
| 任务卡 | `DeskTaskCard` | 点文件夹标签打开，可就地编辑计划 |
| 回归页 | `ReturnView` | 蓝牙断开 5 分钟以上又连回后出现，内容是 Mac 写的摘要 |
| 拿起页 | `DeskPickUpCard` | 手机从桌面拿起时出现。所有者有时也叫它「回归页面」，看截图里的文字来区分 |
| 灵动岛 / 岛 | `NotchIslandView` | Mac 上唯一的主界面，围绕摄像头刘海 |
| 速报 | `NotchPeek` | 岛合上时短暂伸展显示的消息 |
| 引导 / tour | `AnchorTour`、`TourCoach` | 首次启动的引导，在真实界面上跑假数据 |
| 宠物 | `DeskPet*` | 桌面和首页上的像素小宠物，是彩蛋，不是核心功能 |

遗留命名：很多函数和类型带 `Codex` 字样，比如 `CodexSessionBinder`、`MacSourceSetupModel.restoreCodexSession`，因为 Codex 是第一个接入的 agent，现在它们覆盖所有 agent。`AnchorEdgeMenu`、`AnchorStatusMenu` 里的 Edge 和 Menu 来自已删除的边缘小船和菜单栏项。`Harbor*` 是早期视觉主题的名字。`Decision*` 是已退役的决策功能，只为解码旧数据保留。

## 3. 仓库结构

```text
Anchor.xcodeproj             Xcode 工程。app 的 scheme：Anchor iOS、Anchor macOS
Apps/
  AnchorIOS/                 iPhone 入口，组装所有对象（AnchorIOSApp.swift）
  AnchorMac/                 Mac 入口、灵动岛面板控制器、设置窗口
  AnchorIOSUITests/          iPhone UI 测试，含走完整个引导的录制测试
  AnchorMacUITests/          Mac UI 测试，会驱动真实鼠标
  Shared/                    app 图标和强调色
Packages/AnchorKit/          所有业务代码都在这个 Swift 包里
  Sources/AnchorCore/        数据模型、事件、reducer、仓库、日志读取。不依赖 UI
  Sources/AnchorDesign/      颜色、字体、文案、共享组件、启动动画
  Sources/AnchorIOSFeatures/ iPhone 全部界面
  Sources/AnchorMacFeatures/ Mac 灵动岛、设置和 agent 发现
  Sources/AnchorTransport/   Bonjour、蓝牙、加密、配对、CloudKit
  Sources/AnchorCLI/         anchor 命令行工具
  Tests/                     包测试
Configuration/               Info.plist、entitlements、xcconfig
Documentation/               本说明书、修改指南、CLI 和 CloudKit 契约
docs/                        公开产品地图网站（GitHub Pages 发布这个目录）
scripts/                     校验、发布、导出、录制、演示脚本
.github/workflows/           CI
```

模块依赖只能单向：

```text
AnchorCore  <-  AnchorDesign  <-  AnchorIOSFeatures
    ^                   ^-------  AnchorMacFeatures
    |---  AnchorTransport
    |---  AnchorCLI
```

`AnchorTransport` 不依赖 `AnchorDesign`，两个 Features 模块互不依赖，也不依赖 `AnchorTransport`。需要把它们连起来的地方都在 `Apps/` 的入口文件里，这是有意的：`AnchorIOSApp.init()` 和 `AnchorMacApp.init()` 是读懂整个系统的最好起点。

规模：生产代码约 4.4 万行，`AnchorIOSFeatures` 最大（约 1.9 万行）。

## 4. 核心架构：事件日志加回放

每台设备都有一份完整的本地状态，靠事件同步。没有服务器。

```text
界面
  |  model.send(SessionCommand)
  v
AnchorSessionModel（主线程，SwiftUI 观察它）
  |
  v
LinkedSessionRepository（本地落盘后，后台发给对方）
  |
  v
LocalSessionRepository（真相来源）
  1. SessionOperation.make：命令 -> 可回放的操作
  2. 打包成 EventEnvelope，追加到事件日志和发件箱
  3. SessionReducer：回放事件，得到新的 SessionProjection
  4. 先写磁盘
  5. 再发布新投影
  |
  v
投影流 -> model.projection -> 界面刷新
```

对端收到事件后走 `applyRemote`：去重、追加、回放，确认后对方从发件箱移除。

几条必须理解的性质：

- `SessionCommand` 是给 UI 用的，不存储。`SessionOperation` 是存储和传输的形式，必须确定性可回放，所以 reducer 的 operation 路径不能读当前时钟。
- 投影只由事件回放得来。想改状态就加操作，不要直接改投影。
- 传输是至少一次送达，靠事件 ID、来源序号和 `deduplicationKey` 去重。
- UI 永远不等无线电。命令在本地落盘就算完成（`LinkedSessionRepository.requestBackgroundFlush`）。
- 重连后 `reconcilePeerHistory` 重放保留的事件，所以两边终会一致。

信封类型（`EventEnvelope.type`）：

| 类型 | 用途 | 是否进入事件历史 |
| --- | --- | --- |
| `anchor.operation.v1` | 一个 `SessionOperation` | 是 |
| `anchor.reset.v1` | 清空任务或对话（`AnchorDataReset`），两端留墓碑防复活 | 否，直接执行，排在更新的事件前面发送 |
| `anchor.history.v1` | 手机清空后请求 Mac 重发全部（`PeerHistoryRequest`） | 否 |
| `anchor.open.v1` | 手机请求在 Mac 上打开对话（`ConversationOpenRequest`），过期即丢弃 | 否 |
| `anchor.activity.v1` | 当天 token 和连接时段（`DayActivity`），新的覆盖旧的 | 否 |
| `session.projection.v1` | 旧格式，只接收，不再发送 | 旧数据 |

## 5. Mac 端

Mac 没有普通主窗口（`LSUIElement`），只有灵动岛和一个设置窗口。界面语言固定为中文（`AnchorStrings`）。

### 启动模式

`AnchorMacApp.init()` 决定模式。只有普通模式才碰真实数据。

| 模式 | 触发 | 存储 |
| --- | --- | --- |
| 普通 | 默认 | `~/Library/Application Support/Anchor` 和 Keychain |
| 演示 | 设置 › 重新体验引导（`MacDemoLaunch`） | 独立临时目录和 defaults |
| UI 测试 | `ANCHOR_UI_TESTING=1` | 临时目录，内存配对 |
| 本地验证 | `ANCHOR_LOCAL_VALIDATION_ROOT=<dir>` | 指定目录，内存配对 |

一次只运行一个 Anchor（`MacSingleInstance`）。新副本启动时会让旧副本退出，重置功能也靠这个重启。

### 观察流水线

这是 Mac 最核心的部分，主要在 `MacSourceSetupModel`：

```text
~/.codex/sessions、~/.claude/projects、~/.dsh/...、~/.workbuddy/projects
  |  用户授权一次文件夹，保存只读安全书签
  v
CodexTaskSupervisor：每 2 秒按文件元数据发现最近的对话
  |  CodexConversationSummary（只在内存，给岛显示）
  v
TaskMatcher：判断对话属于哪个任务
  |  人的纠正 > 文件夹 > 请求文字匹配 > 当前任务；不确定就留在「未归类」
  v
CodexSessionBinder：把日志绑定到任务
  |  注册 CodexLifecycleFileSource
  v
ProcessSourceCoordinator：串行把事件写进仓库
  |
  v
事件同步到 iPhone
```

同时运行的还有：

- `FileProcessSource`：读 CLI 收件箱，见 [CLI_EVENT_CONTRACT.md](CLI_EVENT_CONTRACT.md)。
- `ReturnRecapper`：手机报告回归时，读各任务最新对话，调用 DeepSeek 写摘要（`deepseek-flash`，key 在 Keychain）。没有 key 时回归页退回显示最近的请求。
- `DayActivityReporter`：统计每半小时 token 和蓝牙连接时段。
- `TaskSessionLifecycleBridge` 和 `TaskRunStore`：Mac 端的任务历史（`task-runs.json`）。

### 灵动岛

- `AnchorNotchController`（app target）：不激活的 NSPanel、全局鼠标监听、⌃⌥A、点外部关闭、速报队列。岛永远不激活 Anchor，这样复制的步骤能直接粘贴到用户正在用的 app。
- `NotchIslandView`：合上时左边是任务竖条，右边是计划进度环或连接警告；打开时显示当前任务、下一步、复制按钮、其他任务、未归类行。
- `NotchHoverMachine`：悬停状态机，纯逻辑，可测试。
- `NotchPeek`：完成 4 秒，等待回复 8 秒，连接丢失 4 秒，配对码一直显示到配对完成。
- `NotchFiling`：把对话移到别的任务或标记为不属于任务。这是 Mac 上唯一能改任务内容的入口。勾步骤只在 iPhone 上。

## 6. iPhone 端

入口：`AnchorIOSRootView` 决定显示引导还是工作区，`AnchorWorkspaceView` 管所有导航。所有路由、sheet、全屏页都列在 `AnchorNavigation.swift`。

竖屏是日常模式，横屏是工作模式，这是产品决定。竖屏首页的卡片不可点是有意的。

| 页面 | 文件 | 怎么到达 |
| --- | --- | --- |
| 首页 | `PortraitDashboard`、`HomeGreeting`、`HomeAnchoring`、`HomeTaskCards`、`HarborTopBar` | 竖屏 |
| 投锚 | `AnchorSetupView`、`AnchorSetupInput`、`AnchorDropSlider` | 点首页锚按钮 `HarborAnchorButton` |
| 桌面 | `LandscapeAmbientDashboard`、`DeskTaskLibrary`、`DeskClock`、`DeskPet` | 横屏 |
| 回溯卡 | `DeskRecallCard` | 点桌面对话卡。下滑或点旁边关闭，上滑在 Mac 打开 |
| 任务卡 | `DeskTaskCard` | 点桌面文件夹标签。大字号时改开 `ProfileDetailSheet` |
| 拿起页 | `DeskPickUpCard` | 工作进行中从横屏转回竖屏 |
| 回归页 | `ReturnView` | 蓝牙断开 5 分钟以上后连回，且任务已有匹配的对话 |
| 配对卡 | `ConnectionSettingsView`、`ConnectionHero`、`ConnectionPairingSection` | 引导结束后；平时从「我的」页进入（`openConnectionCard`） |
| 连接详情 | `ConnectionDetailView` | 设置 › 连接 |
| 我的 | `ProfileView`、`ProfileStats`、`AgentSources` | 头像 |
| 历史 | `AuxiliaryViews.swift` 的 `HistoryView` | 我的 |
| 设置 | `SettingsView`、`DeskPetPicker`、`LocalDataSettingsView` | 首页齿轮 |
| 陈旧任务恢复 | `StaleWorkspaceRecoveryView` | 任务超过一天未动 |

### 引导

`AnchorTour` 在真实界面上跑一个临时仓库，由假 Mac（`TourMac`）喂数据。`Stage` 枚举就是剧本，`TourCoach` 画覆盖层：全屏磨砂，只在当前目标处切出清晰区域。真实视图通过 `TourSpot` 上报位置。

顺序见 `AnchorTour.Stage`。先走首页和投锚（glance、clock、hello、anchorButton、setup、anchored、agent），再转到桌面（turn、desk、pet、waiting、reading、again、sending），然后是离开和回归（called、away、back、returned），最后收尾（leaving、ending、finished）。

设置里可以重新体验。首次运行时，蓝牙和同步要等引导结束才启动（`LinkLauncher`）。DEBUG 下 `ANCHOR_TOUR=1` 可以强制进入。

### 宠物

分层：`DeskPetLife`（首页和桌面共用的一条命）、`DeskPetBrain`（每 tick 行为）、`DeskPetIntents`（约每 10 分钟的小事）、`DeskPetMemory`（每只宠物单独存档）、`DeskPetRenderer` + `DeskPetLooks`（绘制）、`DeskPetScene`（小房间）。

## 7. 连接层

Mac 是服务端：`AnchorBonjourServer` + `AnchorProximityAdvertiser`（蓝牙外设）。iPhone 是客户端：`AnchorBonjourClient` + `AnchorProximityScanner`（蓝牙中心）。

- 路径：优先 Bonjour/TCP（`_anchor._tcp`），失败时走蓝牙（`AnchorAdaptiveEventTransport`）。
- 蓝牙一个服务做三件事：距离（RSSI）、配对凭证、加密事件通道。
- 配对：先试自动方式，失败再显示验证码。iCloud 方式默认关闭（`manualOnly`），只有 DEBUG 下设 `ANCHOR_ENABLE_ICLOUD_PAIRING=1` 才开。日常是蓝牙或验证码。
- 加密：用 CryptoKit 派生共享密钥，帧在 `AnchorLinkCodec` 里封装，有防重放窗口。两条路径用同一种帧格式。
- 密钥在 Keychain（`PairingIdentityStore`）。ad-hoc 的 Debug 构建用旧版钥匙串，重新编译后可能读不到，需要重新配对。
- 手机在 Mac 离开时保持一个挂起的蓝牙连接，Mac 一回来 iOS 就会唤醒 Anchor。

在场判定（`PresenceReducer`）只看蓝牙：断开满 5 分钟是离开，连回来是回归。没有手动回归。

云同步：`CloudKitEventStore` 已实现但未启用，需要付费开发者账号，见 [CLOUDKIT_MVP.md](CLOUDKIT_MVP.md)。

## 8. 支持的 agent

| Agent | 方言 | 读取位置 | 要点 |
| --- | --- | --- | --- |
| Codex | `.codex` | `~/.codex/sessions` | 有明确的 `task_started` / `task_complete` |
| Claude Code | `.claudeCode` | `~/.claude/projects` | 输入的提示开启一轮，`end_turn` 结束；跳过子 agent |
| DeepSeek Harness | `.deepseekHarness` | `~/.dsh/storages/session_projcache/sessions` | 真日志是 zstd 流读不了，只读旁边的状态 JSON |
| WorkBuddy | `.workBuddy` | `~/.workbuddy/projects` | 没有轮次结束记录，带 `providerData.usage` 的 assistant 消息才算结束 |
| 终端命令 | CLI | App Group 收件箱 | `anchor` 命令，不存参数 |

下游的匹配、绑定、同步、速报全部共用，差别只在读日志那一层（`ConversationLogReader`）。

## 9. 隐私边界

这是产品承诺，改代码时不能破坏。

只在 Mac 内存里、不落盘也不发送的：完整对话、命令和输出、`CodexConversationSummary`、匹配用的请求文字。

会通过本地链路发到手机的：对话短名、最近请求开头（≤200 字）、回复开头、测试结论、是否在等回复、累计工作时间、`ConversationDigest`、回归摘要。

只有回归摘要这一项会把对话片段发给外部（DeepSeek），且只在用户自己填了 key 之后。

其他：

- 计划照片和头像只在手机本地，不进事件。
- 文件夹权限只保留日志目录的只读书签，不碰登录文件或数据库。
- 分析用户日志时只能看结构和聚合数据，不要打印对话内容。

## 10. 数据存在哪

| 数据 | 位置 |
| --- | --- |
| 事件日志和投影（两端） | `Application Support/Anchor/session-state.json` |
| Mac 任务历史 | `Application Support/Anchor/task-runs.json` |
| 日志读取位置 | `CodexLifecycleCheckpointStore` 的默认路径 |
| 对话归属、已忽略、学到的文件夹、文件夹书签 | Mac 的 UserDefaults（`MacSourceSetupModel`） |
| 配对密钥、DeepSeek key | Keychain |
| 当天锚定时长 | 手机 UserDefaults（`anchor.anchoring.*`） |
| 宠物记忆 | 手机 UserDefaults（`anchor.desk.pet.memory.<kind>`） |
| 引导完成标记 | 手机 UserDefaults（`anchor.tour.done`） |
| CLI 收件箱 | `~/Library/Group Containers/group.com.andywang.anchor/Anchor/Inbox/` |

## 11. 设计系统

- 颜色：全部来自 `AnchorColorTokens`（浅色和深色各一值），`AnchorPalette` 是语义名。任务颜色在两台设备上一致，按琥珀、青、粉的顺序（`landscapeTaskTab(index:)`）。首页颜色是 `home*` 系列，从所有者的设计稿逐像素测得。
- 字体：只有「Hi! 名字」和时钟用 Poppins，其余用系统字体。桌面时钟是描摹的字形（`DeskClockGlyphs`）。
- 文案：`AnchorStrings.value("key", default: "English")`，中文写在 `Localizable.xcstrings`。共享词在 `L10n`，单页的词放在视图旁的 `…Copy` 枚举里。首页的 "Hi!"、问候语和 "Today's Anchoring" 故意保持英文。
- 声音：`AnchorSound` 代码合成，没有音频文件，跟随静音开关。按压只有触感和视觉，没有声音。
- 按压：`AnchorPressButtonStyle` 的 `.card` 和 `.control`。
- 动效：`AnchorMotion`，遵守系统的减弱动态效果。

## 12. 运行、构建和测试

需要 Xcode 26.2 或更高（CI 用 26.2），iOS 26+，macOS 26+。

打开 `Anchor.xcodeproj`，选 `Anchor iOS` 或 `Anchor macOS`。

包测试（不用模拟器），从 `Packages/AnchorKit` 运行：

```bash
swift test --scratch-path /tmp/anchor-swift-build
```

`--scratch-path` 用来避开桌面文件夹的 `resource fork ... detritus` 签名错误。

iOS 专属测试在 macOS 的 `swift test` 里会被跳过，要这样跑（同样在 `Packages/AnchorKit`）：

```bash
xcodebuild test -scheme IOSFeatureTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

编译检查（不需要签名）：

```bash
xcodebuild -project Anchor.xcodeproj -scheme 'Anchor iOS' -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

```bash
xcodebuild -project Anchor.xcodeproj -scheme 'Anchor macOS' -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
```

生产边界检查，CI 也会跑：

```bash
python3 scripts/validation/check-production-data.py
```

它会拒绝生产代码里出现测试夹具名和已退役的类型名。注释里也不要写这些词。

常用环境变量（都只在 DEBUG 下生效，除非另有说明）：

| 变量 | 作用 |
| --- | --- |
| `ANCHOR_UI_TESTING=1` | 临时存储，关闭真实链路 |
| `ANCHOR_UI_TEST_STORAGE_ID` | UI 测试的存储标识 |
| `ANCHOR_TOUR=1` | iPhone 强制进入引导 |
| `ANCHOR_LOCAL_VALIDATION_ROOT` | Mac 本地验证目录 |
| `ANCHOR_ENABLE_ICLOUD_PAIRING=1` | 打开 iCloud 配对 |
| `ANCHOR_SOUND_EXPORT=<dir>` | 测试导出音效 WAV |
| `ANCHOR_PET_EXPORT` | 测试导出宠物素材 |
| `ANCHOR_RECORD_LANG` | 录制引导的语言 |

脚本：

| 脚本 | 作用 |
| --- | --- |
| `scripts/record-onboarding.sh` | 在模拟器上录完整引导，会清掉模拟器里的 Anchor 数据 |
| `scripts/export-pets.sh` | 导出全部宠物素材，改完宠物美术、送印刷前要跑 |
| `scripts/demo/` | 现场演示用的项目副本工具，见 [它的 README](../scripts/demo/README.md) |
| `scripts/validation/` | 生产边界检查和 Mac 端到端验证 |
| `scripts/release/export-source.py` | 导出干净的源码 ZIP |

CI（`.github/workflows/native-ci.yml`）：包测试、两端 Release 构建、UI 测试编译、归档，并检查没有 Demo target。

## 13. 现状和已知缺口

只在模拟器或测试里验证过、没在真机确认的：

- 蓝牙回归路径、后台唤醒的完整体验。
- 引导里的语音相关权限和真实听写。模拟器跑不了真实语音。
- WorkBuddy 的中断和提问路径是从它的 CLI 代码推断的。
- DeepSeek Harness 没有在运行中的 app 里长期试过。

已知的小问题：

- `PlanStepSplitter` 在 NLTagger 找不到动词时会丢掉那一段。含「崩溃」的中文容易分词出错，iOS 模拟器的英文标注器也不可用。
- Claude Code 和 WorkBuddy 里，轮次中途的提问只有对话摘要显示等待，任务仍算运行中；DeepSeek Harness 不同。
- 回溯卡的 `%lld files changed` 没有处理单复数。
- `ProcessSourceTests` 里有 3 个测试不稳定，会偶发失败：`A source registered after coordinator start…`、`A source event for an old session…`、`A confirmed session association…`（偶尔还有 `A source association cannot capture…`）。它们用 `Task.sleep(for: .milliseconds(50))` 硬等异步结果，负载一高就超时。2026-11-05 对比过干净的 HEAD，失败率相同（各 6/10），与当时的改动无关。看到这几个失败，先单独重跑再判断。

### 没有界面在用的代码

这些类型目前没有被其他文件引用（截至本快照），可以在清理时考虑删除，删前再确认一次：

- `HomeTideCard`（连带 `TideLaneView`、`TaskTide`、`WorkGlance`、`L10n+Glance`）
- `HostedTaskCard`、`TodayRecapCard`（连带 `TodayRecap`、`TodayText`）、`ProjectionStatusNotice`
- `HarborBoatGlyph`、`HarborCompanion`
- `EdgeBuoy`（还有 `EdgeBuoyTests`）
- `TourBabble` 和 `AnchorSound.say`：已移除的宠物语音，代码还在

## 14. 其他资料

- 被撤下的旧文档（产品方向、配色规范、UI 审查、`DESIGN.md`、`AGENTS.md` 等）在分支 `backup/agent-design-docs`。其中不少内容已过时，只当历史参考。
- [公开产品地图](https://asdfghklddd.github.io/Anchor/)是 2026-10-02 的快照，早于灵动岛和首页重做，不能当成现状。
- [CLI 契约](CLI_EVENT_CONTRACT.md)、[CloudKit](CLOUDKIT_MVP.md)、[第三方声明](THIRD_PARTY_NOTICES.md)。
- [已退役的网页观察契约](WEB_OBSERVATION_CONTRACT.md)，只为兼容旧数据。
- 代码注释：每个生产文件开头都有文件头，说明角色和注意事项。找东西时可以先搜文件头：`grep -rn "^// Role:" Packages/AnchorKit/Sources`。
