# Anchor 修改指南

写给要改这个项目的 agent 和开发者。先读 [项目说明书](PROJECT_MANUAL.md) 了解结构。这份只讲怎么改、哪些不能改、改完怎么验证。

## 1. 动手前

和所有者协作的约定：

- 设计或产品问题（流程图、体验意见、方案）先在对话里讨论，达成一致再改代码。只有明确说「做吧」才动手。
- 所有者的原话优先于参考资料。设计稿上的 Figma 评论图钉不是 UI。
- 只有被要求时才提交。没有明确许可不要推送。
- 一件事一个提交，提交信息用 `feat(ios): …`、`fix(mac): …`、`docs: …` 这种格式，能读懂做了什么。
- 不要把 Xcode 自动改动带进提交：`Apps/Shared/InfoPlist.xcstrings`、`Localizable.xcstrings` 里自动提取的无关键。
- 工作区可能有别的会话留下的未提交改动，只提交自己改的文件，不要 `git add -A`。

绝对不要做：

- 未经所有者同意，不要对真实 iPhone 录制、trace 或 profile（xctrace、Instruments 都算）。模拟器和 Mac 上的 Anchor 进程不受此限。
- 不要打印用户的对话内容。分析日志只看结构和聚合数据。
- 不要测试或调试 DeepSeek 的网络调用，也不要动网络配置。所有者自己处理。
- 测试和工具里不要用无参数的 `LocalSessionRepository()`，它写的是真实数据。永远传临时路径。
- 不要运行旧版本的 Anchor 副本（`scripts/demo` 的 `anchor-old`）。它的 bundle ID 相同，会杀掉或共用正在运行的 Anchor。
- 不要恢复 `AGENTS.md`、`DESIGN.md` 这类自动加载的大指南，除非被要求。所有者觉得它们拖慢 agent，2026-10-23 主动撤掉了。

## 2. 产品规则

这些是决定，不是实现细节。想改先问。

任务和计划：

- 任务是在 iPhone 上创建的，不是 Codex 文件夹。目标和步骤只在 iPhone 上定。
- 只有人能标记步骤完成。agent 跑完绝不能让带步骤的任务看起来完成了。
- 下一步来自人自己的计划（`TaskNextAction`），不来自 agent 的建议。
- 来源完成不会归档任务（`TaskSessionLifecycleBridge`）。只有人的明确操作才会。
- 最多同时托管 3 个任务，第 4 次投锚显示所有者写的提示。

离开和回归：

- 唯一的回归触发条件：到 Mac 的蓝牙断开满 5 分钟后连回，且任务已有匹配的对话。没有手动回归，Mac 上也没有欢迎回来。
- 摘要模型名就是 `deepseek-flash`，key 只存 Keychain。

设备分工：

- 竖屏是日常模式，不要改。首页卡片不可点是有意的。
- 横屏是工作模式。更深的层级（回溯卡、任务卡）放在横屏和 Mac 上。
- Mac 只有灵动岛和一个设置窗口。没有菜单栏项、没有完整窗口、没有小船。
- 对话归类在岛上做，勾步骤只在 iPhone 上做。
- Mac 不替代 Codex 和 Claude Code 自己的通知，也不发自己的系统横幅。岛的速报就是提醒。

Mac 观察：

- 只读日志，不写、不回复、不恢复。
- 不确定归属时留在「未归类」等人点一下，不要猜。

## 3. 设计规则

- 让布局自己说明，不要次级标签、页脚和口号。状态放在行尾，不要为了显示状态单开一页。
- 只有展示真实数据或真实操作的页面才值得存在。
- 真需要补充信息时，用 ⓘ 和 tooltip（`MacInfoTip`、`NotchInfoTip`），不要常驻说明文字。表单标签和无障碍名称要保留。新用户仍要看得出下一步点哪里。
- 跟随系统设置（减弱动态、通知、静音开关），不要在 app 里做一份。
- 首页颜色、阴影、字体都是从设计稿逐像素测的，不要凭感觉微调。
- 声音只标记真实的状态变化，按压只有触感和视觉。打开卡片是无声的。
- 引导每一步都靠真实操作或可见变化推进，没有「下一步」按钮，没有「示例」字样。全屏磨砂，只切出当前目标。中文说「投锚」「投下」，不说「抛」。
- 首页的 "Hi! 名字"、问候语、"Today's Anchoring" 保持英文，不是漏翻。
- 宠物是安静的彩蛋：没有通知、数字、说明文字，性格不显示。身体不用红、琥珀、绿。

