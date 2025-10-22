# PR#14: Testing Guide

---

## Test Categories

### 1. Cloud Functions Compilation Tests

**Purpose:** Verify TypeScript code compiles without errors

#### Test 1.1: Initial Compilation
- [ ] **Action:** Run `npm run build` in `functions/` directory
- [ ] **Expected:** Build succeeds with 0 errors, 0 warnings
- [ ] **Actual:** ___________________
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 1.2: Middleware Compilation
- [ ] **Action:** Compile after adding all middleware files
- [ ] **Expected:** 
  - `auth.ts` compiles ✓
  - `rateLimit.ts` compiles ✓
  - `validation.ts` compiles ✓
- [ ] **Actual:** ___________________
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 1.3: AI Router Compilation
- [ ] **Action:** Compile after adding `processAI.ts`
- [ ] **Expected:** 
  - Main router compiles ✓
  - All imports resolve ✓
  - All placeholder functions compile ✓
- [ ] **Actual:** ___________________
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

---

### 2. Deployment Tests

**Purpose:** Verify Cloud Functions deploy successfully to Firebase

#### Test 2.1: Initial Deployment
- [ ] **Action:** Run `firebase deploy --only functions`
- [ ] **Expected:**
  - Deployment starts successfully
  - TypeScript builds without errors
  - Function uploads to Firebase
  - "Deploy complete" message shown
- [ ] **Actual:** ___________________
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 2.2: Firebase Console Verification
- [ ] **Action:** Check https://console.firebase.google.com/project/messageai-95c8f/functions
- [ ] **Expected:**
  - `processAI` function listed
  - Status: "Active"
  - Runtime: Node.js 18
  - Region: us-central1
- [ ] **Actual:** ___________________
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 2.3: Function URL Availability
- [ ] **Action:** Note function URL from deployment output
- [ ] **Expected:** URL format: `https://us-central1-messageai-95c8f.cloudfunctions.net/processAI`
- [ ] **Actual:** ___________________
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

---

### 3. Authentication Tests

**Purpose:** Verify authentication is required and enforced

#### Test 3.1: Unauthenticated Request (Should Fail)
- [ ] **Action:** Log out user, try to call AIService
  ```swift
  // Log out
  try? Auth.auth().signOut()
  
  // Try to call AI
  let result = try await AIService.shared.processMessage(
      "Test message",
      feature: .calendar
  )
  ```
- [ ] **Expected Error:** "You must be logged in to use AI features."
- [ ] **Error Code:** `unauthenticated`
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 3.2: Authenticated Request (Should Succeed)
- [ ] **Action:** Log in user, try to call AIService
  ```swift
  // Log in
  try await Auth.auth().signIn(withEmail: "test@test.com", password: "password")
  
  // Call AI
  let result = try await AIService.shared.processMessage(
      "Soccer Thursday at 4pm",
      feature: .calendar
  )
  ```
- [ ] **Expected:** Success response with placeholder data
- [ ] **Response includes:**
  - `processingTimeMs` field ✓
  - `modelUsed` field ✓
  - `processedAt` field ✓
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 3.3: Expired Token (Should Fail or Refresh)
- [ ] **Action:** Use expired auth token
- [ ] **Expected:** Either error or automatic token refresh
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

---

### 4. Rate Limiting Tests

**Purpose:** Verify 100 requests/hour limit is enforced

#### Test 4.1: First Request (Should Succeed)
- [ ] **Action:** Make first AI request of the hour
- [ ] **Expected:** Request succeeds
- [ ] **Firestore Check:** rateLimits collection has doc with count=1
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 4.2: Multiple Requests (Should Succeed)
- [ ] **Action:** Make 10 rapid AI requests
- [ ] **Expected:** All 10 succeed
- [ ] **Firestore Check:** count increases from 1 to 11
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 4.3: Rate Limit Exceeded (Should Fail)
- [ ] **Action:** Make 101 requests in same hour
  ```swift
  for i in 1...101 {
      do {
          let result = try await AIService.shared.processMessage(
              "Test \(i)",
              feature: .calendar
          )
          print("Request \(i): Success")
      } catch {
          print("Request \(i): Failed - \(error)")
      }
  }
  ```
- [ ] **Expected:**
  - Requests 1-100: Success ✓
  - Request 101: Error "Too many AI requests" ✓
