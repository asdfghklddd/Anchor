# Anchor 色彩系统

更新日期：2026-10-23。适用于 iPhone 与 Mac 正式应用。本文件是 [DESIGN.md](https://github.com/asdfghklddd/Anchor/blob/backup/agent-design-docs/DESIGN.md) D03「颜色」的详细规范；与第一部分设计理念（P1–P6）冲突时以理念为准。

## 1. 一个来源

- 所有颜色只来自 [`AnchorColorTokens.swift`](../Packages/AnchorKit/Sources/AnchorDesign/AnchorColorTokens.swift)：每个令牌一组浅色／深色 sRGB 值，iPhone 与 Mac 共用。
- `AnchorIOSStyle`（iOS）和 `AnchorPalette`（两端）现在只是令牌的别名层，保留旧名称供页面继续使用；新代码直接使用令牌语义名或 `AnchorStateTone`。
- 横屏工作台的例外也在同一令牌库：`LandscapeHarborBackground` 使用横向的 `landscapeCanvasLeading`／`landscapeCanvasTrailing`，任务列标签头使用 `landscapeTaskTabs` 与 `onLandscapeTaskTab`。页面只取令牌，不自行写色值。
- Mac 原有的独立资源目录颜色（BrandDeep `#003C8C`、Interaction `#165D9F`、奶油色 Paper、偏绿的深色 ReturnCanvas 等 21 个 colorset）已删除，Mac 改用同一套港湾色。
- 两个系统级资源颜色不能由代码提供，需手动与令牌同步：`AccentColor` = `action`（新增深色值，原来只有一个深海蓝，深色模式下系统控件会深蓝叠深底），`AnchorLaunchBackground` = `canvasTop`。
- 不属于令牌：App 图标与 A 字锚标（保持不变）、启动港湾插画、Mac 边缘小船、默认头像等艺术资源。少量固定装饰色（`seafoam`、`deepSea`、`oceanHighlight`）不随外观变化，单独列在令牌文件末尾。

## 2. 三类语义色，外加横屏专用视觉令牌

| 类别 | 负责什么 | 不能做什么 |
|---|---|---|
| 表面、文字、品牌 | 港湾背景、卡片、正文、链接、主按钮与锚按钮 | 不表达状态 |
| 状态 | 运行中、需留意、失败、完成——界面上唯一表达状态的颜色 | 不作为任务身份或装饰 |
| 身份 | 区分托管任务（轨道、色签、圆点） | 不表达状态或来源；永远与任务名称同时出现 |
| 横屏工作台专用 | 横屏画布与任务卡标签头的 Figma 对齐外观 | 不是第四套状态／任务身份语义；不能扩散到竖屏、Mac、任务轨道或状态控件 |

此前同一颜色身兼数职：黄色 `yellow` 既是第 1 个任务的身份色又是“需留意”，所以黄色任务轨道上的需留意段看不见；`coral` 既表示失败又是分类色；生成的第 5、7 个任务色（约 25° 橙红、79° 黄绿）会被读成失败或运行。本次修正后三类互不重叠。

## 3. 状态语义

| 状态 | 令牌 | 符号 | 包含 |
|---|---|---|---|
| 运行中 | `runningFill` / `runningInk` | play | 来源上报运行中的会话 |
| 需留意 | `attentionFill` / `attentionInk` | exclamationmark；用户主动中断用 pause | 等待输入、阻塞、断连、用户主动中断（沿用 D02） |
| 失败 | `failedFill` / `failedInk` | xmark | 来源明确上报失败；主动中断不算 |
| 完成 | `doneFill` / `doneInk` | checkmark | 会话完成、锚点确认完成 |
| 未知／尚无来源 | `textSecondary`、虚线 | 无或 circle.dashed | 不属于状态色，保持中性 |

- 形状（圆点、轨道段、终点标记、图标）用 `fill`；文字和文字旁的小图标用 `ink`。代码中用 `AnchorStateTone(.running/.attention/.failed/.done)`，`AnchorStateTone(TideState)` 负责从总览状态换算。
- 颜色永远不是唯一线索：每种状态都配符号或文字（P4、D12）。
- Mac 边缘浮标浮在任意壁纸上，固定使用状态色的浅色值，外加白色描边。

## 4. 身份色

- 指派顺序：蓝 `#4F7CF0` → 青 `#14ADCF` → 粉 `#E967D3` → 紫 `#8B7CF6` → 青绿 `#1FB5A5`；之后按黄金比例在 180°–318° 色相带内生成。
- 与旧版的差异：第 1 色由黄改为蓝（避开需留意）；青加深一级（`#36D1ED` → `#14ADCF`，与白卡片对比 1.83 → 2.66），品牌青 `#36D1ED` 不变；第 5 色由橙红改为青绿；生成色不再进入红、琥珀、绿色相。
- 已保存任务的 `taskColorIndex` 不变，只是同一序号对应的新颜色，所以第 1 个任务会由黄变蓝。

## 4.1 iPhone 横屏任务标签头（2026-10-23）

- 仅 `DeskTaskLibrary` 的标签头使用 `landscapeTaskTabs`，批准顺序固定为琥珀 `#FFB400` → 青 `#3DD4FE` → 粉 `#FF64DB`。这是项目所有者提供的横屏参考色，不改写第 4 节的跨平台任务身份色。
- 标签文字使用 `onLandscapeTaskTab`（`#123B54`），不使用白字；它在三种标签底色上均达到至少 4.5:1 的文字对比度。
- 当前色库暂时只有这三色。第 4 个及之后的任务依据持久的 `taskColorIndex` 循环这三色；项目所有者后续加入颜色时，必须同时明确顺序／映射并更新测试，不能在页面中临时生成第四种色相。
- 任务卡正文的身份浅底仍由全局 `AnchorTaskIdentity` 提供，状态仍只由 `AnchorStateTone` 表达。标签头不能作为运行、需留意、失败或完成的唯一线索。

## 5. 可执行规则

以下规则由 [`AnchorColorTokenTests`](../Packages/AnchorKit/Tests/AnchorMacFeaturesTests/AnchorColorTokenTests.swift) 在 `swift test` 中检查，浅色与深色都要满足：

1. 文字令牌（`text`、`textSecondary`、`heading`、`action` 与四个状态 `ink`）在 `surface`、`canvasTop`、`canvasBottom`、`landscapeCanvasLeading`、`landscapeCanvasTrailing` 上 ≥ 4.5:1。
2. 状态 `fill` 与 `borderStrong` 在 `surface` 上 ≥ 3:1（WCAG 1.4.11 非文字对比）。
3. `onBrand` 在 `brand` 上、`onAction` 在 `action` 上 ≥ 4.5:1。
4. 身份色在 `surface` 上 ≥ 2.5:1，且与红、琥珀、绿三个状态色相相距 ≥ 20°；生成身份色全部落在 180°–318°。身份色总与任务名同时出现，因此不要求 3:1。
5. `onLandscapeTaskTab` 在每一个 `landscapeTaskTabs` 填充上 ≥ 4.5:1。
6. 令牌名唯一。

## 6. 令牌与对比度

由测试导出（`ANCHOR_COLOR_TABLE_EXPORT=<路径> swift test --filter AnchorColorTokenTests`）。最后一列为与同外观 `surface` 的对比度；背景类令牌的这一列只表示与卡片的区分度。

| Token | Light | Dark | On surface (light / dark) |
|---|---|---|---|
| `canvasTop` | `#EAF6F9` | `#101F29` | 1.10 / 1.30 |
| `canvasBottom` | `#D2F7FC` | `#123641` | 1.14 / 1.00 |
| `landscapeCanvasLeading` | `#FAFDFF` | `#101F29` | 1.02 / 1.30 |
| `landscapeCanvasTrailing` | `#D4F7FF` | `#123641` | 1.13 / 1.00 |
| `surface` | `#FFFFFF` | `#20343E` | 1.00 / 1.00 |
| `selection` | `#BFEBF6` | `#24505F` | 1.28 / 1.47 |
| `border` | `#DCECF0` | `#3C5662` | 1.21 / 1.66 |
| `borderStrong` | `#7F94A1` | `#7E97A4` | 3.16 / 4.22 |
| `text` | `#183F52` | `#DFEFF5` | 11.22 / 10.97 |
| `textSecondary` | `#526979` | `#B6CAD5` | 5.74 / 7.64 |
| `heading` | `#315E8B` | `#B5E2F6` | 6.76 / 9.35 |
| `action` | `#176E87` | `#87DCEC` | 5.81 / 8.31 |
| `onAction` | `#FFFFFF` | `#123F52` | 1.00 / 1.15 |
| `brand` | `#36D1ED` | `#289CB8` | 1.83 / 4.03 |
| `onBrand` | `#123F52` | `#082C38` | 11.30 / 1.14 |
| `oceanSurface` | `#6FD8EF` | `#1E6F86` | 1.65 / 2.26 |
| `oceanDeep` | `#2A8FC7` | `#0B2B3A` | 3.59 / 1.14 |
| `runningFill` | `#1E9A5A` | `#4CC98A` | 3.61 / 6.18 |
| `runningInk` | `#16794A` | `#7FDCA7` | 5.43 / 7.83 |
| `attentionFill` | `#C98500` | `#F2C14E` | 3.07 / 7.71 |
| `attentionInk` | `#8A5A00` | `#F2D16B` | 5.93 / 8.70 |
| `failedFill` | `#D92D20` | `#FF6B5E` | 4.83 / 4.63 |
| `failedInk` | `#B42318` | `#FF9C92` | 6.57 / 6.42 |
| `doneFill` | `#26764D` | `#8DDDAD` | 5.55 / 8.06 |
| `doneInk` | `#26764D` | `#8DDDAD` | 5.55 / 8.06 |
| `onLandscapeTaskTab` | `#123B54` | `#123B54` | 11.80 / 1.10 |
| `identityBlue` | `#4F7CF0` | `#7C9DF5` | 3.84 / 4.93 |
| `identityCyan` | `#14ADCF` | `#289CB8` | 2.66 / 4.03 |
| `identityPink` | `#E967D3` | `#D986CB` | 2.86 / 5.07 |
| `identityViolet` | `#8B7CF6` | `#A197F2` | 3.33 / 5.07 |
| `identityTeal` | `#1FB5A5` | `#3CC2B2` | 2.56 / 5.89 |
| `landscapeTaskTabAmber` | `#FFB400` | `#FFB400` | 1.78 / 7.26 |
| `landscapeTaskTabCyan` | `#3DD4FE` | `#3DD4FE` | 1.74 / 7.43 |
| `landscapeTaskTabPink` | `#FF64DB` | `#FF64DB` | 2.59 / 4.99 |

`canvasTop` 浅色由 `#F7FDFF` 调为 `#EAF6F9`：白卡片与背景的区分度由 1.03 提到 1.10（iOS 系统分组背景约 1.12），正文对比几乎不变。

横屏画布从项目所有者提供的参考图取样：浅色为左 `#FAFDFF` 至右 `#D4F7FF` 的水平渐变，不含额外纹理或纵向色差。`onLandscapeTaskTab` 的表面列不代表其使用场景；它只画在三种 `landscapeTaskTab*` 填充上，实际文字对比度由第 5 节第 5 条单独验证。

## 7. 横屏 Figma 对齐（2026-10-23）

| 问题 | 处理 |
|---|---|
| 横屏工作台仍复用较深的共享港湾竖向背景，与参考图色相、亮度和方向不同 | 新增 `landscapeCanvasLeading`／`landscapeCanvasTrailing` 及 `LandscapeHarborBackground`；仅 iPhone 横屏工作台使用左→右 `#FAFDFF` → `#D4F7FF`，不改动竖屏、返航或 Mac 的共享背景 |
| 任务标签头使用新版全局身份色，而非当前横屏设计指定的三色 | 新增 `landscapeTaskTabs`：`#FFB400` → `#3DD4FE` → `#FF64DB`；标签头只取该序列，卡片正文、任务轨道、Mac 和状态色继续用原有语义令牌 |
| 亮色标签使用白字时可读性不足 | 标签文字改为 `onLandscapeTaskTab` `#123B54`，并在测试中要求它在每种批准标签色上 ≥ 4.5:1 |
| 第四个任务会无声落入未经批准的颜色 | 临时按持久的 `taskColorIndex` 循环三色；日后加色必须由项目所有者指定并补充令牌测试与映射 |

## 8. 历史修正一览（2026-10-13）

| 问题 | 处理 |
|---|---|
| iPhone 与 Mac 两套互不相关的色板 | 合并为一个令牌表，删除 Mac 的 21 个 colorset |
| 身份色与状态色重叠（黄、橙红、黄绿） | 身份色限定在 180°–318°，第 1 色改蓝，第 5 色改青绿 |
| `coral`／`sand` 同时表示状态与分类 | 状态改由 `AnchorStateTone` 提供，旧名只保留分类含义 |
| 页面直接使用系统 `.red`／`.green`／`.orange` | 总览、任务卡、返航摘要、状态徽章、Mac 浮标改用状态令牌 |
| 锚按钮白色锚标在青色上仅 1.83:1 | 改用 `onBrand`（6.19:1），与主按钮一致 |
| 青色身份轨道在白卡上 1.83:1 | 身份青加深为 `#14ADCF`（2.66:1） |
| 需留意填充色在白卡上 1.62:1 | `attentionFill` 改为琥珀 `#C98500`（3.07:1），文字用 `attentionInk` |
| `AccentColor` 无深色值 | 补齐，等于 `action` |
| Mac 日期与界面语言不一致 | 已在上一轮修正（`AnchorStrings.interfaceLocale`） |

## 9. 待定与下一步

- **待项目所有者决定**：运行中（`runningFill` `#1E9A5A`）与完成（`doneFill` `#26764D`）同属绿色相，目前靠 play／checkmark 符号区分。可选：保持；或把完成改为港湾青蓝，让“靠岸”与“运行”一眼分开。
- **纪律阶段**（下一步）：把剩余 60 处硬编码（本次已移除 13 处） `Color(red:…)` 和直接写死的色值迁移到令牌；把别名（`brandDeep`、`fluoriteSurface`、`secondaryInk` 等）改为语义名后删除别名；`ReturnView` 强制浅色与自带墨色；Mac 光泽薄荷渐变品牌徽记与 iOS 扁平青色徽记统一；旧来源色 `sourceMark`／`sourceSurface`。圆角、字号等其他令牌随后处理。

## 10. 如何修改颜色

1. 只改 `AnchorColorTokens.swift` 中的值，不在页面里新写颜色。
2. 运行 `swift test --filter AnchorColorTokenTests`；不通过就调整，不放宽规则。
3. 改动 `action` 或 `canvasTop` 时，同步 `Apps/Shared/Assets.xcassets` 中的 `AccentColor`／`AnchorLaunchBackground`。
4. 重新导出第 6 节表格，并在浅色、深色、横屏、增强对比度下截图检查实际叠加效果。
5. 改动横屏工作台的画布或标签头时，保留其 iOS 横屏专属范围；新增标签色前先由项目所有者指定顺序与任务索引映射，再更新第 4.1 节和令牌测试。