## 4. 想改什么，看哪里

| 想改 | 从这里开始 |
| --- | --- |
| 页面入口、导航 | `AnchorNavigation.swift`、`AnchorIOSRootView.swift` |
| 首页 | `PortraitDashboard` 及 `Home*`、`HarborTopBar` |
| 桌面布局 | `LandscapeAmbientDashboard`、`DeskTaskLibrary`（尺寸在 `Metrics`、`DeskLibraryWidths`） |
| 卡片变红、跳到最前的规则 | `TaskConversationStack` |
| 回溯卡内容 | `ConversationDigest`（Mac 算）、`DeskRecallCard`（手机显示） |
| 回归页 | `ReturnView`、`ReturnRecapper`、`DeepSeekRecapWriter` |
| 离开的判定 | `PresenceReducer` |
| 下一步怎么选 | `TaskNextAction`、`PlanText` |
| 对话归到哪个任务 | `TaskMatcher`、`MacSourceSetupModel.performPlacement` |
| 读日志、判断轮次 | `ConversationLog.swift`、`CodexTurnFacts`、`WorkBuddy.swift`、`DeepSeekHarness.swift` |
| 岛的样子 | `NotchIslandView`、`NotchTaskPills`、`NotchIslandSurface`、`NotchIslandGeometry` |
| 岛何时打开、关闭 | `NotchHoverMachine`、`AnchorNotchController` |
| 岛的消息 | `NotchPeek`、`NotchPeekStrip` |
| Mac 设置 | `MacSettingsView` |
| iPhone 设置 | `SettingsView`、`LocalDataSettingsView` |
| 配对、连接 | `AnchorBonjour*`、`AnchorBluetoothProximity`、`AnchorLinkCodec` |
| 引导 | `AnchorTour`（剧本和文案）、`TourCoach`（画面） |
| Mac 演示 | `MacDemo.swift` |
| 启动动画 | `HarborLaunchChoreography`、`HarborLaunchSplash` |
| 颜色 | `AnchorColorTokens` |
| 音效 | `AnchorSound` |
| 宠物 | `DeskPet*`，分层见 `DeskPet.swift` 文件头 |
| 文案 | 代码里的 `default:` 加 `Localizable.xcstrings` 的中文 |

文件开头的 `// Role:` 注释说明了每个文件的职责。可以这样快速搜：

```bash
grep -rn "^// Role:" Packages/AnchorKit/Sources Apps | grep -i "recap"
```

## 5. 常见修改的步骤

### 给同步的模型加字段

比如给 `AnchorProcess` 加一个字段。这些类型存在磁盘上，也在两台设备之间传。

1. 字段必须是可选的，或有默认值。旧数据和旧版本对端都没有它。
2. 如果类型有自定义 `init(from:)` 或 `CodingKeys`，一起改。
3. 确认解码缺字段的旧 JSON 不会失败，加一个测试。
4. 不要改已有字段的名字和枚举 raw value。

### 加一个改状态的操作

比如「人可以把任务置顶」。

1. `SessionCommand` 加 case。
2. `SessionOperation` 加 case，并在 `make(from:…)` 里映射。如果旧版本对端必须拒绝它，提高 `latestEnvelopeSchemaVersion`。
3. `SessionReducer` 的 `operation:` 路径里实现。日期用操作里带的，不要读时钟。`command:` 路径也保持一致。
4. 如果产品上不允许，在 `TaskDashboardPolicy.allows` 里拦住。
5. 界面调用 `model.send(...)`。
6. 在 `AnchorCoreTests` 里测 reducer 和回放。

永远不要删除或改名 `SessionOperation` 的 case，事件历史要靠它们解码。

### 加一种不进历史的消息

比如新的快照类消息。参考 `DayActivity` 和 `ConversationOpenRequest`。

1. 定义 `Codable` 类型，带 `envelopeType = "anchor.xxx.v1"`、`envelope(sourceID:)`、`init?(envelope:)`。
2. 在接收方拦截，然后 `return`，不要让它进 `applyRemote`。Mac 在 `AnchorMacApp.applyInboundEvent`，iPhone 在 `AnchorIOSApp.applyEvent`（经由 `AnchoringLog.receive`）。
3. 直接用 `transport.send` 发送。

### 接入新的 agent

参考 `WorkBuddy.swift`，最近一次就是这么加的（提交 `47a5fae`）。

