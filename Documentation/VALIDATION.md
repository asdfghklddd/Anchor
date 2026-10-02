# Anchor native validation record

Last updated: 2026-10-02

## Current results

- Shared package: **205 tests passed** (149 core, 37 transport, 19 Mac features) in the final source-submission regression. These cover local persistence, slow peer acknowledgements, eventual outbox delivery, decision ownership and idempotency, duplicate process IDs, source ingestion, real loopback Bonjour pairing, reconnect, event acknowledgement, noninteractive Keychain access, and production pairing migration. The optional test against a user-supplied live Codex rollout was skipped because `ANCHOR_REAL_CODEX_ROLLOUT` was unset.
- Earlier iPhone 18 Pro / iOS 27 Simulator validation: **12 full-suite UI tests passed**. After the reliability fixes, **3 targeted tests passed again** for creation and restoration, fresh launch, and speech permission/error handling with cancel and restart. These UI suites were not repeated for the final source-submission regression.
- Earlier macOS validation: **4 functional UI tests passed** for empty workspace, pairing entry, expanded sidebar hit testing, collapsed navigation, and the resting edge entry. This run did not repeat the separate accessibility audits. These UI tests were not repeated for the final source-submission regression.
- Final iOS and macOS **Release builds passed** with code signing disabled.
- The built CLI ran actual `true` and `false` commands. Its start and finish records were durably queued with exit codes 0 and 1.
- Native Mac lifecycle stress test: **60 runs and 120 events completed**, with file replacement at run 30, truncation at run 45, and restarts at runs 20, 40, and the end. It had no lost or duplicate records or polling timeouts. Observed peak RSS was 165,936 KiB (about 162 MiB). The input was controlled lifecycle data; this does not establish long-term memory stability under live AI use.
- The production data boundary check and `git diff --check` passed.

Earlier command output is stored outside the repository in `../Build/logs/real-function-validation-20260930/`. Final source-submission regression output is stored in `../Build/logs/keychain-source-submission-20260930/`.

## Final source-submission verification (2026-09-30)

- Reran the full shared package suite after the Keychain changes: **205 tests passed**; the optional live Codex rollout check remained skipped.
- Both macOS Release and iOS Simulator Release builds passed with signing disabled. No app was launched by these build checks.
- Production data boundary and `git diff --check` checks passed. The source export includes the current working files, including the noninteractive Keychain wrapper, modern pairing migration, isolated validation, stable signed-development configuration, tests, and native workflow guidance.
- Signed fresh-install and upgrade permission behavior remains a device/account acceptance check. Network, Bluetooth, and notification permissions remain separate system permissions requested when their corresponding features need them.

## Keychain authorization follow-up (2026-09-30)

- Diagnosed three concurrently running ad-hoc Mac app instances, including two
  temporary validation/capture bundles. Their designated requirements used
  different code hashes. All three and the attached Xcode debug session were stopped.
- Background transport Keychain calls now disallow both legacy macOS password
  dialogs and Data Protection authentication UI. A disposable locked legacy
  keychain returned authentication errors immediately for reads and writes.
- **30 targeted tests passed** across pairing identity and local-link transport,
  including concurrent denied reads, legacy device-ID retention, stable fallback
  identity, persisted peer-key updates, network reconnect and Bluetooth fallback.
- Final macOS Debug and iOS Simulator Debug builds passed. The isolated Mac
  lifecycle script passed startup, event capture, restart without replay,
  out-of-order/duplicate input and interruption capture. No Mac Anchor processes
  remained after cleanup. Production data boundary and diff checks passed.
- Debug UI/local validation uses in-memory pairing credentials; the validation
  scripts own their app PIDs and clean up on exit, interrupt and termination.
  Existing inaccessible production credentials were not deleted or reauthorized.
  Stable-signature real-device pairing and recovery of previously denied
  credentials remain device/account acceptance checks.

## Production permission reduction follow-up (2026-09-30)

