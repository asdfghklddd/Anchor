window.ANCHOR_MAP = {
  "version": "2026.10.02",
  "baseline": "3ed3e0c25e3734f94945c2b1a921b5c7e3cbe285",
  "repo": "https://github.com/asdfghklddd/Anchor",
  "pages": [
    {
      "id": "home",
      "title": "竖屏工作台",
      "platform": "iPhone",
      "kind": "主页面",
      "summary": "一眼查看所有托管任务和各会话的实际进展。",
      "entry": "启动应用；返航确认后；竖起手机。",
      "behavior": [
        "浅青背景、Anchors 图表、双列错落任务卡。",
        "任务颜色保持身份一致；第一条会话是主线，进度缺失显示虚线。",
        "点击任务卡进入该任务详情；底部锚按钮创建新任务。",
        "本地最新可读性修订：进度胶囊显示「未知」、0% 或实际百分比；截图已更新。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/PortraitDashboard.swift",
      "image": "ios-home.png",
      "imageAlt": "最新本地工作台：四个隔离任务展示未知、0%、63%、100%",
      "localRevision": true
    },
    {
      "id": "setup",
      "title": "创建锚点",
      "platform": "iPhone",
      "kind": "分段表单",
      "summary": "先明确目标、完成标准与计划，再开始托管。",
      "entry": "工作台底部圆形锚按钮；托管任务列表的新建入口。",
      "behavior": [
        "目标 → 完成标准 → 步骤 → 确认。",
        "支持照片、语音与键盘相关输入；权限状态单独反馈。",
        "关闭或旋转时保留本次 App 进程内的草稿；成功创建或主动丢弃后清空。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/AnchorSetupView.swift",
      "image": "ios-setup.png",
      "imageLabel": "创建表单 · 恢复草稿",
      "localRevision": true
    },
    {
      "id": "tasks",
      "title": "托管任务列表",
      "platform": "iPhone",
      "kind": "弹层",
      "summary": "在一个工作台管理多个独立任务。",
      "entry": "工作台「任务进程库」右侧数量入口；横屏任务库入口。",
      "behavior": [
        "每项提供编辑目标、投锚记录、结束工作。",
        "操作先确定任务身份，再打开对应编辑页面。",
        "完成一个任务保留其他托管任务。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/HostedTasksView.swift"
    },
    {
      "id": "detail",
      "title": "任务详情",
      "platform": "iPhone",
      "kind": "弹层",
      "summary": "目标、标准、步骤、来源状态和上下文聚合在一起。",
      "entry": "点击任一托管任务卡；个人中心的本次会话或近期记录。",
      "behavior": [
        "显示当前选择任务的详细信息与进程。",
        "「暂时离开」位于任务管理和结束工作上方。",
        "记录上下文、离开和最终完成是不同操作。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/ProfileDetailViews.swift",
      "image": "ios-detail.png"
    },
    {
      "id": "goal",
      "title": "编辑目标",
      "platform": "iPhone",
      "kind": "弹层",
      "summary": "维护已建立任务的目标和完成标准。",
      "entry": "托管任务列表 → 对应任务 → 编辑目标。",
      "behavior": [
        "修改归属于打开时选择的任务。",
        "通过正式命令保存并进入同步流程。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/ProcessViews.swift"
    },
    {
      "id": "note",
      "title": "投锚记录",
      "platform": "iPhone",
      "kind": "弹层",
      "summary": "把下一次继续工作需要的上下文留在这里。",
      "entry": "托管任务列表 → 投锚记录。",
      "behavior": [
        "保留已有记录；支持记录输入。",
        "保存期间防止重复提交，失败保留原文。",
        "本地保存成功后返回工作台，再后台同步。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/ProcessViews.swift",
      "image": "ios-note.png"
    },
    {
      "id": "process",
      "title": "进程详情",
      "platform": "iPhone",
      "kind": "详情",
      "summary": "查看来源上报的状态、说明与进展。",
      "entry": "相关通知；返航下一步；任务详情中的进程信息。",
      "behavior": [
        "状态来自 Codex / CLI 观测。",
        "等待输入与失败在原工具处理。",
        "Anchor 没有向外部工具作答或恢复执行的入口。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/ProcessViews.swift",
      "image": "ios-process.png"
    },
    {
      "id": "landscape",
      "title": "横屏 Ambient",
      "platform": "iPhone",
      "kind": "主页面",
      "summary": "让手机成为工作旁的一块状态副屏。",
      "entry": "正常工作时将手机横置。",
      "behavior": [
        "左侧约 55% 展示时钟、Focus 与图表；右侧任务卡独立滚动。",
        "大字号时切换为纵向分区。",
        "Focus 是任务开始后的经过分钟数。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/LandscapeAmbientDashboard.swift",
      "image": "ios-landscape.png",
      "imageAspect": "wide",
      "localRevision": true
    },
    {
      "id": "connections",
      "title": "设备连接",
      "platform": "iPhone",
      "kind": "原生弹层",
      "summary": "查看 Mac 连接状态，按需显示配对码。",
      "entry": "顶部连接入口；个人中心 → 连接。",
      "behavior": [
        "竖屏常规高度 400pt，横屏 260pt；大字号使用大弹层。",
        "按真实配对状态显示验证码；错误在卡片内解释。",
        "配对涉及局域网、蓝牙与签名权限，需实机验收。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/ConnectionSettingsView.swift"
    },
    {
      "id": "notifications",
      "title": "应用内通知",
      "platform": "iPhone",
      "kind": "弹层",
      "summary": "汇总可回看的进程变化。",
      "entry": "工作台右上角铃铛。",
      "behavior": [
        "关联进程的条目可打开详情。",
        "后台通知当前不可用。",
        "历史决策记录由当前看板策略过滤。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/ProcessViews.swift"
    },
    {
      "id": "layout",
      "title": "任务布局管理",
      "platform": "iPhone",
      "kind": "列表",
      "summary": "管理进程卡片的显示、顺序和尺寸。",
      "entry": "任务详情 → 任务管理；个人中心 → 任务管理。",
      "behavior": [
        "按已有管理表单调整可展示项。",
        "保留用户选择的排列与尺寸。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/AuxiliaryViews.swift"
    },
    {
      "id": "finish",
      "title": "确认完成",
      "platform": "iPhone",
      "kind": "确认弹层",
      "summary": "由人确认整体任务已经完成，并保留历史。",
      "entry": "托管任务列表或任务详情 → 结束工作。",
      "behavior": [
        "先检查摘要，再执行最终确认。",
        "所有关联进程完成不会替代用户确认。",
        "完成后详细历史可跨重启查看，其余托管任务保持。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/AuxiliaryViews.swift"
    },
    {
      "id": "handoff",
      "title": "离开交接",
      "platform": "iPhone",
      "kind": "全屏状态",
      "summary": "自动离开成立后的短暂交接。",
      "entry": "全部认证连接连续失联至少五分钟，且此前有过有效连接。",
      "behavior": [
        "自动流程保留约三秒交接阶段。",
        "有效连接恢复时交由状态机判断返航。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/AwayReturnViews.swift"
    },
    {
      "id": "away",
      "title": "离开状态",
      "platform": "iPhone",
      "kind": "全屏状态",
      "summary": "离开期间保留任务上下文和已知工作状态。",
      "entry": "任务详情主动暂时离开；自动交接结束。",
      "behavior": [
        "手动离开立即生效。",
        "不把普通旋转或单次 RSSI 变化当作返航。",
        "支持查看任务信息与应用内记录。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/AwayReturnViews.swift"
    },
    {
      "id": "return",
      "title": "返航摘要",
      "platform": "iPhone",
      "kind": "全屏状态",
      "summary": "四张卡帮你重新接回工作。",
      "entry": "离开后认证连接恢复；主动返回流程。",
      "behavior": [
        "四卡：当前任务与上次记录、离开期间变化、当前进展、你的下一步。",
        "卡片按 35ms 间隔弹入，并有一次成功触感；减少动态效果时淡入。",
        "迟到数据继续更新；点击返回成功后才恢复工作台并提示横屏。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/ReturnView.swift",
      "image": "ios-return.png"
    },
    {
      "id": "return-context",
      "title": "返航 · 上下文",
      "platform": "iPhone",
      "kind": "弹层",
      "summary": "完整阅读上次投锚记录。",
      "entry": "返航第一张卡 → 上次投锚记录。",
      "behavior": [
        "保留完整记录文本，长内容可滚动。",
        "关闭后回到同一次返航摘要。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/ReturnView.swift",
      "image": "ios-context.png"
    },
    {
      "id": "return-changes",
      "title": "返航 · 全部变化",
      "platform": "iPhone",
      "kind": "弹层",
      "summary": "查看离开期间发生的具体事件。",
      "entry": "返航变化卡 → 查看全部变化。",
      "behavior": [
        "按真实事件展示来源、时间和内容。",
        "重复回放的事件去重。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/ReturnView.swift",
      "image": "ios-changes.png"
    },
    {
      "id": "recovery",
      "title": "旧任务复核",
      "platform": "iPhone",
      "kind": "弹层",
      "summary": "再次打开长时间未更新的工作时先确认去向。",
      "entry": "已有会话需要恢复检查，且没有其他弹层或全屏流程。",
      "behavior": [
        "可继续当前任务、完成当前任务，或归档后开始新工作。",
        "入口以默认 24 小时的恢复复核间隔检查。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/StaleWorkspaceRecoveryView.swift"
    },
    {
      "id": "profile",
      "title": "个人中心",
      "platform": "iPhone",
      "kind": "主页面",
      "summary": "查看当前会话、历史记录与工作方式设置。",
      "entry": "工作台顶部头像。",
      "behavior": [
        "编辑本地头像与昵称；查看统计和当前会话。",
        "近期事件统一打开当前任务详情。",
        "连接、来源、iCloud、通知、隐私和辅助功能集中在下方。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/AuxiliaryViews.swift"
    },
    {
      "id": "account",
      "title": "个人资料",
      "platform": "iPhone",
      "kind": "弹层",
      "summary": "编辑设备上的头像和昵称。",
      "entry": "个人中心右上角。",
      "behavior": [
        "本地资料编辑，不代表在线账号系统。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/ProfileEditorView.swift"
    },
    {
      "id": "stats",
      "title": "统计详情",
      "platform": "iPhone",
      "kind": "弹层组",
      "summary": "专注、上下文与完成记录的三个详情入口。",
      "entry": "个人中心的三个统计项。",
      "behavior": [
        "专注当前按经过时间表达。",
        "上下文汇总记录和快照；完成项查看现有完成记录。",
        "统计含义以当前代码为准，不能推断为净专注时长。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/ProfileDetailViews.swift"
    },
    {
      "id": "history",
      "title": "工作历史",
      "platform": "iPhone",
      "kind": "列表",
      "summary": "重新找到已完成或归档的工作。",
      "entry": "个人中心 → 历史。",
      "behavior": [
        "选择历史任务进入详情。",
        "最终确认后的任务保留目标、步骤、进程与上下文。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/AuxiliaryViews.swift"
    },
    {
      "id": "history-detail",
      "title": "历史详情",
      "platform": "iPhone",
      "kind": "详情",
      "summary": "恢复一段工作的信息，而不是重新执行它。",
      "entry": "工作历史中选择任务。",
      "behavior": [
        "显示归档任务的详细内容。",
        "迟到事件不会让已归档任务重新变成活动任务。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/AuxiliaryViews.swift"
    },
    {
      "id": "sources",
      "title": "来源状态",
      "platform": "iPhone",
      "kind": "设置",
      "summary": "在手机查看已经接入的来源与最新状态。",
      "entry": "个人中心 → 来源。",
      "behavior": [
        "来源授权和 CLI 安装在 Mac 端完成。",
        "支持当前 Codex 本地生命周期日志和 CLI 命令契约。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/SettingsViews.swift"
    },
    {
      "id": "icloud",
      "title": "iCloud 状态",
      "platform": "iPhone",
      "kind": "说明弹层",
      "summary": "如实显示当前云同步配置与状态。",
      "entry": "个人中心 → iCloud。",
      "behavior": [
        "已实现可选 CloudKit 事件适配器。",
        "生产容器、签名、账号及跨设备同步仍需配置和真机验收。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/ProfileDetailViews.swift"
    },
    {
      "id": "notification-settings",
      "title": "通知说明",
      "platform": "iPhone",
      "kind": "设置",
      "summary": "说明当前通知能力。",
      "entry": "个人中心 → 通知。",
      "behavior": [
        "应用内查看变化；当前版本没有后台通知发送能力。",
        "保留页面不等于已经开放推送服务。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/SettingsViews.swift"
    },
    {
      "id": "privacy",
      "title": "隐私说明",
      "platform": "iPhone",
      "kind": "设置",
      "summary": "解释本地记录、连接与观察范围。",
      "entry": "个人中心 → 隐私。",
      "behavior": [
        "原始工作内容默认保留在设备上。",
        "Codex 正文仅临时参与本地关联匹配，不进入 Anchor 持久化或同步。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/SettingsViews.swift"
    },
    {
      "id": "accessibility",
      "title": "辅助功能",
      "platform": "iPhone",
      "kind": "设置",
      "summary": "提供减弱动态效果与显示辅助说明。",
      "entry": "个人中心 → 辅助功能。",
      "behavior": [
        "支持应用内减弱动态效果开关。",
        "返航合并系统与应用设置；其他组件仍有一致性验收项。",
        "动态字体、旁白、对比度与透明度需完整走查。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorIOSFeatures/SettingsViews.swift",
      "image": "ios-large-type.png",
      "imageLabel": "返航大字号示例",
      "imageAlt": "最大辅助功能字号下的返航摘要，作为适配示例"
    },
    {
      "id": "mac-work",
      "title": "当前工作",
      "platform": "Mac",
      "kind": "主窗口",
      "summary": "在电脑查看任务、来源进程和近期活动。",
      "entry": "屏幕边缘控制 → 详情；侧栏 → 当前工作。",
      "behavior": [
        "原生 NavigationStack；窗口最小 900 × 620pt。",
        "多任务入口目前四列；进程默认前三项，近期活动默认折叠。",
        "连接胶囊显示状态，连接修复在设置。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorMacFeatures/MacWorkOverviewView.swift"
    },
    {
      "id": "mac-edge",
      "title": "屏幕边缘控制",
      "platform": "Mac",
      "kind": "悬浮控件",
      "summary": "通过船与锚提示手机投锚的有效变化。",
      "entry": "Mac 启动后在屏幕边缘显示。",
      "behavior": [
        "88 × 88pt 控制面板与独立装饰面板；装饰不拦截点击。",
        "控制可悬停或键盘聚焦，空闲五秒后收起。",
        "落锚、收锚与轻提示音对应状态变化，绳索摆动有限衰减。"
      ],
      "source": "Apps/AnchorMac/AnchorEdgePanelController.swift"
    },
    {
      "id": "mac-process",
      "title": "Mac 进程详情",
      "platform": "Mac",
      "kind": "详情",
      "summary": "查看单个来源进程和它的事件记录。",
      "entry": "当前工作 → 进程列表。",
      "behavior": [
        "详情提供完整状态与说明。",
        "可进一步查看完整时间线。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorMacFeatures/MacProcessDetailView.swift"
    },
    {
      "id": "mac-timeline",
      "title": "完整时间线",
      "platform": "Mac",
      "kind": "详情",
      "summary": "回看当前任务的事件演进。",
      "entry": "当前工作近期活动；进程详情。",
      "behavior": [
        "近期活动只展示最近五条，此页展开完整事件。",
        "外部状态保持来源所有权。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorMacFeatures/AnchorMacDetailViews.swift"
    },
    {
      "id": "mac-history",
      "title": "Mac 工作历史",
      "platform": "Mac",
      "kind": "主页面",
      "summary": "回看当前选择任务的上下文快照与历史轨迹。",
      "entry": "可展开侧栏 → 历史。",
      "behavior": [
        "基于当前任务的 snapshots 展示历史轨迹，可搜索并打开快照详情。",
        "它与 iPhone 的已归档任务历史列表范围不同。",
        "可返回当前工作。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorMacFeatures/MacHistoryTrackView.swift"
    },
    {
      "id": "mac-settings",
      "title": "Mac 设置",
      "platform": "Mac",
      "kind": "主页面",
      "summary": "设备连接、来源接入与体验设置的统一入口。",
      "entry": "侧栏 → 设置；系统设置快捷键。",
      "behavior": [
        "配对与重试；来源健康与详情。",
        "登录时打开、船锚提示音、减弱动态效果。",
        "当前截图来自本次构建与隔离测试数据。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorMacFeatures/AnchorMacDetailViews.swift",
      "image": "mac-settings.png",
      "imageLabel": "设置页 · 来源区域"
    },
    {
      "id": "mac-codex",
      "title": "Codex 接入",
      "platform": "Mac",
      "kind": "设置模块",
      "summary": "授权本地会话目录，并关联有效的新会话。",
      "entry": "Mac 设置 → 来源 → Codex。",
      "behavior": [
        "每两秒扫描授权目录，以创建时间和本地关键词重合匹配。",
        "只匹配投锚后新建且锚点仍活动的会话；歧义、无关与旧会话不自动加入。",
        "支持手动选择；没有投锚后 30 分钟失效限制。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorMacFeatures/MacSourceSetupView.swift",
      "image": "mac-sources.png"
    },
    {
      "id": "mac-cli",
      "title": "终端接入",
      "platform": "Mac",
      "kind": "设置模块",
      "summary": "让明确接入的命令上报开始和结束。",
      "entry": "Mac 设置 → 安装命令 → 启用 zsh 生命周期钩子。",
      "behavior": [
        "使用签名的 anchor 辅助命令与 App Group 收件箱。",
        "不保存命令参数和完整路径。",
        "命令结束回写开始时的所属任务。"
      ],
      "source": "Documentation/CLI_EVENT_CONTRACT.md"
    },
    {
      "id": "mac-source",
      "title": "来源详情",
      "platform": "Mac",
      "kind": "弹层",
      "summary": "查看某一来源的健康状态和已收到事件。",
      "entry": "Mac 设置 → 来源卡片。",
      "behavior": [
        "显示来源分组下的进程信息。",
        "原始应用打开不等于正在运行 AI 任务。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorMacFeatures/MacSourceDetailView.swift"
    },
    {
      "id": "ingest",
      "title": "来源采集",
      "platform": "Core",
      "kind": "服务模块",
      "summary": "把 Codex 与 CLI 的生命周期转换成统一事件。",
      "entry": "Mac 端已授权或主动接入的来源。",
      "behavior": [
        "CodexLifecycleFileSource / FileProcessSource → ProcessSourceCoordinator。",
        "稳定进程标识、任务归属、检查点与确定性回放。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorCore/ProcessSourceCoordinator.swift"
    },
    {
      "id": "core",
      "title": "状态与任务",
      "platform": "Core",
      "kind": "共享模块",
      "summary": "用事件、命令和 reducer 推导两端可读状态。",
      "entry": "用户操作或来源事件进入 Repository。",
      "behavior": [
        "SessionCommand → SessionOperation → SessionReducer → SessionProjection。",
        "TaskRunStore 与 TaskSessionLifecycleBridge 维护任务生命周期。",
        "TaskDashboardPolicy 过滤已退出范围的来源和决策记录。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorCore/SessionReducer.swift"
    },
    {
      "id": "storage",
      "title": "本地持久化",
      "platform": "Core",
      "kind": "数据模块",
      "summary": "先保存本地操作，再进行后台同步。",
      "entry": "两端的 LocalSessionRepository 与事件日志。",
      "behavior": [
        "崩溃恢复、事件去重、outbox、确定性回放。",
        "暂不把 SwiftData 规划当作已经替换的存储实现。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorCore/Repository.swift"
    },
    {
      "id": "transport",
      "title": "设备同步",
      "platform": "Core",
      "kind": "传输模块",
      "summary": "认证的局域网连接与蓝牙通道同步事件。",
      "entry": "首次发现、配对与后续可信设备重连。",
      "behavior": [
        "Bonjour 发现；一次性码密钥协商与 Keychain 信任。",
        "认证事件信封、确认回执与重放去重。",
        "任一认证通道有效即可继续工作；真实配对需设备验收。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorTransport/LinkedSessionRepository.swift"
    },
    {
      "id": "cloud",
      "title": "可选 CloudKit",
      "platform": "Core",
      "kind": "可选适配",
      "summary": "按需接入私有云事件存储。",
      "entry": "开启对应配置、容器和签名能力后。",
      "behavior": [
        "DurableEventSynchronizer 管理上传、下载和重试。",
        "普通公开网页不连接用户任务或云端数据。",
        "生产容器启用与实际账号验收仍是后续项。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorTransport/CloudKitEventStore.swift"
    },
    {
      "id": "presence",
      "title": "离开与返航状态机",
      "platform": "Core",
      "kind": "状态模块",
      "summary": "根据认证连接与手动操作，决定工作状态。",
      "entry": "连接变化、用户暂时离开、用户确认返回。",
      "behavior": [
        "自动：已连接过 → 全部认证通道失联 ≥ 300 秒 → 交接约 3 秒 → 离开。",
        "手动离开立即生效；自动返航需要认证重连。",
        "旋转与 RSSI 本身不构成返航；返航确认后回到工作台。"
      ],
      "source": "Packages/AnchorKit/Sources/AnchorCore/PresenceReducer.swift"
    }
  ],
  "flows": [
    {
      "id": "journey",
      "title": "从投锚到完成",
      "subtitle": "沿着一段工作的主线，理解手机、电脑与共享状态如何配合。",
      "columns": [
        [
          "setup",
          "home",
          "detail"
        ],
        [
          "mac-codex",
          "mac-cli",
          "mac-work"
        ],
        [
          "away",
          "return",
          "finish"
        ]
      ],
      "edges": [
        [
          "setup",
          "home",
          "确认开始"
        ],
        [
          "home",
          "detail",
          "点任务卡"
        ],
        [
          "setup",
          "mac-codex",
          "新会话关联",
          "sync"
        ],
        [
          "mac-codex",
          "mac-work",
          "观测状态",
          "sync"
        ],
        [
          "mac-cli",
          "mac-work",
          "命令事件",
          "sync"
        ],
        [
          "mac-work",
          "home",
          "认证同步",
          "sync"
        ],
        [
          "detail",
          "away",
          "暂时离开"
        ],
        [
          "away",
          "return",
          "认证重连",
          "auto"
        ],
        [
          "return",
          "home",
          "返回并继续"
        ],
        [
          "detail",
          "finish",
          "结束并确认"
        ]
      ]
    },
    {
      "id": "iphone",
      "title": "iPhone 页面地图",
      "subtitle": "主页面 → 操作与设置 → 详情与结果。每个节点都可以查看入口和源码。",
      "columns": [
        [
          "home",
          "landscape",
          "profile"
        ],
        [
          "setup",
          "tasks",
          "detail",
          "connections",
          "notifications",
          "history"
        ],
        [
          "goal",
          "note",
          "finish",
          "layout",
          "process",
          "history-detail",
          "account",
          "stats",
          "sources",
          "icloud",
          "notification-settings",
          "privacy",
          "accessibility",
          "recovery"
        ]
      ],
      "edges": [
        [
          "home",
          "setup",
          "底部锚按钮"
        ],
        [
          "home",
          "tasks",
          "任务数量"
        ],
        [
          "home",
          "detail",
          "任务卡"
        ],
        [
          "home",
          "connections",
          "连接状态"
        ],
        [
          "home",
          "notifications",
          "铃铛"
        ],
        [
          "home",
          "profile",
          "头像"
        ],
        [
          "landscape",
          "tasks",
          "任务库"
        ],
        [
          "tasks",
          "goal",
          "编辑目标"
        ],
        [
          "tasks",
          "note",
          "投锚记录"
        ],
        [
          "tasks",
          "finish",
          "结束工作"
        ],
        [
          "detail",
          "layout",
          "任务管理"
        ],
        [
          "notifications",
          "process",
          "关联进程"
        ],
        [
          "profile",
          "history",
          "历史"
        ],
        [
          "history",
          "history-detail",
          "选择记录"
        ],
        [
          "profile",
          "account",
          "编辑资料"
        ],
        [
          "profile",
          "stats",
          "统计项"
        ],
        [
          "profile",
          "sources",
          "来源"
        ],
        [
          "profile",
          "icloud",
          "iCloud"
        ],
        [
          "profile",
          "notification-settings",
          "通知"
        ],
        [
          "profile",
          "privacy",
          "隐私"
        ],
        [
          "profile",
          "accessibility",
          "辅助功能"
        ],
        [
          "profile",
          "layout",
          "任务管理"
        ]
      ]
    },
    {
      "id": "returning",
      "title": "离开与返航",
      "subtitle": "手动离开立即生效；自动离开依赖认证连接。返航先回顾，再继续。",
      "columns": [
        [
          "home",
          "detail",
          "presence"
        ],
        [
          "handoff",
          "away",
          "return"
        ],
        [
          "return-context",
          "return-changes",
          "process",
          "landscape"
        ]
      ],
      "edges": [
        [
          "detail",
          "away",
          "暂时离开"
        ],
        [
          "presence",
          "handoff",
          "失联 ≥ 五分钟",
          "auto"
        ],
        [
          "handoff",
          "away",
          "约三秒",
          "auto"
        ],
        [
          "away",
          "return",
          "认证重连",
          "auto"
        ],
        [
          "return",
          "return-context",
          "查看记录"
        ],
        [
          "return",
          "return-changes",
          "全部变化"
        ],
        [
          "return",
          "process",
          "你的下一步"
        ],
        [
          "return",
          "home",
          "确认返回"
        ],
        [
          "home",
          "landscape",
          "横置手机"
        ]
      ]
    },
    {
      "id": "mac",
      "title": "Mac 页面地图",
      "subtitle": "屏幕边缘控制打开详情，侧栏组织当前工作、历史与设置。",
      "columns": [
        [
          "mac-edge"
        ],
        [
          "mac-work",
          "mac-history",
          "mac-settings"
        ],
        [
          "mac-process",
          "mac-timeline",
          "mac-codex",
          "mac-cli",
          "mac-source"
        ]
      ],
      "edges": [
        [
          "mac-edge",
          "mac-work",
          "打开详情"
        ],
        [
          "mac-work",
          "mac-process",
          "进程列表"
        ],
        [
          "mac-work",
          "mac-timeline",
          "近期活动"
        ],
        [
          "mac-process",
          "mac-timeline",
          "查看时间线"
        ],
        [
          "mac-settings",
          "mac-codex",
          "授权来源"
        ],
        [
          "mac-settings",
          "mac-cli",
          "终端接入"
        ],
        [
          "mac-settings",
          "mac-source",
          "来源卡片"
        ]
      ]
    },
    {
      "id": "system",
      "title": "功能结构与数据流",
      "subtitle": "这是原生 App 的本地核心与同步架构；GitHub Pages 只发布这份静态说明。",
      "columns": [
        [
          "mac-codex",
          "mac-cli",
          "setup",
          "note"
        ],
        [
          "ingest",
          "core",
          "storage",
          "presence"
        ],
        [
          "transport",
          "home",
          "cloud"
        ]
      ],
      "edges": [
        [
          "mac-codex",
          "ingest",
          "日志生命周期",
          "sync"
        ],
        [
          "mac-cli",
          "ingest",
          "命令生命周期",
          "sync"
        ],
        [
          "ingest",
          "core",
          "统一事件",
          "sync"
        ],
        [
          "setup",
          "core",
          "用户命令",
          "sync"
        ],
        [
          "note",
          "core",
          "用户命令",
          "sync"
        ],
        [
          "core",
          "storage",
          "先落盘",
          "sync"
        ],
        [
          "storage",
          "transport",
          "后台复制 / ACK",
          "sync"
        ],
        [
          "transport",
          "home",
          "状态投影",
          "sync"
        ],
        [
          "transport",
          "presence",
          "认证连接变化",
          "sync"
        ],
        [
          "storage",
          "cloud",
          "可选持久同步",
          "sync"
        ]
      ]
    }
  ],
  "modules": [
    [
      "建立工作",
      [
        "setup",
        "goal",
        "tasks",
        "detail"
      ]
    ],
    [
      "查看进展",
      [
        "home",
        "landscape",
        "process",
        "notifications",
        "mac-work",
        "mac-process",
        "mac-timeline"
      ]
    ],
    [
      "保存与恢复上下文",
      [
        "note",
        "handoff",
        "away",
        "return",
        "return-context",
        "return-changes",
        "recovery"
      ]
    ],
    [
      "完成与回顾",
      [
        "finish",
        "history",
        "history-detail",
        "mac-history",
        "profile",
        "stats"
      ]
    ],
    [
      "连接与偏好",
      [
        "connections",
        "sources",
        "icloud",
        "notification-settings",
        "privacy",
        "accessibility",
        "account",
        "layout",
        "mac-edge",
        "mac-settings",
        "mac-codex",
        "mac-cli",
        "mac-source"
      ]
    ],
    [
      "共享核心与同步",
      [
        "ingest",
        "core",
        "storage",
        "transport",
        "cloud",
        "presence"
      ]
    ]
  ],
  "assets": {
    "ios-home.png": {
      "caption": "2026-10-02 最新本地可读性验证 · 四个隔离任务展示未知、0%、63%、100% 与对勾完成标记。本地修订另有标注。",
      "origin": "252A2385-FDF3-4DDE-A601-E643A5941FDC.png",
      "date": "2026-10-02"
    },
    "ios-detail.png": {
      "caption": "正式 iOS UI 测试 · 2026-10-02 · 任务详情的暂时离开入口。隔离测试数据。",
      "origin": "81A39B46-3364-4FF4-B629-4017EFB4FC56.png",
      "date": "2026-10-02"
    },
    "ios-note.png": {
      "caption": "正式 iOS UI 测试 · 2026-10-02 · 英文界面，记录保存后再次打开。隔离测试数据。",
      "origin": "0924B945-4A8D-45DB-8E9B-5F01E35E6EFE.png",
      "date": "2026-10-02"
    },
    "ios-setup.png": {
      "caption": "2026-10-02 最新本地可读性验证 · 创建草稿恢复与 Next 按钮深色前景。仅展示创建流程的一步。",
      "origin": "E1AA6E03-1BB8-4847-B563-EE37D4F57BEC.png",
      "date": "2026-10-02"
    },
    "ios-return.png": {
      "caption": "正式 iOS 返航测试 · 2026-10-02 · 使用项目 ReturnDataJourneyTests 生成的隔离数据，非个人工作内容。",
      "origin": "standard-populated-top.png",
      "date": "2026-10-02"
    },
    "ios-process.png": {
      "caption": "正式 iOS 返航测试 · 2026-10-02 · 从返航「下一步」打开的进程详情弹层。隔离测试数据。",
      "origin": "standard-failed-task-detail.png",
      "date": "2026-10-02"
    },
    "ios-context.png": {
      "caption": "正式 iOS 返航测试 · 2026-10-02 · 完整投锚记录。隔离测试数据。",
      "origin": "standard-anchor-context.png",
      "date": "2026-10-02"
    },
    "ios-changes.png": {
      "caption": "正式 iOS 返航测试 · 2026-10-02 · 离开期间全部变化。隔离测试数据。",
      "origin": "standard-all-return-changes.png",
      "date": "2026-10-02"
    },
    "ios-large-type.png": {
      "caption": "正式 iOS 返航测试 · 2026-10-02 · 辅助功能最大字号下的返航页面。此图展示适配结果，不是辅助功能设置页。",
      "origin": "large-populated-top.png",
      "date": "2026-10-02"
    },
    "mac-settings.png": {
      "caption": "本次由基线 3ed3e0c 构建 · 2026-10-02 · Mac 原生设置页的来源区。使用一次性隔离存储与测试数据；未授权真实来源。",
      "origin": "mac-settings.png",
      "date": "2026-10-02"
    },
    "mac-sources.png": {
      "caption": "本次由基线 3ed3e0c 构建 · 2026-10-02 · Mac 原生设置页的来源区。使用一次性隔离存储与测试数据；未授权真实来源。",
      "origin": "mac-settings.png",
      "date": "2026-10-02"
    },
    "ios-landscape.png": {
      "caption": "2026-10-02 最新本地可读性验证 · 横屏 Ambient 工作台。四个任务均为隔离测试数据。",
      "origin": "B5231078-FF50-4EDD-8616-4CD3F3DFFA94.png",
      "date": "2026-10-02"
    }
  },
  "localRevision": {
    "date": "2026-10-02",
    "description": "首页进度可读性与创建按钮对比度本地修订",
    "files": {
      "Packages/AnchorKit/Sources/AnchorIOSFeatures/HostedTaskCard.swift": "1980b208ab7d584eec18aa385ef9b621b1276687e014eb2a1aec6fdc4e99a89a",
      "Packages/AnchorKit/Sources/AnchorIOSFeatures/AnchorSetupView.swift": "a48e63db07253d42014a57e86e5500fac508d8107a6fd6ce6fdbaff739650147"
    }
  }
};
