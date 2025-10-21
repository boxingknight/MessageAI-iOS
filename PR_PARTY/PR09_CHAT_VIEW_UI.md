# PR#9: Chat View - UI Components

**Estimated Time:** 3-4 hours  
**Complexity:** HIGH  
**Dependencies:** PR #4 (Models), PR #5 (ChatService), PR #6 (Persistence), PR #7 (ChatListView)

---

## Overview

### What We're Building

The Chat View is the **core messaging interface** where users view conversation history and send new messages. Think: WhatsApp chat screen, iMessage conversation view. This PR builds the UI components only—the visual layer that displays messages, input field, and conversation header. Real-time messaging logic comes in PR #10.

Key components:
- **ChatView**: Main container with NavigationStack, message list, input bar
- **MessageBubbleView**: Individual message bubble (sender on right, recipient on left)
- **MessageInputView**: Text field with send button at bottom
- **TypingIndicatorView**: "User is typing..." animation
- **ChatHeaderView**: Contact name, online status, profile picture

### Why It Matters

This is the **heart of the messaging app**—where users spend 90% of their time. A poor chat UI = users abandon the app. Critical requirements:
- Messages must be readable and clearly attributed
- Sending messages must feel instant (optimistic UI in PR #10)
- Keyboard handling must be flawless
- Scrolling must be smooth (60fps with 1000+ messages)
- Works on all iPhone screen sizes

**User expectation**: "This should feel just like iMessage or WhatsApp."

### Success in One Sentence

"This PR is successful when users can open a conversation, see message history in bubbles, type in the input field, and tap send—creating a complete chat UI that feels production-ready."

---

## Technical Design

### Architecture Decisions

#### Decision 1: Message List Implementation

**Options Considered:**
1. **ScrollView + LazyVStack** - Standard SwiftUI pattern
   - Pros: Simple, efficient, lazy loading
   - Cons: Manual scroll position management
   
2. **List** - SwiftUI List component
   - Pros: Built-in scroll, selection, swipe actions
   - Cons: Styling limitations, harder to customize bubbles

3. **ScrollViewReader + ForEach** - Programmatic scrolling
   - Pros: Precise scroll control, scroll to specific message
   - Cons: More complex, manual ID tracking

**Chosen:** ScrollView + LazyVStack + ScrollViewReader (Option 1 + 3 hybrid)

**Rationale:**
- LazyVStack for performance (only renders visible messages)
- ScrollViewReader enables "scroll to bottom" after send
- Full styling control for bubble layout
- Standard messaging app pattern

**Trade-offs:**
- Gain: Full control, smooth performance
- Lose: Manual scroll management (acceptable)

**Implementation Pattern:**
```swift
ScrollViewReader { proxy in
    ScrollView {
        LazyVStack(spacing: 8) {
            ForEach(messages) { message in
                MessageBubbleView(message: message)
                    .id(message.id)
            }
        }
    }
    .onChange(of: messages.count) { _ in
        scrollToBottom(proxy: proxy)
    }
}
```

---

#### Decision 2: Message Bubble Layout Strategy

**Options Considered:**
1. **HStack with Spacer** - Conditional leading/trailing spacer
   - Pros: Simple, flexible
   - Cons: Can be verbose with multiple conditions
   
2. **Alignment + Frame** - Use frame alignment
   - Pros: Clean code, SwiftUI-native
   - Cons: Less explicit, harder to debug

3. **Custom Layout** - GeometryReader for precise positioning
   - Pros: Full control
   - Cons: Overkill for simple left/right alignment

**Chosen:** HStack with Conditional Spacer (Option 1)

**Rationale:**
- Clear, explicit intent (if sent by me → align right)
- Easy to understand and modify
- Standard SwiftUI pattern
- No performance overhead

**Code Pattern:**
```swift
HStack {
    if message.isFromCurrentUser {
        Spacer(minLength: 60) // Leave space on left
    }
    
    // Message bubble
    VStack(alignment: message.isFromCurrentUser ? .trailing : .leading) {
        Text(message.text)
            .padding()
            .background(message.isFromCurrentUser ? Color.blue : Color.gray.opacity(0.2))
            .cornerRadius(16)
    }
    
    if !message.isFromCurrentUser {
        Spacer(minLength: 60) // Leave space on right
    }
}
```

---

#### Decision 3: Keyboard Handling Approach

**Options Considered:**
1. **iOS Native (Keyboard Avoidance)** - SwiftUI automatic handling
   - Pros: Zero code, works automatically
   - Cons: Doesn't always work perfectly
   
2. **KeyboardObserver + GeometryReader** - Manual offset adjustment
   - Pros: Full control, reliable
   - Cons: More code, keyboard notifications

3. **Third-Party Library** - IQKeyboardManager, etc.
   - Pros: Battle-tested, feature-rich
   - Cons: External dependency, not SwiftUI-native

**Chosen:** iOS Native + Manual Adjustments (Option 1 with Option 2 fallback)

**Rationale:**
- iOS 16+ has improved keyboard avoidance
- Start with native, add manual adjustment if needed
- Keep codebase pure SwiftUI
- Avoid external dependencies for MVP

**Implementation:**
```swift
ChatView()
    .ignoresSafeArea(.keyboard, edges: .bottom) // Let input field stick to keyboard
```

If issues arise:
```swift
@State private var keyboardHeight: CGFloat = 0

// Subscribe to keyboard notifications
// Adjust padding based on keyboardHeight
```

---

#### Decision 4: Message Input Design

**Options Considered:**
1. **TextField + Button (Horizontal)** - Side-by-side layout
   - Pros: Simple, familiar, always visible
   - Cons: Limited space for text field
   
2. **TextEditor + Floating Button** - Multi-line with overlay
   - Pros: Supports long messages
   - Cons: More complex layout

3. **TextField + Adaptive Button** - Button appears when text entered
   - Pros: Maximizes text field space
   - Cons: Button disappearing is confusing

**Chosen:** TextField + Always-Visible Button (Option 1)

**Rationale:**
- Most messaging apps use this pattern (WhatsApp, iMessage)
- Clear, predictable UI (send button always there)
- TextField auto-expands with keyboard
- Can upgrade to TextEditor in future PR if needed

**Layout:**
```swift
HStack(spacing: 12) {
    TextField("Message", text: $messageText)
        .textFieldStyle(.roundedBorder)
        .frame(minHeight: 36)
    
    Button(action: sendMessage) {
        Image(systemName: "arrow.up.circle.fill")
            .font(.largeTitle)
            .foregroundColor(messageText.isEmpty ? .gray : .blue)
    }
    .disabled(messageText.isEmpty)
}
.padding()
.background(Color(.systemBackground))
```

---

### Component Hierarchy

```
ChatView (Main Container)
├── NavigationStack
│   ├── ChatHeaderView (Custom Title View)
│   │   ├── AsyncImage (Profile Picture)
│   │   ├── VStack
│   │   │   ├── Text (Contact Name)
│   │   │   └── Text ("Active now" / "Last seen X")
│   │   └── OnlineIndicator (Green Dot)
│   │
│   └── VStack
│       ├── ScrollViewReader
│       │   └── ScrollView
│       │       └── LazyVStack
│       │           ├── ForEach(messages)
│       │           │   └── MessageBubbleView
│       │           │       ├── VStack
│       │           │       │   ├── Text (Message Text)
│       │           │       │   └── HStack (Timestamp + Status)
│       │           │       └── Background (Bubble Shape)
│       │           │
│       │           └── TypingIndicatorView (Conditional)
│       │               └── HStack (Animated Dots)
│       │
│       └── MessageInputView (Sticky Bottom)
│           └── HStack
│               ├── TextField
│               └── Button (Send)
```

---

### Data Flow

**Loading Messages:**
```
ChatView.onAppear
    └─> ChatViewModel.loadMessages()
        └─> LocalDataManager.fetchMessages(conversationId)
            ├─> Load from Core Data (instant)
            └─> Display in UI
        
        └─> ChatService.fetchMessages(conversationId) [PR #10]
            └─> Firestore snapshot listener
                └─> New messages → Update ViewModel
                    └─> UI auto-updates (@Published)
```

**Sending Message (UI Only - PR #9):**
```
User Types → @State messageText updates
User Taps Send → sendMessage() called
    └─> Print to console (placeholder)
    └─> Clear text field
    └─> [PR #10 will add: ChatViewModel.sendMessage()]
```

**Sending Message (Full Flow - PR #10):**
```
User Taps Send → sendMessage() called
    └─> ChatViewModel.sendMessage(text)
        ├─> Create optimistic message
        │   └─> Append to messages array (UI updates instantly)
        │   └─> Save to Core Data (isSynced: false)
        │
        └─> ChatService.sendMessage(text)
            ├─> Upload to Firestore
            └─> On success:
                └─> Update message status (sent → delivered)
            └─> On failure:
                └─> Mark as failed, show retry
```

---

## Implementation Details

### File Structure

**New Files:**
```
messAI/
├── ViewModels/
│   └── ChatViewModel.swift (~350 lines)
│       - Load messages from local + Firestore
│       - Send message with optimistic UI
│       - Handle typing indicators
│       - Scroll to bottom logic
│       - Online/offline status
│
├── Views/
│   └── Chat/
│       ├── ChatView.swift (~250 lines)
│       │   - Main container with NavigationStack
│       │   - ScrollView with message list
│       │   - Integrate all subcomponents
│       │   - Keyboard handling
│       │
│       ├── MessageBubbleView.swift (~180 lines)
│       │   - Individual message display
│       │   - Conditional styling (sent vs received)
│       │   - Timestamp formatting
│       │   - Status indicators (PR #11)
│       │
│       ├── MessageInputView.swift (~120 lines)
│       │   - Text field + send button
│       │   - Character limit (optional)
│       │   - Send action binding
│       │   - Keyboard done button
│       │
│       ├── TypingIndicatorView.swift (~80 lines)
│       │   - Animated "..." dots
│       │   - Appears when others typing
│       │   - Clean animation
│       │
│       └── ChatHeaderView.swift (~100 lines)
│           - Profile picture + name
│           - Online status ("Active now")
│           - Last seen timestamp
│
└── Utilities/
    └── String+Extensions.swift (+30 lines)
        - Message preview truncation
        - Character count validation
```

**Modified Files:**
```
messAI/
└── Views/
    └── Chat/
        └── ChatListView.swift (+20 lines)
            - Update navigation to ChatView
            - Pass conversation ID
```

**Total New Code:** ~1,080 lines  
**Total Modified Code:** ~20 lines  
**Total Impact:** ~1,100 lines

---

### Key Implementation Steps

#### Phase 1: ChatViewModel - State Management (60-75 minutes)

**Step 1.1: Create ViewModel Structure**
```swift
// ViewModels/ChatViewModel.swift

import Foundation
import Combine
import FirebaseAuth

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [Message] = []
    @Published var messageText: String = ""
    @Published var isLoading: Bool = false
    @Published var isTyping: Bool = false
    @Published var otherUserTyping: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Dependencies
    private let chatService: ChatService
    private let localDataManager: LocalDataManager
    private let conversationId: String
    private let currentUserId: String
    
    // MARK: - Computed Properties
    var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var conversation: Conversation?
    
    // MARK: - Initialization
    init(
        conversationId: String,
        chatService: ChatService,
        localDataManager: LocalDataManager
    ) {
        self.conversationId = conversationId
        self.chatService = chatService
        self.localDataManager = localDataManager
        self.currentUserId = Auth.auth().currentUser?.uid ?? ""
    }
    
    // MARK: - Methods
    func loadMessages() async {
        isLoading = true
        
        do {
            // Load from local first (instant)
            let localMessages = try localDataManager.fetchMessages(
                conversationId: conversationId
            )
            messages = localMessages.map { Message(from: $0) }
            isLoading = false
            
            // TODO (PR #10): Start Firestore listener for real-time updates
            
        } catch {
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    func sendMessage() {
        guard canSendMessage else { return }
        
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = "" // Clear input immediately
        
        // TODO (PR #10): Implement actual message sending
        print("📤 Send message: \(text)")
        // Will add:
        // - Create optimistic message
        // - Append to messages array
        // - Save to Core Data
        // - Upload to Firestore
    }
    
    func scrollToBottom() {
        // Called after new message or keyboard appears
        // Scroll implementation in ChatView
    }
}
```

---

#### Phase 2: MessageBubbleView Component (30-40 minutes)

**Step 2.1: Create Bubble View**
```swift
// Views/Chat/MessageBubbleView.swift

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message text bubble
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(bubbleColor)
                    .foregroundColor(textColor)
                    .cornerRadius(18)
                    .textSelection(.enabled)
                
                // Timestamp + Status (bottom of bubble)
                HStack(spacing: 4) {
                    Text(formatTime(message.sentAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // Status indicator (sent/delivered/read) - PR #11
                    if isFromCurrentUser {
                        statusIcon
                    }
                }
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
    
    // MARK: - Computed Properties
    
    private var bubbleColor: Color {
        isFromCurrentUser ? Color.blue : Color.gray.opacity(0.2)
    }
    
    private var textColor: Color {
        isFromCurrentUser ? .white : .primary
    }
    
    private var statusIcon: some View {
        Group {
            switch message.status {
            case .sending:
                Image(systemName: "clock.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            case .sent:
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            case .delivered:
                HStack(spacing: -2) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            case .read:
                HStack(spacing: -2) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.caption2)
                .foregroundColor(.blue)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubbleView(
            message: Message(
                id: "1",
                conversationId: "conv1",
                senderId: "user1",
                text: "Hey, how are you?",
                sentAt: Date(),
                status: .sent
            ),
            isFromCurrentUser: false
        )
        
        MessageBubbleView(
            message: Message(
                id: "2",
                conversationId: "conv1",
                senderId: "user2",
                text: "I'm great! Thanks for asking. How about you?",
                sentAt: Date(),
                status: .read
            ),
            isFromCurrentUser: true
        )
    }
    .padding()
}
```

---

#### Phase 3: MessageInputView Component (25-35 minutes)

**Step 3.1: Create Input View**
```swift
// Views/Chat/MessageInputView.swift

import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    
    @FocusState private var isFocused: Bool
    
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
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    if !text.isEmpty {
                        onSend()
                    }
                }
            
            // Send button
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(text.isEmpty ? .gray : .blue)
            }
            .disabled(text.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

#Preview {
    VStack {
        Spacer()
        MessageInputView(
            text: .constant(""),
            onSend: {
                print("Send tapped")
            }
        )
    }
}
```

---

#### Phase 4: ChatView Main Container (60-75 minutes)

**Step 4.1: Create ChatView**
```swift
// Views/Chat/ChatView.swift

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss
    
    // For scroll-to-bottom
    @State private var scrollProxy: ScrollViewProxy?
    
    let conversationId: String
    let recipientName: String
    
    init(
        conversationId: String,
        recipientName: String,
        chatService: ChatService,
        localDataManager: LocalDataManager
    ) {
        self.conversationId = conversationId
        self.recipientName = recipientName
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            conversationId: conversationId,
            chatService: chatService,
            localDataManager: localDataManager
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Message list
            messageListView
            
            // Input bar (sticky bottom)
            MessageInputView(
                text: $viewModel.messageText,
                onSend: {
                    viewModel.sendMessage()
                    scrollToBottom()
                }
            )
        }
        .navigationTitle(recipientName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadMessages()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isFromCurrentUser: message.senderId == viewModel.currentUserId
                        )
                        .id(message.id)
                    }
                    
                    // Scroll anchor (invisible)
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.vertical, 8)
            }
            .onAppear {
                scrollProxy = proxy
                scrollToBottom()
            }
            .onChange(of: viewModel.messages.count) { _ in
                scrollToBottom()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                scrollProxy?.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(
            conversationId: "preview-conv",
            recipientName: "Jane Doe",
            chatService: ChatService(),
            localDataManager: LocalDataManager(
                modelContext: PersistenceController.preview.container.viewContext
            )
        )
    }
}
```

---

#### Phase 5: ChatListView Integration (20-30 minutes)

**Step 5.1: Update ChatListView Navigation**
```swift
// In Views/Chat/ChatListView.swift

// Add navigation state
@State private var selectedConversationId: String?
@State private var selectedConversationName: String?

// Update conversation row tap handler
private func handleConversationTap(_ conversation: Conversation) {
    selectedConversationId = conversation.id
    selectedConversationName = viewModel.getConversationName(conversation)
}

// Add NavigationDestination
.navigationDestination(item: $selectedConversationId) { conversationId in
    if let name = selectedConversationName {
        ChatView(
            conversationId: conversationId,
            recipientName: name,
            chatService: ChatService(),
            localDataManager: viewModel.localDataManager
        )
    }
}
```

---

### String Extensions

**Add to Utilities/String+Extensions.swift:**
```swift
extension String {
    /// Truncate string to max length with ellipsis
    func truncated(to length: Int) -> String {
        if self.count > length {
            return String(self.prefix(length)) + "..."
        }
        return self
    }
    
    /// Remove leading/trailing whitespace and newlines
    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Check if string is empty after trimming
    var isEmptyOrWhitespace: Bool {
        self.trimmed.isEmpty
    }
}
```

---

## Testing Strategy

### Unit Tests

**ChatViewModel Tests:**
```swift
func testLoadMessagesFromLocal() async {
    // Given: Mock local data manager with 5 messages
    // When: loadMessages() called
    // Then: messages array contains 5 messages, isLoading = false
}

func testSendMessageClearsInput() {
    // Given: messageText = "Hello"
    // When: sendMessage() called
    // Then: messageText = ""
}

func testCanSendMessage() {
    // Given: messageText = "Hello"
    // Then: canSendMessage = true
    
    // Given: messageText = "   " (whitespace only)
    // Then: canSendMessage = false
}
```

---

### Integration Tests

**Message Display:**
```
Test: Messages display correctly with correct alignment
Steps:
1. Open ChatView with 10 messages (5 sent, 5 received)
2. Verify sent messages aligned right, blue bubbles
3. Verify received messages aligned left, gray bubbles
4. Verify timestamps display for all messages
5. Verify scrolled to bottom initially

Expected:
- Messages render within 1 second
- Alignment correct for all messages
- Smooth 60fps scroll
```

**Message Input:**
```
Test: Message input and send works
Steps:
1. Open ChatView
2. Tap text field (keyboard appears)
3. Type "Hello, how are you?"
4. Verify send button enabled
5. Tap send button
6. Verify text field clears
7. Verify keyboard stays visible

Expected:
- Keyboard appears smoothly
- Send button only enabled when text present
- Input clears immediately on send
```

**Keyboard Handling:**
```
Test: Keyboard doesn't obscure input field
Steps:
1. Open ChatView with long message history
2. Scroll to middle of conversation
3. Tap input field
4. Verify keyboard appears
5. Verify input field visible above keyboard
6. Verify message list adjusts height
7. Tap outside to dismiss keyboard

Expected:
- Input field always visible
- Messages don't get hidden
- Smooth animations
```

---

## Success Criteria

### Feature Complete When:

- [ ] ChatViewModel loads messages from Core Data
- [ ] ChatView displays messages in scrollable list
- [ ] MessageBubbleView shows correct styling (sent vs received)
- [ ] Messages aligned correctly (right for sent, left for received)
- [ ] MessageInputView allows typing and sending
- [ ] Send button enabled/disabled based on text
- [ ] Keyboard appears/disappears smoothly
- [ ] Auto-scroll to bottom on new message
- [ ] Timestamps display for each message
- [ ] Navigation from ChatListView works
- [ ] Back navigation preserves chat list state
- [ ] Works on all iPhone screen sizes (SE to Pro Max)
- [ ] Smooth 60fps scrolling with 100+ messages
- [ ] No memory leaks (verified with Instruments)
- [ ] All SwiftUI previews working

---

### Performance Targets

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Initial load time | <1 second | Time from onAppear to messages displayed |
| Scroll performance | 60fps | Xcode FPS monitor with 100+ messages |
| Send button response | <50ms | Tap to input clear |
| Memory usage | <80MB | Instruments with 500 messages |
| Keyboard animation | Native speed | Visual inspection |

---

## Risk Assessment

### Risk 1: Scroll-to-Bottom Reliability 🟡 MEDIUM
**Issue:** ScrollViewReader may not scroll reliably on all iOS versions  
**Mitigation:** Add delay, use DispatchQueue.main.asyncAfter, test on iOS 16/17

### Risk 2: Keyboard Obscuring Input 🔴 HIGH
**Issue:** Keyboard covers input field on smaller devices  
**Mitigation:** Use keyboard observers, adjust padding, test on iPhone SE

### Risk 3: Message List Performance 🟡 MEDIUM
**Issue:** LazyVStack may lag with 1000+ messages  
**Mitigation:** Use lazy loading, limit initial load to 50 messages, pagination

---

## Timeline

**Total Estimate:** 3-4 hours

| Phase | Task | Time |
|-------|------|------|
| 1 | ChatViewModel | 60-75 min |
| 2 | MessageBubbleView | 30-40 min |
| 3 | MessageInputView | 25-35 min |
| 4 | ChatView container | 60-75 min |
| 5 | Integration | 20-30 min |

---

## Dependencies

### Requires:
- [x] PR #4: Core Models (Message)
- [x] PR #5: ChatService
- [x] PR #6: LocalDataManager
- [ ] PR #7: ChatListView (navigation point)

### Blocks:
- PR #10: Real-Time Messaging (needs ChatView + ChatViewModel)
- PR #11: Message Status (needs MessageBubbleView)

---

*This specification provides complete technical design for PR #9. Implementation should follow phases in order, testing at each checkpoint.*