- [ ] **Error Code:** `resource-exhausted`
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 4.4: Rate Limit Reset After Hour
- [ ] **Action:** Wait 1 hour, make new request
- [ ] **Expected:** Request succeeds (new hour bucket)
- [ ] **Firestore Check:** New doc created with count=1
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

---

### 5. Input Validation Tests

**Purpose:** Verify input validation catches invalid requests

#### Test 5.1: Missing Feature Parameter
- [ ] **Action:** Call Cloud Function without `feature` field
  ```swift
  // Manually construct invalid request
  let callable = Functions.functions().httpsCallable("processAI")
  let result = try await callable.call(["message": "Test"])
  ```
- [ ] **Expected Error:** "Missing required fields: feature"
- [ ] **Error Code:** `invalid-argument`
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 5.2: Invalid Feature Type
- [ ] **Action:** Call with unknown feature
  ```swift
  let result = try await AIService.shared.processMessage(
      "Test message",
      feature: "invalid_feature"  // Not a valid AIFeature
  )
  ```
- [ ] **Expected Error:** "Invalid AI feature: invalid_feature"
- [ ] **Error Code:** `invalid-argument`
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 5.3: Message Too Long
- [ ] **Action:** Call with 6000 character message
  ```swift
  let longMessage = String(repeating: "a", count: 6000)
  let result = try await AIService.shared.processMessage(
      longMessage,
      feature: .calendar
  )
  ```
- [ ] **Expected Error:** "Message too long. Maximum 5000 characters."
- [ ] **Error Code:** `invalid-argument`
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 5.4: Empty Message
- [ ] **Action:** Call with empty string
  ```swift
  let result = try await AIService.shared.processMessage(
      "",
      feature: .calendar
  )
  ```
- [ ] **Expected Error:** "Message must be a non-empty string."
- [ ] **Error Code:** `invalid-argument`
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

---

### 6. Feature Routing Tests

**Purpose:** Verify each AI feature routes to correct placeholder function

#### Test 6.1: Calendar Feature
- [ ] **Action:** Call with `feature: .calendar`
- [ ] **Expected Response:**
  ```json
  {
    "events": [],
    "message": "Calendar extraction not yet implemented (PR #15)",
    "processingTimeMs": 450,
    "modelUsed": "gpt-4"
  }
  ```
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 6.2: Decision Feature
- [ ] **Action:** Call with `feature: .decision`
- [ ] **Expected Response:**
  ```json
  {
    "hasDecision": false,
    "message": "Decision summarization not yet implemented (PR #16)"
  }
  ```
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 6.3: Urgency Feature
- [ ] **Action:** Call with `feature: .urgency`
- [ ] **Expected Response:**
  ```json
  {
    "urgencyLevel": "normal",
    "isUrgent": false,
    "message": "Priority detection not yet implemented (PR #17)"
  }
  ```
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 6.4: RSVP Feature
- [ ] **Action:** Call with `feature: .rsvp`
- [ ] **Expected Response:**
  ```json
  {
    "response": "pending",
    "message": "RSVP tracking not yet implemented (PR #18)"
  }
  ```
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 6.5: Deadline Feature
- [ ] **Action:** Call with `feature: .deadline`
- [ ] **Expected Response:**
  ```json
  {
    "deadlines": [],
    "message": "Deadline extraction not yet implemented (PR #19)"
  }
  ```
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 6.6: Agent Feature
- [ ] **Action:** Call with `feature: .agent`
- [ ] **Expected Response:**
  ```json
  {
    "message": "Event planning agent not yet implemented (PR #20)",
    "nextStep": null
  }
  ```
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

---

### 7. iOS AIService Tests

**Purpose:** Verify iOS service layer works correctly

#### Test 7.1: AIService Singleton
- [ ] **Action:** Access `AIService.shared` multiple times
- [ ] **Expected:** Same instance returned each time
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 7.2: Caching Behavior
- [ ] **Action:** 
  ```swift
  // First call (should hit Cloud Function)
  let result1 = try await AIService.shared.processMessage(
      "Soccer Thursday 4pm",
      feature: .calendar
  )
  
  // Second call with same message (should use cache)
  let result2 = try await AIService.shared.processMessage(
      "Soccer Thursday 4pm",
      feature: .calendar
  )
  ```
