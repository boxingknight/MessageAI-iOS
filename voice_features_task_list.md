# MessageAI Voice Features - Task List & PR Breakdown

## Project File Structure

```
MessageAI/
├── MessageAI.xcodeproj
├── MessageAI/
│   ├── App/
│   │   ├── MessageAIApp.swift
│   │   └── AppDelegate.swift
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Message.swift
│   │   ├── Conversation.swift
│   │   └── ConversationAudio.swift (NEW)
│   ├── ViewModels/
│   │   ├── ChatViewModel.swift
│   │   ├── VoiceRecorderViewModel.swift (NEW)
│   │   ├── AudioPlayerViewModel.swift (NEW)
│   │   ├── VoiceClonerViewModel.swift (NEW)
│   │   └── ConversationSummaryViewModel.swift (NEW)
│   ├── Views/
│   │   ├── Chat/
│   │   │   ├── ChatView.swift
│   │   │   ├── MessageRowView.swift
│   │   │   ├── VoiceMessageInputView.swift (NEW)
│   │   │   └── MessageAudioPlayerView.swift (NEW)
│   │   ├── Voice/
│   │   │   ├── VoiceCloningSetupView.swift (NEW)
│   │   │   ├── VoiceRecordingView.swift (NEW)
│   │   │   └── WaveformView.swift (NEW)
│   │   └── Summary/
│   │       └── ConversationSummaryView.swift (NEW)
│   ├── Services/
│   │   ├── FirebaseService.swift
│   │   ├── AudioRecordingService.swift (NEW)
│   │   ├── AudioPlaybackService.swift (NEW)
│   │   ├── VoiceCloneService.swift (NEW)
│   │   └── ConversationSummaryService.swift (NEW)
│   ├── Utilities/
│   │   ├── AudioUtilities.swift (NEW)
│   │   ├── FileManager+Extensions.swift (NEW)
│   │   └── TimeFormatter.swift (NEW)
│   └── Resources/
│       ├── GoogleService-Info.plist
│       └── Assets.xcassets
├── CloudFunctions/
│   ├── functions/
│   │   ├── src/
│   │   │   ├── index.ts
│   │   │   ├── transcription.ts (NEW)
│   │   │   ├── voiceCloning.ts (NEW)
│   │   │   ├── textToSpeech.ts (NEW)
│   │   │   └── summarization.ts (NEW)
│   │   ├── package.json
│   │   └── tsconfig.json
│   └── firebase.json
├── Podfile
└── README.md
```

---

## Phase 1: Foundation & Setup (Week 1)

### PR #1: Project Setup & Firebase Configuration
**Branch:** `feature/firebase-setup`  
**Estimated Time:** 4-6 hours

#### Tasks:
- [ ] **1.1** Set up Firebase project (if not already done)
  - Create Firebase project at console.firebase.google.com
  - Enable Firestore, Storage, Authentication, Functions
  - Download `GoogleService-Info.plist`
  
- [ ] **1.2** Update Xcode project with Firebase
  - **Files to modify:**
    - `Podfile` - Add Firebase pods
    - `MessageAIApp.swift` - Initialize Firebase
  - **New files:**
    - `GoogleService-Info.plist` (in Resources/)
  
- [ ] **1.3** Install CocoaPods dependencies
  ```ruby
  # Podfile additions
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Storage'
  pod 'Firebase/Functions'
  ```

- [ ] **1.4** Initialize Firebase in app
  - **Files to modify:**
    - `MessageAIApp.swift`
  ```swift
  import Firebase
  
  @main
  struct MessageAIApp: App {
      init() {
          FirebaseApp.configure()
      }
  }
  ```

- [ ] **1.5** Set up Cloud Functions project
  - **New directory:** `CloudFunctions/`
  - **Files to create:**
    - `CloudFunctions/functions/package.json`
    - `CloudFunctions/functions/tsconfig.json`
    - `CloudFunctions/functions/src/index.ts`
  - Run: `firebase init functions`

- [ ] **1.6** Configure environment variables
  - **Files to create:**
    - `CloudFunctions/functions/.env` (gitignored)
    - Add: `OPENAI_API_KEY`, `ELEVENLABS_API_KEY`

**PR Checklist:**
- [ ] Podfile updated with Firebase dependencies
- [ ] Firebase initialized in app
- [ ] Cloud Functions project created
- [ ] Environment variables configured
- [ ] Build succeeds without errors
- [ ] Firebase connection tested

---

### PR #2: Database Schema Updates
**Branch:** `feature/firestore-schema-voice`  
**Estimated Time:** 2-3 hours

#### Tasks:
- [ ] **2.1** Update User model for voice data
  - **Files to modify:**
    - `Models/User.swift`
  - **Changes:**
    ```swift
    struct User: Codable, Identifiable {
        let id: String
        var name: String
        var email: String
        var photoUrl: String?
        var elevenLabsVoiceId: String? // NEW
        var voiceSampleUrl: String? // NEW
        var voiceCloningCompletedAt: Date? // NEW
        var createdAt: Date
    }
    ```

- [ ] **2.2** Update Message model for audio
  - **Files to modify:**
    - `Models/Message.swift`
  - **Changes:**
    ```swift
    struct Message: Codable, Identifiable {
        let id: String
        let conversationId: String
        let senderId: String
        var content: String
        var audioUrl: String? // NEW
        var transcript: String? // NEW
        var audioDuration: Int? // NEW (seconds)
        var transcriptionConfidence: Double? // NEW
        var sentAt: Date
        var deliveredAt: Date?
        var readAt: Date?
    }
    ```

