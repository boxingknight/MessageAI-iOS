# PR#17: Push Notifications - Firebase Cloud Messaging

**Estimated Time:** 3-4 hours  
**Complexity:** HIGH  
**Dependencies:** PR #1 (Firebase), PR #2 (Auth), PR #5 (Chat Service), PR #10 (Real-time)

---

## Overview

### What We're Building

**The Final MVP Feature** - Push notifications that alert users when they receive messages while the app is backgrounded or closed. This is the **only missing MVP requirement** and unlocks true asynchronous messaging.

Users receive notifications when:
- Someone sends them a message (one-on-one)
- Someone messages a group they're in
- Multiple messages arrive (intelligently grouped)

Users can:
- Tap notification → Opens directly to that conversation
- See sender name + message preview in notification
- See badge count of unread conversations on app icon
- Grant/deny notification permissions with clear messaging

### Why It Matters

**This is the difference between a chat app and a messaging app.**

Without push notifications:
- Users must keep app open to receive messages
- They miss messages while doing other things
- No way to know when someone messages them
- App feels broken and incomplete

With push notifications:
- Users get real-time alerts even when app is closed
- Can respond immediately to important messages
- Feel connected without keeping app open
- Professional, production-quality experience

**Industry Standard:** 90% of messaging apps' value comes from push notifications. It's literally the core feature that makes asynchronous communication possible.

### Success in One Sentence

"This PR is successful when a user receives a notification within 3 seconds of someone sending them a message, taps it, and lands directly in that conversation ready to reply."

---

## Technical Design

### Architecture Decisions

#### Decision 1: Notification Delivery System

**Options Considered:**

1. **Option A: Firebase Cloud Messaging (FCM) only**
   - Pros: Integrated with our stack, free, handles APNs complexity, reliable
   - Cons: Requires Cloud Functions, vendor lock-in
   - Cost: Free tier: 20,000 notifications/day

2. **Option B: Direct APNs integration**
   - Pros: No Cloud Functions, direct control, Apple-native
   - Cons: Complex certificate management, no Android path, no failover
   - Cost: Free

3. **Option C: Third-party service (OneSignal, Pusher)**
   - Pros: Easy setup, cross-platform, analytics
   - Cons: Additional dependency, cost, overkill for MVP
   - Cost: $99+/month

**Chosen:** Option A - Firebase Cloud Messaging

**Rationale:**
- Already using Firebase (Auth, Firestore, Storage)
- FCM handles APNs certificates automatically
- Cloud Functions trigger on Firestore writes (automatic)
- Free tier covers MVP and beyond
- Production-grade reliability
- Future Android compatibility if needed

**Trade-offs:**
- Gain: Automatic, reliable, free, integrated
- Lose: Some control, vendor dependency (acceptable for MVP)

---

#### Decision 2: Notification Trigger Method

**Options Considered:**

1. **Option A: Cloud Functions triggered by Firestore writes**
   - Pros: Automatic, no client code needed, reliable, secure
   - Cons: Slight delay (500ms-2s), requires Cloud Functions setup
   - Pattern: `messages/{messageId}` onCreate → send notification

2. **Option B: Client sends notification directly**
   - Pros: Instant, no backend code
   - Cons: Security risk (anyone can send notifications), not recommended
   - Anti-pattern: Never expose FCM server key to clients

3. **Option C: HTTP endpoint + webhook**
   - Pros: Full control, custom logic
   - Cons: More complex, need server infrastructure, slower
   - Overkill for MVP

**Chosen:** Option A - Cloud Functions on Firestore write

**Rationale:**
- Secure (server-side only)
- Automatic (triggers on every new message)
- Fast enough (1-2 second latency acceptable)
- Simple to implement and maintain
- Industry standard pattern

**Trade-offs:**
- Gain: Security, simplicity, reliability
- Lose: ~1-2 seconds delay vs instant (acceptable)

---

#### Decision 3: Notification Content & Privacy

**Options Considered:**

1. **Option A: Full message preview in notification**
   - Shows: "Alice: Hey, are you free tonight?"
   - Pros: Maximum context, user can decide to open
   - Cons: Privacy concern if device visible to others
   - Standard: iMessage, WhatsApp default

2. **Option B: Generic notification only**
   - Shows: "New message from Alice"
   - Pros: Maximum privacy
   - Cons: Less useful, user must open to see content
   - Standard: Secure messaging apps (Signal)

3. **Option C: Configurable per-user preference**
   - Let user choose in settings
   - Pros: Best of both worlds
   - Cons: More complexity, settings UI needed
   - Future enhancement

**Chosen:** Option A for MVP, Option C for future

**Rationale:**
- Matches industry standard (iMessage, WhatsApp, Messenger)
- Most useful for users (can triage importance)
- Privacy handled by device lock screen settings (iOS feature)
- Can add user preference toggle in PR #16 (Profile)

**Trade-offs:**
- Gain: Useful notifications, better UX
- Lose: Some privacy (mitigated by iOS lock screen)

---

#### Decision 4: Badge Count Strategy

**Options Considered:**

1. **Option A: Count unread conversations**
   - Shows: Number of conversations with unread messages
   - Pros: Simple, clear meaning, matches email pattern
   - Cons: Doesn't show total message count
   - Example: 3 conversations = badge "3"

2. **Option B: Count total unread messages**
   - Shows: Sum of all unread messages across all conversations
   - Pros: More granular, shows volume
   - Cons: Can be overwhelming (badge "47"), loses context
   - Example: 47 messages = badge "47"

3. **Option C: No badge, just notification banner**
   - Shows: Nothing on app icon
   - Pros: Least intrusive
   - Cons: No persistent indicator, harder to remember
   - Not recommended

