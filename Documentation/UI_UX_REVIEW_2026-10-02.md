# Anchor UI / UX 评审候选清单

日期：2026-10-02。初次评审后，用户已授权实现 I1、I2、I3；其余候选项仍未实施。

后续实现：I1 在当前 App 使用期间保留草稿并提供确认放弃入口；I2 仅在保存成功后反馈，保存中防重复提交；I3 按用户新定义保留绿/红/黄三灯，去掉五角星，完成使用对勾徽章。下文 Before/After 为初次评审记录，最新约定见 DESIGN.md 的 2026-10-02 修正章节。

## 评审方法与边界

已安装并使用 `emil-design-eng`，来源为 https://github.com/emilkowalski/skills ，固定版本 `d16ebe60d09a5ba2afcb7054ede9d0a10c9f6128`。实体安装位于仓库 `.agents/skills/emil-design-eng`；上层 Anchor 工作区通过项目内符号链接发现同一份技能。没有写入用户级技能目录。原始 SKILL.md 保持不变，附带 MIT 许可与 SOURCE.json。

采用技能关于即时反馈、操作频率、可中断动效、清晰状态与细节一致性的原则。CSS 和 React 示例不直接用于 SwiftUI。设计规范优先于通用风格建议。

证据来自当前工作区源码（包含已有未提交修改）、DESIGN.md、README、验证记录，以及既有首页/返航截图。截图只作为历史视觉参考；本轮没有重新构建、启动 App，也未做最新版本真机手势、VoiceOver 或动效流畅度测试。旧截图中的头像、昵称和示例数据不作为当前默认值或正式数据的证据。

已有视觉参考：

- `../../Build/Previews/home-larger-titles.png`
- `../../Build/Previews/return-summary-final.png`
- `../../Deliverables/VideoReview/live-iphone-home.png`
- `../../Deliverables/VideoReview/live-mac-home.png`

## 保留的设计

根据 DESIGN.md 保留 iOS 浅青背景、白卡与蓝标题、任务颜色、锚柱/主会话语义、双列错落卡片、圆形创建入口、独立横屏布局、返航四卡及确认路径、原生连接 sheet、既定启动品牌动画。Mac 保留当前窗口与原生交互方向，不推导为要与 iOS 完全同形。

小船、投锚动画与悬浮导航缺少同等详细的用户确认记录，本轮按既有产品选择保留；涉及触发规则的建议标记为讨论项。减少动态效果使用 App 自有开关也是明确的代码选择，不擅自改成新的默认策略。

优先级：高＝影响输入、反馈或发现待办；中＝改善理解和效率。所有 After 均为候选方案，未实施。

## iOS：8 项

| 编号 / 优先级 | Before（当前） | After（建议） | Why / 边界 |
| --- | --- | --- | --- |
| I1 / 高 | 创建页普通关闭后重置草稿；关闭按钮直接 dismiss。只对旋转暂存做例外处理。 | 有输入时保留未提交草稿，再次打开恢复；提供明确的放弃入口。 | 避免语音、文字和照片因误关丢失。保留三段创建与确认流程。源码确认。 |
| I2 / 高 | 投锚记录在发起保存之前触发 success 触感；按钮仅按输入非空判断可用。 | 按下即时反馈，保存期间显示状态并防连点，持久化成功后再触发 success；失败保留文字。 | 成功反馈应对应成功结果。存在重复提交风险，未声称已实测重复记录。源码确认。 |
| I3 / 高 | 首页红/绿状态主要依赖圆点和位置，黄色星形能区分一类状态，但没有直观图例。VoiceOver 已有状态描述。 | 保留灯位与颜色，给异常/待处理状态加符号或极短标签；至少支持“不依赖颜色区分”。 | 不改变卡片骨架，补足视觉识别。若不接受普通模式增加信息，可只在辅助功能模式增强。 |
| I4 / 中 | 50×17 胶囊里只有 13pt 进度环；未知进度和 0% 都没有有效弧线。 | 保留胶囊和主会话口径；用短横线/虚线明确未知，已知值提供可读百分比或轻量查看方式。 | 减少把未知误读为零进度或加载中。数字属于需用户选择的视觉增强。 |
| I5 / 中 | 无任务时，锚柱区与任务区重复相同“投锚托管首个任务”提示。 | 保留两个区块的位置与高度，图表解释“创建后在这里查看进展”；任务区明确“点底部锚按钮创建任务”。 | 把品牌隐喻与实际操作连起来，不删除已确认空态骨架。 |
| I6 / 中 | 头像打开个人页，但相邻昵称与连接文案属于同一个连接按钮；正常未连接与权限/失败状态均为红色。 | 昵称区域与个人资料入口一致，连接行单独可点击；未连接用中性语气，异常再突出。 | 降低误触和不必要的错误感。保留顶部连接入口，不增加大连接卡。 |
| I7 / 中 | 图表外层横向滚动，任务内部会话又横向滚动，二者都隐藏指示器；名称基础字号 8pt 且单行。 | 保留锚柱语义，优先只保留一层横向滚动；溢出给出边缘提示，任务名提供更清楚的阅读方式。 | 多任务/多会话时可能不易发现隐藏内容；手势竞争及字号取舍需实际验证。涉及局部图表布局，列为讨论项。 |
| I8 / 中 | 通知按钮是白色铃铛，背景为 45% 不透明度的青色，在浅色顶栏中显得很淡。 | 保留圆形与尺寸，用语义深色图标或提高前景/背景区分，同时覆盖深色与增强对比度。 | 历史截图和源码均支持可见性疑点；本轮未做最终渲染对比度认证。 |