- [ ] **Expected:**
  - First call: Network request to Cloud Function
  - Second call: Instant response from cache
  - Console shows "Cache hit"
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 7.3: Cache Expiration
- [ ] **Action:** Wait 6 minutes, make same call again
- [ ] **Expected:** Network request (cache expired after 5 min)
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 7.4: Error Mapping
- [ ] **Action:** Trigger each error type, verify iOS error
- [ ] **Expected:**
  - Unauthenticated → AIError.unauthenticated ✓
  - Rate limit → AIError.rateLimitExceeded ✓
  - Invalid input → AIError.serverError ✓
  - Network error → AIError.networkError ✓
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

---

### 8. Data Model Tests

**Purpose:** Verify AIMetadata models encode/decode correctly

#### Test 8.1: AIMetadata Codable
- [ ] **Action:** Create AIMetadata, encode to JSON, decode back
  ```swift
  let metadata = AIMetadata(processedAt: Date())
  metadata.isUrgent = true
  metadata.urgencyLevel = .high
  
  let data = try JSONEncoder().encode(metadata)
  let decoded = try JSONDecoder().decode(AIMetadata.self, from: data)
  
  XCTAssertEqual(decoded.isUrgent, true)
  XCTAssertEqual(decoded.urgencyLevel, .high)
  ```
- [ ] **Expected:** Encodes and decodes without data loss
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 8.2: Message with AIMetadata
- [ ] **Action:** Create Message with aiMetadata, convert to Firestore
  ```swift
  var message = Message(/* ... */)
  message.aiMetadata = AIMetadata(processedAt: Date())
  message.aiMetadata?.isUrgent = true
  
  let dict = message.toDictionary()
  let restored = Message(dictionary: dict)
  
  XCTAssertEqual(restored.aiMetadata?.isUrgent, true)
  ```
- [ ] **Expected:** aiMetadata survives round-trip to Firestore format
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

---

### 9. Performance Tests

**Purpose:** Verify performance targets are met

#### Test 9.1: Cold Start Latency
- [ ] **Action:** Deploy fresh function, make first request
- [ ] **Expected:** < 3 seconds total (including cold start)
- [ ] **Actual:** ___________________
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 9.2: Warm Response Latency
- [ ] **Action:** Make request to already-warm function
- [ ] **Expected:** < 1 second
- [ ] **Actual:** ___________________
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 9.3: End-to-End Latency (iOS → Cloud → iOS)
- [ ] **Action:** Time full request from iOS app
  ```swift
  let start = Date()
  let result = try await AIService.shared.processMessage(
      "Test message",
      feature: .calendar
  )
  let duration = Date().timeIntervalSince(start)
  print("Total time: \(duration)s")
  ```
- [ ] **Expected:** < 2 seconds
- [ ] **Actual:** ___________________
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 9.4: Rate Limit Check Performance
- [ ] **Action:** Check `processingTimeMs` in response
- [ ] **Expected:** < 50ms spent on rate limit check
- [ ] **Actual:** ___________________
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

---

### 10. Security Tests

**Purpose:** Verify API keys are secured and never exposed

#### Test 10.1: API Key Not in iOS Code
- [ ] **Action:** Search iOS codebase for OpenAI key
  ```bash
  cd messAI
  grep -r "sk-proj-" .
  grep -r "OPENAI_API_KEY" .
  ```
- [ ] **Expected:** No matches found (keys only in Cloud Functions)
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 10.2: .env File in .gitignore
- [ ] **Action:** Check .gitignore contains .env
  ```bash
  cat functions/.gitignore | grep ".env"
  ```
- [ ] **Expected:** `.env` listed in .gitignore
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 10.3: Firebase Config Secure
- [ ] **Action:** Check Firebase environment config
  ```bash
  firebase functions:config:get
  ```
- [ ] **Expected:** openai.key present (value hidden)
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 10.4: Git History Clean
- [ ] **Action:** Check git history for accidentally committed keys
  ```bash
  git log --all --full-history --source -- functions/.env
  ```
- [ ] **Expected:** No commits with .env file
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

---

### 11. Logging & Monitoring Tests

**Purpose:** Verify logging works for debugging

#### Test 11.1: Request Logging
- [ ] **Action:** Make AI request, check Firebase logs
  ```bash
  firebase functions:log --limit 10
  ```
- [ ] **Expected Logs:**
  - "AI request received" with userId and feature ✓
  - "AI request completed" with processingTimeMs ✓
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 11.2: Error Logging
- [ ] **Action:** Trigger error, check Firebase logs
- [ ] **Expected Logs:**
  - "AI request failed" with error details ✓
  - Error code and message ✓
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 11.3: Rate Limit Logging
- [ ] **Action:** Hit rate limit, check logs
- [ ] **Expected Logs:**
  - "Rate limit exceeded" with userId and count ✓
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

