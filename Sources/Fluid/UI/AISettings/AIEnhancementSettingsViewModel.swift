import AppKit
import Combine
import Security
import SwiftUI

@MainActor
final class AIEnhancementSettingsViewModel: ObservableObject {
    let settings: SettingsStore
    let menuBarManager: MenuBarManager
    let promptTest: DictationPromptTestCoordinator

    @Published var appear: Bool = false
    @Published var openAIBaseURL: String
    @Published var enableAIProcessing: Bool {
        didSet {
            guard enableAIProcessing != oldValue else { return }
            self.settings.enableAIProcessing = enableAIProcessing
            self.menuBarManager.aiProcessingEnabled = enableAIProcessing
        }
    }

    // Model Management
    @Published var availableModelsByProvider: [String: [String]] = [:]
    @Published var selectedModelByProvider: [String: String] = [:]
    @Published var availableModels: [String] = ["gpt-4.1"]
    @Published var selectedModel: String = "gpt-4.1" {
        didSet {
            guard selectedModel != "__ADD_MODEL__" else { return }
            self.selectedModelByProvider[self.currentProvider] = selectedModel
            self.settings.selectedModelByProvider = self.selectedModelByProvider
        }
    }
    @Published var showingAddModel: Bool = false
    @Published var newModelName: String = ""
    @Published var isFetchingModels: Bool = false
    @Published var fetchModelsError: String? = nil

    // Reasoning Configuration
    @Published var showingReasoningConfig: Bool = false
    @Published var editingReasoningParamName: String = "reasoning_effort"
    @Published var editingReasoningParamValue: String = "low"
    @Published var editingReasoningEnabled: Bool = false

    // Provider Management
    @Published var providerAPIKeys: [String: String] = [:]
    @Published var currentProvider: String = "openai"
    @Published var savedProviders: [SettingsStore.SavedProvider] = []
    @Published var selectedProviderID: String {
        didSet {
            self.settings.selectedProviderID = selectedProviderID
        }
    }

    // Connection Testing
    @Published var isTestingConnection: Bool = false
    @Published var connectionStatus: AIConnectionStatus = .unknown
    @Published var connectionErrorMessage: String = ""

    // UI State
    @Published var showHelp: Bool = false
    @Published var showingSaveProvider: Bool = false
    @Published var showAPIKeyEditor: Bool = false
    @Published var showingEditProvider: Bool = false

    // Provider Form State
    @Published var newProviderName: String = ""
    @Published var newProviderBaseURL: String = ""
    @Published var newProviderApiKey: String = ""
    @Published var newProviderModels: String = ""
    @Published var editProviderName: String = ""
    @Published var editProviderBaseURL: String = ""

    // Keychain State
    @Published var showKeychainPermissionAlert: Bool = false
    @Published var keychainPermissionMessage: String = ""

    // Dictation Prompt Profiles UI
    @Published var promptEditorMode: PromptEditorMode? = nil
    @Published var draftPromptName: String = ""
    @Published var draftPromptText: String = ""
    @Published var promptEditorSessionID: UUID = .init()

    // Prompt Deletion UI
    @Published var showingDeletePromptConfirm: Bool = false
    @Published var pendingDeletePromptID: String? = nil
    @Published var pendingDeletePromptName: String = ""

    init(settings: SettingsStore, menuBarManager: MenuBarManager, promptTest: DictationPromptTestCoordinator) {
        self.settings = settings
        self.menuBarManager = menuBarManager
        self.promptTest = promptTest
        self.openAIBaseURL = ModelRepository.shared.defaultBaseURL(for: "openai")
        self.enableAIProcessing = settings.enableAIProcessing
        self.selectedProviderID = settings.selectedProviderID
    }

    func onAppear() {
        self.appear = true
        self.loadSettings()
    }

    // MARK: - Load Settings

    func loadSettings() {
        self.selectedProviderID = self.settings.selectedProviderID

        self.enableAIProcessing = self.settings.enableAIProcessing
        self.availableModelsByProvider = self.settings.availableModelsByProvider
        self.selectedModelByProvider = self.settings.selectedModelByProvider
        self.providerAPIKeys = self.settings.providerAPIKeys
        self.savedProviders = self.settings.savedProviders

        // Normalize provider keys
        var normalized: [String: [String]] = [:]
        for (key, models) in self.availableModelsByProvider {
            let lower = key.lowercased()
            let newKey: String
            // Use ModelRepository to correctly identify ALL built-in providers
            if ModelRepository.shared.isBuiltIn(lower) {
                newKey = lower
            } else {
                newKey = key.hasPrefix("custom:") ? key : "custom:\(key)"
            }
            let clean = Array(Set(models.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })).sorted()
            if !clean.isEmpty { normalized[newKey] = clean }
        }
        self.availableModelsByProvider = normalized
        self.settings.availableModelsByProvider = normalized

