# Anchor 正式版施工计划与验收台账

> Product decisions are confirmed; implementation completion requires evidence.

- 建立日期：2026-09-04。
- 产品决策状态：用户已确认本轮需求访谈总结，包括 Q37–Q39 的任务归属修正。
- 产品名称澄清（D09）：用户所说的“本地 ChatGPT App”就是当前 `com.openai.codex` 应用，后文统一称 Codex；不额外适配独立 ChatGPT 桌面产品，Safari 长回复范围不变。
- 工程状态：Mac Codex 本地 MVP 已达到开发者验收点并可交给用户无 iPhone 实测；完整 P0/P1 仍受 Claude、provisioned Sandbox、双设备与长期后台等范围约束，P2–P7 未整体完成。
- 用途：之后每轮施工开始前阅读，结束后更新状态、证据、偏差和下一步。
- 范围：正式版 Anchor iOS、Anchor macOS、共享包、Safari 扩展及必要 CLI 集成；不是 Demo 改造计划。
- 当前授权：用户已于 2026-09-10 授权完成 Mac MVP 后提交并合并到本地 `main`；未授权推送、PR、发布或系统配置修改。

## 0. 如何使用这份计划

1. 开工前：阅读第 1–5 节，确认本轮阶段、需求编号、验收项和 Git 基线。
2. 施工中：以第 6 节阶段清单为顺序；发现假设不成立时记录证据，不静默降低要求。
3. 收工前：执行对应测试，将结果写入第 9 节。未跑过的测试必须标记“未验证”。
4. 只有验收通过才勾选 `[x]`；代码已写、编译成功、模拟事件成功、真实来源成功、双设备成功分别记录。
5. 改变已确认产品边界先征求用户同意，在第 10 节保留旧决定、原因与新决定。
6. 后续若在其他 worktree 施工，将本文件作为同一个版本化文档带入施工分支；不要维护内容不同的第二份计划。搬运或提交遵循当轮 Git 授权。

### 0.1 文档优先级

本文记录的是 2026-09-04 本轮访谈确认后的产品方向。与早期 `PRODUCT_BASELINE.md`、`DEVELOPMENT_BLUEPRINT.md`、Demo 页面、比赛说明发生冲突时，以本文已确认边界为准；未冲突的旧材料仍可参考。后续用户明确决定可修订本文。

特别替代旧设计中的：按 App 分卡、整体任务自动恢复、仅按连接或横屏判断返回、把事件分数当完成百分比、将完整 Mac 看板视作核心交互。

### 0.2 施工基线与保护范围

2026-09-04 只读核查结果：

| 对象 | 状态 | 后续处理 |
| --- | --- | --- |
| GitHub `asdfghklddd/Anchor` 的 `main` | `dbc9bfe1546e8926eec8770a043cd9a701c05e7e`，当时无开放 PR | 每次开工重新检查；这是快照，不是永久保证 |
| `/Users/andywang/worktrees/Anchor-main-merged` | 干净 `main`，同上提交 | 正式版代码审查基线；获准实施后从更新后的正式基线开展工作 |
| `/Users/andywang/Desktop/Anchor` | `codex/demo-animation-state-fix`，`14a22abc6020788652b7a15fa58dcae78022e0f6`，有既存改动 | 本计划当前存放位置；不能将此目录旧代码误当最新正式版 |

不得覆盖现有 UI、本地化、视频、截图和清理相关改动；不得擅自切换脏分支、清空工作区或恢复文件。工程实现建议使用获准的独立 `codex/` 分支，提交、推送、PR、合并、发布分别按用户授权执行。必要英文注释说明非显然逻辑，PR 说明包含英文摘要与验证信息。

### 0.3 Mac Codex 本地 MVP 验收点

本验收点只定义“用户在没有 iPhone、开发者账号和 Claude 账号时，能否在正式 macOS target 上体验一条可信的 Codex 核心链路”，不代表完整 Anchor 产品或 P0–P7 全部完成。

- [x] 正式 `Anchor macOS` 可在隔离目录构建、启动并创建本地测试 Task；不使用 Demo 或正式用户数据。
- [x] 来源页按元数据找到最近 Codex JSONL，系统面板定位到其目录并显示候选文件名；用户选择文件后由系统完成最终授权。
- [x] 真实 Codex `task_started`、`task_complete`、`turn_aborted` 可形成同一 WorkItem 下的 Run/Event，并区分 completed 与 interrupted。
- [x] checkpoint 在事件持久化确认后推进；重启、原子替换、原地截断不丢失、不重放、不把来源路径写入 checkpoint。
- [x] 当前任务、详细历史和用户确认结束的前台退出边界已在正式 Mac UI 与存储层通过。
- [x] 127 项／13 套件、Debug 正式 target、优化 Release-validation、真实 rollout 和 600 Run／1200 Event 长稳回归通过。
- [ ] 后续产品范围：provisioned Sandbox、iPhone 同步、Claude Code、Safari 长回复、睡眠唤醒及长稳存储性能优化。

## 1. 产品目标与不做什么

### 1.1 已确认目标

Anchor 是以任务为中心的注意力与上下文伴侣，不是 AI agent，也不是替代 Codex、Claude、终端或浏览器的执行平台。

用户做一个中小型、有明确结果的任务，例如“今天完成信息采集模块”“制作一份 PPT”“剪完一段视频”。离开期间 Anchor 保留状态与关键变化；回来时用户在 iPhone 上快速理解整体情况，在 Mac 原应用里处理实际工作。

优先服务用户自己的真实使用；比赛展示不能取代实际可用性。iOS 能力应服务体验，不为展示传感器或平台特性而增加流程。

### 1.2 平台职责

| 平台 | 职责 | 不应承担 |
| --- | --- | --- |
| iPhone | 语音快速创建整体任务、子任务卡片、横屏 Dock/Dashboard、状态与返回摘要、详细历史、最终结束确认 | 迫使用户回到桌边后在手机上操作 Mac 的真实工作 |
| Mac | 后台采集、归属匹配、菜单栏轻量纠正、权限和来源配置、诊断、当前任务缓存 | 复制一套完整任务看板、弹窗追问每次活动、频繁抢焦点 |
| Safari 扩展 | 授权站点的窄范围状态采集，向 Mac 传递标准事件 | 泛化浏览历史采集、默认读取页面全文 |
| CLI 集成 | 命令生命周期及来源专用执行事件 | 默认保存命令全文、终端输出或替用户批准操作 |

UI 完全可以改变，只冻结必要的数据契约、平台职责和用户旅程。优先复用现有 SwiftUI 组件，不让当前页面反过来限定数据模型。

### 1.3 明确排除与能力边界

- 不做 Chrome/Chromium 适配、商店发布或安装链路；本轮 Web 范围只有 Safari。
- 不要求 macOS 必须通过 Mac App Store 分发；具体签名、权限、打包及发布资格在工程阶段验证。
- 不默认采用 OCR、屏幕录制、通知中心私有读取或其他私有实现作为核心依赖；如确有必要，需说明收益、风险、替代方案并单独确认。
- 不默认采集完整提示词、模型回复、网页正文、终端输出、按键内容、剪贴板、截图、Cookie、令牌或完整 AX 树。
- 不根据 CPU 使用率、进程存活、页面前台等弱信号推断“模型完成”。
- 不编造整体百分比、阶段名、预计剩余时间；“编译／测试／等待批准”等细阶段不是通用必备输出，真实的等待输入信息仍应保留。
- 不保证所有 App 都能提供同等精度；必须显示来源能力、更新时间与未知状态。
- 不修改 Clash Verge、Shadowrocket、Codex 控制通道或现有通知配置。需要来源安装或 hook 调整时另列最小变更和回滚方法。

## 2. 已确认需求与规则

| 编号 | 要求 | 不可偏离的边界 |
| --- | --- | --- |
| R01 | 一个整体任务表达本次工作的结果 | 不是跨多天的个人规划系统；不是一个 App 的生命周期 |
| R02 | iPhone 支持语音快速创建 | Mac 提供候选活动；用户可以后续修正，不要求每次手工列完所有会话 |
| R03 | 子任务卡片按工作内容组织 | App 是执行来源；同子任务可含不同来源执行 |
| R04 | 同一会话内工作持续延伸 | 追问、修改、测试、重试默认仍是原子任务，不按阶段拆新卡 |
| R05 | 一轮执行完成不等于整体任务结束 | 后续新执行可让原卡恢复进行中；历史执行结果不覆盖 |
| R06 | 用户确认结束整体任务 | 保存详细历史并退出前台；不能被新事件自动恢复 |
| R07 | 结束整体任务后复用旧会话 | 新目标属于新整体任务，仅接入新执行，旧历史不搬动 |
| R08 | 尽量自动且少打扰地关联 | 不确定时允许暂存；降低询问频率不能靠放宽误关联标准 |
| R09 | 状态区分执行、注意事项和结果 | 失败后恢复执行时不能仍只显示失败；失联不等于失败 |
| R10 | 返回时先看整体任务情况 | 手机是 Dock/Dashboard；实际处理发生在 Mac 原应用 |
| R11 | 自动离开／返回体验 | 不以常规“我回来了”按钮作为流程；结合接近变化与 Mac 活动验证 |
| R12 | 历史详细、可持久保留 | iPhone 本地保存至用户删除，私有 CloudKit 备份／恢复；Mac 不持有永久全量历史 |
| R13 | 最小权限和可解释采集 | 首次任务引导辅助功能授权；拒绝或撤回后清晰降级，不伪装已启用 |
| R14 | UI 可调整 | 功能、结构、旅程优先；正式版必须跑通，Demo 不是验收替代品 |
| R15 | 最终覆盖全部约定来源 | Codex（用户此前称 ChatGPT App）、Claude Code、CLI、Xcode、Safari 长回复、普通 Mac App；按来源公开真实精度；不增加独立 ChatGPT 桌面产品 |

