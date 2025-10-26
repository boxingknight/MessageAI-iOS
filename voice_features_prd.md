# Product Requirements Document (PRD)
## Voice Features for MessageAI - Busy Parent/Caregiver Edition

**Version:** 1.0  
**Date:** October 25, 2025  
**Owner:** [Your Name]  
**Status:** Draft for Review

---

## 1. Executive Summary

### Vision
Transform MessageAI into the first truly hands-free family messaging platform by integrating voice AI capabilities that allow busy parents to send, receive, and comprehend messages without ever looking at their phone.

### Problem Statement
Busy parents and caregivers face constant communication demands while juggling multiple responsibilities (driving, cooking, childcare, work). Current messaging apps require:
- Eyes on screen to read messages
- Hands free to type responses
- Undivided attention to parse long group threads

This creates dangerous situations (texting while driving), missed information (can't read during tasks), and mental overload (100+ unread messages).

### Solution
Three-phased voice AI system:
1. **Voice-to-Text:** Speak messages, AI transcribes instantly
2. **Text-to-Voice:** Every message playable in sender's cloned voice
3. **Conversation Audio:** Listen to entire group chats or AI summaries

### Success Metrics
- 60%+ of users enable voice features within first week
- 40%+ reduction in average message response time
- 80%+ user satisfaction with voice quality (>4/5 rating)
- Demo video views spike (target: 10k+ views on social)
- Rubric score: 100+ points (A+ with innovation bonuses)

---

## 2. User Stories

### Persona: Sarah - Working Parent with 2 Kids in Activities

**Background:** 38-year-old marketing manager, two kids (ages 7 and 10) in soccer and dance. Juggles work meetings, school pickups, activity coordination, and household management. In 5 different group chats (soccer team parents, dance moms, school PTA, family, neighbors).

#### User Stories:

**US-1: Hands-Free Messaging While Driving**
```
AS Sarah driving to pick up kids from soccer practice
I WANT TO send a message to the team parents without typing
SO THAT I can notify them I'm running late without endangering my family
```
**Acceptance Criteria:**
- Can record voice message with single tap-and-hold
- Transcription appears within 2 seconds of finishing recording
- Can review and edit transcript before sending
- Can cancel recording by swiping/sliding
- Audio quality sufficient for accurate transcription (95%+ accuracy)

**US-2: Listening to Messages While Cooking**
```
AS Sarah preparing dinner with messy hands
I WANT TO hear text messages read aloud
SO THAT I can stay updated on important family coordination without stopping what I'm doing
```
**Acceptance Criteria:**
- Every text message has visible "play" button/icon
- Tapping play speaks message in sender's voice (or default if not cloned)
- Audio is clear and natural-sounding
- Playback speed adjustable (1x, 1.5x, 2x)
- Can pause/resume playback

**US-3: Catching Up on Group Chat During Commute**
```
AS Sarah with 47 unread messages in soccer parents group
I WANT TO listen to a summary of the conversation
SO THAT I can understand decisions made without reading 47 individual messages
```
**Acceptance Criteria:**
- Can trigger summary generation with single tap
- AI extracts key decisions, action items, and dates
- Summary audio is 2-3 minutes max for 50+ message threads
- Includes who's responsible for what
- Option to listen to full conversation or just summary

**US-4: Personal Voice for Authenticity**
```
AS Sarah who wants her family to hear HER voice in messages
I WANT TO clone my voice once and have it used automatically
SO THAT my messages feel personal even when AI-generated
```
**Acceptance Criteria:**
- Voice cloning setup takes <5 minutes
- Recording sample is 30-60 seconds max
- Cloned voice sounds recognizably like user (80%+ similarity)
- Can preview voice before confirming
- Can re-record if unhappy with result

**US-5: Managing Multiple Group Conversations Efficiently**
```
AS Sarah in 5 active group chats simultaneously
I WANT TO quickly understand which conversations need my attention
SO THAT I can prioritize responses without reading everything
```
**Acceptance Criteria:**
- Can see which threads have new voice messages vs. text
- Can play conversation summaries for each group
- Visual indicators for urgent/priority messages
- Can queue multiple summaries to listen back-to-back

---

### Persona: Marcus - Single Dad with Shared Custody

**Background:** 42-year-old software engineer, shares custody of 8-year-old daughter Emma. Coordinates heavily with ex-wife, Emma's school, after-school program, and his own parents who help with childcare.

#### User Stories:

**US-6: Quick Voice Responses During Work Meetings**
```
AS Marcus in a work meeting when urgent message arrives
I WANT TO send quick voice response discreetly
SO THAT I can coordinate Emma's pickup without disrupting my meeting
```
**Acceptance Criteria:**
- Can record voice in low volume/whisper
- Transcription works with whispered speech
- Can send text-only (no audio attachment) for discretion
- <3 second turnaround from record to send

**US-7: Bedtime Stories When Traveling**
```
AS Marcus traveling for work and missing Emma's bedtime
I WANT TO send bedtime story read in my voice
SO THAT Emma can hear daddy's voice even when I'm away
```
**Acceptance Criteria:**
- Can record longer voice messages (3-5 minutes)
- High audio quality for emotional content
- Ex-wife can easily play for Emma
- Audio saved permanently (not auto-deleted)

**US-8: Voice Accessibility for Emma (Child User)**
```
AS Emma who is learning to read but not fluent yet
I WANT TO hear daddy's messages read aloud
SO THAT I can understand what he's saying without asking mom to read it
```
**Acceptance Criteria:**
- Simple, large "play" button child can tap
- Auto-plays in parent's voice by default
- No complex controls that confuse children
- Works offline (cached audio)

---

### Persona: Aisha - Caregiver for Aging Parents

**Background:** 55-year-old nurse, caring for mother (82) with vision impairment and father (85) with mild cognitive decline. Coordinates with siblings, home health aides, and medical providers.

#### User Stories:

**US-9: Accessibility for Vision-Impaired Parent**
```
AS Aisha's mother who cannot read small text on phone
I WANT TO hear all messages read aloud automatically
SO THAT I can stay connected with family without straining my eyes
```
**Acceptance Criteria:**
- Settings option for "auto-play all messages"
- Messages play immediately upon arrival
- High volume and slow speed options
- Works with phone accessibility features (VoiceOver, TalkBack)

**US-10: Medical Coordination with Multiple Caregivers**
```
AS Aisha coordinating home care schedule with 3 siblings
I WANT TO listen to family group updates during my commute
SO THAT I stay informed without dedicating screen time
```
**Acceptance Criteria:**
- Can subscribe to specific groups for auto-summaries
- Daily digest option (morning or evening summary)
- Highlights medical/urgent information
- Distinguishes between different family member voices

---

## 3. Key Features Required for MVP

### Phase 1: Voice-to-Text (Foundation) - **MUST HAVE**

#### Feature 1.1: Voice Message Recording
**Priority:** P0 (Critical)

**Description:** User can record voice message and receive instant transcription.

**Functional Requirements:**
- Long-press microphone icon to record
- Visual feedback (waveform, timer) during recording
- Release to stop, swipe left to cancel
- Maximum recording length: 2 minutes (safety limit)
- Audio format: M4A or MP3
- File size limit: 10MB

**Technical Requirements:**
- Use device native audio recording APIs
- Stream audio to backend for transcription
- Display transcription within 2 seconds of completion
- Handle network failures gracefully (queue for later transcription)

**UX Requirements:**
- Haptic feedback on press/release
- Clear "Recording..." indicator
- Waveform visualization
- Timer display (00:00 format)
- Cancel affordance clearly visible

**Acceptance Criteria:**
- [ ] 95%+ transcription accuracy for clear speech
- [ ] <2 second latency for transcription
- [ ] Works on iOS and Android
- [ ] Handles background noise reasonably
- [ ] Graceful degradation if API fails

---

#### Feature 1.2: Transcription Display & Editing
**Priority:** P0 (Critical)

**Description:** Show transcription result with editing capability before sending.

**Functional Requirements:**
- Display transcript in message input field
- Allow user to edit text before sending
- Show confidence indicator (Good/Fair/Poor)
- Option to listen to original audio
- Can discard and re-record

**UX Requirements:**
- Transcript appears with typing cursor at end
- "✓ Transcribed" or "⚠ Low confidence" indicator
- Edit button with keyboard icon
- Re-record button with microphone icon
- Send button (only enabled after review)

**Acceptance Criteria:**
- [ ] User can edit any word in transcript
- [ ] Original audio preserved if user wants to include it
- [ ] Can choose to send: text-only, audio-only, or both
- [ ] Low-confidence transcriptions flagged for review

---

#### Feature 1.3: Message Storage (Text + Audio)
**Priority:** P0 (Critical)

**Description:** Store both audio file and transcript with message.

**Database Schema:**
```sql
ALTER TABLE messages ADD COLUMN audio_url TEXT;
ALTER TABLE messages ADD COLUMN transcript TEXT;
ALTER TABLE messages ADD COLUMN audio_duration INTEGER; -- seconds
ALTER TABLE messages ADD COLUMN transcription_confidence FLOAT; -- 0-1
```

**Technical Requirements:**
- Upload audio to cloud storage (S3, Cloudflare R2, Firebase Storage)
- Store URL in database
- Enable offline access (cache audio locally)
- Auto-delete audio after 30 days (configurable) to save storage

**Acceptance Criteria:**
- [ ] Audio accessible via URL
- [ ] Transcript searchable
- [ ] Both linked to same message entity
- [ ] Offline playback works

---

### Phase 2: Text-to-Voice (Voice Cloning) - **MUST HAVE**

#### Feature 2.1: Voice Profile Setup
**Priority:** P0 (Critical)

**Description:** One-time voice cloning setup for each user.

**Functional Requirements:**
- User records 30-60 second voice sample
- Sample text provided (pangram or conversational script)
- Submit to ElevenLabs for voice cloning
- Store voice_id in user profile
- Preview cloned voice before confirming

**User Flow:**
```
Settings → Voice Profile → "Set Up My Voice"
→ Read sample text (30-60s)
→ Submit for processing (15-30s wait)
→ "Listen to Preview"
→ Confirm or Re-record
→ Voice active
```

**Sample Text (30-second script):**
```
"Hi, this is [Name]. I'm setting up my voice for MessageAI. 
This voice will be used to read my messages aloud to my family. 
I can speak naturally, just like I'm talking to a friend. 
The quick brown fox jumps over the lazy dog. 
Thanks for setting this up with me!"
```

**Technical Requirements:**
- ElevenLabs Voice Design API integration
- Store voice_id in users table
- Handle API failures (retry logic)
- Cost: ~$0 per voice (included in ElevenLabs plan)

**Acceptance Criteria:**
- [ ] Setup takes <5 minutes end-to-end
- [ ] Cloned voice sounds recognizable (80%+ user satisfaction)
- [ ] Can re-do voice cloning if unsatisfied
- [ ] Works for various accents and ages
- [ ] Fallback to default voice if cloning fails

---

#### Feature 2.2: Text-to-Speech Generation
**Priority:** P0 (Critical)

**Description:** Generate audio for any text message using sender's cloned voice.

**Functional Requirements:**
- Every text message gets "play" button/icon
- On first tap: generate audio (if not cached)
- On subsequent taps: play cached audio
- Uses sender's voice_id if available, else default voice
- Shows "Generating..." indicator (1-3 seconds)

**Technical Requirements:**
```javascript
// API call
POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}
{
  "text": message.content,
  "model_id": "eleven_multilingual_v2",
  "voice_settings": {
    "stability": 0.5,
    "similarity_boost": 0.8
  }
}
```

**Caching Strategy:**
- Generate audio on first play request
- Upload to cloud storage
- Cache URL in messages.audio_url
- Serve from cache for future plays
- Cache locally on device for offline playback

**Cost Considerations:**
- ElevenLabs TTS: ~$0.30 per 1,000 characters
- Average message: 50 characters = $0.015 per message
- Cache aggressively to minimize regeneration
- Budget: $100/month = ~6,600 message plays

**Acceptance Criteria:**
- [ ] Audio generation <3 seconds
- [ ] Voice quality matches original (80%+ similarity)
- [ ] Cached plays are instant
- [ ] Works offline with cached audio
- [ ] Graceful error handling (show text if audio fails)

---

#### Feature 2.3: Audio Playback Controls
**Priority:** P1 (High)

**Description:** Full-featured audio player for voice messages.

**Functional Requirements:**
- Play/Pause button
- Seek bar (scrub through audio)
- Playback speed (1x, 1.25x, 1.5x, 2x)
- Time display (current / total)
- Waveform visualization (optional, P2)

**UX Requirements:**
- Inline player (doesn't navigate away)
- Continues playing while scrolling
- Pause if new audio starts
- Keyboard shortcuts (spacebar = play/pause)

**Technical Requirements:**
- Native audio player APIs
- Background audio support (iOS/Android)
- Lock screen controls
- Bluetooth/CarPlay integration

**Acceptance Criteria:**
- [ ] Smooth playback, no stuttering
- [ ] Seek bar responsive
- [ ] Speed changes don't restart audio
- [ ] Works with device volume controls
- [ ] Pauses automatically for phone calls

---

### Phase 3: Conversation Audio (Choose One) - **SHOULD HAVE**

#### Option A: Multi-Voice Conversation Playback
**Priority:** P1 (High Impact, but complex)

**Description:** Generate podcast-style audio of entire group conversation with unique voice for each participant.

**Functional Requirements:**
- "🎧 Play Conversation" button on group chats
- Select message range (e.g., "Last 50 messages" or "Since yesterday")
- AI generates multi-voice audio with each person's cloned voice
- Visual timeline showing current speaker
- Scrub through conversation by speaker

**Technical Requirements:**
- Batch TTS generation for all messages
- Audio stitching (ffmpeg or similar)
- Insert 300ms silence between speakers
- Generate speaker timeline (who speaks when)
- Total processing time: <30 seconds for 50 messages

**Technical Challenges:**
- **Audio stitching complexity:** Need backend processing
- **Cost:** 50 messages × 50 chars = 2,500 chars = $0.75 per conversation
- **Storage:** Large audio files (5-10MB per conversation)
- **Processing time:** May take 20-30 seconds for long threads

**Acceptance Criteria:**
- [ ] Distinct voices for each participant (minimum 3 voices)
- [ ] Smooth transitions between speakers
- [ ] Visual timeline accurate
- [ ] Generation completes in <30 seconds
- [ ] Audio quality matches individual TTS

**MVP Simplification:**
- Limit to 30 messages max per playback
- Pre-process on backend (not real-time)
- Cache generated audio for 24 hours
- Fallback to summary if stitching fails

---

#### Option B: AI Summary Audio (**RECOMMENDED FOR MVP**)
**Priority:** P1 (High Impact, simpler)

**Description:** Generate narrated summary of long group conversations.

**Functional Requirements:**
- "🎙️ Hear Summary" button appears when thread >20 messages
- AI summarizes key points, decisions, action items
- Professional narrator voice reads summary
- 2-3 minute max duration for any thread length
- Option to read text summary or listen

**Technical Requirements:**
```javascript
// Step 1: GPT-4 Summarization
const summary = await openai.chat.completions.create({
  model: 'gpt-4',
  messages: [
    {
      role: 'system',
      content: `Summarize this group chat for a busy parent. 
                Focus on: decisions made, action items, who's doing what, 
                dates/times, and urgent information.
                Structure: Overview → Decisions → Action Items → Dates.
                Max 300 words. Conversational tone for audio narration.`
    },
    { role: 'user', content: conversationText }
  ]
});

// Step 2: TTS Generation
const audio = await elevenLabs.textToSpeech({
  text: summary,
  voice_id: 'professional_narrator', // ElevenLabs pre-made voice
  model_id: 'eleven_multilingual_v2'
});
```

**Cost Analysis:**
- GPT-4: ~$0.03 per 1k tokens (input) + $0.06 per 1k tokens (output)
- 50 messages = ~2k input tokens + ~300 output tokens = $0.078
- TTS: 300 words = ~1,500 chars = $0.45
- **Total per summary: ~$0.53**
- Budget: $100/month = ~190 summaries

**Acceptance Criteria:**
- [ ] Summary captures all key information
- [ ] Audio narration is natural and professional
- [ ] Generation completes in <10 seconds
- [ ] Summary text also displayed for reading
- [ ] Works for threads of 20-200 messages

**Why This Over Option A:**
- ✅ 60% cheaper per use
- ✅ 3x faster generation
- ✅ Simpler technical implementation (no audio stitching)
- ✅ More practical for daily use (parents want key info, not full playback)
- ✅ Still impressive for demo
- ✅ Can add Option A later as premium feature

---

## 4. Tech Stack

### ✅ **CONFIRMED STACK**

---

### Frontend: Native iOS (Swift + SwiftUI)

**Why Swift:**
- ✅ Already chosen by team
- ✅ Best performance and battery efficiency
- ✅ Full access to iOS native features
- ✅ Smallest app size (~10-15MB)
- ✅ Superior audio handling with AVFoundation
- ✅ Seamless integration with iOS ecosystem

**Audio Framework:**
- **AVFoundation** (Apple's native audio framework)
  - `AVAudioRecorder` for voice recording
  - `AVAudioPlayer` for playback
  - `AVAudioEngine` for advanced audio processing
  - Native noise suppression and echo cancellation
  - Background audio support built-in
  - CarPlay integration ready

**Key Swift Libraries:**
```swift
// Audio Recording & Playback
import AVFoundation

// Firebase Integration
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// Networking
import Alamofire // or native URLSession

// UI
import SwiftUI
import Combine
```

**iOS Version Target:**
- Minimum: iOS 16.0 (covers 95%+ of users)
- Target: iOS 17.0+ for latest features
- Voice features work on iOS 16+

**Important Considerations:**
- ⚠️ **iOS-only for MVP** (no Android)
- ⚠️ Need separate Android implementation later (Kotlin + Jetpack Compose)
- ⚠️ TestFlight for beta testing (100 external testers free)
- ⚠️ App Store review time (~24-48 hours)

---

### Backend: Firebase (Serverless)

**Why Firebase:**
- ✅ Already chosen by team
- ✅ Zero server management
- ✅ Excellent Swift SDK
- ✅ Real-time database & WebSocket built-in
- ✅ Integrated auth, storage, and database
- ✅ Free tier generous (good for MVP)

**Firebase Services Used:**

#### 1. Firebase Authentication
```swift
import FirebaseAuth

// User auth (existing)
Auth.auth().currentUser
```

#### 2. Firebase Firestore (Database)
```swift
import FirebaseFirestore

// Existing schema + voice additions
db.collection("users").document(userId).updateData([
    "elevenLabsVoiceId": voiceId,
    "voiceSampleUrl": url,
    "voiceCloningCompletedAt": Timestamp()
])

db.collection("messages").document(messageId).updateData([
    "audioUrl": url,
    "transcript": text,
    "audioDuration": seconds,
    "transcriptionConfidence": confidence
])
```

**Firestore Schema Updates:**
```
users/
  {userId}/
    name: string
    email: string
    photoUrl: string
    elevenLabsVoiceId: string? (NEW)
    voiceSampleUrl: string? (NEW)
    voiceCloningCompletedAt: timestamp? (NEW)
    createdAt: timestamp

messages/
  {messageId}/
    conversationId: string
    senderId: string
    content: string
    audioUrl: string? (NEW)
    transcript: string? (NEW)
    audioDuration: number? (NEW - seconds)
    transcriptionConfidence: number? (NEW - 0-1)
    sentAt: timestamp
    deliveredAt: timestamp?
    readAt: timestamp?

conversationAudio/ (NEW COLLECTION)
  {audioId}/
    conversationId: string
    type: string ("summary" | "full_conversation")
    audioUrl: string
    summaryText: string?
    messageCount: number
    duration: number
    createdAt: timestamp
    expiresAt: timestamp
```

#### 3. Firebase Storage
```swift
import FirebaseStorage

// Audio file storage
let storageRef = Storage.storage().reference()
let audioRef = storageRef.child("audio/\(userId)/\(messageId).m4a")

// Upload
audioRef.putFile(from: localURL) { metadata, error in
    // Get download URL
    audioRef.downloadURL { url, error in
        // Save URL to Firestore
    }
}
```

**Storage Structure:**
```
audio/
  {userId}/
    {messageId}.m4a (voice recordings)
    voice_sample.m4a (for cloning)
  summaries/
    {conversationId}_{timestamp}.mp3 (generated audio)
```

#### 4. Firebase Cloud Functions (Serverless Backend)
```javascript
// Node.js functions for API calls
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Transcription endpoint
exports.transcribeAudio = functions.https.onCall(async (data, context) => {
    const { audioUrl } = data;
    
    // Call OpenAI Whisper
    const transcript = await callWhisperAPI(audioUrl);
    
    return { transcript };
});

// Voice cloning endpoint
exports.cloneVoice = functions.https.onCall(async (data, context) => {
    const { audioUrl, userId } = data;
    
    // Call ElevenLabs
    const voiceId = await callElevenLabsCloning(audioUrl);
    
    // Save to Firestore
    await admin.firestore().collection('users').doc(userId).update({
        elevenLabsVoiceId: voiceId
    });
    
    return { voiceId };
});

// TTS generation endpoint
exports.generateTTS = functions.https.onCall(async (data, context) => {
    const { text, voiceId } = data;
    
    // Call ElevenLabs TTS
    const audioBuffer = await callElevenLabsTTS(text, voiceId);
    
    // Upload to Firebase Storage
    const audioUrl = await uploadToStorage(audioBuffer);
    
    return { audioUrl };
});

// Summary generation endpoint
exports.generateSummary = functions.https.onCall(async (data, context) => {
    const { messages } = data;
    
    // Call OpenAI GPT
    const summary = await callGPTSummary(messages);
    
    // Generate audio
    const audioUrl = await callElevenLabsTTS(summary.text);
    
    return { summary: summary.text, audioUrl };
});
```

**Why Cloud Functions:**
- ✅ Keep API keys secure (never in client)
- ✅ Serverless (auto-scales, pay per use)
- ✅ Node.js = easy to write
- ✅ Integrated with Firebase ecosystem
- ✅ No server management

**Cloud Functions Setup:**
```bash
firebase init functions
cd functions
npm install openai @elevenlabs/api
firebase deploy --only functions
```

---

### Backend: Firebase Alternatives Considered ❌

**Option: Custom Node.js Backend**
- ❌ Rejected: Firebase already chosen, adds complexity
- ❌ Would need separate server hosting
- ❌ More infrastructure to manage

**Option: Firebase Realtime Database**
- ❌ Rejected: Firestore is better for complex queries
- ❌ Less flexible data structure

**Stick with Firebase Firestore + Cloud Functions**

---

### AI Services

#### ✅ Speech-to-Text: OpenAI Whisper API

**Already have OpenAI key ✅**

**Implementation:**
```swift
// Swift client calling Cloud Function
func transcribeAudio(audioURL: URL) async throws -> String {
    let functions = Functions.functions()
    let transcribe = functions.httpsCallable("transcribeAudio")
    
    let result = try await transcribe.call(["audioUrl": audioURL.absoluteString])
    return result.data["transcript"] as! String
}
```

```javascript
// Cloud Function (Node.js)
const { OpenAI } = require('openai');
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

exports.transcribeAudio = functions.https.onCall(async (data, context) => {
    const { audioUrl } = data;
    
    // Download audio from Firebase Storage
    const audioBuffer = await downloadFromStorage(audioUrl);
    
    // Create temp file
    const tempFile = `/tmp/${Date.now()}.m4a`;
    fs.writeFileSync(tempFile, audioBuffer);
    
    // Transcribe with Whisper
    const transcription = await openai.audio.transcriptions.create({
        file: fs.createReadStream(tempFile),
        model: 'whisper-1',
        language: 'en', // or auto-detect
        response_format: 'verbose_json' // includes confidence
    });
    
    // Cleanup
    fs.unlinkSync(tempFile);
    
    return {
        transcript: transcription.text,
        confidence: transcription.segments?.[0]?.confidence || 1.0
    };
});
```

**Pricing:**
- $0.006 per minute
- Average 30-second voice message = $0.003
- Budget: $50/month = 16,666 transcriptions

**Pros:**
- ✅ Best accuracy (95%+)
- ✅ Handles accents, noise well
- ✅ Fast (1-3 seconds)
- ✅ 100+ languages
- ✅ Already have API key

---

#### ✅ Text-to-Speech & Voice Cloning: ElevenLabs

**Need to set up ElevenLabs account**

**Swift Implementation:**
```swift
// Voice cloning setup
func cloneVoice(audioURL: URL) async throws -> String {
    let functions = Functions.functions()
    let clone = functions.httpsCallable("cloneVoice")
    
    let result = try await clone.call([
        "audioUrl": audioURL.absoluteString,
        "userId": Auth.auth().currentUser!.uid
    ])
    
    return result.data["voiceId"] as! String
}

// Generate TTS
func generateTTS(text: String, voiceId: String) async throws -> URL {
    let functions = Functions.functions()
    let generate = functions.httpsCallable("generateTTS")
    
    let result = try await generate.call([
        "text": text,
        "voiceId": voiceId
    ])
    
    let audioUrlString = result.data["audioUrl"] as! String
    return URL(string: audioUrlString)!
}
```

**Cloud Function Implementation:**
```javascript
const { ElevenLabsClient } = require('@elevenlabs/api');
const elevenlabs = new ElevenLabsClient({ 
    apiKey: process.env.ELEVENLABS_API_KEY 
});

// Voice cloning
exports.cloneVoice = functions.https.onCall(async (data, context) => {
    const { audioUrl, userId } = data;
    
    // Download audio sample from Firebase Storage
    const audioBuffer = await downloadFromStorage(audioUrl);
    
    // Clone voice with ElevenLabs
    const voice = await elevenlabs.voices.add({
        name: `user_${userId}`,
        files: [audioBuffer],
        description: 'MessageAI user voice'
    });
    
    // Save voice_id to Firestore
    await admin.firestore().collection('users').doc(userId).update({
        elevenLabsVoiceId: voice.voice_id,
        voiceCloningCompletedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return { voiceId: voice.voice_id };
});

// Text-to-Speech
exports.generateTTS = functions.https.onCall(async (data, context) => {
    const { text, voiceId, messageId } = data;
    
    // Check cache first
    const messageRef = admin.firestore().collection('messages').doc(messageId);
    const messageDoc = await messageRef.get();
    
    if (messageDoc.data()?.audioUrl) {
        return { audioUrl: messageDoc.data().audioUrl };
    }
    
    // Generate audio with ElevenLabs
    const audio = await elevenlabs.textToSpeech.convert(voiceId, {
        text: text,
        model_id: 'eleven_multilingual_v2',
        voice_settings: {
            stability: 0.5,
            similarity_boost: 0.8,
            style: 0.0,
            use_speaker_boost: true
        }
    });
    
    // Convert stream to buffer
    const chunks = [];
    for await (const chunk of audio) {
        chunks.push(chunk);
    }
    const audioBuffer = Buffer.concat(chunks);
    
    // Upload to Firebase Storage
    const bucket = admin.storage().bucket();
    const file = bucket.file(`audio/tts/${messageId}.mp3`);
    await file.save(audioBuffer, { contentType: 'audio/mpeg' });
    
    // Make publicly accessible (or use signed URL)
    await file.makePublic();
    const audioUrl = file.publicUrl();
    
    // Cache URL in Firestore
    await messageRef.update({ audioUrl });
    
    return { audioUrl };
});
```

**Pricing:**
- Voice cloning: Free (included in plan)
- TTS: $0.30 per 1,000 characters
- Average message: 50 chars = $0.015
- Budget: $100/month = 333,333 characters = 6,666 messages

**Plan Recommendation:**
- Start with **Starter plan** ($5/month)
  - 30,000 characters included
  - Then $0.30 per 1k characters
- Upgrade to **Creator** ($22/month) if needed
  - 100,000 characters included
  - Then $0.24 per 1k characters (20% discount)

---

#### ✅ LLM for Summaries: OpenAI GPT-4o-mini

**Already have OpenAI key ✅**

**Implementation:**
```javascript
// Cloud Function
exports.generateSummary = functions.https.onCall(async (data, context) => {
    const { conversationId, messageRange } = data;
    
    // Fetch messages from Firestore
    const messagesSnapshot = await admin.firestore()
        .collection('messages')
        .where('conversationId', '==', conversationId)
        .where('sentAt', '>=', messageRange.start)
        .where('sentAt', '<=', messageRange.end)
        .orderBy('sentAt', 'asc')
        .get();
    
    // Format conversation
    const conversation = messagesSnapshot.docs.map(doc => {
        const msg = doc.data();
        return `${msg.senderName}: ${msg.content}`;
    }).join('\n');
    
    // Generate summary with GPT-4o-mini
    const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
            {
                role: 'system',
                content: `You are summarizing a group chat for a busy parent. 
                         Focus on: decisions made, action items, who's doing what, 
                         important dates/times, and urgent information.
                         Structure: Brief overview, then key points.
                         Max 200 words. Conversational tone for audio narration.`
            },
            {
                role: 'user',
                content: `Summarize this conversation:\n\n${conversation}`
            }
        ],
        temperature: 0.7,
        max_tokens: 400
    });
    
    const summaryText = completion.choices[0].message.content;
    
    // Generate audio with ElevenLabs
    const audio = await elevenlabs.textToSpeech.convert(
        'professional_narrator_voice_id', // Use pre-made ElevenLabs voice
        {
            text: summaryText,
            model_id: 'eleven_multilingual_v2'
        }
    );
    
    // Upload audio
    const audioBuffer = await streamToBuffer(audio);
    const audioUrl = await uploadToStorage(audioBuffer, `summaries/${conversationId}_${Date.now()}.mp3`);
    
    // Save to Firestore
    await admin.firestore().collection('conversationAudio').add({
        conversationId,
        type: 'summary',
        summaryText,
        audioUrl,
        messageCount: messagesSnapshot.size,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days
        )
    });
    
    return { summaryText, audioUrl };
});
```

**Pricing:**
- GPT-4o-mini: $0.15 per 1M input tokens, $0.60 per 1M output tokens
- 50-message thread: ~2k input tokens, ~300 output tokens
- Cost per summary: ~$0.0005 (basically free!)
- Budget: $50/month = 100,000 summaries (won't hit this)

**Why GPT-4o-mini vs GPT-4:**
- ✅ 30x cheaper
- ✅ Faster responses
- ✅ 95% as good for summaries
- ✅ Good enough for MVP
- Can upgrade to GPT-4 later if needed

---

### Database: Firebase Firestore

**Already using Firebase ✅**

**Schema Design Philosophy:**
- Denormalize for read performance (Firestore best practice)
- Use subcollections for large lists
- Index frequently queried fields
- Use serverTimestamp() for consistency

**Firestore Security Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own profile
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // Messages: only conversation participants can read/write
    match /messages/{messageId} {
      allow read: if request.auth != null && 
                     isConversationMember(resource.data.conversationId);
      allow create: if request.auth != null && 
                       request.auth.uid == request.resource.data.senderId;
      allow update: if request.auth.uid == resource.data.senderId;
    }
    
    // Conversation audio: only participants can access
    match /conversationAudio/{audioId} {
      allow read: if request.auth != null && 
                     isConversationMember(resource.data.conversationId);
      allow create: if request.auth != null;
    }
    
    function isConversationMember(conversationId) {
      return exists(/databases/$(database)/documents/conversations/$(conversationId)/members/$(request.auth.uid));
    }
  }
}
```

---

### File Storage: Firebase Storage

**Already using Firebase ✅**

**Storage Structure:**
```
/audio/
  /recordings/
    /{userId}/
      {messageId}.m4a (voice recordings)
      voice_sample.m4a (for cloning)
  /tts/
    {messageId}.mp3 (generated TTS audio)
  /summaries/
    {conversationId}_{timestamp}.mp3 (summary audio)
```

**Storage Rules:**
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Voice recordings: only owner can write, participants can read
    match /audio/recordings/{userId}/{allPaths=**} {
      allow write: if request.auth.uid == userId;
      allow read: if request.auth != null;
    }
    
    // TTS audio: anyone authenticated can read (cached)
    match /audio/tts/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if false; // Only Cloud Functions can write
    }
    
    // Summaries: conversation participants can read
    match /audio/summaries/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if false; // Only Cloud Functions can write
    }
  }
}
```

**Cost Optimization:**
- Auto-delete old files with lifecycle rules
- Compress audio before upload (AAC codec for recordings)
- Use Cloud Functions to manage storage (delete expired files)

---

### Real-Time Communication: Firebase Realtime Database (for WebSocket)

**For real-time presence and typing indicators:**

```swift
import FirebaseDatabase

// Presence system
let presenceRef = Database.database().reference(withPath: "presence/\(userId)")
presenceRef.onDisconnectRemoveValue()
presenceRef.setValue(["online": true, "lastSeen": ServerValue.timestamp()])

// Typing indicators
let typingRef = Database.database().reference(withPath: "typing/\(conversationId)/\(userId)")
typingRef.setValue(true)
DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
    typingRef.removeValue()
}
```

**Why Realtime Database for presence:**
- ✅ Better for real-time ephemeral data
- ✅ Automatic onDisconnect handling
- ✅ Lower latency than Firestore for presence
- ✅ Free tier sufficient for MVP

---

## Tech Stack Summary

| Component | Technology | Why |
|-----------|-----------|-----|
| **Mobile App** | Swift + SwiftUI | Native performance, team choice |
| **Audio Recording** | AVFoundation | Best iOS audio framework |
| **Backend** | Firebase Cloud Functions | Serverless, secure API key handling |
| **Database** | Firebase Firestore | Already in use, real-time sync |
| **File Storage** | Firebase Storage | Integrated, CDN included |
| **Authentication** | Firebase Auth | Already in use |
| **Real-Time** | Firebase Realtime DB | Presence & typing indicators |
| **Speech-to-Text** | OpenAI Whisper | Best accuracy, have API key |
| **Text-to-Speech** | ElevenLabs | Best voice cloning |
| **Voice Cloning** | ElevenLabs | Industry-leading quality |
| **LLM (Summaries)** | GPT-4o-mini | Cheap, fast, good enough |

---

## Swift + Firebase Architecture

```
┌─────────────────────────────────────────────────────┐
│                  iOS App (Swift)                     │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │ SwiftUI Views│  │ AVFoundation │  │ Firebase  │ │
│  │  - Chat      │  │  - Recording │  │  SDK      │ │
│  │  - Voice     │  │  - Playback  │  │           │ │
│  │  - Settings  │  │              │  │           │ │
│  └──────────────┘  └──────────────┘  └───────────┘ │
└─────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│              Firebase Services                       │
│  ┌──────────┐  ┌───────────┐  ┌──────────────────┐ │
│  │   Auth   │  │ Firestore │  │  Cloud Functions │ │
│  │          │  │ (Database)│  │  - transcribe    │ │
│  │          │  │           │  │  - cloneVoice    │ │
│  │          │  │           │  │  - generateTTS   │ │
│  │          │  │           │  │  - summarize     │ │
│  └──────────┘  └───────────┘  └──────────────────┘ │
│  ┌──────────┐  ┌───────────┐                       │
│  │ Storage  │  │ Realtime  │                       │
│  │ (Audio)  │  │ DB        │                       │
│  └──────────┘  └───────────┘                       │
└─────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│               External APIs                          │
│  ┌──────────────┐  ┌──────────────────────────────┐ │
│  │   OpenAI     │  │      ElevenLabs              │ │
│  │  - Whisper   │  │  - Voice Cloning             │ │
│  │  - GPT-4o    │  │  - Text-to-Speech            │ │
│  └──────────────┘  └──────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```Pros:**
- ✅ Enterprise-grade reliability
- ✅ Moderate pricing
- ✅ Voice cloning available (Azure only)

**Cons:**
- ❌ Voice quality inferior to ElevenLabs
- ❌ More complex setup
- ❌ Azure voice cloning requires more data

**Recommendation:** Skip for MVP.

---

#### LLM for Summaries

**Option: OpenAI GPT-4 (**ONLY OPTION**)**

**Pros:**
- ✅ Best summarization quality
- ✅ Understands context and nuance
- ✅ Structured output
- ✅ Reliable and fast

**Cons:**
- ❌ Most expensive LLM ($0.03 input, $0.06 output per 1k tokens)
- ❌ Requires careful prompt engineering

**Pricing:**
- 50-message thread = ~2k input tokens + ~300 output tokens
- Cost per summary: ~$0.08
- Budget: $50/month = ~625 summaries

**Alternative:** GPT-4o-mini ($0.15 input, $0.60 output per 1M tokens)
- 95% as good, 10x cheaper
- Cost per summary: ~$0.008
- Budget: $50/month = ~6,250 summaries

**Recommendation:** Start with GPT-4o-mini, upgrade to GPT-4 if quality insufficient.

---

## Swift Code Examples

### Voice Recording (AVFoundation)

```swift
import AVFoundation
import FirebaseStorage
import FirebaseFunctions

class VoiceRecorder: ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession?
    
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    
    private var timer: Timer?
    
    func setupRecorder() throws {
        // Configure audio session
        audioSession = AVAudioSession.sharedInstance()
        try audioSession?.setCategory(.playAndRecord, mode: .default)
        try audioSession?.setActive(true)
        
        // Setup recorder
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
        audioRecorder?.prepareToRecord()
    }
    
    func startRecording() throws {
        try setupRecorder()
        audioRecorder?.record()
        isRecording = true
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingTime = self?.audioRecorder?.currentTime ?? 0
        }
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        timer?.invalidate()
        timer = nil
        
        return audioRecorder?.url
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// SwiftUI View
struct VoiceMessageView: View {
    @StateObject private var recorder = VoiceRecorder()
    @State private var isTranscribing = false
    @State private var transcript = ""
    
    var body: some View {
        VStack {
            if recorder.isRecording {
                // Recording UI
                VStack {
                    Text("Recording...")
                        .font(.headline)
                    
                    Text(formatTime(recorder.recordingTime))
                        .font(.system(.title, design: .monospaced))
                    
                    // Waveform visualization (custom view)
                    WaveformView()
                        .frame(height: 50)
                    
                    HStack {
                        Button(action: {
                            recorder.stopRecording()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                        }
                        
                        Button(action: {
                            if let audioURL = recorder.stopRecording() {
                                transcribeAudio(audioURL)
                            }
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.green)
                        }
                    }
                }
            } else if isTranscribing {
                ProgressView("Transcribing...")
            } else if !transcript.isEmpty {
                // Show transcript with edit option
                TextEditor(text: $transcript)
                    .frame(height: 100)
                    .border(Color.gray)
                
                Button("Send Message") {
                    sendMessage(transcript)
                }
            } else {
                // Record button
                Button(action: {
                    try? recorder.startRecording()
                }) {
                    Image(systemName: "mic.fill")
                        .font(.largeTitle)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    func transcribeAudio(_ url: URL) {
        isTranscribing = true
        
        Task {
            do {
                // Upload to Firebase Storage
                let audioURL = try await uploadAudio(url)
                
                // Call Cloud Function
                let functions = Functions.functions()
                let transcribe = functions.httpsCallable("transcribeAudio")
                
                let result = try await transcribe.call(["audioUrl": audioURL])
                let data = result.data as! [String: Any]
                
                await MainActor.run {
                    transcript = data["transcript"] as! String
                    isTranscribing = false
                }
            } catch {
                print("Transcription error: \(error)")
                isTranscribing = false
            }
        }
    }
    
    func uploadAudio(_ localURL: URL) async throws -> String {
        let storage = Storage.storage()
        let userId = Auth.auth().currentUser!.uid
        let messageId = UUID().uuidString
        let storageRef = storage.reference().child("audio/recordings/\(userId)/\(messageId).m4a")
        
        _ = try await storageRef.putFileAsync(from: localURL)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    func sendMessage(_ text: String) {
        // Send to Firestore (existing logic)
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
```

---

### Audio Playback (Text-to-Speech)

```swift
import AVFoundation
import FirebaseFunctions

class AudioPlayer: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0
    
    private var timer: Timer?
    
    func playTTS(for message: Message) async {
        do {
            // Check if audio already cached
            if let cachedURL = message.audioUrl {
                try await playFromURL(URL(string: cachedURL)!)
                return
            }
            
            // Generate TTS
            let functions = Functions.functions()
            let generateTTS = functions.httpsCallable("generateTTS")
            
            let result = try await generateTTS.call([
                "text": message.content,
                "voiceId": message.sender.elevenLabsVoiceId ?? "default",
                "messageId": message.id
            ])
            
            let data = result.data as! [String: Any]
            let audioURLString = data["audioUrl"] as! String
            
            try await playFromURL(URL(string: audioURLString)!)
            
        } catch {
            print("TTS playback error: \(error)")
        }
    }
    
    private func playFromURL(_ url: URL) async throws {
        // Download audio data
        let (data, _) = try await URLSession.shared.data(from: url)
        
        await MainActor.run {
            do {
                audioPlayer = try AVAudioPlayer(data: data)
                audioPlayer?.prepareToPlay()
                audioPlayer?.rate = playbackRate
                audioPlayer?.play()
                
                isPlaying = true
                duration = audioPlayer?.duration ?? 0
                
                startTimer()
            } catch {
                print("Audio player error: \(error)")
            }
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func play() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        audioPlayer?.rate = rate
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.currentTime = self?.audioPlayer?.currentTime ?? 0
            
            if self?.currentTime ?? 0 >= self?.duration ?? 0 {
                self?.isPlaying = false
                self?.stopTimer()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// SwiftUI View
struct MessageAudioPlayer: View {
    let message: Message
    @StateObject private var player = AudioPlayer()
    
    var body: some View {
        HStack {
            Button(action: {
                if player.isPlaying {
                    player.pause()
                } else if player.duration > 0 {
                    player.play()
                } else {
                    Task {
                        await player.playTTS(for: message)
                    }
                }
            }) {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
            }
            
            if player.duration > 0 {
                // Progress slider
                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ),
                    in: 0...player.duration
                )
                
                Text("\(formatTime(player.currentTime)) / \(formatTime(player.duration))")
                    .font(.caption)
                    .monospacedDigit()
                
                // Playback speed
                Menu {
                    Button("1.0x") { player.setPlaybackRate(1.0) }
                    Button("1.25x") { player.setPlaybackRate(1.25) }
                    Button("1.5x") { player.setPlaybackRate(1.5) }
                    Button("2.0x") { player.setPlaybackRate(2.0) }
                } label: {
                    Text("\(String(format: "%.2f", player.playbackRate))x")
                        .font(.caption)
                }
            }
        }
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
```

---

### Voice Cloning Setup

```swift
import FirebaseFunctions
import FirebaseAuth

class VoiceCloner: ObservableObject {
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var voiceId: String?
    @Published var previewAudioURL: URL?
    
    func recordVoiceSample() async throws -> URL {
        // Record 30-60 second sample
        let recorder = VoiceRecorder()
        try recorder.startRecording()
        
        // Wait for user to finish (or implement 60s auto-stop)
        // Return audio URL
        return recorder.stopRecording()!
    }
    
    func cloneVoice(sampleURL: URL) async throws {
        isProcessing = true
        
        do {
            // Upload sample to Firebase Storage
            let storage = Storage.storage()
            let userId = Auth.auth().currentUser!.uid
            let storageRef = storage.reference().child("audio/recordings/\(userId)/voice_sample.m4a")
            
            _ = try await storageRef.putFileAsync(from: sampleURL)
            let downloadURL = try await storageRef.downloadURL()
            
            // Call Cloud Function to clone voice
            let functions = Functions.functions()
            let clone = functions.httpsCallable("cloneVoice")
            
            let result = try await clone.call([
                "audioUrl": downloadURL.absoluteString,
                "userId": userId
            ])
            
            let data = result.data as! [String: Any]
            voiceId = data["voiceId"] as? String
            
            // Generate preview
            try await generatePreview()
            
            isProcessing = false
        } catch {
            isProcessing = false
            throw error
        }
    }
    
    func generatePreview() async throws {
        guard let voiceId = voiceId else { return }
        
        let functions = Functions.functions()
        let generateTTS = functions.httpsCallable("generateTTS")
        
        let result = try await generateTTS.call([
            "text": "Hi, this is a preview of my cloned voice. How does it sound?",
            "voiceId": voiceId,
            "messageId": "preview"
        ])
        
        let data = result.data as! [String: Any]
        let audioURLString = data["audioUrl"] as! String
        
        previewAudioURL = URL(string: audioURLString)
    }
}

// SwiftUI View
struct VoiceCloningView: View {
    @StateObject private var cloner = VoiceCloner()
    @State private var showingInstructions = true
    
    var body: some View {
        VStack(spacing: 20) {
            if showingInstructions {
                instructionsView
            } else if cloner.isRecording {
                recordingView
            } else if cloner.isProcessing {
                processingView
            } else if let previewURL = cloner.previewAudioURL {
                previewView(url: previewURL)
            }
        }
        .padding()
    }
    
    var instructionsView: some View {
        VStack(spacing: 15) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Set Up Your Voice")
                .font(.title.bold())
            
            Text("Record yourself reading the sample text below. Speak naturally and clearly in a quiet environment.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            ScrollView {
                Text(sampleText)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            
            Button("Start Recording") {
                showingInstructions = false
                cloner.isRecording = true
                
                Task {
                    let sampleURL = try await cloner.recordVoiceSample()
                    try await cloner.cloneVoice(sampleURL: sampleURL)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    var recordingView: some View {
        VStack {
            Text("Recording...")
                .font(.title)
            
            // Show waveform, timer, etc.
            
            Button("Stop & Process") {
                // Stop recording and process
            }
        }
    }
    
    var processingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Creating your voice...")
                .padding()
            
            Text("This takes about 30 seconds")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    func previewView(url: URL) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Voice Created!")
                .font(.title.bold())
            
            Text("Listen to a preview:")
                .foregroundColor(.secondary)
            
            // Audio player for preview
            Button(action: {
                // Play preview
            }) {
                Label("Play Preview", systemImage: "play.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            
            HStack {
                Button("Re-record") {
                    // Start over
                    showingInstructions = true
                    cloner.voiceId = nil
                    cloner.previewAudioURL = nil
                }
                .buttonStyle(.bordered)
                
                Button("Looks Good!") {
                    // Save and continue
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    let sampleText = """
    Hi, I'm setting up my voice for MessageAI. This voice will be used to read my messages aloud to my family. I can speak naturally, just like I'm talking to a friend. The quick brown fox jumps over the lazy dog. Thanks for setting this up with me!
    """
}
```

---

## 5. Not Included in MVP (Future Roadmap)

### Explicitly Out of Scope for First Release:

#### 1. Android Support
- ❌ iOS only for MVP
- ❌ Android version requires separate Kotlin codebase
- ❌ Will add in v2 if iOS proves successful

**Rationale:** Focus resources on single platform, iterate faster, prove concept before expanding.

---

#### 2. Advanced Voice Features
- ❌ Real-time voice translation (too complex for MVP)
- ❌ Emotion detection in voice (interesting but not essential)
- ❌ Voice effects/filters (gimmicky for parent persona)
- ❌ Multi-language voice cloning (stick to English for MVP)
- ❌ Voice authentication/verification (security feature for later)

---

#### 3. Offline Voice Processing
- ❌ On-device STT (Whisper requires cloud)
- ❌ On-device TTS (ElevenLabs requires cloud)
- ❌ Offline voice cloning (impossible without cloud)

**Rationale:** All voice AI requires cloud processing. Focus on aggressive caching instead.

---

#### 4. Advanced Audio Features
- ❌ Audio effects (reverb, equalization, noise cancellation beyond iOS defaults)
- ❌ Background music for summaries
- ❌ Custom audio intros/outros
- ❌ Audio annotations/bookmarks

**Rationale:** Nice-to-haves that don't solve core problems.

---

#### 5. Multi-Voice Conversation Playback (Phase 3A)
- ❌ Defer to post-MVP (Phase 3B Summary Audio is MVP)
- ❌ Audio stitching complexity too high for timeline
- ❌ Cost per use too expensive ($0.75 vs $0.53 for summary)

**Rationale:** Summary audio is 60% cheaper, 3x faster, and more practical for daily use. Can add full playback as premium feature later.

---

#### 6. Social/Sharing Features  
- ❌ Share voice clones with other users
- ❌ Public voice message library
- ❌ Voice message reactions/comments beyond text
- ❌ Voice note playlists

**Rationale:** Focus on utility, not social features.

---

#### 7. Analytics/Insights
- ❌ Voice usage statistics dashboard
- ❌ Most active speakers in group
- ❌ Conversation insights (sentiment analysis, etc.)
- ❌ Voice quality metrics

**Rationale:** Defer until users demand it.

---

#### 8. Premium/Monetization Features
- ❌ Unlimited voice cloning (limit to 1 voice in MVP)
- ❌ Premium voices (celebrity, character voices)
- ❌ Advanced summarization options (custom styles, lengths)
- ❌ Priority processing (faster TTS/STT)

**Rationale:** Prove value first, monetize later.

---

#### 9. Integration/Ecosystem
- ❌ Export audio to podcast apps
- ❌ Integration with Apple Calendar (auto-add extracted events)
- ❌ Siri Shortcuts integration
- ❌ HomeKit/Smart home integration (play on HomePod)
- ❌ Apple Watch companion app

**Rationale:** MVP is self-contained. Integrations are v2+.

---

#### 10. Collaboration Features
- ❌ Shared voice profiles (family voice)
- ❌ Voice message threading/replies
- ❌ Collaborative audio editing
- ❌ Voice note folders/organization

**Rationale:** Core messaging + voice is enough complexity for MVP.

---

## 6. Technical Risks & Mitigation

### Risk 1: Voice Cloning Quality
**Risk:** Users dissatisfied with cloned voice quality (doesn't sound like them).

**Likelihood:** Medium  
**Impact:** High (core feature)

**Mitigation:**
- Provide clear sample text that captures voice range
- Allow preview before confirming
- Allow re-recording unlimited times
- Set expectations: "AI voice, ~80% similarity"
- Fallback: Use high-quality default voice if user unhappy
- Collect feedback early (beta testing critical)

---

### Risk 2: API Costs Spiral Out of Control
**Risk:** ElevenLabs/OpenAI costs exceed budget as usage grows.

**Likelihood:** High  
**Impact:** Critical (could kill project)

**Mitigation:**
- **Aggressive caching:** Never regenerate same audio twice
- **Rate limiting:** Max 50 voice generations per user per day
- **Smart defaults:** Only generate TTS on explicit user request (not auto)
- **Cost monitoring:** Alert if daily spend >$10
- **Fallback:** Disable voice features if monthly budget exceeded
- **User quotas:** Free tier = 100 voice messages/month, paid = unlimited
- **Batch processing:** Generate multiple TTS requests in single API call where possible
- **Use cheaper models:** GPT-4o-mini instead of GPT-4 for summaries

**Budget Planning:**
```
Monthly Budget: $200
- ElevenLabs: $100 (335k characters = ~6,700 messages)
- OpenAI Whisper: $50 (~8,300 transcriptions)
- OpenAI GPT-4o-mini: $50 (~6,250 summaries)

Per-user cost: ~$0.50/month (assumes 30 voice messages + 2 summaries)
Breakeven: 400 active users at $0.50/user
```

---

### Risk 3: Audio Processing Latency
**Risk:** TTS generation takes >5 seconds, feels slow and broken.

**Likelihood:** Medium  
**Impact:** High (UX suffers)

**Mitigation:**
- **Optimistic UI:** Show "Generating audio..." with progress indicator
- **Background generation:** Pre-generate audio for recent messages on app open
- **Streaming:** Explore ElevenLabs streaming TTS (plays while generating)
- **Caching strategy:** Cache aggressively on device
- **Fallback:** If generation >10 seconds, offer "Listen later" option
- **Server-side optimization:** Use edge functions for faster API calls

---

### Risk 4: Poor Transcription Accuracy
**Risk:** Whisper transcribes incorrectly, creates embarrassing/confusing messages.

**Likelihood:** Medium  
**Impact:** Medium (user can edit, but annoying)

**Mitigation:**
- **Always show transcript before sending** (user can review/edit)
- **Confidence scoring:** Flag low-confidence transcriptions for review
- **Noise detection:** Warn if background noise detected
- **Retry mechanism:** "Transcription unclear, try recording again?"
- **User education:** "Speak clearly, minimize background noise"
- **Quality settings:** Allow user to choose "High quality" (slower) vs "Fast" mode

---

### Risk 5: Voice Cloning Misuse/Abuse
**Risk:** Users clone others' voices without consent, use for impersonation.

**Likelihood:** Low (within family app)  
**Impact:** High (legal/ethical issues)

**Mitigation:**
- **Terms of Service:** Explicitly prohibit cloning others without consent
- **One voice per account:** Users can only clone their own voice
- **No voice sharing:** Can't export/share voice_id to other users
- **Watermarking:** ElevenLabs adds inaudible watermark to detect synthetic audio
- **Reporting mechanism:** Users can flag suspicious voice messages
- **Age verification:** Require 18+ for voice cloning (protect minors)

---

### Risk 6: Storage Costs for Audio Files
**Risk:** Audio files accumulate, storage costs balloon.

**Likelihood:** High  
**Impact:** Medium (manageable with cleanup)

**Mitigation:**
- **Auto-deletion:** Delete audio files after 30 days (configurable)
- **Compression:** Use efficient codecs (AAC, Opus)
- **Selective storage:** Only store audio for important messages (starred/pinned)
- **User control:** "Delete all audio older than X days" option
- **Cloud optimization:** Use Cloudflare R2 (cheapest storage, free egress)
- **Lifecycle policies:** Automatically move old files to cold storage

**Cost Projection:**
```
Average voice message: 30 seconds = ~500KB (compressed)
1,000 users × 10 messages/day × 30 days = 300,000 messages
300,000 × 500KB = 150GB
Storage cost: 150GB × $0.015/GB = $2.25/month (Cloudflare R2)
```

---

### Risk 7: Real-Time Performance Degradation
**Risk:** WebSocket connection struggles with audio uploads/downloads.

**Likelihood:** Medium  
**Impact:** Medium (affects core messaging)

**Mitigation:**
- **Separate channels:** Use HTTP for audio upload/download, WebSocket only for signaling
- **Chunked uploads:** Upload large files in chunks
- **Progress indicators:** Show upload/download progress clearly
- **Retry logic:** Auto-retry failed uploads with exponential backoff
- **Compression:** Compress audio before upload
- **CDN delivery:** Serve audio from CDN, not origin server

---

### Risk 8: Platform Restrictions (iOS/Android)
**Risk:** Apple/Google reject app for voice features or restrict functionality.

**Likelihood:** Low  
**Impact:** Critical (could block launch)

**Mitigation:**
- **Review guidelines compliance:** Study App Store/Play Store voice policies
- **Privacy disclosures:** Clearly state audio recording/processing in privacy policy
- **Permissions:** Request microphone permissions with clear explanation
- **Data handling:** Comply with data retention/deletion requirements
- **No restricted content:** Voice features can't be used for prohibited content
- **Age gating:** Require 13+ (COPPA compliance)

**Specific Concerns:**
- **iOS:** Apple requires clear disclosure of cloud voice processing
- **Android:** Google requires runtime microphone permission with rationale
- **Both:** Must allow users to delete all voice data

---

### Risk 9: Accessibility Requirements
**Risk:** Voice features create barriers for deaf/hard-of-hearing users.

**Likelihood:** Medium  
**Impact:** Medium (ethical + legal concerns)

**Mitigation:**
- **Always show transcript:** Every voice message has text alternative
- **Visual indicators:** Waveform, captions, speaker labels
- **Screen reader support:** Full VoiceOver/TalkBack compatibility
- **Subtitles:** Auto-generate captions for all audio playback
- **Haptic feedback:** Vibration for audio-related actions
- **Settings:** "Prefer text" mode disables auto-play, shows text by default

---

### Risk 10: Network Failures During Critical Moments
**Risk:** User tries to send urgent voice message, upload fails due to poor network.

**Likelihood:** High  
**Impact:** High (defeats purpose of hands-free messaging)

**Mitigation:**
- **Offline queueing:** Store audio locally, auto-upload when connected
- **Retry logic:** Exponential backoff with max 5 retries
- **Fallback:** If transcription fails, send audio-only message
- **Network detection:** Warn user if on weak connection
- **Local transcription attempt:** Try on-device speech recognition as backup
- **Status indicators:** Clear "Queued", "Uploading", "Sent" states

---

## 7. Success Criteria & KPIs

### Launch Goals (First 30 Days)

**Adoption Metrics:**
- [ ] 60%+ of users try voice-to-text within first week
- [ ] 40%+ of users complete voice cloning setup
- [ ] 30%+ of users listen to at least one message via TTS
- [ ] 20%+ of users try conversation summary feature

**Engagement Metrics:**
- [ ] 25%+ of messages sent via voice-to-text
- [ ] 15%+ of messages played via TTS
- [ ] 5+ conversation summaries generated per active user
- [ ] 70%+ retention after first voice message sent

**Quality Metrics:**
- [ ] <5% transcription error rate (user-reported)
- [ ] >80% voice cloning satisfaction (survey)
- [ ] <3 second average TTS generation time
- [ ] >90% audio playback success rate (no errors)

**Technical Metrics:**
- [ ] <2% API failure rate (ElevenLabs, OpenAI)
- [ ] <1% audio upload failures
- [ ] <5 second average message send latency (including voice)
- [ ] Zero security incidents (voice data leaks)

**Cost Metrics:**
- [ ] Stay under $200/month API budget
- [ ] <$0.50 per active user per month
- [ ] <10% over-budget on any single API

**Rubric Score:**
- [ ] 100+ points total (A+ with bonuses)
- [ ] 10/10 on Advanced AI Capability
- [ ] +3 Innovation bonus
- [ ] +3 Polish bonus

---

## 8. Development Timeline

### Phase 1: Voice-to-Text (Weeks 1-2)

**Week 1:**
- [ ] Day 1-2: Audio recording UI/UX (React Native expo-av)
- [ ] Day 3-4: Whisper API integration
- [ ] Day 5: Transcription display & editing
- [ ] Day 6-7: Message storage (database schema, file upload)

**Week 2:**
- [ ] Day 1-3: End-to-end testing (record → transcribe → send)
- [ ] Day 4-5: Error handling & edge cases
- [ ] Day 6-7: Polish, optimizations, offline support

**Deliverable:** Working voice-to-text messaging

---

### Phase 2: Text-to-Voice (Weeks 3-4)

**Week 3:**
- [ ] Day 1-2: Voice cloning UI flow
- [ ] Day 3-4: ElevenLabs Voice Design API integration
- [ ] Day 5-7: User profile voice storage & preview

**Week 4:**
- [ ] Day 1-3: TTS generation on demand
- [ ] Day 4-5: Audio player component (play, pause, speed, seek)
- [ ] Day 6-7: Caching strategy & offline playback

**Deliverable:** Every message playable in sender's voice

---

### Phase 3: Conversation Audio (Weeks 5-6)

**Week 5 (Summary Path - RECOMMENDED):**
- [ ] Day 1-2: GPT-4 summarization logic
- [ ] Day 3-4: Summary UI/UX ("Hear Summary" button)
- [ ] Day 5-7: TTS generation for summaries, storage

**Week 6:**
- [ ] Day 1-3: Smart triggering (suggest summary for long threads)
- [ ] Day 4-5: Polish and optimization
- [ ] Day 6-7: End-to-end testing, demo prep

**Deliverable:** AI audio summaries for group chats

---

### Week 7: Integration, Testing, Demo

**Integration Week:**
- [ ] Day 1-2: Integrate all 3 phases into main app
- [ ] Day 3-4: Cross-feature testing (voice-to-text + TTS + summary)
- [ ] Day 5: Performance testing, cost analysis

**Demo Prep:**
- [ ] Day 6: Record demo video (5-7 minutes)
- [ ] Day 7: Write Persona Brainlift doc, create social post

**Buffer:** Week 8 for polish, bug fixes, documentation

---

## 9. Testing Strategy

### Unit Testing
**Voice-to-Text:**
- [ ] Audio recording starts/stops correctly
- [ ] Transcription API called with correct parameters
- [ ] Transcript displayed and editable
- [ ] Message saves with audio URL and transcript

**Text-to-Voice:**
- [ ] Voice cloning API called correctly
- [ ] Voice_id stored in database
- [ ] TTS generation uses correct voice_id
- [ ] Audio caching works (second play is instant)

**Conversation Audio:**
- [ ] Summary generation captures key points
- [ ] Audio generates for summaries
- [ ] Trigger logic works (20+ messages)

---

### Integration Testing
- [ ] Record voice → transcribe → send → other user receives both audio & text
- [ ] Clone voice → send text message → other user plays in sender's voice
- [ ] Long group thread → generate summary → play audio → verify accuracy
- [ ] Offline: record voice → go online → transcription completes

---

### User Acceptance Testing (Beta)
**Recruit 10 beta testers (actual busy parents):**
- [ ] 5 working parents with kids in activities
- [ ] 2 caregivers for elderly parents
- [ ] 2 single parents with shared custody
- [ ] 1 parent with vision impairment

**Testing Scenarios:**
1. **Driving scenario:** Send voice message while simulating driving
2. **Cooking scenario:** Listen to messages while hands are messy
3. **Group chat catchup:** 50+ message thread, test summary
4. **Voice cloning:** Complete setup, verify satisfaction with voice quality
5. **Multi-day usage:** Use app for 7 days, report friction points

**Feedback Collection:**
- Daily diary (what worked, what didn't)
- Exit survey (NPS, feature ratings)
- Usage analytics (which features used most)

---

### Performance Testing
- [ ] Transcription latency: Average <2 seconds for 30-second audio
- [ ] TTS generation: Average <3 seconds for 50-character message
- [ ] Summary generation: <10 seconds for 50-message thread
- [ ] Audio playback: No stuttering/buffering on 4G connection
- [ ] App launch: <2 seconds cold start with voice features enabled

---

### Cost Testing
**Simulate usage patterns:**
- 100 users × 10 voice messages/day × 30 days = 30,000 transcriptions
- Cost: 30,000 × (30 seconds average) ÷ 60 = 15,000 minutes
- 15,000 minutes × $0.006 = $90 (within budget ✅)

- 100 users × 30 messages/day × 30 days × 50% play rate = 45,000 TTS generations
- 45,000 × 50 chars = 2.25M characters
- 2.25M × $0.30/1k = $675 (OVER BUDGET ❌)

**Adjustment needed:** Aggressive caching reduces to ~5,000 unique TTS generations = $75 ✅

---

## 10. Open Questions for Review

### Technical Decisions to Make:

**Q1: React Native or Native Development?**
- Recommendation: React Native (faster, cross-platform)
- Your preference: _______________
- Rationale: _______________

**Q2: Phase 3 - Multi-Voice Playback OR Summary Audio?**
- Recommendation: Summary Audio (simpler, cheaper, more practical)
- Your preference: _______________
- Rationale: _______________

**Q3: Voice Cloning Required or Optional?**
- Recommendation: Optional (fallback to default voice)
- Your preference: _______________
- Rationale: _______________

**Q4: Auto-Play TTS or Explicit Play Button?**
- Recommendation: Explicit button (respect user's attention)
- Your preference: _______________
- Rationale: _______________

**Q5: Audio File Retention Period?**
- Recommendation: 30 days (balance storage cost and usefulness)
- Your preference: _______________
- Rationale: _______________

---

### Product Decisions to Make:

**Q6: Free Tier Voice Limits?**
- Recommendation: 100 voice messages/month, unlimited after
- Your preference: _______________
- Rationale: _______________

**Q7: Voice Cloning Age Requirement?**
- Recommendation: 18+ (protect minors from impersonation)
- Your preference: _______________
- Rationale: _______________

**Q8: Default Voice Selection?**
- Recommendation: Let user choose from 5 ElevenLabs pre-made voices
- Your preference: _______________
- Rationale: _______________

**Q9: Voice Message Max Length?**
- Recommendation: 2 minutes (balance cost and usefulness)
- Your preference: _______________
- Rationale: _______________

**Q10: Conversation Summary Max Messages?**
- Recommendation: 200 messages max per summary (cost control)
- Your preference: _______________
- Rationale: _______________

---

## 11. Dependencies & Prerequisites

### Required Before Starting Development:

**Accounts & Access:**
- [ ] OpenAI API key (for Whisper + GPT)
- [ ] ElevenLabs account (Starter plan minimum: $5/month)
- [ ] Cloud storage account (Cloudflare R2 or AWS S3)
- [ ] Database hosting (Railway, Supabase, or Render)

**Development Environment:**
- [ ] Node.js 20+ installed
- [ ] Expo CLI installed (`npm install -g expo-cli`)
- [ ] iOS Simulator (Mac) or Android Emulator
- [ ] Physical devices for testing (iOS + Android)

**Backend Setup:**
- [ ] PostgreSQL database provisioned
- [ ] File storage bucket created
- [ ] Environment variables configured
- [ ] HTTPS domain for API (required for mobile)

**Third-Party Services:**
- [ ] Firebase Auth or Auth0 (existing)
- [ ] WebSocket server running (existing)
- [ ] Existing MessageAI backend functional

---

## 12. Next Steps After PRD Approval

1. **Review & Feedback Session** (30 minutes)
   - Go through each section
   - Make decisions on open questions
   - Identify any missing requirements

2. **Tech Stack Finalization** (1 hour)
   - Confirm React Native + Node.js
   - Set up API accounts (OpenAI, ElevenLabs)
   - Test API calls with sample audio

3. **Database Schema Updates** (2 hours)
   - Write migration scripts
   - Add voice-related columns
   - Test schema changes

4. **Sprint Planning** (1 hour)
   - Break down Phase 1 into tickets
   - Assign story points
   - Set up project board (GitHub Projects, Jira, etc.)

5. **Kickoff Development** (Week 1, Day 1)
   - Start with audio recording UI
   - Parallel: Backend Whisper integration
   - Daily standups to track progress

---

## 13. Appendix

### A. Sample Voice Cloning Script
```
"Hi, I'm [Your Name]. I'm setting up my voice for MessageAI so my family 
can hear my messages read aloud. This is my natural speaking voice. I'm 
excited to try this new feature. The quick brown fox jumps over the lazy 
dog. Thanks for listening!"
```
(30 seconds, covers vocal range)

---

### B. Error Messages & User Communication

**Transcription Failed:**
> "Couldn't transcribe audio. Please try again in a quieter environment."

**Voice Cloning Failed:**
> "We couldn't process your voice sample. Please re-record in a quiet space and speak clearly for 30 seconds."

**TTS Generation Failed:**
> "Audio unavailable. You can still read the message."

**Summary Generation Failed:**
> "Couldn't generate summary right now. Try again in a moment."

**Over Quota:**
> "You've reached your monthly voice limit (100 messages). Upgrade for unlimited."

---

### C. Privacy & Data Handling

**What We Store:**
- Voice recordings (for messages you send)
- Voice cloning samples (to create your voice profile)
- Generated audio files (for playback)
- Transcripts (searchable text)

**What We Don't Store:**
- Real-time audio streams
- Voice data from other apps
- Biometric voice fingerprints

**User Rights:**
- Delete all voice data at any time
- Export voice recordings
- Revoke voice cloning (removes voice_id)
- Opt-out of voice features entirely

**Compliance:**
- GDPR: Right to erasure, data portability
- CCPA: Right to know, delete
- COPPA: No voice data from users <13

---

### D. Competitive Analysis

**Why MessageAI Voice Features Are Unique:**

| Feature | MessageAI | WhatsApp | Telegram | Discord |
|---------|-----------|----------|----------|---------|
| Voice-to-Text | ✅ Whisper AI | ❌ | ✅ Basic | ❌ |
| Voice Cloning | ✅ Your voice | ❌ | ❌ | ❌ |
| Text-to-Voice | ✅ Sender's voice | ❌ | ❌ | Basic TTS |
| AI Summaries | ✅ GPT-4 | ❌ | ❌ | ❌ |
| Multi-Voice Playback | ✅ (Phase 3) | ❌ | ❌ | ❌ |
| Persona-Specific | ✅ Busy parents | ❌ General | ❌ General | ❌ Gamers |

**Our Moat:** Voice cloning + AI summarization for family coordination.

---

## 14. Sign-Off

**Product Manager:** _________________ Date: _______

**Engineering Lead:** _________________ Date: _______

**Design Lead:** _________________ Date: _______

---

**Document Status:** 🟡 Draft - Awaiting Review

**Next Review Date:** _________________

**Approved for Development:** [ ] Yes [ ] No

---

## Questions? Comments? Edits?

**Areas that need more detail:**
- [ ] _______________________________________________
- [ ] _______________________________________________
- [ ] _______________________________________________

**Concerns or blockers:**
- [ ] _______________________________________________
- [ ] _______________________________________________
- [ ] _______________________________________________

**Additional features to consider:**
- [ ] _______________________________________________
- [ ] _______________________________________________
- [ ] _______________________________________________