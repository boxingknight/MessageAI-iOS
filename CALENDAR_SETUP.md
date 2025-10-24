# 📅 iOS Calendar Integration Setup

## ⚠️ Required: Add Calendar Permission

Before the "Add to Calendar" feature will work, you need to add a calendar permission description to your Xcode project.

---

## 🔧 Setup Instructions (5 minutes)

### Option 1: Using Xcode GUI (Easiest)

1. **Open the project in Xcode**:
   ```bash
   open messAI.xcodeproj
   ```

2. **Select the messAI target**:
   - Click on the project name in the left sidebar
   - Select "messAI" under TARGETS (not the project)

3. **Go to the Info tab**:
   - Look for tabs at the top: General, Signing & Capabilities, Resource Tags, **Info**, Build Settings, Build Phases

4. **Add the calendar permission**:
   - Click the **+** button to add a new key
   - Select **"Privacy - Calendars Full Access Usage Description"**
   - Or manually type: `NSCalendarsFullAccessUsageDescription`

5. **Set the description** (shown to users when requesting permission):
   ```
   messAI needs calendar access to add events you RSVP to
   ```

6. **Build and run** - Done! ✅

---

### Option 2: Edit Info.plist Directly

If your project has a separate Info.plist file:

1. Open `messAI/Info.plist`
2. Add this key-value pair:

```xml
<key>NSCalendarsFullAccessUsageDescription</key>
<string>messAI needs calendar access to add events you RSVP to</string>
```

---

## ✅ How to Test

### 1. Run the app
```bash
cd messAI
# Run in Xcode or via command line
```

### 2. Create an event and RSVP Yes
- User A: Send "Soccer on Friday at 2PM"
- User A: Tap "Create & Organize"
- User B: See invitation, tap "Yes, I'll attend"

### 3. Tap "Add to Calendar"
- iOS will show permission alert: **"messAI Would Like to Access Your Calendar"**
- Tap **"Allow"**

### 4. Check iOS Calendar app
- Open Calendar app
- Event should appear with:
  - Title: "Soccer" (or your event name)
  - Date: Tomorrow (simplified for now)
  - Duration: 1 hour
  - Location: (if provided)
  - Notes: "Created from messAI"

---

## 📊 Expected Behavior

### First Time:
1. User taps "Add to Calendar"
2. **iOS permission alert appears**
3. User grants permission
4. Event added to Calendar ✅
5. Ambient Bar dismisses

### Subsequent Times:
1. User taps "Add to Calendar"
2. **No alert** (permission already granted)
3. Event added immediately ✅
4. Ambient Bar dismisses

---

## 🐛 Troubleshooting

### Issue: "Calendar access denied" error

**Cause**: User denied permission or it wasn't requested properly

**Fix**:
1. Go to **Settings** → **Privacy & Security** → **Calendars**
2. Find **messAI**
3. Toggle **ON**
4. Restart the app

### Issue: Permission alert doesn't appear

**Cause**: `NSCalendarsFullAccessUsageDescription` not set in Info.plist

**Fix**:
1. Follow setup instructions above
2. Clean build: `Cmd+Shift+K`
3. Rebuild and run

### Issue: Event doesn't appear in Calendar

**Check**:
1. Console logs - look for "✅ Event added to calendar"
2. Open Calendar app - check tomorrow's date
3. Check default calendar (it uses the user's default)

---

## 🚀 What's Working

- ✅ Calendar permission request (iOS 17+)
- ✅ Event creation with title, date, time, location
- ✅ Saves to user's default calendar
- ✅ Error handling for denied permissions
- ✅ Ambient Bar dismisses after adding

---

## 🔄 Future Improvements

1. **Better date parsing**: Currently uses "tomorrow" as fallback
2. **Parse time strings**: "2PM" → actual time
3. **Add reminders**: 15 min before, 1 hour before, etc.
4. **Add participants**: Set event attendees from RSVP list
5. **Handle timezones**: Proper timezone conversion
6. **Custom calendar selection**: Let user choose which calendar

---

## 📝 Current Limitations

1. **Date Parsing**: 
   - Currently uses tomorrow as default
   - Need to parse strings like "Friday", "next week", "Dec 15"

2. **Time Parsing**:
   - Need to parse strings like "2PM", "14:00", "afternoon"

3. **Duration**:
   - Currently hardcoded to 1 hour
   - Could extract from context ("2-4pm" = 2 hours)

---

## ✅ Ready to Use!

Once you've added the `NSCalendarsFullAccessUsageDescription` key:

1. **Run the app**
2. **RSVP to an event**
3. **Tap "Add to Calendar"**
4. **Grant permission**
5. **Check Calendar app** ✅

The event will be there! 🎉