- Production `PairingIdentityStore` now defaults to the Data Protection keychain.
  Mac Release and the optional stable signed development configuration use this
  backend; ad-hoc Debug retains noninteractive legacy compatibility. Formal UI
  and isolated local validation remain memory-only.
- Only a confirmed missing modern item can trigger a noninteractive legacy
  migration. Readable secrets are copied to the modern backend without deleting
  old items. A denied legacy credential can be replaced by freshly verified
  pairing in the modern backend. Signing failures do not fall back to legacy.
- **36 targeted tests passed** for identity caching, migration, entitlement
  failure handling, persisted legacy test updates, network and Bluetooth paths.
  Modern-backend migration is tested with a controlled client; successful
  production Keychain access still requires signed-device acceptance.
- macOS Release and iOS Simulator Release compiled successfully with signing
  disabled, without launching an app. These are compilation checks, not proof of
  fresh-install or upgrade permission behavior. Distribution acceptance must use
  an App Store build or a correctly signed/notarized Developer ID build under a
  fresh macOS user account.

## Reliability changes verified

- Task edits finish after the durable local save. A background worker drains the outbox, so a slow or disconnected peer does not hold setup, notes, or confirmation on screen. Failed deliveries stay queued for retry.
- Decision confirmation rejects repeat taps and stale sheets. Mac source actions use the envelope's owning task and claim a newly resolved decision once, including when reconnect replays history.
- Connection, presence, source-health, and cloud refreshes preserve actionable operation errors until dismissal or a successful user operation.
- Photo preparation and file access run off the main actor. A cancelled plan view rejects a late image load from a previous task.
- Speech audio-session cleanup belongs to its recognition request. A late callback cannot disable a newer recording's controls or deactivate its audio session.
- Repeated process IDs no longer create duplicate rows or trap snapshot, history, and source lookups.
- Native validation isolates preferences, pairing identity, cloud sync, and the source inbox, so it does not consume installed app data.

## Recording-data removal

- Ordinary Debug and Release launches create no recording tasks. The scheduled iOS return generator, visual-only microphone override, fixed profile trends, arbitrary progress bars, storyboard illustrations, and static cloud-success claims were removed.
- iOS settings state that background notifications are unavailable. Decisions retain source-owned execution status until an observed update.
- On upgrade from a recording build, the local repository backs up `session-state.json` before removing reserved recording task IDs and marked synthetic process activity. Real goals and notes remain. Tests cover backup, preservation, outbox cleanup, and restart idempotency.
- `SimulatedProcessSource` is compiled only in the core test target. UI tests use private temporary storage and do not populate ordinary launches.

## Run the checks

From the repository root:

```sh
python3 scripts/validation/check-production-data.py
cd Packages/AnchorKit && swift test
```

The `Anchor iOS` and `Anchor macOS` schemes in `Anchor.xcodeproj` include formal UI tests. GitHub Actions runs package tests, unsigned Release builds, UI-test compilation, and archive checks for the production apps. A clean source archive can be generated with `python3 scripts/release/export-source.py /tmp/Anchor-source-submission.zip`.

## Device and account acceptance still needed

Physical iPhone–Mac Bluetooth/Bonjour behavior, successful on-device speech transcription, provisioned CloudKit, signed Safari App Group handoff, and long background/sleep recovery require the corresponding devices and signing account. The simulator speech test accepts a clear recognizer-unavailable error when controls remain usable. The unsigned builds and controlled stress run do not establish those services or a zero-defect guarantee.

## 2026-10-02 — iOS 草稿、记录保存与状态灯

