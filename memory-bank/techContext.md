# MessageAI - Technical Context

**Last Updated**: October 20, 2025

---

## Technology Stack

### iOS Frontend

#### Core Technologies
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (iOS 16.0+)
- **Development IDE**: Xcode 15+
- **Minimum iOS**: 16.0 (to be confirmed/set in PR #1)

#### Key iOS Frameworks
```swift
import SwiftUI              // UI framework
import SwiftData            // Local persistence (Core Data successor)
import Combine              // Reactive programming
import PhotosUI             // Image picker
import UserNotifications    // Push notifications
import Network              // Network monitoring (NWPathMonitor)
```

#### State Management
- **@Published**: Observable properties in ViewModels
- **@StateObject**: ViewModel lifecycle management
- **@ObservedObject**: Pass ViewModels to child views
- **@Environment**: Dependency injection, scene phase
- **@State**: Local view state
- **Combine**: Reactive streams and publishers

---

### Firebase Backend

#### Firebase Services Used
```javascript
// Firebase Project Configuration
{
  projectId: "messai-xxxxx",
  apiKey: "...",
  authDomain: "...",
  storageBucket: "...",
  messagingSenderId: "..."
}
```

#### 1. Firebase Authentication
- **Purpose**: User signup, login, session management
- **Provider**: Email/Password
- **Features**:
  - Account creation
  - Email verification (optional)
  - Password reset
  - Session persistence
  - Auth state observers

```swift
// SDK Usage
import FirebaseAuth

let auth = Auth.auth()
auth.createUser(withEmail: email, password: password)
auth.signIn(withEmail: email, password: password)
auth.currentUser
```

#### 2. Cloud Firestore
- **Purpose**: Real-time database for messages, conversations, users
- **Type**: NoSQL document database
- **Features**:
  - Real-time sync (snapshot listeners)
  - Offline persistence (built-in)
  - Compound queries
  - Atomic transactions
  - Security rules

```swift
// SDK Usage
import FirebaseFirestore

let db = Firestore.firestore()
db.collection("conversations")
  .document(conversationId)
  .collection("messages")
  .addSnapshotListener { snapshot, error in
    // Real-time updates
  }
```

**Firestore Data Schema**:
```
/users/{userId}
  - displayName: String
  - email: String
  - photoURL: String
  - fcmToken: String
  - isOnline: Boolean
  - lastSeen: Timestamp
  - createdAt: Timestamp

/conversations/{conversationId}
  - participants: [String] (array of user IDs)
  - isGroup: Boolean
  - groupName: String? (optional)
  - lastMessage: String
  - lastMessageAt: Timestamp
  - createdBy: String (user ID)
  - createdAt: Timestamp
  
  /messages/{messageId}
    - senderId: String
    - text: String
    - imageURL: String? (optional)
    - sentAt: Timestamp
    - deliveredAt: Timestamp? (optional)
    - readAt: Timestamp? (optional)
    - status: String (sending/sent/delivered/read)

/presence/{userId}
  - isOnline: Boolean
  - lastSeen: Timestamp

/typingStatus/{conversationId}
  - {userId}: Timestamp (when user started typing)
```

#### 3. Firebase Storage
- **Purpose**: Store images (profile pictures, message images)
- **Features**:
  - Secure file upload
  - Public/private access control
  - Download URLs
  - Metadata storage

```swift
// SDK Usage
import FirebaseStorage

let storage = Storage.storage()
let ref = storage.reference().child("chat_images/\(messageId).jpg")
ref.putData(imageData) { metadata, error in
  ref.downloadURL { url, error in
    // Use download URL in message
  }
}
```

**Storage Structure**:
```
/profile_pictures/
  {userId}.jpg

/chat_images/
  {conversationId}/
    {messageId}.jpg          (full size)
    {messageId}_thumb.jpg    (thumbnail 200x200)
```

#### 4. Firebase Cloud Messaging (FCM)
- **Purpose**: Push notifications
- **Integration**: APNs (Apple Push Notification service)
- **Features**:
  - Foreground notifications
  - Background notifications
  - Deep linking to conversations
  - Badge management

```swift
// SDK Usage
import FirebaseMessaging

Messaging.messaging().delegate = self
Messaging.messaging().token { token, error in
  // Store FCM token in user document
}
```

#### 5. Cloud Functions (Node.js)
- **Purpose**: Server-side logic (notifications, automation)
- **Runtime**: Node.js 18+
- **Triggers**: Firestore document events

```javascript
// Cloud Function Example
exports.sendNotification = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const conversation = await getConversation(context.params.conversationId);
    
    // Send notifications to all participants except sender
    const recipients = conversation.participants.filter(id => id !== message.senderId);
    
    for (const recipientId of recipients) {
      const user = await getUser(recipientId);
      if (user.fcmToken) {
        await admin.messaging().send({
          token: user.fcmToken,
          notification: {
            title: getSenderName(message.senderId),
            body: message.text
          },
          data: {
            conversationId: context.params.conversationId
          }
        });
      }
    }
  });
```

---

## Local Persistence (SwiftData)

### SwiftData Overview
- **What**: Apple's modern data persistence framework (successor to Core Data)
- **Why**: Simpler API, better Swift integration, less boilerplate
- **When**: iOS 17+, but can fallback to Core Data for iOS 16

### SwiftData Models

```swift
import SwiftData

@Model
class MessageEntity {
    @Attribute(.unique) var id: String
    var conversationId: String
    var senderId: String
    var text: String
    var imageURL: String?
    var sentAt: Date
    var deliveredAt: Date?
    var readAt: Date?
    var status: String
    var isSynced: Bool = false
    var syncAttempts: Int = 0
    
    init(id: String, conversationId: String, senderId: String, text: String) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
        self.sentAt = Date()
        self.status = "sending"
    }
}

@Model
class ConversationEntity {
    @Attribute(.unique) var id: String
    var participants: [String]
    var isGroup: Bool
    var groupName: String?
    var lastMessage: String
    var lastMessageAt: Date
    
    @Relationship(deleteRule: .cascade)
    var messages: [MessageEntity] = []
    
    init(id: String, participants: [String], isGroup: Bool) {
        self.id = id
        self.participants = participants
        self.isGroup = isGroup
        self.lastMessage = ""
        self.lastMessageAt = Date()
    }
}
```

### SwiftData Configuration

```swift
import SwiftData

@main
struct MessageAIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [MessageEntity.self, ConversationEntity.self])
    }
}
```

### Querying Data

```swift
import SwiftData

class LocalDataManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchMessages(conversationId: String) throws -> [MessageEntity] {
        let predicate = #Predicate<MessageEntity> { message in
            message.conversationId == conversationId
        }
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.sentAt)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchUnsyncedMessages() throws -> [MessageEntity] {
        let predicate = #Predicate<MessageEntity> { message in
            message.isSynced == false
        }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }
}
```

---

## Networking

### Network Monitoring

```swift
import Network

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected: Bool = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }
}
```

### Firebase SDK Networking
- All networking handled by Firebase SDK
- Built-in retry logic
- Automatic connection pooling
- Certificate pinning included

---

## Image Processing

### Image Compression Utility

```swift
import UIKit

class ImageCompressor {
    static func compress(
        _ image: UIImage,
        maxSizeMB: Double = 2.0,
        maxWidth: CGFloat = 1920
    ) -> Data? {
        // Resize if needed
        let resized = resize(image, maxWidth: maxWidth)
        
        // Compress to target size
        var compressionQuality: CGFloat = 0.7
        var imageData = resized.jpegData(compressionQuality: compressionQuality)
        
        let maxSizeBytes = maxSizeMB * 1024 * 1024
        
        while let data = imageData,
              data.count > Int(maxSizeBytes),
              compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = resized.jpegData(compressionQuality: compressionQuality)
        }
        
        return imageData
    }
    
    static func createThumbnail(
        _ image: UIImage,
        size: CGSize = CGSize(width: 200, height: 200)
    ) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
```

### Image Picker

```swift
import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
    }
}
```

---

## Development Environment

### Xcode Configuration
- **Version**: Xcode 15+
- **Swift**: 5.9+
- **Build System**: New build system
- **Simulator**: iOS 17.0+
- **Physical Device**: Recommended for testing

### Project Structure
```
MessageAI/
├── MessageAI.xcodeproj
├── MessageAI/
│   ├── App/
│   │   ├── MessageAIApp.swift       (App entry point)
│   │   └── AppDelegate.swift        (Notifications)
│   │
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Conversation.swift
│   │   ├── Message.swift
│   │   ├── MessageStatus.swift
│   │   └── TypingStatus.swift
│   │
│   ├── ViewModels/
│   │   ├── AuthViewModel.swift
│   │   ├── ChatListViewModel.swift
│   │   ├── ChatViewModel.swift
│   │   ├── GroupViewModel.swift
│   │   ├── ProfileViewModel.swift
│   │   └── ContactsViewModel.swift
│   │
│   ├── Views/
│   │   ├── Auth/                    (Login, SignUp)
│   │   ├── Chat/                    (ChatList, ChatView)
│   │   ├── Contacts/                (ContactsList)
│   │   ├── Group/                   (NewGroup, GroupInfo)
│   │   └── Profile/                 (ProfileView, EditProfile)
│   │
│   ├── Services/
│   │   ├── FirebaseService.swift    (Base Firebase)
│   │   ├── AuthService.swift        (Authentication)
│   │   ├── ChatService.swift        (Messaging)
│   │   ├── PresenceService.swift    (Online/offline)
│   │   ├── StorageService.swift     (Images)
│   │   ├── NotificationService.swift (Push)
│   │   └── NetworkMonitor.swift     (Connectivity)
│   │
│   ├── Persistence/
│   │   ├── MessageEntity.swift      (SwiftData model)
│   │   ├── ConversationEntity.swift (SwiftData model)
│   │   ├── LocalDataManager.swift   (CRUD)
│   │   └── SyncManager.swift        (Sync logic)
│   │
│   ├── Utilities/
│   │   ├── ImagePicker.swift
│   │   ├── ImageCompressor.swift
│   │   ├── DateFormatter+Extensions.swift
│   │   ├── String+Extensions.swift
│   │   └── Constants.swift
│   │
│   ├── Assets.xcassets/
│   └── GoogleService-Info.plist     (Firebase config)
│
├── firebase/
│   ├── functions/
│   │   ├── index.js                 (Cloud Functions)
│   │   ├── sendNotification.js
│   │   └── package.json
│   │
│   └── firestore.rules              (Security rules)
│
└── README.md
```

### Dependencies (Swift Package Manager)

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0")
]