        // Normalize selected model by provider
        var normalizedSel: [String: String] = [:]
        for (key, model) in self.selectedModelByProvider {
            let lower = key.lowercased()
            // Use ModelRepository to correctly identify ALL built-in providers
            let newKey: String = ModelRepository.shared.isBuiltIn(lower) ? lower :
                (key.hasPrefix("custom:") ? key : "custom:\(key)")
            if let list = normalized[newKey], list.contains(model) { normalizedSel[newKey] = model }
        }
        self.selectedModelByProvider = normalizedSel
        self.settings.selectedModelByProvider = normalizedSel

        // Determine initial model list AND set baseURL BEFORE calling updateCurrentProvider
        if let saved = savedProviders.first(where: { $0.id == selectedProviderID }) {
            let key = self.providerKey(for: self.selectedProviderID)
            let stored = self.availableModelsByProvider[key]
            self.availableModels = saved.models.isEmpty ? (stored ?? []) : saved.models
            self.openAIBaseURL = saved.baseURL // Set this FIRST
        } else if ModelRepository.shared.isBuiltIn(self.selectedProviderID) {
            // Handle all built-in providers using ModelRepository
            self.openAIBaseURL = ModelRepository.shared.defaultBaseURL(for: self.selectedProviderID)
            let key = self.selectedProviderID
            self.availableModels = self.availableModelsByProvider[key] ?? ModelRepository.shared.defaultModels(for: key)
        } else {
            self.availableModels = ModelRepository.shared.defaultModels(for: self.providerKey(for: self.selectedProviderID))
        }

        // NOW update currentProvider after openAIBaseURL is set correctly
        self.updateCurrentProvider()

        // Restore selected model using the correct currentProvider
        // If no models available, clear selection
        if self.availableModels.isEmpty {
            self.selectedModel = ""
        } else if let sel = selectedModelByProvider[currentProvider], availableModels.contains(sel) {
            self.selectedModel = sel
        } else if let first = availableModels.first {
            self.selectedModel = first
        }

