# 🐛 Debugging: Deadline Not Detecting

## Issue
User sent messages like:
- "deadline is friday at 2PM"
- "Homework is due saturday at 1PM"

But no deadline is being created.

## Possible Causes

### 1. Extraction Not Being Triggered
**Check for:** `🚨 DEADLINE: Extracting deadline from message:`

If this log is **MISSING**, it means the extraction function is not being called at all.

**Possible reasons:**
- Message sender is not current user (only sender extracts deadlines after Bug #1 fix)
- Message listener not firing
- Task block not executing

### 2. Keyword Filter Rejecting Message
**Check for:** `✅ No deadline indicators found. Skipping GPT-4.`

If you see this, the message is being rejected by the keyword pre-filter.

**Current keywords checked:**
```typescript
DEADLINE_KEYWORDS = [
  'deadline', 'due', 'submit', 'turn in', 'by', 'before',
  'no later than', 'expires', 'ends', 'finish', 'complete'
];
```

**Issue:** User messages have "deadline" and "due" keywords, so this should NOT be the issue.

### 3. Cloud Function Error
**Check for:** `❌ Cloud Function ERROR:`

If you see this, the Cloud Function is being called but failing.

### 4. Parsing Error
**Check for:** `❌ Failed to parse due date:`

If you see this, the date string from GPT-4 is malformed.

### 5. GPT-4 Says "No Deadline"
**Check for:** `ℹ️ No deadline detected in message`

If you see this, GPT-4 determined the message doesn't contain a deadline.

---

## Diagnostic Steps

### Step 1: Check if Extraction is Being Called
Look for: `🚨 DEADLINE: Extracting deadline from message:`

- **If YES:** Continue to Step 2
- **If NO:** See "Extraction Not Being Called" section below

### Step 2: Check Cloud Function Logs
Look for: `📤 AIService: Calling Cloud Function for deadline extraction`

- **If YES:** Continue to Step 3
- **If NO:** Extraction started but didn't reach Cloud Function call

### Step 3: Check Cloud Function Response
Look for: `📦 Raw response from Cloud Function:`

**What to check:**
- Is `detected: true` or `detected: false`?
- Is there a `deadline` object with `title`, `dueDate`, etc.?

### Step 4: Check Date Parsing
Look for: `✅ Cloud Function SUCCESS!`

- **If YES:** Extraction succeeded, check Firestore
- **If NO:** Check for parsing errors

---

## Quick Fixes to Try

### Fix 1: Add More Logging
Add this to the top of `handleFirestoreMessages` to confirm messages are being received:

```swift
print("🚨 DEADLINE: 📨 Message received: \(firebaseMessage.text)")
print("🚨 DEADLINE:    Sender: \(firebaseMessage.senderId)")
print("🚨 DEADLINE:    Current user: \(currentUserId)")
print("🚨 DEADLINE:    Will extract? \(firebaseMessage.senderId == currentUserId)")
```

### Fix 2: Temporarily Remove Sender Check
Change line 345 from:
```swift
if firebaseMessage.senderId == currentUserId {
```

To:
```swift
if true { // TEMP: Extract for all messages
```

This will help diagnose if the sender check is the issue.

### Fix 3: Check Keyword Filter
The keyword filter might be case-sensitive. Try sending:
- "Deadline is Friday at 2PM" (capital D)
- "Due Friday at 2PM" (just "due")

### Fix 4: Check Cloud Function Logs
Go to Firebase Console → Functions → Logs

Look for recent `processAI` function calls. Check if they show:
- Message text received
- `detectDeadline` being called
- GPT-4 response
- Any errors

---

## Expected Log Flow (When Working)

### 1. Message Received
```
🚨 DEADLINE: Extracting deadline from message: msg123
```

### 2. Cloud Function Called
```
📤 AIService: Calling Cloud Function for deadline extraction
   Message: deadline is friday at 2PM...
```

### 3. Cloud Function Response
```
📦 Raw response from Cloud Function:
   Keys: [confidence, deadline, detected, method, ...]
   Full data: {detected: 1, deadline: {...}, ...}
```

### 4. Date Parsing
```
✅ Cloud Function SUCCESS!
   - Title: Deadline
   - Due: 2025-10-24 14:00:00
   - Priority: high
```

### 5. Firestore Update
```
✅ Updated message AIMetadata with deadline in Firestore
```

### 6. Firestore Listener
```
🔄 Update received - 1 documents from Firestore
📄 Parsing document: deadline123
   ✅ Parsed: Deadline - Due: 2025-10-24 14:00:00
✅ Updated UI state - 1 active deadlines
```

---

## User: Try This Now

### Test Message
Send this exact message (it has very obvious deadline indicators):

```
DEADLINE: Submit report by Friday 2PM
```

### What to Check
1. Open Xcode console
2. Filter for "DEADLINE:"
3. Look for the first log: `Extracting deadline from message`
4. Follow the log trail to see where it stops

### Report Back
Tell me:
- Do you see "Extracting deadline from message"? YES / NO
- If NO, do you see ANY logs with "DEADLINE:" after sending? YES / NO  
- If YES, what's the last "DEADLINE:" log you see?
- Any errors with "❌" or "ERROR"?

This will help me pinpoint exactly where the issue is!

