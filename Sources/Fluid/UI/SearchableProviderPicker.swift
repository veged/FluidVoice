//
//  SearchableProviderPicker.swift
//  Fluid
//
//  A searchable picker for selecting AI providers.
//  Uses a popover with search field for better UX when there are many providers.
//

import SwiftUI

struct SearchableProviderPicker: View {
    let builtInProviders: [(id: String, name: String)]
    let savedProviders: [SettingsStore.SavedProvider]
    @Binding var selectedProviderID: String

    @State private var searchText = ""
    @State private var isShowingPopover = false

    private var allProviders: [(id: String, name: String, isBuiltIn: Bool)] {
        var result: [(id: String, name: String, isBuiltIn: Bool)] = []

        // Add built-in providers
        for provider in self.builtInProviders {
            result.append((id: provider.id, name: provider.name, isBuiltIn: true))
        }

        // Add saved providers
        for provider in self.savedProviders {
            result.append((id: provider.id, name: provider.name, isBuiltIn: false))
        }

        return result
    }

    private var filteredProviders: [(id: String, name: String, isBuiltIn: Bool)] {
        if self.searchText.isEmpty {
            return self.allProviders
        }
        return self.allProviders.filter {
            $0.name.localizedCaseInsensitiveContains(self.searchText) ||
                $0.id.localizedCaseInsensitiveContains(self.searchText)
        }
    }

    private var selectedProviderName: String {
        if let provider = allProviders.first(where: { $0.id == selectedProviderID }) {
            return provider.name
        }
        return self.selectedProviderID.isEmpty ? "Select Provider" : self.selectedProviderID
    }

    var body: some View {
        Button(action: { self.isShowingPopover.toggle() }) {
            HStack(spacing: 4) {
                Text(self.selectedProviderName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 180, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .popover(isPresented: self.$isShowingPopover, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search providers...", text: self.$searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))

                Divider()

                // Provider list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Built-in section
                        let builtIns = self.filteredProviders.filter { $0.isBuiltIn }
                        if !builtIns.isEmpty {
                            Text("BUILT-IN")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.top, 8)
                                .padding(.bottom, 4)

                            ForEach(builtIns, id: \.id) { provider in
                                self.providerRow(provider)
                            }
                        }

                        // Saved/Custom section
                        let saved = self.filteredProviders.filter { !$0.isBuiltIn }
                        if !saved.isEmpty {
                            if !builtIns.isEmpty {
                                Divider()
                                    .padding(.vertical, 4)
                            }

                            Text("CUSTOM")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.top, 4)
                                .padding(.bottom, 4)

                            ForEach(saved, id: \.id) { provider in
                                self.providerRow(provider)
                            }
                        }

                        if self.filteredProviders.isEmpty {
                            Text("No providers match '\(self.searchText)'")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .frame(width: 240)
        }
    }

    private func providerRow(_ provider: (id: String, name: String, isBuiltIn: Bool)) -> some View {
        Button(action: {
            self.selectedProviderID = provider.id
            self.searchText = ""
            self.isShowingPopover = false
        }) {
            HStack {
                Text(provider.name)
                    .lineLimit(1)
                Spacer()
                if provider.id == self.selectedProviderID {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(provider.id == self.selectedProviderID ? Color.blue.opacity(0.1) : Color.clear)
    }
}

#Preview {
    SearchableProviderPicker(
        builtInProviders: [
            ("openai", "OpenAI"),
            ("groq", "Groq"),
            ("cerebras", "Cerebras"),
        ],
        savedProviders: [],
        selectedProviderID: .constant("openai")
    )
    .padding()
}