**Chosen:** Option A - Count unread conversations

**Rationale:**
- More actionable (3 conversations to check vs 47 messages)
- Less overwhelming (stays in single digits usually)
- Matches Mail.app pattern (familiar to users)
- Easier to implement (one query vs aggregation)

**Trade-offs:**
- Gain: Simple, clear, actionable
- Lose: Less granular info (acceptable)

---

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS Device                               │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ MessageAI App                                           │    │
│  │  ├─ Request notification permission (on first launch)  │    │
│  │  ├─ Receive FCM token                                  │    │
│  │  ├─ Save token to Firestore (/users/{userId})         │    │
│  │  ├─ Handle foreground notifications (banner)           │    │
│  │  ├─ Handle background notifications (system)           │    │
│  │  └─ Deep link to conversation on tap                   │    │
│  └────────────────────────────────────────────────────────┘    │
│                          ↕                                       │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ APNs (Apple Push Notification service)                 │    │
│  └────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
                           ↕
┌─────────────────────────────────────────────────────────────────┐
│                    Firebase Cloud (Backend)                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Firebase Cloud Messaging (FCM)                          │    │
│  │  ├─ Manages APNs certificates                          │    │
│  │  ├─ Routes notifications to correct device             │    │
│  │  ├─ Handles delivery and retry logic                   │    │
│  │  └─ Provides admin SDK for sending                     │    │
│  └────────────────────────────────────────────────────────┘    │
│                          ↑                                       │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Cloud Functions (Triggers)                              │    │
│  │  ├─ onMessageCreated() - New message trigger           │    │
│  │  │   ├─ Get recipient user(s)                          │    │
│  │  │   ├─ Get sender info                                │    │
│  │  │   ├─ Get FCM tokens                                 │    │
│  │  │   ├─ Check if user is online/in-app                 │    │
│  │  │   └─ Send notification via FCM admin SDK            │    │
│  │  └─ Deployed to Firebase via Firebase CLI             │    │
│  └────────────────────────────────────────────────────────┘    │
│                          ↑                                       │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Firestore Database                                      │    │
│  │  ├─ /messages/{messageId} - onCreate trigger           │    │
│  │  ├─ /users/{userId} - FCM token storage                │    │
│  │  └─ /conversations/{convId} - Metadata                 │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

**Flow:**
1. User A sends message to User B
2. Message written to Firestore `/messages/{messageId}`
3. Cloud Function detects new message (onCreate trigger)
4. Function fetches User B's FCM token from `/users/{userId}`
5. Function checks if User B is currently active (skip if in-app)
6. Function sends notification via FCM Admin SDK
7. FCM routes through APNs to User B's device
8. iOS displays notification (banner/lock screen)
9. User B taps notification
10. App deep links to conversation with User A

---

### Data Model Changes

#### User Model Extension

**Add FCM Token Storage:**

```swift
// Models/User.swift (existing)
struct User: Codable, Identifiable, Equatable {
    let id: String
    var displayName: String
    var email: String
    var photoURL: String?
    var isOnline: Bool
    var lastSeen: Date
    var createdAt: Date
    
    // ✨ NEW: Push notification support
    var fcmToken: String?              // FCM device token
    var notificationsEnabled: Bool     // User preference
    var lastTokenUpdate: Date?         // When token was refreshed
    
    // Existing methods...
}
```

**Firestore Structure:**
```
/users/{userId}
├── displayName: "Alice"
├── email: "alice@example.com"
├── isOnline: true
├── fcmToken: "dP1KX4gp3k:APA91bH..."  ← NEW
├── notificationsEnabled: true          ← NEW
└── lastTokenUpdate: Timestamp          ← NEW
```

---

#### Notification Model (New)

**Create NotificationPayload:**

```swift
// Models/NotificationPayload.swift (NEW FILE)
struct NotificationPayload: Codable {
    let title: String              // "Alice"
    let body: String               // "Hey, are you free?"
    let conversationId: String     // For deep linking
    let senderId: String           // Who sent the message
    let messageId: String          // Specific message
    let badge: Int?                // Unread conversation count
    let sound: String              // "default"
    let timestamp: Date            // When sent
    
    // Computed for FCM format
    var toFCMPayload: [String: Any] {
        return [
            "notification": [
                "title": title,
                "body": body,
                "sound": sound,
                "badge": badge ?? 0
            ],
            "data": [
                "conversationId": conversationId,
                "senderId": senderId,
                "messageId": messageId,
                "timestamp": Int(timestamp.timeIntervalSince1970)
            ],
            "apns": [
                "payload": [
                    "aps": [
                        "alert": [
                            "title": title,
                            "body": body
                        ],
                        "sound": sound,
                        "badge": badge ?? 0,
                        "mutable-content": 1,
                        "category": "MESSAGE"
                    ]
                ]
            ]
        ]
    }
}
```

---

### Service Architecture

#### NotificationService (New)

**Responsibilities:**
- Request notification permissions
- Register for remote notifications
- Receive and store FCM token
- Handle foreground notifications
- Handle background notification tap
- Update badge count
- Deep link to conversations

**File:** `Services/NotificationService.swift` (~300 lines)

**Key Methods:**