1. 先用只读方式看日志结构，不要读消息内容，记下怎么判断轮次开始和结束、中断、提问。
2. `ConversationDialect` 加 case，改 `of(_:)` 的识别。
3. 写轮次读取器（返回 `TurnLogRecord`），接进 `ConversationLogReader`。
4. `CodexSessionMetadata` 加头部读取，排除子 agent。
5. `ConversationTranscript` 支持它的消息格式，用于摘要和回溯卡。
6. `TokenTally` 确认 token 的算法，只算新输入加输出，缓存读取不算。
7. `ConversationLink` 加打开链接。
8. `MacSourceSetupModel`：根目录、书签键、`observeAuthorized…`、`restore…Root`，以及授权面板里的路径。
9. `MacSettingsView` 的来源行，手机的 `AgentSources` 和卡片徽标。
10. 用脱敏的 fixture 写测试。

### 加文案

```swift
static let title = AnchorStrings.value("page.title", default: "English text")
```

然后在对应模块的 `Resources/Localizable.xcstrings` 里加中文。key 要稳定且有描述性。

### 加颜色

在 `AnchorColorTokens` 加 token，浅色深色各一个值。不要在视图里写死颜色值（宠物美术的调色板除外）。

### 加音效

`AnchorSoundEffect` 加 case，在 `AnchorSynth` 合成。先想清楚它标记的是不是真实的状态变化。声音只有所有者能判断，导出 WAV 给所有者听：

```bash
ANCHOR_SOUND_EXPORT=/tmp/anchor-sounds swift test --filter AnchorSoundTests
```

### 改引导步骤

1. `AnchorTour.Stage` 和它的转换，文案在 `TourCopy`。
2. `TourCoach` 里对应的磨砂目标，真实视图用 `tourSpot` 上报位置。
3. 这一步要能点的按钮，都要在 `TourBlocker` 里留开口。Skip 曾经就被吞掉过。
4. 更新 `AnchorTourTests` 和 UI 测试里走完整引导的流程，以及 `OnboardingRecordingUITests`。
5. 也要看 `MacDemo` 的文案是否要同步。
6. 用真实的页面和手势，不要为引导发明交互。

### 加宠物行为

保持 brain、planner、memory 的分层。小事放 `DeskPetIntents`，在 `DeskPetPlanner` 里打分，随机数走 `DeskPetRandom`，用带种子的测试。改了美术就要重新跑 `scripts/export-pets.sh`，周边要和 app 像素一致。

## 6. 踩过的坑

性能：

- 永远不要把原始时钟值喂给 `dashPhase` 或其他渲染参数，先取模。巨大的值曾让真机整个屏幕卡死。
- Mac 岛合上时的循环动画必须用 Core Animation 层，不能用 SwiftUI 的 `keyframeAnimator(repeating:)`，后者每帧都重新布局窗口。
- `MacSourceSetupModel` 每 2 秒跑一次，只在真正变化时赋值，否则岛每 2 秒重新布局。
- 不要在主线程调同步 XPC，比如 `removePendingNotificationRequests`。
- `TaskMatcher.words` 用 NLTokenizer，很贵，要走缓存。
- 目标：Mac 空闲 CPU 约 1–2%。

系统 API：

- `SCNShape` 在 iOS 上不能拉伸含二次曲线的路径，而 macOS 会自动转换，所以 Mac 上的测试发现不了。`ConnectionBrandGlyph` 必须保持三次曲线。
- `URL.resourceValues` 会缓存修改时间，轮询文件要用 `FileManager.attributesOfItem`。
- `CBManager` 的权限弹窗要等引导结束，所以 `LinkLauncher` 延后启动。
- 全应用只有一个 `CMMotionManager`（`GravitySensor`）。
- 桌面上 `keyboardWillChangeFrame` 不起作用，用 `KeyboardTopReader` 的 `keyboardLayoutGuide`。
- AppKit 在有模态 sheet 时拒绝退出，所以 `MacSingleInstance.quit` 会强制退出。

解析和文字：

- `PlanStepSplitter` 没找到动词就丢弃片段。测试放 `AnchorCoreTests`（macOS），iOS 模拟器的标注器不可靠。
- WorkBuddy 的 Bash 结果 `status` 总是 completed，要看输出里的 `Exit Code:`。
- `input_tokens` 的含义各家不同：WorkBuddy 含缓存读取，Claude Code 不含。
- 听写的语言跟随界面语言，不跟随地区（`speechLocale()`）。

SwiftUI：

- 带阴影的卡片在阴影前加 `.compositingGroup()`，否则光晕会渗到内部内容上。
- 灵动岛（Dynamic Island）在横屏两侧各占约 50 pt，桌面留了 58 pt（`islandGutter`）。
- 拿起页里的 `HomePet(lives: false)` 只绘制，否则宠物的循环会跑两份，速度翻倍。