### iOS 源码证据

- I1：`AnchorIOSFeatures/AnchorIOSRootView.swift:125–133`、`AnchorSetupView.swift` 的 header close 与 interactiveDismissDisabled、`AnchorSetupHeader.swift` 的 close。
- I2：`AnchorIOSFeatures/ProcessViews.swift:395–406`。
- I3：`AnchorIOSFeatures/HostedTaskCard.swift:38–61`；已确认颜色语义见 DESIGN.md 首页章节。
- I4：`AnchorIOSFeatures/HostedTaskCard.swift:64` 起。
- I5：`AnchorIOSFeatures/PortraitDashboard.swift:40`、`HomeAnchorChart.swift:25`。
- I6：`AnchorIOSFeatures/HarborTopBar.swift:61–88`、`146` 起。
- I7：`AnchorIOSFeatures/HomeAnchorChart.swift:12`、`30`、`76–78`。
- I8：`AnchorIOSFeatures/HarborTopBar.swift:99–126`。

以上相对路径均位于 `Packages/AnchorKit/Sources/` 下。

## macOS：8 项

**2026-10-02 范围修正：** 用户明确 Mac 仅采集 AI／终端任务并同步至手机看板，决策处理不属于产品范围。M1 撤回；M2 的“待确认”部分撤回，仅可讨论来源明确上报的运行／失败状态。M7 的普通应用／Safari 接入建议撤回。以下表格保留原评审记录，不作为实现授权。


| 编号 / 优先级 | Before（当前） | After（建议） | Why / 边界 |
| --- | --- | --- | --- |
| M1 / 高 | 当前任务的优先处理卡在问候、任务库、状态/返航信息和目标大卡之后。 | 有待决策/阻塞时，在首屏更靠上的位置显示简短待处理入口；保留目标大卡。 | 缩短“打开 App → 找到需要我做什么”的路径。代码顺序确认，具体首屏占用需窗口实测。 |
| M2 / 高 | 任务切换卡只显示任务生命周期的“进行中/未开始”，不会表达某个任务内部有等待输入或失败的进程。 | 保留生命周期，加一个独立的“待确认 1 / 异常 1”徽标，选择卡片后进入对应任务。 | 当前任务运行正常时，也能发现其他任务需要处理。避免把任务生命周期和进程状态混为一谈。 |
| M3 / 高 | 顶部连接状态是不可点击的 Label；unavailable 只显示“未知”。 | 改为能打开现有连接设置的状态入口，写明对象是 iPhone；可确认的原因直接解释，原因未知时明确“连接状态暂不可用”。 | 提供从问题到恢复的路径，不凭空推断是未配对，不改配对协议。 |
| M4 / 中 | 任务库固定四列，标题最多两行；窗口最小宽度 900pt。 | 随可用宽度切换 2/3/4 列，为截断标题提供完整名称提示。 | 长中文标题与多任务下更好扫描。保留卡片式任务切换；需用长标题、窄窗口验证。 |
| M5 / 中 | 当前工作/历史/设置由悬浮菜单进入，未见这三个路由的直接键盘快捷方式。已有 Escape、打开主窗口及提交等快捷键。 | 补充对应菜单命令与固定快捷键，显示在菜单内；键盘触发不增加额外装饰入场等待。 | 改善桌面高频切换效率，保留原来的鼠标路径。 |
| M6 / 中，讨论项 | 鼠标进入锚图标立即展开菜单，离开组合区域立即收起；展开与收起统一有 260ms 动画。 | 先实测斜向移动与反复擦过；若误触明显，只给 hover 适度容错，点击/键盘保持直接响应。 | 防止菜单反复展开收起。已有组合命中区域，不再把历史的菜单间隙问题当成当前缺陷。保留悬浮导航，未测得卡顿。 |
| M7 / 中 | Codex 来源接入里“授权文件夹”和“选择会话”并列；终端/Safari 同级展示。 | 在 Codex 区域明确推荐的自动关联路径，把手动选择表达为补充方式；其他来源保留，解释何时需要。 | 用户更容易知道第一步和下一步，不改变匹配规则、授权范围或已有接入能力。 |
| M8 / 中 | 已有任务但没有进程时，列表只显示通用空态，没有接入操作。 | 区分“尚未关联会话”和“已有接入、尚无事件”；给出“连接来源/查看接入状态”入口。 | 创建成功后能继续完成下一步，避免把无进程理解成 App 没反应。保留本地个人计划可以独立存在的语义。 |