```swift
class NotificationService: NSObject, ObservableObject {
    // Singleton
    static let shared = NotificationService()
    
    // State
    @Published var permissionGranted: Bool = false
    @Published var fcmToken: String?
    @Published var currentBadgeCount: Int = 0
    
    // Dependencies
    private let authService: AuthService
    private let chatService: ChatService
    
    // MARK: - Initialization & Permissions
    
    /// Request notification permission on first launch
    func requestPermission() async -> Bool
    
    /// Register for remote notifications with APNs
    func registerForRemoteNotifications()
    
    /// Handle FCM token received
    func didReceiveFCMToken(_ token: String)
    
    /// Save FCM token to Firestore
    func saveFCMTokenToFirestore(_ token: String) async throws
    
    // MARK: - Foreground Notifications
    
    /// Handle notification while app is active
    func handleForegroundNotification(_ notification: UNNotification)
    
    /// Show in-app banner for foreground messages
    func showInAppBanner(title: String, body: String)
    
    // MARK: - Background Notifications
    
    /// Handle notification tap (app was closed/backgrounded)
    func handleNotificationTap(_ response: UNNotificationResponse)
    
    /// Deep link to conversation from notification
    func openConversation(conversationId: String)
    
    // MARK: - Badge Management
    
    /// Update badge count based on unread conversations
    func updateBadgeCount() async
    
    /// Clear badge when app becomes active
    func clearBadgeIfNeeded()
    
    // MARK: - Token Management
    
    /// Refresh FCM token periodically
    func refreshTokenIfNeeded() async
    
    /// Remove FCM token on sign out
    func removeFCMToken() async
}
```

---

### Cloud Functions Design

#### Function 1: Send Notification on New Message

**File:** `functions/src/index.ts` (NEW)

**Trigger:** Firestore onCreate at `/messages/{messageId}`

**Logic:**

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const sendMessageNotification = functions.firestore
  .document('messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const messageId = context.params.messageId;
    
    // 1. Get conversation to find recipients
    const conversationRef = admin.firestore()
      .collection('conversations')
      .doc(message.conversationId);
    const conversationSnap = await conversationRef.get();
    const conversation = conversationSnap.data();
    
    // 2. Get sender info
    const senderRef = admin.firestore()
      .collection('users')
      .doc(message.senderId);
    const senderSnap = await senderRef.get();
    const sender = senderSnap.data();
    
    // 3. Find recipients (all participants except sender)
    const recipientIds = conversation.participantIds
      .filter(id => id !== message.senderId);
    
    // 4. Get recipient FCM tokens
    const recipientPromises = recipientIds.map(async (recipientId) => {
      const userRef = admin.firestore().collection('users').doc(recipientId);
      const userSnap = await userRef.get();
      const user = userSnap.data();
      
      // Skip if user is online and in this conversation
      if (user.isOnline && user.currentConversationId === message.conversationId) {
        return null; // Don't send notification if actively chatting
      }
      
      // Skip if notifications disabled
      if (!user.notificationsEnabled || !user.fcmToken) {
        return null;
      }
      
      return {
        userId: recipientId,
        token: user.fcmToken,
        displayName: user.displayName
      };
    });
    
    const recipients = (await Promise.all(recipientPromises))
      .filter(r => r !== null);
    
    if (recipients.length === 0) {
      console.log('No recipients to notify');
      return null;
    }
    
    // 5. Get unread count for badge (per recipient)
    const notificationPromises = recipients.map(async (recipient) => {
      const unreadCount = await getUnreadConversationCount(recipient.userId);
      
      // 6. Build notification payload
      const payload = {
        notification: {
          title: sender.displayName,
          body: message.text || '📷 Image',
          sound: 'default',
        },
        data: {
          conversationId: message.conversationId,
          senderId: message.senderId,
          messageId: messageId,
          type: 'new_message',
        },
        apns: {
          payload: {
            aps: {
              badge: unreadCount,
              sound: 'default',
              category: 'MESSAGE',
              'thread-id': message.conversationId, // Groups notifications
            }
          }
        },
        token: recipient.token
      };
      
      // 7. Send via FCM
      try {
        await admin.messaging().send(payload);
        console.log(`Notification sent to ${recipient.userId}`);
      } catch (error) {
        console.error(`Failed to send to ${recipient.userId}:`, error);
        
        // If token is invalid, remove it from user document
        if (error.code === 'messaging/invalid-registration-token') {
          await admin.firestore()
            .collection('users')
            .doc(recipient.userId)
            .update({ fcmToken: admin.firestore.FieldValue.delete() });
        }
      }
    });
    
    await Promise.all(notificationPromises);
    return null;
  });

// Helper: Count unread conversations for badge
async function getUnreadConversationCount(userId: string): Promise<number> {
  const conversationsSnap = await admin.firestore()
    .collection('conversations')
    .where('participantIds', 'array-contains', userId)
    .get();
  
  let unreadCount = 0;
  
  for (const doc of conversationsSnap.docs) {
    const conversation = doc.data();
    const lastMessage = conversation.lastMessage;
    
    // If last message exists and not from this user
    if (lastMessage && lastMessage.senderId !== userId) {
      // Check if user has read it
      const isRead = lastMessage.readBy?.includes(userId);
      if (!isRead) {
        unreadCount++;
      }
    }
  }
  
  return unreadCount;
}
```

**Deployment:**

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Cloud Functions
firebase init functions

# Deploy functions
firebase deploy --only functions
```

---

### iOS Configuration Required

#### 1. Xcode Project Settings

**Add Capability:**
- Open Xcode project
- Select MessageAI target
- Go to "Signing & Capabilities"
- Click "+ Capability"
- Add "Push Notifications"
- Add "Background Modes" → Enable "Remote notifications"

**Bundle Identifier:**
- Must match Firebase project: `com.isaacjaramillo.messAI`

---

#### 2. APNs Authentication Key (Easier Method)

**Steps:**
1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to "Certificates, Identifiers & Profiles"
3. Click "Keys" → "+" (Create a new key)
4. Name: "MessageAI Push Notifications"
5. Enable "Apple Push Notifications service (APNs)"
6. Download `.p8` file (keep secure!)
7. Note Key ID and Team ID

