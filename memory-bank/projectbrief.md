# MessageAI - Project Brief

**Last Updated**: October 20, 2025  
**Platform**: iOS (Swift + SwiftUI)  
**Backend**: Firebase (Firestore, Auth, Storage, Cloud Messaging)  
**Timeline**: 24-hour MVP, extensible to full feature set  
**Developer**: Isaac Jaramillo

---

## Mission Statement

Build a production-quality messaging application for iOS that demonstrates solid messaging infrastructure with real-time sync, offline support, and group chat capabilities. The MVP focuses on reliability over feature count, following the WhatsApp model of simple, fast, and dependable communication.

---

## Core Objectives

### Primary Goal
Create a messaging app that **never loses messages** and delivers them reliably under any network conditions—the foundation of trust in a messaging platform.

### Success Criteria (MVP - 24 Hours)
1. ✅ One-on-one chat with real-time delivery (1-2 seconds)
2. ✅ Group chat with 3+ participants
3. ✅ Messages persist through app restarts and force quits
4. ✅ Optimistic UI (messages appear instantly)
5. ✅ Online/offline presence indicators
6. ✅ Typing indicators
7. ✅ Message read receipts (sent/delivered/read)
8. ✅ Basic image sharing
9. ✅ Push notifications (foreground minimum)
10. ✅ Offline message queuing with automatic sync

### Technical Requirements
- **Real-Time Messaging**: Messages deliver within 1-2 seconds for online users
- **Offline Support**: Full functionality offline, automatic sync on reconnect
- **Message Persistence**: SwiftData for local storage + Firestore for cloud sync
- **Network Resilience**: Handle 3G, packet loss, intermittent connectivity
- **No Data Loss**: Messages never lost under any circumstance (app crashes, force quit, offline)

---

## Project Scope

### In Scope (MVP)
- User authentication (email/password via Firebase Auth)
- One-on-one text messaging
- Group messaging (3+ participants)
- Real-time message delivery with Firestore listeners
- Message status tracking (sending/sent/delivered/read)
- Online/offline presence
- Typing indicators
- Image sharing (photo library + camera)
- Push notifications via Firebase Cloud Messaging
- Offline message queue with retry logic
- Local persistence with SwiftData
- Profile management (display name, profile picture)

### Out of Scope (Future/AI Features)
- Message translation
- Conversation summarization
- AI-powered message suggestions
- Voice/video calling
- Message reactions/emojis
- Message editing/deletion
- End-to-end encryption
- Stories/status updates
- Location sharing
- Contact sync from phone

---

## Key Constraints

### Time Constraints
- **MVP Deadline**: 24 hours from start
- **Prioritization**: Core messaging must work perfectly before adding features
- **Build Strategy**: Vertical slices—finish one feature completely before starting next

