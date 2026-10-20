# Native Mac 构建与测试工作流

## 项目 UI/UX 技能

- 对于 Anchor 的 UI、UX 和动效评审，需先阅读
  `.agents/skills/emil-design-eng/SKILL.md` 和 `DESIGN.md`。
  该技能仅安装在本项目中；其出处和上游许可证存放在清单旁边。
- 将其交互和动效原则应用到原生 SwiftUI。Web 专用的
  CSS、React 和浏览器规范并不是原生实现要求。
- 保留 `DESIGN.md` 中用户已确认的布局和语义。识别任何涉及这些决定的提案，
  并区分已确认的来源问题与需要实时交互测试的假设。仅仅提出评审请求
  并不授权更改应用 UI。
- 将 `DESIGN.md` 的第一部分视为冻结内容：只有在项目负责人明确要求修正
  设计哲学时，才允许修改。维护第二部分中的现有实现证据，以及第三部分中的
  派生要求；绝不在没有证据时将目标要求报告为“已实现”。

## 构建与测试

- 构建本身并不授权保留新的 GUI 应用实例。除非任务确实需要正在运行的应用��
  否则只使用构建验证检查。
- 在启动 Anchor 运行于用户的 Mac 之前，先检查现有的 Anchor 进程。
  记录每个测试实例的 PID，并在成功、失败、中断和超时后统一终止它们。
  不要在没有持有对应进程的情况下反复使用 `open -n`。
- 对于 UI 测试，设置 `ANCHOR_UI_TESTING=1`。对于本地端到端验证，设置唯一的
  `ANCHOR_LOCAL_VALIDATION_ROOT`。这些启动模式使用内存中的配对凭据，
  并且不得访问生产 Keychain 项目。
- 后台配对的读取和写入必须使用 `NoninteractiveKeychain`。不得为使无头测试通过
  而启用 Keychain 认证 UI，不得自动处理密码或 “Always Allow” 对话框，也不得
  修改用户的 Keychain ACL。
- 生产配对必须使用 Data Protection keychain 和稳定的签名权利。若签名或权限
  检查失败，不能静默回退到旧版存储。对于持续的真实设备开发，请使用
  `Configuration/AnchorMac-Development.xcconfig`；未签名构建仅验证编译，
  不能被报告为“分发权限接受”。
- 切勿在测试清理中删除生产配对凭据。应使用一次性测试服务或临时 keychain，
  并只清理测试自身创建的资源。