- [ ] **2.3** Create ConversationAudio model
  - **Files to create:**
    - `Models/ConversationAudio.swift`
  - **Content:**
    ```swift
    struct ConversationAudio: Codable, Identifiable {
        let id: String
        let conversationId: String
        let type: AudioType // summary or full_conversation
        let audioUrl: String
        var summaryText: String?
        var messageCount: Int
        var duration: Int
        var createdAt: Date
        var expiresAt: Date
        
        enum AudioType: String, Codable {
            case summary
            case fullConversation = "full_conversation"
        }
    }
    ```

- [ ] **2.4** Update Firestore security rules
  - **Files to modify:**
    - `CloudFunctions/firestore.rules`
  - Add rules for voice data access control

**PR Checklist:**
- [ ] User model updated with voice fields
- [ ] Message model updated with audio fields
- [ ] ConversationAudio model created
- [ ] Security rules updated
- [ ] Models compile without errors
- [ ] Codable conformance tested

---

## Phase 2: Voice Recording & Transcription (Week 1-2)

### PR #3: Audio Recording Service
**Branch:** `feature/audio-recording`  
**Estimated Time:** 8-10 hours

#### Tasks:
- [ ] **3.1** Create AudioRecordingService
  - **Files to create:**
    - `Services/AudioRecordingService.swift`
  - **Functionality:**
    - Configure AVAudioSession
    - Start/stop recording
    - Save to local file
    - Handle permissions

- [ ] **3.2** Create VoiceRecorderViewModel
  - **Files to create:**
    - `ViewModels/VoiceRecorderViewModel.swift`
  - **State management:**
    - `@Published var isRecording: Bool`
    - `@Published var recordingTime: TimeInterval`
    - `@Published var audioURL: URL?`

- [ ] **3.3** Request microphone permissions
  - **Files to modify:**
    - `Info.plist`
  - **Add:**
    ```xml
    <key>NSMicrophoneUsageDescription</key>
    <string>We need access to your microphone to record voice messages.</string>
    ```

- [ ] **3.4** Create audio utilities
  - **Files to create:**
    - `Utilities/AudioUtilities.swift`
  - **Functions:**
    - Format time (MM:SS)
    - Calculate audio duration
    - Compress audio file

- [ ] **3.5** Create WaveformView component
  - **Files to create:**
    - `Views/Voice/WaveformView.swift`
  - Visual feedback during recording

- [ ] **3.6** Create VoiceRecordingView
  - **Files to create:**
    - `Views/Voice/VoiceRecordingView.swift`
  - **UI Elements:**
    - Record button (hold to record)
    - Timer display
    - Waveform visualization
    - Cancel / Send buttons

**PR Checklist:**
- [ ] AudioRecordingService implemented
- [ ] VoiceRecorderViewModel created
- [ ] Microphone permissions requested
- [ ] WaveformView renders correctly
- [ ] VoiceRecordingView UI complete
- [ ] Can record and save audio locally
- [ ] Recording stops after 2 minutes max

---

### PR #4: Cloud Function - Transcription
**Branch:** `feature/cloud-function-transcription`  
**Estimated Time:** 6-8 hours

#### Tasks:
- [ ] **4.1** Install OpenAI SDK in Cloud Functions
  - **Files to modify:**
    - `CloudFunctions/functions/package.json`
  - **Add dependency:**
    ```json
    "openai": "^4.0.0"
    ```

- [ ] **4.2** Create transcription Cloud Function
  - **Files to create:**
    - `CloudFunctions/functions/src/transcription.ts`
  - **Function:**
    ```typescript
    import { onCall } from 'firebase-functions/v2/https';
    import OpenAI from 'openai';
    
    export const transcribeAudio = onCall(async (request) => {
        const { audioUrl } = request.data;
        
        // Download audio from Firebase Storage
        // Call OpenAI Whisper API
        // Return transcript and confidence
    });
    ```

- [ ] **4.3** Export function in index
  - **Files to modify:**
    - `CloudFunctions/functions/src/index.ts`
  - **Add:**
    ```typescript
    export { transcribeAudio } from './transcription';
    ```

- [ ] **4.4** Deploy Cloud Function
  - Run: `firebase deploy --only functions:transcribeAudio`

- [ ] **4.5** Test transcription endpoint
  - Create test audio file
  - Call function from iOS
  - Verify response format

**PR Checklist:**
- [ ] OpenAI SDK installed
- [ ] transcribeAudio function implemented
- [ ] Function deployed successfully
- [ ] Function tested with sample audio
- [ ] Error handling implemented
- [ ] Returns transcript and confidence score

---

### PR #5: Transcription Integration in iOS
**Branch:** `feature/transcription-integration`  
**Estimated Time:** 8-10 hours

#### Tasks:
- [ ] **5.1** Create VoiceMessageInputView
  - **Files to create:**
    - `Views/Chat/VoiceMessageInputView.swift`
  - **States:**
    - Idle (mic button)
    - Recording (waveform + controls)
    - Transcribing (loading spinner)
    - Review (editable transcript)

- [ ] **5.2** Implement upload to Firebase Storage
  - **Files to modify:**
    - `Services/FirebaseService.swift`
  - **Function:**
    ```swift
    func uploadAudio(_ localURL: URL, userId: String) async throws -> String {
        // Upload to Firebase Storage
        // Return download URL
    }
    ```