// Specific products:
.product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
.product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
.product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
.product(name: "FirebaseMessaging", package: "firebase-ios-sdk")
```

---

## Development Tools

### Version Control
- **Git**: For source control
- **GitHub**: Remote repository
- **Branch Strategy**: Feature branches (feature/pr#-name)
- **Commit Format**: `[PR #X] Description`

### Firebase CLI
```bash
# Installation
npm install -g firebase-tools

# Login
firebase login

# Initialize project
firebase init

# Deploy functions
firebase deploy --only functions

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage
```

### Testing Tools
- **XCTest**: Unit testing
- **XCUITest**: UI testing (optional for MVP)
- **Physical Devices**: Real-world testing
- **Network Link Conditioner**: Simulate poor networks

---

## Performance Considerations

### Firestore Best Practices
1. **Limit Query Results**: Use `.limit()` to avoid downloading entire collections
2. **Index Queries**: Create composite indexes for complex queries
3. **Batch Writes**: Group multiple writes into single batch
4. **Pagination**: Load data in chunks (e.g., 50 messages at a time)
5. **Detach Listeners**: Remove listeners when views disappear

### SwiftUI Performance
1. **Lazy Loading**: Use `LazyVStack` for long lists
2. **Identify Items**: Provide stable IDs for list items
3. **Minimize State**: Only mark necessary properties as `@Published`
4. **Avoid Force Unwrapping**: Use optional binding
5. **Profile with Instruments**: Identify bottlenecks

### Image Optimization
1. **Compress Before Upload**: Target 2MB max
2. **Generate Thumbnails**: 200x200 for chat bubbles
3. **Lazy Load Images**: Only load visible images
4. **Cache Aggressively**: Use AsyncImage caching
5. **Progressive Loading**: Show placeholder → thumbnail → full

---

## Security Considerations

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own profile
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // Users can only access conversations they're part of
    match /conversations/{conversationId} {
      allow read: if request.auth != null 
                  && request.auth.uid in resource.data.participants;
      allow create: if request.auth != null 
                    && request.auth.uid in request.resource.data.participants;
      
      match /messages/{messageId} {
        allow read: if request.auth != null 
                    && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
        allow create: if request.auth != null
                      && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants
                      && request.resource.data.senderId == request.auth.uid;
      }
    }
  }
}
```

### Storage Security Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_pictures/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    match /chat_images/{conversationId}/{imageId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

---

## Configuration Files

### GoogleService-Info.plist
- Downloaded from Firebase Console
- Contains API keys, project ID, etc.
- **Important**: Add to `.gitignore` (don't commit!)

### Info.plist Additions
```xml
<!-- Camera usage -->
<key>NSCameraUsageDescription</key>
<string>Take photos to send in messages</string>

<!-- Photo library -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Select photos to send in messages</string>

<!-- Push notifications -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

---

## Known Technical Constraints

1. **iOS 16.0+ Only**: SwiftUI and SwiftData require recent iOS
2. **Firebase Free Tier Limits**: 
   - 50K reads/day
   - 20K writes/day
   - 1GB storage
   - (Sufficient for MVP, may hit limits at scale)
3. **APNs Requires Apple Developer Account**: $99/year for push notifications
4. **Simulator Limitations**: 
   - No camera
   - No push notifications (unless using Xcode 15+)
   - Different performance characteristics

---

*This technical context provides the foundation for implementation decisions throughout the project.*

