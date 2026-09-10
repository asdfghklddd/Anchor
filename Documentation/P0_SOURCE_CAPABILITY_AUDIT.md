# P0 来源能力核查：首轮只读取证

日期：2026-09-04。状态：**部分完成，不满足 P0 退出标准**。

最新进展：Codex 已从首轮只读诊断推进到正式 Mac App 文件源、真实 rollout、重启／轮转／故障恢复、任务历史边界及 `turn_aborted → interrupted` 验收；当前全量 127 项测试，Debug 与优化 Release-validation 构建通过，另有 600 Run／1200 Event 的 Debug 和优化长稳回归。Mac Codex 本地 MVP 已进入用户验收。Claude Code 因无账号尚未进行受控实测。首轮记录与后续验证分开保留，不把 Mac-only 通过等同于完整 P0/P2 通过。

对应计划：`ANCHOR_IMPLEMENTATION_PLAN.md` 的 P0、R04/R05/R09/R13/R15。

范围澄清（用户后续确认，D09）：此前“本地 ChatGPT App”指的就是当前 `com.openai.codex` 应用。当前核心范围为 Codex 与 Claude Code，不增加独立 ChatGPT 桌面产品；下文保留安装位置的原始探测事实，但不再将其当作缺失能力或 P0 阻碍。Safari 长回复仍按原计划执行。

## 1. 本轮结论

1. 本机 `/Applications/ChatGPT.app` 的 bundle ID 是 `com.openai.codex`，包含 Codex CLI；不能凭应用文件名证明独立 ChatGPT 桌面端已被验证。
2. 当前 Anchor 会话的真实 Codex JSONL 记录含稳定会话身份、项目元数据和每轮开始／完成／中断标识。这支持“同会话下多个 Run”的数据设计，不必仅依赖窗口文本猜测。
3. 当前运行的桌面后端没有显式监听参数，默认控制 socket 的只读版本查询失败。没有启动新 daemon、代理连接、截取现有 stdio 或修改配置；外部实时订阅能力仍未验证。
4. Claude Code 2.1.220 已安装，帮助中有流式输出和 hook 事件选项；本轮进程快照未发现运行中的 Claude Code。尚未产生新的受控回合，不能将官方文档或旧历史当成本机 hooks 成功证据。
5. 尚未使用 AX/OCR，尚未验证正式 Anchor sandbox 读取权限、后台监听、并行会话、断点恢复或双设备传输。A01–A20 本轮均不勾为整体通过。

## 2. 环境与 Git 边界

| 项目 | 本轮读数 |
| --- | --- |
| macOS | 26.5.2，build 25F84 |
| 桌面应用 | `/Applications/ChatGPT.app`，`com.openai.codex`，26.901.20858 |
| 内嵌 CLI | `codex-cli 0.153.0-alpha.5` |
| Claude CLI | `/Users/andywang/.local/bin/claude`，2.1.220 |
| Claude URL Handler | `com.anthropic.claude-code-url-handler`；只是 URL 入口，不能算完整桌面产品 |
| 独立 ChatGPT | `/Applications`、用户 Applications 目录和 Spotlight bundle 查询未发现；检索阴性不是全盘不存在的保证 |
| 工作副本 | `/Users/andywang/worktrees/Anchor-implementation-plan`，`codex/anchor-implementation-plan` |
| 起始提交 | `254ac981dd0bdb0aa494be12bb288b795dbf5399`，已推送的计划文档提交 |
| 正式 main | 查询确认仍为 `dbc9bfe1546e8926eec8770a043cd9a701c05e7e`，开放 PR 查询为空 |

GitHub main 查询第一次出现 EOF，重试读取成功；未改网络配置。原共享仓库的 `origin/HEAD` 异常没有在本轮修复。只在干净独立副本记录 P0 结果，不修改桌面旧分支的业务代码。

本轮没有启动付费模型测试，没有配置 hooks，没有改通知、登录状态、权限开关、VPN 或 Codex 控制链路；没有提交／推送本轮新增结果。

## 3. 证据等级与能力表

- **真实记录**：从限定的实际会话记录取到结构字段，不代表实时监听已成立。
- **本机协议**：由已安装 CLI 输出的 schema／help 支持，不代表连接和执行测试已成功。
- **文档候选**：官方说明存在该机制，本机版本与具体运行方式仍需验证。
- **未验证**：没有足够证据，不能在产品中伪装支持。

