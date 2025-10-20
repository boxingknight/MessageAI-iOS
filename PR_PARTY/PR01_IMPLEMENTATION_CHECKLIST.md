# PR #1: Implementation Checklist

**Use this as your daily todo list.** Check off items as you complete them.

**Branch**: `feature/project-setup`  
**Estimated Time**: 1-2 hours  
**Started**: (Fill in when you begin)  
**Completed**: (Fill in when done)

---

## Pre-Implementation Setup (5 minutes)

- [ ] Read main planning document (`PR01_PROJECT_SETUP.md`) - 45 min
- [ ] Read this checklist completely - 10 min
- [ ] Have Google account ready for Firebase
- [ ] Have stable internet connection
- [ ] Xcode is open with messAI project loaded
- [ ] Git working tree is clean
  ```bash
  git status  # Should show "nothing to commit, working tree clean"
  ```
- [ ] Create feature branch
  ```bash
  git checkout -b feature/project-setup
  ```

**Checkpoint**: ✅ Branch created, ready to begin

---

## Phase 1: Firebase Project Creation (30 minutes)

### 1.1: Create Firebase Project (5 minutes)

- [ ] Open browser and go to https://console.firebase.google.com
- [ ] Click "Add project" or "Create a project"
- [ ] Enter project name: **MessageAI** (recommended) or **messAI**
  - Note: This is just a display name, choose whichever you prefer
- [ ] Click "Continue"
- [ ] Google Analytics: Toggle OFF (not needed for MVP)
- [ ] Click "Create project"
- [ ] Wait for project creation (~1-2 minutes)
  - Watch for "Your new project is ready"
- [ ] Click "Continue"

**Checkpoint**: ✅ Firebase project created

---

### 1.2: Register iOS App (5 minutes)

- [ ] In Firebase Console, click iOS icon (or "Add app" → iOS)
- [ ] Fill in iOS bundle ID: `com.isaacjaramillo.messAI`
  - **Important**: Must match exactly what you'll use in Xcode
  - Alternative: `com.boxingknight.messAI` if you prefer
  - **Decision**: Write down which one you chose: __________________