## 3. 数据结构、状态与归属设计

以下领域边界已确认；类型名、存储技术和字段细节属于待实施设计，不表示现有代码已经具备。

```text
Anchor Task：整体目标、完成标准、生命周期
└── Work Item：语义子任务，对应 iPhone 一张卡片
    └── Run：一次来源执行；每个子任务可累积多轮执行与重试产生的新 Run
        └── Event：开始、关键变化、需输入、失败、完成等不可变记录

Source Session：外部工具的持续会话身份
Association：限定 Anchor Task 范围的会话／执行归属
```

### 3.1 最低契约

- Task：稳定 ID、标题、完成标准、开始／结束时间、最终确认、归档状态。
- Work Item：稳定 ID、所属 Task、语义标题、归属确认信息、聚合状态、重新活动的代次。
- Run：稳定 ID、Task／Work Item、来源、来源会话标识、外部运行标识、开始／结束时间、执行状态、最终结果。
- Event：唯一 ID、来源序列或去重信息、发生时间与接收时间、明确归属、最小事件内容、观察精度。
- Association：Task、来源身份、Source Session、目标 Work Item、生效执行边界、自动／用户确认依据。
- Source Health：权限、可用性、精度、最近成功观测、错误；与业务执行结果分离。
- History：Task、子任务、运行与关键事件、备注、返回摘要、最终快照、置信信息；不默认保存全文。

外部会话 ID 需要来源命名空间；仅窗口标题、PID、同一路径、同一站点或一个标签页都不足以作为永久会话身份。具体身份和重启恢复策略在 P0/P1 验证。

对模型会话，一次用户发起到该轮终态是一个 Run，后续追问产生新 Run；轮内多次工具调用记录为事件或有明确关系的派生执行，不把它们误认成用户新建的子任务。来源不提供逐轮边界时必须标记较低精度，不能把整个 CLI 进程冒充一个精确模型回合。

### 3.2 状态模型

内部保留三类状态信息：

| 维度 | 基础取值 | 说明 |
| --- | --- | --- |
| execution | `queued / running / waitingBackground / idle` | 描述执行是否仍在活动 |
| attention | `none / needsInput / hasFailure / stale` | 聚合层需要同时保留多个注意事项，不能用单一优先级覆盖事实 |
| outcome | `none / completed / failed / interrupted` | 已结束 Run 的结果不因后续执行而改写 |

- Work Item 是历史 Run 与当前 Run 的投影；运行失败后重试可以显示“进行中，曾有失败”。
- `stale` 表示观测可信度不足，不推断执行已停、已失败或已完成。
- `needsInput` 与真正阻塞应可区分；并非所有待处理事项都会阻止其他执行继续。
- 一次模型／工具执行完成后卡片可以显示完成；后续执行仍在当前 Task 内则恢复活动，不新建子任务卡。
- 整体 Task 只能由用户确认结束；允许提前结束，但历史应保留当时仍在执行或未解决的状态。
- 进度仅使用来源真实提供且含义明确的数值；不可将不同来源百分比简单平均为整体目标完成度。
- 可建议用户结束，但不能把“已关联部分完成”描述成所有执行完成，尤其仍有待关联活动时。

### 3.3 关联规则与 Mac 交互

1. 明确来源任务 ID、明确父子执行关系、当前 Task 内已确认的会话归属，可用于自动关联。
2. 已关联的同一会话后续默认继承，不因“实现变验证”等话题变化重新分类。避免反复询问。
3. 项目路径、会话标题、时间邻近仅作建议依据；不能仅因同仓库合并两个子任务。
4. 新会话先识别它与既有任务的关系；不能机械规定每个 App 或每次命令都生成一张卡。
5. 不确定时使用菜单栏待关联标记，点击后集中确认／改归属／忽略；不弹窗、不抢焦点。未操作不等于同意。
6. 已知属于当前 Task、但子任务未知的活动保留在任务级待关联区；不能污染已确认子任务状态。
7. 连整体 Task 归属都未知的活动只作为候选，不影响任务完成判定。
8. 用户纠正默认只影响当前 Task 的指定会话／执行范围；永久目录规则或跨任务模板需要显式选择，不默认学习。
9. 整体 Task 结束后关联失效。复用会话要面向新 Task 建立新边界；不能复活旧 Task。
10. 延迟、重复、乱序及旧队列消息必须依据原始身份与生效边界处理，不能只按接收时的当前 Task 分配。来源证据不足时隔离待确认。

可选本地语义相似度仅列为后续建议排序优化，先有真实误关联样本再决定，不能成为 MVP 的强制依赖或自动合并的唯一依据。

## 4. 采集与同步架构

```text
Mac 应用生命周期／有限 AX ／来源专用事件／CLI ／Safari
                         ↓
           标准化、校验、隐私过滤、来源健康
                         ↓
             会话身份与任务范围关联
                         ↓
              持久事件、去重与状态投影
                         ↓
       本地可信连接／离线队列／CloudKit 补传
                         ↓
       iPhone 卡片、返回摘要、归档与历史恢复
```

### 4.1 来源策略

| 来源 | 首选验证方向 | 能力边界与退化 |
| --- | --- | --- |
| Codex 桌面端 | 以 `com.openai.codex` 身份核实版本，检查能合法读取的结构化事件、会话状态；必要时窄范围 AX | 用户已确认此项就是所称 ChatGPT App；不额外验证独立 ChatGPT，亦不能假定可接管已有 app-server 连接 |
| Claude Code | 官方支持的 hooks／事件及稳定会话标识，辅以 CLI 生命周期 | 启动 `claude` 到退出不是每一轮回复；后台任务、等待授权、停止需分别验证 |
| 通用 CLI | 可选 shell hook／包装器，开始、结束、退出码及安全的上下文标识 | 不默认读取参数／输出；重试、新 shell、进程中断不能误判或重复上报 |
| Xcode | 先验证 CLI 构建／测试，再验证 GUI 场景的结构化结果或 AX | 不能把 `xcodebuild` 覆盖宣称为全部 Xcode GUI 覆盖；不可用时明确降低精度 |
| Safari 长回复 | 内嵌扩展与站点专用窄范围事件／页面状态识别 | 标签页关闭、后台化、网络暂断不等于模型完成；要处理多会话和长时运行 |
| 普通 Mac App | 通用应用生命周期＋经授权的窗口／文档／状态字段 | 只提供确实观测到的状态；窗口关闭不等于工作成果完成 |

统一层负责事件与身份契约，专用适配器负责来源语义。统一不代表有一个 API 能准确理解所有 App。

### 4.2 连接、离开与返回

- 本地可信连接服务桌边及时更新；离线队列与 CloudKit 承担补传、持久性和恢复，不许承诺云同步硬实时。
- iCloud 可用不证明人在附近；蓝牙接近不证明网络可用；连接、接近、业务新鲜度分别展示。
- 返回候选组合：此前确实离开，BLE 从远／失联变近，加上 Mac 唤醒、解锁或闲置后恢复活动等信号。
- Mac 活动只用于存在判断，不采集按键内容；横屏是展示状态，不是用户已返回的唯一证据。
- 无法确定时保留未知或弱提示，不假装可靠触发。真实 iOS 后台、锁屏和蓝牙限制必须用双设备验证。
- 返回摘要先表达整体状态，再呈现失败、待输入和重要完成；按子任务组织，允许展开时间线。
- 没有重要变化时简短说明，不制造仪式或虚假收益分数。Mac 不抢焦点，用户在原应用继续。
- Live Activity 等 iOS 展示必须反映真实更新和新鲜度，不借平台特性承诺后台持续采样。

### 4.3 隐私与存储

- 首次创建任务时解释辅助功能用途并引导授权，拒绝后能继续使用较低精度来源。
- 仅读取为身份／状态所需的字段；不因拿到 AX 权限就持续遍历所有应用全文。
- 无当前任务时，候选发现与持久记录分开；不要持续保存无关活动。队列保留、过期、清理策略在实现时明确并测试。
- 历史主要在 iPhone，保留至用户删除；私有 CloudKit 支持备份恢复，删除传播也应明确。
- Mac 在 iPhone 已可靠接收／归档之前保留必要待确认事件；不得为了“只留临时缓存”而提前丢失未同步数据。
- 安装 CLI／扩展需要用户最终授权，尽可能由 Mac 引导；不静默修改 shell 配置或来源 hooks。

## 5. 正式版现状与差距

以下是对 `main@dbc9bfe` 的源码审查快照，不是 2026-09-04 的真实双设备验收。下列仓库相对路径应在正式版基线中查阅；当前桌面旧分支可能不存在或内容不同。