### macOS 源码证据

- M1：`AnchorMacFeatures/MacWorkOverviewView.swift:14–59`。
- M2：`AnchorMacFeatures/MacWorkOverviewView.swift:107–118`。
- M3：`AnchorMacFeatures/MacWorkHeaderView.swift:36–63`。
- M4：`AnchorMacFeatures/MacWorkOverviewView.swift:107–116`、`AnchorMacRootView.swift` 的最小窗口尺寸。
- M5：`AnchorMacFeatures/MacSidebar.swift`、`MacSidebarRail.swift`、`AnchorMacMenuView.swift`、`Apps/AnchorMac/AnchorMacApp.swift`。结论仅针对当前/历史/设置路由，不是说 App 完全没有键盘支持。
- M6：`AnchorMacFeatures/AnchorMacRootView.swift:72–105`、`AnchorDesign/AnchorMotion.swift`。
- M7：`AnchorMacFeatures/MacSourceSetupView.swift:36–57` 及其他来源区域。
- M8：`AnchorMacFeatures/MacWorkProcessList.swift:25–33`。

除 Apps 路径外，以上相对路径均位于 `Packages/AnchorKit/Sources/` 下。

## 暂不建议调整

- 不因技能的通用“300ms”建议而缩短已确认的 iOS 启动仪式或 Mac 投锚演出；品牌事件与高频操作分开判断。
- 共用按压反馈已有 0.98 缩放和 140ms 曲线，常规 micro/panel 是 200/260ms，没有依据要求全局换曲线。
- iOS 连接 sheet 已用原生关闭手势并取消未开始的 Logo 入场，不重复建议重写。
- 大字号任务卡已有单列与自适应，不把它列为缺失功能。
- 不更改 iOS 主会话进度与 Mac 已上报进程平均进度的既有统计口径；若要统一，另作产品决定。
- 不把旧预览中的演示任务、昵称或日期当作生产数据问题。

## 建议选择顺序

优先讨论 I1、I2、M2、M3，其次 I3、I5、M1、M8。I4、I7、M4、M6 更涉及现有视觉/交互取舍，可暂缓。

后续若获准实现：I1 测有输入/空草稿/旋转/提交后的关闭行为；I2 测保存失败和连续点击；M2 测未选中任务产生待决策；M3 测不同连接状态的导航与说明。涉及视觉的项在浅深色、长标题、大字号、窄窗口下验证；交互动画需实际运行检查。

## 外部参考

- [Emil skills 仓库](https://github.com/emilkowalski/skills)：技能来源。
- [OpenAI 项目级技能发现规则](https://learn.chatgpt.com/docs/build-skills)：`.agents/skills` 与项目内符号链接。
- [Apple：不只依赖颜色传递信息](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/differentiate-without-color-alone-evaluation-criteria/)：I3 的依据；保留颜色并补充符号/文本。

初次评审仅安装技能和整理建议。随后用户明确批准 I1、I2、I3，已按本页顶部记录实施；其他候选项仍待选择。
