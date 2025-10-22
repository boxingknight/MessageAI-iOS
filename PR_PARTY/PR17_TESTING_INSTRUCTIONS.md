# PR#17: Priority Highlighting - Testing Guide 🧪

**Feature:** AI-powered urgent message detection with visual indicators  
**Branch:** `feature/pr17-priority-highlighting`  
**Status:** ✅ Ready to Test

---

## 🚀 Quick Start (3 Steps)

### Step 1: Build & Run
```bash
# Open Xcode
open messAI.xcodeproj

# Build and run on simulator (Cmd + R)
# OR use command line:
xcodebuild -project messAI.xcodeproj -scheme messAI -sdk iphonesimulator -destination 'platform=iOS Simulator,id=1B149F11-C949-452E-9B5B-473C76F971E4' build
```

### Step 2: Navigate to a Chat
1. Sign in to the app
2. Open any conversation (1-on-1 or group chat)
3. Look for the **orange triangle button** (⚠️) in the toolbar next to the purple sparkles button

### Step 3: Test Priority Detection
1. Send a test message (see examples below)
2. Tap the **orange triangle button** (⚠️) to detect priority
3. Watch the Xcode console for detection results
4. **See the visual indicators** appear on the message:
   - 🔴 **Red border** = Critical priority
   - 🟠 **Orange border** = High priority
   - ⚪ **No border** = Normal priority

---

## 📝 Test Message Examples

### 🚨 Critical Priority (Should show RED border + 🚨 badge)

```
EMERGENCY - need help now!
```

```
URGENT: School pickup changed to 2pm TODAY
```

```
ASAP - meeting starting right now
```

```
911 - car accident on Main Street
```

```
CRITICAL - server is down
```

### ⚠️ High Priority (Should show ORANGE border + ⚠️ badge)

```
Important: Forms due today by 5pm
```

```
Reminder - pickup at 3pm this afternoon
```

```
Don't forget the meeting tonight at 7pm
```

```
Deadline tomorrow - need your feedback soon
```

```
Pickup changed to 4pm today
```

### ⚪ Normal Priority (Should show NO border or badge)

```
Hey, how are you?
```

```
Had a great day at the park!
```

```
Thanks for helping yesterday
```

```
See you next week!
```

```
What are you doing for dinner?
```

---

## 🧪 Testing Methods

### Method 1: Test Button (Easiest) ✅

**What:** Orange triangle button (⚠️) in chat toolbar

**How to Use:**
1. Send or receive any message
2. Tap the **orange triangle button** (⚠️) in top-right
3. Watch Xcode console for detection results
4. Message will update with visual indicators

**What to Look For:**
```
🧪 Testing priority detection on message: abc123
   Text: EMERGENCY - need help now!
   
🎯 AIService: Detecting priority...
📤 AIService: Calling Cloud Function...
✅ AIService: Priority detected successfully
   - Level: critical
   - Confidence: 0.95
   - Method: hybrid
   - Used GPT-4: true
   - Processing Time: 2100ms
   
✅ Priority Detection Test Complete:
   Level: critical
   Confidence: 0.95
   Method: hybrid
   Used GPT-4: true
   Processing Time: 2100ms
   Keywords: emergency, now
   Reasoning: Emergency keyword detected with immediate action required
```

**Visual Result:**
- Message should now have a **red border** (2pt)
- **🚨 badge** in top-right corner
- Border is clearly visible around the message bubble

---

### Method 2: Automatic Detection (Coming Soon)

**Note:** Automatic detection on new messages is implemented but not yet wired up to run automatically. To enable:

1. Open `ChatViewModel.swift`
2. Find `handleFirestoreMessages()` function
3. Add this code when a new message arrives:

```swift
// Detect priority for new message
Task {
    await detectMessagePriority(
        for: firebaseMessage.id,
        messageText: firebaseMessage.text
    )
}
```

---

## 🔍 What to Verify

### ✅ Visual Indicators

1. **Critical Messages (Red):**
   - [ ] Red border (2pt thickness)
   - [ ] 🚨 badge in top-right corner
   - [ ] Border clearly visible and distinguishable
   - [ ] Badge icon rendered cleanly

2. **High Priority Messages (Orange):**
   - [ ] Orange border (1.5pt thickness)
   - [ ] ⚠️ badge in top-right corner
   - [ ] Border clearly visible
   - [ ] Different from critical (orange vs red)

3. **Normal Messages (No Indicator):**
   - [ ] No border
   - [ ] No badge
   - [ ] Looks like regular message bubble

### ✅ Detection Accuracy

Test each category:

| Message Type | Expected Level | Keywords to Test |
|--------------|----------------|------------------|
| Emergency | Critical | emergency, urgent, asap, 911, help |
| Time-Sensitive | High | today, tonight, pickup changed, deadline |
| Important | High | important, reminder, don't forget |
| Casual | Normal | hey, thanks, how are you |

### ✅ Performance

Watch Xcode console for timing:

- **Keyword-only (80% of messages):**
  - [ ] Processing time < 100ms
  - [ ] Method: "keyword"
  - [ ] Used GPT-4: false

- **Hybrid (20% of messages):**
  - [ ] Processing time < 3 seconds
  - [ ] Method: "hybrid"
  - [ ] Used GPT-4: true
  - [ ] Confidence > 0.7

