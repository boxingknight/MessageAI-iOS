import SwiftUI

/// View for displaying translation options and results for a message
struct TranslationView: View {
    let messageText: String
    let messageId: String
    let conversationId: String
    
    @State private var translationState: TranslationState = .idle
    @State private var selectedLanguage: LanguageCode = .spanish
    @State private var showLanguagePicker = false
    @State private var showTranslationDetails = false
    
    // Translation preferences (would normally come from UserDefaults/persistence)
    @AppStorage("preferredTranslationLanguage") private var preferredLanguage: String = LanguageCode.spanish.rawValue
    @AppStorage("showTranslationConfidence") private var showConfidence: Bool = false
    
    private var preferredLanguageCode: LanguageCode {
        LanguageCode(rawValue: preferredLanguage) ?? .spanish
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Translation Controls
            HStack {
                // Translate Button
                Button(action: { 
                    Task { await translateMessage() }
                }) {
                    Label("Translate", systemImage: "globe")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .disabled(translationState.isLoading)
                
                Spacer()
                
                // Language Selection
                Button(action: { showLanguagePicker = true }) {
                    HStack(spacing: 4) {
                        Text(preferredLanguageCode.flagEmoji)
                        Text(preferredLanguageCode.displayName)
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // Translation Result
            if case .translating = translationState {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Translating...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            } else if case .success(let result) = translationState {
                TranslationResultView(
                    result: result,
                    showDetails: $showTranslationDetails,
                    showConfidence: showConfidence
                )
            } else if case .error(let errorMessage) = translationState {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onAppear {
            selectedLanguage = preferredLanguageCode
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(
                selectedLanguage: $selectedLanguage,
                preferredLanguage: $preferredLanguage
            )
        }
    }
    
    @MainActor
    private func translateMessage() async {
        translationState = .translating
        
        do {
            let result = try await AIService.shared.translateMessage(
                messageText,
                to: selectedLanguage,
                conversationId: conversationId,
                messageId: messageId
            )
            
            translationState = .success(result)
            
            // Update preferred language for future translations
            preferredLanguage = selectedLanguage.rawValue
            
        } catch {
            let errorMessage = (error as? AIError)?.errorDescription ?? error.localizedDescription
            translationState = .error(errorMessage)
        }
    }
}

/// View for displaying translation result with details
struct TranslationResultView: View {
    let result: TranslationResult
    @Binding var showDetails: Bool
    let showConfidence: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Translated Text
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.translatedText)
                        .font(.body)
                        .textSelection(.enabled)
                    
                    // Translation info
                    HStack(spacing: 8) {
                        Label(
                            "\(result.detectedSourceLanguage.flagEmoji) → \(result.targetLanguage.flagEmoji)",
                            systemImage: "arrow.right"
                        )
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .labelStyle(.titleOnly)
                        
                        if showConfidence {
                            Text(result.confidenceDescription)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        // Details toggle
                        Button(action: { showDetails.toggle() }) {
                            Image(systemName: showDetails ? "chevron.up" : "info.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Copy button
                Button(action: {
                    UIPasteboard.general.string = result.translatedText
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Expanded details
            if showDetails {
                Divider()
                    .padding(.vertical, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    DetailRow(
                        label: "Method", 
                        value: result.translationMethod.displayName,
                        icon: "gear"
                    )
                    DetailRow(
                        label: "Processing Time", 
                        value: result.processingTimeDescription,
                        icon: "clock"
                    )
                    DetailRow(
                        label: "Tokens Used", 
                        value: "\(result.tokensUsed)",
                        icon: "number"
                    )
                    if result.cost > 0 {
                        DetailRow(
                            label: "Cost", 
                            value: result.costDescription,
                            icon: "dollarsign.circle"
                        )
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

/// Helper view for detail rows
struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .frame(width: 12)
            Text("\(label):")
                .fontWeight(.medium)
            Text(value)
            Spacer()
        }
    }
}

/// Language picker sheet
struct LanguagePickerView: View {
    @Binding var selectedLanguage: LanguageCode
    @Binding var preferredLanguage: String
    @Environment(\.dismiss) private var dismiss
    
    private let popularLanguages = LanguageCode.popularLanguages
    private let allLanguages = LanguageCode.allCases.sorted { $0.displayName < $1.displayName }
    
    var body: some View {
        NavigationView {
            List {
                // Popular Languages Section
                Section("Popular Languages") {
                    ForEach(popularLanguages, id: \.self) { language in
                        LanguageRow(
                            language: language,
                            isSelected: selectedLanguage == language
                        ) {
                            selectLanguage(language)
                        }
                    }
                }
                
                // All Languages Section
                Section("All Languages") {
                    ForEach(allLanguages, id: \.self) { language in
                        LanguageRow(
                            language: language,
                            isSelected: selectedLanguage == language
                        ) {
                            selectLanguage(language)
                        }
                    }
                }
            }
            .navigationTitle("Translate to")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") { dismiss() }
            )
        }
    }
    
    private func selectLanguage(_ language: LanguageCode) {
        selectedLanguage = language
        preferredLanguage = language.rawValue
        dismiss()
    }
}

/// Row for displaying a language option
struct LanguageRow: View {
    let language: LanguageCode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(language.flagEmoji)
                    .font(.title3)
                
                Text(language.displayName)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct TranslationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Idle state
            TranslationView(
                messageText: "Hello! How are you doing today?",
                messageId: "msg1",
                conversationId: "conv1"
            )
            
            // With translation result
            TranslationView(
                messageText: "Hello! How are you doing today?",
                messageId: "msg2",
                conversationId: "conv1"
            )
            .onAppear {
                // Simulate translation result for preview
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

struct LanguagePickerView_Previews: PreviewProvider {
    static var previews: some View {
        LanguagePickerView(
            selectedLanguage: .constant(.spanish),
            preferredLanguage: .constant("es")
        )
    }
}
