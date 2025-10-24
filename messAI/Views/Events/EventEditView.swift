import SwiftUI

/**
 * PR#20.2 Phase 4: Event Edit View
 * 
 * Modal form for editing event details (creator only).
 * Supports editing title, date, time, location, and notes.
 */

struct EventEditView: View {
    @StateObject private var viewModel: EventEditViewModel
    @Environment(\.dismiss) var dismiss
    
    init(event: EventDocument, conversationId: String) {
        _viewModel = StateObject(wrappedValue: EventEditViewModel(event: event, conversationId: conversationId))
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Event Details Section
                Section(header: Text("Event Details")) {
                    TextField("Event Title", text: $viewModel.title)
                        .autocorrectionDisabled()
                    
                    TextField("Date (e.g., October 31, Monday)", text: $viewModel.date)
                        .autocorrectionDisabled()
                    
                    TextField("Time (e.g., 7PM, 2:30PM)", text: $viewModel.time)
                        .autocorrectionDisabled()
                }
                
                // Optional Details Section
                Section(header: Text("Optional Details")) {
                    TextField("Location", text: $viewModel.location)
                        .autocorrectionDisabled()
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $viewModel.notes)
                            .frame(height: 100)
                        
                        if viewModel.notes.isEmpty {
                            Text("Additional notes...")
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                }
                
                // Error Message Section
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if viewModel.hasChanges {
                            viewModel.showCancelConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task {
                                await viewModel.saveChanges()
                                dismiss()
                            }
                        }
                        .disabled(!viewModel.isValid || !viewModel.hasChanges)
                    }
                }
            }
            .confirmationDialog("Discard Changes?", isPresented: $viewModel.showCancelConfirmation) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Text("Event Edit View Preview")
        .font(.title)
}

