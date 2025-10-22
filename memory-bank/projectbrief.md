# MessageAI - Project Brief

**Last Updated**: October 22, 2025  
**Platform**: iOS (Swift + SwiftUI)  
**Backend**: Firebase (Firestore, Auth, Storage, Cloud Messaging) + **Cloud Functions + OpenAI**  
**Timeline**: Core messaging complete (PRs 1-13), now building AI features (PRs 14-20)  
**Developer**: Isaac Jaramillo

---

## 🎯 STRATEGIC PIVOT (October 22, 2025)

### Original Mission: ✅ COMPLETE!
Built a production-quality messaging application for iOS with solid messaging infrastructure, real-time sync, offline support, and group chat capabilities. The foundation follows the WhatsApp model of simple, fast, and dependable communication.

**Status**: Core messaging complete (PRs 1-13)! 🎉

### New Mission: AI-Powered Messaging for Busy Parents
Now building on this solid foundation to add **5 required AI features + 1 advanced agent** that help busy parents manage family coordination:

**5 Required AI Features:**
1. 📅 **Calendar Extraction** - Auto-detect dates, times, events from messages
2. 🎯 **Decision Summarization** - Summarize group decisions and action items
3. ⚡ **Priority Highlighting** - Highlight urgent/important messages visually
4. ✅ **RSVP Tracking** - Track who responded yes/no/maybe to events
5. 📆 **Deadline Extraction** - Extract and track deadlines from conversations

**Advanced Feature (+10 bonus points):**
6. 🤖 **Multi-Step Event Planning Agent** - Conversational AI agent for coordinating family events

**Target User**: Sarah, 34, working mom with 2 kids, manages 100+ messages/day across family, school, and work groups.

**Success Metric**: Sarah can confidently manage all her group chats in 10 minutes per day instead of 45 minutes.

---

## Core Objectives

### Primary Goal
Create a messaging app that **never loses messages** and delivers them reliably under any network conditions—the foundation of trust in a messaging platform.

### Success Criteria

**Core Messaging (PRs 1-13):** ✅ **COMPLETE!**
1. ✅ User authentication with Firebase Auth
2. ✅ One-on-one chat with real-time delivery (1-2 seconds)
3. ✅ Group chat with 3+ participants
4. ✅ Messages persist through app restarts and force quits
5. ✅ Optimistic UI (messages appear instantly)
6. ✅ Online/offline presence indicators
7. ✅ Typing indicators
8. ✅ Message read receipts (sent/delivered/read)
9. ✅ WhatsApp-quality status indicators
10. ✅ Offline message queuing with automatic sync

**AI Features (PRs 14-20):** ⏳ **IN PROGRESS**
1. ⏳ Calendar Extraction (Date/time/event detection from messages)
2. ⏳ Decision Summarization (Group decision and action item summaries)
3. ⏳ Priority Highlighting (Urgent/important message detection)
4. ⏳ RSVP Tracking (Yes/no/maybe response tracking for events)
5. ⏳ Deadline Extraction (Deadline detection and tracking)
6. ⏳ Multi-Step Event Planning Agent (Advanced conversational agent) **+10 bonus!**

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

### Now In Scope (AI Features - PRs 14-20)
- ✅ Calendar extraction (dates, times, events)
- ✅ Decision summarization (group decisions & action items)
- ✅ Priority highlighting (urgent/important visual indicators)
- ✅ RSVP tracking (yes/no/maybe for events)
- ✅ Deadline extraction and tracking
- ✅ Multi-step event planning agent (advanced conversational AI) **+10 bonus!**
- ✅ Cloud Functions for AI processing
- ✅ OpenAI GPT-4 integration
- ✅ RAG pipeline for conversation context

### Out of Scope (Future Features)
- Message translation
- Voice/video calling
- Message reactions/emojis
- Message editing/deletion
- End-to-end encryption
- Stories/status updates
- Location sharing
- Contact sync from phone
- Image sharing (deferred)

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

## Project Phases (REVISED)

### Phase 1: Foundation ✅ **COMPLETE** (PRs #1-3)
- **PRs**: Project setup, Firebase config, authentication UI
- **Goal**: Users can sign up and log in
- **Status**: ✅ Complete - Working auth flow

### Phase 2: Core Messaging ✅ **COMPLETE** (PRs #4-13)
- **PRs**: Models, chat service, UI, real-time delivery, message status, presence, typing, group chat
- **Goal**: Two users can message each other in real-time with full features
- **Status**: ✅ Complete - WhatsApp-quality messaging