**Upload to Firebase:**
1. Go to Firebase Console → Project Settings
2. Click "Cloud Messaging" tab
3. Under "Apple app configuration"
4. Upload APNs Authentication Key (.p8 file)
5. Enter Key ID and Team ID
6. Save

---

#### 3. Info.plist Updates

**Add entries:**

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>

<key>NSUserNotificationsUsageDescription</key>
<string>MessageAI needs notification permission to alert you when you receive new messages.</string>

<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

---

### Deep Linking Strategy

#### URL Scheme Setup

**Info.plist:**

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.isaacjaramillo.messAI</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>messageai</string>
        </array>
    </dict>
</array>
```

**URL Format:**
```
messageai://conversation/{conversationId}
messageai://conversation/abc123xyz
```

**Implementation:**

```swift
// messAIApp.swift
.onOpenURL { url in
    // Handle deep link from notification tap
    NotificationService.shared.handleDeepLink(url)
}
```

---

## Implementation Details

### File Structure

**New Files:**

```
messAI/
├── Services/
│   └── NotificationService.swift          (~300 lines) - Core notification logic
├── Models/
│   └── NotificationPayload.swift          (~80 lines) - Notification data structure
├── Views/
│   └── Settings/
│       └── NotificationSettingsView.swift (~100 lines) - Permission UI (future)
└── Utilities/
    └── AppDelegate.swift                  (~150 lines) - Handle APNs lifecycle

functions/
├── package.json                           - Node.js dependencies
├── tsconfig.json                          - TypeScript config
└── src/
    └── index.ts                           (~200 lines) - Cloud Functions
```

**Modified Files:**

```
messAI/
├── messAIApp.swift                        (+50 lines) - Integrate NotificationService
├── Models/User.swift                      (+15 lines) - Add FCM token fields
├── Services/AuthService.swift             (+20 lines) - Save token on login
├── Views/Chat/ChatView.swift              (+10 lines) - Track active conversation
└── Info.plist                             (+15 lines) - APNs configuration

firebase.json                              (+10 lines) - Functions configuration
```

---

### Key Implementation Steps

#### Phase 1: iOS Setup (1 hour)

**1. Add Push Notification Capability**

```swift
// In Xcode:
// Target → Signing & Capabilities → + Capability → Push Notifications
// Target → Signing & Capabilities → + Capability → Background Modes
//   ↳ Enable "Remote notifications"
```

**2. Create AppDelegate for APNs**

```swift
// Utilities/AppDelegate.swift
import UIKit
import FirebaseCore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Request notification permission
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, _ in
                print("Permission granted: \(granted)")
            }
        )
        
        application.registerForRemoteNotifications()
        
        // Set FCM delegate
        Messaging.messaging().delegate = self
        
        return true
    }
    
    // APNs token received
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("FCM Token: \(token)")
        
        // Save to NotificationService
        NotificationService.shared.didReceiveFCMToken(token)
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    // Handle notification in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Extract conversation ID
        if let conversationId = userInfo["conversationId"] as? String {
            NotificationService.shared.openConversation(conversationId: conversationId)
        }
        
        completionHandler()
    }
}
```

**3. Integrate AppDelegate into SwiftUI**

```swift
// messAIApp.swift
import SwiftUI
import FirebaseCore

@main
struct messAIApp: App {
    // Register AppDelegate for Firebase and APNs
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authViewModel: AuthViewModel
    
    init() {
        FirebaseApp.configure()
        
        let authService = AuthService()
        _authViewModel = StateObject(wrappedValue: AuthViewModel(authService: authService))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .onOpenURL { url in
                    // Handle deep link from notification
                    NotificationService.shared.handleDeepLink(url)
                }
        }
    }
}
```

---

#### Phase 2: NotificationService Implementation (1.5 hours)

**Create complete NotificationService:**

```swift
// Services/NotificationService.swift