| 模块 | 已有基础 | 未完成的新目标 | 代码／文档依据 |
| --- | --- | --- | --- |
| 采集入口 | 接入文件、Web、Mac workspace 三类来源 | 来源专用会话、细粒度执行、关联规则 | `Apps/AnchorMac/AnchorMacApp.swift` |
| Mac 通用观察 | 常规 GUI App 生命周期及前后台 | AX 窗口与会话、应用内部结果 | `SystemMacWorkspaceObserver.swift`、`MacWorkspaceProcessSource.swift`，位于 `Packages/AnchorKit/Sources/AnchorCore/` |
| CLI | 事件 inbox、命令开始／结束、可选 zsh hook | 模型每轮执行、后台任务与授权等待 | `Documentation/CLI_EVENT_CONTRACT.md`、`Packages/AnchorKit/Sources/AnchorCLI/main.swift` |
| Safari | 正式版内嵌扩展，站点／标签页活动 | 对话身份与长回复结果 | `Documentation/WEB_OBSERVATION_CONTRACT.md`、`Apps/AnchorSafariExtension/Resources/background.js` |
| 数据模型 | `AnchorSession.processes`，单来源 `AnchorProcess` | Task／Work Item／Run 分层及多来源关系 | `Packages/AnchorKit/Sources/AnchorCore/DomainModels.swift` |
| 结束／历史 | 标记 completed、当前任务快照 | 多任务归档、清空前台、新 Task 开始 | `Packages/AnchorKit/Sources/AnchorCore/SessionReducer.swift`、`Packages/AnchorKit/Sources/AnchorIOSFeatures/AuxiliaryViews.swift` |
| 返回判断 | 连接／接近／展示姿态 reducer | Mac 恢复活动与可靠的离开→返回序列 | `Packages/AnchorKit/Sources/AnchorCore/PresenceReducer.swift` |
| 返回摘要 | 已有页面与事件变化分数 | 去掉虚构整体百分比，按任务呈现真实差异 | `Packages/AnchorKit/Sources/AnchorIOSFeatures/AwayReturnViews.swift` |
| 持久化／同步 | 本地事件、队列、Bonjour 与 CloudKit 代码路径 | 多 Task 迁移、历史恢复、真实双设备和后台验收 | `Packages/AnchorKit/Sources/AnchorCore/Repository.swift`、`Packages/AnchorKit/Sources/AnchorTransport/` |
| Mac UI | 菜单栏＋较完整详情窗口 | 收敛为后台插件、关联入口及设置诊断 | `Packages/AnchorKit/Sources/AnchorMacFeatures/` |

## 6. 阶段施工清单

各阶段当前状态见第 9 节。顺序可根据 P0 证据调整，但不得静默取消 R15 来源范围；不成立的能力要回报用户并明确取舍。每个阶段结束必须更新第 9 节。

### P0 — 真实来源能力验证（最高优先级）

目标：先证明核心信息拿得到，不先围绕假设重构 UI。

- [ ] 核实 Codex 桌面端、Claude Code 的实际产品、版本、运行模式与可用接口，分别记录。产品名称歧义已由用户澄清，可用接口验证仍未完成。
- [ ] 对 Codex、Claude Code 两个核心来源建立能力记录，识别会话身份、每轮开始／完成、等待输入、失败／中断、继续执行；不能以一个来源的证据替代另一个。
- [ ] 验证多会话、后台运行、应用重启与观察器重启，不把进程存活当模型状态。
- [x] 给每个来源生成能力表：已观测字段、观察方法、权限、精度、缺失字段、降级方案。首轮见 `P0_SOURCE_CAPABILITY_AUDIT.md`；表中未验证项不等于已支持。
- [x] 保存经过脱敏的事件样本和可复现实验步骤，不保存无关对话或秘密。当前有 Codex 实际记录与增量探针证据；Claude 因未登录仍未完成受控实测。
- [ ] 明确最小权限、sandbox／签名可行性；任何新增配置先获准，不接管 Codex 控制链路。

完整退出标准：Codex 与 Claude Code 各有真实样本支持可用能力；未验证及未支持字段逐项标注。缺少任一核心来源验证时只能报告部分完成，不能用 fixture 将 P0 标成完成。独立 ChatGPT 桌面产品不参与退出判定。

施工放行（D10）：用户暂无 Claude 账号，已确认先用 Codex 实际身份与生命周期证据推进 P1，并继续补验 Codex 权限、后台观察与恢复，再完成 Codex 双设备闭环。Claude 先保留适配契约、解析与模拟测试，真实受控验收待有可用账号后补齐；不要求为此注册或付费。该调整改变施工依赖，不代表 P0 完整通过。

### P1 — 领域模型、归属边界与兼容迁移

- [x] 建立 Task、WorkItem、Run 及执行／注意事项／结果状态契约，并保留旧 Session 模型兼容。
- [x] 提供明确关联后的 ExternalProcessEvent → AnchorRun 映射。
- [x] Mac 端 TaskRunStore 支持原子写入与重启恢复，且终态 Run 不被迟到开始事件覆盖；旧版缺失来源 ID 的关联会被安全拒绝；AnchorKit 当前 127 个测试通过。
- [x] 确认后的来源 session→Task/WorkItem 关联可持久化并在协调器重启时恢复；未确认映射会被拒绝。
- [ ] 正式 Mac 设置页已实现 Codex JSONL 单次确认、安全作用域书签恢复、当前 Task/WorkItem 关联与运行中来源注册；真实 `NSOpenPanel`、独立偏好域书签恢复和当前 Codex 文件的真实生命周期追加／重启不重放已在无签名 Debug 包通过，另有约 16 分 54 秒、600 Run／1200 Event 的合成长稳回归通过；仍待 provisioned Sandbox 包、真实用户文件数小时运行与睡眠唤醒验收。
- [x] 协调器支持运行中新增／替换来源，无需重启 Anchor；Codex 绑定过滤早于当前 Anchor Task 的历史生命周期记录。
- [x] 独立正式实现目录的 `Anchor macOS` Debug target 构建通过（arm64，CODE_SIGNING_ALLOWED=NO）；Desktop 旧分支本轮构建失败，详见下方核对记录。
- [x] CLI 生命周期信号已有解析测试并可生成标准 ExternalProcessEvent；Codex 生命周期日志已接入独立只读文件适配器。
- [x] Codex JSONL 行扫描器已完成：仅保留三类生命周期记录，跳过损坏、正文和未知类型；新增扫描测试通过。
- [x] Codex 增量扫描覆盖半行、完整行 checkpoint、文件身份、磁盘 checkpoint、损坏状态保护及显式 reset；checkpoint 不保存日志正文。
- [x] CodexLifecycleFileSource 自动测试覆盖持续追加、原地截断、原子替换和重启不重放；真实 Debug App 已完成基础闭环、60 轮快速 soak、600 轮约 16 分 54 秒长稳回归，并从当前 Codex rollout 捕获真实完成／开始事件及跨构建重启恢复；checkpoint 不保存路径。真实用户文件的数小时／睡眠唤醒观察仍单独验收。
- [x] CodexSessionFileLocator 已完成：按文件元数据选择最近 JSONL，会话定位不读取正文；临时目录排序测试通过。

依赖：P0 已取得的 Codex 来源身份与事件语义证据；不等待 Claude 账号。Claude 尚未实测的契约明确标为暂定，解析和模拟测试不得充当真实来源证据。

- [x] Task／Work Item／Run、任务范围 Association 与独立不可变 Event 领域层已建立；Event 与 Run 原子落盘，重复／乱序／迟到事件及旧数据缺失 Event 字段已有兼容测试。
- [ ] WorkItem 与 Task 级执行／注意事项／结果三维确定性投影、重新活动代次、持久化重启读取及正式 Mac 来源页消费已实现；iPhone／同步消费与真实来源注意事项仍待完成。
- [ ] 同会话延续不拆卡；跨 App 关联需要明确证据或用户确认。
- [x] 去重、乱序、迟到、重启恢复、执行中断、旧任务消息隔离都有自动测试；真实来源与双设备部分仍按 A01–A10 单独验收。
- [ ] 领域层已实现归档、新 Task 创建、旧会话新边界及中断写恢复；正式 macOS 已验证用户确认后退出当前页且重启不恢复，iPhone／双设备旅程仍待完成。
- [x] TaskRunStore schema v2 与 Event protocol v1 已显式版本化；无版本旧历史升级前保存逐字节恢复副本，未来 schema／Event 版本拒绝读取且不覆盖原文件。旧二进制降级写入仍不支持，发布时必须禁止混用。
- [x] TaskRunStore 已将唯一当前任务记录与完整归档历史分离；每条历史保留 Task、WorkItem、Run、Event 及三维状态，不再只挂在 current session 上。iPhone 历史消费仍属 P6。

退出标准：A01–A09 中的自动测试部分通过，旧数据迁移有样本与回退证据；真实来源／双设备部分留给 P2，在此之前不得将对应完整验收项勾为通过。不要求此时做完视觉调整。

### P2 — 正式版第一个端到端闭环

依赖：P1；按 D10 先完成 Codex 子里程碑，Claude 真实闭环待有可用账号后补齐。Codex 正式进程权限、后台观察与恢复必须随接入实测，不能只用诊断脚本放行。P2 所需的最小权限与一次性归属入口随闭环实现；P3 负责扩展和打磨，不能成为 P2 的隐性阻塞。

- [ ] iPhone 语音／文本创建目标与完成标准，Mac 获取当前 Task。
- [ ] 真实会话接入，iPhone 展示同一子任务下多次执行。
- [ ] 用户继续会话后卡片恢复进行中；失败恢复、待输入、未知状态正确。
- [ ] 断连补传后去重，无串卡和伪造进度。
- [ ] 用户确认结束，历史持久保存，前台清空；创建新 Task 后复用旧会话不污染历史。
- [ ] Codex、Claude Code 分别完成来源到 Mac 到 iPhone 的证据链；不以其中一个来源替代另一个。

Codex 子里程碑：正式 target、真实 Codex 来源、真实 Mac＋iPhone 完成 A01–A10 及 A20 中适用的链路与状态场景，逐项记录证据及未覆盖项；模拟器和人工 JSON 仅作辅助。该里程碑可独立交付并放行后续施工，不等待 Claude。

