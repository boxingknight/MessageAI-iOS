# 🧪 PR#18 RSVP Tracking - Quick Test Card

## ⚡ 5-Minute Quick Test

### 1. Launch App & Sign In (30 seconds)
```bash
open messAI.xcodeproj
# Build & Run (Cmd+R) on iPhone simulator
```

### 2. Create Calendar Event (1 minute)
**Send message:**
```
Soccer practice Thursday at 4pm at Central Park
```
**Long-press** → "Extract Calendar Event"  
**Wait 2-3s** → Calendar card appears ✅

### 3. Test RSVP Responses (2 minutes)

**YES Response:**
```
Yes! I'll be there
```
✅ Check Xcode console for: `RSVP detected: yes`

**NO Response:**
```
Sorry, can't make it
```
✅ Check console for: `RSVP detected: no`

**MAYBE Response:**
```
Maybe, depends on my schedule
```
✅ Check console for: `RSVP detected: maybe`

**NOT an RSVP:**
```
What time does it start?
```
✅ Check console for: `No RSVP detected`

### 4. Verify in Firebase Console (1 minute)
1. Go to: https://console.firebase.google.com
2. Navigate to Firestore Database
3. Check: `conversations/{id}/messages/{id}/aiMetadata`
4. Look for: `rsvpStatus: "yes"`
5. Check: `events/{eventId}/rsvps/{userId}`

---

## 🎯 Test Messages Cheat Sheet

| Message | Expected | Passes Keyword Filter? |
|---------|----------|------------------------|
| `"Yes! Count me in"` | **yes** | ✅ Yes (instant) |
| `"Definitely"` | **yes** | ✅ Yes (instant) |
| `"No, can't make it"` | **no** | ✅ Yes (instant) |
| `"Sorry, have to pass"` | **no** | ✅ Yes (instant) |
| `"Maybe"` | **maybe** | ✅ Yes (instant) |
| `"Not sure yet"` | **maybe** | ✅ Yes (instant) |
| `"What time?"` | **none** | ❌ No (skips GPT-4) |
| `"See you there"` | **yes** | ✅ Yes (GPT-4 needed) |

---

## 🔍 What to Look For in Console

### ✅ SUCCESS (RSVP Detected)
```
🎯 Tracking RSVP for message: [id]
✓ RSVP keywords found. Proceeding to GPT-4 analysis...
🤖 Calling GPT-4 for RSVP detection...
✅ RSVP detected: yes
   - Confidence: 0.95
   - Event ID: event123
   - Method: hybrid
✅ Updated local message with RSVP: yes
✅ Updated Firestore with RSVP metadata
✅ Updated event RSVP tracking: event123 → yes
```

### ✅ SUCCESS (No RSVP - Fast Path)
```
🎯 Tracking RSVP for message: [id]
✅ No RSVP keywords found (45ms). Skipping GPT-4.
```

### ❌ ERROR (Check These)
```
❌ RSVP tracking failed: You must be logged in
❌ Invalid response from AI service
❌ Failed to update message RSVP in Firestore
```

---

## 🚨 Common Issues

| Issue | Quick Fix |
|-------|-----------|
| No RSVP detected for "Yes" | Check OpenAI API key: `firebase functions:config:get openai.key` |
| Cloud Function error | Redeploy: `cd functions && npm run deploy` |
| Firestore permission error | Check you're signed in as authenticated user |
| Message not in Firestore | Wait 2-3s, check network connection |

---

## 📊 Success Checklist

- [ ] Calendar event creation works
- [ ] "Yes" responses detected
- [ ] "No" responses detected  
- [ ] "Maybe" responses detected
- [ ] Non-RSVP messages ignored
- [ ] Console shows clear logging
- [ ] Firestore has `rsvpStatus` field
- [ ] Event subcollection updated

---

**Full Test Guide**: See `PR18_TESTING_INSTRUCTIONS.md`  
**Estimated Time**: 5-20 minutes depending on depth
