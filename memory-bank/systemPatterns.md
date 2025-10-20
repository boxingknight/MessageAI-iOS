# MessageAI - System Patterns & Architecture

**Last Updated**: October 20, 2025

---

## Architecture Overview

### High-Level System Design

```
┌─────────────────────────────────────────────────────────────┐
│                     iOS App (SwiftUI)                        │
│                                                              │
│  ┌────────────┐    ┌──────────────┐    ┌────────────────┐  │
│  │   Views    │───▶│  ViewModels  │───▶│   Services     │  │
│  │  (SwiftUI) │◀───│   (Logic)    │◀───│  (Firebase)    │  │
│  └────────────┘    └──────────────┘    └────────────────┘  │
│                           │                     │            │
│                           ▼                     ▼            │
│                    ┌──────────────┐    ┌────────────────┐  │
│                    │  SwiftData   │    │  Firebase SDK  │  │
│                    │ (Local Store)│    │  (Network)     │  │
│                    └──────────────┘    └────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    Firebase Backend                          │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐ │
│  │   Auth   │  │Firestore │  │ Storage  │  │  FCM/Push  │ │
│  └──────────┘  └──────────┘  └──────────┘  └────────────┘ │
│                       │                                      │
│                       ▼                                      │
│              ┌─────────────────┐                            │
│              │ Cloud Functions │                            │
│              │  (Notifications)│                            │
│              └─────────────────┘                            │
└─────────────────────────────────────────────────────────────┘
```

---

## Design Pattern: MVVM (Model-View-ViewModel)

### Pattern Structure

```
┌─────────────────────────────────────────────────────────┐
│                         VIEW                            │
│  ┌───────────────────────────────────────────────┐     │
│  │  SwiftUI View (Presentation Only)             │     │
│  │  - Renders UI                                  │     │
│  │  - Responds to user input                      │     │
│  │  - No business logic                           │     │
│  └───────────────────────────────────────────────┘     │
│                       ▲ │                               │
│                Observe │ │ Actions                      │
│                       │ ▼                               │
│  ┌───────────────────────────────────────────────┐     │
│  │  ViewModel (Business Logic)                    │     │
│  │  - @Published properties                       │     │
│  │  - State management                            │     │
│  │  - Validation logic                            │     │
│  │  - Calls services                              │     │
│  └───────────────────────────────────────────────┘     │
│                       ▲ │                               │
│                 Query │ │ Update                        │
│                       │ ▼                               │
│  ┌───────────────────────────────────────────────┐     │
│  │  Services (Data Layer)                         │     │
│  │  - Firebase interactions                       │     │
│  │  - Network calls                               │     │
│  │  - Data transformation                         │     │
│  └───────────────────────────────────────────────┘     │
│                       ▲ │                               │
│                 Read  │ │ Write                         │
│                       │ ▼                               │
│  ┌───────────────────────────────────────────────┐     │
│  │  Models (Data Structures)                      │     │
│  │  - Codable structs                             │     │
│  │  - Business entities                           │     │
│  │  - No logic (data only)                        │     │
│  └───────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

### Why MVVM?
- ✅ **Testable**: ViewModels can be unit tested without UI
- ✅ **Reactive**: SwiftUI observes ViewModel changes automatically
- ✅ **Separation**: Clear boundaries between layers
- ✅ **Reusable**: ViewModels can drive multiple views
- ✅ **Standard**: Industry best practice for SwiftUI

---

## Data Flow Patterns

### Pattern 1: Optimistic UI (Message Sending)

```
User Action (Send Message)
    │
    ▼
┌────────────────────────────────────────┐
│ 1. ChatViewModel                       │
│    - Create local Message object       │
│    - Set status: .sending              │
│    - Append to messages array          │  ← UI updates immediately
│    - Save to SwiftData                 │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ 2. ChatService                         │
│    - Send message to Firestore         │
│    - Return completion handler         │
└────────────────────────────────────────┘
    │
    ├─ Success ────────────────┐
    │                          │
    ▼                          ▼
┌──────────────────┐    ┌──────────────────┐
│ 3a. Update Local │    │ 3b. Firestore    │
│ - Status: .sent  │    │ - Generates ID   │
│ - Add server ID  │    │ - Adds timestamp │
└──────────────────┘    └──────────────────┘
    │                          │
    └─────────┬────────────────┘
              ▼
    ┌──────────────────┐
    │ 4. Real-time     │
    │    Listener      │  ← Other devices receive
    │    triggers      │
    └──────────────────┘
```

**Key Principle**: Show immediately, confirm later

---

### Pattern 2: Real-Time Sync (Message Receiving)

```
Firestore Change Event
    │
    ▼