完整退出标准：上述验收范围全部通过，且 Codex、Claude Code 各自有真实双设备证据链。Claude 延后期间 P2 只能报告 Codex 子里程碑完成，不得将整个 P2 或最终全来源验收标为通过。

### P3 — Mac 自动关联、权限与窄范围辅助功能

依赖：P1 与 P2 的 Codex 子里程碑已有稳定身份契约，不等待 Claude 真实闭环。

- [ ] 已确认会话与明确派生关系自动沿用，不逐轮询问。
- [ ] 任务候选、待关联活动、忽略状态与来源健康清楚区分。
- [ ] 菜单栏批量确认／改归属／忽略，不新建完整任务看板、不抢焦点。
- [ ] AX 仅提取允许字段；测试首次授权、拒绝、撤回、目标 App 无 AX 字段。
- [ ] 普通 App 的窗口／状态低精度回退不被显示为内部任务完成。
- [ ] 记录误关联率、首次确认次数、同会话重复询问次数；在真实使用中优化，禁止靠猜测消除待关联。

退出标准：A11–A13 通过；确定身份的同会话正常续接不要求重复确认；误关联与缺失应可解释可纠正。

### P4 — 扩展 CLI 与 Xcode 场景

- [ ] CLI 命令成功、失败、中断、shell 重启及重复 hook 的行为可验证。
- [ ] 长任务与明确派生执行归属正确，不按每个命令生成独立卡片。
- [ ] CLI 安装和配置尽量自动引导，保留最终确认、冲突检查与可恢复卸载。
- [ ] 覆盖 Xcode 构建／测试的 CLI 场景，再覆盖 GUI 场景；分别记录能力和限制。
- [ ] 不读取无关参数、完整路径或终端正文；确需更强身份字段时做最小隐私设计。

退出标准：A14 通过；区分“已有通用 hook”与“真实 GUI 构建／测试已验证”。

### P5 — Safari 长回复适配

- [ ] 复用正式版内嵌扩展，完成启用／权限／桥接状态引导，不引入 Chrome。
- [ ] 对目标 Web 对话建立稳定身份及每次回复 Run，不把标签页 ID 当永久对话 ID。
- [ ] 识别可证实的开始、等待、完成、失败；状态不明确时不推断。
- [ ] 验证切换标签、页面刷新、关闭、重开、网络中断和多个对话。
- [ ] 完成至少一次真实长回复观察，另用可重复测试验证长时序与恢复；不能只用短 fixture 代替。
- [ ] 无当前任务、隐私窗口、权限撤回、网站结构变化时降级与隐私边界正确。

退出标准：A15 通过，来源到 iPhone 完整链路可复现；站点适配范围及版本风险写入能力表。

### P6 — 自动返回、iOS 呈现与历史恢复

- [ ] 用已离开＋BLE 接近变化＋Mac 恢复活动验证返回，而非仅按连接或横屏。
- [ ] 区分连接、接近与数据新鲜度；未知不强行返回，也不依赖常规手动返回按钮。
- [ ] iPhone 按子任务展示整体状态、返回差异、失败／待处理与可展开事件。
- [ ] 移除虚构 impact 百分比；无重要变化时简短表达。
- [ ] 横屏 Dashboard 与必要的 Live Activity 使用同一状态投影，记录后台能力与刷新限制。
- [ ] iPhone 历史多任务浏览、重启恢复、私有 CloudKit 备份恢复和删除行为通过测试。
- [ ] Mac 临时缓存须在可靠归档交接之后清理，离线时不丢事件。
- [ ] 验证锁屏、后台、蓝牙切换、Mac 睡眠／唤醒、无本地网络与恢复连接。

退出标准：A16–A18 双设备通过；不能以“CloudKit 配置存在”或“BLE 能广播”替代体验验收。

### P7 — 正式版整体回归与版本交付

- [ ] A01–A20 全部有结果；未通过项不允许隐藏在演示脚本中。
- [ ] 正式 iOS/macOS 编译与关键 UI 流程回归，Demo fixture 不泄漏到正式入口。
- [ ] 来源权限、数据最小化、事件大小／输入校验、资源占用与持续运行稳定性复核。
- [ ] 历史迁移、断连重试、归档边界和来源版本变化的回归测试可重复运行。
- [ ] 更新本文、来源能力表、必要工程文档与已知限制；记录本地安装及发布前提。
- [ ] 经用户授权后按小批次提交／推送／PR／合并，逐项记录 SHA、CI 和真实验证；不将 CI 成功称为发布完成。

退出标准：用户能在自己的正式版工作流使用，真实采集、任务归属、返回和历史均成立；发布渠道不作为本地测试的替代。

## 7. 总体验收矩阵

状态初始均为未验证。自动测试与真机测试分开记，证据位置写入第 9 节。

| 编号 | 场景 | 期望结果 | 最低验证层 |
| --- | --- | --- | --- |
| A01 | 同一 Task 同会话多轮追问、测试、重试 | 一张子任务卡，多次 Run；不按阶段拆卡 | 单元＋真实来源 |
| A02 | 两个会话同时工作 | 不串状态、不串结果；按确认关系分卡或关联 | 单元＋真实来源 |
| A03 | 同子任务跨来源 | 多 Run 聚合，不因 App 不同强拆卡 | 单元＋集成 |
| A04 | 一轮完成后继续 | 原卡恢复活动，历史完成不改写 | 单元＋真实来源 |
| A05 | 失败后重试，仍有待输入 | 活动与历史失败／注意项并存，无错误覆盖 | 单元＋集成 |
| A06 | 来源中断／连接过期 | 未知／stale，不自动宣称完成或失败 | 单元＋故障注入 |
| A07 | 用户确认整体结束 | 持久归档、退出前台，不自动恢复 | 单元＋双设备 |
| A08 | 新 Task 复用旧会话 | 只关联新边界之后的执行；旧历史保留 | 单元＋真实来源 |
| A09 | 重复、乱序、迟到、跨任务事件 | 幂等、不串任务，无法归属则隔离 | 单元＋集成 |
| A10 | Mac／iPhone 离线后恢复、重启 | 补传不丢不重，历史可恢复 | 双设备 |
| A11 | 分别测试已知 Task 的待关联活动、完全未知归属候选 | 前者必须提示仍有待关联，不能宣称全部执行完成；后者不影响 Task 完成判定。都不污染已确认卡片，未操作不算确认；用户仍可主动提前结束 | 单元＋UI＋真实使用 |
| A12 | 同会话已确认后持续工作 | 正常续接无重复确认，不根据标题变动迁移 | UI＋真实使用 |
| A13 | AX 拒绝／撤回／字段缺失 | 明确降级，不崩溃，不扩大读取范围 | 真机 |
| A14 | CLI 与 Xcode 成功／失败／中断 | 结果有来源证据；GUI 与 CLI 覆盖分开报告 | 真实来源 |
| A15 | Safari 长回复与多标签切换 | 不把后台、关页、断网当模型完成 | Safari＋双设备 |
| A16 | 离开后返回与恢复 Mac 活动 | 恰当触发，无抢焦点或常规按钮依赖；不重复弹摘要 | 双设备 |
| A17 | 返回时没有重要变化 | 简短说明，无虚假收益或整体进度 | UI＋双设备 |
| A18 | 多任务历史与 CloudKit 恢复 | 内容完整，当前任务隔离，删除语义清晰 | 双设备＋恢复实验 |
| A19 | 正式包安装与来源启用 | 正式版包含所需组件；Safari 最终确认保留，无 Chrome 依赖 | 包检查＋本机安装 |
| A20 | iPhone 语音创建、修正识别结果、拒绝语音权限 | 能生成可编辑的目标与完成标准并关联 Mac 候选；语音不可用时可文本创建，不擅自开始错误任务 | iPhone 真机＋Mac 联调 |

## 8. 风险与工程决策门槛

| 风险 | 处理方式 | 何时必须回报用户 |
| --- | --- | --- |
| 外部 App 没有可用结构化状态 | 先 P0 验证；窄范围 AX 或明确低精度回退 | 必须 OCR／私有方法／全文读取才能实现时 |
| 无稳定会话身份 | 明确范围的临时身份与待关联，不能用标题强配 | 不能满足同会话延续或多会话隔离时 |
| 自动关联不足 | 保留确认结果与明确关系，测量真实误关联 | 想引入额外语义模型、内容采集或全局规则时 |
| 旧数据／新事件协议冲突 | 迁移样本、版本隔离、回退设计 | 可能损失历史或需重置用户数据时 |
| 云与后台不及时 | 本地优先，显示新鲜度，真实后台测试 | 无法实现约定的返回体验或持久性时 |
| 网站／工具升级破坏适配 | 版本记录、样本回归、能力降级 | 核心来源失效且无安全回退时 |
| 签名／sandbox／权限冲突 | 最小可运行样例验证再决定包结构 | 需要账号付费、扩大权限或改变分发架构时 |

实现流程的普通可逆细节可由开发者决定；不能借“最终都完成”扩张采集范围、远程执行授权或修改用户环境。

## 9. 施工台账（每轮必须更新）

### 9.1 阶段状态