- 用户授权实现 UI/UX 评审的 I1、I2、I3。草稿在当前 App 使用期间保留，成功创建或明确放弃后清空；记录保存中防连点，失败保留文字，成功反馈跟随本地持久化结果；移除任务卡五角星，完成使用对勾徽章。
- 新增 `AnchorIOSFeaturesTests`：7 个测试通过，其中状态映射参数测试覆盖全部 7 种 ProcessStatus。覆盖失败重试、未完成保存期间重复提交、成功后再次点击、空白输入、混合会话、无进程个人计划、环境进程过滤和主动中断。命令：`swift test --scratch-path /tmp/anchor-uiux-swift-build --filter 'AnchorNoteSubmissionTests|HostedTaskIndicatorTests'`。
- iOS Debug 模拟器构建通过。4 个不同 UI 流程测试通过：关闭/恢复/放弃/提交后重置草稿；横屏暂存与恢复；连续创建两个任务及昵称恢复；保存记录后重开可见已保存内容。测试采用 `ANCHOR_UI_TESTING=1` 和独立存储。
- 截图检查发现新增草稿提示与底部按钮重叠，已将提示与放弃入口移至底部 safeAreaInset 操作栈，最终将滚动内容和底部操作放入独立的 VStack 布局区域，并裁剪滚动边界，避免固定按钮覆盖步骤导航。测试增加两者不重叠的坐标断言。早期失败分别为 SwiftUI 类型推断超时和测试对系统确认按钮的多节点匹配，已拆分表达式并调整测试定位。
- 产物：`/tmp/anchor-uiux-unit.log`、`/tmp/anchor-uiux-ios-tests-r2.xcresult`（包含两个通过的回归测试及已修正的测试定位失败）、`/tmp/anchor-uiux-ios-tests-r3.xcresult`（两项通过）、`/tmp/anchor-uiux-ios-layout-v2.xcresult`（横屏通过）、`/tmp/anchor-uiux-ios-layout-verified.xcresult`（草稿与布局坐标断言通过）。
- 本次未重跑全部包测试或 macOS App UI 测试；未验证真机触感、VoiceOver 全流程和强制退出后的草稿恢复。草稿采用内存暂存，强制退出恢复不属于本次实现。

## 2026-10-02：收敛为 AI／终端任务看板

- 两个正式启动器启用 TaskDashboardPolicy；Mac 不再注册 MacWorkspaceProcessSource 和 WebProcessSource，当前来源名称请求不再枚举系统应用，入站同步不再派发决策动作。
- 当前任务和并行任务视图过滤旧环境／浏览器来源、决策对象及相关时间线／返航变化；旧存储与归档保持兼容。决策命令（包括任务作用域包装）在正式模型中被拒绝。
- 来源设置保留 Codex／终端；移除普通应用／Safari 设置入口，明确 ChatGPT 内部任务尚未接入。旧扩展打包资源仍保留，正式 App 不消费 WebInbox。
- 31 项相关 Swift 测试通过，包含新增 2 项范围与兼容测试，以及 Codex 生命周期、CLI 命令、模型可靠性回归。日志：/tmp/anchor-dashboard-tests.log。
- 最终源码的 macOS Debug 和 iOS Simulator Debug 编译通过，均为 CODE_SIGNING_ALLOWED=NO。日志：/tmp/anchor-dashboard-mac-build.log、/tmp/anchor-dashboard-ios-build.log。
- git diff --check 通过。本轮未启动 GUI App，未重复 UI 自动化、实际手机同步或签名发行验证；未访问或修改生产配对凭据。未新增 ChatGPT／其他 AI 应用接入，不声称已有自动卡顿识别。

## 2026-10-02：核心使用流程最终回归

### 提交版本核对与更正

- 实际提交记录指向 `../Build/Submission-v4/Anchor-source-submission-v4-20261001.zip`，SHA256 为 `e8ed55d1f6a4e4c8256fa58792a53eb70480abd383e733c58b7b2763abd10005`，本次未修改此文件或比赛提交。
- v4 内包含 CodexAutoAssociation 和自动扫描代码，并非只有页面；原验证未覆盖所有实际触发边界。旧规则排除单关键词和投锚超过 30 分钟的新会话。
- 本机 `/Applications/ChatGPT.app` 的 CFBundleIdentifier 是 `com.openai.codex`，版本 `26.928.40906`。此前“ChatGPT 内部任务未接入”的笼统描述不准确：本地 Codex 格式任务属于现有接入，普通聊天不应一并声称已支持。