---

### 12. Integration Tests

**Purpose:** Verify end-to-end functionality

#### Test 12.1: Full AI Request Flow
- [ ] **Action:** Complete flow from iOS to Cloud Function and back
  ```swift
  // 1. User logged in
  guard Auth.auth().currentUser != nil else { return }
  
  // 2. Call AIService
  let result = try await AIService.shared.processMessage(
      "Soccer practice Thursday at 4pm",
      feature: .calendar
  )
  
  // 3. Verify response
  XCTAssertNotNil(result["processingTimeMs"])
  XCTAssertNotNil(result["modelUsed"])
  XCTAssertNotNil(result["processedAt"])
  ```
- [ ] **Expected:** All steps succeed without errors
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 12.2: Multiple Sequential Requests
- [ ] **Action:** Make 5 different AI requests in sequence
- [ ] **Expected:** All 5 succeed
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

#### Test 12.3: Concurrent Requests
- [ ] **Action:** Make 5 AI requests simultaneously
  ```swift
  await withTaskGroup(of: Void.self) { group in
      for i in 1...5 {
          group.addTask {
              let result = try? await AIService.shared.processMessage(
                  "Test \(i)",
                  feature: .calendar
              )
          }
      }
  }
  ```
- [ ] **Expected:** All 5 succeed (no race conditions)
- [ ] **Status:** ⏳ PENDING / ✅ PASS / ❌ FAIL

---

## Test Summary

### Completion Checklist
- [ ] **Compilation:** All TypeScript and Swift compiles ✓
- [ ] **Deployment:** Cloud Functions deployed successfully ✓
- [ ] **Authentication:** Enforced and working ✓
- [ ] **Rate Limiting:** 100 req/hour enforced ✓
- [ ] **Validation:** Invalid inputs rejected ✓
- [ ] **Routing:** All 6 features route correctly ✓
- [ ] **iOS Service:** AIService works end-to-end ✓
- [ ] **Data Models:** AIMetadata encodes/decodes ✓
- [ ] **Performance:** Meets all latency targets ✓
- [ ] **Security:** API keys secured ✓
- [ ] **Logging:** Logs visible in Firebase Console ✓
- [ ] **Integration:** End-to-end flow works ✓

---

## Acceptance Criteria

**This PR passes testing when:**

### Functional Requirements ✅
- [x] Cloud Function deployed to Firebase
- [x] Can call function from iOS app with authentication
- [x] Rate limiting works (100 req/hour/user)
- [x] All 6 AI features route to placeholder functions
- [x] Placeholder functions return expected structure
- [x] iOS AIService successfully calls Cloud Function
- [x] AI results cached for 5 minutes
- [x] Error handling works for all error types

### Performance Requirements ✅
- [x] Cold start: < 3 seconds
- [x] Warm response: < 1 second
- [x] Total iOS → Cloud → iOS: < 2 seconds
- [x] Rate limit check: < 50ms

### Security Requirements ✅
- [x] API keys secured (never in iOS app)
- [x] .env file in .gitignore
- [x] Firebase config uses environment variables
- [x] Authentication enforced on Cloud Function
- [x] Rate limiting prevents abuse

### Quality Requirements ✅
- [x] All TypeScript compiles without errors
- [x] All Swift compiles without errors
- [x] No ESLint warnings
- [x] No Xcode warnings
- [x] Logs visible in Firebase Console
- [x] Error messages are user-friendly

---

## Test Results Summary

**Total Tests:** 45  
**Passed:** ___ / 45  
**Failed:** ___ / 45  
**Pending:** ___ / 45  

**Overall Status:** ⏳ TESTING IN PROGRESS / ✅ ALL TESTS PASS / ❌ TESTS FAILING

---

## Next Steps After Testing

**When all tests pass:**
1. Commit all changes
2. Push to feature branch
3. Create pull request
4. Merge to main
5. Start PR #15 (Calendar Extraction)

**If tests fail:**
1. Review failed tests
2. Check Firebase logs for errors
3. Fix issues
4. Redeploy if needed
5. Re-run tests
6. Repeat until all pass

---

*"Tests are documentation that never goes out of date."*

**Happy Testing!** 🧪✅