| 阶段 | 状态 | 最近证据 | 下一步 |
| --- | --- | --- | --- |
| P0 | 部分完成；Claude 真实验收延后，不阻塞 Codex 施工 | Codex 增量诊断、真实 `NSOpenPanel` 与书签恢复已验证；本机无对应 provisioning profile | 继续验证 provisioned Sandbox、真实 Codex 后台与进程恢复；Claude 待有可用账号后补验 |
| P1 | Mac Codex 本地 MVP 达到用户验收点；完整阶段仍进行中 | Task/WorkItem/Run/Event 契约、来源级关联隔离、提交后确认 checkpoint、schema v2/Event v1 迁移回退、当前／历史分层、Codex interrupted 语义、正式 Mac 前台退出及三维诊断；127 项测试、真实面板／书签恢复、当前 Codex 文件真实事件／重启恢复、优化 Release-validation 及 600 Run／1200 Event 三故障长稳回归通过 | 用户先执行 Mac 本地验收；后续再做 provisioned Sandbox、真实用户文件数小时／睡眠唤醒、存储写入优化、iPhone／同步消费及真实来源迟到/乱序场景 |
| P2 | 未开始；Codex 优先 | 无 | 等待 P1，先完成 Codex Mac→iPhone 闭环；Claude 真实闭环后补 |
| P3 | 未开始 | 无 | 等待身份契约与 Codex 最小闭环，不等待 Claude 账号 |
| P4 | 未开始 | 无 | 扩展 CLI／Xcode |
| P5 | 未开始 | 无 | Safari 对话长回复 |
| P6 | 未开始 | 无 | 返回、历史、后台与云恢复 |
| P7 | 未开始 | 无 | 全部阶段回归与获准交付 |

### 9.2 每轮记录模板

```text
日期／执行人：
施工阶段与需求编号：
工作目录／分支／起始 SHA：
GitHub main／开放 PR 检查：
本轮授权范围：
本轮实际变更（文件／行为）：
测试命令、结果、环境与来源版本：
真实来源证据／双设备证据位置：
通过／未通过的验收编号：
未验证能力与已知限制：
权限／配置变更及回滚方式：
提交／推送／PR／合并／安装状态（分别写）：
与计划偏差、用户确认及变更编号：
下一轮最小可执行动作：
```

### 9.3 已发生记录

#### 2026-09-04 — 建立计划

- 完成：将访谈确认的产品边界、任务归属、阶段顺序、验收矩阵和更新模板写入本文。
- 基线核查：GitHub `main` 与干净正式版 worktree 为 `dbc9bfe`，查询时无开放 PR；桌面旧分支及既存改动保留。
- 文档验证：独立读者审查并复核通过；修正逐产品取证、Run 边界及待关联完成判定歧义，补齐 A20 语音创建降级验收。该审查只验证文档自洽，不代表业务能力验证。
- 状态：只新增文档；没有执行 P0–P7，没有业务代码修改或真实双设备测试，没有提交／推送／合并／发布。
- 下一步：获得实施授权后，从最新正式基线开展 P0；不要从桌面旧分支直接重建适配器。

#### 2026-09-04 — 推送计划与开始 P0

- 计划文档已单独提交并推送：`254ac981dd0bdb0aa494be12bb288b795dbf5399`，分支 `codex/anchor-implementation-plan`；尚未合并 main。
- 原共享仓库拉取时出现 `origin/HEAD` 引用异常，未修复；使用独立副本 `/Users/andywang/worktrees/Anchor-implementation-plan` 完成文档推送及本轮 P0 记录。桌面目录的计划同步保持一致，业务改动不动。
- 用户“继续”后开始 P0，只读核实产品身份、版本、CLI 帮助、本机 schema、当前 Anchor rollout 的结构字段；未配置 hooks、未启动模型测试、未使用 AX/OCR、未修改通知或网络。
- 真实证据：本机名为 ChatGPT.app 的产品 bundle 是 `com.openai.codex`；当前会话记录有多组 `task_started/task_complete` 及 `turn_aborted`，支持分辨同会话多轮执行。
- 限制：默认控制 socket 不存在，实时外部订阅及正式 Anchor 权限未验证；Claude 已安装但未做受控回合；独立 ChatGPT 未在限定位置找到，用户实际指代待确认。
- 新增记录：`P0_SOURCE_CAPABILITY_AUDIT.md`、`evidence/p0-2026-09-04-source-metadata.json`。本轮未通过任何完整 A01–A20，也未提交／推送本轮 P0 变更。
- 下一步：先确认产品范围，随后以隔离、最小权限的 Claude 会话验证开始／完成／中断／待输入，再验证 Codex 增量读取与恢复。

#### 2026-09-04 — 增量诊断与认证前置检查

- 当前 Claude 2.1.220 未登录；现有环境和用户 settings 没有配置 API 认证或 apiKeyHelper。没有读取凭据值、启动登录流程、发起模型请求、配置 hooks 或更改网络。
- 新增 `scripts/p0/codex-lifecycle-probe.mjs` 与测试，仅作为 P0 只读诊断工具，不接入正式业务 target。
- `node --test scripts/p0/codex-lifecycle-probe.test.mjs`：7 通过、0 失败；真实 Anchor 会话增量验证的 checkpoint 重读新增事件 0。
- 新证据见 `evidence/p0-2026-09-04-incremental-probe.json`，核查报告第 8 节说明跳过超长记录、非追加改写和正式权限等限制。P0 未整体通过，P1–P7 不提前开始。
- 所有本轮成果未提交／推送；桌面副本同步保持内容一致，既存业务改动不动。下一步由用户完成 Claude 登录后继续受控回合。

#### 产品名称澄清后的施工记录

- 用户明确确认“本地 ChatGPT App”就是当前 `com.openai.codex` 应用。
- 已按 D09 修正 R15、P0/P2 退出要求及来源能力报告；此前“独立 ChatGPT 待确认”仅保留在首轮取证历史中，不再是当前阻碍。
- 原始脱敏 JSON 保持不变：它记录当时查找结果，不定义产品范围。
- 本次只更新文档，不启动模型、不配置 hooks、不修改业务代码、不提交或推送。P0 仍部分完成，完整验收结果不变。

### 2026-09-04 — D10：无 Claude 账号时调整施工顺序

- 用户说明“我没有账号”，随后以“ok”确认 Codex 优先方案；不再将登录 Claude 作为下一阶段的前置操作。
- 下一步进入 P1，以已有 Codex 真实事件为输入建立领域模型与迁移测试；随后接正式 Mac→iPhone 的 Codex 闭环。
- Claude Code 保留在最终范围内，先做解析与模拟测试，真实来源及双设备验收待有可用账号后补齐。模拟证据不能替代真实证据；P0/P2 完整退出及最终全来源验收不提前勾选。
- 此决定取代此前施工日志中“下一步等待 Claude 登录”的安排；历史取证结果不改写。本次仅更新计划与能力报告，未改业务代码、账号配置或推送 GitHub。

### 2026-09-06 — 构建目录与验收证据纠偏

- 正式开发基线为独立目录 `/Users/andywang/worktrees/Anchor-implementation-plan`，当前 HEAD 为 `254ac98`；Desktop 仍是 `14a22ab` 的旧分支并有既存 UI 工作。局部文件复制不构成版本同步。
- 独立目录最近一次全量 Swift 测试：80 项通过。此前该目录正式 macOS Debug 无签名构建通过，仅证明该目录的构建，不证明 Desktop 或真实运行完成。
- 本轮 Desktop 构建明确失败：缺少 SourceArtifactInstaller、SafariExtensionStateClient，以及 sourceSetup 相关本地化成员。不能覆盖既存本地化工作来逐个搬运新基线依赖；后续正式实现与验收统一在独立目录开展。
- 最近文件定位只提供候选，不能证明任务归属。独立目录及 Desktop 启动入口均已撤下未确认的自动 Codex 注册；前次回复中“启动已打通 Codex”不准确，以本记录为准。
- 本轮调整了超出测试证据的勾选。整体目标仍未完成；下一步是在正式基线实现确认绑定、持久化关联及真实文件消费闭环，然后补充 Mac 本地验收证据。iPhone 与 Claude 账号仍非当前施工前置条件。

### 2026-09-06 — Desktop 正式版构建复核

- Desktop 正式目录 `/Users/andywang/Desktop/Anchor` 的 `Anchor macOS` arm64 Debug 构建已通过，命令使用 `CODE_SIGNING_ALLOWED=NO`，输出 `** BUILD SUCCEEDED **`。
- 2026-09-07 复核：Desktop 正式目录通过 59 项、6 个套件；独立实现目录通过 82 项、10 个套件；Desktop 的 `Anchor macOS` arm64 Debug 无签名构建再次成功。测试数量差异来自两个工作区的既存协作差异，分别记录。
- 构建期间恢复了正式基线中缺失的共享来源文件；Desktop 旧分支中的来源设置入口与当前基线不兼容，已移除其接线，未改 Demo target。
- Codex 最近会话定位仍是候选发现，不自动绑定任务；当前正式启动链只启用已有 FileProcessSource，等待确认入口完成后再注册 Codex 会话源。

### 2026-09-07 — Mac Codex 确认绑定验收点

- 正式实现目录新增 Codex 会话文件确认入口：系统文件面板只允许选择 JSONL；保存安全作用域书签，恢复后重新注册观察器。
- 确认时以当前 Anchor Session 创建／更新对应 Task 与 Codex WorkItem，持久化 session 关联，再动态注册来源；没有活动任务时明确失败。
- 来源只接收不早于当前 Anchor Task 开始时间的生命周期记录，避免将同一 Codex 文件的旧 turn 混入新任务。
- 协调器运行中注册测试、确认关联恢复测试、Task 归档隔离等均通过；独立实现目录全量 84 项、10 个套件通过。
- `Anchor macOS` arm64 Debug 无签名构建成功；临时构建 App 启动后持续运行超过 19 秒，无立即崩溃，随后只结束该临时进程。
- 文件面板真实点击、书签跨真实 App 重启、持续追加与文件替换仍需人工／长期运行证据，因此本项保持部分完成。

### 2026-09-09 — Mac-only 验收复核

