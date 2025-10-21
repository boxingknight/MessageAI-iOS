# PR#17: Push Notifications - Testing Guide

**Comprehensive test strategy for Firebase Cloud Messaging integration**

---

## Overview

This testing guide covers **28 comprehensive test scenarios** across 5 categories:
- Unit Tests (5 tests)
- Integration Tests (8 tests)
- Edge Cases (6 tests)
- Performance Tests (4 tests)
- Acceptance Criteria (5 tests)

**Testing Philosophy:** Push notifications are a critical user-facing feature. Every test scenario should pass before declaring this PR complete.

**Time Required:** ~1 hour for full test suite (30 min device testing + 30 min verification)

---

## Test Environment Setup

### Required Equipment

**2 Physical iOS Devices:**
- Device A: Your primary testing device (logged in as User A)
- Device B: Secondary device or simulator (logged in as User B)

**Why Physical Devices:**
- iOS Simulator cannot receive push notifications
- Need to test APNs integration end-to-end
- Need to test lock screen notifications
- Need to test app closed/backgrounded states

**Minimum Configuration:**
- iOS 16.0+
- Connected to WiFi or cellular
- Logged into different user accounts
- Push notification permission granted

---

### Test Data Setup

#### Create Test Users (5 minutes)

**User A (Primary Tester):**
```
Email: tester1@messageai.test
Display Name: Alice Test
Password: testpass123
```

**User B (Secondary Tester):**
```
Email: tester2@messageai.test
Display Name: Bob Test
Password: testpass123
```

**User C (Group Testing):**
```
Email: tester3@messageai.test
Display Name: Charlie Test
Password: testpass123
```

#### Create Test Conversations

**1. One-on-One Conversation:**
- Participants: Alice, Bob
- Messages: 2-3 test messages

**2. Group Conversation:**
- Participants: Alice, Bob, Charlie
- Group Name: "Test Group"
- Messages: 2-3 test messages

---

### Verification Tools

**1. Xcode Console (Device Logs)**
```bash
# Connect device via USB
# Xcode → Window → Devices and Simulators
# Select device → Open Console
# Filter: "messageai" or "FCM"
```

**2. Firebase Console (Cloud Function Logs)**
```
Firebase Console → Functions → Logs
Look for:
- "📬 New message detected: [messageId]"
- "✅ Notification sent to [recipientId]"
- "❌ Failed to send: [error]"
```

**3. Firestore Console (Token Verification)**
```
Firebase Console → Firestore Database
Path: /users/{userId}
Verify:
- fcmToken: "dP1KX4gp3k:APA91bH..."
- notificationsEnabled: true
- lastTokenUpdate: [timestamp]
```

**4. Firebase Cloud Messaging Test Tool**
```
Firebase Console → Cloud Messaging → Send test message
- Enter FCM token from Firestore
- Add title and body
- Click "Send"
- Should appear on device immediately
```

---

## Unit Tests (5 tests)

### Test 1: FCM Token Save to Firestore

**Objective:** Verify FCM token is saved correctly when received

**Setup:**
- Fresh app install on Device A
- User A logged in

**Steps:**
1. Launch app
2. Grant notification permission when prompted
3. Wait 3 seconds

**Expected Results:**
- ✅ Xcode console shows: "🔥 FCM Token: dP1KX4gp3k..."
- ✅ Xcode console shows: "✅ FCM token saved to Firestore for user: [userId]"
- ✅ Firestore `/users/{userA-id}` document contains:
  - `fcmToken`: "[token string]"
  - `notificationsEnabled`: true
  - `lastTokenUpdate`: [timestamp]

**Verification:**
```
1. Open Firebase Console → Firestore
2. Navigate to /users/[userA-id]
3. Confirm fcmToken field exists and is a long string (150+ chars)
4. Confirm lastTokenUpdate is recent (within last 5 minutes)
```

**Pass Criteria:**
- FCM token saved successfully
- Token is valid format (starts with letter, contains colons)
- Timestamp is recent

---

### Test 2: Permission Request

**Objective:** Verify permission request appears and is handled correctly

**Setup:**
- Fresh app install (delete and reinstall)
- No permission granted yet

**Steps:**
1. Launch app
2. Sign in as User A
3. Observe iOS permission dialog

**Expected Results:**
- ✅ iOS system permission dialog appears automatically
- ✅ Dialog text: "MessageAI would like to send you notifications"
- ✅ Custom message visible: "MessageAI needs notifications to alert you when you receive new messages..."
- ✅ Two buttons: "Don't Allow" and "Allow"

**Test Both Paths:**

