//
//  MessageInputView.swift
//  messAI
//
//  Created for PR #9 - Chat View UI Components
//  Text input field with send button
//

import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    @Binding var isFocused: Bool  // Accept focus binding from parent
    let onSend: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool  // Internal focus state
    
    var body: some View {
        HStack(spacing: 12) {
            // Text input field
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .lineLimit(1...5)
                .focused($isTextFieldFocused)
                .submitLabel(.send)
                .onSubmit {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                    }
                }
            
            // Send button
            Button(action: {
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onSend()
                }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(sendButtonColor)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .onChange(of: isFocused) { oldValue, newValue in
            // Sync parent binding to internal focus state
            print("🎯 Parent focus changed: \(oldValue) → \(newValue)")
            isTextFieldFocused = newValue
        }
        .onChange(of: isTextFieldFocused) { oldValue, newValue in
            // Sync internal focus state to parent binding
            print("🎯 TextField focus changed: \(oldValue) → \(newValue)")
            isFocused = newValue
        }
        .onChange(of: text) { oldValue, newValue in
            // Debug: Track text changes that might affect focus
            print("🎯 Text changed: '\(oldValue)' → '\(newValue)', focus: \(isTextFieldFocused)")
        }
    }
    
    private var sendButtonColor: Color {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue
    }
}

#Preview("Empty Input") {
    VStack {
        Spacer()
        
        MessageInputView(
            text: .constant(""),
            isFocused: .constant(false),
            onSend: {
                print("Send tapped")
            }
        )
    }
}

#Preview("With Text") {
    VStack {
        Spacer()
        
        MessageInputView(
            text: .constant("Hello, how are you doing today?"),
            isFocused: .constant(true),
            onSend: {
                print("Send tapped")
            }
        )
    }
}