- [ ] App nickname: **MessageAI iOS**
- [ ] App Store ID: Leave blank (don't have one yet)
- [ ] Click "Register app"

**Checkpoint**: ✅ iOS app registered with Firebase

---

### 1.3: Download Configuration File (2 minutes)

- [ ] Click "Download GoogleService-Info.plist"
- [ ] Save to Downloads folder
- [ ] **Important**: Do NOT add to Xcode yet (we'll do that in Phase 2)
- [ ] Click "Next"
- [ ] Click "Next" (skip SDK instructions, we'll do SPM)
- [ ] Click "Continue to console"

**Checkpoint**: ✅ GoogleService-Info.plist downloaded

---

### 1.4: Enable Firebase Authentication (5 minutes)

- [ ] In Firebase Console sidebar, click "Build" → "Authentication"
- [ ] Click "Get started"
- [ ] Click "Sign-in method" tab
- [ ] Find "Email/Password" in the list
- [ ] Click on it
- [ ] Toggle "Enable" switch to ON
- [ ] **Important**: Leave "Email link (passwordless sign-in)" OFF
- [ ] Click "Save"
- [ ] Verify you see "Email/Password" with green checkmark

**Checkpoint**: ✅ Email/Password authentication enabled

---

### 1.5: Create Firestore Database (8 minutes)

- [ ] In Firebase Console sidebar, click "Build" → "Firestore Database"
- [ ] Click "Create database"
- [ ] Choose location: 
  - Recommended: **us-central1** (Iowa)
  - Alternative: Choose closest to you
  - **Decision**: Write down location: __________________
- [ ] Click "Next"
- [ ] Select "Start in **test mode**"
  - ⚠️ Note: This is insecure, we'll add rules in PR #5
  - Test mode allows: Read/write access for 30 days
- [ ] Click "Enable"
- [ ] Wait for database creation (~2-3 minutes)
- [ ] Verify you see empty database with "Start collection" button

**Checkpoint**: ✅ Firestore database created in test mode

---

### 1.6: Enable Firebase Storage (5 minutes)

- [ ] In Firebase Console sidebar, click "Build" → "Storage"
- [ ] Click "Get started"
- [ ] Review security rules: "Start in **test mode**"
  - ⚠️ Note: This is insecure, we'll add rules in PR #14
- [ ] Click "Next"
- [ ] Storage location: Should match Firestore location
  - Verify it says: **us-central1** (or your chosen location)
- [ ] Click "Done"
- [ ] Wait for storage setup (~30 seconds)
- [ ] Verify you see empty storage with folder icon

**Checkpoint**: ✅ Firebase Storage enabled

---

### 1.7: Verify Cloud Messaging (1 minute)

- [ ] In Firebase Console sidebar, click "Build" → "Cloud Messaging"
- [ ] You should see Cloud Messaging page
- [ ] **Note**: Full configuration in PR #17, just verify it exists
- [ ] No action needed now

**Checkpoint**: ✅ Cloud Messaging verified available

**Phase 1 Complete**: ✅ Firebase project fully configured (30 minutes)

**Commit** (optional checkpoint):
```bash
# Note: No code changes yet, but document your Firebase project details
echo "Firebase Project: MessageAI" >> firebase-setup-notes.txt
echo "Bundle ID: com.isaacjaramillo.messAI" >> firebase-setup-notes.txt
echo "Region: us-central1" >> firebase-setup-notes.txt
git add firebase-setup-notes.txt
git commit -m "[PR #1] Document Firebase project configuration"
```

---

## Phase 2: Xcode Project Configuration (30 minutes)

### 2.1: Update Project Settings (5 minutes)

- [ ] Open Xcode with messAI project
- [ ] In Project Navigator, click on **messAI** (blue project icon at top)
- [ ] In editor, ensure **messAI** target is selected (not the project)
- [ ] Click "General" tab
- [ ] Update settings:

**Identity:**
- [ ] Display Name: **MessageAI** (user-facing name)
- [ ] Bundle Identifier: `com.isaacjaramillo.messAI`
  - ⚠️ **Must match** what you entered in Firebase
  - Change if different

**Deployment:**
- [ ] Minimum Deployments → iOS: **16.0**
  - Change from default (likely 17.0)

**Version:**
- [ ] Version: **1.0** (keep default)
- [ ] Build: **1** (keep default)

**Checkpoint**: ✅ Project settings updated

---

### 2.2: Add GoogleService-Info.plist (5 minutes)

- [ ] In Finder, locate your Downloads folder
- [ ] Find `GoogleService-Info.plist`
- [ ] Drag file into Xcode Project Navigator
- [ ] **Important**: Drop it in the **messAI** folder (same level as messAIApp.swift)
- [ ] Dialog appears: "Choose options for adding these files"
  - [ ] ✅ Check: "Copy items if needed"
  - [ ] ✅ Check: "Create groups"
  - [ ] ✅ Check: "messAI" target is selected
- [ ] Click "Finish"
- [ ] Verify: `GoogleService-Info.plist` appears in Project Navigator under messAI folder

**Verify Contents:**
- [ ] Click on `GoogleService-Info.plist` in navigator
- [ ] Check it has keys like: `BUNDLE_ID`, `PROJECT_ID`, `API_KEY`, etc.
- [ ] Verify `BUNDLE_ID` matches your bundle identifier

**Checkpoint**: ✅ GoogleService-Info.plist added to project

---

### 2.3: Add Firebase SDK via Swift Package Manager (10 minutes)

- [ ] In Xcode menu: **File** → **Add Package Dependencies...**
- [ ] In search bar, paste: `https://github.com/firebase/firebase-ios-sdk`
- [ ] Press Return/Enter
- [ ] Wait for repository to load (~30 seconds)

**Configure Package:**
- [ ] Dependency Rule: **Up to Next Major Version**
- [ ] Version: Should show **10.0.0** (or latest)
- [ ] Click "Add Package"
- [ ] Wait for package resolution (~2-3 minutes)
  - ⚠️ This may take a while, be patient
  - You'll see "Resolving Package Graph..." at top

**Select Products:**
- [ ] In the products list, check these 4 packages:
  - [ ] ✅ **FirebaseAuth**
  - [ ] ✅ **FirebaseFirestore**
  - [ ] ✅ **FirebaseStorage**
  - [ ] ✅ **FirebaseMessaging**
- [ ] Verify target: **messAI** (should be selected for all)
- [ ] Click "Add Package"
- [ ] Wait for download and integration (~3-5 minutes)

**Verification:**
- [ ] After completion, check Project Navigator → messAI → Dependencies
- [ ] You should see: firebase-ios-sdk with 4 products listed
- [ ] Build project: **Cmd+B**
- [ ] Build should succeed (may have warnings, that's OK)

**Checkpoint**: ✅ Firebase SDK added via SPM

**If errors occur:**
- Try: File → Packages → Reset Package Caches
- Try: Close and reopen Xcode
- Try: Manually specify version 10.0.0

---

### 2.4: Configure Firebase in App (5 minutes)

- [ ] Open `messAI/messAIApp.swift` in editor
- [ ] Add import at top (after `import SwiftUI`):
  ```swift
  import FirebaseCore
  ```
- [ ] Add init() method inside the App struct (before `var body`):
  ```swift
  init() {
      FirebaseApp.configure()
  }
  ```

**Complete code should look like:**
```swift
import SwiftUI
import FirebaseCore

@main
struct messAIApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Verify:**
- [ ] No syntax errors (Xcode should show no red underlines)
- [ ] Build: **Cmd+B**
- [ ] Build succeeds

**Checkpoint**: ✅ Firebase configured in app entry point

---

### 2.5: Test Firebase Connection (5 minutes)

- [ ] Run app: **Cmd+R**
- [ ] App should launch on simulator
- [ ] Check Xcode Console (bottom panel, show if hidden)
- [ ] Look for Firebase initialization logs:
  ```
  [Firebase/Core][I-COR000003] The default Firebase app has been configured.
  ```
- [ ] If you see that log, Firebase is working! ✅
- [ ] If no log appears, check:
  - [ ] GoogleService-Info.plist is in project
  - [ ] FirebaseApp.configure() is in init()
  - [ ] Build succeeded without errors

**Optional: Firestore Write Test**
- [ ] Open `messAI/ContentView.swift`
- [ ] Add import at top:
  ```swift
  import FirebaseFirestore
  ```
- [ ] Replace body content with:
  ```swift
  var body: some View {
      VStack {
          Text("MessageAI")
              .font(.largeTitle)
          
          Button("Test Firebase Connection") {
              testFirebase()
          }
          .buttonStyle(.borderedProminent)
      }
      .padding()
  }
  
  func testFirebase() {
      let db = Firestore.firestore()
      db.collection("test").document("connection").setData([
          "message": "Firebase connected!",
          "timestamp": Date(),
          "source": "iOS App"
      ]) { error in
          if let error = error {
              print("❌ Error writing to Firestore: \(error.localizedDescription)")
          } else {
              print("✅ Successfully wrote to Firestore!")
          }
      }
  }
  ```
- [ ] Run app: **Cmd+R**
- [ ] Tap "Test Firebase Connection" button
- [ ] Check Xcode Console for: `✅ Successfully wrote to Firestore!`
- [ ] Open Firebase Console → Firestore Database
- [ ] Verify you see `test` collection with `connection` document
- [ ] If document appears, **Firebase is fully working!** 🎉

**Checkpoint**: ✅ Firebase connection tested and working

**Phase 2 Complete**: ✅ Xcode configured with Firebase (30 minutes)

**Commit**:
```bash
git add .
git commit -m "[PR #1] Configure Firebase in Xcode

- Added GoogleService-Info.plist
- Added Firebase SDK via SPM (Auth, Firestore, Storage, Messaging)
- Configured Firebase in messAIApp.swift
- Updated minimum iOS to 16.0
- Updated bundle identifier
- Tested Firebase connection successfully"
```

---

## Phase 3: Project Structure Setup (15 minutes)

### 3.1: Create Folder Structure (5 minutes)

**Create Main Folders:**
- [ ] In Xcode Project Navigator, right-click on **messAI** folder
- [ ] Select **New Group**
- [ ] Name it: **Models**
- [ ] Repeat for these folders (6 total):
  - [ ] **ViewModels**
  - [ ] **Views**
  - [ ] **Services**
  - [ ] **Persistence**
  - [ ] **Utilities**

**Create Views Subfolders:**
- [ ] Right-click on **Views** folder
- [ ] Select **New Group**
- [ ] Name it: **Auth**
- [ ] Repeat for these subfolders under Views (5 total):
  - [ ] **Chat**
  - [ ] **Contacts**
  - [ ] **Group**
  - [ ] **Profile**

**Verify Structure:**
```
messAI/
├── Models/
├── ViewModels/
├── Views/
│   ├── Auth/
│   ├── Chat/
│   ├── Contacts/
│   ├── Group/
│   └── Profile/
├── Services/
├── Persistence/
├── Utilities/
├── Assets.xcassets/
├── messAIApp.swift
├── ContentView.swift
└── GoogleService-Info.plist
```

**Checkpoint**: ✅ All folders created

---

### 3.2: Create Constants.swift (10 minutes)

- [ ] Right-click on **Utilities** folder
- [ ] Select **New File...**
- [ ] Choose **Swift File**
- [ ] Click "Next"
- [ ] Name: **Constants.swift**
- [ ] Group: Utilities (should be pre-selected)
- [ ] Target: messAI (should be checked)
- [ ] Click "Create"

**Add Content:**
- [ ] Delete the comment lines (keep header comment if you want)
- [ ] Copy the full Constants.swift code from `PR01_PROJECT_SETUP.md` (Phase 5)
- [ ] Or type this structure:

```swift
//
//  Constants.swift
//  messAI
//

import Foundation
import SwiftUI

/// App-wide constants for configuration and styling
struct Constants {
    
    // MARK: - App Configuration
    static let appName = "MessageAI"
    static let appVersion = "1.0.0"
    static let minimumIOSVersion = "16.0"
    
    // MARK: - Firebase Configuration
    struct Firestore {
        static let users = "users"
        static let conversations = "conversations"
        static let messages = "messages"
        static let presence = "presence"
        static let typingStatus = "typingStatus"
    }
    
    struct Storage {
        static let profilePictures = "profile_pictures"
        static let chatImages = "chat_images"
    }
    
    // MARK: - UI Constants
    struct Messages {
        static let maxTextLength = 10_000
        static let messageFetchLimit = 50
    }
    
    struct Images {
        static let maxImageSizeMB: Double = 2.0
        static let maxImageWidth: CGFloat = 1920
        static let thumbnailSize = CGSize(width: 200, height: 200)
        static let profileImageSize = CGSize(width: 200, height: 200)
    }
    
    struct Timing {
        static let typingIndicatorTimeout: TimeInterval = 3.0
        static let typingDebounceDelay: TimeInterval = 0.5
        static let messageRetryDelay: TimeInterval = 2.0
    }
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color.blue
        static let accent = Color.green
        static let sentMessage = Color.blue
        static let receivedMessage = Color.gray.opacity(0.2)
        static let onlineIndicator = Color.green
        static let offlineIndicator = Color.gray
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }
}
```

**Verify:**
- [ ] Build: **Cmd+B**
- [ ] No errors
- [ ] Constants.swift appears under Utilities folder

**Checkpoint**: ✅ Constants.swift created

**Phase 3 Complete**: ✅ Project structure established (15 minutes)

**Commit**:
```bash
git add .
git commit -m "[PR #1] Create project folder structure and constants

- Created MVVM folder structure (Models, ViewModels, Views, Services, Persistence, Utilities)
- Created Views subfolders (Auth, Chat, Contacts, Group, Profile)
- Added Constants.swift with app configuration values"
```

---

## Phase 4: Documentation (15 minutes)

### 4.1: Create README.md (15 minutes)

- [ ] In Xcode, right-click on project root (messAI folder at very top)
- [ ] Select **New File...**
- [ ] Scroll down and choose **Empty** file
- [ ] Click "Next"
- [ ] Name: **README.md**
- [ ] **Important**: Place in **project root** (not inside messAI folder)
- [ ] Save Location: Same level as messAI.xcodeproj
- [ ] Click "Create"

**Add Content:**
- [ ] Copy the full README.md content from `PR01_PROJECT_SETUP.md` (Phase 6)
- [ ] Save file: **Cmd+S**

**Verify:**
- [ ] README.md should appear at project root in Finder
- [ ] Check structure includes:
  - [ ] Project overview
  - [ ] Features list
  - [ ] Tech stack
  - [ ] Setup instructions
  - [ ] Firebase configuration steps
  - [ ] Installation guide
  - [ ] Project structure diagram
  - [ ] Architecture explanation
  - [ ] Roadmap

**View on GitHub (after push):**
- [ ] README will automatically display on repository homepage

**Checkpoint**: ✅ README.md created

**Phase 4 Complete**: ✅ Documentation added (15 minutes)

**Commit**:
```bash
git add README.md
git commit -m "[PR #1] Add comprehensive README with setup instructions"
```

---

## Phase 5: Testing & Verification (10 minutes)

### 5.1: Final Build Test (3 minutes)

- [ ] Clean build folder: **Product** → **Clean Build Folder** (Cmd+Shift+K)
- [ ] Build: **Product** → **Build** (Cmd+B)
- [ ] Build succeeds with 0 errors
- [ ] Note any warnings (minor warnings OK, but record them)

**Warnings (if any):**
- ____________________________________________
- ____________________________________________

**Checkpoint**: ✅ Clean build succeeds

---

### 5.2: Run on Simulator (3 minutes)

- [ ] Select simulator: iPhone 15 Pro (or latest available)
- [ ] Run: **Cmd+R**
- [ ] App launches successfully
- [ ] No crashes
- [ ] Test Firebase button works (if you added it)
- [ ] Check console for Firebase initialization log

**Checkpoint**: ✅ App runs on simulator

---

### 5.3: Configuration Checklist (4 minutes)

**Project Settings:**
- [ ] Minimum iOS: 16.0 ✓
- [ ] Bundle ID: com.isaacjaramillo.messAI ✓
- [ ] Display Name: MessageAI ✓
- [ ] Version: 1.0 ✓

**Firebase:**
- [ ] GoogleService-Info.plist in project ✓
- [ ] Firebase SDK packages installed ✓
- [ ] Firebase configured in app ✓
- [ ] Firestore connection tested ✓

**Project Structure:**
- [ ] All 6 main folders created ✓
- [ ] All 5 Views subfolders created ✓
- [ ] Constants.swift exists ✓
- [ ] README.md exists ✓

**Checkpoint**: ✅ All verification complete

**Phase 5 Complete**: ✅ Testing passed (10 minutes)

---

## Phase 6: Git Finalization (5 minutes)

### 6.1: Review Changes (2 minutes)

- [ ] Check git status:
  ```bash
  git status
  ```
- [ ] Review what changed:
  ```bash
  git diff
  ```
- [ ] Verify GoogleService-Info.plist is **NOT** in staged files
  - It should be ignored by .gitignore
  - Check: `git status` should NOT show GoogleService-Info.plist

**Checkpoint**: ✅ Changes reviewed

---

### 6.2: Final Commit (3 minutes)

- [ ] Stage all changes:
  ```bash
  git add .
  ```
- [ ] Commit with comprehensive message:
  ```bash
  git commit -m "[PR #1] Complete project setup and Firebase integration

## Summary
- Configured Firebase project (Auth, Firestore, Storage, Messaging)
- Integrated Firebase SDK via Swift Package Manager
- Set minimum iOS to 16.0
- Created MVVM folder structure
- Added Constants.swift with app configuration
- Created comprehensive README

## Firebase Setup
- Project: MessageAI
- Bundle ID: com.isaacjaramillo.messAI
- Region: us-central1
- Services: Auth (Email/Password), Firestore (test mode), Storage (test mode)

## Testing
- ✅ Firebase initialization successful
- ✅ Firestore connection tested
- ✅ App builds and runs without errors
- ✅ All folder structure created

## Files Added
- GoogleService-Info.plist (gitignored)
- Utilities/Constants.swift
- README.md
- Project structure (11 folders)

## Next Steps
- PR #2: Authentication services
- PR #3: Authentication UI"
  ```
- [ ] Push to GitHub:
  ```bash
  git push -u origin feature/project-setup
  ```

**Checkpoint**: ✅ Changes committed and pushed

**Phase 6 Complete**: ✅ Git finalized (5 minutes)

---

## Completion Checklist

### All Phases Complete
- [ ] Phase 1: Firebase project created (30 min)
- [ ] Phase 2: Xcode configured (30 min)
- [ ] Phase 3: Project structure created (15 min)
- [ ] Phase 4: Documentation added (15 min)
- [ ] Phase 5: Testing passed (10 min)
- [ ] Phase 6: Git finalized (5 min)

### All Success Criteria Met
- [ ] Firebase project configured
- [ ] All services enabled
- [ ] Firebase SDK integrated
- [ ] App builds successfully
- [ ] App runs without crashes
- [ ] Firebase connection verified
- [ ] Folder structure complete
- [ ] Constants.swift created
- [ ] README.md created
- [ ] All tests passing
- [ ] Changes committed
- [ ] Changes pushed to GitHub

### Post-Completion Tasks
- [ ] Update `PR_PARTY/README.md` (mark PR #1 as complete)
- [ ] Update `memory-bank/activeContext.md` (document completion)
- [ ] Update `memory-bank/progress.md` (update progress tracking)
- [ ] Create PR #1 complete summary document (optional but recommended)
- [ ] Merge feature branch to main:
  ```bash
  git checkout main
  git merge feature/project-setup
  git push origin main
  ```
- [ ] Celebrate! 🎉

---

## Time Tracking

**Estimated**: 1-2 hours  
**Actual**: ________ hours

**Breakdown**:
- Firebase setup: ________ minutes
- Xcode config: ________ minutes
- Structure: ________ minutes
- Documentation: ________ minutes
- Testing: ________ minutes
- Git: ________ minutes

**Notes**: (Any observations about what took longer/shorter than expected)

---

## Issues Encountered

**Issue 1**: (If any)
- **Problem**: 
- **Solution**: 
- **Time Lost**: 

**Issue 2**: (If any)
- **Problem**: 
- **Solution**: 
- **Time Lost**: 

---

**Status**: ⏳ READY TO IMPLEMENT  
**Next**: Begin Phase 1 - Firebase Project Creation  

**Remember**: Follow this checklist step-by-step. Check off each item as you complete it. Test after each phase. Commit frequently. You've got this! 💪