### 实现与证据

- 修复单关键词／长时间锚点匹配、手动与自动绑定跨任务重启恢复及终端结束事件归属。后续用户收紧了离开规则，见文末长时间中断验证。新增显式“暂时离开”入口。
- **220 项 Swift 测试通过**：155 Core、37 Transport、21 MacFeatures、7 IOSFeatures。日志 `/tmp/anchor-workflow-full-tests.log`。
- 新增完整流程测试使用两个独立持久仓库、生产 LinkedSessionRepository、MacSourceSetupModel 文件扫描、CodexSessionBinder 和 CodexLifecycleFileSource，验证投锚／记录、自动发现、跨任务恢复、状态回传、返航摘要、结束、双端归档及重新读取历史。事件传输在该测试中使用内存转发，不冒充物理设备测试。
- 单独启用真实 Bonjour 测试：从本机近期实际 Codex 日志提取一组开始／完成事件，仅保留时间戳、事件类型和 turn ID；经真实 loopback Bonjour 配对、断线、事件积压、重连同步到返航摘要。输入是实际事件重放，不代表现场发起了新 AI 请求，也未复制提示正文。
- **2 项 iOS UI 测试通过**：暂时离开 → 返航四卡 → Back 继续；最终确认结束 → 重启 → 历史详情。使用 ANCHOR_UI_TESTING=1、独立存储、内存配对。结果 `/tmp/anchor-core-workflow-ios.xcresult`。
- 原生 Mac 隔离生命周期脚本通过：启动、开始／完成、中断、重启游标、迟到和重复事件；记录目录 `/tmp/anchor-mac-local-e2e.O5zApB`。测试实例由脚本持有 PID 并关闭，没有使用生产凭据或会话。
- macOS Debug 最终构建通过；iOS UI 测试构建通过。最终 iOS 增量构建记录 `/tmp/anchor-core-workflow-ios-final.log`。均关闭签名，不代替发行安装验证。
- 尚需真机验收：手机与 Mac 的系统权限、同网配对、蓝牙实际距离、后台／休眠恢复，以及用户真实内容在关键词匹配中的命中情况。首次文件夹授权和终端 Shell 接入仍需按系统流程完成。

## 2026-10-02：长时间中断、竖屏返航与蓝牙采样修复

以下记录为上一轮验证；其中 10 分钟默认值已被后续用户明确指定的 5 分钟覆盖。

- 用户最新规则：办公室内短暂走动继续工作；不做 Wi-Fi RSSI 采样。已有认证连接持续中断 10 分钟才进入自动交接／离开。单独 BLE 断开或信号变弱且 Wi-Fi 通道仍连通，不触发离开；不足 10 分钟的失联重连不触发返航。手动“暂时离开”立即生效。
- 返航由认证重连或明确的手动返回触发，横屏／近场读数本身不触发。四卡摘要竖屏可用；前台每次返航一次系统触感，Back 后才出现可关闭的横屏提示。
- BLE 已连接后通过 readRSSI 持续采样，信任认证前不把候选设备距离当作当前 Mac；加入三样本确认、强弱阈值滞回、失效读数／12 秒过期清理、断开时取消采样。RSSI 用于近场指示，不单独决定离开。
- 新的 awaySince 可选操作字段和 awayStartedAt 会话字段保存失联开始时间，使返航摘要包含 10 分钟确认期的变化；快照按真正创建时间记录。旧的 presence 操作仍可解码。重连回调可补算被 iOS 暂停的计时器，但不宣称能补出系统从未交付的断连信号。
- **228 项 Swift 测试通过**：160 Core、40 Transport、21 MacFeatures、7 IOSFeatures。覆盖 599 秒／600 秒／20 分钟断连、Wi-Fi 保持连通、转屏不返航、未配对／权限异常、摘要完整时间范围、自动重连模型链路、一次性触感标记、旧事件兼容及 RSSI 过滤。日志：`/tmp/anchor-return-tests-verified.log`。
- 本次全量测试启用了实际本机日志两条生命周期事件的 Bonjour 回放：`ANCHOR_REAL_CODEX_ROLLOUT=/tmp/anchor-real-lifecycle-sample.jsonl`。该数据仅含类型、时间与 turn ID；测试通过，不代表真实无线走动验收。
- **1 项 iOS UI 流程测试通过**：暂时离开 → 横屏仍保持离开 → 竖屏手动返航 → 四卡 → Back → 横屏提示 → 转屏后提示消失。只用隔离存储与内存配对，测试退出已终止其 App。结果：`/tmp/anchor-return-review-ios.xcresult`；截图：`../Build/Previews/Return-20261002/`。截图是模拟器实际渲染，任务文字由 UI 测试输入，没有注入虚构任务进度。
- iOS 测试构建与 macOS 构建通过；macOS 日志 `/tmp/anchor-return-review-mac.log`。生产数据边界脚本、git diff --check 通过。未启动新的 Mac GUI 进程。
- 尚需真机验收：真实 BLE RSSI 阈值、无线离开／重连、iPhone 触感，以及锁屏／后台／Mac 休眠。iOS 不允许自动把后台 App 强行带到前台；本次没有新增后台通知或提示音。断连只能作为长时间中断的近似证据，不能识别人离开和 Mac 关机的区别。