| 能力 | Codex 桌面端 | Claude Code |
| --- | --- | --- |
| 产品身份 | bundle、版本、进程父子关系已核实；用户确认就是所指应用 | CLI 版本已核实；URL Handler 不当作执行端 |
| 会话与项目身份 | 当前 Anchor 会话元数据匹配 | 官方 hooks 有会话及 cwd 字段，本轮未实测 |
| 每轮开始 | 真实 `task_started`＋`turn_id` | `UserPromptSubmit` 文档候选 |
| 每轮完成 | 真实 `task_complete`＋同一 `turn_id` | `Stop` 文档候选，不得忽略后续 hook 续跑及后台任务 |
| 中断 | 记录窗口中发现 `turn_aborted` | 未进行受控中断实验 |
| 失败 | 本机协议包含失败终态；未主动制造故障 | `StopFailure` 文档候选，本轮未触发 |
| 等待输入／批准 | 本机 schema 有 thread/turn scoped 请求；实时获取未验证 | `PermissionRequest` 文档候选，本轮未触发 |
| 同会话继续 | 同一会话中多组不同执行 ID 的开始／完成记录 | 恢复／继续参数存在，本轮未实测 |
| 多会话、后台、重启恢复 | 未做本轮受控实验 | 未做本轮受控实验 |
| 正式 Anchor 接入 | 未实现本轮来源适配；sandbox 权限待验 | 未实现本轮来源适配 |

## 4. Codex 实际记录与接入限制

### 4.1 最小事件证据

只检查本次 Anchor 对应 rollout 的元数据与最后 3000 条序列化记录，输出白名单事件类型、字段名、时间和本地别名；没有把正文、工具参数或返回内容送入报告。单条超过 2 MiB 的记录跳过；尾部截断窗口不用于推算全会话完整性。

取证时读数：30 个 `task_started`、29 个 `task_complete`、1 个 `turn_aborted`，JSON 解析错误计数为 0。窗口中的第一条完成可能没有对应开始，当前进行中的执行也可能尚未结束，因此不能把这些数量相减当作失败数。

同一会话的连续片段，时间为 UTC：

| 执行别名 | 事件 | 时间 |
| --- | --- | --- |
| run-29 | task_started | 2026-09-04T02:12:48.163Z |
| run-29 | task_complete | 2026-09-04T02:21:21.242Z |
| run-30 | task_started | 2026-09-04T02:40:13.064Z |
| run-30 | task_complete | 2026-09-04T02:44:15.513Z |
| run-31 | task_started | 2026-09-04T06:12:59.403Z |

别名仅用于这份脱敏样本，不是产品稳定 ID。机器可读摘要见 `evidence/p0-2026-09-04-source-metadata.json`。原始 rollout 不复制到项目或 GitHub。

会话创建元数据记录的是早期 CLI 0.149.0-alpha.4.1、source 为 `vscode`；这些是创建时数据，不能覆盖本轮从应用包和可执行文件取得的当前版本／运行身份。

### 4.2 本机 schema 与传输

运行已安装 CLI 的 `app-server generate-json-schema`，仅生成临时诊断文件到 `/tmp/anchor-p0-schema.g7R4oJ`，没有启动模型或服务器。

- `TurnCompletedNotification` 含 `threadId` 与 `turn`；共享 `TurnStatus` 枚举含 `completed/interrupted/failed/inProgress`。共享枚举允许值不代表 completed 通知应该以 inProgress 结束，需遵循运行语义。
- `ThreadStatusChangedNotification` 含 `threadId/status`。
- `ToolRequestUserInputParams` 含 `threadId/turnId/itemId/isBlocking/questions`。
- `CommandExecutionRequestApprovalParams` 含 `threadId/turnId/itemId/startedAtMs`。

这些证明当前 CLI 协议具备必要身份与状态字段；不证明另一个进程能旁听当前 Desktop。

只读 `codex app-server daemon version` 返回默认 `app-server-control.sock` 不存在。进程检查发现桌面子进程运行 app-server，未提供显式 `--listen` 参数；本轮没有看到可命名的控制监听 socket。结论仅限于“默认控制入口本轮不可用”，不能扩大成“所有接入方式都不存在”。

后续接入顺序建议：