┌────────────────────────────────────────┐
│ Firestore Snapshot Listener            │
│ - Detects new/modified/deleted docs    │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ ChatService.onMessageReceived          │
│ - Parse Firestore document             │
│ - Create Message object                │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ ChatViewModel receives update          │
│ - Check if message already exists      │  ← Deduplication
│ - If new: append to messages array     │
│ - If existing: update properties       │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ Save to SwiftData                      │
│ - Persist locally                      │
│ - Mark as synced                       │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ View Auto-Updates                      │
│ - SwiftUI observes @Published          │
│ - Triggers re-render                   │
│ - Smooth animation                     │
└────────────────────────────────────────┘
```

**Key Principle**: Listen continuously, update incrementally

---

### Pattern 3: Offline Queue & Sync

```
User Sends Message While Offline
    │
    ▼
┌────────────────────────────────────────┐
│ NetworkMonitor detects offline         │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ ChatViewModel                          │
│ - Create message with status: .sending │
│ - Save to SwiftData only (not Firebase)│
│ - Mark as unsynced                     │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ SyncManager adds to queue              │
│ - Store in local queue                 │
│ - Wait for connectivity                │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ NetworkMonitor detects online          │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ SyncManager.syncQueuedMessages()       │
│ - Retrieve unsynced messages           │
│ - Send to Firebase in order            │
│ - Retry on failure (exp. backoff)      │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ On Success                             │
│ - Update status: .sent                 │
│ - Mark as synced in SwiftData          │
│ - Remove from queue                    │
└────────────────────────────────────────┘
```

**Key Principle**: Queue locally, sync automatically

---

## Core Architectural Patterns

### 1. Service Layer Pattern

**Purpose**: Encapsulate all Firebase operations

```swift
// Service Interface
protocol ChatServiceProtocol {
    func createConversation(participants: [String], isGroup: Bool) async throws -> Conversation
    func sendMessage(conversationId: String, text: String) async throws -> Message
    func fetchMessages(conversationId: String) -> AsyncThrowingStream<[Message], Error>
    func markAsRead(conversationId: String, userId: String) async throws
}

// Implementation
class ChatService: ChatServiceProtocol {
    private let firestore = Firestore.firestore()
    
    // Methods implement protocol
    // All Firebase logic contained here
}
```

**Benefits**:
- ✅ Testable (mock service in tests)
- ✅ Swappable (could switch from Firebase to another backend)
- ✅ Centralized error handling
- ✅ Single source of truth for data operations

---

### 2. Repository Pattern (via SwiftData)

**Purpose**: Abstract local data storage

```swift
// LocalDataManager handles all SwiftData operations
class LocalDataManager {
    private let modelContext: ModelContext
    
    // CRUD operations
    func saveMessage(_ message: MessageEntity)
    func fetchMessages(conversationId: String) -> [MessageEntity]
    func updateMessage(id: String, updates: [String: Any])
    func deleteMessage(id: String)
    
    // Sync operations
    func fetchUnsyncedMessages() -> [MessageEntity]
    func markAsSynced(messageId: String)
}
```

**Benefits**:
- ✅ Hides SwiftData complexity
- ✅ Easy to batch operations
- ✅ Consistent query patterns
- ✅ Migration-friendly

---

### 3. Observer Pattern (Combine + @Published)

**Purpose**: Reactive state updates

```swift
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init(chatService: ChatService) {
        // Subscribe to real-time updates
        chatService.messagesPublisher
            .sink { [weak self] newMessages in
                self?.messages = newMessages
            }
            .store(in: &cancellables)
    }
}
```

**Benefits**:
- ✅ SwiftUI auto-updates on changes
- ✅ Decoupled components
- ✅ Memory-safe (weak references)
- ✅ Composable (chain publishers)

---

### 4. Strategy Pattern (Network Handling)

**Purpose**: Different behaviors for different network states

```swift
protocol NetworkStrategy {
    func sendMessage(_ message: Message) async throws
}

class OnlineStrategy: NetworkStrategy {
    func sendMessage(_ message: Message) async throws {
        // Send directly to Firebase
    }
}

class OfflineStrategy: NetworkStrategy {
    func sendMessage(_ message: Message) async throws {
        // Queue locally for later sync
    }
}

class NetworkMonitor {
    var strategy: NetworkStrategy {
        isConnected ? OnlineStrategy() : OfflineStrategy()
    }
}
```

**Benefits**:
- ✅ Clean separation of online/offline logic
- ✅ Easy to test each strategy independently
- ✅ Extensible (add more strategies)

---

## State Management Patterns

### ViewModel State Machine

```swift
enum ChatViewState {
    case loading
    case loaded(messages: [Message])
    case empty
    case error(message: String)
}

class ChatViewModel: ObservableObject {
    @Published var state: ChatViewState = .loading
    
