#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacCodexConnectionNotice: View {
    @Bindable var model: MacSourceSetupModel

    var body: some View {
        if !model.hasConversationSource {
            HStack {
                Label("连接本机 Codex 和 Claude Code 后，新对话会自动出现在这里。", systemImage: "folder.badge.plus")
                Spacer()
                Button("连接本地会话") { model.showsCodexOnboarding = true }
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
            Label("自动接入本机 AI 会话", systemImage: "folder.badge.plus")
                .font(.title2.bold())
            Text("首次选择本机的会话文件夹后，Anchor 会自动发现 Codex 和 Claude Code 的新对话，不需要每次新建会话再点跟踪。")
                .foregroundStyle(AnchorPalette.secondaryInk)
            VStack(alignment: .leading, spacing: 12) {
                Label("在同一个文件夹窗口中选择 Codex sessions 和 Claude Code projects", systemImage: "1.circle")
                Label("自动读取会话标题、最新请求、每轮回复摘要和实时状态", systemImage: "2.circle")
                Label("自动匹配到任务；归属不准时在“当前工作”里调整", systemImage: "3.circle")
            }
            Text("一次选择会记住这两个会话目录，之后新增会话会自动发现和跟踪。Anchor 只读取这些目录里的日志；发送到 iPhone 的是会话标题、最新请求、每轮回复摘要及实时状态，不是整份原始日志。")
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
                Button("一次连接 Codex + Claude…", systemImage: "folder.badge.plus") {
                    model.clearError()
                    Task { await model.authorizeAgentSessionFolders() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isWorking)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("mac.agents.onboarding.authorize")
            }
        }
    }
}
#endif