- 独立正式实现目录 `/Users/andywang/worktrees/Anchor-implementation-plan` 的 `Anchor macOS` arm64 Debug 无签名构建再次通过；临时产物可启动并由系统注册，无构建错误。
- 独立目录 AnchorKit 全量 Swift Testing 复跑通过 84 项、10 个套件；上一轮一次配对超时未能稳定复现，立即重跑通过。Desktop 正式目录全量测试通过 59 项、6 个套件，`Anchor macOS` arm64 Debug 构建也通过。
- 本轮仍未操作 Demo target、VPN、账号或真实 iPhone；因此当前验收点是“Mac 本地正式版可构建、可启动、可测试，Codex 确认绑定链路已接线”，不是“真实用户授权与长期后台采集已完成”。
- 下一项 Mac-only 工作聚焦真实手动验收：在设置页选择当前 Codex JSONL、确认安全作用域、观察追加的 task lifecycle，并验证 Anchor 重启后书签与 Task/WorkItem 关联恢复；完成前不勾选 P1 的完整退出项。

### 2026-09-09 — 无 iPhone 的真实 Mac App Codex 闭环

- 新增只在 Debug 环境变量存在时启用的隔离验收模式：使用临时数据根目录、临时设备 ID 和指定 JSONL，不访问用户正式 Anchor 数据或 Keychain；Release 行为不变。
- 新增磁盘 checkpoint：仅保存文件编号、创建时间与完整行 scanner offset，不保存 Codex 日志正文；损坏 checkpoint 会报错且不会被覆盖。
- 修复两项 E2E 才暴露的归属缺陷：Codex 与 Mac Workspace 原先共用固定来源 UUID；Association 原先只按 Anchor Session 匹配，会把同任务下其他来源误归到 Codex WorkItem。现在按 `Anchor Session + sourceID` 隔离，并有回归测试。
- 修复 SafariServices XPC completion 在 Swift 6 下错误继承 MainActor 导致来源页崩溃的问题；改为显式 `@Sendable` completion。修复后验收运行没有生成新的 crash report。
- `scripts/validation/mac-codex-local-e2e.sh` 驱动真实构建 App 完成：空文件绑定保持 0 Run、捕获 `task_started`、同 Run 变为 completed、结束并重启 App 后不重放、再追加新 turn 后生成第二个 Run。最终为 1 Task、1 WorkItem、2 Runs、1 Association、1 checkpoint。
- 自动测试为 92 项、10 个套件全部通过；`Anchor macOS` arm64 Debug、`CODE_SIGNING_ALLOWED=NO` 构建通过。机器证据见 `Documentation/evidence/p1-2026-09-09-mac-local-codex-e2e.json`。
- 该节点证明“不用 iPhone 也能在 Mac 本地重复验证正式 App 的核心 Codex 采集链”；事件仍为脱敏合成生命周期行，真实 NSOpenPanel／安全作用域书签与真实 Codex 文件的长时间观察尚未通过。

### 2026-09-09 — 真实 NSOpenPanel 与书签跨进程恢复

- 为不依赖 iPhone 创建活动任务，同时不污染正式 Anchor 数据，Debug 隔离模式新增可独立启用的本地 Task seed 与独立 `UserDefaults` suite；未指定 JSONL 时不会绕过用户文件确认。
- 在最终 `Anchor macOS` 无签名 Debug 构建中实际打开系统 `NSOpenPanel`，选择隔离的生命周期 JSONL；来源页显示 `codex-session.jsonl`，磁盘生成 1 Task、1 WorkItem、1 Association 和 1 running Run。
- 结束该 App 进程并以相同隔离数据和偏好域重启，没有再次打开文件面板；来源页自动恢复文件名。重启后追加 `task_complete`，同一 Run 变为 completed，checkpoint offset 从 122 推进到 245。
- 真实运行发现 checkpoint 字典键仍泄露完整文件路径，与隐私说明不符。现改为固定 Codex source UUID 键，自动测试及 headless E2E 都断言 checkpoint 不包含所选路径；书签恢复入口也增加 MainActor 串行保护，避免 App 启动与来源页并发注册。
- 最终复验：AnchorKit 92 项、10 个套件通过；正式 macOS arm64 Debug 无签名构建通过；headless 生命周期 E2E（含路径泄漏断言）通过；本轮没有新 Anchor crash report。结构化证据见 `Documentation/evidence/p1-2026-09-09-mac-codex-bookmark-ui-e2e.json`。
- 签名边界已实际核查：本机 Xcode 自动签名因 `Anchor macOS` 和 `AnchorSafariExtension` 缺 provisioning profile 而失败；手工 ad-hoc 签名虽通过 `codesign --verify`，进程未完成 App Sandbox 初始化。因此本轮证明真实面板、书签写入／解析、跨进程恢复与恢复后采集，不证明 provisioned Sandbox 包的安全作用域授权。
- 下一步 Mac-only 验收转向真实 Codex JSONL 的受控生命周期和较长时间的后台／轮转观察；有可用 provisioning profile 后再补 Sandbox 执法证据。未修改 Demo、VPN、账号或正式用户数据，未提交／推送／合并。

### 2026-09-09 — 60 轮 Mac Codex 耐久与故障注入

- 新增 `scripts/validation/mac-codex-soak-e2e.sh`，直接驱动正式 `Anchor macOS` Debug App；默认每秒完成一轮隐私最小化生命周期，共 60 轮／120 个事件。
- 第 20、40 轮后及最终分别结束并重启验收 App；第 30 轮原子替换 JSONL，第 45 轮原地截断后继续写入。每轮都等待对应 source session 成为 completed，任何超时立即失败。
- 最终保持 1 Task、1 WorkItem、1 Association、60 个唯一 Run；60 个 sourceSessionID 均唯一且全部 completed。checkpoint 只有固定 source UUID 键，不包含 JSONL 路径；最终重启没有重复 Run。
- 运行期间观测到最高 RSS 138752 KiB；TaskRunStore 为 20174 bytes，事件仓库为 429325 bytes，checkpoint 为 188 bytes。本轮没有新 crash report。该数值是本机 Debug／一分钟样本，只作为后续回归基线，不等于 Release 长期资源结论。
- 先执行的 8 轮快速 soak 及正式 60 轮 soak 均通过；AnchorKit 92 项／10 个套件和正式 arm64 Debug 构建也保持通过。结构化证据见 `Documentation/evidence/p1-2026-09-09-mac-codex-soak-e2e.json`。
- 当前仍缺真实 Codex 文件在正在执行回合中的受控追加，以及数小时／睡眠唤醒级别观察；本轮不使用 iPhone，不把一分钟合成 soak 表述为长期真实来源通过。

### 2026-09-09 — WorkItem 三维状态投影

- `AnchorRun` 新增独立 `attention` 维度，当前支持 `needsInput`、`hasFailure`、`stale`；旧版持久数据缺失该字段时按空集合解码，不破坏已有 Run。
- 新增确定性 `AnchorWorkItemStateProjector`：执行、注意事项、结果不互相覆盖；执行优先级固定为 running、waitingBackground、queued、idle，并按完成后的新活动计算重新活动代次。
- 失败后的重试显示 running，同时保留可处理的历史失败提醒；重试成功后该失败只留在 Run 历史，不继续污染当前注意事项。`stale` 保持未知事实，不会伪造为失败或完成。
- `TaskRunStore` 已提供单 WorkItem 与 Task 范围的投影读取接口；失败后重试的状态经过落盘、重新创建 Store 后仍一致。终态 Run 的不可变保护沿用现有持久化规则。
- 全量 AnchorKit 99 项、11 个套件通过；正式 `Anchor macOS` arm64 Debug 无签名构建、基础 App 生命周期 E2E 与 8 轮替换／截断／重启回归通过。结构化证据见 `Documentation/evidence/p1-2026-09-09-work-item-state-projection.json`。
- 该节点只完成 WorkItem 级纯投影与存储消费入口；Task 级汇总、正式 Mac／iPhone UI、同步协议和真实 Codex `needsInput`／失败事件接入仍未完成，因此 P1 完整三维状态项保持未勾选。

### 2026-09-09 — Task 聚合与 Mac 实时诊断消费

- 新增 `AnchorTaskStateProjector`，将同一 Task 下的 WorkItem 投影聚合为执行、注意事项和观测结果；输入顺序与其他 Task 的状态不会影响结果。活动工作优先于已完成兄弟项，全部观测结果完成时只显示模型侧 `completed`，Task lifecycle 仍保持用户控制的 `active`。
- 聚合规则明确覆盖：活动工作与 `needsInput`／历史失败并存、无活动时失败优先、空 Task 保持 idle/unknown、用户归档时未解决状态不被伪造为完成。`TaskRunStore.taskState(id:)` 从落盘 Run 历史提供同一结果。
- 正式 Mac 来源页新增轻量“当前任务观测”诊断区，只显示四个聚合字段和 WorkItem／Run 数量，不展示子任务卡或替代 iPhone Dashboard；页面显示期间每秒从 Store 刷新，离开页面即取消。
- 真实无签名 Debug App 的辅助功能树确认：运行事件显示“运行中／无／尚无结果／进行中”；同一 Run 完成后约一秒更新为“空闲／无／已完成／进行中”，证明模型侧完成没有自动归档 Task；结束并重启 App 后完成状态仍恢复。
- 隔离持久化 fixture 还确认“运行中／有过失败和等待输入／尚无结果／进行中”可同时显示。该状态是 UI 映射验证，不冒充真实 Codex `needsInput` 来源证据。
- AnchorKit 104 项、12 个套件通过；正式 macOS arm64 Debug 无签名构建、基础 App E2E 与 8 轮重启／替换／截断回归通过。结构化证据见 `Documentation/evidence/p1-2026-09-09-task-state-ui-e2e.json`。
- 本轮仍未使用 iPhone、开发者账号或真实用户内容；未修改 Demo、VPN 或正式数据，未提交／推送／合并。