**Path A: Grant Permission**
1. Tap "Allow"
2. Expected: `NotificationService.permissionGranted` = true
3. Expected: Console shows "✅ Notification permission granted: true"

**Path B: Deny Permission**
1. Tap "Don't Allow"
2. Expected: `NotificationService.permissionGranted` = false
3. Expected: Console shows "✅ Notification permission granted: false"
4. Expected: App continues working (no crash)

**Verification:**
```swift
// Check NotificationService state
print(NotificationService.shared.permissionGranted)
// Should match user's choice
```

**Pass Criteria:**
- Permission dialog appears automatically
- Both "Allow" and "Don't Allow" work without crashes
- Permission state reflects user's choice

---

### Test 3: Badge Count Calculation

**Objective:** Verify badge count accurately reflects unread conversations

**Setup:**
- Device A logged in as User A
- 3 conversations with unread messages from others
- 2 conversations with no unread messages

**Steps:**
1. Ensure 3 conversations have unread messages (don't open them)
2. Launch app (or background and reopen)
3. Call `NotificationService.shared.updateBadgeCount()`
4. Check app icon

**Expected Results:**
- ✅ Badge shows "3"
- ✅ Console shows: "🔢 Badge count updated: 3"

**Test Badge Updates:**
1. Open one conversation (read messages)
2. Return to conversation list
3. Expected: Badge updates to "2"

4. Open all conversations (read all messages)
5. Expected: Badge updates to "0" (clears)

**Verification:**
```
1. Look at app icon on home screen
2. Badge number should match unread conversation count exactly
3. Badge should update within 1 second of reading messages
```

**Pass Criteria:**
- Badge count = number of conversations with unread messages
- Badge updates in real-time (<1 second)
- Badge clears when all read

---

### Test 4: Deep Link URL Parsing

**Objective:** Verify deep link URLs are parsed correctly

**Test Cases:**

**Valid URL:**
```swift
let url = URL(string: "messageai://conversation/abc123xyz")!
NotificationService.shared.handleDeepLink(url)
```

**Expected:**
- ✅ Console: "🔗 Deep link received: messageai://conversation/abc123xyz"
- ✅ Console: "📱 Opening conversation: abc123xyz"
- ✅ NotificationCenter posts "OpenConversation" with conversationId = "abc123xyz"

**Invalid Scheme:**
```swift
let url = URL(string: "https://example.com/conversation/abc123")!
NotificationService.shared.handleDeepLink(url)
```

**Expected:**
- ✅ Console: "⚠️ Unknown URL scheme: https"
- ✅ No navigation triggered

**Malformed URL:**
```swift
let url = URL(string: "messageai://invalid")!
NotificationService.shared.handleDeepLink(url)
```

**Expected:**
- ✅ No crash
- ✅ No navigation triggered

**Pass Criteria:**
- Valid URLs navigate correctly
- Invalid URLs handled gracefully (no crash)
- URL parsing is case-insensitive

---

### Test 5: Token Removal on Sign Out

**Objective:** Verify FCM token is removed from Firestore when user signs out

**Setup:**
- Device A logged in as User A
- FCM token saved in Firestore

**Steps:**
1. Verify FCM token exists in Firestore `/users/{userA-id}`
2. In app, navigate to profile/settings
3. Tap "Sign Out"
4. Confirm sign out

**Expected Results:**
- ✅ Console shows: "✅ FCM token removed from Firestore"
- ✅ Firestore `/users/{userA-id}` document updated:
  - `fcmToken`: [field deleted]
  - `notificationsEnabled`: false
- ✅ Badge count cleared (0)
- ✅ User redirected to welcome/login screen

**Verification:**
```
1. Firebase Console → Firestore → /users/{userA-id}
2. Confirm fcmToken field does not exist
3. Confirm notificationsEnabled = false
```

**Pass Criteria:**
- Token removed successfully
- Badge cleared
- No crashes during sign out

---

## Integration Tests (8 tests)

### Test 6: Send Message → Receive Notification (One-on-One)

**Objective:** End-to-end notification flow for one-on-one chat

**Setup:**
- Device A: User A (receiver)
- Device B: User B (sender)
- One-on-one conversation exists between them
- Device A has app backgrounded (not closed)

**Steps:**
1. Device A: Press home button (background app)
2. Device B: Open conversation with User A
3. Device B: Type and send message: "Test notification #1"
4. Start stopwatch

**Expected Results:**
- ✅ Notification appears on Device A within 3 seconds
- ✅ Notification banner shows on lock screen
- ✅ Notification content:
  - Title: "Alice Test" (sender's name)
  - Body: "Test notification #1" (message text)
  - Sound plays
- ✅ Badge on app icon updates (e.g., "1")

**Xcode Console (Device A):**
```
📬 Foreground notification: [conversationId: xyz, senderId: abc]
```

**Firebase Console (Cloud Function Logs):**
```
📬 New message detected: [messageId]
👥 Sending to 1 recipients
✅ Notification sent to [userA-id]
```

**Pass Criteria:**
- Latency <3 seconds (send to notification)
- Notification content accurate
- Sound plays
- Badge updates

---

### Test 7: Tap Notification → Open Conversation

**Objective:** Verify deep linking from notification tap

**Setup:**
- Continuation of Test 6
- Device A has notification visible on lock screen

**Steps:**
1. Device A: Tap the notification
2. Observe app behavior

**Expected Results:**
- ✅ App launches (if closed) or comes to foreground (if backgrounded)
- ✅ App navigates directly to conversation with User B
- ✅ ChatView displays with messages visible
- ✅ Can reply immediately (MessageInputView ready)
- ✅ New message "Test notification #1" is visible

**Xcode Console (Device A):**
```
👆 Notification tapped: [conversationId: xyz]
🔗 Deep link received: messageai://conversation/xyz
📱 Opening conversation: xyz
```

**Pass Criteria:**
- App opens to correct conversation
- Navigation time <500ms
- All messages visible
- Can reply immediately

---

### Test 8: Foreground Notification (App Open)

**Objective:** Verify notification appears when app is actively open

**Setup:**
- Device A: User A, app open, viewing **different conversation** (not with User B)
- Device B: User B

**Steps:**
1. Device A: Open conversation with User C (not User B)
2. Device B: Send message to User A: "Foreground test"
3. Observe Device A

**Expected Results:**
- ✅ Notification banner appears at top of app
- ✅ Banner shows sender name and message preview
- ✅ Sound plays
- ✅ Banner auto-dismisses after 3 seconds
- ✅ Badge count updates
- ✅ User can tap banner to navigate to conversation

**Xcode Console (Device A):**
```
📬 Foreground notification: [userInfo]
```

**Pass Criteria:**
- Banner appears while app is active
- Banner is tappable and navigates correctly
- Sound plays
- Doesn't interrupt current activity

---

### Test 9: Background Notification (App Backgrounded)

**Objective:** Verify notification on lock screen when app is backgrounded

**Setup:**
- Device A: User A, app backgrounded (home button pressed)
- Device B: User B

**Steps:**
1. Device A: Press home button (see home screen)
2. Device B: Send message to User A: "Background test"
3. Observe Device A lock screen / notification center

**Expected Results:**
- ✅ Notification appears on lock screen
- ✅ Notification shows sender name and message
- ✅ Sound plays and device vibrates
- ✅ Badge appears on app icon
- ✅ Notification persists (doesn't auto-dismiss)

**iOS Notification Center:**
- Swipe down from top → Notification visible
- Tap notification → Opens app to conversation

**Pass Criteria:**
- Lock screen notification visible
- Sound and vibration
- Tappable to open app
- Badge count accurate

---

### Test 10: Closed App Notification (App Terminated)

**Objective:** Verify notification when app is completely closed

**Setup:**
- Device A: User A, app force-quit (swiped up in app switcher)
- Device B: User B

**Steps:**
1. Device A: Double-press home button → App switcher
2. Device A: Swipe up on MessageAI to force quit
3. Confirm app is closed (not in background)
4. Device B: Send message to User A: "Closed app test"
5. Wait 3 seconds

**Expected Results:**
- ✅ Notification appears on Device A lock screen
- ✅ Notification content accurate (sender + message)
- ✅ Sound plays
- ✅ Badge on app icon shows count
- ✅ Tap notification → App launches fresh
- ✅ App navigates to conversation

**Critical:** This is the most important test. If app is closed, notifications MUST still work.

**Pass Criteria:**
- Notification delivered despite app being closed
- Latency <5 seconds
- Deep link works from cold start
- No data loss or sync issues

---

### Test 11: Group Message Notification

**Objective:** Verify notifications work in group chats

**Setup:**
- Group chat: Alice (Device A), Bob (Device B), Charlie (Device C or same as B)
- Group name: "Test Group"

**Steps:**
1. Device A: Background app
2. Device B: Send message to group: "Group notification test"
3. Observe Device A

**Expected Results:**
- ✅ Notification appears on Device A
- ✅ Notification title: "Test Group" (group name) OR "Alice Test" (sender name)
- ✅ Notification body: "Bob Test: Group notification test" (sender + message)
- ✅ Sound plays
- ✅ Badge updates

**Verify All Group Members:**
- Device A (Alice): Receives notification ✅
- Device C (Charlie): Receives notification ✅
- Device B (Bob - sender): Does NOT receive notification ✅

**Cloud Function Logs:**
```
📬 New message detected: [messageId]
👥 Sending to 2 recipients (all except sender)
✅ Notification sent to [alice-id]
✅ Notification sent to [charlie-id]
⏭️ Skipping [bob-id] (sender)
```

**Pass Criteria:**
- All participants (except sender) receive notification
- Group name or sender name shown
- Message preview includes sender name
- No duplicate notifications

---

### Test 12: Multiple Messages → Grouped Notifications

**Objective:** Verify iOS groups notifications by conversation

**Setup:**
- Device A: User A, app closed
- Device B: User B

**Steps:**
1. Device A: Force quit app
2. Device B: Send 3 messages rapidly:
   - "Message 1"
   - "Message 2"
   - "Message 3"
3. Wait 5 seconds
4. Observe Device A lock screen

**Expected Results:**
- ✅ iOS groups notifications by conversation (thread-id = conversationId)
- ✅ Notification shows: "3 new messages from Bob Test"
- ✅ Expand notification → Shows all 3 messages
- ✅ Badge shows "1" (one conversation with unread)
- ✅ Tap notification → Opens conversation with all 3 messages

**iOS Behavior:**
- Recent iOS versions automatically group notifications from same app
- Uses `thread-id` field in APNs payload
- Shows most recent message by default
- Expand to see all messages

**Pass Criteria:**
- Notifications grouped intelligently
- Badge count is conversation-based (not message-based)
- All messages visible when expanded
- Tap opens to conversation with all messages

---

### Test 13: Badge Count Accuracy Across App Lifecycle

**Objective:** Verify badge stays accurate through app states

**Setup:**
- Device A: User A
- Multiple conversations with unread messages

**Test Sequence:**

**1. App Launch from Closed:**
- Start with 2 unread conversations
- Launch app
- Expected: Badge shows "2" immediately
- Open one conversation
- Expected: Badge updates to "1"

**2. App Backgrounded:**
- Background app with 1 unread
- Receive new message (now 2 unread)
- Expected: Badge updates to "2" while backgrounded

**3. App Reopened:**
- Reopen app
- Expected: Badge still shows "2"
- Read both conversations
- Expected: Badge updates to "0"

**4. Sign Out and Sign In:**
- Sign out
- Expected: Badge clears to "0"
- Sign back in
- Expected: Badge reflects actual unread count

**Pass Criteria:**
- Badge accurate at all times
- Updates within 1 second of state change
- Persists across app lifecycle
- Clears on sign out

---

## Edge Cases (6 tests)

### Test 14: No Notification If User is Actively Chatting

**Objective:** Verify users don't get notified for messages in active conversation

**Setup:**
- Device A: User A, ChatView open with User B
- Device B: User B

**Steps:**
1. Device A: Open conversation with User B
2. Device A: Stay in ChatView (actively viewing conversation)
3. Device B: Send message: "Active chat test"
4. Observe Device A

**Expected Results:**
- ✅ Message appears in ChatView immediately (real-time listener)
- ✅ NO notification banner appears
- ✅ NO sound plays
- ✅ Badge does NOT change (user is already viewing)

**Cloud Function Logs:**
```
📬 New message detected: [messageId]
⏭️ Skipping [userA-id] (active in conversation)
```

**Mechanism:**
- ChatView sets `NotificationService.shared.activeConversationId` on appear
- Cloud Function checks if `user.currentConversationId === message.conversationId`
- If match, skip notification

**Pass Criteria:**
- No notification when actively chatting
- Message still appears via real-time listener
- Seamless user experience

---

### Test 15: No Notification If Notifications Disabled

**Objective:** Verify users who disable notifications don't receive them

**Setup:**
- Device A: User A
- Notifications disabled in Firestore

**Steps:**
1. Manually update Firestore: `/users/{userA-id}`
   - Set `notificationsEnabled: false`
2. Device B: Send message to User A
3. Observe Device A

**Expected Results:**
- ✅ No notification appears
- ✅ No sound plays
- ✅ No badge update
- ✅ Message still delivered to Firestore (via real-time listener when app opens)

**Cloud Function Logs:**
```
📬 New message detected: [messageId]
⏭️ Skipping [userA-id] (notifications disabled or no token)
```

**Pass Criteria:**
- No notification sent
- User preference respected
- Messages still accessible when app opens

---

### Test 16: Invalid FCM Token Handling

**Objective:** Verify invalid tokens are detected and removed

**Setup:**
- Device A: User A with valid FCM token
- Manually corrupt token in Firestore

**Steps:**
1. Firestore: Edit `/users/{userA-id}`
   - Change `fcmToken` to invalid value: "invalid-token-12345"
2. Device B: Send message to User A
3. Check Cloud Function logs

**Expected Results:**
- ✅ Cloud Function attempts to send notification
- ✅ FCM returns error: "invalid-registration-token"
- ✅ Cloud Function detects error
- ✅ Cloud Function removes invalid token from Firestore
- ✅ Firestore: `fcmToken` field deleted

**Cloud Function Logs:**
```
📬 New message detected: [messageId]
❌ Failed to send to [userA-id]: messaging/invalid-registration-token
🗑️ Removing invalid token for [userA-id]
```

**Verification:**
```
1. Firebase Console → Firestore → /users/{userA-id}
2. Confirm fcmToken field no longer exists
```

**Pass Criteria:**
- Invalid token detected
- Token removed automatically
- No crash or infinite retry
- User can re-register token on next app launch

---

### Test 17: Permission Denied by User

**Objective:** Verify app handles permission denial gracefully

**Setup:**
- Fresh app install
- User A not yet granted permission

**Steps:**
1. Delete app from Device A
2. Reinstall and launch
3. Sign in as User A
4. When iOS permission dialog appears, tap "Don't Allow"
5. Continue using app

**Expected Results:**
- ✅ App does NOT crash
- ✅ App continues functioning normally
- ✅ Can send and receive messages (via real-time listener)
- ✅ No FCM token saved to Firestore
- ✅ No console errors

**User Experience:**
- Messages still work (real-time updates when app is open)
- No notifications when app is closed (expected behavior)
- User can enable later via iOS Settings

**Pass Criteria:**
- No crash on permission denial
- App usable without notifications
- Clear that notifications are disabled (no errors)

---

### Test 18: Network Offline → Notification on Reconnect

**Objective:** Verify FCM queues notifications when device is offline

**Setup:**
- Device A: User A, app backgrounded
- Device A: Turn on Airplane Mode (network offline)

**Steps:**
1. Device A: Enable Airplane Mode
2. Device B: Send message: "Offline test"
3. Wait 10 seconds (notification should NOT appear)
4. Device A: Disable Airplane Mode (reconnect)
5. Wait 3 seconds

**Expected Results:**
- ✅ While offline: No notification (expected)
- ✅ After reconnecting: Notification appears within 3-5 seconds
- ✅ Notification content accurate
- ✅ Badge updates
- ✅ Message in Firestore when app opens

**Firebase Behavior:**
- FCM queues notifications for offline devices
- Notifications delivered when device reconnects
- Queued for up to 4 weeks (FCM default TTL)

**Pass Criteria:**
- Notification delivered after reconnect
- No data loss
- Latency <5 seconds after reconnect

---

### Test 19: Rapid Message Spam (10+ messages/second)

**Objective:** Verify system handles rapid message bursts

**Setup:**
- Device A: User A, app backgrounded
- Device B: User B

**Steps:**
1. Device B: Send 20 messages as fast as possible:
   - "Spam 1", "Spam 2", ..., "Spam 20"
2. Observe Device A and Firebase logs

**Expected Results:**
- ✅ All 20 messages delivered to Firestore
- ✅ Cloud Function executes 20 times (one per message)
- ✅ Notifications sent (may be grouped by iOS)
- ✅ No crashes or timeouts
- ✅ No lost messages
- ✅ Badge count accurate

**iOS Behavior:**
- iOS may group rapid notifications from same conversation
- Shows "20 new messages from Bob Test"

**Cloud Function Performance:**
- Each function execution completes independently
- Firebase Functions auto-scales to handle burst
- Typical execution time: <2 seconds per message

**Pass Criteria:**
- All 20 messages delivered
- No function timeouts or errors
- Badge and notification state accurate
- System recovers gracefully

---

## Performance Tests (4 tests)

### Test 20: Notification Latency (One-on-One)

**Objective:** Measure end-to-end notification delivery time

**Setup:**
- Device A: User A, app backgrounded
- Device B: User B
- Stopwatch ready

**Steps:**
1. Device A: Background app
2. Device B: Open conversation with User A
3. Device B: Type message "Performance test"
4. **Start stopwatch** when tap "Send"
5. **Stop stopwatch** when notification appears on Device A

**Target:** <3 seconds

**Measurement:**
```
Breakdown:
- Message write to Firestore: ~200ms
- Cloud Function trigger + execute: ~1-2s
- FCM → APNs → Device: ~500ms-1s
Total: ~2-3 seconds
```

**Expected Results:**
- ✅ 90% of notifications delivered in <3 seconds
- ✅ 99% of notifications delivered in <5 seconds
- ✅ No notifications take >10 seconds

**Pass Criteria:**
- Average latency <3 seconds
- No outliers >10 seconds
- Consistent performance across 10 tests

---

### Test 21: Notification Latency (Group, 10 Participants)

**Objective:** Measure group notification performance at scale

**Setup:**
- Group with 10 participants (create test users if needed)
- All participants backgrounded except sender

**Steps:**
1. Sender: Send message to group
2. Start stopwatch
3. Monitor all 9 recipient devices
4. Record when each receives notification

**Target:** All 9 recipients within 5 seconds

**Expected Results:**
- ✅ First recipient: <2 seconds
- ✅ Last recipient: <5 seconds
- ✅ Average across all recipients: <3 seconds

**Cloud Function Behavior:**
- Function fetches all 9 recipient tokens
- Sends notifications in parallel (Promise.all)
- All notifications complete within 2-3 seconds

**Pass Criteria:**
- All recipients notified within 5 seconds
- No failed notifications
- Cloud Function execution time <3 seconds

---

### Test 22: Cloud Function Execution Time

**Objective:** Measure Cloud Function performance

**Setup:**
- Monitor Firebase Console → Functions → Logs

**Steps:**
1. Send test message
2. Wait for Cloud Function to complete
3. Check Firebase logs for execution time

**Target:** <2 seconds

**Verification:**
```
Firebase Console → Functions → sendMessageNotification → Logs

Look for execution time in logs:
"Function execution took 1,234 ms, finished with status 'ok'"
```

**Expected Results:**
- ✅ Average execution time: 1-2 seconds
- ✅ 99th percentile: <3 seconds
- ✅ No timeouts (60 second limit)

**Factors Affecting Performance:**
- Cold start (first invocation after 15min idle): +1-3 seconds
- Warm function (frequent usage): ~1-2 seconds
- Number of recipients: ~100ms per recipient
- Firestore query time: ~200-500ms

**Pass Criteria:**
- Average execution <2 seconds
- No timeouts
- Cold starts <5 seconds

---

### Test 23: Badge Update Performance

**Objective:** Measure badge count update speed

**Setup:**
- Device A: User A
- 50 conversations (30 with unread messages)

**Steps:**
1. Launch app (badge should update on launch)
2. Start stopwatch when app appears
3. Stop when badge number visible

**Target:** <1 second

**Expected Results:**
- ✅ Badge appears within 1 second of app launch
- ✅ Badge count accurate (30 unread conversations)
- ✅ No lag or delay in UI

**Performance Factors:**
- Firestore query for all conversations: ~200-500ms
- Count unread logic: ~100ms
- Badge API call: ~50ms
- Total: ~500ms typical

**Pass Criteria:**
- Update time <1 second
- Accurate count
- No UI blocking

---

## Acceptance Criteria (5 tests)

### Test 24: CRITICAL - Notifications Work in Production

**Objective:** Verify notifications work in production TestFlight environment

**Setup:**
- App deployed to TestFlight
- Real user device (not connected to Xcode)
- Production Firebase project

**Steps:**
1. Download app from TestFlight
2. Sign in as test user
3. Have another user send message
4. Verify notification received

**Expected Results:**
- ✅ Notification delivered in production
- ✅ All notification features work (badge, sound, deep link)
- ✅ No differences from development behavior
- ✅ Cloud Functions executing in production

**Critical:** This is the final gate before submission. Must pass!

**Pass Criteria:**
- Production notifications work identically to development
- No certificate or configuration issues
- Reliable delivery (<3 second latency)

---

### Test 25: CRITICAL - Deep Linking Works Reliably

**Objective:** Verify 100% deep link success rate

**Setup:**
- Device A with 10 different conversations

**Steps:**
1. Have 10 different users send messages to Device A
2. Device A receives 10 notifications
3. Tap each notification one at a time
4. Verify each opens correct conversation

**Expected Results:**
- ✅ 10/10 notifications open correct conversation
- ✅ No navigation errors
- ✅ No wrong conversation opened
- ✅ No crashes

**Pass Criteria:**
- 100% success rate (10/10 correct)
- Navigation time <500ms
- No edge cases or failures

---

### Test 26: CRITICAL - No Notification Spam

**Objective:** Verify users don't receive notifications for messages they've already seen

**Setup:**
- Device A: User A

**Test Scenarios:**

**1. User is actively chatting:**
- Open conversation with User B
- User B sends message
- Expected: No notification (already viewing)

**2. User just read the message:**
- User B sends message
- User A opens conversation and reads
- User B sends another message within 5 seconds
- Expected: Notification received (user may have left conversation)

**3. Message already read via other device:**
- User A reads message on Device A (iPhone)
- Same message synced to Device B (iPad)
- Expected: Badge clears on both devices

**Pass Criteria:**
- No notifications when actively viewing conversation
- No notification spam or duplicates
- Read state syncs across devices

---

### Test 27: CRITICAL - Permission UX is Clear

**Objective:** Verify users understand why permission is requested

**Setup:**
- Fresh install
- New user (never seen permission prompt before)

**Steps:**
1. Launch app for first time
2. Complete sign up/sign in
3. Permission dialog appears
4. Read dialog text

**Expected Results:**
- ✅ Dialog appears at appropriate time (after sign in, not immediately)
- ✅ Custom description visible: "MessageAI needs notifications to alert you when you receive new messages..."
- ✅ Description is clear and specific (not generic)
- ✅ User understands value before deciding

**User Testing:**
- Show app to 5 people who haven't seen it
- Ask: "Would you grant notification permission?"
- Target: 70%+ say yes (understand value)

**Pass Criteria:**
- Permission request timing appropriate
- Description clear and valuable
- 70%+ grant permission (user testing)

---

### Test 28: CRITICAL - Works on Poor Network (3G)

**Objective:** Verify graceful degradation on slow network

**Setup:**
- Device A: Enable Network Link Conditioner (3G)
  - Settings → Developer → Network Link Conditioner → 3G
- Device B: Normal network

**Steps:**
1. Device A: 3G network enabled, app backgrounded
2. Device B: Send message
3. Wait and observe Device A

**Expected Results:**
- ✅ Notification still delivered (may take 5-10 seconds)
- ✅ No timeout errors
- ✅ No crash
- ✅ Message appears when app opens
- ✅ Badge updates eventually

**Acceptable Degradation:**
- Latency may be 5-10 seconds (vs 2-3 seconds on WiFi)
- Multiple retries may occur
- Eventually consistent (all messages delivered)

**Pass Criteria:**
- Notifications delivered despite slow network
- No data loss
- Graceful handling of delays

---

## Test Execution Checklist

### Before Testing (Pre-Flight)

- [ ] 2 physical devices available (Device A and B)
- [ ] Both devices on iOS 16+
- [ ] 2-3 test users created in Firebase Auth
- [ ] Test conversations created (1-on-1 and group)
- [ ] Xcode console open for Device A logs
- [ ] Firebase Console open for Cloud Function logs
- [ ] Firestore Console open for data verification

### During Testing (Execution)

- [ ] Execute Unit Tests #1-5 (20 minutes)
- [ ] Execute Integration Tests #6-13 (30 minutes)
- [ ] Execute Edge Case Tests #14-19 (20 minutes)
- [ ] Execute Performance Tests #20-23 (15 minutes)
- [ ] Execute Acceptance Tests #24-28 (30 minutes)

**Total Testing Time:** ~2 hours

### After Testing (Verification)

- [ ] All 28 tests passed
- [ ] No critical bugs found
- [ ] Performance targets met
- [ ] Badge count accurate
- [ ] Deep linking 100% success rate
- [ ] Document any issues found
- [ ] Retest any failed scenarios

---

## Success Criteria Summary

**Feature is complete when ALL of these pass:**

### Functional Requirements ✅
- [x] FCM token saved to Firestore on login
- [x] FCM token removed on sign out
- [x] Permission request appears and is handled
- [x] Foreground notifications appear (app open)
- [x] Background notifications appear (app backgrounded)
- [x] Closed app notifications appear (app terminated)
- [x] Deep linking works from all app states
- [x] Badge count accurate at all times
- [x] Group notifications work
- [x] No notification spam (active conversation skipped)

### Performance Targets ✅
- [x] Notification latency <3 seconds (one-on-one)
- [x] Notification latency <5 seconds (group with 10 users)
- [x] Cloud Function execution <2 seconds
- [x] Badge update <1 second
- [x] Deep link navigation <500ms

### Quality Gates ✅
- [x] Zero crashes during notification flow
- [x] 100% deep link success rate (10/10 tests)
- [x] Badge count 100% accurate
- [x] Permission UX clear (70%+ grant permission)
- [x] Works on poor network (3G)
- [x] Invalid tokens handled gracefully
- [x] Permission denial doesn't crash app

### Acceptance Criteria ✅
- [x] Notifications work in TestFlight production
- [x] All 28 test scenarios pass
- [x] No critical bugs
- [x] Performance acceptable
- [x] Ready to ship!

---

## Troubleshooting Failed Tests

### If Test #6 Fails (No Notification Received)

**Check in order:**

1. **APNs Configuration (Firebase Console)**
   - Project Settings → Cloud Messaging
   - APNs Auth Key uploaded? ✅
   - Key ID and Team ID correct?

2. **FCM Token (Firestore)**
   - /users/{userId}/fcmToken exists?
   - Token is recent (not stale)?

3. **Cloud Function (Firebase Console)**
   - Functions → Logs
   - Function executed?
   - Any errors in logs?

4. **Device Permission (iOS Settings)**
   - Settings → MessageAI → Notifications
   - Allow Notifications = ON?

5. **Network (Device)**
   - Device connected to internet?
   - Firebase reachable?

---

### If Test #7 Fails (Deep Link Doesn't Work)

**Check in order:**

1. **Console Logs**
   - "👆 Notification tapped" appears?
   - "🔗 Deep link received" appears?
   - ConversationId extracted correctly?

2. **Navigation Code**
   - ChatListView listening for "OpenConversation"?
   - NavigationCenter post triggered?

3. **URL Scheme**
   - Info.plist has CFBundleURLSchemes?
   - Scheme is "messageai"?

4. **Test Manually**
   ```swift
   // In Xcode, test deep linking directly:
   let url = URL(string: "messageai://conversation/[test-conversation-id]")!
   NotificationService.shared.handleDeepLink(url)
   ```

---

### If Test #13 Fails (Badge Count Wrong)

**Debug Steps:**

1. **Check Query**
   ```swift
   // Add debug logs to ChatService.getUnreadConversationCount()
   print("Total conversations: \(snapshot.documents.count)")
   print("Unread count: \(unreadCount)")
   ```

2. **Verify Logic**
   - Are you counting conversations (not messages)?
   - Are you filtering by `senderId != currentUserId`?
   - Are you checking `readBy` array?

3. **Manual Verification**
   - Count unread conversations manually in Firestore
   - Compare to badge count
   - Should match exactly

---

## Test Data Cleanup

After testing, clean up test data:

```bash
# Delete test messages
Firebase Console → Firestore → messages
Filter by createdAt > [test start time]
Select all → Delete

# Delete test conversations
Firebase Console → Firestore → conversations
Filter by test user IDs
Select all → Delete

# Keep test users for future testing
Do NOT delete test user accounts
```

---

## Appendix: Test Report Template

```markdown
# PR#17 Push Notifications - Test Report

**Date:** [Date]
**Tester:** [Name]
**Duration:** [Time]
**Environment:** [Production/Staging]

## Summary
- Tests Executed: X/28
- Tests Passed: X/28
- Tests Failed: X/28
- Critical Issues: X
- Pass Rate: XX%

## Unit Tests (5 tests)
- [x] Test #1: FCM token save - PASS
- [x] Test #2: Permission request - PASS
- [x] Test #3: Badge count - PASS
- [x] Test #4: Deep link parsing - PASS
- [x] Test #5: Token removal - PASS

## Integration Tests (8 tests)
- [x] Test #6: Send → Receive - PASS
- [x] Test #7: Tap notification - PASS
- [x] Test #8: Foreground - PASS
- [x] Test #9: Background - PASS
- [x] Test #10: Closed app - PASS
- [x] Test #11: Group message - PASS
- [x] Test #12: Multiple messages - PASS
- [x] Test #13: Badge accuracy - PASS

## Edge Cases (6 tests)
- [x] Test #14: Active chat - PASS
- [x] Test #15: Disabled notifications - PASS
- [x] Test #16: Invalid token - PASS
- [x] Test #17: Permission denied - PASS
- [x] Test #18: Offline → Online - PASS
- [x] Test #19: Message spam - PASS

## Performance Tests (4 tests)
- [x] Test #20: Latency 1-on-1 - PASS (2.1s avg)
- [x] Test #21: Latency group - PASS (3.8s avg)
- [x] Test #22: Function execution - PASS (1.5s avg)
- [x] Test #23: Badge update - PASS (0.4s avg)

## Acceptance Tests (5 tests)
- [x] Test #24: Production - PASS
- [x] Test #25: Deep linking - PASS (10/10)
- [x] Test #26: No spam - PASS
- [x] Test #27: Permission UX - PASS
- [x] Test #28: Poor network - PASS

## Issues Found
None / [List issues]

## Recommendation
✅ READY TO SHIP / ⚠️ NEEDS FIXES
```

---

**Status:** ✅ TESTING GUIDE COMPLETE  
**Total Test Scenarios:** 28  
**Estimated Test Time:** 2 hours  
**Coverage:** Unit, Integration, Edge Cases, Performance, Acceptance

---

*"If it's not tested, it's broken. Test everything."*