1. 先确认是否存在受支持、不会接管桌面会话的观察接口。
2. 如继续验证本地记录，使用增量游标、文件身份、去重和重启恢复；完成事件缺失时显示未知，而不是按超时自动完成。
3. 在正式 Anchor 权限环境验证可读性。终端能读文件不代表 sandbox 内的 Anchor 可以读。
4. 记录格式属于需版本化回归的实现依赖；未完成这些步骤前，不能称为已上线的稳定适配器。

### 4.3 最小重现命令

设置 `ANCHOR_P0_ROLLOUT` 为用户选择的 Anchor 会话文件后，仅投影结构字段：

```sh
tail -n 3000 "$ANCHOR_P0_ROLLOUT" | jq -c '
  select(.type == "event_msg")
  | select(.payload.type == "task_started"
        or .payload.type == "task_complete"
        or .payload.type == "turn_aborted")
  | {at: .timestamp, event: .payload.type, turnID: .payload.turn_id}
'
```

此命令供本地核对，会显示真实执行 ID；公开样本必须替换为一致别名。输出可随新执行变化，不应要求重跑仍有相同计数。它不是生产采集器，不处理尾部半条 JSON、轮转、权限或跨版本兼容。

## 5. Claude Code：可进入受控实验，但本轮没有假装通过

本机帮助明确列出 `--output-format=stream-json`、`--include-hook-events`、`--include-partial-messages`、`--resume` 和 `--session-id`。这是参数存在的证据，不是成功捕获运行事件的证据。

用户级 settings 的 `hooks` 事件键为空；只检查键名，不输出配置值。未检查并否定所有项目级／管理级 hooks，不能据此全局宣称“没有 hooks”。存在本地历史文件，但未读取其他项目的对话，未用旧记录代替当前版本测试。

下一次受控实验应使用专用空目录、无私密输入、少量测试回合、最少工具权限，以及仅对该测试会话生效的事件配置。若要安装观察 hook，应只提取 `session_id`、事件类型、时间、必要状态及安全上下文，不原样落盘 prompt、tool_input 或 last_assistant_message。观察器不得返回批准／拒绝决定或延长来源执行。

该实验会实际启动模型会话，可能消耗账户额度；临时事件配置、实验输入及影响范围需在执行前明确。本轮未执行。

## 6. 已澄清的产品范围与下一步

用户已确认：此前“本地 ChatGPT App”就是当前 bundle ID 为 `com.openai.codex` 的应用。因此不再增加独立 ChatGPT 桌面端适配，也不因没有该独立产品而阻塞 P0；Safari Web 对话范围保持不变。

技术下一步（D10）：基于已有 Codex 身份与生命周期证据进入 P1，建立任务／子任务／执行／事件及归属边界、兼容迁移测试；并继续验证 Codex 正式进程权限、后台观察与恢复，随后完成正式 Mac→iPhone 闭环。Claude 先保留适配契约、解析与模拟测试，真实受控回合待有可用账号后补验；不要求用户现在注册或付费。

## 7. 官方参考与证据范围

