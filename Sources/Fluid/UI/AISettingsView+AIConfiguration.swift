//
//  AISettingsView+AIConfiguration.swift
//  fluid
//
//  Extracted from AISettingsView.swift to keep view body under lint limit.
//

import AppKit
import SwiftUI

extension AIEnhancementSettingsView {
    // MARK: - Helper Functions

    func formLabel(_ title: String) -> some View {
        Text(title)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(width: AISettingsLayout.labelWidth, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [self.theme.palette.accent.opacity(0.15), self.theme.palette.accent.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(6)
    }

    // MARK: - AI Configuration Card

    var aiConfigurationCard: some View {
        VStack(spacing: 14) {
            ThemedCard(style: .prominent, hoverEffect: false) {
                VStack(alignment: .leading, spacing: 10) {
                    // Header
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundStyle(self.theme.palette.accent)
                            Text("AI Enhancement")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        Spacer()
                        Toggle("", isOn: self.$viewModel.enableAIProcessing)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    // Streaming Toggle
                    if self.viewModel.enableAIProcessing && self.viewModel.selectedProviderID != "apple-intelligence" {
                        HStack(spacing: 20) {
                            Toggle("Enable Streaming", isOn: Binding(
                                get: { SettingsStore.shared.enableAIStreaming },
                                set: { SettingsStore.shared.enableAIStreaming = $0 }
                            ))
                            .toggleStyle(.checkbox)

                            Toggle("Show Thinking Tokens", isOn: Binding(
                                get: { SettingsStore.shared.showThinkingTokens },
                                set: { SettingsStore.shared.showThinkingTokens = $0 }
                            ))
                            .toggleStyle(.checkbox)
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(self.theme.palette.secondaryText)
                        .padding(.leading, 4)
                        .padding(.top, -2)
                    }

                    // API Key Warning
                    if self.viewModel.enableAIProcessing && self.viewModel.selectedProviderID != "apple-intelligence" &&
                        !self.viewModel.isLocalEndpoint(self.viewModel.openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)) &&
                        (self.viewModel.providerAPIKeys[self.viewModel.currentProvider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    {
                        self.apiKeyWarningView
                    }

                    // Help Section
                    if self.viewModel.showHelp { self.helpSectionView }

                    // Provider/Model Configuration (only shown when AI Enhancement is enabled)
                    if self.viewModel.enableAIProcessing {
                        HStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "key.fill")
                                    .font(.title3)
                                    .foregroundStyle(self.theme.palette.accent)
                                Text("API Configuration")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }

                            // Compatibility Badge
                            if self.viewModel.selectedProviderID == "apple-intelligence" {
                                HStack(spacing: 4) {
                                    Image(systemName: "apple.logo").font(.caption2)
                                    Text("On-device").font(.caption)
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.quaternary.opacity(0.5)))
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill").font(.caption2)
                                    Text("OpenAI Compatible").font(.caption)
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.quaternary.opacity(0.5)))
                            }

                            Spacer()

                            Button(action: { self.viewModel.showHelp.toggle() }) {
                                Image(systemName: self.viewModel.showHelp ? "questionmark.circle.fill" : "questionmark.circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(self.theme.palette.accent.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }

                        self.providerConfigurationSection

                        self.advancedSettingsCard
                    }
                }
                .padding(14)
            }
            .modifier(CardAppearAnimation(delay: 0.1, appear: self.$viewModel.appear))
        }
    }

    var apiKeyWarningView: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 16))
            Text("API key required for AI enhancement to work")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.orange)
            Spacer()
        }
        .padding(12)
        .background(.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.orange.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 4)
    }

    var helpSectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                Text("Quick Start Guide").font(.subheadline).fontWeight(.semibold)
            }
            VStack(alignment: .leading, spacing: 6) {
                self.helpStep("1", "Enable AI enhancement if needed")
                self.helpStep("2", "Add/choose any provider of your choice along with its API key")
                self.helpStep("3", "Add/choose any good model of your liking")
                self.helpStep("4", "If it's OpenAI compatible endpoint, then update the base URL")
                self.helpStep("5", "Once everything is set, click verify to check if the connection works")
            }
        }
        .padding(14)
        .background(self.theme.palette.accent.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(self.theme.palette.accent.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 4)
        .transition(.opacity)
    }

    func helpStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption).fontWeight(.semibold).frame(width: 16, alignment: .trailing)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    var providerConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            self.providerPickerRow

            if self.viewModel.showingEditProvider { self.editProviderSection }

            if self.viewModel.selectedProviderID == "apple-intelligence" { self.appleIntelligenceBadge }

            // API Key Management
            if self.viewModel.selectedProviderID != "apple-intelligence" {
                HStack(spacing: 8) {
                    Button(action: { self.viewModel.handleAPIKeyButtonTapped() }) {
                        Label("Add or Modify API Key", systemImage: "key.fill")
                            .labelStyle(.titleAndIcon).font(.caption)
                    }
                    .buttonStyle(CompactButtonStyle(isReady: true))
                    .frame(minWidth: AISettingsLayout.primaryActionMinWidth, minHeight: AISettingsLayout.controlHeight)

                    // Get API Key / Download button for built-in providers
                    if let websiteInfo = ModelRepository.shared.providerWebsiteURL(for: self.viewModel.selectedProviderID),
                       let url = URL(string: websiteInfo.url)
                    {
                        Button(action: { NSWorkspace.shared.open(url) }) {
                            Label(websiteInfo.label, systemImage: websiteInfo.label.contains("Download") ? "arrow.down.circle.fill" : (websiteInfo.label.contains("Guide") ? "book.fill" : "link"))
                                .labelStyle(.titleAndIcon).font(.caption)
                        }
                        .buttonStyle(CompactButtonStyle())
                        .frame(minWidth: AISettingsLayout.actionMinWidth, minHeight: AISettingsLayout.controlHeight)
                    }
                }
            }

            // Model Row
            if self.viewModel.selectedProviderID == "apple-intelligence" {
                self.appleIntelligenceModelRow
            } else {
                self.standardModelRow
                if self.viewModel.showingAddModel { self.addModelSection }
                if self.viewModel.showingReasoningConfig { self.reasoningConfigSection }
            }

            // Connection Test
            if self.viewModel.selectedProviderID != "apple-intelligence" {
                self.connectionTestSection
                if self.viewModel.showingSaveProvider { self.addProviderSection }
            }
        }
        .padding(.horizontal, 4)
    }

    var providerPickerRow: some View {
        HStack(spacing: 12) {
            self.formLabel("Provider:")

            // Searchable provider picker with bounded popover
            SearchableProviderPicker(
                builtInProviders: self.builtInProvidersList,
            savedProviders: self.viewModel.savedProviders,
                selectedProviderID: Binding(
                get: { self.viewModel.selectedProviderID },
                    set: { newValue in
                    self.viewModel.selectedProviderID = newValue
                    self.viewModel.handleProviderChange(newValue)
                    }
                ),
                controlWidth: AISettingsLayout.pickerWidth,
                controlHeight: AISettingsLayout.controlHeight
            )

            // Edit button for all providers (including built-in)
            if self.viewModel.selectedProviderID != "apple-intelligence" {
                Button(action: { self.viewModel.startEditingProvider() }) {
                    HStack(spacing: 4) { Image(systemName: "pencil"); Text("Edit") }.font(.caption)
                }
                .buttonStyle(CompactButtonStyle())
                .frame(minWidth: AISettingsLayout.compactActionMinWidth, minHeight: AISettingsLayout.controlHeight)
            }

            // Delete button only for custom providers
            if !ModelRepository.shared.isBuiltIn(self.viewModel.selectedProviderID) {
                Button(action: { self.viewModel.deleteCurrentProvider() }) {
                    HStack(spacing: 4) { Image(systemName: "trash"); Text("Delete") }.font(.caption)
                }
                .buttonStyle(CompactButtonStyle(foreground: .red, borderColor: .red.opacity(0.6)))
                .frame(minWidth: AISettingsLayout.compactActionMinWidth, minHeight: AISettingsLayout.controlHeight)
            }

            Button("+ Add Provider") {
                self.viewModel.showingSaveProvider = true
                self.viewModel.newProviderName = ""
                self.viewModel.newProviderBaseURL = ""
                self.viewModel.newProviderApiKey = ""
                self.viewModel.newProviderModels = ""
            }
            .buttonStyle(CompactButtonStyle(isReady: true))
            .frame(minWidth: AISettingsLayout.wideActionMinWidth, minHeight: AISettingsLayout.controlHeight)
        }
    }

    var builtInProvidersList: [(id: String, name: String)] {
        ModelRepository.shared.builtInProvidersList(
            includeAppleIntelligence: true,
            appleIntelligenceAvailable: AppleIntelligenceService.isAvailable
        )
    }

    var editProviderSection: some View {
        VStack(spacing: 12) {
            HStack { Text("Edit Provider").font(.headline).fontWeight(.semibold); Spacer() }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name").font(.caption).foregroundStyle(.secondary)
                    TextField("Provider name", text: self.$viewModel.editProviderName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Base URL").font(.caption).foregroundStyle(.secondary)
                    TextField("e.g., http://localhost:11434/v1", text: self.$viewModel.editProviderBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }
            HStack(spacing: 8) {
                Button("Save") { self.viewModel.saveEditedProvider() }
                    .buttonStyle(GlassButtonStyle())
                    .frame(minWidth: AISettingsLayout.actionMinWidth, minHeight: AISettingsLayout.controlHeight)
                    .disabled(self.viewModel.editProviderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        self.viewModel.editProviderBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel") {
                    self.viewModel.showingEditProvider = false
                    self.viewModel.editProviderName = ""
                    self.viewModel.editProviderBaseURL = ""
                }
                    .buttonStyle(GlassButtonStyle())
                    .frame(minWidth: AISettingsLayout.actionMinWidth, minHeight: AISettingsLayout.controlHeight)
            }
        }
        .padding(12)
        .background(self.theme.palette.cardBackground.opacity(0.5))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(self.theme.palette.accent.opacity(0.3), lineWidth: 1))
        .padding(.vertical, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    var appleIntelligenceBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "apple.logo").font(.system(size: 14))
            Text("On-Device").fontWeight(.medium)
            Text("•").foregroundStyle(.secondary)
            Image(systemName: "lock.shield.fill").font(.system(size: 12))
            Text("Private").fontWeight(.medium)
        }
        .font(.caption).foregroundStyle(Color.fluidGreen)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.fluidGreen.opacity(0.15))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                Color.fluidGreen.opacity(0.3),
                lineWidth: 1
            )))
    }

    var appleIntelligenceModelRow: some View {
        HStack(spacing: 12) {
            self.formLabel("Model:")
            Text("System Language Model").foregroundStyle(.secondary).font(.system(.body))
            Spacer()
        }
    }

    var standardModelRow: some View {
        HStack(spacing: 12) {
            self.formLabel("Model:")

            // Searchable model picker with refresh button
            SearchableModelPicker(
                models: self.viewModel.availableModels,
                selectedModel: self.$viewModel.selectedModel,
                onRefresh: { await self.viewModel.fetchModelsForCurrentProvider() },
                isRefreshing: self.viewModel.isFetchingModels,
                controlWidth: AISettingsLayout.pickerWidth,
                controlHeight: AISettingsLayout.controlHeight
            )

            if !ModelRepository.shared.isBuiltIn(self.viewModel.selectedProviderID) {
                Button(action: { self.viewModel.deleteSelectedModel() }) {
                    HStack(spacing: 4) { Image(systemName: "trash"); Text("Delete") }.font(.caption)
                }
                .buttonStyle(CompactButtonStyle(foreground: .red, borderColor: .red.opacity(0.6)))
                .frame(minWidth: AISettingsLayout.compactActionMinWidth, minHeight: AISettingsLayout.controlHeight)
            }

            if !self.viewModel.showingAddModel {
                Button("+ Add Model") {
                    self.viewModel.showingAddModel = true
                    self.viewModel.newModelName = ""
                }
                    .buttonStyle(CompactButtonStyle(isReady: true))
                    .frame(minWidth: AISettingsLayout.wideActionMinWidth, minHeight: AISettingsLayout.controlHeight)
            }

            Button(action: { self.viewModel.openReasoningConfig() }) {
                HStack(spacing: 4) {
                    Image(systemName: self.viewModel.hasReasoningConfigForCurrentModel() ? "brain.fill" : "brain")
                    Text("Reasoning")
                }
                .font(.caption)
            }
            .buttonStyle(CompactButtonStyle(
                foreground: self.viewModel.hasReasoningConfigForCurrentModel() ? self.theme.palette.accent : nil,
                borderColor: self.viewModel.hasReasoningConfigForCurrentModel() ? self.theme.palette.accent.opacity(0.6) : nil
            ))
            .frame(minWidth: AISettingsLayout.compactActionMinWidth, minHeight: AISettingsLayout.controlHeight)
        }
    }

    func openReasoningConfig() {
        self.viewModel.openReasoningConfig()
    }

    var addModelSection: some View {
        HStack(spacing: 8) {
            TextField("Enter model name", text: self.$viewModel.newModelName)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    if !self.viewModel.newModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.viewModel.addNewModel()
                    }
                }
            Button("Add") { self.viewModel.addNewModel() }
                .buttonStyle(CompactButtonStyle(isReady: true))
                .frame(minWidth: AISettingsLayout.compactActionMinWidth, minHeight: AISettingsLayout.controlHeight)
                .disabled(self.viewModel.newModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel") {
                self.viewModel.showingAddModel = false
                self.viewModel.newModelName = ""
            }
                .buttonStyle(CompactButtonStyle())
                .frame(minWidth: AISettingsLayout.compactActionMinWidth, minHeight: AISettingsLayout.controlHeight)
        }
        .padding(.leading, AISettingsLayout.rowLeadingIndent)
    }

    var reasoningConfigSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "brain.head.profile").foregroundStyle(self.theme.palette.accent)
                Text("Reasoning Config for \(self.viewModel.selectedModel)").font(.caption).fontWeight(.semibold)
                Spacer()
            }

            Toggle("Enable reasoning parameter", isOn: self.$viewModel.editingReasoningEnabled)
                .toggleStyle(.switch)
                .font(.caption)

            if self.viewModel.editingReasoningEnabled {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Parameter Name").font(.caption2).foregroundStyle(.secondary)
                        Picker("", selection: Binding(
                            get: {
                                // Map current value to picker options
                                if self.viewModel.editingReasoningParamName == "reasoning_effort" {
                                    return "reasoning_effort"
                                } else if self.viewModel.editingReasoningParamName == "enable_thinking" {
                                    return "enable_thinking"
                                } else {
                                    return "custom"
                                }
                            },
                            set: { newValue in
                                if newValue == "custom" {
                                    // Keep the current value for custom editing
                                    if self.viewModel.editingReasoningParamName == "reasoning_effort" ||
                                        self.viewModel.editingReasoningParamName == "enable_thinking" {
                                        self.viewModel.editingReasoningParamName = ""
                                    }
                                } else {
                                    self.viewModel.editingReasoningParamName = newValue
                                }
                            }
                        )) {
                            Text("reasoning_effort").tag("reasoning_effort")
                            Text("enable_thinking").tag("enable_thinking")
                            Text("Custom...").tag("custom")
                        }
                        .pickerStyle(.menu).labelsHidden().frame(width: 150)
                    }

                    // Show TextField for custom parameter name
                    if self.viewModel.editingReasoningParamName != "reasoning_effort" &&
                        self.viewModel.editingReasoningParamName != "enable_thinking" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Name").font(.caption2).foregroundStyle(.secondary)
                            TextField("e.g., thinking_budget", text: self.$viewModel.editingReasoningParamName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 150)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Value").font(.caption2).foregroundStyle(.secondary)
                        if self.viewModel.editingReasoningParamName == "reasoning_effort" {
                            Picker("", selection: self.$viewModel.editingReasoningParamValue) {
                                Text("none").tag("none"); Text("minimal").tag("minimal"); Text("low").tag("low"); Text("medium").tag("medium"); Text("high").tag("high")
                            }
                            .pickerStyle(.menu).labelsHidden().frame(width: 100)
                        } else if self.viewModel.editingReasoningParamName == "enable_thinking" {
                            Picker("", selection: self.$viewModel.editingReasoningParamValue) {
                                Text("true").tag("true"); Text("false").tag("false")
                            }
                            .pickerStyle(.menu).labelsHidden().frame(width: 100)
                        } else {
                            // Free-form value for custom parameters
                            TextField("value", text: self.$viewModel.editingReasoningParamValue)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button("Save") { self.saveReasoningConfig() }
                    .buttonStyle(GlassButtonStyle())
                    .frame(minWidth: AISettingsLayout.actionMinWidth, minHeight: AISettingsLayout.controlHeight)
                Button("Cancel") { self.viewModel.showingReasoningConfig = false }
                    .buttonStyle(CompactButtonStyle())
                    .frame(minWidth: AISettingsLayout.actionMinWidth, minHeight: AISettingsLayout.controlHeight)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(self.theme.palette.accent.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: 8).stroke(self.theme.palette.accent.opacity(0.2), lineWidth: 1)))
        .padding(.leading, AISettingsLayout.rowLeadingIndent)
        .transition(.opacity)
    }

    func saveReasoningConfig() {
        self.viewModel.saveReasoningConfig()
    }

    var connectionTestSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: { Task { await self.viewModel.testAPIConnection() } }) {
                    Text(self.viewModel.isTestingConnection ? "Verifying..." : "Verify Connection")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .buttonStyle(CompactButtonStyle(isReady: true))
                .frame(minWidth: AISettingsLayout.primaryActionMinWidth, minHeight: AISettingsLayout.controlHeight)
                .disabled(self.viewModel.isTestingConnection ||
                    (!self.viewModel.isLocalEndpoint(self.viewModel.openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)) &&
                        (self.viewModel.providerAPIKeys[self.viewModel.currentProvider] ?? "").isEmpty))
            }

            // Connection Status Display
            if self.viewModel.connectionStatus == .success {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.fluidGreen).font(.caption)
                    Text("Connection verified").font(.caption).foregroundStyle(Color.fluidGreen)
                }
            } else if self.viewModel.connectionStatus == .failed {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red).font(.caption)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connection failed").font(.caption).foregroundStyle(.red)
                        if !self.viewModel.connectionErrorMessage.isEmpty {
                            Text(self.viewModel.connectionErrorMessage)
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }
            } else if self.viewModel.connectionStatus == .testing {
                HStack(spacing: 8) {
                    ProgressView().frame(width: 16, height: 16)
                    Text("Verifying...").font(.caption).foregroundStyle(self.theme.palette.accent)
                }
            }

            // API Key Editor Sheet
            Color.clear.frame(height: 0)
                .sheet(isPresented: self.$viewModel.showAPIKeyEditor) {
                    self.apiKeyEditorSheet
                }
        }
    }

    var apiKeyEditorSheet: some View {
        VStack(spacing: 14) {
            Text("Enter \(self.viewModel.providerDisplayName(for: self.viewModel.selectedProviderID)) API Key")
                .font(.headline)
            SecureField("API Key (optional for local endpoints)", text: self.$viewModel.newProviderApiKey)
                .textFieldStyle(.roundedBorder).frame(width: 300)
            HStack(spacing: 12) {
                Button("Cancel") { self.viewModel.showAPIKeyEditor = false }
                    .buttonStyle(CompactButtonStyle())
                    .frame(minWidth: AISettingsLayout.actionMinWidth, minHeight: AISettingsLayout.controlHeight)
                Button("OK") {
                    let trimmedKey = self.viewModel.newProviderApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.viewModel.providerAPIKeys[self.viewModel.currentProvider] = trimmedKey
                    self.viewModel.saveProviderAPIKeys()
                    if self.viewModel.connectionStatus != .unknown {
                        self.viewModel.connectionStatus = .unknown
                        self.viewModel.connectionErrorMessage = ""
                    }
                    self.viewModel.showAPIKeyEditor = false
                }
                .buttonStyle(GlassButtonStyle())
                .frame(minWidth: AISettingsLayout.actionMinWidth, minHeight: AISettingsLayout.controlHeight)
                .disabled(!self.viewModel.isLocalEndpoint(self.viewModel.openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)) &&
                    self.viewModel.newProviderApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 350, minHeight: 150)
    }

    var addProviderSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("Provider name", text: self.$viewModel.newProviderName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                TextField("Base URL", text: self.$viewModel.newProviderBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
            }
            HStack(spacing: 8) {
                SecureField("API Key (optional for local)", text: self.$viewModel.newProviderApiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                TextField("Models (comma-separated)", text: self.$viewModel.newProviderModels)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
            }
            HStack(spacing: 8) {
                Button("Save Provider") { self.saveNewProvider() }
                    .buttonStyle(GlassButtonStyle())
                    .frame(minWidth: AISettingsLayout.actionMinWidth, minHeight: AISettingsLayout.controlHeight)
                    .disabled(self.viewModel.newProviderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        self.viewModel.newProviderBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel") {
                    self.viewModel.showingSaveProvider = false
                    self.viewModel.newProviderName = ""
                    self.viewModel.newProviderBaseURL = ""
                    self.viewModel.newProviderApiKey = ""
                    self.viewModel.newProviderModels = ""
                }
                .buttonStyle(GlassButtonStyle())
                .frame(minWidth: AISettingsLayout.actionMinWidth, minHeight: AISettingsLayout.controlHeight)
            }
        }
        .transition(.opacity)
    }

    func saveNewProvider() {
        self.viewModel.saveNewProvider()
    }
}