import Foundation
import FirebaseMessaging
import FirebaseFirestore
import UserNotifications

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    // Published state
    @Published var permissionGranted: Bool = false
    @Published var fcmToken: String?
    @Published var currentBadgeCount: Int = 0
    
    // Dependencies
    private var authService: AuthService?
    private var chatService: ChatService?
    
    // Current conversation (to skip notifications)
    var activeConversationId: String?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Configuration
    
    func configure(authService: AuthService, chatService: ChatService) {
        self.authService = authService
        self.chatService = chatService
    }
    
    // MARK: - Permissions
    
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            self.permissionGranted = granted
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
    
    func checkPermissionStatus() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        let granted = settings.authorizationStatus == .authorized
        self.permissionGranted = granted
        return granted
    }
    
    // MARK: - Token Management
    
    func didReceiveFCMToken(_ token: String) {
        self.fcmToken = token
        
        // Save to Firestore if user is logged in
        Task {
            await saveFCMTokenToFirestore(token)
        }
    }
    
    func saveFCMTokenToFirestore(_ token: String) async {
        guard let userId = authService?.currentUser?.id else {
            print("No user logged in, skipping FCM token save")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        do {
            try await userRef.updateData([
                "fcmToken": token,
                "notificationsEnabled": true,
                "lastTokenUpdate": FieldValue.serverTimestamp()
            ])
            print("FCM token saved to Firestore")
        } catch {
            print("Error saving FCM token: \(error)")
        }
    }
    
    func removeFCMToken() async {
        guard let userId = authService?.currentUser?.id else { return }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        do {
            try await userRef.updateData([
                "fcmToken": FieldValue.delete(),
                "notificationsEnabled": false
            ])
            
            // Clear local state
            self.fcmToken = nil
            
            print("FCM token removed from Firestore")
        } catch {
            print("Error removing FCM token: \(error)")
        }
    }
    
    // MARK: - Badge Management
    
    func updateBadgeCount() async {
        guard let userId = authService?.currentUser?.id else {
            await MainActor.run {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
            return
        }
        
        let count = await chatService?.getUnreadConversationCount() ?? 0
        
        await MainActor.run {
            self.currentBadgeCount = count
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    
    func clearBadge() {
        Task {
            await MainActor.run {
                UIApplication.shared.applicationIconBadgeNumber = 0
                self.currentBadgeCount = 0
            }
        }
    }
    
    // MARK: - Deep Linking
    
    func handleDeepLink(_ url: URL) {
        // Format: messageai://conversation/{conversationId}
        guard url.scheme == "messageai" else { return }
        
        let pathComponents = url.pathComponents
        
        if pathComponents.count >= 3,
           pathComponents[1] == "conversation" {
            let conversationId = pathComponents[2]
            openConversation(conversationId: conversationId)
        }
    }
    
    func openConversation(conversationId: String) {
        // Post notification to navigate to conversation
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenConversation"),
            object: nil,
            userInfo: ["conversationId": conversationId]
        )
    }
}
```

---

#### Phase 3: Cloud Functions Setup (1-1.5 hours)

**1. Initialize Firebase Functions**

```bash
# In project root
firebase init functions

# Select:
# - Language: TypeScript
# - ESLint: Yes
# - Install dependencies: Yes
```

**2. Install Dependencies**

```bash
cd functions
npm install firebase-admin
npm install firebase-functions
```

**3. Implement sendMessageNotification**

(See Cloud Functions Design section above for full implementation)

**4. Deploy Functions**

```bash
firebase deploy --only functions
```

---

#### Phase 4: Integration & Testing (30 min)

**1. Update ChatView to track active conversation**

```swift
// Views/Chat/ChatView.swift
.onAppear {
    // Track active conversation (prevent self-notifications)
    NotificationService.shared.activeConversationId = conversation.id
}
.onDisappear {
    // Clear active conversation
    NotificationService.shared.activeConversationId = nil
}
```

**2. Update badge on app launch**

```swift
// messAIApp.swift
.onAppear {
    Task {
        await NotificationService.shared.updateBadgeCount()
    }
}
```

**3. Update badge on sign out**

```swift
// Services/AuthService.swift
func signOut() async throws {
    // Remove FCM token before signing out
    await NotificationService.shared.removeFCMToken()
    
    // Clear badge
    NotificationService.shared.clearBadge()
    
    // Existing sign out logic...
}
```

---

## Testing Strategy

### Test Categories

#### Unit Tests (5 tests)

**NotificationService Tests:**

1. **Test: FCM token save**
   - Action: Call `saveFCMTokenToFirestore()`
   - Expected: Token saved to Firestore users collection
   - Verify: Query Firestore, confirm token exists

2. **Test: Permission request**
   - Action: Call `requestPermission()`
   - Expected: iOS permission dialog appears
   - Verify: Check `permissionGranted` property

3. **Test: Badge count calculation**
   - Setup: Create 3 conversations with unread messages
   - Action: Call `updateBadgeCount()`
   - Expected: Badge = 3
   - Verify: Check `UIApplication.shared.applicationIconBadgeNumber`

4. **Test: Deep link parsing**
   - Input: `messageai://conversation/abc123`
   - Action: Call `handleDeepLink(url)`
   - Expected: Opens conversation "abc123"
   - Verify: NotificationCenter post received

5. **Test: Token removal on sign out**
   - Action: Call `removeFCMToken()`
   - Expected: Token deleted from Firestore
   - Verify: Query shows no `fcmToken` field

---

#### Integration Tests (8 tests)

**End-to-End Notification Flow:**

6. **Test: Send message → Receive notification**
   - Setup: Two physical devices, Device A (Alice), Device B (Bob)
   - Action: Alice sends message to Bob
   - Expected: Bob receives notification within 3 seconds
   - Verify: Bob's device shows banner notification

7. **Test: Tap notification → Open conversation**
   - Setup: Bob has notification from Alice
   - Action: Tap notification
   - Expected: App opens directly to Alice's conversation
   - Verify: ChatView displays with correct conversation

8. **Test: Foreground notification (app open)**
   - Setup: Bob has app open on different conversation
   - Action: Alice sends message
   - Expected: Bob sees in-app banner notification
   - Verify: Notification appears without leaving app

9. **Test: Background notification (app backgrounded)**
   - Setup: Bob backgrounds app (home button)
   - Action: Alice sends message
   - Expected: Bob sees lock screen notification
   - Verify: iOS system notification appears

10. **Test: Closed app notification (app terminated)**
    - Setup: Bob force-quits app (swipe up in app switcher)
    - Action: Alice sends message
    - Expected: Bob sees notification on lock screen
    - Verify: Tap opens app to conversation

11. **Test: Group message notification**
    - Setup: Group chat with Alice, Bob, Charlie
    - Action: Alice sends message to group
    - Expected: Bob and Charlie both receive notifications
    - Verify: Notification says "Alice" (sender name)

12. **Test: Multiple messages → Grouped notifications**
    - Setup: Bob has app closed
    - Action: Alice sends 3 messages quickly
    - Expected: iOS groups notifications by conversation
    - Verify: Shows "3 new messages from Alice"

13. **Test: Badge count accuracy**
    - Setup: Bob has 2 unread conversations
    - Action: Check app icon
    - Expected: Badge shows "2"
    - Action: Bob opens one conversation
    - Expected: Badge updates to "1"
    - Verify: Real-time badge updates

---

#### Edge Cases (6 tests)

14. **Test: No notification if user is in conversation**
    - Setup: Bob is actively chatting with Alice
    - Action: Alice sends message
    - Expected: No notification (Bob already sees message)
    - Verify: Cloud Function skips notification

15. **Test: No notification if notifications disabled**
    - Setup: Bob disables notifications in settings
    - Action: Alice sends message
    - Expected: No notification sent
    - Verify: Cloud Function checks `notificationsEnabled`

16. **Test: Invalid FCM token handling**
    - Setup: Bob uninstalls and reinstalls app (new token)
    - Action: Try to send to old token
    - Expected: Cloud Function detects invalid token
    - Verify: Old token removed from Firestore

17. **Test: Permission denied by user**
    - Setup: New user signs up
    - Action: Deny notification permission
    - Expected: App continues working, no crashes
    - Verify: No token saved to Firestore

18. **Test: Network offline → Notification on reconnect**
    - Setup: Bob's device is offline
    - Action: Alice sends message
    - Expected: FCM queues notification
    - Action: Bob comes online
    - Expected: Notification delivered
    - Verify: Notification appears when reconnected

19. **Test: Rapid message spam (10+ messages/second)**
    - Setup: Alice sends 20 messages very quickly
    - Action: Cloud Function processes all
    - Expected: Bob receives notifications (possibly grouped)
    - Verify: No crashes, all notifications sent

---

#### Performance Tests (4 tests)

20. **Test: Notification latency (one-on-one)**
    - Setup: Two devices with good WiFi
    - Action: Send message
    - Expected: Notification arrives in <3 seconds
    - Verify: Measure time from send to notification

21. **Test: Notification latency (group, 10 participants)**
    - Setup: Group with 10 users
    - Action: Send message to group
    - Expected: All participants notified within 5 seconds
    - Verify: Measure time for all 10 notifications

22. **Test: Cloud Function execution time**
    - Action: Monitor Cloud Function logs
    - Expected: Function completes in <2 seconds
    - Verify: Firebase Console shows execution time

23. **Test: Badge update performance**
    - Setup: User with 50 conversations, 10 unread
    - Action: Open app
    - Expected: Badge updates in <1 second
    - Verify: No lag in UI

---

#### Acceptance Criteria (5 tests)

24. **CRITICAL: Notifications work in production**
    - Setup: Real app on TestFlight
    - Action: Send message to tester
    - Expected: Notification received
    - **MVP GATE:** Must pass to ship

25. **CRITICAL: Deep linking works reliably**
    - Setup: Tap 10 different notifications
    - Expected: All 10 open correct conversations
    - **MVP GATE:** Must pass to ship

26. **CRITICAL: No notification spam**
    - Setup: User actively chatting
    - Expected: No self-notifications
    - **MVP GATE:** Must pass to ship

27. **CRITICAL: Permission UX is clear**
    - Setup: New user first launch
    - Expected: Clear explanation before permission request
    - **MVP GATE:** User understands why permission needed

28. **CRITICAL: Works on poor network**
    - Setup: Throttle to 3G speeds
    - Action: Send messages
    - Expected: Notifications still arrive (may be delayed)
    - **MVP GATE:** Graceful degradation

---

## Success Criteria

### Feature Complete When:

- [x] **iOS Push Notification Capability Added**
  - Xcode project configured
  - Push Notifications capability enabled
  - Background modes enabled

- [x] **APNs Authentication Configured**
  - APNs Auth Key uploaded to Firebase
  - Team ID and Key ID entered
  - Firebase Console shows "Connected"

- [x] **FCM Token Management Working**
  - Tokens received on device
  - Tokens saved to Firestore
  - Tokens removed on sign out

- [x] **Cloud Functions Deployed**
  - `sendMessageNotification` function live
  - Triggers on new messages
  - Sends notifications via FCM Admin SDK

- [x] **Notifications Delivered**
  - Foreground notifications show in-app
  - Background notifications show on lock screen
  - Closed app notifications show on lock screen
  - Notification latency <3 seconds

- [x] **Deep Linking Works**
  - Tap notification opens app
  - App navigates to correct conversation
  - Works from all app states (closed, background, foreground)

- [x] **Badge Count Accurate**
  - Badge shows unread conversation count
  - Badge updates in real-time
  - Badge clears when all read

- [x] **All Tests Pass**
  - 28 test scenarios complete
  - No critical bugs
  - Performance targets met

---

### Performance Targets

| Metric | Target | Critical |
|--------|--------|----------|
| Notification latency (1-on-1) | <3s | ✅ Yes |
| Notification latency (group, 10 users) | <5s | ✅ Yes |
| Cloud Function execution time | <2s | ⚠️ Preferred |
| Badge update time | <1s | ⚠️ Preferred |
| Deep link navigation time | <500ms | ⚠️ Preferred |
| Permission grant rate | >70% | ℹ️ Target |

---

### Quality Gates

**Before Merging:**
- ✅ Notifications work on physical device (simulator not sufficient)
- ✅ Deep linking tested with 10+ notifications
- ✅ No notification spam (skip if user in conversation)
- ✅ Badge count accurate across app lifecycle
- ✅ Cloud Functions deployed and triggered successfully
- ✅ APNs authentication valid (no certificate errors)
- ✅ Code compiles without errors or warnings
- ✅ No console errors during notification flow

**Before Declaring MVP Complete:**
- ✅ All 5 critical acceptance tests pass
- ✅ Tested with 2+ physical devices
- ✅ Works in TestFlight environment
- ✅ Permission UX reviewed and approved
- ✅ Notification content is appropriate
- ✅ No crashes in notification path

---

## Risk Assessment

### Risk 1: APNs Certificate Configuration Complexity 🟡 MEDIUM

**Issue:** APNs setup requires Apple Developer account, certificates, and correct configuration. Easy to misconfigure.

**Likelihood:** MEDIUM (common first-time mistake)  
**Impact:** HIGH (blocks all notifications)

**Mitigation:**
- Follow Apple's official documentation step-by-step
- Use APNs Auth Key method (easier than certificates)
- Firebase automatically handles APNs certificate issues
- Test with simulator first, then physical device
- Firebase Console provides clear error messages

**Contingency:**
- If Auth Key fails, fall back to APNs Certificates (.p12 method)
- Use Firebase Console's APNs tester to validate setup
- Community support (StackOverflow, Firebase Discord)

**Status:** 🟡 Documented, mitigated with Firebase

---

### Risk 2: Physical Device Required for Testing 🟢 LOW

**Issue:** iOS Simulator cannot receive push notifications. Must test on physical device.

**Likelihood:** HIGH (guaranteed requirement)  
**Impact:** MEDIUM (slows testing, but manageable)

**Mitigation:**
- Plan to test on physical iPhone/iPad
- Ensure device has active developer profile
- Use TestFlight for broader testing
- Xcode can install directly to device

**Contingency:**
- If no physical device available:
  - Use Firebase Console's Cloud Messaging test tool
  - Deploy to TestFlight and test there
  - Ask friend/colleague to test

**Status:** 🟢 Expected, planned for

---

### Risk 3: Cloud Functions Cold Start Latency 🟡 MEDIUM

**Issue:** Cloud Functions can have 1-3 second cold start if unused for 15+ minutes. Adds to notification latency.

**Likelihood:** MEDIUM (happens during low usage periods)  
**Impact:** MEDIUM (user experience, not critical)

**Mitigation:**
- Firebase keeps functions warm during active usage
- 1-3 second cold start + 1-2 second execution = 2-5 second total
- Still within acceptable range (<5 seconds)
- For production: Use Firebase Blaze plan with min instances (keeps warm)

**Contingency:**
- Acceptable for MVP (most messages during active hours)
- Future optimization: Keep functions warm with scheduled pings
- Alternative: Move to HTTP endpoint with always-on server

**Status:** 🟢 Acceptable for MVP

---

### Risk 4: iOS Notification Permission Denial 🟡 MEDIUM

**Issue:** Users may deny notification permission, breaking key MVP feature.

**Likelihood:** MEDIUM (30-40% of users deny initially)  
**Impact:** MEDIUM (app works but notifications don't)

**Mitigation:**
- Show clear explanation **before** iOS permission prompt
- Explain value: "Get notified instantly when friends message you"
- Allow users to enable later in settings
- App continues working without notifications (not a crash)

**Contingency:**
- Add "Enable Notifications" prompt in settings
- Show in-app explanation of benefits
- Provide deep link to iOS Settings if denied

**Status:** 🟡 UX design required

---

### Risk 5: FCM Token Rotation and Invalidation 🟢 LOW

**Issue:** FCM tokens can change when app reinstalls, or become invalid over time.

**Likelihood:** LOW (infrequent, but happens)  
**Impact:** LOW (automatic recovery)

**Mitigation:**
- FCM automatically provides new token on change
- Cloud Function detects invalid tokens and removes them
- NotificationService saves new token on each update
- Firestore always has latest token

**Contingency:**
- If token invalid: Cloud Function cleans up automatically
- User receives new token on next app launch
- No user-facing impact

**Status:** 🟢 Handled automatically

---

### Risk 6: Notification Content Privacy Concerns 🟡 MEDIUM

**Issue:** Message previews visible on lock screen may be seen by others.

**Likelihood:** MEDIUM (privacy-conscious users concerned)  
**Impact:** LOW (user preference, not functionality)

**Mitigation:**
- Match industry standard (WhatsApp, iMessage show previews)
- iOS lock screen settings allow users to hide previews
- Document privacy settings in app
- Future: Add app-level toggle for preview visibility

**Contingency:**
- If privacy feedback: Add "Hide message preview" setting (PR #16)
- Show "New message from Alice" instead of message content
- User-configurable in profile settings

**Status:** 🟡 Future enhancement

---

## Open Questions

### Question 1: Notification Sound Customization?

**Question:** Should we allow custom notification sounds, or use default iOS sound?

**Options:**
- A: Default iOS sound (simple, familiar)
- B: Custom sound (brand identity, differentiation)
- C: User-selectable sounds (maximum flexibility)

**Decision Needed By:** Before implementation (Phase 1)

**Recommendation:** **Option A for MVP** - Default sound is familiar and requires no additional assets. Can add custom sound in polish phase (PR #20).

---

### Question 2: Notification Grouping Strategy?

**Question:** How should we group multiple notifications from same sender?

**Options:**
- A: Automatic iOS grouping by thread-id (system default)
- B: Show only latest notification (dismiss previous)
- C: Show count: "Alice sent 3 new messages"

**Decision Needed By:** Cloud Function implementation (Phase 3)

**Recommendation:** **Option A** - iOS automatically groups by thread-id (conversationId). Clean, built-in, no extra work.

---

### Question 3: Notification Actions (Quick Reply)?

**Question:** Should users be able to reply directly from notification without opening app?

**Options:**
- A: No actions, just tap to open (simple MVP)
- B: Add "Reply" action with text input (advanced)
- C: Add "Mark as Read" action

**Decision Needed By:** Before implementation (Phase 1)

**Recommendation:** **Option A for MVP** - Quick reply is complex (requires notification service extension, background processing). Great feature for post-MVP (PR #24).

---

## Timeline

### Total Estimate: 3-4 hours

| Phase | Tasks | Time | Status |
|-------|-------|------|--------|
| **Phase 1: iOS Setup** | Xcode capabilities, Info.plist, APNs config | 1h | ⏳ |
| **Phase 2: NotificationService** | Token management, permissions, deep linking | 1.5h | ⏳ |
| **Phase 3: Cloud Functions** | Setup, implement, deploy | 1-1.5h | ⏳ |
| **Phase 4: Integration & Testing** | Wire up, test on device | 30m | ⏳ |
| **TOTAL** | | **3-4h** | |

### Detailed Breakdown

**Phase 1: iOS Setup (1 hour)**
- Add Push Notifications capability (5 min)
- Add Background Modes capability (5 min)
- Create APNs Auth Key in Apple Developer (15 min)
- Upload Auth Key to Firebase Console (10 min)
- Update Info.plist with notification keys (10 min)
- Create AppDelegate.swift (15 min)

**Phase 2: NotificationService Implementation (1.5 hours)**
- Create NotificationService.swift structure (20 min)
- Implement token management (20 min)
- Implement permission handling (15 min)
- Implement badge management (15 min)
- Implement deep linking (20 min)

**Phase 3: Cloud Functions Setup (1-1.5 hours)**
- Initialize Firebase Functions project (15 min)
- Install dependencies (5 min)
- Write sendMessageNotification function (30 min)
- Test locally (if possible) (10 min)
- Deploy to Firebase (10 min)
- Verify deployment in console (10 min)

**Phase 4: Integration & Testing (30 minutes)**
- Integrate AppDelegate into messAIApp (5 min)
- Update ChatView to track active conversation (5 min)
- Update AuthService to save token on login (5 min)
- Test on physical device (15 min)
  - Send message → receive notification
  - Tap notification → open conversation
  - Check badge count

---

## Dependencies

### Requires (Must be complete first):

- ✅ **PR #1: Firebase Project Setup**
  - Firebase project exists
  - Firebase SDK integrated
  - GoogleService-Info.plist configured

- ✅ **PR #2: Authentication**
  - User IDs available
  - Auth state management
  - User model with Firestore

- ✅ **PR #5: Chat Service**
  - Messages written to Firestore
  - Firestore collection structure defined
  - Message model stable

- ✅ **PR #10: Real-Time Messaging**
  - Messages deliver to recipients
  - Conversation IDs established
  - Read receipts working

### Blocks (Cannot start until this is done):

- **PR #21: Testing & Bug Fixes**
  - Needs notifications working to test end-to-end
  - Multi-device testing requires notifications

- **MVP Submission**
  - This is the final MVP requirement
  - Cannot submit until notifications work

---

## References

### Apple Documentation
- [UserNotifications Framework](https://developer.apple.com/documentation/usernotifications)
- [Registering Your App with APNs](https://developer.apple.com/documentation/usernotifications/registering_your_app_with_apns)
- [Handling Notifications](https://developer.apple.com/documentation/usernotifications/handling_notifications_and_notification-related_actions)

### Firebase Documentation
- [Firebase Cloud Messaging for iOS](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [Cloud Functions for Firebase](https://firebase.google.com/docs/functions)
- [Send Messages with FCM Admin SDK](https://firebase.google.com/docs/cloud-messaging/send-message)

### Related PRs
- PR #1: Firebase setup (GoogleService-Info.plist)
- PR #2: Authentication (user IDs, auth state)
- PR #5: Chat Service (Firestore structure)
- PR #10: Real-time messaging (message delivery)

### External Resources
- [APNs Provider API](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server)
- [Firebase Cloud Messaging Best Practices](https://firebase.google.com/docs/cloud-messaging/concept-options)

---

## Notes

### Why This Is The Last MVP Feature

Push notifications complete the **asynchronous messaging experience**. Every other feature (real-time messaging, read receipts, presence, groups) assumes users have the app open. Notifications enable:

1. **True asynchrony** - Users don't need app open to receive messages
2. **Timely responses** - Users know immediately when someone messages them
3. **App re-engagement** - Brings users back to app when activity happens
4. **Production quality** - Without this, app feels incomplete and broken

**This is the final piece of the MVP puzzle.** Once notifications work, you have a fully-functional messaging app that rivals WhatsApp, iMessage, and Telegram in core features.

---

### Testing Notes

**Simulator Limitations:**
- ❌ Cannot receive push notifications (APNs requires physical device)
- ✅ Can test permission UI
- ✅ Can test deep linking (manual URL simulation)
- ✅ Can test badge management

**Physical Device Required:**
- ✅ Full notification testing
- ✅ Foreground, background, closed app states
- ✅ Notification tap and deep linking
- ✅ Real APNs token generation

**TestFlight Testing:**
- ✅ Production-like environment
- ✅ Test with beta testers
- ✅ Real-world notification delivery
- ✅ Final validation before App Store

---

### Future Enhancements (Post-MVP)

**PR #24: Notification Enhancements** (3-4 hours)
- Quick reply from notification (notification service extension)
- "Mark as Read" action button
- Mute conversation notifications
- Custom notification sounds per conversation
- Notification preview toggle (privacy)

**Advanced Features:**
- Rich notifications with images
- Notification delivery reports
- Scheduled notifications (reminders)
- Smart notification timing (ML-based)
- Cross-device notification sync

---

**Status:** ✅ PLANNING COMPLETE  
**Next Step:** Implement Phase 1 (iOS Setup) when ready  
**Estimated Total Time:** 3-4 hours  
**Complexity:** HIGH (APNs, Cloud Functions, device testing)  
**Impact:** 🔥 CRITICAL - Final MVP requirement

---

*"The app works without notifications, but it's not a messaging app until notifications work."*