### Technical Constraints
- iOS 16.0+ minimum deployment target
- SwiftUI-only UI (no UIKit except for image picker)
- Firebase as only backend (no custom servers)
- Physical device testing required (simulators don't show real performance)

### Quality Gates
- Zero critical bugs in core messaging flow
- All messages must sync correctly
- App must handle offline gracefully
- Performance: <2 second message delivery, <500ms UI response

---

## Architecture Philosophy

### Core Principles

1. **Optimistic UI First**
   - Messages appear instantly when sent
   - Update status as server confirms
   - User never waits for network

2. **Offline-First Design**
   - App works fully offline (read, compose)
   - Queue messages locally
   - Auto-sync on reconnect
   - No data loss, ever

3. **Real-Time by Default**
   - Firestore snapshot listeners for instant updates
   - Presence tracking with sub-second latency
   - Typing indicators with debouncing

4. **MVVM Pattern**
   - ViewModels handle business logic
   - Services encapsulate Firebase operations
   - Views are pure presentation
   - Clear separation of concerns

5. **Test Early, Test Often**
   - Two physical devices for real-time testing
   - Test offline scenarios constantly
   - Verify app lifecycle handling
   - No feature complete without testing

---

## Project Phases

### Phase 1: Foundation (Hours 0-8)
- **PR #1-3**: Project setup, Firebase config, authentication UI
- **Goal**: Users can sign up and log in
- **Deliverable**: Working auth flow

### Phase 2: Core Messaging (Hours 8-16)
- **PR #4-11**: Models, chat service, UI, real-time delivery, message status
- **Goal**: Two users can message each other in real-time
- **Deliverable**: Working one-on-one chat

### Phase 3: Enhanced Features (Hours 16-20)
- **PR #12-15**: Presence, typing, group chat, images, offline support
- **Goal**: Feature-complete MVP
- **Deliverable**: Group chat, images, offline queue

### Phase 4: Polish & Deploy (Hours 20-24)
- **PR #16-22**: Profile, notifications, error handling, testing, docs
- **Goal**: Production-ready app
- **Deliverable**: Deployed, documented, demo-ready

---

## Technical Stack

### Frontend (iOS)
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Local Storage**: SwiftData (Core Data successor)
- **State Management**: Combine + @Published
- **Image Handling**: AsyncImage, UIImagePickerController
- **Networking**: Built into Firebase SDK

### Backend (Firebase)
- **Authentication**: Firebase Auth (email/password)
- **Database**: Cloud Firestore (real-time NoSQL)
- **Storage**: Firebase Storage (images/media)
- **Messaging**: Firebase Cloud Messaging (push notifications)
- **Functions**: Cloud Functions (notification triggers)

### Development Tools
- **IDE**: Xcode 15+
- **Version Control**: Git + GitHub
- **Dependency Management**: Swift Package Manager
- **Testing**: XCTest (unit), XCUITest (UI), Physical devices (integration)

---

## Risk Management

### High-Risk Areas

1. **Firestore Offline Sync Conflicts**
   - Risk: Duplicate messages or data loss
   - Mitigation: Use unique message IDs, server timestamp as source of truth

2. **Memory Leaks from Firestore Listeners**
   - Risk: App crashes, battery drain
   - Mitigation: Properly detach listeners on view disappear, limit query results

3. **Push Notification Setup Complexity**
   - Risk: Notifications don't work
   - Mitigation: Follow Firebase FCM setup exactly, test on physical device

4. **Offline Message Queue Failures**
   - Risk: Messages lost when offline
   - Mitigation: SwiftData persistence, retry with exponential backoff

5. **Timeline Pressure**
   - Risk: Not enough time for all features
   - Mitigation: Prioritize ruthlessly, ship core messaging first

---

## Success Metrics

### Functional Metrics
- ✅ Message delivery success rate: 100%
- ✅ Real-time delivery latency: <2 seconds
- ✅ Offline sync success rate: 100%
- ✅ App crash rate: <0.1%
- ✅ Message ordering accuracy: 100%

### Quality Metrics
- ✅ All critical test scenarios pass
- ✅ Zero data loss in stress testing
- ✅ Handles 20+ rapid messages correctly
- ✅ Works on 3G networks
- ✅ Survives force quit without data loss

### Delivery Metrics
- ✅ MVP complete in 24 hours
- ✅ Demo video (5-7 minutes) recorded
- ✅ Documentation complete (README, setup guide)
- ✅ GitHub repository published
- ✅ Firebase backend deployed

---

## Current Status

**Project Stage**: 🟢 INITIALIZED  
**Code State**: Fresh Xcode project created, no implementation yet  
**Next Action**: Begin PR #1 - Project Setup & Firebase Configuration

**Date Started**: October 20, 2025  
**Target MVP Completion**: October 21, 2025 (24 hours)

---

## Key Decisions

### Why Firebase?
- Real-time sync built-in (saves weeks of development)
- Offline persistence out-of-the-box
- Authentication is 10 lines of code
- Scales to production usage
- Cloud Functions ready for future AI features

### Why SwiftUI?
- Fastest development for iOS
- Modern, declarative UI
- Native performance and animations
- Best integration with iOS features
- SwiftData for simple local persistence

### Why MVVM?
- Clear separation of concerns
- Testable business logic
- Reactive data flow with Combine
- Industry-standard pattern for SwiftUI
- Easy to reason about and maintain

---

## Reference Documents

- **PRD**: `/messageai_prd.md` - Complete product requirements (811 lines)
- **Task List**: `/messageai_task_list.md` - PR breakdown with 23 PRs (1601 lines)
- **Xcode Project**: `/messAI.xcodeproj` - iOS project configuration

---

*This is the foundation document. All other memory bank files derive from this brief.*

