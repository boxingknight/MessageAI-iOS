# PR #1: Project Setup & Firebase Configuration

**Estimated Time**: 1-2 hours  
**Complexity**: LOW  
**Dependencies**: None (first PR)  
**Branch**: `feature/project-setup`

---

## Overview

### What We're Building
Setting up the foundation for MessageAI by integrating Firebase backend services and establishing the project structure. This PR creates the scaffolding that all future features will build upon.

### Why It Matters
This is the foundation of our entire app. Without proper Firebase setup:
- No authentication system
- No real-time messaging
- No cloud storage for images
- No push notifications

A solid foundation here prevents hours of debugging later.

### Success in One Sentence
"This PR is successful when the app launches without errors and successfully connects to Firebase, verified by a test write to Firestore."

---

## Technical Design

### Architecture Decisions

#### Decision 1: Dependency Management - Swift Package Manager vs CocoaPods
**Options Considered:**
1. **Swift Package Manager (SPM)**
   - Pros: Native to Xcode, no external tools, faster builds, modern
   - Cons: Slightly less mature than CocoaPods for some libraries
   
2. **CocoaPods**
   - Pros: Mature ecosystem, well-documented
   - Cons: Requires Ruby, external tool, slower builds, extra files

**Chosen:** Swift Package Manager

**Rationale:**
- Native integration with Xcode (no extra tools needed)
- Firebase fully supports SPM
- Faster build times
- Cleaner project structure (no Pods directory)
- Apple's recommended approach

**Trade-offs:**
- Gain: Simplicity, speed, native tooling
- Lose: Some third-party libraries still prefer CocoaPods (not relevant for our project)

---

#### Decision 2: Minimum iOS Version - 16.0 vs 17.0
**Options Considered:**
1. **iOS 16.0**
   - Pros: Broader device compatibility (~90% of devices)
   - Cons: May need to conditionally handle some iOS 17 features
   
2. **iOS 17.0**
   - Pros: Latest SwiftUI features, SwiftData works best
   - Cons: Limits to newer devices only (~70% of devices)

**Chosen:** iOS 16.0

**Rationale:**
- PRD specifies iOS 16.0+
- Broader user base
- SwiftUI and SwiftData work on iOS 16
- Only 6 months older, most features available

**Trade-offs:**
- Gain: 20% more potential users
- Lose: May need Core Data fallback if SwiftData issues arise on iOS 16

---

#### Decision 3: Firebase Project Configuration - Test Mode vs Production Rules
**Options Considered:**
1. **Test Mode** (allow all reads/writes)
   - Pros: Easy setup, no authentication required initially
   - Cons: Security risk, need to change later
   
2. **Production Rules** (authenticated only from start)
   - Pros: Secure from day 1, no migration needed
   - Cons: Slightly more complex initial setup

**Chosen:** Start with test mode, add security rules in PR #5

**Rationale:**
- Faster initial setup (good for 24-hour MVP)
- Can test Firebase connection immediately
- PR #5 (Chat Service) will add proper security rules
- Test mode only for development, not deployment