## 2026-10-02：5 分钟、独立蓝牙通道与返航弹簧动效

- 按用户明确要求将默认失联确认门槛改为 300 秒；保留 3 秒交接和手动离开立即生效。任一已认证通道在线即保持工作，只有蓝牙也可独立支持工作／离开／返航。修复网络不可用时单独 BLE failed 被掩盖为 unavailable 的汇总状态。
- BLE 近场输出离散 near／far；连续 3 个明确样本确认方向，中间滞回区保留此前结果，缺失／过期证据为 unknown。新增中间区间、噪声打断和方向反转测试，无线阈值仍需真机校准。
- 返航四卡以 scale 0.92、向下 22pt、spring(duration: 0.36, bounce: 0.26) 弹入，卡间 35ms；入口只消费一次模型的返航展示标记，与一次触感同步。转屏、子弹层返回及摘要数据刷新不重复弹入。宿主取消返航时的整页上滑，避免与卡片动效叠加。系统或 App 减少动态效果时用 160ms 淡入。
- **231 项 Swift 测试通过**：161 Core、42 Transport、21 MacFeatures、7 IOSFeatures。覆盖 299／300／301 秒、蓝牙独立工作、蓝牙唯一通道 disconnected／failed 后恢复、RSSI 离散状态。蓝牙通道测试使用真实 AnchorBonjourClient 汇总逻辑与模拟的 BLE 连接回调，未启动 Bonjour，不冒充物理 BLE 测试。实际本机 Codex 两事件的 Bonjour 回放也通过。日志 `/tmp/anchor-five-minute-tests.log`。
- **2 项 iOS UI 流程测试通过**：常规动效、减少动态效果；都验证暂时离开、转屏不返航、竖屏摘要、Back 和横屏提示。结果 `/tmp/anchor-return-spring-ios.xcresult`，日志 `/tmp/anchor-return-spring-ios.log`。测试 App 使用隔离存储／内存配对，并在结束时终止。
- 已录制模拟器实际画面并提取入场阶段帧检查；5 秒预览 `../Build/Previews/Return-spring-20261002/return-card-spring-preview.mp4`，包含进入返航摘要与返回工作区。录制进程已结束。视频不验证实体触感。
- iOS 测试构建、macOS 构建通过；Mac 构建日志 `/tmp/anchor-five-minute-mac.log`。未启动新的 Mac GUI App。git diff --check 与源码导出中的生产数据边界检查通过。

## 2026-10-02：返航数据链路与有内容的页面

### 数据与行为

