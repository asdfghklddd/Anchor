#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacCodexConnectionNotice: View {
    @Bindable var model: MacSourceSetupModel

    var body: some View {
        if !model.hasConversationSource {
            HStack {
                Label("连接 Codex 后，你的对话会自动出现在这里。", systemImage: "folder.badge.plus")
                Spacer()
                Button("连接 Codex") { model.showsCodexOnboarding = true }
            }
            .padding(.top, 32)
        }
    }
}

struct MacCodexConnectionSheet: View {
    @Bindable var model: MacSourceSetupModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            onboarding
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(AnchorPalette.sourceInk("coral"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(28)
        .frame(width: 560)
        .background(AnchorPalette.canvas)
        .tint(AnchorPalette.interaction)
        .interactiveDismissDisabled(model.isWorking)
    }

    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("让 Anchor 找到你的 Codex 工作", systemImage: "folder.badge.plus")
                .font(.title2.bold())
            Text("连接一次，之后你的 Codex 对话会自动出现在 Anchor 里，不需要先投锚。")
                .foregroundStyle(AnchorPalette.secondaryInk)
            VStack(alignment: .leading, spacing: 12) {
                Label("授权读取 Codex 会话文件夹", systemImage: "1.circle")
                Label("自动显示每个对话的进度和结束时的回复", systemImage: "2.circle")
                Label("对话会自动归到你在 iPhone 上投的任务；拿不准的放进“未归类”", systemImage: "3.circle")
            }
            Text("点击后会打开 macOS 文件夹窗口。选择 sessions 文件夹并授权即可。每轮回复的开头会经本地连接同步到你的 iPhone；其余对话内容只在这台 Mac 上读取，不会保存。")
                .font(.callout)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            if model.hasConversationSource {
                Label("已连接。你的对话会显示在“当前工作”页面。", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AnchorPalette.mintInk)
            }
            HStack {
                Button(model.hasConversationSource ? "关闭" : "稍后连接") { model.finishCodexOnboarding() }
                    .disabled(model.isWorking)
                Spacer()
                // Claude Code users can start there instead; both can be connected later in Sources.
                if model.claudeProjectsFolderName == nil {
                    Button("连接 Claude Code…") {
                        model.clearError()
                        Task { await model.authorizeClaudeCodeFolder() }
                    }
                    .disabled(model.isWorking)
                    .accessibilityIdentifier("mac.claude.onboarding.authorize")
                }
                if model.codexSessionsFolderName != nil {
                    Button("继续") { model.finishCodexOnboarding() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("连接 Codex…") {
                        model.clearError()
                        Task { await model.authorizeCodexSessionsFolder() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isWorking)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("mac.codex.onboarding.authorize")
                }
            }
        }
    }
}
#endif
