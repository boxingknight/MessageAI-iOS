# PR#17: Push Notifications - Implementation Checklist

**Use this as your daily todo list.** Check off items as you complete them.

**Estimated Total Time:** 3-4 hours  
**Complexity:** HIGH (APNs, Cloud Functions, physical device required)

---

## Pre-Implementation Setup (15 minutes)

- [ ] Read main planning document (`PR17_PUSH_NOTIFICATIONS_FCM.md`) (~45 min)
- [ ] Review Quick Start guide (`PR17_README.md`) (~10 min)
- [ ] Prerequisites verified:
  - [ ] Physical iOS device available (simulator won't work!)
  - [ ] Apple Developer account access
  - [ ] Device registered in Apple Developer portal
  - [ ] Xcode 15+ installed
  - [ ] Firebase CLI installed (`npm install -g firebase-tools`)
  - [ ] Node.js 18+ installed (for Cloud Functions)
  - [ ] Firebase project has Blaze plan (for Cloud Functions)
- [ ] Git branch created:
  ```bash
  git checkout -b feature/pr17-push-notifications
  ```

**Checkpoint:** Ready to start! Physical device connected, developer account accessible.

---

## Phase 1: Apple Developer & Firebase Configuration (30 minutes)

### 1.1: Create APNs Authentication Key (15 minutes)

#### Go to Apple Developer Portal
- [ ] Navigate to [https://developer.apple.com/account/](https://developer.apple.com/account/)
- [ ] Sign in with Apple ID
- [ ] Click "Certificates, Identifiers & Profiles"

#### Create New Key
- [ ] Click "Keys" in sidebar
- [ ] Click "+" button (Create a new key)
- [ ] Key Name: `MessageAI Push Notifications`
- [ ] Check "Apple Push Notifications service (APNs)"
- [ ] Click "Continue"
- [ ] Click "Register"

#### Download Key
- [ ] Click "Download" (save `.p8` file - **IMPORTANT: Can only download once!**)
- [ ] Save to secure location: `~/Downloads/AuthKey_XXXXXXXXXX.p8`
- [ ] Note **Key ID** (10 characters, e.g., `AB12CD34EF`)
- [ ] Note **Team ID** (in top-right of page, e.g., `XYZ1234ABC`)

**Store safely:**
```bash
# Copy to secure location (not in git!)
mkdir -p ~/secure/messageai-apns/
cp ~/Downloads/AuthKey_*.p8 ~/secure/messageai-apns/
```

---

### 1.2: Upload APNs Key to Firebase (10 minutes)

#### Open Firebase Console
- [ ] Navigate to [https://console.firebase.google.com/](https://console.firebase.google.com/)
- [ ] Select "MessageAI" project
- [ ] Click gear icon → "Project settings"

#### Configure APNs
- [ ] Click "Cloud Messaging" tab
- [ ] Scroll to "Apple app configuration"
- [ ] Click "Upload" under "APNs Authentication Key"
- [ ] Select `.p8` file from secure location
- [ ] Enter **Key ID** (from Apple Developer portal)
- [ ] Enter **Team ID** (from Apple Developer portal)
- [ ] Click "Upload"

#### Verify Configuration
- [ ] Status shows "APNs certificate uploaded successfully" ✅
- [ ] Key ID and Team ID displayed correctly

**Checkpoint:** APNs authentication configured! ✓

---

### 1.3: Enable Firebase Cloud Functions (5 minutes)

#### Upgrade to Blaze Plan
- [ ] In Firebase Console → left sidebar
- [ ] Click "Upgrade" (if on Spark plan)
- [ ] Select "Blaze" (pay as you go)
- [ ] **Note:** Free tier includes 2M invocations/month (more than enough for MVP)
- [ ] Add payment method
- [ ] Confirm upgrade

#### Verify Functions Enabled
- [ ] Left sidebar → Click "Functions"
- [ ] Should see "Get started" page (not "Upgrade required")

**Checkpoint:** Firebase Cloud Functions ready! ✓

**Commit:**
```bash
git add .
git commit -m "[PR #17] Phase 1: APNs authentication configured in Firebase"
```

---

## Phase 2: Xcode Project Configuration (20 minutes)

### 2.1: Add Push Notifications Capability (5 minutes)

#### Open Xcode Project
- [ ] Open `messAI.xcodeproj` in Xcode
- [ ] Select `messAI` project in navigator
- [ ] Select `messAI` target

#### Add Capability
- [ ] Click "Signing & Capabilities" tab
- [ ] Click "+ Capability" button (top-left)
- [ ] Search for "Push Notifications"
- [ ] Double-click "Push Notifications"
- [ ] Verify capability added (shows in list)

#### Verify Bundle ID
- [ ] In "Signing & Capabilities", check "Bundle Identifier"
- [ ] Must match: `com.isaacjaramillo.messAI`
- [ ] If different, update in Firebase Console to match

---

### 2.2: Add Background Modes Capability (3 minutes)

#### Add Capability
- [ ] Still in "Signing & Capabilities" tab
- [ ] Click "+ Capability" button
- [ ] Search for "Background Modes"
- [ ] Double-click "Background Modes"
- [ ] Check ✓ "Remote notifications"

**Checkpoint:** Capabilities added! ✓

---

### 2.3: Update Info.plist (5 minutes)

#### Open Info.plist
- [ ] In Xcode navigator, find `Info.plist`
- [ ] Right-click → "Open As" → "Source Code"

#### Add Notification Permission Description
- [ ] Add before `</dict>`:
  ```xml
  <key>NSUserNotificationsUsageDescription</key>
  <string>MessageAI needs notifications to alert you when you receive new messages, even when the app is closed.</string>
  ```

#### Add Background Modes
- [ ] Add before `</dict>`:
  ```xml
  <key>UIBackgroundModes</key>
  <array>
      <string>remote-notification</string>
  </array>
  ```

#### Disable Firebase Proxy (Required for Manual APNs Handling)
- [ ] Add before `</dict>`:
  ```xml
  <key>FirebaseAppDelegateProxyEnabled</key>
  <false/>
  ```

#### Verify Info.plist
- [ ] Switch back to "Property List" view
- [ ] Confirm all 3 keys added correctly

---

### 2.4: Add Firebase Messaging SDK (5 minutes)

#### Add Package Dependency
- [ ] In Xcode, File → Add Package Dependencies...
- [ ] Search URL: `https://github.com/firebase/firebase-ios-sdk`
- [ ] Version: "Up to Next Major Version" `10.0.0` < `11.0.0`
- [ ] Click "Add Package"

#### Select Product
- [ ] Check ✓ "FirebaseMessaging"
- [ ] Target: `messAI`
- [ ] Click "Add Package"

#### Verify Import
- [ ] Wait for package resolution
- [ ] In Project Navigator, expand "Package Dependencies"
- [ ] Confirm "firebase-ios-sdk" appears

---

### 2.5: Build and Verify (2 minutes)

#### Test Build
- [ ] Select "Any iOS Device (arm64)" as destination
- [ ] Press Cmd+B (build)
- [ ] Verify: "Build Succeeded" ✅
- [ ] Check for warnings (should be none related to capabilities)

**Checkpoint:** Xcode project configured! ✓

**Commit:**
```bash
git add .
git commit -m "[PR #17] Phase 2: Xcode capabilities and Info.plist configured"
```

---

## Phase 3: Create AppDelegate for APNs (30 minutes)

### 3.1: Create AppDelegate.swift (25 minutes)

#### Create New File
- [ ] In Xcode, File → New → File...
- [ ] Select "Swift File"
- [ ] Name: `AppDelegate.swift`
- [ ] Target: `messAI`
- [ ] Create in: `messAI/Utilities/`

#### Implement AppDelegate
- [ ] Add imports:
  ```swift
  import UIKit
  import FirebaseCore
  import FirebaseMessaging
  import UserNotifications
  ```

- [ ] Create AppDelegate class:
  ```swift
  class AppDelegate: NSObject, UIApplicationDelegate {
      func application(
          _ application: UIApplication,
          didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
      ) -> Bool {
          // Set notification center delegate
          UNUserNotificationCenter.current().delegate = self
          
          // Request notification permission
          let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
          UNUserNotificationCenter.current().requestAuthorization(
              options: authOptions
          ) { granted, error in
              if let error = error {
                  print("❌ Notification permission error: \(error)")
              } else {
                  print("✅ Notification permission granted: \(granted)")
              }
          }
          
          // Register for remote notifications
          application.registerForRemoteNotifications()
          
          // Set FCM delegate
          Messaging.messaging().delegate = self
          
          return true
      }
      
      // Called when APNs token received
      func application(
          _ application: UIApplication,
          didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
      ) {
          print("📱 APNs token received")
          
          // Pass to Firebase Messaging
          Messaging.messaging().apnsToken = deviceToken
      }
      
      // Called if registration fails
      func application(
          _ application: UIApplication,
          didFailToRegisterForRemoteNotificationsWithError error: Error
      ) {
          print("❌ Failed to register for notifications: \(error)")
      }
  }
  ```

- [ ] Add MessagingDelegate extension:
  ```swift
  // MARK: - MessagingDelegate
  extension AppDelegate: MessagingDelegate {
      func messaging(
          _ messaging: Messaging,
          didReceiveRegistrationToken fcmToken: String?
      ) {
          guard let token = fcmToken else {
              print("❌ No FCM token received")
              return
          }
          
          print("🔥 FCM Token: \(token)")
          
          // Save to NotificationService
          Task { @MainActor in
              NotificationService.shared.didReceiveFCMToken(token)
          }
      }
  }
  ```

- [ ] Add UNUserNotificationCenterDelegate extension:
  ```swift
  // MARK: - UNUserNotificationCenterDelegate
  extension AppDelegate: UNUserNotificationCenterDelegate {
      // Handle notification in foreground (app is open)
      func userNotificationCenter(
          _ center: UNUserNotificationCenter,
          willPresent notification: UNNotification,
          withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
      ) {
          let userInfo = notification.request.content.userInfo
          print("📬 Foreground notification: \(userInfo)")
          
          // Show banner, sound, and badge even when app is open
          completionHandler([.banner, .sound, .badge])
      }
      
      // Handle notification tap (user tapped notification)
      func userNotificationCenter(
          _ center: UNUserNotificationCenter,
          didReceive response: UNNotificationResponse,
          withCompletionHandler completionHandler: @escaping () -> Void
      ) {
          let userInfo = response.notification.request.content.userInfo
          print("👆 Notification tapped: \(userInfo)")
          
          // Extract conversation ID from payload
          if let conversationId = userInfo["conversationId"] as? String {
              Task { @MainActor in
                  NotificationService.shared.openConversation(conversationId: conversationId)
              }
          }
          
          completionHandler()
      }
  }
  ```

#### Verify Syntax
- [ ] Press Cmd+B (build)
- [ ] Fix any syntax errors (should compile, but NotificationService not created yet)

---

### 3.2: Integrate AppDelegate into messAIApp (5 minutes)

#### Open messAIApp.swift
- [ ] Navigate to `messAI/messAIApp.swift`

#### Add AppDelegate Adapter
- [ ] Add below `@main` line:
  ```swift
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  ```

#### Verify Full messAIApp.swift Structure
- [ ] Should look like:
  ```swift
  import SwiftUI
  import FirebaseCore
  
  @main
  struct messAIApp: App {
      // Register AppDelegate for Firebase and APNs
      @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
      
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
                      // Handle deep link from notification tap
                      NotificationService.shared.handleDeepLink(url)
                  }
          }
      }
  }
  ```

#### Build (Will Fail - Expected)
- [ ] Press Cmd+B
- [ ] Expected errors: `NotificationService` not found (we'll create next)

**Checkpoint:** AppDelegate structure complete! ✓

**Commit:**
```bash
git add Utilities/AppDelegate.swift
git add messAI/messAIApp.swift
git commit -m "[PR #17] Phase 3: AppDelegate created with APNs handling"
```

---

## Phase 4: Create NotificationService (45 minutes)

### 4.1: Update User Model (5 minutes)

#### Open Models/User.swift
- [ ] Add FCM token properties to User struct:
  ```swift
  // ✨ Push Notification Support (PR #17)
  var fcmToken: String?
  var notificationsEnabled: Bool = true
  var lastTokenUpdate: Date?
  ```

#### Update Firestore Conversion
- [ ] In `toDictionary()` method, add:
  ```swift
  "fcmToken": fcmToken as Any,
  "notificationsEnabled": notificationsEnabled,
  "lastTokenUpdate": lastTokenUpdate?.timeIntervalSince1970 as Any
  ```

- [ ] In `init(from dictionary:)`, add:
  ```swift
  self.fcmToken = dictionary["fcmToken"] as? String
  self.notificationsEnabled = dictionary["notificationsEnabled"] as? Bool ?? true
  self.lastTokenUpdate = (dictionary["lastTokenUpdate"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
  ```

#### Test Build
- [ ] Press Cmd+B
- [ ] Verify no errors in User.swift

---

### 4.2: Create NotificationService.swift Structure (10 minutes)

#### Create New File
- [ ] File → New → File... → Swift File
- [ ] Name: `NotificationService.swift`
- [ ] Target: `messAI`
- [ ] Group: `Services/`

#### Add Imports and Class Declaration
- [ ] Add:
  ```swift
  import Foundation
  import FirebaseMessaging
  import FirebaseFirestore
  import UserNotifications
  import SwiftUI
  
  @MainActor
  class NotificationService: NSObject, ObservableObject {
      // Singleton pattern
      static let shared = NotificationService()
      
      // Published state
      @Published var permissionGranted: Bool = false
      @Published var fcmToken: String?
      @Published var currentBadgeCount: Int = 0
      
      // Dependencies (will be injected)
      private var authService: AuthService?
      private var chatService: ChatService?
      
      // Track active conversation (skip notifications for active chat)
      var activeConversationId: String?
      
      private override init() {
          super.init()
      }
      
      // Configure dependencies (call after services initialized)
      func configure(authService: AuthService, chatService: ChatService) {
          self.authService = authService
          self.chatService = chatService
      }
  }
  ```

---

### 4.3: Implement Permission Management (10 minutes)

#### Add Permission Methods
- [ ] Add to NotificationService class:
  ```swift
  // MARK: - Permission Management
  
  /// Request notification permission from user
  func requestPermission() async -> Bool {
      let center = UNUserNotificationCenter.current()
      
      do {
          let granted = try await center.requestAuthorization(
              options: [.alert, .sound, .badge]
          )
          
          await MainActor.run {
              self.permissionGranted = granted
          }
          
          print(granted ? "✅ Notification permission granted" : "❌ Notification permission denied")
          return granted
      } catch {
          print("❌ Error requesting notification permission: \(error)")
          return false
      }
  }
  
  /// Check current permission status
  func checkPermissionStatus() async -> Bool {
      let center = UNUserNotificationCenter.current()
      let settings = await center.notificationSettings()
      
      let granted = settings.authorizationStatus == .authorized
      
      await MainActor.run {
          self.permissionGranted = granted
      }
      
      return granted
  }
  ```

---

### 4.4: Implement FCM Token Management (10 minutes)

#### Add Token Methods
- [ ] Add to NotificationService class:
  ```swift
  // MARK: - FCM Token Management
  
  /// Called when FCM token received from Firebase
  func didReceiveFCMToken(_ token: String) {
      self.fcmToken = token
      print("🔥 FCM Token updated: \(token)")
      
      // Save to Firestore
      Task {
          await saveFCMTokenToFirestore(token)
      }
  }
  
  /// Save FCM token to user's Firestore document
  func saveFCMTokenToFirestore(_ token: String) async {
      guard let userId = authService?.currentUser?.id else {
          print("⚠️ No user logged in, skipping FCM token save")
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
          print("✅ FCM token saved to Firestore for user: \(userId)")
      } catch {
          print("❌ Error saving FCM token: \(error)")
      }
  }
  
  /// Remove FCM token on sign out
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
          await MainActor.run {
              self.fcmToken = nil
          }
          
          print("✅ FCM token removed from Firestore")
      } catch {
          print("❌ Error removing FCM token: \(error)")
      }
  }
  ```

---

### 4.5: Implement Badge Management (5 minutes)

#### Add Badge Methods
- [ ] Add to NotificationService class:
  ```swift
  // MARK: - Badge Management
  
  /// Update app icon badge count based on unread conversations
  func updateBadgeCount() async {
      guard let userId = authService?.currentUser?.id else {
          await setBadgeCount(0)
          return
      }
      
      // Get unread conversation count from ChatService
      let count = await chatService?.getUnreadConversationCount() ?? 0
      
      await setBadgeCount(count)
  }
  
  /// Set badge count on app icon
  private func setBadgeCount(_ count: Int) async {
      await MainActor.run {
          self.currentBadgeCount = count
          UIApplication.shared.applicationIconBadgeNumber = count
          print("🔢 Badge count updated: \(count)")
      }
  }
  
  /// Clear badge count
  func clearBadge() {
      Task {
          await setBadgeCount(0)
      }
  }
  ```

---

### 4.6: Implement Deep Linking (5 minutes)

#### Add Deep Link Methods
- [ ] Add to NotificationService class:
  ```swift
  // MARK: - Deep Linking
  
  /// Handle deep link URL from notification tap
  func handleDeepLink(_ url: URL) {
      print("🔗 Deep link received: \(url)")
      
      // Expected format: messageai://conversation/{conversationId}
      guard url.scheme == "messageai" else {
          print("⚠️ Unknown URL scheme: \(url.scheme ?? "nil")")
          return
      }
      
      let pathComponents = url.pathComponents
      
      if pathComponents.count >= 3,
         pathComponents[1] == "conversation" {
          let conversationId = pathComponents[2]
          openConversation(conversationId: conversationId)
      }
  }
  
  /// Navigate to conversation (called from notification tap)
  func openConversation(conversationId: String) {
      print("📱 Opening conversation: \(conversationId)")
      
      // Post notification for ChatListView to handle navigation
      NotificationCenter.default.post(
          name: NSNotification.Name("OpenConversation"),
          object: nil,
          userInfo: ["conversationId": conversationId]
      )
  }
  ```

#### Verify Build
- [ ] Press Cmd+B
- [ ] Should compile successfully now!

**Checkpoint:** NotificationService complete! ✓

**Commit:**
```bash
git add Models/User.swift
git add Services/NotificationService.swift
git commit -m "[PR #17] Phase 4: NotificationService with token management and deep linking"
```

---

## Phase 5: Update ChatService for Unread Count (15 minutes)

### 5.1: Add Unread Count Method to ChatService (15 minutes)

#### Open Services/ChatService.swift
- [ ] Add new method at end of class:
  ```swift
  // MARK: - Badge Count Support (PR #17)
  
  /// Get count of conversations with unread messages (for badge)
  func getUnreadConversationCount() async -> Int {
      guard let currentUserId = authService.currentUser?.id else {
          return 0
      }
      
      let db = Firestore.firestore()
      
      do {
          // Get all conversations for current user
          let snapshot = try await db.collection("conversations")
              .whereField("participantIds", arrayContains: currentUserId)
              .getDocuments()
          
          var unreadCount = 0
          
          for document in snapshot.documents {
              let data = document.data()
              
              // Check if conversation has unread messages
              guard let lastMessageData = data["lastMessage"] as? [String: Any],
                    let senderId = lastMessageData["senderId"] as? String,
                    let readBy = lastMessageData["readBy"] as? [String] else {
                  continue
              }
              
              // If last message is from someone else and current user hasn't read it
              if senderId != currentUserId && !readBy.contains(currentUserId) {
                  unreadCount += 1
              }
          }
          
          print("📬 Unread conversations: \(unreadCount)")
          return unreadCount
          
      } catch {
          print("❌ Error getting unread count: \(error)")
          return 0
      }
  }
  ```

#### Test Build
- [ ] Press Cmd+B
- [ ] Verify compiles successfully

**Commit:**
```bash
git add Services/ChatService.swift
git commit -m "[PR #17] Phase 5: Add unread conversation count for badge"
```

---

## Phase 6: Integrate NotificationService into App (20 minutes)

### 6.1: Configure NotificationService on App Launch (5 minutes)

#### Open ContentView.swift
- [ ] Add to ContentView struct:
  ```swift
  .onAppear {
      // Configure NotificationService with dependencies
      if let authService = authViewModel.authService,
         let chatService = authViewModel.chatService { // You may need to expose chatService
          NotificationService.shared.configure(
              authService: authService,
              chatService: chatService
          )
      }
      
      // Update badge count
      Task {
          await NotificationService.shared.updateBadgeCount()
      }
  }
  ```

**Note:** You may need to expose chatService from AuthViewModel or pass it differently based on your architecture.

---

### 6.2: Track Active Conversation in ChatView (5 minutes)

#### Open Views/Chat/ChatView.swift
- [ ] Add to ChatView body:
  ```swift
  .onAppear {
      // Existing code...
      
      // Track active conversation (skip notifications for this chat)
      NotificationService.shared.activeConversationId = conversation.id
  }
  .onDisappear {
      // Clear active conversation
      NotificationService.shared.activeConversationId = nil
  }
  ```

---

### 6.3: Remove Token on Sign Out (5 minutes)

#### Open Services/AuthService.swift
- [ ] Update `signOut()` method:
  ```swift
  func signOut() async throws {
      // Remove FCM token before signing out (PR #17)
      await NotificationService.shared.removeFCMToken()
      
      // Clear badge
      NotificationService.shared.clearBadge()
      
      // Existing sign out logic...
      try Auth.auth().signOut()
      // ... rest of sign out code
  }
  ```

---

### 6.4: Handle Deep Link Navigation in ChatListView (5 minutes)

#### Open Views/Chat/ChatListView.swift
- [ ] Add to ChatListView body:
  ```swift
  .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenConversation"))) { notification in
      guard let userInfo = notification.userInfo,
            let conversationId = userInfo["conversationId"] as? String else {
          return
      }
      
      // Find conversation in list
      if let conversation = viewModel.conversations.first(where: { $0.id == conversationId }) {
          // Navigate to conversation (set selection or push)
          self.selectedConversation = conversation // Adjust based on your navigation
      }
  }
  ```

**Note:** Adjust navigation logic based on your existing navigation pattern (NavigationStack, NavigationLink, etc.)

**Commit:**
```bash
git add ContentView.swift
git add Views/Chat/ChatView.swift
git add Services/AuthService.swift
git add Views/Chat/ChatListView.swift
git commit -m "[PR #17] Phase 6: Integrate NotificationService throughout app"
```

**Checkpoint:** iOS integration complete! ✓

---

## Phase 7: Cloud Functions Setup (45 minutes)

### 7.1: Initialize Firebase Functions (10 minutes)

#### Install Firebase CLI (if not installed)
- [ ] Open Terminal
- [ ] Run:
  ```bash
  npm install -g firebase-tools
  ```
- [ ] Verify installation:
  ```bash
  firebase --version
  ```

#### Login to Firebase
- [ ] Run:
  ```bash
  firebase login
  ```
- [ ] Follow browser authentication flow
- [ ] Confirm "Success! Logged in as [your-email]"

#### Initialize Functions
- [ ] Navigate to project root:
  ```bash
  cd ~/Documents/GauntletAI/Week2/messAI
  ```
- [ ] Initialize functions:
  ```bash
  firebase init functions
  ```
- [ ] Selections:
  - Use existing project: **MessageAI (messageai-95c8f)**
  - Language: **TypeScript**
  - ESLint: **Yes**
  - Install dependencies: **Yes**

#### Verify Structure Created
- [ ] Check files created:
  ```
  functions/
  ├── package.json
  ├── tsconfig.json
  ├── .eslintrc.js
  └── src/
      └── index.ts
  ```

**Checkpoint:** Cloud Functions initialized! ✓

---

### 7.2: Install Dependencies (5 minutes)

#### Navigate to Functions Directory
- [ ] Run:
  ```bash
  cd functions
  ```

#### Install Required Packages
- [ ] Install Firebase Admin SDK:
  ```bash
  npm install firebase-admin
  ```
- [ ] Install Firebase Functions:
  ```bash
  npm install firebase-functions@latest
  ```

#### Verify Dependencies
- [ ] Check `package.json`:
  ```json
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0"
  }
  ```

---

### 7.3: Implement sendMessageNotification Function (25 minutes)

#### Open functions/src/index.ts
- [ ] Replace entire content with:

```typescript
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();

/**
 * Send push notification when new message is created
 * Triggered by: Firestore onCreate at /messages/{messageId}
 */
export const sendMessageNotification = functions.firestore
  .document("messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const messageId = context.params.messageId;

    console.log(`📬 New message detected: ${messageId}`);

    try {
      // 1. Get conversation details
      const conversationRef = admin
        .firestore()
        .collection("conversations")
        .doc(message.conversationId);
      const conversationSnap = await conversationRef.get();

      if (!conversationSnap.exists) {
        console.log("❌ Conversation not found");
        return null;
      }

      const conversation = conversationSnap.data()!;

      // 2. Get sender info
      const senderRef = admin
        .firestore()
        .collection("users")
        .doc(message.senderId);
      const senderSnap = await senderRef.get();

      if (!senderSnap.exists) {
        console.log("❌ Sender not found");
        return null;
      }

      const sender = senderSnap.data()!;

      // 3. Find recipients (all participants except sender)
      const recipientIds = conversation.participantIds.filter(
        (id: string) => id !== message.senderId
      );

      console.log(`👥 Sending to ${recipientIds.length} recipients`);

      // 4. Send notification to each recipient
      const notificationPromises = recipientIds.map(async (recipientId: string) => {
        // Get recipient data
        const recipientRef = admin
          .firestore()
          .collection("users")
          .doc(recipientId);
        const recipientSnap = await recipientRef.get();

        if (!recipientSnap.exists) {
          console.log(`⚠️ Recipient ${recipientId} not found`);
          return;
        }

        const recipient = recipientSnap.data()!;

        // Skip if recipient is online and in this conversation
        if (
          recipient.isOnline &&
          recipient.currentConversationId === message.conversationId
        ) {
          console.log(`⏭️ Skipping ${recipientId} (active in conversation)`);
          return;
        }

        // Skip if notifications disabled or no FCM token
        if (!recipient.notificationsEnabled || !recipient.fcmToken) {
          console.log(`⏭️ Skipping ${recipientId} (notifications disabled or no token)`);
          return;
        }

        // Get unread count for badge
        const unreadCount = await getUnreadConversationCount(recipientId);

        // Build notification payload
        const notificationTitle = conversation.isGroup
          ? conversation.groupName || "Group Chat"
          : sender.displayName;

        const notificationBody = message.text
          ? conversation.isGroup
            ? `${sender.displayName}: ${message.text}`
            : message.text
          : "📷 Image";

        const payload = {
          notification: {
            title: notificationTitle,
            body: notificationBody,
            sound: "default",
          },
          data: {
            conversationId: message.conversationId,
            senderId: message.senderId,
            messageId: messageId,
            type: "new_message",
          },
          apns: {
            payload: {
              aps: {
                badge: unreadCount,
                sound: "default",
                category: "MESSAGE",
                "thread-id": message.conversationId,
              },
            },
          },
          token: recipient.fcmToken,
        };

        // Send notification
        try {
          await admin.messaging().send(payload);
          console.log(`✅ Notification sent to ${recipientId}`);
        } catch (error: any) {
          console.error(`❌ Failed to send to ${recipientId}:`, error);

          // If token is invalid, remove it from user document
          if (
            error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered"
          ) {
            console.log(`🗑️ Removing invalid token for ${recipientId}`);
            await recipientRef.update({
              fcmToken: admin.firestore.FieldValue.delete(),
            });
          }
        }
      });

      await Promise.all(notificationPromises);
      console.log(`✅ All notifications processed for message ${messageId}`);

      return null;
    } catch (error) {
      console.error("❌ Error in sendMessageNotification:", error);
      return null;
    }
  });

/**
 * Helper: Count unread conversations for badge
 */
async function getUnreadConversationCount(userId: string): Promise<number> {
  try {
    const conversationsSnap = await admin
      .firestore()
      .collection("conversations")
      .where("participantIds", "array-contains", userId)
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
  } catch (error) {
    console.error("Error getting unread count:", error);
    return 0;
  }
}
```

#### Verify Syntax
- [ ] Run TypeScript compiler:
  ```bash
  npm run build
  ```
- [ ] Verify: "Build succeeded" (no TypeScript errors)

---

### 7.4: Deploy Cloud Functions (5 minutes)

#### Deploy to Firebase
- [ ] From functions directory, run:
  ```bash
  cd .. # Back to project root
  firebase deploy --only functions
  ```

#### Wait for Deployment
- [ ] Monitor console output
- [ ] Look for:
  ```
  ✔  functions: Finished running predeploy script.
  i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
  ✔  functions: required API cloudfunctions.googleapis.com is enabled
  i  functions: preparing functions directory for uploading...
  i  functions: packaged functions (XX KB) for uploading
  ✔  functions: functions folder uploaded successfully
  i  functions: creating Node.js 18 function sendMessageNotification...
  ✔  functions[sendMessageNotification(us-central1)] Successful create operation.
  
  ✔  Deploy complete!
  ```

#### Verify in Firebase Console
- [ ] Open Firebase Console → Functions
- [ ] Confirm `sendMessageNotification` appears in list
- [ ] Status should be "Healthy" ✅

**Checkpoint:** Cloud Functions deployed! ✓

**Commit:**
```bash
git add functions/
git add firebase.json
git commit -m "[PR #17] Phase 7: Cloud Functions deployed for push notifications"
```

---

## Phase 8: Testing on Physical Device (30 minutes)

### 8.1: Prepare Physical Device (5 minutes)

#### Connect iPhone
- [ ] Connect iPhone to Mac via USB
- [ ] Unlock iPhone
- [ ] Trust computer if prompted

#### Select Device in Xcode
- [ ] In Xcode, select your iPhone from device dropdown
- [ ] Should show: "Isaac's iPhone" (or your device name)

#### Build and Install
- [ ] Press Cmd+R (Run)
- [ ] Wait for build and installation
- [ ] App should launch on device

---

### 8.2: Grant Notification Permission (3 minutes)

#### First Launch
- [ ] App launches
- [ ] iOS permission dialog appears: "MessageAI would like to send you notifications"
- [ ] Tap "Allow"

#### Verify Permission
- [ ] Check Xcode console for:
  ```
  ✅ Notification permission granted: true
  ```

#### Get FCM Token
- [ ] Check Xcode console for:
  ```
  📱 APNs token received
  🔥 FCM Token: dP1KX4gp3k:APA91bH...
  ✅ FCM token saved to Firestore for user: [userId]
  ```

#### Verify in Firebase Console
- [ ] Open Firebase Console → Firestore
- [ ] Navigate to `/users/{your-userId}`
- [ ] Confirm fields exist:
  - `fcmToken`: "dP1KX4gp3k:APA91bH..."
  - `notificationsEnabled`: true
  - `lastTokenUpdate`: [timestamp]

**Checkpoint:** FCM token registered! ✓

---

### 8.3: Test Foreground Notification (5 minutes)

#### Setup
- [ ] Have app open on your device (Device A)
- [ ] On different device or simulator (Device B), sign in as different user
- [ ] Start conversation between Device A user and Device B user

#### Send Message from Device B
- [ ] Device B: Send message "Test notification!"
- [ ] Device A: Should see notification banner at top of app

#### Check Logs
- [ ] Xcode console should show:
  ```
  📬 Foreground notification: [conversationId: abc123, senderId: xyz]
  ```

#### Verify
- [ ] ✅ Notification banner appeared while app open
- [ ] ✅ Notification includes sender name and message text
- [ ] ✅ Sound played

---

### 8.4: Test Background Notification (5 minutes)

#### Setup
- [ ] Device A: Background the app (press home button)
- [ ] Device A should be on home screen

#### Send Message from Device B
- [ ] Device B: Send message "Background test!"
- [ ] Device A: Check lock screen / notification center

#### Verify Notification Appears
- [ ] ✅ Notification appears on lock screen
- [ ] ✅ Shows sender name and message preview
- [ ] ✅ Badge count appears on app icon (e.g., "1")

#### Check Cloud Function Logs
- [ ] Firebase Console → Functions → Logs
- [ ] Should see:
  ```
  📬 New message detected: [messageId]
  👥 Sending to 1 recipients
  ✅ Notification sent to [recipientId]
  ```

---

### 8.5: Test Notification Tap & Deep Linking (5 minutes)

#### Tap Notification
- [ ] Device A: Tap the notification on lock screen
- [ ] App should open

#### Verify Deep Link
- [ ] ✅ App opens directly to conversation
- [ ] ✅ Shows correct conversation with sender
- [ ] ✅ Can reply immediately

#### Check Console Logs
- [ ] Xcode console should show:
  ```
  👆 Notification tapped: [conversationId: abc123]
  🔗 Deep link received: messageai://conversation/abc123
  📱 Opening conversation: abc123
  ```

---

### 8.6: Test Closed App Notification (5 minutes)

#### Force Quit App
- [ ] Device A: Swipe up to app switcher
- [ ] Swipe up on MessageAI to force quit
- [ ] App is completely closed

#### Send Message from Device B
- [ ] Device B: Send message "Closed app test!"
- [ ] Wait 3 seconds

#### Verify Notification
- [ ] Device A: Check lock screen
- [ ] ✅ Notification appears even with app closed
- [ ] ✅ Tap opens app to correct conversation

---

### 8.7: Test Badge Count (2 minutes)

#### Create Multiple Unread Conversations
- [ ] Device B: Send messages from 2 different users to Device A
- [ ] Device A: Don't open app

#### Check Badge
- [ ] Device A: Look at app icon on home screen
- [ ] ✅ Badge shows "2" (two unread conversations)

#### Open One Conversation
- [ ] Device A: Open app, read one conversation
- [ ] Check badge count updates to "1"

#### Open All Conversations
- [ ] Device A: Read all messages
- [ ] ✅ Badge count clears to "0"

**Checkpoint:** All notification scenarios tested! ✓

---

## Phase 9: Final Integration & Polish (15 minutes)

### 9.1: Add Notification Permission Request Flow (10 minutes)

#### Create Permission Prompt (Optional Enhancement)
- [ ] **Option A:** Request permission immediately on first launch (current implementation)
- [ ] **Option B:** Show custom screen explaining benefits before iOS prompt

**For MVP, Option A is sufficient (already implemented in AppDelegate).**

#### Verify Permission Flow
- [ ] Delete app from device
- [ ] Reinstall and launch
- [ ] Confirm iOS permission dialog appears
- [ ] Test both "Allow" and "Don't Allow" paths
- [ ] Verify app doesn't crash on denial

---

### 9.2: Handle Edge Cases (5 minutes)

#### Test: User Denies Permission
- [ ] Deny notification permission
- [ ] Verify app continues working
- [ ] Verify no crashes when sending messages
- [ ] FCM token should not be saved

#### Test: User is Actively Chatting
- [ ] Device A: Open conversation with User B
- [ ] Device B: Send message
- [ ] Device A: Should **not** receive notification (already in conversation)

#### Test: Sign Out and Sign Back In
- [ ] Sign out from Device A
- [ ] Verify FCM token removed from Firestore
- [ ] Sign back in
- [ ] Verify new FCM token saved
- [ ] Test notification delivery works again

**Checkpoint:** Edge cases handled! ✓

**Commit:**
```bash
git add .
git commit -m "[PR #17] Phase 9: Testing complete, all scenarios validated"
```

---

## Phase 10: Documentation & Cleanup (10 minutes)

### 10.1: Update Documentation (5 minutes)

#### Update memory-bank/activeContext.md
- [ ] Add:
  ```markdown
  ### ✅ Just Completed: PR #17 - Push Notifications 🎉
  
  **Completion Date**: [Date]
  **Time Taken**: X hours actual (3-4 hours estimated)
  **Status**: COMPLETE - MVP REQUIREMENT MET! 🎉
  
  **What Was Built**:
  - APNs authentication configured
  - FCM token management
  - NotificationService with deep linking
  - Cloud Functions deployed (sendMessageNotification)
  - Badge count management
  - Tested on physical device
  
  **MVP Status**: ✅ ALL 10 MVP REQUIREMENTS COMPLETE!
  ```

#### Update memory-bank/progress.md
- [ ] Mark PR #17 as complete:
  ```markdown
  - ✅ PR #17: Push Notifications - FCM (X hours) ✅ COMPLETE! 🎉 **MVP DONE!**
  ```

---

### 10.2: Clean Build (2 minutes)

#### Clean and Rebuild
- [ ] In Xcode: Product → Clean Build Folder (Cmd+Shift+K)
- [ ] Product → Build (Cmd+B)
- [ ] Verify: 0 errors, 0 warnings

---

### 10.3: Final Commit and Push (3 minutes)

#### Final Commit
```bash
git add .
git commit -m "[PR #17] Push Notifications complete - MVP REQUIREMENT MET! 🎉

Features:
- APNs authentication configured
- FCM token management (save/remove)
- NotificationService with permissions and deep linking
- Badge count based on unread conversations
- Cloud Functions deployed (sendMessageNotification)
- Foreground, background, and closed app notifications
- Deep linking to conversations from notification tap
- Tested on physical device

All 28 test scenarios passing!
Time: X hours (3-4h estimated)
Status: COMPLETE - FINAL MVP FEATURE! 🎉"
```

#### Push to GitHub
```bash
git push origin feature/pr17-push-notifications
```

#### Merge to Main
```bash
git checkout main
git merge feature/pr17-push-notifications
git push origin main
```

**Checkpoint:** PR #17 COMPLETE! 🎉

---

## Completion Checklist

### ✅ All Features Implemented
- [x] APNs authentication configured in Firebase
- [x] Push Notifications capability added to Xcode
- [x] Background Modes enabled
- [x] Info.plist configured with notification permissions
- [x] AppDelegate created with APNs and FCM handling
- [x] NotificationService implemented (token, permissions, badge, deep linking)
- [x] User model extended with FCM token fields
- [x] ChatService unread count method added
- [x] Cloud Functions deployed (sendMessageNotification)
- [x] Integration complete (sign out, active conversation tracking)
- [x] Deep linking works from notification tap

### ✅ All Tests Passed
- [x] FCM token saved to Firestore
- [x] Permission request works
- [x] Foreground notification received (app open)
- [x] Background notification received (app backgrounded)
- [x] Closed app notification received (app terminated)
- [x] Notification tap opens correct conversation
- [x] Badge count accurate and updates in real-time
- [x] Group message notifications work
- [x] No notification if user is actively chatting
- [x] Cloud Function executes successfully
- [x] Invalid tokens handled and removed

### ✅ Quality Standards Met
- [x] No compiler errors or warnings
- [x] No console errors during notification flow
- [x] Tested on physical device (simulator not sufficient)
- [x] Deep linking tested with 10+ notifications
- [x] Performance: Notification latency <3 seconds
- [x] Badge updates <1 second
- [x] Code follows existing patterns and style
- [x] All files committed to git
- [x] Documentation updated

### ✅ MVP Requirement Met
- [x] **Push notifications working (at least in foreground)** ✅
- [x] **BONUS: Background and closed app notifications also working!** 🎉
- [x] **ALL 10 MVP REQUIREMENTS NOW COMPLETE!** 🚀

---

## Time Tracking

| Phase | Estimated | Actual | Notes |
|-------|-----------|--------|-------|
| Pre-Setup | 15 min | ___ min | Reading, prerequisites |
| Phase 1: APNs Config | 30 min | ___ min | Apple Developer + Firebase |
| Phase 2: Xcode Config | 20 min | ___ min | Capabilities + Info.plist |
| Phase 3: AppDelegate | 30 min | ___ min | APNs handling |
| Phase 4: NotificationService | 45 min | ___ min | Core service logic |
| Phase 5: ChatService Update | 15 min | ___ min | Unread count |
| Phase 6: Integration | 20 min | ___ min | Wire throughout app |
| Phase 7: Cloud Functions | 45 min | ___ min | Deploy functions |
| Phase 8: Device Testing | 30 min | ___ min | All notification scenarios |
| Phase 9: Polish | 15 min | ___ min | Edge cases |
| Phase 10: Documentation | 10 min | ___ min | Final docs |
| **TOTAL** | **3-4 hours** | **___ hours** | |

---

## Celebration! 🎉

**YOU DID IT!** You've implemented the final MVP requirement!

**What this means:**
- ✅ All 10 MVP requirements complete
- ✅ Production-quality messaging app
- ✅ Ready for TestFlight submission
- ✅ Comparable to WhatsApp/iMessage in core features

**Next Steps:**
1. Test with multiple users for 24 hours
2. Fix any critical bugs found
3. Record demo video
4. Submit to TestFlight
5. SHIP IT! 🚀

---

*"The app was good before. Now it's complete."*