- `ReturnReviewContent` 从当前真实投影派生投锚上下文、离开时长、任务状态统计及查看顺序。变化列表使用 `ReturnSummary`，当前进展使用任务最新状态；两者分别回答“离开时发生了什么”和“现在怎么样”。
- 新增 `ReturnDataJourneyTests`：两个持久仓库通过生产 `LinkedSessionRepository` 传输，手机先投锚并离开，Mac 在断线期间收到七个不同状态任务，手机先打开空摘要，再重连补到数据。断线和收包由测试传输控制；验证迟到内容进入已打开页面、重复回放去重、读取持久仓库恢复、返回后两端仍保留任务及投锚记录，以及补数不重复触感标记。
- 回归样例包含两个完成、一个运行中、一个明确失败、一次主动中断、一个断连、一个排队任务。过滤后的返航事件统计排除旧环境活动，并且不把主动中断计为失败。
- 已修复真实交互问题：任务 ID 与 sheet 展示状态分开更新，首次点“下一步”可能打开空内容；改为随 sheet 原子传入所选任务。详情保持选中的任务身份，实时刷新不会把详情替换成另一个任务。
- 首卡支持投锚记录全文；变化入口支持完整标题、详情、来源和时间；状态统计有图标与文字，大字号使用两列；下一步优先查看明确失败及需要留意的任务。没有记录或 Mac 离线时明确说明状态。保留用户确认的四卡骨架、弹簧入场及返回顺序。

### 验证与隔离

- **236 项 Swift 测试通过**：162 Core、43 Transport、21 MacFeatures、10 IOSFeatures。日志 `/tmp/anchor-populated-all-tests.log`。其中真实本机 Codex 生命周期样本的 loopback Bonjour 回放已启用并通过；不把此结果视作手机无线实测。
- macOS Debug 构建通过，日志 `/tmp/anchor-populated-mac-build.log`；iOS 在 UI 测试中完成构建，均关闭签名。
- **5 项不同 iOS UI 流程通过**：有数据的标准字号与 Accessibility XXXL、无远端任务记录的手动返航、减少动态效果、最终确认归档后重启读取历史。有数据流程读取记录全文、全部变化、校验状态计数、打开对应失败任务详情、返回工作区。最终两项数据 UI 测试 2 passed／0 skipped：`/tmp/anchor-return-review-complete/review.xcresult`；三项既有流程：`/tmp/anchor-return-data-regression.xcresult`。
- 已逐张检查四卡、长标题、变化列表、任务详情、大字号和横屏截图，修复了大字号图标占位过窄。横屏改用全屏截图，避免应用元素截图在旋转后错误裁剪。最终截图目录 `../Build/Previews/Return-data-20261002/complete/`，可读名称以 `standard-`／`large-` 开头。
- 页面数据从测试目标生成的真实仓库文件导入两个保留 UUID 的 UI 隔离目录；正式 App 没有新增固定样例或导入入口。生成的仓库文件和两个注入目录会被清理；回归数据仅在测试源码中，截图保留为验证证据。生产数据边界检查禁止这次导出变量和保留 UUID 进入正式源码。
- 可复现命令：先在指定模拟器安装 Debug App，再执行 `python3 scripts/validation/ios-populated-return.py --device SIMULATOR_UUID`。脚本生成临时事件仓库、运行两项 UI 测试，要求 2 passed／0 skipped，结束或失败后清理它拥有的目录，保留日志和 xcresult。清理覆盖 Xcode 重装后迁移到的新沙盒路径；本轮已确认临时仓库及当前模拟器中的两个保留 UUID 目录均不存在，测试 App 已退出。
- 初轮视觉测试找到并修复了 sheet 空内容；最大字号测试改为先把点击中心滚到固定 Back 上方；横屏截图等待系统转屏动画结束，避免截取旋转中间帧。一次 Xcode 失败诊断收集超时，后续关闭冗长的 sysdiagnose 收集，保留测试截图与断言结果。
- 本轮覆盖软件链路与模拟器 UI；实体 iPhone 的无线重连、后台唤醒和触感仍属于真机验收范围。
