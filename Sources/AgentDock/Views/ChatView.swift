import SwiftUI

struct ChatView: View {
    let viewModel: AgentViewModel
    let agentId: UUID

    @State private var inputText = ""
    @State private var showMentionPicker = false

    private var agentIndex: Int? {
        viewModel.agents.firstIndex(where: { $0.id == agentId })
    }

    private var agent: Agent? {
        guard let index = agentIndex else { return nil }
        return viewModel.agents[index]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            if let agent = agent {
                chatHeader(agent)
                Divider()
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if let agent = agent {
                            ForEach(agent.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(16)
                }
                .onChange(of: agent?.messages.count) { _, _ in
                    if let lastId = agent?.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Mention suggestions
            if showMentionPicker {
                mentionSuggestions
            }

            // Input
            inputBar
        }
        .frame(minWidth: 380, minHeight: 400)
    }

    // MARK: - Header

    private func chatHeader(_ agent: Agent) -> some View {
        HStack(spacing: 8) {
            StatusBadgeView(status: agent.status)
            Text(agent.name)
                .fontWeight(.semibold)
            Text("- \(agent.role)")
                .foregroundStyle(.secondary)
            Spacer()

            if !agent.tools.isEmpty {
                Text("\(agent.tools.count) tools")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Mention Suggestions

    private var mentionSuggestions: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.agents) { a in
                Button {
                    insertMention(a.name)
                } label: {
                    HStack(spacing: 4) {
                        Text("@\(a.name)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                insertMention("all")
            } label: {
                Text("@all")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            Button {
                showMentionPicker.toggle()
            } label: {
                Image(systemName: "at")
                    .font(.body)
                    .foregroundStyle(showMentionPicker ? Color.blue : Color.secondary)
            }
            .buttonStyle(.plain)

            TextField("Message... (use @ to mention agents)", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .onSubmit {
                    send()
                }
                .onChange(of: inputText) { _, newValue in
                    // Auto-show mention picker when typing @
                    if newValue.hasSuffix("@") {
                        showMentionPicker = true
                    }
                }

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(inputText.isEmpty ? Color.secondary : Color.blue)
            }
            .disabled(inputText.isEmpty)
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.bar)
    }

    // MARK: - Actions

    private func insertMention(_ name: String) {
        if inputText.hasSuffix("@") {
            inputText += "\(name) "
        } else {
            inputText += "@\(name) "
        }
        showMentionPicker = false
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        showMentionPicker = false

        let (_, mentionedIds) = CollaborationService.parseMentions(
            from: text, agents: viewModel.agents
        )

        Task {
            if mentionedIds.count > 1 {
                // Multi-agent collaboration
                await viewModel.sendCollaborativeMessage(content: text)
            } else {
                // Single agent chat
                await viewModel.sendMessage(to: agentId, content: text)
            }
        }
    }
}