### Phase 3: AI Features ⏳ **IN PROGRESS** (PRs #14-20) **NEW!**
- **PR #14**: Cloud Functions Setup & AI Service Base (2-3h)
- **PR #15**: Calendar Extraction Feature (3-4h)
- **PR #16**: Decision Summarization Feature (3-4h)
- **PR #17**: Priority Highlighting Feature (2-3h)
- **PR #18**: RSVP Tracking Feature (3-4h)
- **PR #19**: Deadline Extraction Feature (3-4h)
- **PR #20**: Multi-Step Event Planning Agent (5-6h) **+10 bonus!**
- **Goal**: AI-powered messaging for busy parents with advanced agent
- **Status**: ⏳ Next phase

### Phase 4: Essential Polish (PRs #21-25)
- **PRs**: Offline support, push notifications, image sharing, profile, error handling
- **Goal**: Complete core app features
- **Status**: ⏳ Pending

### Phase 5: Final Polish & Deploy (PRs #26-28)
- **PRs**: UI polish, testing, documentation, demo video
- **Goal**: Production-ready app ready for submission
- **Status**: ⏳ Pending

---

## Technical Stack

### Frontend (iOS)
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Local Storage**: SwiftData (Core Data successor)
- **State Management**: Combine + @Published
- **Image Handling**: AsyncImage, UIImagePickerController
- **Networking**: Built into Firebase SDK

### Backend (Firebase + AI) **ENHANCED!**
- **Authentication**: Firebase Auth (email/password)
- **Database**: Cloud Firestore (real-time NoSQL)
- **Storage**: Firebase Storage (images/media)
- **Messaging**: Firebase Cloud Messaging (push notifications)
- **Functions**: Cloud Functions (Node.js 18+) - **Enhanced for AI!**
  - Notification triggers
  - **AI service endpoints** (summarize, replies, action items, importance)
  - **RAG pipeline** (conversation context retrieval)
  - **OpenAI integration** (GPT-4)

### AI Infrastructure **NEW!**
- **OpenAI API**: GPT-4 for AI features
- **Cloud Functions**: Serverless AI endpoints
- **RAG Pipeline**: Conversation context for AI
- **iOS AIService**: Type-safe Swift wrapper

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

**Project Stage**: 🚀 **AI INTEGRATION PHASE** (PRs 1-13 complete!)  
**Code State**: Core messaging complete, ready for AI features  
**Next Action**: PR #14 - AI Infrastructure Setup (Cloud Functions + OpenAI)

**Date Started**: October 20, 2025  
**Core Messaging Complete**: October 21, 2025 (PRs 1-13)  
**Strategic Revision**: October 22, 2025 (New AI direction)  
**Current Phase**: Building AI features (PRs 14-20)

**Completed PRs**: 13/28 (46%)  
**Lines of Code**: ~4,000+ Swift, 100+ Firestore rules  
**Documentation**: ~250,000+ words in PR_PARTY  
**Next PR**: #14 - Cloud Functions Setup & AI Service Base

---

## Key Decisions

### Why Firebase + Cloud Functions + OpenAI?
- Real-time sync built-in (saves weeks of development) ✅
- Offline persistence out-of-the-box ✅
- Authentication is 10 lines of code ✅
- Scales to production usage ✅
- Cloud Functions perfect for AI processing **✅ NOW USING!**
- Secure API key management (server-side)
- Serverless architecture (no server maintenance)
- RAG pipeline with Firestore integration
- OpenAI for state-of-the-art AI features

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

### Original Documents
- **Original PRD**: `/messageai_prd.md` - Complete product requirements (811 lines)
- **Original Task List**: `/messageai_task_list.md` - PR breakdown with 23 PRs (1601 lines)

### Revised Documents **NEW!**
- **Revised PRD**: `/REVISED_PRD.md` - Updated with busy parent persona and AI features
- **Revised Task List**: `/REVISED_TASK_LIST.md` - Reorganized PRs 14-20 for AI integration
- **Revision Summary**: `/REVISION_SUMMARY.md` - Detailed explanation of strategic changes
- **Quick Start Guide**: `/QUICK_START_GUIDE.md` - Visual implementation guide
- **README Revision**: `/README_REVISION.md` - Final summary document

### Project Files
- **Xcode Project**: `/messAI.xcodeproj` - iOS project configuration
- **PR Documentation**: `/PR_PARTY/` - 92 comprehensive planning documents (~250K+ words)

---

*This is the foundation document. All other memory bank files derive from this brief.*