        DebugLogger.shared.debug(
            "loadSettings complete: provider=\(self.selectedProviderID), currentProvider=\(self.currentProvider), model=\(self.selectedModel), baseURL=\(self.openAIBaseURL)",
            source: "AISettingsView"
        )
    }

    // MARK: - Helper Functions

    func providerKey(for providerID: String) -> String {
        // Built-in providers use their ID directly
        if ModelRepository.shared.isBuiltIn(providerID) { return providerID }
        // Custom providers get "custom:" prefix (if not already present)
        if providerID.hasPrefix("custom:") { return providerID }
        return providerID.isEmpty ? self.currentProvider : "custom:\(providerID)"
    }

    func providerDisplayName(for providerID: String) -> String {
        switch providerID {
        case "openai": return "OpenAI"
        case "groq": return "Groq"
        case "apple-intelligence": return "Apple Intelligence"
        default:
            return self.savedProviders.first(where: { $0.id == providerID })?.name ?? providerID.capitalized
        }
    }

    func saveProviderAPIKeys() {
        self.settings.providerAPIKeys = self.providerAPIKeys
    }

    func updateCurrentProvider() {
        let url = self.openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.contains("openai.com") { self.currentProvider = "openai"; return }
        if url.contains("groq.com") { self.currentProvider = "groq"; return }
        self.currentProvider = self.providerKey(for: self.selectedProviderID)
    }

    func saveSavedProviders() {
        self.settings.savedProviders = self.savedProviders
    }

    func isLocalEndpoint(_ urlString: String) -> Bool {
        return ModelRepository.shared.isLocalEndpoint(urlString)
    }

    func hasReasoningConfigForCurrentModel() -> Bool {
        let pKey = self.providerKey(for: self.selectedProviderID)
        if self.settings.hasCustomReasoningConfig(forModel: self.selectedModel, provider: pKey) {
            if let config = self.settings.getReasoningConfig(forModel: selectedModel, provider: pKey) {
                return config.isEnabled
            }
        }
        return self.settings.isReasoningModel(self.selectedModel)
    }

    func addNewModel() {
        guard !self.newModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let modelName = self.newModelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = self.providerKey(for: self.selectedProviderID)

        var list = self.availableModelsByProvider[key] ?? self.availableModels
        if !list.contains(modelName) {
            list.append(modelName)
            self.availableModelsByProvider[key] = list
            self.settings.availableModelsByProvider = self.availableModelsByProvider

            if let providerIndex = savedProviders.firstIndex(where: { $0.id == selectedProviderID }) {
                let updatedProvider = SettingsStore.SavedProvider(
                    id: self.savedProviders[providerIndex].id,
                    name: self.savedProviders[providerIndex].name,
                    baseURL: self.savedProviders[providerIndex].baseURL,
                    models: list
                )
                self.savedProviders[providerIndex] = updatedProvider
                self.saveSavedProviders()
            }

            self.availableModels = list
            self.selectedModel = modelName
            self.selectedModelByProvider[key] = modelName
            self.settings.selectedModelByProvider = self.selectedModelByProvider
        }

        self.showingAddModel = false
        self.newModelName = ""
    }

    // MARK: - Keychain Access Helpers

    private enum KeychainAccessCheckResult {
        case granted
        case denied(OSStatus)
    }

    func handleAPIKeyButtonTapped() {
        switch self.probeKeychainAccess() {
        case .granted:
            self.newProviderApiKey = self.providerAPIKeys[self.currentProvider] ?? ""
            self.showAPIKeyEditor = true
        case let .denied(status):
            self.keychainPermissionMessage = self.keychainPermissionExplanation(for: status)
            self.showKeychainPermissionAlert = true
        }
    }

    private func probeKeychainAccess() -> KeychainAccessCheckResult {
        let service = "com.fluidvoice.provider-api-keys"
        let account = "fluidApiKeys"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        var readQuery = query
        readQuery[kSecReturnData as String] = kCFBooleanTrue
        readQuery[kSecMatchLimit as String] = kSecMatchLimitOne

        let readStatus = SecItemCopyMatching(readQuery as CFDictionary, nil)
        switch readStatus {
        case errSecSuccess:
            return .granted
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            addQuery[kSecValueData as String] = (try? JSONEncoder().encode([String: String]())) ?? Data()

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus == errSecSuccess {
                SecItemDelete(query as CFDictionary)
            }

            switch addStatus {
            case errSecSuccess, errSecDuplicateItem:
                return .granted
            case errSecAuthFailed, errSecInteractionNotAllowed, errSecUserCanceled:
                return .denied(addStatus)
            default:
                return .denied(addStatus)
            }
        case errSecAuthFailed, errSecInteractionNotAllowed, errSecUserCanceled:
            return .denied(readStatus)
        default:
            return .denied(readStatus)
        }
    }

    private func keychainPermissionExplanation(for status: OSStatus) -> String {
        var message = "FluidVoice stores provider API keys securely in your macOS Keychain but does not currently have permission to access it."
        if let detail = SecCopyErrorMessageString(status, nil) as String? {
            message += "\n\nmacOS reported: \(detail) (\(status))"
        }
        message += "\n\nClick \"Always Allow\" when the Keychain prompt appears, or open Keychain Access > login > Passwords, locate the FluidVoice entry, and grant access."
        return message
    }

    func presentKeychainAccessAlert(message: String) {
        let msg = message.isEmpty
            ? "FluidVoice stores provider API keys securely in your macOS Keychain. Please grant access by choosing \"Always Allow\" when prompted."
            : message

        let alert = NSAlert()
        alert.messageText = "Keychain Access Required"
        alert.informativeText = msg
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Keychain Access")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.keychainaccess") {
                NSWorkspace.shared.openApplication(
                    at: appURL,
                    configuration: NSWorkspace.OpenConfiguration(),
                    completionHandler: nil
                )
            }
        }
    }

    // MARK: - API Connection Testing

    func testAPIConnection() async {
        guard !self.isTestingConnection else { return }

        let apiKey = self.providerAPIKeys[self.currentProvider] ?? ""
        let baseURL = self.openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let isLocal = self.isLocalEndpoint(baseURL)

        if isLocal {
            guard !baseURL.isEmpty else {
                await MainActor.run {
                    self.connectionStatus = .failed
                    self.connectionErrorMessage = "Base URL is required"
                }
                return
            }
        } else {
            guard !apiKey.isEmpty, !baseURL.isEmpty else {
                await MainActor.run {
                    self.connectionStatus = .failed
                    self.connectionErrorMessage = "API key and base URL are required"
                }
                return
            }
        }

        await MainActor.run {
            self.isTestingConnection = true
            self.connectionStatus = .testing
            self.connectionErrorMessage = ""
        }

        do {
            let endpoint = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let fullURL: String
            if endpoint.contains("/chat/completions") || endpoint.contains("/api/chat") || endpoint
                .contains("/api/generate")
            {
                fullURL = endpoint
            } else {
                fullURL = endpoint + "/chat/completions"
            }

            // Debug logging to diagnose test failures
            DebugLogger.shared.debug(
                "testAPIConnection: provider=\(self.selectedProviderID), model=\(self.selectedModel), baseURL=\(endpoint), fullURL=\(fullURL)",
                source: "AISettingsView"
            )

            guard let url = URL(string: fullURL) else {
                await MainActor.run {
                    self.connectionStatus = .failed
                    self.connectionErrorMessage = "Invalid Base URL format"
                }
                return
            }

            let provKey = self.providerKey(for: self.selectedProviderID)
            let reasoningConfig = self.settings.getReasoningConfig(forModel: self.selectedModel, provider: provKey)

            let usesMaxCompletionTokens = self.settings.isReasoningModel(self.selectedModel)

            var requestDict: [String: Any] = [
                "model": selectedModel,
                "messages": [["role": "user", "content": "test"]],
            ]

            if usesMaxCompletionTokens {
                requestDict["max_completion_tokens"] = 50
            } else {
                requestDict["max_tokens"] = 50
            }

            if let config = reasoningConfig, config.isEnabled {
                if config.parameterName == "enable_thinking" {
                    requestDict[config.parameterName] = config.parameterValue == "true"
                } else {
                    requestDict[config.parameterName] = config.parameterValue
                }
            }

            guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict, options: []) else {
                await MainActor.run {
                    self.connectionStatus = .failed
                    self.connectionErrorMessage = "Failed to create test payload"
                }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = jsonData
            request.timeoutInterval = 12

            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 200, httpResponse.statusCode < 300 {
                await MainActor.run {
                    self.connectionStatus = .success
                    self.connectionErrorMessage = ""
                }
            } else if let httpResponse = response as? HTTPURLResponse {
                await MainActor.run {
                    self.connectionStatus = .failed
                    self.connectionErrorMessage = "HTTP \(httpResponse.statusCode)"
                }
            } else {
                await MainActor.run {
                    self.connectionStatus = .failed
                    self.connectionErrorMessage = "Unexpected response"
                }
            }
        } catch {
            await MainActor.run {
                self.connectionStatus = .failed
                self.connectionErrorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            self.isTestingConnection = false
        }
    }

    // MARK: - Provider/Model Handling

    func handleProviderChange(_ newValue: String) {
        // Handle Apple Intelligence specially (no base URL)
        if newValue == "apple-intelligence" {
            self.openAIBaseURL = ""
            self.updateCurrentProvider()
            self.availableModels = ["System Model"]
            self.selectedModel = "System Model"
            return
        }

        // Check if it's a built-in provider
        if ModelRepository.shared.isBuiltIn(newValue) {
            self.openAIBaseURL = ModelRepository.shared.defaultBaseURL(for: newValue)
            self.updateCurrentProvider()
            let key = newValue
            self.availableModels = self.availableModelsByProvider[key] ?? ModelRepository.shared.defaultModels(for: key)
            // If no models available, clear selection; otherwise use saved or first
            if self.availableModels.isEmpty {
                self.selectedModel = ""
            } else {
                self.selectedModel = self.selectedModelByProvider[key] ?? self.availableModels.first ?? ""
            }
            return
        }

        // Handle saved/custom providers
        if let provider = savedProviders.first(where: { $0.id == newValue }) {
            self.openAIBaseURL = provider.baseURL
            self.updateCurrentProvider()
            let key = self.providerKey(for: newValue)
            self.availableModels = provider.models.isEmpty ? (self.availableModelsByProvider[key] ?? []) : provider.models
            self.selectedModel = self.selectedModelByProvider[key] ?? self.availableModels.first ?? self.selectedModel
        }
    }

    func startEditingProvider() {
        // Handle built-in providers
        if ModelRepository.shared.isBuiltIn(self.selectedProviderID) {
            self.editProviderName = ModelRepository.shared.displayName(for: self.selectedProviderID)
            self.editProviderBaseURL = self.openAIBaseURL // Use current URL (may have been customized)
            self.showingEditProvider = true
            return
        }
        // Handle saved/custom providers
        if let provider = savedProviders.first(where: { $0.id == selectedProviderID }) {
            self.editProviderName = provider.name
            self.editProviderBaseURL = provider.baseURL
            self.showingEditProvider = true
        }
    }

    func deleteCurrentProvider() {
        self.savedProviders.removeAll { $0.id == self.selectedProviderID }
        self.saveSavedProviders()
        let key = self.providerKey(for: self.selectedProviderID)
        self.availableModelsByProvider.removeValue(forKey: key)
        self.selectedModelByProvider.removeValue(forKey: key)
        self.providerAPIKeys.removeValue(forKey: key)
        self.saveProviderAPIKeys()
        self.settings.availableModelsByProvider = self.availableModelsByProvider
        self.settings.selectedModelByProvider = self.selectedModelByProvider
        // Reset to OpenAI
        self.selectedProviderID = "openai"
        self.openAIBaseURL = ModelRepository.shared.defaultBaseURL(for: "openai")
        self.updateCurrentProvider()
        // Use fetched models if available, fall back to defaults (same logic as handleProviderChange)
        self.availableModels = self.availableModelsByProvider["openai"] ?? ModelRepository.shared.defaultModels(for: "openai")
        self.selectedModel = self.selectedModelByProvider["openai"] ?? self.availableModels.first ?? ""
    }

    func saveEditedProvider() {
        let name = self.editProviderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = self.editProviderBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !base.isEmpty else { return }

        // For built-in providers, we just update the base URL (name is not editable)
        if ModelRepository.shared.isBuiltIn(self.selectedProviderID) {
            self.openAIBaseURL = base
            self.updateCurrentProvider()
            self.showingEditProvider = false
            self.editProviderName = ""; self.editProviderBaseURL = ""
            return
        }

        // For saved/custom providers, update the full provider record
        if let providerIndex = savedProviders.firstIndex(where: { $0.id == selectedProviderID }) {
            let oldProvider = self.savedProviders[providerIndex]
            let updatedProvider = SettingsStore.SavedProvider(id: oldProvider.id, name: name, baseURL: base, models: oldProvider.models)
            self.savedProviders[providerIndex] = updatedProvider
            self.saveSavedProviders()
            self.openAIBaseURL = base
            self.updateCurrentProvider()
        }
        self.showingEditProvider = false
        self.editProviderName = ""; self.editProviderBaseURL = ""
    }

    func deleteSelectedModel() {
        let key = self.providerKey(for: self.selectedProviderID)
        var list = self.availableModelsByProvider[key] ?? self.availableModels
        list.removeAll { $0 == self.selectedModel }
        if list.isEmpty { list = ModelRepository.shared.defaultModels(for: key) }
        self.availableModelsByProvider[key] = list
        self.settings.availableModelsByProvider = self.availableModelsByProvider

        if let providerIndex = savedProviders.firstIndex(where: { $0.id == selectedProviderID }) {
            let updatedProvider = SettingsStore.SavedProvider(
                id: self.savedProviders[providerIndex].id,
                name: self.savedProviders[providerIndex].name,
                baseURL: self.savedProviders[providerIndex].baseURL,
                models: list
            )
            self.savedProviders[providerIndex] = updatedProvider
            self.saveSavedProviders()
        }

        self.availableModels = list
        self.selectedModel = list.first ?? ""
        self.selectedModelByProvider[key] = self.selectedModel
        self.settings.selectedModelByProvider = self.selectedModelByProvider
    }

    func fetchModelsForCurrentProvider() async {
        self.isFetchingModels = true
        self.fetchModelsError = nil
        defer { self.isFetchingModels = false }

        let baseURL = self.openAIBaseURL
        let key = self.providerKey(for: self.selectedProviderID)
        let apiKey = self.providerAPIKeys[key] ?? self.providerAPIKeys[self.selectedProviderID]

        do {
            let models = try await ModelRepository.shared.fetchModels(
                for: self.selectedProviderID,
                baseURL: baseURL,
                apiKey: apiKey
            )

            // Update state on main thread
            await MainActor.run {
                if models.isEmpty {
                    // Keep existing models if fetch returned empty
                    self.fetchModelsError = "No models returned from API"
                } else {
                    self.availableModels = models
                    self.availableModelsByProvider[key] = models
                    self.settings.availableModelsByProvider = self.availableModelsByProvider

                    if let providerIndex = self.savedProviders.firstIndex(where: { $0.id == self.selectedProviderID }) {
                        let updatedProvider = SettingsStore.SavedProvider(
                            id: self.savedProviders[providerIndex].id,
                            name: self.savedProviders[providerIndex].name,
                            baseURL: self.savedProviders[providerIndex].baseURL,
                            models: models
                        )
                        self.savedProviders[providerIndex] = updatedProvider
                        self.saveSavedProviders()
                    }

                    // Select first model if current selection not in list
                    if !models.contains(self.selectedModel) {
                        self.selectedModel = models.first ?? ""
                        self.selectedModelByProvider[key] = self.selectedModel
                        self.settings.selectedModelByProvider = self.selectedModelByProvider
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.fetchModelsError = error.localizedDescription
            }
        }
    }

    func openReasoningConfig() {
        let pKey = self.providerKey(for: self.selectedProviderID)
        if let config = self.settings.getReasoningConfig(forModel: selectedModel, provider: pKey) {
            self.editingReasoningParamName = config.parameterName
            self.editingReasoningParamValue = config.parameterValue
            self.editingReasoningEnabled = config.isEnabled
        } else {
            let modelLower = self.selectedModel.lowercased()
            if modelLower.hasPrefix("gpt-5") || modelLower.hasPrefix("o1") || modelLower.hasPrefix("o3") || modelLower.contains("gpt-oss") {
                self.editingReasoningParamName = "reasoning_effort"; self.editingReasoningParamValue = "low"; self.editingReasoningEnabled = true
            } else if modelLower.contains("deepseek"), modelLower.contains("reasoner") {
                self.editingReasoningParamName = "enable_thinking"; self.editingReasoningParamValue = "true"; self.editingReasoningEnabled = true
            } else {
                self.editingReasoningParamName = "reasoning_effort"; self.editingReasoningParamValue = "low"; self.editingReasoningEnabled = false
            }
        }
        self.showingReasoningConfig = true
    }

    func saveReasoningConfig() {
        let pKey = self.providerKey(for: self.selectedProviderID)
        if self.editingReasoningEnabled {
            let config = SettingsStore.ModelReasoningConfig(
                parameterName: self.editingReasoningParamName,
                parameterValue: self.editingReasoningParamValue,
                isEnabled: true
            )
            self.settings.setReasoningConfig(config, forModel: self.selectedModel, provider: pKey)
        } else {
            let config = SettingsStore.ModelReasoningConfig(parameterName: "", parameterValue: "", isEnabled: false)
            self.settings.setReasoningConfig(config, forModel: self.selectedModel, provider: pKey)
        }
        self.showingReasoningConfig = false
    }

    func saveNewProvider() {
        let name = self.newProviderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = self.newProviderBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let api = self.newProviderApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !base.isEmpty else { return }

        let modelsList = self.newProviderModels.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let models = modelsList.isEmpty ? ModelRepository.shared.defaultModels(for: "openai") : modelsList

        let newProvider = SettingsStore.SavedProvider(name: name, baseURL: base, models: models)
        self.savedProviders.removeAll { $0.name.lowercased() == name.lowercased() }
        self.savedProviders.append(newProvider)
        self.saveSavedProviders()

        let key = self.providerKey(for: newProvider.id)
        self.providerAPIKeys[key] = api
        self.availableModelsByProvider[key] = models
        self.selectedModelByProvider[key] = models.first ?? self.selectedModel
        self.settings.providerAPIKeys = self.providerAPIKeys
        self.settings.availableModelsByProvider = self.availableModelsByProvider
        self.settings.selectedModelByProvider = self.selectedModelByProvider

        self.selectedProviderID = newProvider.id
        self.openAIBaseURL = base
        self.updateCurrentProvider()
        self.availableModels = models
        self.selectedModel = models.first ?? self.selectedModel

        self.showingSaveProvider = false
        self.newProviderName = ""; self.newProviderBaseURL = ""; self.newProviderApiKey = ""; self.newProviderModels = ""
    }

    // MARK: - Prompt Editor / Test

    func promptPreview(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Empty prompt" }
        let singleLine = trimmed.replacingOccurrences(of: "\n", with: " ")
        return singleLine.count > 120 ? String(singleLine.prefix(120)) + "…" : singleLine
    }

    /// Combine a user-visible body with the hidden base prompt to ensure role/intent is always present.
    func combinedDraftPrompt(_ text: String) -> String {
        let body = SettingsStore.stripBaseDictationPrompt(from: text)
        return SettingsStore.combineBasePrompt(with: body)
    }

    func requestDeletePrompt(_ profile: SettingsStore.DictationPromptProfile) {
        self.pendingDeletePromptID = profile.id
        self.pendingDeletePromptName = profile.name.isEmpty ? "Untitled Prompt" : profile.name
        self.showingDeletePromptConfirm = true
    }

    func clearPendingDeletePrompt() {
        self.showingDeletePromptConfirm = false
        self.pendingDeletePromptID = nil
        self.pendingDeletePromptName = ""
    }

    func deletePendingPrompt() {
        guard let id = self.pendingDeletePromptID else {
            self.clearPendingDeletePrompt()
            return
        }

        // Remove profile
        var profiles = self.settings.dictationPromptProfiles
        profiles.removeAll { $0.id == id }
        self.settings.dictationPromptProfiles = profiles

        // If the deleted profile was active, reset to Default
        if self.settings.selectedDictationPromptID == id {
            self.settings.selectedDictationPromptID = nil
        }

        self.clearPendingDeletePrompt()
    }

    func isAIPostProcessingConfiguredForDictation() -> Bool {
        DictationAIPostProcessingGate.isConfigured()
    }

    func openDefaultPromptViewer() {
        self.draftPromptName = "Default"
        if let override = self.settings.defaultDictationPromptOverride {
            self.draftPromptText = SettingsStore.stripBaseDictationPrompt(from: override)
        } else {
            self.draftPromptText = SettingsStore.defaultDictationPromptBodyText()
        }
        self.promptEditorSessionID = UUID()
        self.promptEditorMode = .defaultPrompt
    }

    func openNewPromptEditor() {
        self.draftPromptName = "New Prompt"
        self.draftPromptText = ""
        self.promptEditorSessionID = UUID()
        self.promptEditorMode = .newPrompt
    }

    func openEditor(for profile: SettingsStore.DictationPromptProfile) {
        self.draftPromptName = profile.name
        self.draftPromptText = SettingsStore.stripBaseDictationPrompt(from: profile.prompt)
        self.promptEditorSessionID = UUID()
        self.promptEditorMode = .edit(promptID: profile.id)
    }

    func closePromptEditor() {
        self.promptEditorMode = nil
        self.draftPromptName = ""
        self.draftPromptText = ""
        self.promptTest.deactivate()
    }

    func savePromptEditor(mode: PromptEditorMode) {
        // Default prompt is non-deletable; save it via the optional override (empty is allowed).
        if mode.isDefault {
            let body = SettingsStore.stripBaseDictationPrompt(from: self.draftPromptText)
            self.settings.defaultDictationPromptOverride = body
            self.closePromptEditor()
            return
        }

        let name = self.draftPromptName.trimmingCharacters(in: .whitespacesAndNewlines)
        let promptBody = SettingsStore.stripBaseDictationPrompt(from: self.draftPromptText)

        var profiles = self.settings.dictationPromptProfiles
        let now = Date()

        if let id = mode.editingPromptID,
           let idx = profiles.firstIndex(where: { $0.id == id })
        {
            var updated = profiles[idx]
            updated.name = name
            updated.prompt = promptBody
            updated.updatedAt = now
            profiles[idx] = updated
        } else {
            let newProfile = SettingsStore.DictationPromptProfile(name: name, prompt: promptBody, createdAt: now, updatedAt: now)
            profiles.append(newProfile)
        }

        self.settings.dictationPromptProfiles = profiles
        self.closePromptEditor()
    }
}