- [ ] **5.3** Call transcription Cloud Function
  - **Files to modify:**
    - `ViewModels/VoiceRecorderViewModel.swift`
  - **Function:**
    ```swift
    func transcribeAudio(_ audioURL: String) async throws -> (String, Double) {
        let functions = Functions.functions()
        let callable = functions.httpsCallable("transcribeAudio")
        let result = try await callable.call(["audioUrl": audioURL])
        // Parse and return transcript + confidence
    }
    ```

- [ ] **5.4** Display transcript with edit capability
  - **Files to modify:**
    - `Views/Chat/VoiceMessageInputView.swift`
  - Show TextEditor with transcript
  - Allow user to edit before sending

- [ ] **5.5** Send message with audio + transcript
  - **Files to modify:**
    - `ViewModels/ChatViewModel.swift`
  - Save message to Firestore with both fields

- [ ] **5.6** Handle transcription errors
  - Low confidence warning
  - API failure fallback (send audio-only)
  - Network error retry logic

**PR Checklist:**
- [ ] VoiceMessageInputView complete
- [ ] Audio uploads to Firebase Storage
- [ ] Transcription Cloud Function called successfully
- [ ] Transcript displayed and editable
- [ ] Messages save with audio URL and transcript
- [ ] Error handling works (low confidence, failures)
- [ ] End-to-end flow tested (record → transcribe → send)

---

### PR #6: Message Display with Audio
**Branch:** `feature/message-audio-display`  
**Estimated Time:** 4-6 hours

#### Tasks:
- [ ] **6.1** Update MessageRowView for audio messages
  - **Files to modify:**
    - `Views/Chat/MessageRowView.swift`
  - **Show:**
    - Audio icon/badge
    - Transcript text
    - Duration

- [ ] **6.2** Add visual indicators
  - Show microphone icon for voice messages
  - Display audio duration
  - Different styling for voice vs text messages

- [ ] **6.3** Implement offline caching
  - **Files to create:**
    - `Utilities/FileManager+Extensions.swift`
  - Cache audio files locally
  - Load from cache when available

**PR Checklist:**
- [ ] MessageRowView shows audio messages correctly
- [ ] Visual indicators clear (mic icon, duration)
- [ ] Audio files cached locally
- [ ] Transcript displayed below/with audio indicator
- [ ] UI looks polished

---

## Phase 3: Text-to-Speech & Voice Cloning (Week 3-4)

### PR #7: Voice Cloning Setup Flow
**Branch:** `feature/voice-cloning-setup`  
**Estimated Time:** 10-12 hours

#### Tasks:
- [ ] **7.1** Create VoiceCloningSetupView
  - **Files to create:**
    - `Views/Voice/VoiceCloningSetupView.swift`
  - **Screens:**
    - Instructions screen
    - Sample text display
    - Recording screen
    - Processing screen
    - Preview screen

- [ ] **7.2** Create VoiceClonerViewModel
  - **Files to create:**
    - `ViewModels/VoiceClonerViewModel.swift`
  - **State:**
    - Current step (instructions, recording, processing, preview)
    - Voice ID
    - Preview audio URL

- [ ] **7.3** Record voice sample (30-60 seconds)
  - Reuse AudioRecordingService
  - Show sample text to read
  - Enforce minimum 30 seconds