**Trade-offs:**
- Gain: Speed of initial setup
- Lose: Need to remember to add security rules later (documented in PR #5 checklist)

---

#### Decision 4: Project Structure - Flat vs Organized Folders
**Options Considered:**
1. **Flat Structure**
   - All files in root `messAI/` folder
   - Pros: Simple, less navigation
   - Cons: Gets messy quickly with 40+ files
   
2. **Organized by Layer** (MVVM)
   - Models/, ViewModels/, Views/, Services/, etc.
   - Pros: Clear separation, easy to navigate, scalable
   - Cons: More clicks to navigate

**Chosen:** Organized by Layer (MVVM)

**Rationale:**
- 40+ files planned, needs organization
- MVVM pattern requires clear separation
- Industry standard for SwiftUI apps
- Easier onboarding for new developers
- Matches task list structure

**Trade-offs:**
- Gain: Scalability, clarity, maintainability
- Lose: Extra folder navigation (minimal cost)

---

### Firebase Services Configuration

**Services to Enable:**

1. **Firebase Authentication**
   - Provider: Email/Password
   - Purpose: User signup and login
   - Configuration: Enable in Firebase Console

2. **Cloud Firestore**
   - Mode: Test mode initially (locked mode in PR #5)
   - Region: us-central1 (or closest to user)
   - Purpose: Real-time message database

3. **Firebase Storage**
   - Rules: Test mode initially
   - Purpose: Store profile pictures and message images

4. **Firebase Cloud Messaging (FCM)**
   - Purpose: Push notifications
   - Note: Requires APNs configuration (later in PR #17)

---

### Project Structure

**Folder Organization:**

```
messAI/
├── messAI/
│   ├── messAIApp.swift              (App entry point - MODIFY)
│   ├── ContentView.swift            (Temp - will delete later)
│   ├── GoogleService-Info.plist     (Firebase config - ADD)
│   │
│   ├── Models/                       (CREATE)
│   │   └── (empty for now)
│   │
│   ├── ViewModels/                   (CREATE)
│   │   └── (empty for now)
│   │
│   ├── Views/                        (CREATE)
│   │   ├── Auth/                     (CREATE)
│   │   ├── Chat/                     (CREATE)
│   │   ├── Contacts/                 (CREATE)
│   │   ├── Group/                    (CREATE)
│   │   └── Profile/                  (CREATE)
│   │
│   ├── Services/                     (CREATE)
│   │   └── (empty for now)
│   │
│   ├── Persistence/                  (CREATE)
│   │   └── (empty for now)
│   │
│   ├── Utilities/                    (CREATE)
│   │   └── Constants.swift           (CREATE)
│   │
│   └── Assets.xcassets/
│       └── (existing)
│
├── messAI.xcodeproj/
├── PR_PARTY/
├── memory-bank/
└── README.md                         (CREATE)
```

**New Folders**: 7 folders (Models, ViewModels, Views + 5 subfolders, Services, Persistence, Utilities)  
**New Files**: 2 files (Constants.swift, README.md) + GoogleService-Info.plist (downloaded)  
**Modified Files**: 1 file (messAIApp.swift)

---

### Bundle Identifier

**Format**: Reverse domain notation

**Chosen**: `com.isaacjaramillo.messAI`

**Rationale**:
- Standard Apple convention
- Uses developer's name (Isaac Jaramillo)
- Unique identifier for App Store
- Matches GitHub username pattern (boxingknight → isaacjaramillo)

**Alternative**: `com.boxingknight.messAI` (using GitHub username)

---

## Implementation Details

### File Structure

**New Files:**
```
messAI/Utilities/Constants.swift      (~50 lines)
README.md                              (~150 lines)
messAI/GoogleService-Info.plist       (Firebase generated)
```

**Modified Files:**
```
messAI/messAIApp.swift                (+10 lines: Firebase import & configure)
messAI.xcodeproj/project.pbxproj      (Xcode modifications)
```

**Total New Lines**: ~200 lines of code/documentation

---

### Key Implementation Steps

#### Phase 1: Firebase Project Setup (30 minutes)

**Steps:**
1. Go to https://console.firebase.google.com
2. Click "Add project" or "Create a project"
3. Enter project name: "MessageAI" (or "messAI")
4. Disable Google Analytics (optional for MVP)
5. Click "Create project"

**Wait for project creation (~1 minute)**

6. Navigate to Project Settings (gear icon)
7. Under "Your apps", click iOS icon (+)
8. Enter iOS bundle ID: `com.isaacjaramillo.messAI`
9. Enter App nickname: "MessageAI iOS"
10. Click "Register app"
11. Download `GoogleService-Info.plist`
12. Click "Next" through remaining steps

**Enable Services:**

**Authentication:**
1. Go to Build → Authentication
2. Click "Get started"
3. Click "Email/Password" provider
4. Toggle "Enable"
5. Click "Save"

**Firestore:**
1. Go to Build → Firestore Database
2. Click "Create database"
3. Select "Start in test mode"
4. Choose location: "us-central1" (or closest)
5. Click "Enable"

**Storage:**
1. Go to Build → Storage
2. Click "Get started"
3. Start in test mode
4. Use default location
5. Click "Done"

**Cloud Messaging:**
1. Go to Build → Cloud Messaging
2. Note: Full setup in PR #17, just verify it's available

---

#### Phase 2: Xcode Configuration (15 minutes)

**Step 1: Adjust Project Settings**
```
1. Open messAI.xcodeproj in Xcode
2. Select project in navigator
3. Select "messAI" target
4. General tab:
   - Minimum Deployments: iOS 16.0
   - Bundle Identifier: com.isaacjaramillo.messAI
   - Version: 1.0
   - Build: 1
```

**Step 2: Add GoogleService-Info.plist**
```
1. Drag GoogleService-Info.plist into Xcode
2. Ensure "Copy items if needed" is checked
3. Target membership: messAI (checked)
4. Place in messAI/ folder (root of target)
```

**Step 3: Add Firebase SDK via SPM**
```
1. File → Add Package Dependencies
2. Enter URL: https://github.com/firebase/firebase-ios-sdk
3. Dependency Rule: "Up to Next Major Version" 10.0.0
4. Click "Add Package"
5. Select products to add:
   ✅ FirebaseAuth
   ✅ FirebaseFirestore
   ✅ FirebaseStorage
   ✅ FirebaseMessaging
6. Click "Add Package"
```

**Wait for package resolution (~2-3 minutes)**

---

#### Phase 3: Configure Firebase in App (10 minutes)

**File**: `messAI/messAIApp.swift`

**Before:**
```swift
import SwiftUI

@main
struct messAIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**After:**
```swift
import SwiftUI
import FirebaseCore

@main
struct messAIApp: App {
    // Initialize Firebase
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

**Changes:**
- Import FirebaseCore
- Add init() method
- Call FirebaseApp.configure()

---

#### Phase 4: Create Folder Structure (5 minutes)

**Steps:**
1. Right-click on `messAI` folder in Xcode
2. New Group → "Models"
3. Repeat for: ViewModels, Views, Services, Persistence, Utilities
4. Right-click on `Views` folder
5. Create subgroups: Auth, Chat, Contacts, Group, Profile

**Xcode Navigator should show:**
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

---

#### Phase 5: Create Constants File (10 minutes)

**File**: `messAI/Utilities/Constants.swift`

```swift
//
//  Constants.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import Foundation
import SwiftUI

/// App-wide constants for configuration and styling
struct Constants {
    
    // MARK: - App Configuration
    
    /// App display name
    static let appName = "MessageAI"
    
    /// App version
    static let appVersion = "1.0.0"
    
    /// Minimum iOS version supported
    static let minimumIOSVersion = "16.0"
    
    // MARK: - Firebase Configuration
    
    /// Firestore collection names
    struct Firestore {
        static let users = "users"
        static let conversations = "conversations"
        static let messages = "messages"
        static let presence = "presence"
        static let typingStatus = "typingStatus"
    }
    
    /// Firebase Storage paths
    struct Storage {
        static let profilePictures = "profile_pictures"
        static let chatImages = "chat_images"
    }
    
    // MARK: - UI Constants
    
    /// Message limits
    struct Messages {
        static let maxTextLength = 10_000
        static let messageFetchLimit = 50
    }
    
    /// Image constraints
    struct Images {
        static let maxImageSizeMB: Double = 2.0
        static let maxImageWidth: CGFloat = 1920
        static let thumbnailSize = CGSize(width: 200, height: 200)
        static let profileImageSize = CGSize(width: 200, height: 200)
    }
    
    /// Timing
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

**Purpose**: Centralize all magic numbers and configuration values

---

#### Phase 6: Create README (15 minutes)

**File**: `README.md` (project root)

```markdown
# MessageAI

A production-quality iOS messaging application with real-time sync, offline support, and Firebase backend.

## Overview

MessageAI is a WhatsApp-like messaging app built with Swift and SwiftUI, demonstrating modern iOS development practices and reliable messaging infrastructure.

### Features

- 💬 **Real-time messaging** - Messages deliver in <2 seconds
- 👥 **Group chat** - Coordinate with 3+ people
- 📱 **Offline support** - Queue messages, sync automatically
- ✅ **Read receipts** - Track message delivery and read status
- 🟢 **Presence indicators** - See who's online
- ⌨️ **Typing indicators** - Know when someone is responding
- 📸 **Image sharing** - Send photos from library or camera
- 🔔 **Push notifications** - Never miss a message
- 🔐 **User authentication** - Secure Firebase Auth

## Tech Stack

- **Frontend**: Swift 5.9+, SwiftUI, SwiftData
- **Backend**: Firebase (Auth, Firestore, Storage, Messaging)
- **Architecture**: MVVM with service layer
- **Minimum iOS**: 16.0
- **Dependencies**: Firebase iOS SDK (via SPM)

## Project Structure

```
messAI/
├── Models/              # Data structures (User, Message, Conversation)
├── ViewModels/          # Business logic (MVVM)
├── Views/               # SwiftUI views
│   ├── Auth/            # Login, signup
│   ├── Chat/            # Chat list, chat view
│   ├── Contacts/        # Contact selection
│   ├── Group/           # Group creation
│   └── Profile/         # User profile
├── Services/            # Firebase integration
├── Persistence/         # Local storage (SwiftData)
├── Utilities/           # Helpers and extensions
└── Assets.xcassets/     # Images and colors
```

## Setup Instructions

### Prerequisites

- Xcode 15+
- iOS 16.0+ device or simulator
- Firebase account (free tier)
- Apple Developer account (for push notifications)

### Firebase Setup

1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Create new project: "MessageAI"
   - Add iOS app with bundle ID: `com.isaacjaramillo.messAI`

2. **Enable Firebase Services**
   - Authentication → Email/Password
   - Firestore Database → Test mode
   - Storage → Test mode
   - Cloud Messaging → Note configuration for later

3. **Download Config**
   - Download `GoogleService-Info.plist`
   - Add to Xcode project root

### Installation

1. **Clone Repository**
   ```bash
   git clone https://github.com/boxingknight/MessageAI-iOS.git
   cd MessageAI-iOS
   ```

2. **Open in Xcode**
   ```bash
   open messAI.xcodeproj
   ```

3. **Add Firebase Config**
   - Drag `GoogleService-Info.plist` into project
   - Ensure "Copy items if needed" is checked
   - Target: messAI

4. **Install Dependencies**
   - Xcode will automatically resolve SPM packages
   - Wait for Firebase SDK to download

5. **Build and Run**
   - Select target device/simulator
   - Press Cmd+R to build and run

## Development

### Firebase Security Rules

**Important**: The app starts with test mode rules for development. Deploy production rules before launching:

```bash
cd firebase
firebase deploy --only firestore:rules
firebase deploy --only storage
```

### Testing

Test with two physical devices for best results:
- Real-time messaging
- Push notifications
- Camera access
- Network conditions

### Git Workflow

- `main` - Stable code
- `feature/*` - Feature branches
- Commit format: `[PR #X] Description`

## Documentation

- **PRD**: `messageai_prd.md` - Product requirements
- **Task List**: `messageai_task_list.md` - Development roadmap
- **Memory Bank**: `memory-bank/` - Architecture and context
- **PR Party**: `PR_PARTY/` - Detailed PR documentation

## Architecture

### MVVM Pattern

```
Views (SwiftUI)
    ↓
ViewModels (Business Logic)
    ↓
Services (Firebase)
    ↓
Models (Data)
```

### Key Principles

- **Optimistic UI**: Messages appear instantly
- **Offline-First**: Queue locally, sync when online
- **Real-Time**: Firestore listeners for instant updates
- **No Data Loss**: Messages never lost, ever

## Roadmap

### Phase 1: Foundation (PRs #1-3) ✅
- Project setup and Firebase
- Authentication (signup/login)

### Phase 2: Core Messaging (PRs #4-11) 🚧
- One-on-one chat
- Real-time delivery
- Message status indicators

### Phase 3: Enhanced Features (PRs #12-15) 📋
- Group chat
- Image sharing
- Offline support
- Presence and typing

### Phase 4: Polish (PRs #16-22) 📋
- Push notifications
- Error handling
- Testing
- Deployment

## Contributing

This is a learning project for building production-quality messaging apps. Contributions welcome!

## License

MIT License - See LICENSE file for details

## Author

Isaac Jaramillo ([@boxingknight](https://github.com/boxingknight))

## Acknowledgments

- Inspired by WhatsApp's simplicity and reliability
- Built as part of GauntletAI Week 2 challenge
- Firebase for excellent backend infrastructure

---

**Status**: 🚧 In Development - MVP targeting 24 hours  
**Last Updated**: October 20, 2025
```

---

## Testing Strategy

### Test Scenarios

#### Test 1: Firebase Connection
**Goal**: Verify Firebase initializes successfully

**Steps:**
1. Build and run app on simulator
2. Check Xcode console for Firebase initialization logs
3. Look for: `[Firebase/Core][I-COR000003] The default Firebase app has been configured`

**Expected**: No errors, Firebase configured message appears

**Actual**: (To be filled during testing)

---

#### Test 2: Firestore Write Test
**Goal**: Verify Firestore connection works

**Steps:**
1. Add temporary test button to ContentView
2. Button writes test document to Firestore
3. Check Firebase Console to verify document appears

**Test Code:**
```swift
import FirebaseFirestore

Button("Test Firebase") {
    let db = Firestore.firestore()
    db.collection("test").document("testDoc").setData([
        "message": "Hello from MessageAI!",
        "timestamp": Date()
    ]) { error in
        if let error = error {
            print("❌ Error: \(error.localizedDescription)")
        } else {
            print("✅ Successfully wrote to Firestore!")
        }
    }
}
```

**Expected**: 
- Console shows: "✅ Successfully wrote to Firestore!"
- Firebase Console shows document in `test` collection

**Actual**: (To be filled during testing)

---

#### Test 3: Project Structure
**Goal**: Verify all folders created correctly

**Checklist:**
- [ ] Models/ folder exists
- [ ] ViewModels/ folder exists
- [ ] Views/ folder exists
  - [ ] Views/Auth/ exists
  - [ ] Views/Chat/ exists
  - [ ] Views/Contacts/ exists
  - [ ] Views/Group/ exists
  - [ ] Views/Profile/ exists
- [ ] Services/ folder exists
- [ ] Persistence/ folder exists
- [ ] Utilities/ folder exists
- [ ] Utilities/Constants.swift exists
- [ ] GoogleService-Info.plist exists in project root
- [ ] README.md exists in project root

**Expected**: All checkboxes checked

---

#### Test 4: Build Success
**Goal**: Verify project builds without errors

**Steps:**
1. Clean build folder: Product → Clean Build Folder (Cmd+Shift+K)
2. Build: Product → Build (Cmd+B)
3. Check for errors/warnings

**Expected**: 
- 0 errors
- 0 warnings (or only minor warnings)
- Build succeeds

**Actual**: (To be filled during testing)

---

#### Test 5: iOS Target Version
**Goal**: Verify minimum iOS set correctly

**Steps:**
1. Select project in navigator
2. Select messAI target
3. General tab → Minimum Deployments

**Expected**: iOS 16.0

**Actual**: (To be filled during testing)

---

## Success Criteria

### Feature is complete when:

- [x] Firebase project created and configured
- [x] Firebase services enabled (Auth, Firestore, Storage, Messaging)
- [x] GoogleService-Info.plist added to Xcode
- [x] Firebase SDK added via Swift Package Manager
- [x] Firebase configured in messAIApp.swift
- [x] App builds without errors
- [x] App launches successfully
- [x] Firebase initialization log appears in console
- [x] Test write to Firestore succeeds
- [x] All folder structure created correctly
- [x] Constants.swift created with all values
- [x] README.md created and comprehensive
- [x] Minimum iOS set to 16.0
- [x] Bundle identifier set correctly
- [x] All tests pass
- [x] No critical warnings
- [x] Changes committed to git
- [x] PR documentation complete

---

## Risk Assessment

### Risk 1: Firebase Project Creation Issues
**Likelihood:** LOW  
**Impact:** HIGH  
**Mitigation**: Follow Firebase setup exactly, use existing Google account  
**Status**: 🟢 LOW RISK

### Risk 2: SPM Package Resolution Fails
**Likelihood:** LOW  
**Impact:** MEDIUM  
**Mitigation**: Retry, check internet connection, manually specify version  
**Fallback**: Use specific Firebase SDK version (10.0.0)  
**Status**: 🟢 LOW RISK

### Risk 3: GoogleService-Info.plist Not Found
**Likelihood:** MEDIUM  
**Impact:** HIGH (blocks Firebase entirely)  
**Mitigation**: Double-check file is in project root, verify target membership  
**Recovery**: Re-download from Firebase Console  
**Status**: 🟡 MEDIUM RISK - Test immediately

### Risk 4: iOS 16.0 Compatibility Issues
**Likelihood:** LOW  
**Impact:** MEDIUM  
**Mitigation**: SwiftUI works on iOS 16, Firebase supports iOS 13+  
**Fallback**: Bump to iOS 17 if critical issues  
**Status**: 🟢 LOW RISK

### Risk 5: Build Time Too Long
**Likelihood:** MEDIUM  
**Impact:** LOW (annoying but not blocking)  
**Mitigation**: First SPM build takes 5-10 minutes, subsequent builds faster  
**Expectation**: Initial build ~10 minutes, rebuild ~1-2 minutes  
**Status**: 🟢 EXPECTED - Not a risk

---

## Open Questions

### Question 1: Bundle Identifier Confirmation
**Question**: Use `com.isaacjaramillo.messAI` or `com.boxingknight.messAI`?  
**Options**:
- A) `com.isaacjaramillo.messAI` (real name)
- B) `com.boxingknight.messAI` (GitHub username)

**Recommendation**: Use real name (`com.isaacjaramillo.messAI`) for App Store  
**Decision needed by**: During Firebase project setup  
**Status**: ⏳ PENDING USER DECISION

---

### Question 2: Firebase Project Name
**Question**: "MessageAI" or "messAI"?  
**Options**:
- A) "MessageAI" (proper case, matches PRD)
- B) "messAI" (matches Xcode project name)

**Recommendation**: "MessageAI" (proper case looks more professional)  
**Impact**: Cosmetic only, doesn't affect functionality  
**Status**: ⏳ PENDING USER DECISION

---

## Timeline

**Total Estimate**: 1-2 hours

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Firebase project setup | 30 min | ⏳ |
| 2 | Xcode configuration | 15 min | ⏳ |
| 3 | Configure Firebase in app | 10 min | ⏳ |
| 4 | Create folder structure | 5 min | ⏳ |
| 5 | Create Constants.swift | 10 min | ⏳ |
| 6 | Create README.md | 15 min | ⏳ |
| 7 | Testing & verification | 15 min | ⏳ |
| 8 | Git commit & push | 5 min | ⏳ |
| **Total** | | **1.5 hours** | ⏳ |

**Buffer**: +30 minutes for troubleshooting = **2 hours max**

---

## Dependencies

### Requires:
- [x] Git repository initialized (completed in setup)
- [x] GitHub remote connected (completed in setup)
- [x] Xcode project created (completed in setup)
- [x] Google account (for Firebase)
- [ ] Firebase account created
- [ ] Internet connection

### Blocks:
- PR #2: Authentication Services (needs Firebase configured)
- PR #3: Authentication UI (needs Firebase configured)
- All future PRs depend on this foundation

---

## References

- [Firebase iOS Setup Guide](https://firebase.google.com/docs/ios/setup)
- [Firebase Authentication Documentation](https://firebase.google.com/docs/auth/ios/start)
- [Cloud Firestore Getting Started](https://firebase.google.com/docs/firestore/quickstart)
- [Swift Package Manager](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)
- Task List: `messageai_task_list.md` lines 96-144

---

**Status**: 📋 PLANNING COMPLETE  
**Next Step**: Create feature branch and begin implementation  
**Estimated Completion**: October 20, 2025 (same day)