- [OpenAI app-server 文档](https://learn.chatgpt.com/docs/app-server)：描述 thread/turn 及状态通知。本轮另用本机生成 schema 核实字段；文档不等于当前桌面外部订阅成功。
- [Claude Code hooks](https://code.claude.com/docs/en/hooks)：描述 UserPromptSubmit、Stop、StopFailure、PermissionRequest 等机制。它们是后续实验候选，不能将 Stop 一律映射为整个目标完成，也不能从收到权限事件推断用户已经批准。

本报告所有“真实记录”和“本机协议”判断来自本轮本地检查；外部参考仅用于解释候选机制。没有生产接入、后台准确率或双设备延迟的测量结论。

## 8. 第二轮：Codex 增量诊断与 Claude 认证阻碍

### 8.1 Claude Code 前置检查

- 本机版本仍为 2.1.220。
- `claude auth status` 返回 `loggedIn:false / authMethod:none / apiProvider:firstParty`；输出仅保留认证状态，不包含账号或凭据。
- 当前进程环境及用户级 settings 中，API key、auth token、base URL、Bedrock／Vertex 启用项均未配置，亦没有 apiKeyHelper；没有扫描或挪用其他应用的凭据。
- 因此未发起模型请求，未声称 hooks 实测成功，未改全局配置。Claude 真实受控回合需要可用认证；按后续 D10，该验证延后，不再是其他施工的前置条件。
- 隔离试验准备目录为 `/tmp/anchor-p0-claude.WORhkY`，本轮未在其中启动会话。

后续试验分开验收：先使用 safe mode、禁用工具与 MCP、无隐私输入验证流式回合；safe mode 会禁用自定义 hooks，所以该模式的成功不能用于证明 hooks 成功。真正 hook 观察需要另一个仅限测试会话的配置实验。认证与参数依据 [Claude CLI reference](https://code.claude.com/docs/en/cli-reference)，运行结果须以实际取证为准。

### 8.2 Codex 只读诊断脚本

新增 `scripts/p0/codex-lifecycle-probe.mjs`，只打开用户明确选择的一个 rollout，并要求它的首条 session metadata 匹配预期会话 ID。不是正式适配器，不扫描所有会话，不修改来源文件，也不写用户配置。

- 白名单输出 `task_started/task_complete/turn_aborted`、时间、稳定哈希事件键与运行别名；不输出真实会话 ID、正文或工具参数。
- checkpoint 只保留文件身份、字节偏移、超长记录跳过状态和已见事件哈希，不持久保存半条原始 JSON。
- 末尾半条记录留待下次重读；超大记录有界跳过；重复生命周期事件去重。
- 检测到文件替换或当前文件短于已确认偏移时返回 resetRequired，不自动换绑会话。
- 默认单次最多读取 128 MiB、单行上限 2 MiB、最多保留 10000 个事件键，均为诊断保护，不是产品保留政策。

测试命令：

```sh
node --test scripts/p0/codex-lifecycle-probe.test.mjs
```

本机使用应用内 Node 24.19.0 执行，7/7 通过：多轮分辨与隐私输出、checkpoint 重读与重复事件、半条记录、跨会话拒绝、截断／替换、损坏与超大记录、超长半条记录跨批次恢复。测试仅在 `anchor-p0-probe-test-*` 临时目录创建合成样本，不覆盖用户来源文件。

### 8.3 真实文件验证及限制

2026-09-04T12:42:09.141Z 仅对当前 Anchor 会话读取 76,035,016 字节：识别 54 个开始、46 个完成、7 个中断、54 个不同运行；跳过 4 条超大记录，解析错误 0。随后将 checkpoint 序列化／还原并再次读取，新增生命周期事件为 0，未重复报出旧事件。机器证据见 `evidence/p0-2026-09-04-incremental-probe.json`。

这不是完整性或实时延迟证明：超大记录被跳过；未知类型仍被忽略；没有被动监听 daemon；同 inode 文件被重写并在下次检查前长回原长度的情形、非追加式修改、正式 sandbox 权限、跨设备传输仍未覆盖。checkpoint 恢复测试不等于应用进程重启验收。只有 A01/A04/A08/A09 的局部诊断证据，完整验收项仍未通过。

本轮成果只保存在本地，尚未提交／推送。按后续 D10，下一步推进 Codex 优先的 P1 与双设备闭环；Claude 实测待有可用账号后再执行少量隔离回合。不通过读取旧对话或伪造 hook 输入把真实验证缺口算作已解决。

## 9. 无 Claude 账号时的执行边界（D10）

- 用户已确认先推进 Codex，不需为 Anchor 当前施工注册或购买 Claude 服务。
- 下一交付阶段为 P1 领域模型与兼容迁移；第一条真实端到端链路采用当前 `com.openai.codex` 应用。诊断脚本不是正式适配器，权限与后台恢复仍需实测。
- Claude 解析与模拟测试属于后续待做项，本次文档调整不代表它们已实现。将来即使模拟通过，也只证明解析／状态归约，不证明真实 hooks 或双设备接入。
- P0 仍为部分完成；P2 允许单独交付 Codex 子里程碑。Claude 仍在最终范围内，完整来源验收待真实证据补齐后再通过。
- 本次仅同步计划与核查报告，不改历史 JSON 证据、业务代码、认证或网络配置；未提交／推送。

### 9.1 Mac 正式 target 构建复核（2026-09-06）

- Desktop 正式目录 `/Users/andywang/Desktop/Anchor` 的 `Anchor macOS` arm64 Debug 构建成功，使用 `CODE_SIGNING_ALLOWED=NO`。
- 2026-09-07 复核：Desktop AnchorKit 包测试通过 59 项、6 个套件；独立实现目录通过 82 项、10 个套件。Desktop `Anchor macOS` arm64 Debug 无签名构建成功。两份目录存在既存协作差异，结果分别记录。
- 确认后的来源 session→Task/WorkItem 关联现可持久化并在协调器重启时恢复；未确认映射会被拒绝。正式 Mac 文件选择和安全作用域授权仍待实现。
- 本证据只证明编译与测试，不证明真实 Codex 账号、权限、后台采集或任务归属绑定已经完成。

### 9.2 Codex 确认绑定实现证据（2026-09-07）

- Mac 设置页已实现 JSONL 文件选择与安全作用域书签；确认回调创建当前 Task/WorkItem 关联并运行中注册 Codex 来源。
- 关联恢复、未确认映射拒绝、运行中新增来源、旧事件时间边界均有自动测试；独立实现目录全量 84 项通过，正式 target 构建和临时 App 启动通过。
- 真实文件面板点击、书签跨实际进程重启及持续文件变化仍未实测，本项不构成完整生产接入证明。

### 9.3 Mac-only 构建与测试复核（2026-09-09）

- 独立正式实现目录的 `Anchor macOS` arm64 Debug 无签名构建再次成功，临时 App 启动验证通过；未修改 Demo target。
- 独立 AnchorKit 全量测试复跑通过 84 项、10 个套件；Desktop 正式目录通过 59 项、6 个套件，且 `Anchor macOS` arm64 Debug 构建成功。一次并发配对超时重跑通过，当前没有稳定复现失败。
- 这些证据只覆盖 Mac 本地构建、启动、模型／解析／持久化／协调器自动测试；真实文件面板点击、安全作用域跨重启、持续追加／替换和 iPhone 链路仍待用户在 Mac 上完成手动确认。

### 9.4 无 iPhone 的真实 Mac App Codex E2E（2026-09-09）

- Debug-only 隔离模式使用临时数据目录、临时设备 ID 和指定 JSONL，避免无签名构建阻塞真实 Keychain，也不读写用户正式 Anchor 数据。Release 不读取这些验证环境变量。
- 真实构建 App 在空 JSONL 下建立 1 个 Task、1 个 Codex WorkItem 和 1 个来源级 Association，且保持 0 Run；随后捕获 `task_started` 与 `task_complete`，同一 source session 归并为 completed Run。
- 结束并重新启动真实 App 后，磁盘 checkpoint 阻止旧事件重放；追加第二个 turn 后新增 running Run。最终为 1 Task、1 WorkItem、2 Runs、1 Association、1 checkpoint。
- E2E 发现并修复来源 UUID 冲突、Association 跨来源串线，以及 SafariServices 回调 actor isolation 崩溃。修复后的 E2E 未产生新 crash report。
- `CodexLifecycleFileSource` 的自动测试现覆盖追加、截断、原子替换、checkpoint 恢复和 checkpoint 损坏保护；来源关联测试还覆盖旧版缺失来源 ID 时的安全拒绝；AnchorKit 92 项、10 个套件通过，正式 macOS Debug target 构建通过。
- 可重复命令为 `scripts/validation/mac-codex-local-e2e.sh <Anchor macOS.app>`；结构化证据见 `evidence/p1-2026-09-09-mac-local-codex-e2e.json`。该 headless 脚本本身不替代真实 NSOpenPanel；后续第 9.5 节已补无签名 Debug 的真实面板与书签恢复，provisioned Sandbox 和真实用户文件长期观察仍待验证。

### 9.5 NSOpenPanel、书签恢复与签名边界（2026-09-09）

- 在不读取真实 Codex 内容的隔离环境中，正式 macOS target 的无签名 Debug App 实际打开系统 `NSOpenPanel` 并选择 JSONL；UI 显示文件已连接，随后生成来源级 Association 和 running Run。
- 结束并重新启动 App 后没有再次选择文件，独立 `UserDefaults` suite 中的书签成功恢复；重启后追加完成事件，同一 Run 转为 completed，证明恢复的不只是 UI 文件名而是实际观察器。
- checkpoint 原先以完整文件路径为键，现改为固定 Codex source UUID；单元测试与 headless E2E 均断言 checkpoint 文件不包含所选 JSONL 路径。书签自身仍由 macOS bookmark data 持久化，这是跨进程恢复所需的授权凭据。
- 本机没有 Anchor App 与 Safari 扩展所需 provisioning profile：Xcode 自动签名失败；ad-hoc 签名可通过静态校验但未完成 App Sandbox 初始化。因此真实面板与书签代码路径已验证，provisioned Sandbox 的安全作用域执法仍未验证，不能把无签名结果表述为正式签名包通过。
- 结构化证据见 `evidence/p1-2026-09-09-mac-codex-bookmark-ui-e2e.json`。下一步是不依赖 iPhone 的真实 Codex 文件受控事件与较长时间后台／文件轮转观察。

### 9.6 60 轮持续采集与故障注入（2026-09-09）

- `scripts/validation/mac-codex-soak-e2e.sh` 驱动真实构建 App 连续处理 60 轮／120 个生命周期事件，并在第 20、40 轮及最终重启 App。
- 第 30 轮执行 JSONL 原子替换，第 45 轮执行原地截断；最终 60 个 Run 和 60 个 source session ID 均唯一，全部 completed，没有跨来源污染或重启重放。
- 最高 RSS 为 138752 KiB；checkpoint 仅 188 bytes、只有固定来源 UUID 键且不含所选路径。本轮没有新 Anchor crash report。
- 结构化证据见 `evidence/p1-2026-09-09-mac-codex-soak-e2e.json`。这是约一分钟的合成负载回归，不替代真实 Codex 回合、数小时后台、Mac 睡眠唤醒或 Release 资源验证。

### 9.7 WorkItem 三维状态投影（2026-09-09）

- Run 现将执行、注意事项、结果分开持久化，旧记录缺少注意事项字段时兼容为空；`stale` 不映射为失败或完成。
- WorkItem 投影按稳定时间与 ID 排序，支持失败后重新活动、并发执行优先级和重启后一致读取；成功重试后历史失败不会继续污染当前注意事项。
- AnchorKit 99 项、11 个套件、正式 macOS Debug target、基础 App E2E 和 8 轮故障注入回归均通过；证据见 `evidence/p1-2026-09-09-work-item-state-projection.json`。
- 这不证明真实 Codex 能提供待输入／失败细粒度事件；Task 级汇总、正式 UI 和同步消费仍属于后续 P1/P2 工作。

### 9.8 Task 聚合与 Mac 诊断 UI（2026-09-09）

- Task 级投影现从 WorkItem 状态推导执行、注意事项和模型侧观测结果，同时保留独立的用户控制 lifecycle；模型执行完成不会自动结束整体 Task。
- 正式 Mac 来源页已消费该投影并每秒刷新；真实 Debug App 辅助功能树验证 running→completed 的 UI 更新及 App 重启恢复，另以隔离 fixture 验证 running、needs-input 与历史失败并存。
- AnchorKit 104 项、12 个套件、正式 macOS Debug target、基础 App E2E 和 8 轮故障注入回归均通过；证据见 `evidence/p1-2026-09-09-task-state-ui-e2e.json`。
- 当前 Codex JSONL 适配器仍只有开始／完成／中断证据；待输入和失败 UI 仅证明投影与显示能力，不代表真实来源已提供这些事件。

### 9.9 不可变 Event 与检查点确认顺序（2026-09-10）

- TaskRunStore 已持久化独立、隐私最小化 Event，并与 Run 投影原子提交；完成先到、迟到开始、重复投递、事件身份冲突、Task 时间边界、归档拒绝及缺失 Event 字段的旧存储均有自动测试。
- 一次 60 轮 Event 压力测试在第 11 轮暴露旧顺序：扫描器先把 checkpoint 推到文件末尾，下游 TaskRunStore 当时仍少一轮。残留 App 随后完成该轮，说明超时目录的最终状态不是永久丢失证据；但如果进程在该窗口退出，重启会越过未落库行，属于必须修复的耐久性缺口。
- 现在 Codex 源为每个完整行准备候选 checkpoint，并等待协调器显式确认；协调器先提交 SessionRepository，再原子提交 Event＋Run，最后才推进 checkpoint。未确认或持久化失败时，重新创建来源会从旧偏移重放；明确无效的跨 Session／越界事实才确认丢弃。
- 故障注入测试真实制造 TaskRunStore 文件替换失败，确认 checkpoint 未生成；修复路径并重建协调器后同一 Event 成功恢复。另有独立测试证明仅消费但不确认时，来源重启会重放同一行。
- 最终回归：AnchorKit 112 项／13 个套件、正式 macOS arm64 Debug 无签名构建、3 Run／5 Event 基础 E2E、8 Run／16 Event 快速 soak 和 60 Run／120 Event 完整 soak 全部通过。完整 soak 包含三次 App 重启、JSONL 原子替换与原地截断，所有 Run、来源会话和 Event ID 唯一，最终 checkpoint offset 与当前文件长度同为 3824。
- 机器证据见 `evidence/p1-2026-09-10-immutable-event-ack-e2e.json`。这些结果仍来自脱敏合成生命周期行，不替代真实 Codex 活动回合、provisioned Sandbox、iPhone 同步、数小时后台或睡眠唤醒验证。

### 9.10 Task 历史 schema 与 Event 版本（2026-09-10）

- TaskRunStore 当前写出 schema v2，Event 当前写出 protocol v1；旧文件缺失版本字段时按 v1 迁移，未知未来版本拒绝写入并保留原始字节。
- 旧历史第一次升级写入前会生成逐字节相同的 `.pre-v2.backup`；备份目标已有不同内容时迁移失败而不是覆盖。自动测试还从该备份重新创建 Store，确认 Task 与 WorkItem 可恢复。
- 首次备份实现使用了 Foundation 不支持的 `atomic + withoutOverwriting` 组合，针对性测试以 signal 5 失败；已改为同目录原子临时文件加不覆盖 move，并对并发出现的备份进行字节核对。修复后的 3 项迁移测试通过；后续真实来源验收加入 Mac 状态回归后，全量为 117 项／13 套件。
- 正式 macOS 构建、3／5 基础 E2E、8／16 快速 soak 及 60／120 完整 soak 均通过；最终落盘确认 `schemaVersion: 2` 且所有 Event 为 `version: 1`。
- 此策略不承诺旧二进制安全写回 v2 文件；发布／回滚时必须避免新旧版本交替使用同一数据目录。机器证据见 `evidence/p1-2026-09-10-task-history-schema-migration.json`。

### 9.11 当前 Codex rollout 的真实增量验收（2026-09-10）

- 正式 `Anchor macOS` 无签名 Debug App 在隔离数据根目录只读绑定当前 Anchor 对话的真实 Codex rollout；约 100 MiB 的既有内容先按当前 Task 开始时间建立边界，初始保持 0 Run／0 Event，没有把历史回合倒灌为当前任务。
- 随真实会话自然推进，App 先捕获一个完成和下一回合开始，后续又捕获一组完成／开始；最终形成 3 个不同来源会话的 3 Run／4 Event，事件接收延迟均小于 140 ms。重建并复用同一目录后数量保持 3／4，checkpoint 没有重放。
- 正式来源页辅助功能树确认真实文件名、1 WorkItem／3 Runs 及 running Task 投影同时显示。验证入口此前只完成后台绑定却显示未连接，现与用户选择／书签恢复共用同一连接方法，并有 Swift Testing 回归。
- 正式来源现每次最多读取 4 MiB，32-byte 分块测试覆盖跨批次完整行；后续当前／历史分层回归加入后，全量 124 项／13 套件和正式 arm64 Debug 构建通过。Event 与 checkpoint 仍不持久化 prompt、模型输出或所选文件路径。
- 结构化证据见 `evidence/p1-2026-09-10-real-codex-live-mac-e2e.json`。这将“真实 Codex 文件受控追加”从未验证推进为 Mac-only 通过，但不替代 provisioned Sandbox、iPhone 同步、Claude、数小时后台或睡眠唤醒验收。

### 9.12 当前任务、历史分层与生命周期边界（2026-09-10）

- TaskRunStore 现在分别返回唯一当前 Task 和归档历史；历史记录保留 Task、WorkItem、Run、Event 与三维投影。普通写入不能创建第二个前台 Task，用户会话创建边界才可显式切换。
- Session 完成会归档对应 Task，之后创建 Session 会生成新 Task；若 App 在新 Session 已保存、旧 Task 尚未归档时中断，重启同步以新会话开始时间封口旧 Task。迟到的更早会话不能覆盖新 Task，拒绝写入后原文件字节不变。
- 全量 AnchorKit 124 项／13 套件与正式 macOS arm64 Debug 构建通过。真实 Codex 目录重启保持 1 个当前 Task、3 Run／4 Event 且无重放，来源页可见 3 Runs 和 active/running 投影。
- 机器证据见 `evidence/p1-2026-09-10-task-current-history-boundary.json`。数据层历史分离已通过；当时未验收的 macOS 前台退出与 `turn_aborted` 专用 interrupted 语义已在第 9.13 节补齐，iPhone 历史消费和双设备新任务边界仍未验收。

### 9.13 Codex 中断与正式 Mac 当前任务退出（2026-09-10）

- Codex `turn_aborted` 现在通过可选的来源观测结果保留为 Task 层 `interrupted` Run／Event；legacy Process 仍使用 failed，旧 ExternalProcessEvent 缺少新字段时继续解码。参数化测试分别覆盖 completed 与 interrupted 终态。
- 正式 App 的合成 JSONL E2E 捕获 4 Run／6 Event，其中恰好 1 个 interrupted Run 与 1 条 interrupted Event；该流程同时覆盖 checkpoint 重启不重放、乱序和重复事件，App 日志为空且验证进程已退出。
- 正式 macOS 当前页与菜单入口不再把 completed/archived Session 当作当前工作；Demo 通过默认开关保持原场景。实际点击完成确认后，辅助功能树从 `mac.current.screen` 切到 `mac.empty.screen`，TaskRunStore 从 1 当前／0 历史切到 0 当前／1 历史；App 重启后仍为空当前页。
- 确认文案同步纠正，不再声称可恢复旧任务，明确之后继续同一对话会开始新 Task。全量 127 项／13 套件与正式 macOS arm64 Debug 构建通过；机器证据见 `evidence/p1-2026-09-10-codex-interruption-and-foreground-exit.json`。
- 以上是 Mac-only 证据；iPhone、双设备、provisioned Sandbox、数小时后台／睡眠唤醒及 Claude 仍未验收，不能据此将完整阶段标为通过。

### 9.14 600 轮持续采集、三次重启与文件轮转（2026-09-10）

- 正式无签名 Debug App 在隔离临时目录运行 1014.06 秒，连续接收 600 轮／1200 个生命周期事件；最终 600 个 Run、600 个 source session ID 和 1200 个 Event ID 分别唯一，全部 Run 为 completed。
- 第 200、400 轮及最终重启 App，第 300 轮原子替换源文件，第 450 轮原地截断；最终没有重放或丢失，checkpoint 不含源路径，App 的 stdout/stderr 均为空，验证结束后没有残留进程或本轮新增 crash report。
- 长运行 Debug 最大 RSS 为 298688 KiB；相同 600／1200 历史冷启动后，RSS 从 2 秒的 144896 KiB 到 10 秒的 154032 KiB，状态保持不变。该差异说明尚不能把长跑峰值直接定性为泄漏，但在 Release＋Instruments 分配画像完成前，资源表现不能算生产验收通过。
- 机器证据见 `evidence/p1-2026-09-10-mac-codex-600-turn-soak.json`。这是约 17 分钟的合成后台进程回归，不是数小时真实 Codex 使用，也未覆盖 provisioned Sandbox 或睡眠唤醒；远程控制期间主动避免让 Mac 睡眠以保护连接。

### 9.15 优化资源复核与本地 MVP 交接（2026-09-10）

- 优化验证包以 Release 优化级别构建，为隔离入口附加 `DEBUG` 条件；它验证优化代码路径，不冒充可分发签名包。600 Run／1200 Event 用时 866.73 秒，三次重启、原子替换和原地截断后仍完整且无重放。
- 长跑最大 RSS 337904 KiB；同一历史冷启动 2 秒／10 秒为 147232／146496 KiB，`vmmap` physical footprint 65.1M、峰值 119.3M。静态审查显示每个事件会复制、重放、排序并重新编码完整状态，因此确认存在随历史增长的分配压力，但现有证据不足以证明泄漏。
- Instruments 目标 Allocation attach 受本机 Developer Mode 关闭阻止；没有为此更改系统设置。对于 Anchor 定义的中小型任务，正确性、恢复和用户旅程已足以进入本地 MVP 验收；批量／增量持久化优化列为后续性能债。
- 本地启动器只运行正式 macOS target，使用临时 Task 和独立数据根。实际来源页及 `NSOpenPanel` 已复核：Anchor 定位到最新候选目录并显示候选文件名；公开 API 不可靠地预选现有文件，用户仍需点选该文件并点击 Open。检查后已取消面板并退出测试 App，没有授予新权限。
- 最终 AnchorKit 127 项／13 套件通过。机器证据见 `evidence/p1-2026-09-10-release-resource-and-mvp-handoff.json`；iPhone、Claude、Safari、provisioned Sandbox、睡眠唤醒和完整产品验收仍未完成。