- [ ] **7.4** Add Settings navigation
  - **Files to modify:**
    - `Views/Settings/SettingsView.swift` (or create if doesn't exist)
  - Add "Set Up My Voice" button
  - Navigate to VoiceCloningSetupView

**PR Checklist:**
- [ ] VoiceCloningSetupView UI complete
- [ ] VoiceClonerViewModel manages state
- [ ] Can record 30-60 second sample
- [ ] Settings has voice setup option
- [ ] UI flow tested (all screens transition correctly)

---

### PR #8: Cloud Function - Voice Cloning
**Branch:** `feature/cloud-function-voice-cloning`  
**Estimated Time:** 6-8 hours

#### Tasks:
- [ ] **8.1** Install ElevenLabs SDK
  - **Files to modify:**
    - `CloudFunctions/functions/package.json`
  - **Add:**
    ```json
    "@elevenlabs/sdk": "^0.8.0"
    ```

- [ ] **8.2** Create voice cloning function
  - **Files to create:**
    - `CloudFunctions/functions/src/voiceCloning.ts`
  - **Function:**
    ```typescript
    export const cloneVoice = onCall(async (request) => {
        const { audioUrl, userId } = request.data;
        
        // Download audio from Firebase Storage
        // Call ElevenLabs Voice Design API
        // Save voice_id to Firestore user document
        // Return voice_id
    });
    ```

- [ ] **8.3** Deploy and test
  - Deploy: `firebase deploy --only functions:cloneVoice`
  - Test with sample audio

**PR Checklist:**
- [ ] ElevenLabs SDK installed
- [ ] cloneVoice function implemented
- [ ] Function saves voice_id to Firestore
- [ ] Deployed and tested successfully
- [ ] Error handling for failed cloning

---

### PR #9: Voice Cloning Integration
**Branch:** `feature/voice-cloning-integration`  
**Estimated Time:** 6-8 hours

#### Tasks:
- [ ] **9.1** Call cloneVoice Cloud Function
  - **Files to modify:**
    - `ViewModels/VoiceClonerViewModel.swift`
  - **Function:**
    ```swift
    func cloneVoice(sampleURL: URL) async throws -> String {
        // Upload sample to Storage
        // Call Cloud Function
        // Save voice_id locally
    }
    ```

- [ ] **9.2** Update user profile with voice_id
  - **Files to modify:**
    - `Services/FirebaseService.swift`
  - Save elevenLabsVoiceId to Firestore

- [ ] **9.3** Generate and play preview
  - Generate short preview audio
  - Play in VoiceCloningSetupView
  - Allow re-record if unhappy

- [ ] **9.4** Handle voice cloning errors
  - API failures
  - Poor audio quality warnings
  - Retry mechanism

**PR Checklist:**
- [ ] Voice cloning flow works end-to-end
- [ ] voice_id saved to user profile
- [ ] Preview audio generated and playable
- [ ] Can re-record if unsatisfied
- [ ] Error handling functional

---

### PR #10: Cloud Function - Text-to-Speech
**Branch:** `feature/cloud-function-tts`  
**Estimated Time:** 8-10 hours

#### Tasks:
- [ ] **10.1** Create TTS Cloud Function
  - **Files to create:**
    - `CloudFunctions/functions/src/textToSpeech.ts`
  - **Function:**
    ```typescript
    export const generateTTS = onCall(async (request) => {
        const { text, voiceId, messageId } = request.data;
        
        // Check if audio already cached in Firestore
        // If not, call ElevenLabs TTS API
        // Upload audio to Firebase Storage
        // Update message document with audioUrl
        // Return audioUrl
    });
    ```

- [ ] **10.2** Implement caching logic
  - Check Firestore for existing audioUrl
  - Only generate if missing
  - Update message document

- [ ] **10.3** Handle default voice fallback
  - If user has no voice_id, use ElevenLabs pre-made voice
  - Professional, neutral voice

- [ ] **10.4** Deploy and test
  - Deploy: `firebase deploy --only functions:generateTTS`
  - Test with various text lengths

**PR Checklist:**
- [ ] generateTTS function implemented
- [ ] Caching prevents duplicate generation
- [ ] Default voice fallback works
- [ ] Deployed successfully
- [ ] Audio quality acceptable

---

### PR #11: Audio Playback Service
**Branch:** `feature/audio-playback`  
**Estimated Time:** 10-12 hours

#### Tasks:
- [ ] **11.1** Create AudioPlaybackService
  - **Files to create:**
    - `Services/AudioPlaybackService.swift`
  - **Functionality:**
    - Load audio from URL
    - Play/pause/seek
    - Playback speed control (1x, 1.25x, 1.5x, 2x)
    - Background audio support

- [ ] **11.2** Create AudioPlayerViewModel
  - **Files to create:**
    - `ViewModels/AudioPlayerViewModel.swift`
  - **State:**
    - `@Published var isPlaying: Bool`
    - `@Published var currentTime: TimeInterval`
    - `@Published var duration: TimeInterval`
    - `@Published var playbackRate: Float`

- [ ] **11.3** Create MessageAudioPlayerView
  - **Files to create:**
    - `Views/Chat/MessageAudioPlayerView.swift`
  - **UI:**
    - Play/pause button
    - Progress slider
    - Time labels (current / total)
    - Speed selector

- [ ] **11.4** Integrate into MessageRowView
  - **Files to modify:**
    - `Views/Chat/MessageRowView.swift`
  - Show MessageAudioPlayerView for messages with text
  - Generate TTS on demand when play tapped

- [ ] **11.5** Call generateTTS Cloud Function
  - **Files to modify:**
    - `ViewModels/AudioPlayerViewModel.swift`
  - Check if audioUrl exists
  - If not, call Cloud Function to generate
  - Show loading state during generation

- [ ] **11.6** Implement audio caching
  - Cache downloaded audio locally
  - Play from cache on subsequent taps
  - Clear old cache files periodically

**PR Checklist:**
- [ ] AudioPlaybackService implemented
- [ ] AudioPlayerViewModel manages playback state
- [ ] MessageAudioPlayerView UI complete
- [ ] Play button appears on all text messages
- [ ] generateTTS called on first play
- [ ] Cached audio plays instantly
- [ ] Playback speed controls work
- [ ] Background audio supported

---

## Phase 4: Conversation Summaries (Week 5-6)

### PR #12: Cloud Function - Conversation Summary
**Branch:** `feature/cloud-function-summary`  
**Estimated Time:** 10-12 hours

#### Tasks:
- [ ] **12.1** Create summarization function
  - **Files to create:**
    - `CloudFunctions/functions/src/summarization.ts`
  - **Function:**
    ```typescript
    export const generateSummary = onCall(async (request) => {
        const { conversationId, messageRange } = request.data;
        
        // Fetch messages from Firestore
        // Format conversation for GPT
        // Call OpenAI GPT-4o-mini
        // Generate summary text
        // Call ElevenLabs TTS for audio
        // Upload audio to Storage
        // Save to conversationAudio collection
        // Return summary text and audioUrl
    });
    ```

- [ ] **12.2** Implement message fetching
  - Query Firestore for message range
  - Format as conversation (Name: Message)
  - Limit to 200 messages max

- [ ] **12.3** GPT-4o-mini integration
  - Craft system prompt for parent-focused summaries
  - Extract: decisions, action items, dates, responsibilities
  - Max 200 words output

- [ ] **12.4** Generate summary audio
  - Use professional narrator voice from ElevenLabs
  - Upload to Storage at `audio/summaries/`

- [ ] **12.5** Save to conversationAudio collection
  - Store summary text, audio URL, metadata
  - Set expiration date (7 days)

- [ ] **12.6** Deploy and test
  - Deploy: `firebase deploy --only functions:generateSummary`
  - Test with real conversation data

**PR Checklist:**
- [ ] generateSummary function implemented
- [ ] Fetches correct message range
- [ ] GPT-4o-mini generates quality summaries
- [ ] Summary audio generated with ElevenLabs
- [ ] Data saved to conversationAudio collection
- [ ] Deployed and tested successfully

---

### PR #13: Conversation Summary UI
**Branch:** `feature/summary-ui`  
**Estimated Time:** 10-12 hours

#### Tasks:
- [ ] **13.1** Create ConversationSummaryViewModel
  - **Files to create:**
    - `ViewModels/ConversationSummaryViewModel.swift`
  - **Functionality:**
    - Detect when summary should be suggested (20+ messages)
    - Call generateSummary Cloud Function
    - Manage loading state
    - Store summary locally

- [ ] **13.2** Create ConversationSummaryView
  - **Files to create:**
    - `Views/Summary/ConversationSummaryView.swift`
  - **UI:**
    - Summary text display
    - Audio player for narration
    - "Hear Summary" button

- [ ] **13.3** Add summary trigger in ChatView
  - **Files to modify:**
    - `Views/Chat/ChatView.swift`
  - Show "Hear Summary" button when 20+ unread messages
  - Navigate to ConversationSummaryView

- [ ] **13.4** Display summary card
  - Show text summary
  - Audio player with controls
  - Option to dismiss or listen later

- [ ] **13.5** Handle summary generation states
  - Loading (analyzing conversation...)
  - Success (show summary)
  - Error (try again button)

- [ ] **13.6** Cache summaries
  - Store in local database or UserDefaults
  - Don't regenerate for same message range
  - Expire after 7 days

**PR Checklist:**
- [ ] ConversationSummaryViewModel implemented
- [ ] ConversationSummaryView UI complete
- [ ] "Hear Summary" button appears in ChatView
- [ ] Summary generates successfully
- [ ] Audio plays correctly
- [ ] Loading and error states handled
- [ ] Summaries cached locally

---

## Phase 5: Polish & Integration (Week 7)

### PR #14: Performance Optimizations
**Branch:** `feature/performance-optimization`  
**Estimated Time:** 8-10 hours

#### Tasks:
- [ ] **14.1** Implement aggressive audio caching
  - **Files to modify:**
    - `Services/AudioPlaybackService.swift`
    - `Utilities/FileManager+Extensions.swift`
  - Cache all played audio locally
  - Implement cache size limits (100MB max)
  - Clear old files (LRU eviction)

- [ ] **14.2** Optimize Firestore queries
  - **Files to modify:**
    - `Services/FirebaseService.swift`
  - Add compound indexes
  - Limit message fetches
  - Use pagination

- [ ] **14.3** Background audio generation
  - Pre-generate TTS for recent messages
  - Queue generation during idle time
  - Prioritize visible messages

- [ ] **14.4** Reduce API calls
  - Batch transcription requests when possible
  - Debounce summary generation
  - Implement rate limiting

- [ ] **14.5** Memory optimization
  - Release audio players when not in use
  - Compress cached audio files
  - Monitor memory usage

**PR Checklist:**
- [ ] Audio caching implemented
- [ ] Firestore queries optimized
- [ ] Background generation working
- [ ] API call frequency reduced
- [ ] App memory usage acceptable (<100MB)
- [ ] No performance regressions

---

### PR #15: Error Handling & Edge Cases
**Branch:** `feature/error-handling`  
**Estimated Time:** 6-8 hours

#### Tasks:
- [ ] **15.1** Network failure handling
  - **Files to modify:**
    - All ViewModels
    - All Services
  - Retry logic with exponential backoff
  - Offline queueing for uploads
  - Clear error messages to user

- [ ] **15.2** API failure handling
  - Handle OpenAI/ElevenLabs API errors
  - Fallback to text-only when TTS fails
  - Show meaningful error messages

- [ ] **15.3** Audio permission denied
  - **Files to modify:**
    - `Services/AudioRecordingService.swift`
  - Detect permission denial
  - Show alert with Settings link
  - Disable voice features gracefully

- [ ] **15.4** Low storage space
  - Detect low device storage
  - Warn user before recording
  - Auto-clean cache if needed

- [ ] **15.5** Voice cloning failures
  - Poor audio quality detection
  - Suggest re-recording with tips
  - Fallback to default voice

**PR Checklist:**
- [ ] Network failures handled gracefully
- [ ] API errors don't crash app
- [ ] Permission denial handled
- [ ] Low storage handled
- [ ] Voice cloning errors clear
- [ ] All error messages user-friendly

---

### PR #16: UI/UX Polish
**Branch:** `feature/ui-polish`  
**Estimated Time:** 8-10 hours

#### Tasks:
- [ ] **16.1** Add haptic feedback
  - **Files to modify:**
    - `Views/Chat/VoiceMessageInputView.swift`
    - `Views/Chat/MessageAudioPlayerView.swift`
  - Haptics on record start/stop
  - Haptics on play/pause
  - Haptics on send

- [ ] **16.2** Improve animations
  - Smooth transitions between states
  - Animated waveform
  - Progress indicators

- [ ] **16.3** Add loading states
  - Skeleton screens during loads
  - Progress indicators for uploads
  - Shimmer effects

- [ ] **16.4** Accessibility improvements
  - VoiceOver support for all buttons
  - Dynamic Type support
  - High contrast mode

- [ ] **16.5** Visual polish
  - Consistent color scheme
  - Smooth corners and shadows
  - Professional icons

- [ ] **16.6** Onboarding tooltips
  - First-time user guidance
  - Feature discovery hints
  - Dismissible tips

**PR Checklist:**
- [ ] Haptic feedback added
- [ ] Animations smooth
- [ ] Loading states clear
- [ ] VoiceOver works throughout
- [ ] UI looks polished
- [ ] Onboarding helpful

---

### PR #17: Testing & Bug Fixes
**Branch:** `feature/testing-bug-fixes`  
**Estimated Time:** 10-12 hours

#### Tasks:
- [ ] **17.1** Unit tests for ViewModels
  - **Files to create:**
    - `MessageAITests/VoiceRecorderViewModelTests.swift`
    - `MessageAITests/AudioPlayerViewModelTests.swift`
    - `MessageAITests/VoiceClonerViewModelTests.swift`
  - Test state transitions
  - Test error handling
  - Mock Firebase/API calls

- [ ] **17.2** Integration tests
  - End-to-end voice message flow
  - Voice cloning flow
  - Summary generation flow

- [ ] **17.3** UI tests
  - **Files to create:**
    - `MessageAIUITests/VoiceMessageUITests.swift`
  - Record and send message
  - Play TTS audio
  - Generate summary

- [ ] **17.4** Manual testing checklist
  - Test on multiple devices (iPhone 12, 14, 15)
  - Test in airplane mode
  - Test with poor network
  - Test with background/foreground transitions
  - Test with phone calls interrupting
  - Test with headphones/AirPods
  - Test with CarPlay (if available)

- [ ] **17.5** Bug fixes from testing
  - **Files to modify:** (based on bugs found)
  - Fix any crashes
  - Fix UI glitches
  - Fix audio playback issues

- [ ] **17.6** Performance profiling
  - Use Instruments to profile
  - Fix memory leaks
  - Optimize slow operations

**PR Checklist:**
- [ ] Unit tests pass (80%+ coverage on ViewModels)
- [ ] Integration tests pass
- [ ] UI tests pass
- [ ] Manual testing complete
- [ ] No critical bugs remaining
- [ ] Performance acceptable

---

### PR #18: Documentation & Code Cleanup
**Branch:** `feature/documentation`  
**Estimated Time:** 4-6 hours

#### Tasks:
- [ ] **18.1** Update README.md
  - **Files to modify:**
    - `README.md`
  - Add voice features documentation
  - Setup instructions for APIs
  - Environment variable configuration
  - Testing instructions

- [ ] **18.2** Add inline code documentation
  - **Files to modify:** All new files
  - Add header comments to files
  - Document public functions
  - Add usage examples

- [ ] **18.3** Create API documentation
  - **Files to create:**
    - `CloudFunctions/API.md`
  - Document all Cloud Functions
  - Request/response formats
  - Error codes

- [ ] **18.4** Code cleanup
  - Remove console.log statements
  - Remove commented code
  - Format code consistently
  - Fix linting warnings

- [ ] **18.5** Create .env.example files
  - **Files to create:**
    - `CloudFunctions/functions/.env.example`
  - Template for required environment variables

**PR Checklist:**
- [ ] README.md updated
- [ ] All files have header comments
- [ ] Public APIs documented
- [ ] Code cleaned up
- [ ] .env.example created
- [ ] No linting errors

---

## Phase 6: Demo & Deployment (Week 7-8)

### PR #19: Demo Preparation
**Branch:** `feature/demo-prep`  
**Estimated Time:** 6-8 hours

#### Tasks:
- [ ] **19.1** Create demo data
  - **Files to create:**
    - `MessageAI/DemoData/DemoConversations.swift`
  - Seed realistic parent conversations
  - Pre-generate voice samples
  - Create test users

- [ ] **19.2** Optimize for demo
  - Reduce API call latency for demo
  - Pre-cache demo audio
  - Ensure smooth demo flow

- [ ] **19.3** Record demo video
  - Follow demo script from PRD
  - Show all 3 phases
  - 5-7 minutes total
  - HD quality, clear audio

- [ ] **19.4** Create demo environment
  - Separate Firebase project for demo
  - Pre-populated with realistic data
  - No risk of demo data mixing with dev

**PR Checklist:**
- [ ] Demo data created
- [ ] Demo optimized for smooth playback
- [ ] Demo video recorded
- [ ] Demo environment set up
- [ ] Demo runs smoothly without issues

---

### PR #20: TestFlight Deployment
**Branch:** `release/v1.0-voice`  
**Estimated Time:** 4-6 hours

#### Tasks:
- [ ] **20.1** Update version number
  - **Files to modify:**
    - Xcode project settings
  - Bump version to 1.0.0
  - Update build number

- [ ] **20.2** Configure release build
  - Set optimization flags
  - Disable debug logging
  - Set production Firebase config

- [ ] **20.3** Generate app icons
  - **Files to modify:**
    - `Resources/Assets.xcassets`
  - Create all required icon sizes
  - Add voice-related imagery if desired

- [ ] **20.4** Update App Store metadata
  - App description (mention voice features)
  - Screenshots showing voice features
  - Privacy policy updates

- [ ] **20.5** Build and archive
  - Archive in Xcode
  - Upload to App Store Connect
  - Submit for TestFlight review

- [ ] **20.6** Create TestFlight internal group
  - Add beta testers (10 target users)
  - Send installation instructions
  - Create feedback form

**PR Checklist:**
- [ ] Version number updated
- [ ] Release build configured
- [ ] App icons complete
- [ ] App Store metadata ready
- [ ] Build uploaded to TestFlight
- [ ] Beta testers invited
- [ ] Installation instructions sent

---

## Phase 7: Deliverables & Final Touches (Week 8)

### PR #21: Persona Brainlift Document
**Branch:** `docs/persona-brainlift`  
**Estimated Time:** 2-3 hours

#### Tasks:
- [ ] **21.1** Create Persona Brainlift document
  - **Files to create:**
    - `docs/PersonaBrainlift.md`
  - **Sections:**
    - Chosen persona: Busy Parent/Caregiver
    - Pain points addressed
    - Feature-to-problem mapping (5 AI features)
    - Technical decisions rationale
    - Key outcomes

- [ ] **21.2** Export as PDF
  - Professional formatting
  - Include diagrams if helpful
  - Max 1 page

**PR Checklist:**
- [ ] Document created
- [ ] All sections complete
- [ ] Well-formatted and professional
- [ ] Exported as PDF
- [ ] Submitted with project

---

### PR #22: Social Media Post
**Branch:** `docs/social-post`  
**Estimated Time:** 1-2 hours

#### Tasks:
- [ ] **22.1** Create social media post
  - **Files to create:**
    - `docs/SocialPost.md`
  - **Content:**
    - 2-3 sentence description
    - Key features highlight
    - Persona mention
    - Demo video link
    - GitHub repo link
    - @GauntletAI tag

- [ ] **22.2** Create screenshots/graphics
  - **Files to create:**
    - `docs/screenshots/`
  - 2-3 compelling screenshots
  - Show voice features in action

- [ ] **22.3** Post on X/LinkedIn
  - Schedule or post immediately
  - Monitor for engagement
  - Respond to comments

**PR Checklist:**
- [ ] Post drafted and reviewed
- [ ] Screenshots created
- [ ] Posted on platform
- [ ] @GauntletAI tagged
- [ ] Links working
- [ ] Screenshot in docs/

---

### PR #23: Final Repository Cleanup
**Branch:** `chore/final-cleanup`  
**Estimated Time:** 2-3 hours

#### Tasks:
- [ ] **23.1** Update main README
  - **Files to modify:**
    - `README.md`
  - Add voice features section
  - Update setup instructions
  - Add demo video embed
  - Add screenshots

- [ ] **23.2** Create comprehensive SETUP.md
  - **Files to create:**
    - `docs/SETUP.md`
  - Step-by-step setup guide
  - API key configuration
  - Firebase setup
  - Cloud Functions deployment

- [ ] **23.3** Create ARCHITECTURE.md
  - **Files to create:**
    - `docs/ARCHITECTURE.md`
  - System architecture diagram
  - Data flow diagrams
  - Component relationships
  - Tech stack details

- [ ] **23.4** Add LICENSE file
  - **Files to create:**
    - `LICENSE`
  - Choose appropriate license (MIT recommended)

- [ ] **23.5** Clean up git history
  - Squash any fixup commits
  - Write clear commit messages
  - Remove any sensitive data

- [ ] **23.6** Add contributing guidelines
  - **Files to create:**
    - `CONTRIBUTING.md`
  - How to report bugs
  - How to contribute
  - Code style guide

**PR Checklist:**
- [ ] README comprehensive
- [ ] SETUP.md created
- [ ] ARCHITECTURE.md created
- [ ] LICENSE added
- [ ] Git history clean
- [ ] CONTRIBUTING.md added
- [ ] Repository looks professional

---

## Summary Checklist

### Phase 1: Foundation (Week 1)
- [ ] PR #1: Firebase Setup ✅
- [ ] PR #2: Database Schema ✅

### Phase 2: Voice Recording (Week 1-2)
- [ ] PR #3: Audio Recording Service ✅
- [ ] PR #4: Transcription Cloud Function ✅
- [ ] PR #5: Transcription Integration ✅
- [ ] PR #6: Message Audio Display ✅

### Phase 3: Text-to-Speech (Week 3-4)
- [ ] PR #7: Voice Cloning Setup ✅
- [ ] PR #8: Voice Cloning Cloud Function ✅
- [ ] PR #9: Voice Cloning Integration ✅
- [ ] PR #10: TTS Cloud Function ✅
- [ ] PR #11: Audio Playback ✅

### Phase 4: Summaries (Week 5-6)
- [ ] PR #12: Summary Cloud Function ✅
- [ ] PR #13: Summary UI ✅

### Phase 5: Polish (Week 7)
- [ ] PR #14: Performance Optimization ✅
- [ ] PR #15: Error Handling ✅
- [ ] PR #16: UI/UX Polish ✅
- [ ] PR #17: Testing & Bugs ✅
- [ ] PR #18: Documentation ✅

### Phase 6: Deployment (Week 7-8)
- [ ] PR #19: Demo Prep ✅
- [ ] PR #20: TestFlight Deploy ✅

### Phase 7: Deliverables (Week 8)
- [ ] PR #21: Persona Brainlift ✅
- [ ] PR #22: Social Post ✅
- [ ] PR #23: Final Cleanup ✅

---

## Git Workflow Guide

### Branch Naming Convention
```
feature/    - New features
bugfix/     - Bug fixes
chore/      - Maintenance tasks
docs/       - Documentation
release/    - Release preparation
```

### Commit Message Format
```
[Type] Brief description

Detailed explanation if needed

- List of changes
- Another change
```

**Types:** feat, fix, docs, style, refactor, test, chore

### Example Workflow
```bash
# Start new feature
git checkout -b feature/audio-recording
git add Services/AudioRecordingService.swift
git commit -m "[feat] Add AudioRecordingService

Implements core audio recording functionality:
- AVAudioSession configuration
- Start/stop recording
- Save to local file
- Permission handling
"
git push origin feature/audio-recording

# Create PR on GitHub
# After review and approval, merge to main
```

---

## Cost Tracking Per PR

### API Costs by Phase

**Phase 2 (Transcription):**
- Testing: ~$5 (OpenAI Whisper)
- Per PR: Minimal (20-30 test transcriptions)

**Phase 3 (Voice Cloning & TTS):**
- Testing: ~$20 (ElevenLabs)
- Voice cloning: $0 (included)
- TTS testing: ~50 generations = $7.50

**Phase 4 (Summaries):**
- Testing: ~$3 (GPT-4o-mini + ElevenLabs)
- Per PR: Minimal (10-15 test summaries)

**Total Development Budget:** ~$50

---

## Testing Checklist Per PR

Before merging each PR, verify:

- [ ] **Builds successfully** in Xcode
- [ ] **No Swift warnings** or errors
- [ ] **All new functions have documentation**
- [ ] **Functionality works as expected**
- [ ] **No regressions** in existing features
- [ ] **UI looks correct** on multiple device sizes
- [ ] **Memory leaks checked** (Instruments)
- [ ] **Network failures handled**
- [ ] **Edge cases tested** (empty states, errors)
- [ ] **Code reviewed** by team (or self-review)

---

## Quick Reference: Files by Feature

### Voice Recording (PRs 3-6)
- `Services/AudioRecordingService.swift`
- `ViewModels/VoiceRecorderViewModel.swift`
- `Views/Voice/VoiceRecordingView.swift`
- `Views/Voice/WaveformView.swift`
- `Views/Chat/VoiceMessageInputView.swift`
- `CloudFunctions/functions/src/transcription.ts`

### Voice Cloning (PRs 7-9)
- `Views/Voice/VoiceCloningSetupView.swift`
- `ViewModels/VoiceClonerViewModel.swift`
- `CloudFunctions/functions/src/voiceCloning.ts`

### Text-to-Speech (PRs 10-11)
- `Services/AudioPlaybackService.swift`
- `ViewModels/AudioPlayerViewModel.swift`
- `Views/Chat/MessageAudioPlayerView.swift`
- `CloudFunctions/functions/src/textToSpeech.ts`

### Summaries (PRs 12-13)
- `ViewModels/ConversationSummaryViewModel.swift`
- `Views/Summary/ConversationSummaryView.swift`
- `CloudFunctions/functions/src/summarization.ts`
- `Models/ConversationAudio.swift`

---

## Total Estimated Time

| Phase | PRs | Estimated Hours |
|-------|-----|-----------------|
| Phase 1: Foundation | 2 | 6-9 hours |
| Phase 2: Recording | 4 | 26-34 hours |
| Phase 3: TTS | 5 | 40-50 hours |
| Phase 4: Summaries | 2 | 20-24 hours |
| Phase 5: Polish | 5 | 36-46 hours |
| Phase 6: Deploy | 2 | 10-14 hours |
| Phase 7: Docs | 3 | 5-8 hours |
| **TOTAL** | **23 PRs** | **143-185 hours** |

**Timeline:** 7-8 weeks at 20-25 hours/week

---

## Emergency Shortcuts (If Behind Schedule)

### Can Skip Without Breaking MVP:
- PR #16 (UI/UX Polish) - Nice to have
- PR #18 (Documentation) - Can do after MVP
- PR #14 (Performance) - Optimize later
- Waveform visualization - Use simple timer instead

### Cannot Skip:
- Any Cloud Function PRs (core functionality)
- Any Service/ViewModel PRs (core functionality)
- PR #20 (TestFlight) - Required for submission
- PR #21-22 (Deliverables) - Required by rubric

### If Really Tight on Time:
**Focus on Phase 1-3 only** (Voice-to-Text + TTS)
- Skip Phase 4 (Summaries) entirely
- Still impressive: voice cloning alone is unique
- Can add summaries post-MVP

---

## Success Metrics

Track these after each phase:

**Phase 2 Complete:**
- [ ] Can record voice message
- [ ] Transcription accuracy >90%
- [ ] Latency <3 seconds

**Phase 3 Complete:**
- [ ] Voice cloning works
- [ ] TTS sounds like user (>80% similarity)
- [ ] Every message playable

**Phase 4 Complete:**
- [ ] Summaries capture key points
- [ ] Audio narration clear
- [ ] Generation <10 seconds

**Final:**
- [ ] All features work end-to-end
- [ ] No critical bugs
- [ ] Demo video recorded
- [ ] Rubric score 100+ points