### 2026-09-10 — 不可变 Event 与提交后检查点确认

- `TaskRunStore` 现把隐私最小化的不可变 Event 与对应 Run 投影作为一次原子文件替换提交；Event 只保留任务／子任务／Run／来源身份、来源序列、发生／接收时间及状态种类，不保存 prompt、模型输出、文件路径或标题正文。
- Codex lifecycle 的开始、完成、中断等状态映射为独立 Event；重复事件按稳定 ID 幂等，ID 被复用于不同事实时拒绝，完成早于开始时仍保留两条事实、回填开始时间且不重开终态 Run。旧 `task-runs.json` 缺少 `events` 字段时按空历史读取并可继续追加。
- 首次把 Event 加入 60 轮脚本后，第 11 轮曾超时。初始故障检查时 JSONL 已含第 11 轮且 checkpoint 已到文件末尾，而 TaskRunStore 仍停在 10 Run／20 Event，暴露出扫描器在下游持久化完成前推进 checkpoint 的不安全窗口；残留验证进程随后补写到 11／22，因此该目录现状不能再单独证明永久丢失，但旧代码顺序确实允许在该窗口崩溃时跳过未落库事件。
- `ProcessSource` 新增显式 `acknowledge` 契约。Codex 源按完整行生成候选 checkpoint，一次只等待一个需要持久化的 Event；协调器只有在 SessionRepository 与 TaskRunStore 都成功提交后才确认并写 checkpoint。磁盘／仓库失败会保持旧 checkpoint 并进入可重试状态；跨 Session、越过 Task 边界等明确无效事实会被确认丢弃，避免永久重放。
- 新增两类回归：未确认事件跨源实例重启后必须重放；真实让 TaskRunStore 的原子替换失败时 checkpoint 必须保持为空，修复存储并重建协调器后同一 Event 成功恢复。全量 AnchorKit 112 项／13 个套件通过。
- 正式 `Anchor macOS` arm64 Debug、`CODE_SIGNING_ALLOWED=NO` 构建通过。基础真实 App E2E 为 3 Run／5 Event，覆盖完成先到、迟到开始与重复完成；8 轮回归为 8／16；最终 60 轮为 60／120，所有 ID 唯一、全部 Run 完成，包含第 20／40 轮和最终重启、第 30 轮原子替换、第 45 轮原地截断，最高 RSS 142160 KiB。
- 验证脚本退出逻辑会等待被测 App 结束，必要时只终止精确 PID，避免失败后残留 Bonjour 广播污染后续配对测试。完整测试前发现一个先前 UI 验证 App 会让既有客户端连接错误的同名 Bonjour 服务；隔离该进程后 3 个配对测试及全量套件通过，未借此修改传输产品逻辑。
- 结构化证据见 `Documentation/evidence/p1-2026-09-10-immutable-event-ack-e2e.json`。仍未使用 iPhone、真实 Codex 正在运行的回合、开发者账号或 provisioned Sandbox；`turn_aborted` 目前仍是通用失败映射，数小时后台／睡眠唤醒也未验证。本轮未修改 Demo、VPN 或正式用户数据，未提交／推送／合并。

### 2026-09-10 — Task 历史与 Event 协议版本迁移

- `TaskRunStore` 顶层格式现显式写入 `schemaVersion: 2`，`AnchorTaskEvent` 显式写入 `version: 1`。缺失顶层版本的既有文件按 v1 解释；缺失 Event version 的既有 Event 按 v1 解释。
- v1 历史第一次发生写入前，Store 在同目录保存原始字节到 `task-runs.json.pre-v2.backup`，随后才原子写入 v2 主文件。已有备份内容不同则拒绝覆盖和迁移；这提供人工回退原件，不把“可重新解码”冒充“可恢复原文件”。
- 顶层 schema 高于当前版本，或 Event version 高于当前版本时，初始化进入只读保护状态；后续修改抛出明确错误，原文件字节保持不变，也不会生成伪造备份。
- 首次针对性测试暴露 Foundation 不支持 `atomic + withoutOverwriting` 的组合并触发 signal 5；实现改为同目录唯一临时文件原子写入后，以不覆盖的 move 安装备份，并在并发目标出现时逐字节核对。修正后相关 3 项通过；后续真实来源验收加入 Mac 状态回归后，全量为 117 项／13 套件。
- 最新正式 macOS arm64 Debug 无签名构建通过；基础 App E2E 写出 schema v2 和 Event v1，共 3 Run／5 Event；8 轮为 8／16；最终 60 轮为 60／120，全部完成且 ID 唯一，三次重启、原子替换及原地截断均通过，最高 RSS 142032 KiB。
- 结构化证据见 `Documentation/evidence/p1-2026-09-10-task-history-schema-migration.json`。旧版本 App 本身不知道 v2 规则，若允许它与新版本交替写同一文件，仍可能丢弃新字段；因此当前兼容承诺是“新版本安全读取／迁移旧文件，并拒绝未知未来文件”，不是双向降级写兼容。未提交／推送／合并。

### 2026-09-10 — 当前 Codex rollout 的真实增量与重启 UI 验收

- 正式 `Anchor macOS` Debug App 在独立临时数据根目录只读绑定当前 Anchor 对话对应的真实 Codex rollout。绑定时先将 checkpoint 定位到当前 Task 的时间边界，103,840,753 bytes 的既有历史没有生成 Run 或 Event；这验证旧会话历史不会倒灌当前 Anchor Task。
- 随当前真实对话自然推进，App 捕获一个 `task_complete` 和下一回合的 `task_started`，落为 2 个不同 source session 的 2 Run／2 Event。两条 Event 的接收延迟均小于 140 ms；Task 聚合显示 running，任务 lifecycle 仍是 active，没有因模型侧完成自动归档。
- 大文件读取改为每轮最多 4 MiB，避免首次绑定约 100 MiB rollout 时一次性把余量全部读入内存；新增 32-byte 分块回归证明跨读取边界的生命周期行仍完整。首轮真实运行 8 分 41 秒末 RSS 为 111600 KiB，启动／观察样本最高为 140528 KiB；这些仅是本机 Debug 样本，不是 Release 长期资源结论。
- 重建正式 App 后复用同一隔离目录启动，重启前后保持 2 Run／2 Event，没有重放。辅助功能树同时确认来源行显示真实 JSONL 文件名，任务诊断显示“1 个工作项 · 2 次执行／运行中／无／尚无结果／进行中”。测试环境入口此前只绑定来源而未更新文件名，已统一到与面板／书签相同的连接方法并增加回归测试。
- 干净 Bonjour 环境下 AnchorKit 117 项／13 套件通过，正式 arm64 Debug、`CODE_SIGNING_ALLOWED=NO` 构建通过。测试期间误启动的另一个旧 DerivedData App 会广播相同 `_anchor._tcp` 服务并造成配对测试超时；仅停止精确识别的本轮实例后重跑通过，未修改传输逻辑或系统网络配置。多 Anchor 服务发现的产品鲁棒性留给 P2 双设备验收。
- 当前 `task-runs.json` 只含 Task／WorkItem／Run／Event 身份、状态和时间字段；Event 不含 prompt、模型输出、标题、detail 或文件路径。checkpoint 仍只保存固定来源键、文件身份及完整行 offset；当前活动行未完整时 offset 可落后文件长度，重启后从旧 offset 重读。
- 机器证据见 `Documentation/evidence/p1-2026-09-10-real-codex-live-mac-e2e.json`。本轮没有 iPhone、开发者账号、provisioned Sandbox、Claude 账号、数小时后台或睡眠唤醒证据；没有修改 Demo、VPN 或正式 Anchor 用户数据，也没有提交／推送／合并。

### 2026-09-10 — 当前任务、历史分层与新任务边界

- `TaskRunStore` 新增当前任务记录与归档历史两条读取路径。当前层只有一个未归档 Task；历史记录按结束时间倒序，保留该 Task 的 WorkItem、Run、不可变 Event 和确定性三维状态，不再依赖 legacy `current session` 承载永久历史。
- 新 Task 不能通过普通 `upsert` 静默挤掉当前 Task；只有用户会话生命周期桥接使用显式 `activate` 边界。完成 Session 会归档对应 Task，完成后创建 Session 会取得新 ID；来源侧 Run 完成仍不会结束整体 Task。
- 补充崩溃窗口恢复：若新 Session 已落盘但旧 Task 尚未归档，启动同步会以新 Session 的开始时间封口旧 Task。迟到的更早 Session 会被拒绝，持久文件保持逐字节不变。
- 全量 AnchorKit 124 项／13 套件通过，包含当前／历史分离、隐式第二前台任务拒绝、完成后新任务、边界写中断恢复、乱序旧任务拒绝以及既有旧来源消息隔离；正式 `Anchor macOS` arm64 Debug、`CODE_SIGNING_ALLOWED=NO` 构建通过。
- 新构建复用真实 Codex 隔离目录后仍为 1 个当前 Task、1 WorkItem、3 Runs、4 Events、1 Association，来源页显示“1 个工作项 · 3 次执行／运行中／无／尚无结果／进行中”，没有重放。结构化证据见 `Documentation/evidence/p1-2026-09-10-task-current-history-boundary.json`。
- 这一节点完成 P1 的数据层当前／历史分离；当时尚未完成的 legacy macOS 已完成 Session 可见退出和 `turn_aborted` 专用语义，已由紧随其后的 Mac-only 验收补齐。iPhone 历史消费仍未完成。未使用 iPhone、开发者账号、Claude、provisioned Sandbox、睡眠唤醒或数小时后台；未修改 Demo、VPN 或正式数据，未提交／推送／合并。