    func loadMessages() {
        state = .loading
        
        Task {
            do {
                let messages = try await chatService.fetchMessages(conversationId)
                state = messages.isEmpty ? .empty : .loaded(messages: messages)
            } catch {
                state = .error(message: error.localizedDescription)
            }
        }
    }
}
```

**Benefits**:
- ✅ Impossible states are unrepresentable
- ✅ UI always reflects actual state
- ✅ Easy to reason about
- ✅ Type-safe

---

## Data Persistence Strategy

### Two-Tier Storage

```
┌─────────────────────────────────────────────┐
│           Application Layer                 │
└─────────────────────────────────────────────┘
                    │
         ┌──────────┴──────────┐
         │                     │
    ┌────▼────┐          ┌────▼────┐
    │SwiftData│          │Firebase │
    │ (Local) │          │(Cloud)  │
    └─────────┘          └─────────┘
         │                     │
    ┌────▼────────────────────▼────┐
    │    Sync Manager               │
    │  - Reconciles differences     │
    │  - Handles conflicts          │
    │  - Queues offline changes     │
    └───────────────────────────────┘
```

**Sync Rules**:
1. **Write**: Always write to SwiftData first (fast), then Firebase (background)
2. **Read**: Try local first (instant), fall back to Firebase
3. **Conflicts**: Server timestamp wins (last-write-wins)
4. **Offline**: Queue changes in SwiftData, sync on reconnect

---

## Component Communication Patterns

### Pattern: Dependency Injection

```swift
// Dependencies injected via initializer
class ChatViewModel: ObservableObject {
    private let chatService: ChatServiceProtocol
    private let localDataManager: LocalDataManager
    private let networkMonitor: NetworkMonitor
    
    init(
        chatService: ChatServiceProtocol,
        localDataManager: LocalDataManager,
        networkMonitor: NetworkMonitor
    ) {
        self.chatService = chatService
        self.localDataManager = localDataManager
        self.networkMonitor = networkMonitor
    }
}

// In view
struct ChatView: View {
    @StateObject var viewModel: ChatViewModel
    
    init(conversationId: String) {
        // Create dependencies
        let chatService = ChatService()
        let localDataManager = LocalDataManager()
        let networkMonitor = NetworkMonitor.shared
        
        // Inject into ViewModel
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            chatService: chatService,
            localDataManager: localDataManager,
            networkMonitor: networkMonitor
        ))
    }
}
```

**Benefits**:
- ✅ Testable (inject mocks)
- ✅ Explicit dependencies
- ✅ Flexible (swap implementations)
- ✅ No global state

---

## Error Handling Pattern

### Consistent Error Flow

```swift
// Domain-specific errors
enum ChatError: LocalizedError {
    case messageNotSent
    case conversationNotFound
    case networkUnavailable
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .messageNotSent: return "Failed to send message. Try again."
        case .conversationNotFound: return "Conversation not found."
        case .networkUnavailable: return "No internet connection."
        case .invalidData: return "Invalid message data."
        }
    }
}

// ViewModel handles errors consistently
class ChatViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    func sendMessage(_ text: String) {
        Task {
            do {
                try await chatService.sendMessage(conversationId, text: text)
            } catch let error as ChatError {
                // Domain error - show to user
                errorMessage = error.errorDescription
                showError = true
            } catch {
                // Unknown error - generic message
                errorMessage = "Something went wrong. Please try again."
                showError = true
            }
        }
    }
}
```

---

## Navigation Pattern

### Coordinator-Light Approach

```swift
// App-level navigation state
class NavigationCoordinator: ObservableObject {
    @Published var conversationId: String?
    @Published var showNewConversation: Bool = false
    @Published var showProfile: Bool = false
    
    func openConversation(_ id: String) {
        conversationId = id
    }
}

// Inject into views
struct ChatListView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    
    var body: some View {
        NavigationStack {
            // View content
            .navigationDestination(item: $coordinator.conversationId) { id in
                ChatView(conversationId: id)
            }
        }
    }
}
```

---

## Performance Patterns

### 1. Lazy Loading
- Load messages in batches (e.g., 50 at a time)
- Virtualize long lists with `LazyVStack`
- Paginate Firestore queries

### 2. Image Caching
- Use `AsyncImage` with caching
- Store thumbnails separately from full images
- Lazy load images as user scrolls

### 3. Debouncing
- Typing indicators send at most every 500ms
- Search queries debounced to 300ms
- Reduce unnecessary Firestore writes

### 4. Batch Operations
- Batch Firestore writes when possible
- Update UI once for multiple changes
- Coalesce state updates

---

## Key Architectural Principles

1. **Single Source of Truth**: Firestore is authoritative, local is cache
2. **Unidirectional Data Flow**: Actions → ViewModel → Services → Backend → ViewModel → Views
3. **Fail Gracefully**: Never crash, always show error state
4. **Optimistic by Default**: Assume success, handle failures
5. **Observable Everything**: Use @Published for all mutable state
6. **Test at Boundaries**: Mock services, test ViewModels, snapshot Views
7. **Separation of Concerns**: Views present, ViewModels coordinate, Services execute

---

*This architecture supports reliable, testable, maintainable messaging at scale.*