测试和模拟器：

- XCUITest 的 `app.screenshot()` 在 iOS 27 模拟器的横屏会裁切，要录屏用 `simctl io recordVideo`，它开始录制大约晚 1 秒。
- 模拟器键盘要在输入框有焦点时手动打开。
- 拿起页只有从横屏转到竖屏才会出现，测试时要真的旋转。
- 模拟器跑不了真实语音（`kLSRErrorDomain 300`）。
- 桌面文件夹的构建缓存可能导致签名报错：用 `--scratch-path` 把构建产物放到桌面之外。
- `ProcessSourceTests` 有几个测试偶发失败，见 [说明书第 13 节](PROJECT_MANUAL.md#13-现状和已知缺口)。

## 7. 改完怎么验证

| 改动类型 | 至少要跑 |
| --- | --- |
| `AnchorCore`、`AnchorTransport`、Mac 逻辑 | `swift test` |
| 模型、操作、链路格式 | `swift test`，并确认旧数据能解码 |
| iOS 逻辑 | `xcodebuild test -scheme IOSFeatureTests` |
| 任何生产代码 | 两端编译、`check-production-data.py` |
| iOS 界面 | 模拟器上看，浅色和深色、竖屏和横屏，必要时看英文和大字号 |
| 引导 | 走完全程，或跑 UI 测试 |
| Mac 界面 | 所有者在真实刘海屏上看；UI 测试会驱动真实鼠标，不要在别人用电脑时跑 |

命令见 [说明书第 12 节](PROJECT_MANUAL.md#12-运行构建和测试)。

诚实汇报验证范围。CloudKit、蓝牙、Bonjour、权限、签名这些只有在真机上才算验证过，编译通过不算。没试过的要明说。

## 8. 注释规范

- 注释用简单英文，和现有代码一致。文档用中文。
- 每个生产文件开头是文件头：

  ```swift
  // Role: 这个文件负责什么，在系统里处于什么位置。
  // Rule: 不能破坏的产品规则（如果有）。
  // Note / Pitfall / Performance: 不看代码想不到的事（如果有）。
  ```

- 声明上用 `///` 说明它是什么、为什么存在。函数体内用 `//` 说明为什么这样做。
- 不要复述代码，不要写「这里设置 x 为 1」。只写从代码看不出来的东西：原因、约束、踩过的坑。
- 不要写日期和提交号，那些在 git 里。
- 代码改了，就同步改注释。过时的注释比没有更糟。

## 9. 改完要更新什么

- 改了结构、数据流、存储位置、支持的 agent：更新 [项目说明书](PROJECT_MANUAL.md)。
- 踩到新坑或定了新规则：更新这份指南。
- 改了 CLI 契约：更新 [CLI_EVENT_CONTRACT.md](CLI_EVENT_CONTRACT.md)。
- 新增或重命名文件：写好文件头。

`docs/` 会发布到公开网站，不要往里放内部资料。这个仓库本身也是公开的，文档和注释里不要写个人信息、密钥或对话内容。

## 10. 项目演变

想知道某个决定怎么来的，用 `git log --follow <文件>` 看。大的节点：

| 时间 | 变化 |
| --- | --- |
| 2026-07 至 09 | 初版：事件模型、配对、通用观察 |
| 2026-10-02 | 比赛提交。之后撤掉 Safari 扩展、通用 app 观察和决策功能 |
| 2026-10-17 | 方向改为个人日常工具，单位是 iPhone 上创建的任务，加入计划和下一步 |
| 2026-10-22 | 桌面变成「任务进程库」 |
| 2026-10-24 | 回归改为只由蓝牙触发，DeepSeek 写摘要；设置瘦身 |
| 2026-10-27 | 首页重做（锚定时钟、token 柱、3 个任务上限），宠物有了完整生活 |
| 2026-10-28 至 29 | Mac 只留灵动岛，删除约一万行旧界面；性能修复 |
| 2026-10-28 至 11-05 | 引导多轮重做：真实界面加假数据，全屏磨砂，无「下一步」按钮 |
| 2026-11-01 | 回溯卡（本地算法摘要），接入 DeepSeek Harness |
| 2026-11-03 至 04 | 新启动动画「AI多线程，工作有主线」，全局音效和按压手感，配对卡和「我的」页重做 |
| 2026-11-05 | 任务卡取代全屏详情，接入 WorkBuddy |