### 2026-09-10 — Codex 中断语义与正式 Mac 前台退出

- `ExternalProcessEvent` 增加可选的任务层观测结果；Codex `turn_aborted` 在 legacy Process 层保持 failed 兼容，但写入 TaskRunStore 时形成 `AnchorRunOutcome.interrupted` 与不可变 `AnchorTaskEventKind.interrupted`。缺失新字段的旧事件仍可解码。
- 正式 App 本地 E2E 已把 `turn_aborted` 从 JSONL 经文件源、协调器和原子存储完整跑通；最终 4 Run／6 Event 中恰好 1 个 interrupted Run 和 1 条 interrupted Event，同时保留重启不重放、完成先到、迟到开始及重复完成回归。
- 正式 macOS 入口明确关闭 completed Session 的当前工作展示；Demo 继续沿用默认行为，未修改 Demo 入口或场景。用户在真实 Debug 界面确认完成后，当前页立即切到 `mac.empty.screen`，磁盘从 1 当前／0 历史变为 0 当前／1 历史。
- 重启同一正式 App 和同一隔离目录后仍显示空当前页，归档 Task 及结束时间保持存在；历史页仍可访问 legacy Session 记录。确认说明也已改为“保留到历史并退出当前工作，之后继续同一对话会作为新任务”。
- 全量 AnchorKit 127 项／13 套件通过，正式 `Anchor macOS` arm64 Debug、`CODE_SIGNING_ALLOWED=NO` 构建通过。结构化证据见 `Documentation/evidence/p1-2026-09-10-codex-interruption-and-foreground-exit.json`。
- 该节点将 P1 的“执行中断”自动测试项勾选，并完成 Mac-only 的前台退出验收；iPhone 创建／结束、双设备边界、provisioned Sandbox、数小时后台、睡眠唤醒和 Claude 仍未通过，因此 P1/P2 不整体勾选。未修改 VPN 或正式数据，未提交／推送／合并。

### 2026-09-10 — 600 轮 Mac 持续观察、轮转与冷启动

- 正式 `Anchor macOS` 无签名 Debug App 在独立临时目录连续运行 1014.06 秒（约 16 分 54 秒），每秒写入一轮合成 Codex 生命周期；最终 1 Task、1 WorkItem、1 Association、600 个唯一 Run、1200 条唯一 Event，全部 Run 为 completed。
- 第 200、400 轮及最终重启 App，第 300 轮原子替换 JSONL，第 450 轮原地截断；每个故障点后历史均完整恢复，source session 无重复，checkpoint 仍只有固定来源键且不含所选文件路径。stdout/stderr 均为空，没有发现本轮新增 Anchor crash report，验证 App 已退出。
- Debug 长运行最高 RSS 为 298688 KiB。用同一份 600 Run／1200 Event 历史冷启动后，2 秒和 10 秒 RSS 分别为 144896 KiB、154032 KiB，状态仍保持 600／1200 且无重放；这不能证明内存泄漏，但长运行分配峰值已经构成 Release＋Instruments 画像前不得忽略的性能风险。
- 机器证据见 `Documentation/evidence/p1-2026-09-10-mac-codex-600-turn-soak.json`。该节点把一分钟级合成回归提升到约 17 分钟的进程后台观察，但仍不冒充真实用户文件的数小时运行。远程控制期间未触发 macOS 睡眠，避免切断控制链；provisioned Sandbox、睡眠唤醒、iPhone、Claude 和 Release 资源验收仍待完成。
- 本轮只运行既有脚本并记录证据，没有修改业务实现、Demo、VPN 或正式用户数据；没有提交／推送／合并。

### 2026-09-10 — Release 资源闸门与 Mac MVP 交接

- 正式 `Anchor macOS` 以 `-O -whole-module-optimization` 构建优化验证包；为复用隔离测试入口仅附加 `DEBUG` 编译条件，不等同于分发 Release。600 Run／1200 Event 在 866.73 秒内完成，包含三次进程重启、一次原子替换和一次原地截断，最终数据完整，stdout/stderr 为空。
- 优化验证长跑最大 RSS 为 337904 KiB；同一历史冷启动 2 秒／10 秒分别为 147232／146496 KiB，`vmmap` 的 physical footprint 为 65.1M、峰值 119.3M。现有仓库每个事件会复制、重放并重新编码完整 event/outbox/task state，可解释随历史增大的分配压力；当前证据不足以定性为泄漏。
- Instruments 对目标进程的 Allocation attach 被本机关闭的 Developer Mode 阻止；未为测试启用 Developer Mode。该资源问题记录为中型任务 MVP 之后的性能债，不阻塞本地正确性验收，也不算生产长期资源通过。
- 新增 `scripts/validation/launch-mac-local-mvp.sh`：构建正式 target，在临时目录创建测试 Task 并打开来源页；文件面板按元数据定位到最新候选目录并显示文件名，用户仍需选择文件并点击 Open 以完成系统授权。实际 UI 已验证到该面板并取消，没有授权或读取会话正文。
- 最终回归为 AnchorKit 127 项／13 套件全部通过；结构化证据见 `Documentation/evidence/p1-2026-09-10-release-resource-and-mvp-handoff.json`。本节点只宣布 Mac Codex 本地 MVP 进入用户验收，不把 iPhone、Claude、Safari、provisioned Sandbox、睡眠唤醒或完整 P0/P1/P2 标成完成。

## 10. 决策与变更记录

| 编号 | 日期 | 决定 | 原因／来源 |
| --- | --- | --- | --- |
| D01 | 2026-09-04 汇总 | Task → Work Item → Run → Event，App 是执行来源 | 用户确认 Q30 与最终总结 |
| D02 | 2026-09-04 汇总 | Mac 轻量插件，iPhone 为主体验，UI 可变 | 用户关于 Mac 不展示子任务看板及 Q36 的确认 |
| D03 | 2026-09-04 汇总 | 不确定时安静待关联，尽量减少发生 | Q37，不能用误关联换少确认 |
| D04 | 2026-09-04 汇总 | 同会话内后续工作是原子任务衍生 | Q38，不因实现／验证变化拆任务 |
| D05 | 2026-09-04 汇总 | 整体结束后复用会话开展新目标，算新任务 | Q39，不自动恢复旧整体任务 |
| D06 | 2026-09-04 汇总 | 用户最终结束，详细历史在 iPhone，云备份恢复 | 历史及最终总结确认 |
| D07 | 2026-09-04 汇总 | Safari-only，不做 Chrome；无默认 OCR／私有依赖 | 已确认 MVP 和隐私边界 |
| D08 | 2026-09-04 | 先来源验证，再核心模型，再真实闭环和扩展 | 施工方案；可按证据调整顺序，不减少最终范围 |
| D09 | P0 身份澄清后 | 将误增的“独立 ChatGPT 桌面产品”从 R15、P0、P2 移除；本地核心来源为 Codex 与 Claude Code，Safari 不变 | 用户原话“是的，就是这个应用”，确认 `com.openai.codex` 即此前所指。纠正产品名称歧义，不降低两个核心来源的验收要求；旧版逐产品要求由此项取代 |
| D10 | 2026-09-04 | Codex 优先推进 P1 与 P2 子里程碑；Claude 先保留解析与模拟测试，真实验收后补，不阻塞其他施工 | 用户“我没有账号”后以“ok”确认建议。无需为推进 Anchor 注册或付费；Claude 仍属最终范围，P0/P2 完整验收不能以模拟测试替代 |

新增变更格式：日期、影响需求编号、旧规则、新规则、原因、用户确认、迁移／验证影响。不要删除历史决定来掩盖方向变化。

## 11. 参考入口与后续取证

### 11.1 项目材料

- 早期产品定义：`Documentation/PRODUCT_BASELINE.md`。
- 早期工程蓝图：`Documentation/DEVELOPMENT_BLUEPRINT.md`。
- CLI 契约：`Documentation/CLI_EVENT_CONTRACT.md`。
- Web 契约：正式基线中的 `Documentation/WEB_OBSERVATION_CONTRACT.md`。
- 云同步材料：`Documentation/CLOUDKIT_MVP.md`。
- 验证记录入口：`Documentation/VALIDATION.md`。
- 访谈所属任务 ID：`01a03648-ea00-7d21-ad70-93b0f075a0da`；本文需能脱离访谈独立用于施工。

### 11.2 前期研究入口（实施时重新核实版本）

以下是前期讨论参考，不代表 Anchor 已接入，也不代表当前安装版本支持全部接口：

- [ActivityWatch 窗口采集器](https://github.com/ActivityWatch/aw-watcher-window)：通用应用／窗口观测思路，不解决语义任务归属。
- [Codex app-server 文档](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md)：会话、执行与事件研究；不能据此假定能附着已有桌面连接。
- [Claude Code hooks](https://code.claude.com/docs/en/hooks)：按安装版本核实事件语义与回调范围。
- [Safari 原生消息](https://developer.apple.com/documentation/safariservices/messaging-between-the-app-and-javascript-in-a-safari-web-extension)：Web 与本地桥接研究入口。
- [Apple 文本相似度](https://developer.apple.com/documentation/naturallanguage/finding-similarities-between-pieces-of-text)：可选的后续建议排序，不是已批准的必做依赖。

每个适配器完成时追加：来源版本、权限、入口、最小脱敏样本、可重复步骤、实际覆盖、已知缺陷和最后验真日期。
