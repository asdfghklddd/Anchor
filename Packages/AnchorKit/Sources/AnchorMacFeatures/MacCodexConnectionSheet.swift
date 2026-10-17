#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacCodexConnectionNotice: View {
    @Bindable var model: MacSourceSetupModel

    var body: some View {
        if model.codexSessionsFolderName == nil {
            HStack {
                Label("连接 Codex 后，Anchor 会按任务关键词查找会话。", systemImage: "folder.badge.plus")
                Spacer()
                Button("连接 Codex") { model.showsCodexOnboarding = true }
            }
            .padding(.top, 32)
        } else if !model.codexSuggestions.isEmpty {
            HStack {
                Label("找到 \(model.codexSuggestions.count) 个可能相关的会话", systemImage: "bubble.left.and.text.bubble.right")
                Spacer()
                Button("确认或修改") { model.showsCodexReview = true }
            }
            .padding(.top, 32)
        }
    }
}

struct MacCodexConnectionSheet: View {
    @Bindable var model: MacSourceSetupModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if model.showsCodexOnboarding {
                onboarding
            } else {
                review
            }
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
            Text("连接一次，之后打开 Anchor 就会自动查找与你的任务相关的会话。")
                .foregroundStyle(AnchorPalette.secondaryInk)
            VStack(alignment: .leading, spacing: 12) {
                Label("授权读取 Codex 会话文件夹", systemImage: "1.circle")
                Label("按任务名称、完成标准和步骤匹配", systemImage: "2.circle")
                Label("确认或修改找到的会话，再开始追踪", systemImage: "3.circle")
            }
            Text("点击后会打开 macOS 文件夹窗口。选择 sessions 文件夹并授权即可。匹配在本机进行，会话正文不会保存或同步到 Anchor。")
                .font(.callout)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            if model.codexSessionsFolderName != nil {
                Label("已连接，正在自动查找。没有匹配时，也会继续留意新会话。", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AnchorPalette.mintInk)
            }
            HStack {
                Button(model.codexSessionsFolderName == nil ? "稍后连接" : "关闭") { model.finishCodexOnboarding() }
                    .disabled(model.isWorking)
                Spacer()
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

    private var review: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("找到可能相关的会话").font(.title2.bold())
            Text("已按任务关键词推荐归属。确认后开始追踪，也可以改选任务或忽略。")
                .foregroundStyle(AnchorPalette.secondaryInk)
            if model.codexSuggestions.isEmpty {
                Label("已处理完当前匹配，Anchor 会继续查找新会话。", systemImage: "checkmark.circle")
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(model.codexSuggestions) { suggestion in
                            MacCodexSuggestionRow(model: model, suggestion: suggestion)
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
            HStack {
                Text("未确认的会话不会加入任务。")
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                Spacer()
                Button(model.codexSuggestions.isEmpty ? "完成" : "稍后确认") {
                    model.showsCodexReview = false
                    model.clearError()
                }
                .disabled(model.isWorking)
                .keyboardShortcut(.cancelAction)
            }
        }
    }
}

private struct MacCodexSuggestionRow: View {
    let model: MacSourceSetupModel
    let suggestion: MacSourceSetupModel.CodexSuggestion
    @State private var selectedTaskID: UUID?

    init(model: MacSourceSetupModel, suggestion: MacSourceSetupModel.CodexSuggestion) {
        self.model = model
        self.suggestion = suggestion
        _selectedTaskID = State(initialValue: suggestion.suggestedTaskIDs.first)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(suggestion.candidate.workspaceName ?? "Codex 会话")
                .font(.headline)
            HStack {
                Text(suggestion.candidate.modifiedAt, format: .dateTime.month().day().hour().minute())
                Text("· \(suggestion.candidate.id.suffix(8))")
            }
            .font(.caption)
            .foregroundStyle(AnchorPalette.secondaryInk)
            Picker("关联到任务", selection: $selectedTaskID) {
                Text("选择任务").tag(nil as UUID?)
                ForEach(model.activeTasks) { task in
                    Text(task.goal.title + (suggestion.suggestedTaskIDs.contains(task.id) ? "（关键词匹配）" : ""))
                        .tag(Optional(task.id))
                }
            }
            HStack {
                Button("忽略") { model.dismissSuggestion(suggestion) }
                Spacer()
                Button("确认追踪") {
                    guard let selectedTaskID else { return }
                    Task { await model.confirmSuggestion(suggestion, taskID: selectedTaskID) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedTaskID == nil || !model.activeTasks.contains { $0.id == selectedTaskID })
            }
        }
        .padding(16)
        .background(AnchorPalette.fluoriteSurface, in: .rect(cornerRadius: 14))
        .disabled(model.isWorking)
    }
}
#endif
