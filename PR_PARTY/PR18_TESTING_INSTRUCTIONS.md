# PR#18: RSVP Tracking - Manual Testing Guide

**Feature**: AI-powered RSVP detection that automatically tracks yes/no/maybe responses to events  
**Status**: Ready for testing  
**Estimated Test Time**: 15-20 minutes

---

## 📋 Prerequisites

### 1. Check Cloud Functions Deployment
```bash
cd functions
firebase functions:list | grep processAI
```
✅ You should see `processAI` listed with status `deployed`

### 2. Launch iOS App
```bash
# Open Xcode
open messAI.xcodeproj

# Or use command line
xcodebuild -project messAI.xcodeproj -scheme messAI -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### 3. Verify You're on the Right Branch
```bash
git branch --show-current
# Should output: feature/pr18-rsvp-tracking
```

---

## 🧪 Test Scenario 1: Basic RSVP Detection (Yes/No/Maybe)

### Setup
1. **Launch app** in iOS Simulator
2. **Sign in** with two test users:
   - User A: Primary test user
   - User B: RSVP responder

### Test Steps

#### Step 1: Create a Calendar Event (Prerequisite for PR#18)
**From User A's device:**

1. Go to a group chat or 1-on-1 conversation
2. Send message:
   ```
   Soccer practice Thursday at 4pm at Central Park
   ```
3. **Long-press the message** → Select "Extract Calendar Event"
4. **Expected**: Calendar card appears below message with event details
5. **Wait**: 2-3 seconds for AI extraction
6. **Verify**: 
   - ✅ Card shows "Soccer practice"
   - ✅ Date: "Thursday"
   - ✅ Time: "4:00 PM - 5:00 PM"
   - ✅ Location: "Central Park"

---

#### Step 2: Send RSVP Response (YES)
**From User B's device:**

1. Switch to User B's simulator/device
2. Open the same conversation
3. Send message:
   ```
   Yes! I'll be there
   ```
4. **Expected**: 
   - ✅ Message appears **immediately** (optimistic UI)
   - ✅ Wait 1-2 seconds...
   - ✅ Check Xcode console for:
     ```
     🎯 Tracking RSVP for message: [messageId]
     ✅ RSVP detected: yes
        - Confidence: 0.9X
        - Event ID: [eventId]
        - Method: hybrid
     ```

5. **Verify RSVP Metadata** (check Firestore):
   - Navigate to Firebase Console → Firestore Database
   - Go to: `conversations/{conversationId}/messages/{messageId}`
   - Look for `aiMetadata` field:
     ```json
     {
       "rsvpStatus": "yes",
       "rsvpEventId": "[eventId]",
       "rsvpConfidence": 0.95,
       "rsvpMethod": "hybrid"
     }
     ```

6. **Verify Event RSVP Subcollection**:
   - Go to: `events/{eventId}/rsvps/{userId}`
   - Check document exists with:
     ```json
     {
       "userId": "[userBId]",
       "userName": "[User B Name]",
       "status": "yes",
       "respondedAt": [Timestamp],
       "messageId": "[messageId]"
     }
     ```

---

#### Step 3: Test Different RSVP Statuses

**Test "NO" Response:**
```
Sorry, can't make it. Have a dentist appointment.
```
**Expected**: 
- ✅ Console: `RSVP detected: no`
- ✅ Firestore: `rsvpStatus: "no"`

**Test "MAYBE" Response:**
```
Maybe, depends on whether I can get a babysitter.
```
**Expected**: 
- ✅ Console: `RSVP detected: maybe`
- ✅ Firestore: `rsvpStatus: "maybe"`

**Test "NO RSVP" (Regular Message):**
```
What time does it start again?
```
**Expected**: 
- ✅ Console: `No RSVP detected in message`
- ✅ Firestore: No `rsvpStatus` field added

---

## 🧪 Test Scenario 2: Keyword Filter Fast Path

**Goal**: Verify that 80% of messages skip GPT-4 (cost optimization)

### Test Steps

#### Test 1: Message WITHOUT RSVP Keywords (Fast Path)
**Send:**
```
What's the weather forecast?
```
**Expected**: 
- ✅ Console: `No RSVP detected` (should be almost instant, <100ms)
- ✅ No GPT-4 API call made (check Firebase Functions logs)

#### Test 2: Message WITH RSVP Keywords BUT No Intent
**Send:**
```
Yes, I heard about the event. When is it?
```
**Expected**: 
- ✅ Keyword filter passes (contains "yes")
- ✅ GPT-4 called for context analysis
- ✅ Console: `No RSVP detected` (because not actually responding to attend)

---

## 🧪 Test Scenario 3: Multiple RSVPs in Group Chat

### Setup
1. Create a **group chat** with 4+ users
2. Post a calendar event message
3. Have multiple users respond

### Test Steps

**User A posts event:**
```
Birthday party Saturday 2pm at my place!
```
**Extract calendar event** (long-press → Extract)

**User B responds:**
```
Count me in! 🎉
```
**Expected**: ✅ RSVP: yes

**User C responds:**
```
Can't make it, sorry 😢
```
**Expected**: ✅ RSVP: no

**User D responds:**
```
Tentative - need to check my schedule
```
**Expected**: ✅ RSVP: maybe

**User E (no response yet)**
**Expected**: ✅ RSVP: pending (default)

---

## 🧪 Test Scenario 4: RSVP Without Event Link

**Goal**: Test RSVP detection when no recent calendar events exist

### Test Steps

1. Start a **new conversation** (no calendar events yet)
2. Send RSVP-like message:
   ```
   Yes, I'll be there!
   ```

**Expected**: 
- ✅ RSVP detected: yes
- ✅ But `rsvpEventId`: null (no event to link to)
- ✅ Console: `Event ID: none`

---

## 🧪 Test Scenario 5: Hybrid Detection (Keyword → GPT-4)

**Goal**: Verify the two-tier system works correctly

### Test Messages

| Message | Keyword Filter | GPT-4 Called? | Expected Result |
|---------|---------------|---------------|-----------------|
| "Yes!" | ✅ Pass | ✅ Yes | RSVP: yes |
| "Absolutely!" | ✅ Pass | ✅ Yes | RSVP: yes |
| "Nope" | ✅ Pass | ✅ Yes | RSVP: no |
| "Can't come" | ✅ Pass | ✅ Yes | RSVP: no |
| "Possibly" | ✅ Pass | ✅ Yes | RSVP: maybe |
| "Hello there" | ❌ Fail | ❌ No | No RSVP |
| "What time?" | ❌ Fail | ❌ No | No RSVP |
| "See you soon" | ❌ Fail | ❌ No | No RSVP |

### How to Verify
**Check Xcode Console for:**
```
🎯 Tracking RSVP for message: [id]
✅ No RSVP keywords found (XXms). Skipping GPT-4.  // Fast path
```
OR
```
✓ RSVP keywords found. Proceeding to GPT-4 analysis...  // Slow path
🤖 Calling GPT-4 for RSVP detection...
```

---

## 🧪 Test Scenario 6: Edge Cases

### Test 1: Ambiguous Response
**Message:**
```
I might be able to make it, but yes for now
```
**Expected**: 
- ✅ RSVP: maybe (due to "might" and uncertainty)
- OR ✅ RSVP: yes (if GPT-4 interprets "yes for now" as commitment)
- ✅ Confidence: 0.6-0.8 (lower due to ambiguity)

### Test 2: Multiple Events in Chat
**Setup:**
- Create 2 calendar events:
  1. "Soccer practice Thursday 4pm"
  2. "Piano recital Friday 7pm"

**Message:**
```
Yes to soccer, but can't make the recital
```
**Expected**: 
- ✅ GPT-4 should detect two RSVPs
- ✅ First RSVP: yes (linked to soccer event)
- ⚠️ **Note**: Current implementation processes one RSVP per message
  - This is a **known limitation** (documented in planning docs)
  - Would need multiple RSVP detection for full support

### Test 3: RSVP in Different Languages
**Message (Spanish):**
```
Sí, estaré ahí
```
**Expected**: 
- ⚠️ May not pass keyword filter (English keywords only)
- 🔧 **Enhancement needed**: Multi-language keyword support

---

## 🧪 Test Scenario 7: Performance Testing

**Goal**: Verify AI processing doesn't block UI

### Test Steps

1. **Send calendar event message**
2. **Immediately send RSVP response** (don't wait)
3. **Rapidly send 5 more messages** (any text)

**Expected**: 
- ✅ All messages appear **instantly** (optimistic UI)
- ✅ No UI freezing or lag
- ✅ RSVP detection happens in background (~1-2s delay)
- ✅ Check console for async processing logs

---

## 🧪 Test Scenario 8: Firestore Verification

**Goal**: Verify data is stored correctly in Firestore

### Steps to Check Firestore

1. **Open Firebase Console**: https://console.firebase.google.com
2. **Navigate to Firestore Database**
3. **Check Message Document**:
   ```
   conversations/{conversationId}/messages/{messageId}
   ```
   Look for:
   ```json
   {
     "text": "Yes! I'll be there",
     "senderId": "...",
     "aiMetadata": {
       "rsvpStatus": "yes",
       "rsvpEventId": "event123",
       "rsvpConfidence": 0.95,
       "rsvpMethod": "hybrid",
       "rsvpReasoning": "Clear affirmative response"
     }
   }
   ```

4. **Check Event RSVP Subcollection**:
   ```
   events/{eventId}/rsvps/{userId}
   ```
   Look for:
   ```json
   {
     "userId": "user456",
     "userName": "Sarah Johnson",
     "status": "yes",
     "respondedAt": Timestamp(2025-10-22 20:30:00),
     "messageId": "msg789"
   }
   ```

---

## 📊 Success Criteria Checklist

Use this checklist to verify PR#18 is working correctly:

### Core Functionality
- [ ] ✅ RSVP detection works for "yes" responses
- [ ] ✅ RSVP detection works for "no" responses
- [ ] ✅ RSVP detection works for "maybe" responses
- [ ] ✅ Non-RSVP messages are correctly ignored
- [ ] ✅ RSVPs are linked to calendar events (when available)

### Performance
- [ ] ✅ Messages appear instantly (optimistic UI)
- [ ] ✅ RSVP detection is non-blocking (~1-2s background)
- [ ] ✅ Keyword filter skips GPT-4 for non-RSVP messages (<100ms)
- [ ] ✅ No UI freezing during AI processing

### Data Storage
- [ ] ✅ Message `aiMetadata` updated in Firestore
- [ ] ✅ RSVP stored in `/events/{eventId}/rsvps/{userId}`
- [ ] ✅ RSVP includes userId, userName, status, timestamp
- [ ] ✅ Local message state updated after detection

### Edge Cases
- [ ] ✅ Works without calendar events (RSVP detected, no event link)
- [ ] ✅ Works in group chats (multiple RSVPs tracked)
- [ ] ✅ Handles ambiguous responses (lower confidence scores)
- [ ] ✅ Doesn't crash on malformed messages

### Console Logging
- [ ] ✅ Clear logging for keyword filter results
- [ ] ✅ Clear logging for GPT-4 API calls
- [ ] ✅ Clear logging for RSVP detection results
- [ ] ✅ Clear logging for Firestore updates

---

## 🐛 Known Issues & Limitations

### Current Limitations
1. **Single RSVP per message**: Can't detect "Yes to soccer, no to piano" in one message
2. **English keywords only**: Non-English responses may not pass keyword filter
3. **No UI display yet**: RSVPSectionView created but not integrated into ChatView
   - Will be added in follow-up commit
4. **No event aggregation UI**: RSVP summary ("5 of 12 confirmed") not displayed yet

### Expected Behavior
- **False negatives rare**: Hybrid approach catches 90%+ of RSVPs
- **False positives possible**: "Yes, I saw your message" might trigger detection
  - GPT-4 context analysis reduces this to <10%

---

## 🔧 Troubleshooting

### Issue: "No RSVP detected" for clear response
**Possible Causes:**
1. Message doesn't contain RSVP keywords → Fast path skipped GPT-4
2. Check console for "No RSVP keywords found"
3. **Fix**: Add more keywords to `RSVP_KEYWORDS` array in `rsvpTracking.ts`

### Issue: "Invalid response from AI service"
**Possible Causes:**
1. Cloud Function not deployed
2. OpenAI API key not configured
3. **Check**: `firebase functions:config:get openai.key`
4. **Fix**: `firebase functions:config:set openai.key="YOUR_KEY"`

### Issue: "Failed to update message RSVP in Firestore"
**Possible Causes:**
1. Firestore security rules blocking update
2. User not authenticated
3. **Check**: Firestore rules allow `aiMetadata` field updates
4. **Fix**: Update rules to allow authenticated users to update their messages

### Issue: Messages not appearing in Firestore Console
**Possible Causes:**
1. Network offline
2. Firestore sync disabled
3. **Check**: Look for "📦 Message from other user" in console
4. **Fix**: Check network connection, restart app

---

## 📈 Performance Benchmarks

**Target Performance:**
- Keyword filter: <100ms (80% of messages)
- GPT-4 analysis: <3s (20% of messages)
- Total processing time: <2s average
- Cost per RSVP: <$0.003

**How to Measure:**
1. Check console logs for "Processing Time: XXXms"
2. Use Xcode Instruments to profile async tasks
3. Monitor Firebase Functions execution logs

---

## 🎯 Next Steps After Testing

Once all tests pass:

1. **Merge to main:**
   ```bash
   git checkout main
   git merge feature/pr18-rsvp-tracking
   git push origin main
   ```

2. **Deploy Cloud Functions to production:**
   ```bash
   cd functions
   npm run deploy
   ```

3. **Update documentation:**
   - Mark PR#18 as COMPLETE in PR_PARTY/README.md
   - Update memory-bank/progress.md
   - Create PR18_COMPLETE_SUMMARY.md

4. **Start PR#19 (Deadline Extraction)** OR **Continue with UI integration**

---

## 📞 Support

**Issues?** Check:
1. Xcode console logs (search for "RSVP")
2. Firebase Functions logs (search for "rsvpTracking")
3. Firestore data (verify documents exist)
4. Network connectivity (Cloud Functions require internet)

**Questions?** Review:
- `PR18_RSVP_TRACKING.md` - Main specification
- `PR18_IMPLEMENTATION_CHECKLIST.md` - Implementation details
- `PR18_TESTING_GUIDE.md` - Comprehensive test scenarios

---

**Happy Testing! 🎉**

This feature saves busy parents 10+ minutes per event organized. Let's make sure it works perfectly! 💪

