import SwiftUI

struct SettingsView: View {
    let viewModel: AgentViewModel

    var body: some View {
        TabView {
            ConnectionTab(viewModel: viewModel)
                .tabItem { Label("Connection", systemImage: "antenna.radiowaves.left.and.right") }

            AgentsTab(viewModel: viewModel)
                .tabItem { Label("Agents", systemImage: "person.3") }

            SkillsTab()
                .tabItem { Label("Skills", systemImage: "sparkles") }

            MemoryTab()
                .tabItem { Label("Memory", systemImage: "brain") }

            ClaudeCodeTab()
                .tabItem { Label("Claude Code", systemImage: "terminal") }
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - Connection Tab (with OAuth)

struct ConnectionTab: View {
    let viewModel: AgentViewModel
    @State private var apiKeyInput = ""
    @State private var showSaved = false
    @State private var connectionMode: ConnectionMode = .subscription
    @State private var authStatus: ClaudeCLIService.AuthStatus?
    @State private var isCheckingAuth = false

    enum ConnectionMode: String, CaseIterable {
        case subscription = "Claude Subscription (OAuth)"
        case apiKey = "API Key"
    }

    private let cliService = ClaudeCLIService()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connection").font(.headline)

            Picker("Mode", selection: $connectionMode) {
                ForEach(ConnectionMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if connectionMode == .subscription {
                subscriptionSection
            } else {
                apiKeySection
            }

            Spacer()
        }
        .padding(24)
        .onAppear { refreshAuthStatus() }
    }

    // MARK: - Claude Subscription (OAuth)

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // CLI availability
            HStack(spacing: 8) {
                Circle()
                    .fill(cliService.isAvailable ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(cliService.isAvailable
                     ? "Claude CLI detected"
                     : "Claude CLI not found. Install Claude Code first.")
                    .font(.subheadline)
            }

            if cliService.isAvailable {
                // Auth status card
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Authentication Status")
                                .font(.subheadline).fontWeight(.medium)
                            Spacer()
                            Button("Refresh") {
                                refreshAuthStatus()
                            }
                            .font(.caption)
                            .disabled(isCheckingAuth)
                        }

                        if let status = authStatus {
                            HStack(spacing: 8) {
                                Image(systemName: status.loggedIn ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(status.loggedIn ? .green : .red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(status.loggedIn ? "Connected via \(status.authMethod)" : "Not authenticated")
                                        .font(.subheadline)
                                    if let email = status.email {
                                        Text(email).font(.caption).foregroundStyle(.secondary)
                                    }
                                    if let org = status.orgName {
                                        Text(org).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } else if isCheckingAuth {
                            ProgressView().controlSize(.small)
                        }

                        Divider()

                        // OAuth actions
                        HStack(spacing: 12) {
                            if authStatus?.loggedIn == true {
                                Button("Reconnect") {
                                    cliService.startOAuthLogin()
                                    // Refresh after a delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                        refreshAuthStatus()
                                    }
                                }
                                .buttonStyle(.bordered)

                                Button("Logout") {
                                    cliService.logout()
                                    refreshAuthStatus()
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            } else {
                                Button("Connect via Claude Account") {
                                    cliService.startOAuthLogin()
                                    // Refresh after a delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                                        refreshAuthStatus()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .padding(4)
                }

                Text("Uses your existing Claude subscription via OAuth. No separate API key needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func refreshAuthStatus() {
        isCheckingAuth = true
        DispatchQueue.global(qos: .userInitiated).async {
            let status = cliService.checkAuthStatus()
            DispatchQueue.main.async {
                authStatus = status
                isCheckingAuth = false
            }
        }
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SecureField("sk-ant-...", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !key.isEmpty {
                        viewModel.setApiKey(key)
                        showSaved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showSaved = false }
                    }
                }
                .disabled(apiKeyInput.isEmpty)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.hasApiKey ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(viewModel.hasApiKey ? "API key configured" : "No API key")
                    .font(.caption).foregroundStyle(.secondary)
                if showSaved {
                    Text("Saved").font(.caption).foregroundStyle(.green)
                }
            }
        }
    }
}

// MARK: - Agents Tab

struct AgentsTab: View {
    let viewModel: AgentViewModel
    @State private var showCreateSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Agents").font(.headline)
                Spacer()
                Text("~/.claude/agents/").font(.caption).foregroundStyle(.tertiary)
                Button("Reload") { viewModel.reloadAgentsFromDisk() }
                    .font(.caption)
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help("Add custom agent")
            }

            List(viewModel.agents) { agent in
                AgentRowView(agent: agent)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .padding(24)
        .sheet(isPresented: $showCreateSheet) {
            CreateAgentSheet(viewModel: viewModel, isPresented: $showCreateSheet)
        }
    }
}

// MARK: - Create Agent Sheet

struct CreateAgentSheet: View {
    let viewModel: AgentViewModel
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var description = ""
    @State private var model = "sonnet"
    @State private var toolsText = "Read, Write, Edit, Glob, Grep, Bash"
    @State private var skillsText = ""
    @State private var systemPrompt = ""
    @State private var errorMessage = ""

    private let models = ["sonnet", "opus", "haiku"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Custom Agent")
                .font(.headline)

            Form {
                TextField("Name:", text: $name, prompt: Text("e.g. devops"))
                TextField("Description:", text: $description, prompt: Text("e.g. DevOps and infrastructure agent"))
                Picker("Model:", selection: $model) {
                    ForEach(models, id: \.self) { Text($0) }
                }
                TextField("Tools:", text: $toolsText, prompt: Text("comma-separated"))
                    .font(.system(.body, design: .monospaced))
                TextField("Skills:", text: $skillsText, prompt: Text("comma-separated (optional)"))

                VStack(alignment: .leading) {
                    Text("System Prompt:")
                    TextEditor(text: $systemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                        .border(Color.gray.opacity(0.2))
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { createAgent() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || description.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500, height: 440)
    }

    private func createAgent() {
        let tools = toolsText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let skills = skillsText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        let prompt = systemPrompt.isEmpty
            ? "You are \(name), a specialized agent for \(description)."
            : systemPrompt

        do {
            try viewModel.createCustomAgent(
                name: name, description: description,
                tools: tools, model: model,
                skills: skills, systemPrompt: prompt
            )
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AgentRowView: View {
    let agent: Agent

    private var emoji: String {
        switch agent.character {
        case "bear": return "\u{1F43B}"
        case "pig": return "\u{1F437}"
        case "cat": return "\u{1F431}"
        default: return "\u{1F916}"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji).font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(agent.name).fontWeight(.medium)
                    Text("(\(agent.model))").font(.caption).foregroundStyle(.tertiary)
                }
                Text(agent.role).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if !agent.tools.isEmpty {
                badge("\(agent.tools.count) tools", color: .blue)
            }
            if !agent.skills.isEmpty {
                badge("\(agent.skills.count) skills", color: .purple)
            }

            StatusBadgeView(status: agent.status)
        }
        .padding(.vertical, 4)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

// MARK: - Skills Tab

struct SkillsTab: View {
    @State private var skills: [ClaudeCodeSyncService.SkillInfo] = []
    private let syncService = ClaudeCodeSyncService()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Agent Skills").font(.headline)
                Spacer()
                Button("Reload") { skills = syncService.loadSkills() }
                    .font(.caption)
            }
            Text("Skills loaded from agent .md frontmatter")
                .font(.caption).foregroundStyle(.secondary)

            if skills.isEmpty {
                ContentUnavailableView("No skills found", systemImage: "sparkles",
                                       description: Text("Agent .md files have no skills defined"))
            } else {
                List(skills) { skill in
                    HStack {
                        Image(systemName: "sparkle")
                            .foregroundStyle(.purple)
                        Text(skill.name).fontWeight(.medium)
                        Spacer()
                        Text(skill.source)
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .padding(24)
        .onAppear { skills = syncService.loadSkills() }
    }
}

// MARK: - Memory Tab

struct MemoryTab: View {
    @State private var memories: [MemoryItem] = []
    @State private var searchText = ""
    @State private var stats: (total: Int, projects: [String]) = (0, [])

    private let memoryService = MemoryService()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Claude Memories").font(.headline)
                Spacer()
                if memoryService.isAvailable {
                    Text("\(stats.total) total")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if !memoryService.isAvailable {
                ContentUnavailableView("claude-mem not found",
                                       systemImage: "brain",
                                       description: Text("Install claude-mem MCP plugin to view memories"))
            } else {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search memories...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { search() }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                List(memories) { item in
                    MemoryRowView(item: item)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .padding(24)
        .onAppear {
            stats = memoryService.memoryStats()
            memories = memoryService.recentMemories(limit: 30)
        }
    }

    private func search() {
        if searchText.isEmpty {
            memories = memoryService.recentMemories(limit: 30)
        } else {
            memories = memoryService.searchMemories(query: searchText)
        }
    }
}

struct MemoryRowView: View {
    let item: MemoryItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.typeIcon)
                .foregroundStyle(typeColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.typeLabel)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(typeColor.opacity(0.12))
                    .clipShape(Capsule())
                Text(formatDate(item.createdAt))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }

    private var typeColor: Color {
        switch item.type {
        case "discovery": return .blue
        case "feature": return .green
        case "bugfix": return .red
        case "decision": return .orange
        case "change": return .purple
        default: return .gray
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        if let tIndex = dateStr.firstIndex(of: "T") {
            let time = String(dateStr[dateStr.index(after: tIndex)...].prefix(5))
            return time
        }
        return String(dateStr.suffix(8))
    }
}

// MARK: - Claude Code Tab

struct ClaudeCodeTab: View {
    @State private var claudeMDs: [ClaudeCodeSyncService.ClaudeMD] = []
    @State private var plugins: [ClaudeCodeSyncService.MCPPlugin] = []

    private let syncService = ClaudeCodeSyncService()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Claude Code Sync").font(.headline)

            GroupBox("CLAUDE.md Files") {
                if claudeMDs.isEmpty {
                    Text("No CLAUDE.md files found").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(claudeMDs) { md in
                        HStack {
                            Image(systemName: "doc.text")
                            VStack(alignment: .leading) {
                                Text(md.scope.capitalized).font(.caption).fontWeight(.medium)
                                Text(md.path).font(.system(size: 9)).foregroundStyle(.tertiary).lineLimit(1)
                            }
                            Spacer()
                            Text("\(md.content.count) chars")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            GroupBox("MCP Plugins") {
                if plugins.isEmpty {
                    Text("No MCP plugins configured").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(plugins) { plugin in
                        HStack {
                            Image(systemName: "puzzlepiece.extension")
                                .foregroundStyle(.green)
                            Text(plugin.name).font(.caption).fontWeight(.medium)
                            Spacer()
                            Text(plugin.command).font(.system(size: 9)).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Spacer()
        }
        .padding(24)
        .onAppear {
            claudeMDs = syncService.loadClaudeMDFiles()
            plugins = syncService.loadMCPPlugins()
        }
    }
}
