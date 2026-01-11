//
//  SearchableModelPicker.swift
//  Fluid
//
//  A searchable picker for selecting AI models.
//  Uses a popover with search field for better UX.
//

import SwiftUI

struct SearchableModelPicker: View {
    let models: [String]
    @Binding var selectedModel: String
    var onRefresh: (() async -> Void)?
    var isRefreshing: Bool = false

    @State private var searchText = ""
    @State private var isShowingPopover = false

    private var filteredModels: [String] {
        if self.searchText.isEmpty {
            return self.models
        }
        return self.models.filter { $0.localizedCaseInsensitiveContains(self.searchText) }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Model button that opens popover
            Button(action: { self.isShowingPopover.toggle() }) {
                HStack(spacing: 4) {
                    Text(self.selectedModel.isEmpty ? "Select Model" : self.selectedModel)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(self.selectedModel.isEmpty ? .secondary : .primary)
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
                        TextField("Search models...", text: self.$searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))

                    Divider()

                    // Model list
                    if self.models.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("No models")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Click refresh to fetch from API")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                    } else if self.filteredModels.isEmpty {
                        Text("No models match '\(self.searchText)'")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(self.filteredModels.prefix(100), id: \.self) { model in
                                    Button(action: {
                                        self.selectedModel = model
                                        self.searchText = ""
                                        self.isShowingPopover = false
                                    }) {
                                        HStack {
                                            Text(model)
                                                .lineLimit(1)
                                            Spacer()
                                            if model == self.selectedModel {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(.blue)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .background(model == self.selectedModel ? Color.blue.opacity(0.1) : Color.clear)
                                }
                            }
                        }
                        .frame(maxHeight: 250)

                        if self.filteredModels.count > 100 {
                            Divider()
                            Text("\(self.filteredModels.count - 100) more (use search)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(6)
                        }
                    }
                }
                .frame(width: 280)
            }

            // Refresh button
            if let onRefresh = onRefresh {
                Button(action: {
                    Task { await onRefresh() }
                }) {
                    if self.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(self.isRefreshing)
                .help("Fetch models from API")
            }
        }
    }
}

#Preview {
    SearchableModelPicker(
        models: ["gpt-4.1", "gpt-4o", "gpt-3.5-turbo", "claude-3-opus", "claude-3-sonnet"],
        selectedModel: .constant("gpt-4.1"),
        onRefresh: { try? await Task.sleep(nanoseconds: 1_000_000_000) },
        isRefreshing: false
    )
    .padding()
}