### ✅ Error Handling

1. **No Internet:**
   - [ ] Detection fails gracefully
   - [ ] Message still displays normally
   - [ ] Error logged to console

2. **API Rate Limit:**
   - [ ] Error message shown
   - [ ] Message remains functional
   - [ ] Can retry later

3. **Invalid Message:**
   - [ ] Empty messages handled
   - [ ] Special characters work
   - [ ] Emoji messages work

---

## 📊 Expected Results

### Fast Path (Keyword Filter - 80% of messages)

**Example Message:** "Hey, how are you?"

```
✅ Priority detected: normal
   - Confidence: 0.85
   - Method: keyword
   - Used GPT-4: false
   - Processing Time: 45ms
   - Keywords: []
   - Reasoning: No urgency indicators detected
```

**Visual:** No border, no badge ✅

---

### Slow Path (GPT-4 Analysis - 20% of messages)

**Example Message:** "URGENT: School pickup changed to 2pm TODAY"

```
✅ Priority detected: critical
   - Confidence: 0.95
   - Method: hybrid
   - Used GPT-4: true
   - Processing Time: 2100ms
   - Keywords: ["urgent", "today", "pickup changed"]
   - Reasoning: Time-sensitive schedule change requiring immediate action
```

**Visual:** Red border (2pt) + 🚨 badge ✅

---

## 🐛 Troubleshooting

### Issue: Test button doesn't appear
**Solution:** Make sure you're running a DEBUG build (not RELEASE)

### Issue: Button appears but nothing happens
**Solution:** 
1. Check Xcode console for errors
2. Verify OpenAI API key is configured in Firebase Functions
3. Check internet connection

### Issue: Detection always returns "normal"
**Solution:**
1. Verify Cloud Function is deployed: `firebase functions:list`
2. Check if `processAI` function shows in list
3. Re-deploy: `firebase deploy --only functions`

### Issue: Visual indicators don't show
**Solution:**
1. Check message has `aiMetadata.priorityLevel` set
2. Print message data in console: `print(message.aiMetadata)`
3. Verify PriorityLevel enum is imported in MessageBubbleView

### Issue: "GPT-4 failed" errors
**Solution:**
1. Check Firebase Functions logs: `firebase functions:log`
2. Verify OpenAI API key: `firebase functions:config:get`
3. Check OpenAI account has credits

---

## 📈 Success Criteria

Your testing is successful when:

- [x] Test button appears in toolbar (DEBUG builds only)
- [x] Tapping button triggers detection (see console logs)
- [x] Critical messages show **red border + 🚨 badge**
- [x] High priority messages show **orange border + ⚠️ badge**
- [x] Normal messages show **no indicators**
- [x] 80% of messages use fast keyword path (<100ms)
- [x] 20% of messages use GPT-4 hybrid path (<3s)
- [x] Detection accuracy: >80% correct classifications
- [x] No app crashes or hangs
- [x] Visual indicators update in real-time

---

## 🎯 Advanced Testing

### Test Hybrid Approach Cost Savings

1. Send 10 normal messages (casual conversation)
   - **Expected:** All use keyword method (0 GPT-4 calls)
   - **Cost:** $0

2. Send 5 messages with "important" keyword
   - **Expected:** Some use GPT-4 for context
   - **Cost:** ~$0.01 (5 × $0.002)

3. Send 5 messages with "URGENT" keyword
   - **Expected:** Most use GPT-4 for verification
   - **Cost:** ~$0.01

**Total Cost:** ~$0.02 for 20 messages (vs. $0.04 if all used GPT-4)

### Test Edge Cases

1. **Empty message:** Should handle gracefully
2. **Very long message (500+ words):** Should still detect
3. **Multiple urgent keywords:** Should increase confidence
4. **Mixed language:** Should work with basic English
5. **All caps:** "HELLO" - Should not trigger false positive
6. **URLs in message:** Should ignore URLs
7. **Emoji only:** "😊😊😊" - Should be normal priority

---

## 📝 Test Report Template

```markdown
## PR#17 Priority Highlighting - Test Results

**Date:** [Date]
**Tester:** [Your Name]
**Build:** Debug
**Simulator:** iPhone 17 (iOS 26.0.1)

### Visual Indicators
- [x] Red borders for critical messages
- [x] Orange borders for high priority
- [x] Badges render cleanly
- [x] No indicators on normal messages

### Detection Accuracy
- Critical: 9/10 correct (90%)
- High: 8/10 correct (80%)
- Normal: 10/10 correct (100%)

### Performance
- Keyword path: 45ms average
- GPT-4 path: 2.1s average
- Fast path usage: 82% (good!)

### Issues Found
- None

### Recommendations
- Ready for merge ✅
```

---

## 🚀 Next Steps After Testing

Once testing is complete:

1. **Merge to main:**
   ```bash
   git checkout main
   git merge feature/pr17-priority-highlighting
   git push origin main
   ```

2. **Document results** in `PR17_COMPLETE_SUMMARY.md`

3. **Remove test button** (optional - it's DEBUG-only so won't appear in production)

4. **Move to PR#18** (RSVP Tracking or next AI feature)

---

**Happy Testing!** 🎉

If you encounter any issues, check the Xcode console first - it has detailed logging for every step of the detection process.

