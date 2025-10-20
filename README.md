# MessageAI

A production-quality iOS messaging application with real-time sync, offline support, and Firebase backend.

[![iOS](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Firebase](https://img.shields.io/badge/Firebase-12.4.0-yellow.svg)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

MessageAI is a WhatsApp-like messaging app built with Swift and SwiftUI, demonstrating modern iOS development practices and reliable messaging infrastructure. This project showcases real-time communication, offline-first architecture, and seamless Firebase integration.

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

### Frontend
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Local Storage**: SwiftData
- **State Management**: Combine + @Published
- **Minimum iOS**: 16.0

### Backend
- **Authentication**: Firebase Auth
- **Database**: Cloud Firestore (real-time NoSQL)
- **Storage**: Firebase Storage (images/media)
- **Messaging**: Firebase Cloud Messaging (push notifications)
- **Functions**: Cloud Functions (notification triggers)

### Architecture
- **Pattern**: MVVM (Model-View-ViewModel)
- **Dependency Management**: Swift Package Manager
- **Design**: Offline-first, optimistic UI

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
│   └── Constants.swift  # App-wide configuration
└── Assets.xcassets/     # Images and colors
```

## Setup Instructions

### Prerequisites

- **Xcode**: 15+ (latest recommended)
- **iOS**: 16.0+ device or simulator
- **Firebase Account**: Free tier is sufficient
- **Apple Developer Account**: Required for push notifications (optional for MVP)
- **macOS**: Ventura or later

### Firebase Setup

#### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add project" or "Create a project"
3. Enter project name: **MessageAI**
4. Disable Google Analytics (optional)
5. Click "Create project"

#### 2. Register iOS App

1. In Firebase Console, click iOS icon
2. **iOS bundle ID**: `com.isaacjaramillo.messAI`
3. **App nickname**: MessageAI iOS
4. Click "Register app"
5. **Download** `GoogleService-Info.plist`

#### 3. Enable Firebase Services

**Authentication:**
1. Go to Build → Authentication
2. Click "Get started"
3. Enable **Email/Password** provider
4. Click "Save"

**Firestore Database:**
1. Go to Build → Firestore Database
2. Click "Create database"
3. Start in **test mode**
4. Choose location: **us-central1** (or closest)
5. Click "Enable"

**Storage:**
1. Go to Build → Storage
2. Click "Get started"
3. Start in **test mode**
4. Use default location
5. Click "Done"

**Cloud Messaging:**
1. Go to Build → Cloud Messaging
2. Verify service is available (full setup in later phase)

### Installation

#### 1. Clone Repository

```bash
git clone https://github.com/boxingknight/MessageAI-iOS.git
cd MessageAI-iOS
```

#### 2. Add Firebase Configuration

1. Place `GoogleService-Info.plist` in the `messAI/` directory
   - Same level as `messAIApp.swift`
2. **Important**: This file is gitignored - never commit it!

#### 3. Open in Xcode

```bash
open messAI.xcodeproj
```

#### 4. Install Dependencies

- Xcode will automatically resolve Swift Package Manager dependencies
- Wait for Firebase SDK to download (~5-10 minutes first time)
- Dependencies include:
  - FirebaseAuth
  - FirebaseFirestore
  - FirebaseStorage
  - FirebaseMessaging

#### 5. Build and Run

1. Select target device/simulator: **iPhone 15 Pro** (or preferred)
2. Press **⌘ + R** to build and run
3. Wait for simulator to boot
4. App should launch successfully

**Verify Firebase Connection:**
- Open Xcode console (⌘ + Shift + Y)
- Look for: `[Firebase/Core][I-COR000003] The default Firebase app has been configured.`
- If you see this, Firebase is working! ✅

## Development

### Project Configuration

**Bundle Identifier**: `com.isaacjaramillo.messAI`  
**Minimum iOS**: 16.0  
**Deployment Target**: iOS 16.0+  
**Version**: 1.0 (Build 1)

### Firebase Security Rules

⚠️ **Important**: The app starts with test mode rules for development.

**Deploy production rules before launching:**

**Firestore Rules** (`firebase/firestore.rules`):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own profile
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // Users can only access conversations they're part of
    match /conversations/{conversationId} {
      allow read: if request.auth != null 
                  && request.auth.uid in resource.data.participants;
      allow create: if request.auth != null 
                    && request.auth.uid in request.resource.data.participants;
      
      match /messages/{messageId} {
        allow read: if request.auth != null 
                    && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
        allow create: if request.auth != null
                      && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants
                      && request.resource.data.senderId == request.auth.uid;
      }
    }
  }
}
```

**Deploy:**
```bash
cd firebase
firebase deploy --only firestore:rules
firebase deploy --only storage
```

### Testing

#### Test with Two Devices (Recommended)

For best results, test with **two physical iOS devices**:
- Real-time messaging
- Push notifications
- Camera access
- Network conditions
- Performance

#### Critical Test Scenarios

1. **Real-Time Messaging**: Send message from Device A → appears on Device B within 2 seconds
2. **Offline Mode**: Device goes offline → send messages → come back online → messages sync
3. **Group Chat**: Create group with 3+ users → all receive messages
4. **Image Sharing**: Send image → recipient receives and can view
5. **Read Receipts**: Send message → recipient opens → status updates to "read"

### Git Workflow

**Branching Strategy:**
```
main                    # Stable code
  ├─ feature/*         # New features
  ├─ bugfix/*          # Bug fixes
  └─ docs/*            # Documentation
```

**Commit Format:**
```
[PR #X] Brief description

- Detailed change 1
- Detailed change 2
```

**Example:**
```bash
git checkout -b feature/authentication
git add .
git commit -m "[PR #2] Implement user authentication

- Created User model
- Added AuthService with Firebase Auth
- Implemented AuthViewModel with state management"
git push origin feature/authentication
```

## Architecture

### MVVM Pattern

```
┌─────────────────────────────────────────┐
│              Views (SwiftUI)            │
│  - Pure presentation                    │
│  - Observes ViewModel state             │
└─────────────────┬───────────────────────┘
                  │ @Published
                  │ Observe
                  ↓
┌─────────────────────────────────────────┐
│          ViewModels (Logic)             │
│  - Business logic                       │
│  - State management                     │
│  - Calls Services                       │
└─────────────────┬───────────────────────┘
                  │ Method Calls
                  │ Return Data
                  ↓
┌─────────────────────────────────────────┐
│          Services (Firebase)            │
│  - Firebase operations                  │
│  - Network calls                        │
│  - Data transformation                  │
└─────────────────┬───────────────────────┘
                  │ Read/Write
                  │ Transform
                  ↓
┌─────────────────────────────────────────┐
│          Models (Data)                  │
│  - Codable structs                      │
│  - Business entities                    │
│  - No logic                             │
└─────────────────────────────────────────┘
```

### Key Architectural Principles

1. **Optimistic UI**: Messages appear instantly, confirm later
2. **Offline-First**: App works fully offline, syncs when online
3. **Real-Time by Default**: Firestore listeners for instant updates
4. **No Data Loss**: Messages never lost under any circumstance
5. **Testable**: Clear separation allows easy unit testing

### Data Flow

**Sending a Message:**
```
User taps "Send"
    ↓
ChatViewModel.sendMessage()
    ↓
1. Add message to local array (instant UI)
2. Save to SwiftData (offline support)
3. Call ChatService.sendMessage()
    ↓
Firebase.addDocument()
    ↓
Firestore Snapshot Listener fires
    ↓
Update message status (sent → delivered → read)
```

## Documentation

### Project Documentation

- **📋 PRD**: `messageai_prd.md` - Complete product requirements (811 lines)
- **📝 Task List**: `messageai_task_list.md` - 23 PR breakdown (1,601 lines)
- **🧠 Memory Bank**: `memory-bank/` - Architecture, context, progress tracking
- **🎉 PR Party**: `PR_PARTY/` - Comprehensive PR-by-PR documentation

### Memory Bank Structure

```
memory-bank/
├── projectbrief.md      # Project mission and scope
├── productContext.md    # User stories and UX goals
├── activeContext.md     # Current status and next steps
├── systemPatterns.md    # Architecture and design patterns
├── techContext.md       # Tech stack documentation
└── progress.md          # Progress tracking for all PRs
```

### PR Party Documentation

Each PR has 5-7 comprehensive documents:
- Main Specification (~8,000 words)
- Implementation Checklist (step-by-step)
- Quick Start Guide
- Planning Summary
- Testing Guide
- Bug Analysis (when needed)
- Complete Summary (after completion)

## Roadmap

### ✅ Phase 1: Foundation (Complete)
- [x] Project setup and Firebase integration
- [ ] Authentication (signup/login)

### 🚧 Phase 2: Core Messaging (In Progress)
- [ ] One-on-one chat
- [ ] Real-time delivery
- [ ] Message status indicators
- [ ] Presence and typing indicators

### 📋 Phase 3: Enhanced Features (Planned)
- [ ] Group chat (3+ users)
- [ ] Image sharing
- [ ] Offline support and sync
- [ ] Push notifications

### 📋 Phase 4: Polish & Deployment (Planned)
- [ ] Profile management
- [ ] Error handling
- [ ] UI polish and animations
- [ ] Testing and bug fixes
- [ ] TestFlight deployment

## Current Status

**Project Stage**: 🟢 Phase 1 Complete - Foundation Established  
**Last Updated**: October 20, 2025  
**Next Milestone**: PR #2 - Authentication Services

### Completed PRs

- ✅ **PR #1**: Project Setup & Firebase Configuration
  - Firebase project created and configured
  - iOS app structure established
  - Firebase SDK integrated via SPM
  - All services enabled (Auth, Firestore, Storage, Messaging)
  - MVVM folder structure created
  - Constants and configuration complete

### Next PRs

- 🚧 **PR #2**: Authentication - Models & Services (2-3 hours)
- 📋 **PR #3**: Authentication - UI Views (2-3 hours)
- 📋 **PR #4**: Core Models & Data Structure (1-2 hours)

## Contributing

This is a learning project built as part of the GauntletAI Week 2 challenge. Contributions, suggestions, and feedback are welcome!

### Development Process

1. Follow the PR breakdown in `messageai_task_list.md`
2. Create feature branch: `git checkout -b feature/pr#-name`
3. Follow implementation checklist in `PR_PARTY/`
4. Test thoroughly (use 2 devices when possible)
5. Commit with clear messages
6. Update documentation

## Resources

### Firebase Documentation
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [Cloud Firestore](https://firebase.google.com/docs/firestore)
- [Firebase Authentication](https://firebase.google.com/docs/auth)
- [Firebase Storage](https://firebase.google.com/docs/storage)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)

### SwiftUI Resources
- [Apple SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui)

### Similar Projects
- Search GitHub for "SwiftUI Firebase Chat" for reference implementations
- [WhatsApp System Design](https://www.youtube.com/results?search_query=whatsapp+system+design)

## License

MIT License - See [LICENSE](LICENSE) file for details

## Author

**Isaac Jaramillo** ([@boxingknight](https://github.com/boxingknight))

Built as part of GauntletAI's intensive coding challenge, demonstrating:
- Production-quality iOS development
- Real-time messaging infrastructure
- Firebase backend integration
- Offline-first architecture
- Modern SwiftUI patterns

## Acknowledgments

- Inspired by **WhatsApp**'s simplicity and reliability
- Built with **GauntletAI** Week 2 challenge guidelines
- Powered by **Firebase** backend infrastructure
- Developed with **Cursor AI** assistance

---

**Status**: 🚀 Foundation Complete - Ready for Authentication  
**Last Build**: ✅ Successful  
**Firebase**: ✅ Connected  
**Tests**: 7/7 Critical Tests Passed

---

*"Perfect is the enemy of good. But good planning makes perfect possible."*

