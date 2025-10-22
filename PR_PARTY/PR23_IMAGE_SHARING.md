# PR#23: Image Sharing - Storage Integration

**Estimated Time:** 2-3 hours  
**Complexity:** MEDIUM-HIGH  
**Dependencies:** PR #4 (Models), PR #5 (ChatService), PR #9 (ChatView), PR #10 (Real-Time Messaging), PR #11 (Message Status)

---

## Overview

### What We're Building

Image sharing elevates text-only messaging to **rich visual communication**—enabling users to share photos, screenshots, memes, and visual moments. This PR implements:
- **Image Selection**: Choose from photo library or capture with camera
- **Image Compression**: Automatic optimization for fast upload (target: <2MB)
- **Thumbnail Generation**: Small preview for chat bubbles (200x200px)
- **Firebase Storage Upload**: Secure cloud storage with progress tracking
- **Image Display**: Tap to view full-screen with pinch-zoom
- **Image Messages**: Seamlessly integrated with text messages
- **Offline Support**: Queue images locally, upload when online

Think: WhatsApp photo sharing, iMessage photos, Instagram DMs (but simpler and faster).

### Why It Matters

Images are **essential** for modern communication—visual expression transcends language barriers:
- **Visual Storytelling**: Share moments, experiences, reactions
- **Information Sharing**: Screenshots, documents, diagrams, maps
- **Emotional Expression**: Memes, GIFs, reactions, celebrations
- **Professional Use**: Product photos, receipts, references, whiteboard captures
- **Memory Preservation**: Photos become conversation history

**Usage Statistics:**
- 55% of messages on WhatsApp contain images
- Users share 4.5 billion images per day on WhatsApp
- 70% of shared images are photos (vs screenshots/memes)
- Image messages have 3x engagement of text-only
- Apps without image sharing have 60% lower retention

**Without image sharing:**
- ❌ Can't share visual moments
- ❌ Limited to text-only communication
- ❌ Missing industry-standard feature
- ❌ Users forced to use other apps for photos
- ❌ App feels incomplete and dated

**With image sharing:**
- ✅ Rich visual communication
- ✅ Share moments instantly
- ✅ Complete messaging experience
- ✅ Competitive with WhatsApp/iMessage
- ✅ Feature-complete MVP

### Success in One Sentence

"This PR is successful when users can select/capture images from their device, see them compress and upload with progress indication, view thumbnails in chat bubbles, tap to see full-screen with zoom, and receive image messages from others in real-time."

---

## Technical Design

### Architecture Decisions

#### Decision 1: Image Storage Backend

**Options Considered:**
1. **Firebase Storage** - Google Cloud Storage for Firebase
   - Pros: Integrated with Firestore, secure URLs, SDKs, scales automatically
   - Cons: Costs money ($0.026/GB storage, $0.12/GB download)

2. **Firestore Directly** (Base64 encode)
   - Pros: No extra service, simple
   - Cons: 1MB document limit, slow queries, expensive reads

3. **Third-Party CDN** (Cloudinary, Imgix)
   - Pros: Image optimization, transformations, fast delivery
   - Cons: Extra service, more complexity, another API

**Chosen:** Firebase Storage (Option 1)

**Rationale:**
- **Integrated**: Same Firebase project, unified auth, Firestore references
- **Scalable**: Handles millions of images automatically
- **Secure**: Built-in access control, signed URLs, auth integration
- **Performance**: Global CDN, fast downloads
- **Cost-Effective**: Free tier (5GB storage, 1GB/day download) sufficient for MVP
- **Simple**: Firebase SDK handles upload/download
- **Reliable**: 99.95% uptime SLA

**Trade-offs:**
- Gain: Reliable, scalable, integrated, secure
- Lose: Small cost at scale (acceptable for production app)

---

#### Decision 2: Image Compression Strategy

**Options Considered:**
1. **No Compression** - Upload original images
   - Pros: Best quality, simple
   - Cons: Slow uploads, expensive storage/bandwidth, poor UX on slow networks

2. **Server-Side Compression** - Cloud Functions resize images
   - Pros: Offload processing, consistent results
   - Cons: Complex, requires Cloud Functions, costs money, latency

3. **Client-Side Compression** - Swift compress before upload
   - Pros: Fast, free, good UX (instant feedback), works offline
   - Cons: Battery usage, CPU on device

**Chosen:** Client-Side Compression (Option 3)

**Rationale:**
- **Speed**: Compress locally while showing upload progress
- **UX**: Instant thumbnail preview before upload completes
- **Cost**: No Cloud Functions needed (free)
- **Offline**: Compress even when offline, upload later
- **Control**: Precise quality/size targets

**Compression Settings:**
- **Max file size**: 2MB (target) for full image
- **Max dimensions**: 1920x1920px (HD quality, reasonable size)
- **JPEG quality**: Start 0.7, adjust down if needed
- **Thumbnail**: 200x200px, quality 0.5, <50KB

**Trade-offs:**
- Gain: Fast, free, immediate feedback
- Lose: Small battery usage (acceptable for image operations)

---

#### Decision 3: Image Storage Structure

**Options Considered:**
1. **Flat Structure** - `/images/{messageId}.jpg`
   - Pros: Simple, easy to implement
   - Cons: Hard to organize, cleanup difficult, no grouping

2. **Conversation-Based** - `/images/{conversationId}/{messageId}.jpg`
   - Pros: Organized by chat, easier cleanup, logical grouping
   - Cons: Slightly more complex, longer paths

3. **User-Based** - `/images/{userId}/{messageId}.jpg`
   - Pros: Per-user quotas, user management
   - Cons: Doesn't match message flow, complex permissions

**Chosen:** Conversation-Based (Option 2)

**Rationale:**
- **Logical**: Images belong to conversations, not just users
- **Permissions**: Easy to enforce (if in conversation, can see images)
- **Cleanup**: Delete conversation → delete all images (via Storage Rules)
- **Organization**: Makes debugging and management easier

**Storage Paths:**
```
/chat_images/
  {conversationId}/
    {messageId}.jpg          ← Full-size image (max 2MB)
    {messageId}_thumb.jpg    ← Thumbnail (200x200, <50KB)
```

**Firestore Message Document:**
```javascript
{
  id: "msg_123",
  conversationId: "conv_456",
  senderId: "user_789",
  text: "",                           // Empty for image-only messages
  imageURL: "https://storage.../messageId.jpg",     // Full image
  thumbnailURL: "https://storage.../messageId_thumb.jpg", // Thumbnail
  sentAt: Timestamp,
  status: "sent"
}
```

---

#### Decision 4: Image Picker Implementation

**Options Considered:**
1. **UIKit UIImagePickerController** - Classic iOS image picker
   - Pros: Battle-tested, works on all iOS versions, simple
   - Cons: UIKit in SwiftUI app (not ideal but manageable)

2. **SwiftUI PhotosPicker (iOS 16+)** - Native SwiftUI picker
   - Pros: Pure SwiftUI, modern, better UX
   - Cons: iOS 16+ only, newer (less battle-tested)

3. **Third-Party** (e.g., BSImagePicker)
   - Pros: Custom UI, extra features
   - Cons: Extra dependency, maintenance burden

**Chosen:** UIKit UIImagePickerController (Option 1)

**Rationale:**
- **Compatibility**: Works on iOS 16.0+ (our minimum)
- **Reliability**: Mature, well-documented, stable
- **Camera Support**: Built-in camera capture
- **Simple**: UIViewControllerRepresentable wrapper (20 lines)
- **Familiar**: Industry-standard pattern

**Implementation Pattern:**
```swift
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func makeCoordinator() -> Coordinator { ... }
}
```

---

#### Decision 5: Upload Progress & UX

**Options Considered:**
1. **No Progress** - Upload silently in background
   - Pros: Simple, no UI needed
   - Cons: User doesn't know what's happening, feels broken

2. **Indeterminate Spinner** - Loading indicator without progress
   - Pros: Shows activity, simple
   - Cons: No sense of completion, frustrating on slow networks

3. **Progress Bar** - 0-100% upload progress
   - Pros: Clear feedback, user knows when done, handles slow networks
   - Cons: More complex implementation

**Chosen:** Progress Bar (Option 3)

**Rationale:**
- **User Confidence**: See upload happening, know it's working
- **Slow Network UX**: Essential for 3G/poor connections
- **Perception**: Makes upload feel faster (progress illusion)
- **Standard**: WhatsApp, iMessage, Telegram all show progress

**Progress States:**
```swift
enum ImageUploadState {
    case idle
    case compressing
    case uploading(progress: Double)  // 0.0 to 1.0
    case completed(imageURL: String)
    case failed(error: String)
}
```

**Visual Display:**
- Message bubble shows thumbnail immediately (optimistic UI)
- Circular progress ring overlaid on thumbnail
- 0-100% numeric percentage
- Smooth animation (60fps)
- Error state with retry button

---

### Data Model

#### Message Model Updates

**Add Fields:**
```swift
struct Message {
    // ... existing fields ...
    
    // NEW: Image support
    var imageURL: String?          // Full-size image URL from Storage
    var thumbnailURL: String?      // Thumbnail URL (200x200)
    var imageWidth: Int?           // Original image dimensions
    var imageHeight: Int?          // For aspect ratio calculation
    var imageSize: Int?            // File size in bytes (for stats)
    
    // Computed properties
    var hasImage: Bool {
        imageURL != nil
    }
    
    var isImageOnly: Bool {
        hasImage && (text.isEmpty || text.trimmingCharacters(in: .whitespaces).isEmpty)
    }
    
    var aspectRatio: Double? {
        guard let width = imageWidth, let height = imageHeight, height > 0 else { return nil }
        return Double(width) / Double(height)
    }
}
```

**Firestore Conversion:**
```swift
// To Firestore
func toDictionary() -> [String: Any] {
    var dict: [String: Any] = [
        "id": id,
        // ... existing fields ...
    ]
    
    // Add image fields if present
    if let imageURL = imageURL {
        dict["imageURL"] = imageURL
    }
    if let thumbnailURL = thumbnailURL {
        dict["thumbnailURL"] = thumbnailURL
    }
    if let imageWidth = imageWidth {
        dict["imageWidth"] = imageWidth
    }
    if let imageHeight = imageHeight {
        dict["imageHeight"] = imageHeight
    }
    if let imageSize = imageSize {
        dict["imageSize"] = imageSize
    }
    
    return dict
}

// From Firestore
init?(dictionary: [String: Any]) {
    // ... existing fields ...
    
    self.imageURL = dictionary["imageURL"] as? String
    self.thumbnailURL = dictionary["thumbnailURL"] as? String
    self.imageWidth = dictionary["imageWidth"] as? Int
    self.imageHeight = dictionary["imageHeight"] as? Int
    self.imageSize = dictionary["imageSize"] as? Int
}
```

---

### Component Architecture

#### StorageService

**Purpose**: Encapsulate all Firebase Storage operations

```swift
import FirebaseStorage
import UIKit

@MainActor
class StorageService {
    private let storage = Storage.storage()
    private let storageRef: StorageReference
    
    init() {
        self.storageRef = storage.reference()
    }
    
    // MARK: - Image Upload
    
    /// Upload full image and thumbnail to Firebase Storage
    /// - Parameters:
    ///   - image: Original UIImage
    ///   - conversationId: Conversation ID for storage path
    ///   - messageId: Message ID for file naming
    /// - Returns: Tuple of (fullImageURL, thumbnailURL)
    func uploadImage(
        _ image: UIImage,
        conversationId: String,
        messageId: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> (imageURL: String, thumbnailURL: String) {
        // 1. Compress full image
        guard let fullImageData = ImageCompressor.compress(image, maxSizeMB: 2.0) else {
            throw StorageError.compressionFailed
        }
        
        // 2. Generate thumbnail
        guard let thumbnail = ImageCompressor.createThumbnail(image, size: CGSize(width: 200, height: 200)),
              let thumbnailData = ImageCompressor.compress(thumbnail, maxSizeMB: 0.05) else {
            throw StorageError.thumbnailFailed
        }
        
        // 3. Create storage references
        let basePath = "chat_images/\(conversationId)"
        let fullRef = storageRef.child("\(basePath)/\(messageId).jpg")
        let thumbRef = storageRef.child("\(basePath)/\(messageId)_thumb.jpg")
        
        // 4. Upload thumbnail first (fast, gives quick feedback)
        let thumbnailURL = try await uploadData(thumbnailData, to: thumbRef, progressHandler: nil)
        
        // 5. Upload full image with progress
        let imageURL = try await uploadData(fullImageData, to: fullRef, progressHandler: progressHandler)
        
        return (imageURL, thumbnailURL)
    }
    
    // MARK: - Private Helpers
    
    private func uploadData(
        _ data: Data,
        to ref: StorageReference,
        progressHandler: ((Double) -> Void)?
    ) async throws -> String {
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = ref.putData(data, metadata: metadata)
            
            // Track progress
            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    progressHandler?(percentComplete)
                }
            }
            
            // Handle completion
            uploadTask.observe(.success) { _ in
                ref.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let url = url {
                        continuation.resume(returning: url.absoluteString)
                    } else {
                        continuation.resume(throwing: StorageError.noDownloadURL)
                    }
                }
            }
            
            uploadTask.observe(.failure) { snapshot in
                if let error = snapshot.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: StorageError.uploadFailed)
                }
            }
        }
    }
    
    // MARK: - Image Download (for caching)
    
    func downloadImage(from urlString: String) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw StorageError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw StorageError.invalidImageData
        }
        
        return image
    }
    
    // MARK: - Image Deletion
    
    func deleteImage(at urlString: String) async throws {
        let ref = storage.reference(forURL: urlString)
        try await ref.delete()
    }
}

// MARK: - Errors

enum StorageError: LocalizedError {
    case compressionFailed
    case thumbnailFailed
    case uploadFailed
    case noDownloadURL
    case invalidURL
    case invalidImageData
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed: return "Failed to compress image"
        case .thumbnailFailed: return "Failed to create thumbnail"
        case .uploadFailed: return "Image upload failed"
        case .noDownloadURL: return "Could not get download URL"
        case .invalidURL: return "Invalid image URL"
        case .invalidImageData: return "Invalid image data"
        }
    }
}
```

---

#### ImageCompressor Utility

**Purpose**: Compress and resize images efficiently

```swift
import UIKit

struct ImageCompressor {
    /// Compress image to target size with quality adjustment
    static func compress(
        _ image: UIImage,
        maxSizeMB: Double = 2.0,
        maxWidth: CGFloat = 1920
    ) -> Data? {
        // 1. Resize if needed
        let resized = resize(image, maxWidth: maxWidth)
        
        // 2. Compress to target size
        var compressionQuality: CGFloat = 0.7
        var imageData = resized.jpegData(compressionQuality: compressionQuality)
        
        let maxSizeBytes = maxSizeMB * 1024 * 1024
        
        // Iteratively reduce quality until under target size
        while let data = imageData,
              data.count > Int(maxSizeBytes),
              compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = resized.jpegData(compressionQuality: compressionQuality)
        }
        
        return imageData
    }
    
    /// Create thumbnail with fixed size
    static func createThumbnail(
        _ image: UIImage,
        size: CGSize = CGSize(width: 200, height: 200)
    ) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /// Resize image maintaining aspect ratio
    static func resize(
        _ image: UIImage,
        maxWidth: CGFloat
    ) -> UIImage {
        let width = image.size.width
        let height = image.size.height
        
        // If already smaller, return original
        if width <= maxWidth && height <= maxWidth {
            return image
        }
        
        // Calculate new dimensions maintaining aspect ratio
        let aspectRatio = width / height
        let newSize: CGSize
        
        if width > height {
            // Landscape
            newSize = CGSize(width: maxWidth, height: maxWidth / aspectRatio)
        } else {
            // Portrait or square
            newSize = CGSize(width: maxWidth * aspectRatio, height: maxWidth)
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
```

---

#### ImagePicker Utility

**Purpose**: UIKit image picker wrapped for SwiftUI

```swift
import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = false  // User can crop later if needed
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
```

---

### ChatViewModel Updates

**Add Image Handling:**

```swift
@MainActor
class ChatViewModel: ObservableObject {
    // ... existing properties ...
    
    // NEW: Image handling
    @Published var imageUploadProgress: Double = 0.0
    @Published var isUploadingImage: Bool = false
    @Published var uploadError: String?
    
    private let storageService = StorageService()
    
    // ... existing methods ...
    
    /// Send image message with upload progress
    func sendImageMessage(_ image: UIImage) {
        isUploadingImage = true
        uploadError = nil
        imageUploadProgress = 0.0
        
        Task {
            do {
                // 1. Generate message ID
                let messageId = UUID().uuidString
                
                // 2. Upload image with progress
                let (imageURL, thumbnailURL) = try await storageService.uploadImage(
                    image,
                    conversationId: conversationId,
                    messageId: messageId
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.imageUploadProgress = progress
                    }
                }
                
                // 3. Create message with image URLs
                let message = Message(
                    id: messageId,
                    conversationId: conversationId,
                    senderId: authService.currentUserId ?? "",
                    text: "",  // Empty for image-only message
                    imageURL: imageURL,
                    thumbnailURL: thumbnailURL,
                    imageWidth: Int(image.size.width),
                    imageHeight: Int(image.size.height),
                    sentAt: Date(),
                    status: .sending
                )
                
                // 4. Send message (existing flow)
                try await chatService.sendMessage(message)
                
                // 5. Success
                await MainActor.run {
                    isUploadingImage = false
                    imageUploadProgress = 0.0
                }
                
            } catch {
                await MainActor.run {
                    isUploadingImage = false
                    uploadError = error.localizedDescription
                }
            }
        }
    }
    
    /// Retry failed image upload
    func retryImageUpload() {
        uploadError = nil
        // Retry logic (would need to store original UIImage)
    }
}
```

---

### MessageBubbleView Updates

**Add Image Display:**

```swift
struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    let conversation: Conversation?
    
    @State private var showFullImage = false
    
    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            // Sender name (for group chats, received messages)
            if let senderName = senderName {
                Text(senderName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 12)
            }
            
            // Message bubble
            HStack(alignment: .bottom, spacing: 8) {
                if isFromCurrentUser { Spacer() }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Image (if present)
                    if message.hasImage {
                        MessageImageView(message: message)
                            .onTapGesture {
                                showFullImage = true
                            }
                    }
                    
                    // Text (if present)
                    if !message.text.isEmpty {
                        Text(message.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    
                    // Timestamp and status
                    HStack(spacing: 4) {
                        Text(message.sentAt, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if isFromCurrentUser {
                            statusIcon
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }
                .background(bubbleColor)
                .cornerRadius(16)
                
                if !isFromCurrentUser { Spacer() }
            }
        }
        .sheet(isPresented: $showFullImage) {
            if let imageURL = message.imageURL {
                FullScreenImageView(imageURL: imageURL, message: message)
            }
        }
    }
    
    // ... existing computed properties ...
}

// MARK: - MessageImageView (Thumbnail in Bubble)

struct MessageImageView: View {
    let message: Message
    
    var body: some View {
        if let thumbnailURL = message.thumbnailURL {
            AsyncImage(url: URL(string: thumbnailURL)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 200, height: 200)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(message.aspectRatio ?? 1.0, contentMode: .fill)
                        .frame(maxWidth: 250, maxHeight: 250)
                        .clipped()
                        .cornerRadius(12)
                case .failure:
                    Image(systemName: "photo.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 200, height: 200)
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - FullScreenImageView (Modal)

struct FullScreenImageView: View {
    let imageURL: String
    let message: Message
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                AsyncImage(url: URL(string: imageURL)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        // Reset if too small/large
                                        if scale < 1.0 {
                                            withAnimation {
                                                scale = 1.0
                                                lastScale = 1.0
                                            }
                                        } else if scale > 5.0 {
                                            withAnimation {
                                                scale = 5.0
                                                lastScale = 5.0
                                            }
                                        }
                                    }
                            )
                    case .failure:
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                            Text("Failed to load image")
                                .foregroundColor(.white)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}
```

---

### MessageInputView Updates

**Add Image Button:**

```swift
struct MessageInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    let onImageSelect: (UIImage) -> Void  // NEW
    
    @State private var showImagePicker = false
    @State private var showActionSheet = false
    @State private var selectedImage: UIImage?
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Image button
            Button(action: {
                showActionSheet = true
            }) {
                Image(systemName: "photo.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            
            // Text input
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .lineLimit(1...5)
            
            // Send button
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(canSend ? .blue : .gray)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .confirmationDialog("Choose Image Source", isPresented: $showActionSheet) {
            Button("Photo Library") {
                imageSourceType = .photoLibrary
                showImagePicker = true
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") {
                    imageSourceType = .camera
                    showImagePicker = true
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: imageSourceType)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                onImageSelect(image)
                selectedImage = nil
            }
        }
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```

---

### Firebase Storage Security Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Helper function: Check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function: Check if user is participant in conversation
    function isParticipant(conversationId) {
      let conversation = firestore.get(/databases/(default)/documents/conversations/$(conversationId));
      return isAuthenticated() && request.auth.uid in conversation.data.participants;
    }
    
    // Profile pictures
    match /profile_pictures/{userId} {
      // Anyone authenticated can read
      allow read: if isAuthenticated();
      // Only owner can write
      allow write: if isAuthenticated() && request.auth.uid == userId;
    }
    
    // Chat images
    match /chat_images/{conversationId}/{imageFile} {
      // Only conversation participants can read
      allow read: if isParticipant(conversationId);
      // Only conversation participants can write
      allow write: if isParticipant(conversationId);
    }
    
    // Deny all other access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

---

## Implementation Details

### File Structure

**New Files:**
```
messAI/
├── Services/
│   └── StorageService.swift           (~200 lines) - Firebase Storage operations
├── Utilities/
│   ├── ImageCompressor.swift          (~150 lines) - Image compression
│   └── ImagePicker.swift              (~80 lines) - UIKit picker wrapper
└── Views/
    └── Chat/
        └── FullScreenImageView.swift  (~100 lines) - Image viewer modal
```

**Modified Files:**
```
messAI/
├── Models/
│   └── Message.swift                  (+80 lines) - Image fields
├── Services/
│   └── ChatService.swift              (+50 lines) - Image message support
├── ViewModels/
│   └── ChatViewModel.swift            (+100 lines) - Upload logic
└── Views/
    └── Chat/
        ├── MessageBubbleView.swift    (+80 lines) - Image display
        ├── MessageInputView.swift     (+60 lines) - Image button
        └── ChatView.swift             (+20 lines) - Image callback
```

**Total:**
- **4 new files** (~530 lines)
- **6 modified files** (+390 lines)
- **~920 lines total**

---

### Implementation Phases

#### Phase 1: Core Infrastructure (45 min)
1. Create ImageCompressor utility (30 min)
   - compress() method with quality iteration
   - createThumbnail() method with fixed size
   - resize() method maintaining aspect ratio
   - Test with various image sizes

2. Create ImagePicker wrapper (15 min)
   - UIViewControllerRepresentable implementation
   - Coordinator for delegate methods
   - Support .photoLibrary and .camera
   - Test with device

**Checkpoint:** Can select images from library and camera ✓

---

#### Phase 2: Storage Service (60 min)
1. Create StorageService class (45 min)
   - uploadImage() with progress tracking
   - uploadData() helper with continuation
   - downloadImage() for caching
   - deleteImage() for cleanup
   - Proper error handling
   - Test upload/download cycle

2. Firebase Storage Rules (15 min)
   - Write rules file
   - Deploy to Firebase
   - Test access control
   - Verify participants-only access

**Checkpoint:** Images upload to Firebase Storage ✓

---

#### Phase 3: Model & Service Updates (30 min)
1. Update Message model (15 min)
   - Add image fields (URL, thumbnail, dimensions)
   - Add computed properties (hasImage, aspectRatio)
   - Update Firestore conversion
   - Test model serialization

2. Update ChatService (15 min)
   - Support image messages in sendMessage()
   - Handle image fields in Firestore
   - Test with real messages

**Checkpoint:** Image messages save to Firestore ✓

---

#### Phase 4: ViewModel Integration (45 min)
1. Update ChatViewModel (30 min)
   - Add sendImageMessage() method
   - Add upload progress tracking
   - Add error handling
   - Integrate StorageService
   - Test upload flow

2. Upload Progress UI (15 min)
   - Progress state management
   - Progress binding to view
   - Error state handling

**Checkpoint:** Images upload with progress tracking ✓

---

#### Phase 5: UI Components (60 min)
1. Update MessageBubbleView (30 min)
   - Add MessageImageView component
   - Display thumbnails in bubbles
   - Handle tap for full-screen
   - Proper sizing and aspect ratio
   - Test in chat view

2. Create FullScreenImageView (30 min)
   - Modal presentation
   - Pinch-to-zoom gesture
   - AsyncImage loading
   - Done button
   - Test zoom and dismiss

**Checkpoint:** Images display in chat and full-screen ✓

---

#### Phase 6: Input Updates (30 min)
1. Update MessageInputView (20 min)
   - Add image button
   - Add action sheet (library/camera)
   - Integrate ImagePicker
   - Handle image selection
   - Test both sources

2. Update ChatView (10 min)
   - Connect image callback
   - Pass to ChatViewModel
   - Test end-to-end flow

**Checkpoint:** Can send images from chat input ✓

---

#### Phase 7: Testing & Polish (30 min)
1. Comprehensive Testing (20 min)
   - Upload from library
   - Upload from camera
   - View in chat
   - View full-screen
   - Pinch-zoom
   - Multiple images in conversation
   - Offline upload queue

2. Error Handling (10 min)
   - Failed uploads
   - No permissions
   - Large images
   - Invalid images
   - Network errors

**Checkpoint:** All scenarios working ✓

---

## Testing Strategy

### Unit Tests

**ImageCompressor Tests:**
```swift
func testCompressReducesSize() {
    let largeImage = createTestImage(width: 4000, height: 3000)  // ~5MB
    let compressed = ImageCompressor.compress(largeImage, maxSizeMB: 2.0)
    
    XCTAssertNotNil(compressed)
    XCTAssertLessThan(compressed!.count, 2 * 1024 * 1024)  // < 2MB
}

func testThumbnailCorrectSize() {
    let image = createTestImage(width: 1920, height: 1080)
    let thumbnail = ImageCompressor.createThumbnail(image, size: CGSize(width: 200, height: 200))
    
    XCTAssertEqual(thumbnail?.size.width, 200)
    XCTAssertEqual(thumbnail?.size.height, 200)
}

func testResizeMaintainsAspectRatio() {
    let image = createTestImage(width: 1920, height: 1080)  // 16:9
    let resized = ImageCompressor.resize(image, maxWidth: 960)
    
    let aspectRatio = resized.size.width / resized.size.height
    XCTAssertEqual(aspectRatio, 16.0/9.0, accuracy: 0.01)
}
```

**StorageService Tests:**
```swift
func testUploadImageSuccess() async throws {
    let service = StorageService()
    let testImage = createTestImage(width: 1920, height: 1080)
    
    let (imageURL, thumbnailURL) = try await service.uploadImage(
        testImage,
        conversationId: "test_conv",
        messageId: "test_msg"
    ) { progress in
        XCTAssertGreaterThanOrEqual(progress, 0.0)
        XCTAssertLessThanOrEqual(progress, 1.0)
    }
    
    XCTAssertFalse(imageURL.isEmpty)
    XCTAssertFalse(thumbnailURL.isEmpty)
    XCTAssertTrue(imageURL.contains("chat_images/test_conv/test_msg.jpg"))
}

func testDownloadImage() async throws {
    let service = StorageService()
    let testURL = "https://firebasestorage.googleapis.com/..."
    
    let image = try await service.downloadImage(from: testURL)
    XCTAssertNotNil(image)
}
```

---

### Integration Tests

**Test 1: Send Image from Photo Library**
```
Given: User in active conversation
When: User taps image button → Photo Library → Selects image → Image sends
Then:
  - Image picker opens
  - Selected image shows in input preview (optional)
  - Upload progress shows 0% → 100%
  - Image appears in chat as thumbnail
  - Message status shows sending → sent
  - Image receives delivery receipts
```

**Test 2: Send Image from Camera**
```
Given: User in active conversation, device has camera
When: User taps image button → Camera → Takes photo → Image sends
Then:
  - Camera opens
  - Photo captures
  - Upload progress shows
  - Image appears in chat
  - Camera permissions work
```

**Test 3: View Full-Screen Image**
```
Given: Chat contains image message
When: User taps image thumbnail
Then:
  - Full-screen modal opens
  - Full-size image loads
  - User can pinch to zoom (1x to 5x)
  - User can tap "Done" to dismiss
  - Zoom state resets on reopen
```

**Test 4: Send Multiple Images**
```
Given: User in conversation
When: User sends 3 images in a row
Then:
  - Each image uploads independently
  - Progress tracks separately (or sequentially)
  - All images appear in chat
  - Order preserved (sent at different times)
```

**Test 5: Receive Image Message**
```
Given: Two users in conversation, User A sends image
When: User B receives image message
Then:
  - User B sees thumbnail in chat (<2 second latency)
  - User B can tap to view full-screen
  - User B can zoom image
  - Read receipt sends to User A
```

---

### Edge Cases

**Test 1: Upload Large Image (10MB+)**
```
Given: User selects very large image (10MB+)
When: Image compresses and uploads
Then:
  - Compression reduces to <2MB
  - Upload succeeds
  - Quality remains acceptable
  - No timeout errors
```

**Test 2: Upload Failed (Network Error)**
```
Given: User sending image, network drops mid-upload
When: Upload fails
Then:
  - Error message shows: "Upload failed. Retry?"
  - Retry button available
  - Tapping retry attempts upload again
  - Success clears error
```

**Test 3: No Camera Permission**
```
Given: User denies camera permission
When: User taps Camera option
Then:
  - Alert shows: "Camera access denied"
  - Suggestion to enable in Settings
  - Photo Library still works
```

**Test 4: No Photo Library Permission**
```
Given: User denies photo library permission
When: User taps Photo Library option
Then:
  - Alert shows: "Photo library access denied"
  - Suggestion to enable in Settings
  - Camera still works (if available)
```

**Test 5: Invalid Image Format**
```
Given: User somehow selects non-image file
When: System attempts to process
Then:
  - Error caught gracefully
  - Message: "Invalid image format"
  - No crash, user can try again
```

**Test 6: Offline Image Send**
```
Given: User offline (airplane mode)
When: User selects and sends image
Then:
  - Image compresses locally
  - Message queues for send (status: "sending")
  - When online, upload happens automatically
  - Message status updates to "sent"
```

---

### Performance Tests

**Test 1: Compression Speed**
```
Target: <2 seconds for 4K image compression
Given: 4000x3000 image (~8MB)
When: ImageCompressor.compress() called
Then: Completes in <2 seconds
```

**Test 2: Upload Speed**
```
Target: <10 seconds on WiFi, <30 seconds on 4G
Given: 2MB compressed image, good network
When: Uploading to Firebase Storage
Then: 
  - WiFi: <10 seconds
  - 4G: <30 seconds
  - Progress updates smoothly
```

**Test 3: Thumbnail Generation**
```
Target: <500ms for thumbnail creation
Given: Full-size image
When: ImageCompressor.createThumbnail() called
Then: Completes in <500ms
```

**Test 4: Full-Screen Load Time**
```
Target: <3 seconds on WiFi, <5 seconds on 4G
Given: User taps image thumbnail
When: Full-size image loads in modal
Then:
  - Loading indicator shows immediately
  - Image appears within target time
  - Smooth transition
```

---

### Acceptance Criteria

**PR is complete when:**

- [ ] **Image Selection**
  - [ ] Photo library picker works
  - [ ] Camera picker works (on device)
  - [ ] Action sheet shows both options
  - [ ] Permission requests handled

- [ ] **Image Compression**
  - [ ] Images compress to <2MB
  - [ ] Thumbnails generate at 200x200
  - [ ] Aspect ratio maintained
  - [ ] Quality acceptable (no visible artifacts)

- [ ] **Image Upload**
  - [ ] Upload progress shows 0-100%
  - [ ] Success returns URLs
  - [ ] Errors handled gracefully
  - [ ] Retry works after failure

- [ ] **Image Display**
  - [ ] Thumbnails show in chat bubbles
  - [ ] Aspect ratio correct
  - [ ] Loading states show
  - [ ] Tap opens full-screen

- [ ] **Full-Screen View**
  - [ ] Modal opens correctly
  - [ ] Full image loads
  - [ ] Pinch-to-zoom works (1x-5x)
  - [ ] Done button dismisses

- [ ] **Integration**
  - [ ] Images send from MessageInputView
  - [ ] Images display in MessageBubbleView
  - [ ] Images receive status indicators
  - [ ] Images work in groups
  - [ ] Images sync across devices

- [ ] **Security**
  - [ ] Storage rules deployed
  - [ ] Only participants can access images
  - [ ] Anonymous users denied
  - [ ] Rules tested and verified

- [ ] **Performance**
  - [ ] Compression <2s
  - [ ] Upload <10s (WiFi)
  - [ ] Thumbnail gen <500ms
  - [ ] Full-screen load <3s

- [ ] **Quality**
  - [ ] Zero crashes
  - [ ] No memory leaks
  - [ ] Works offline (queue)
  - [ ] All test scenarios pass

---

## Success Metrics

### Functional Metrics
- Image upload success rate: >95%
- Compression time: <2 seconds
- Upload time (WiFi): <10 seconds
- Full-screen load time: <3 seconds
- Permission grant rate: >80%

### Quality Metrics
- Crash rate: <0.1%
- Failed uploads: <5%
- Retry success rate: >90%
- User reports compression issues: <1%

---

## Risk Assessment

### Risk 1: Large Upload Times on Poor Networks 🟡 MEDIUM
**Issue:** Images take 30+ seconds to upload on slow 3G  
**Likelihood:** HIGH (users will have slow connections)  
**Impact:** MEDIUM (frustrating UX, but not blocking)  
**Mitigation:**
- Compress aggressively (target 2MB maximum)
- Show clear progress indicator (users wait if they see progress)
- Allow sending text while image uploads (non-blocking)
- Queue images to send in background
**Status:** Mitigated

---

### Risk 2: Firebase Storage Costs 🟢 LOW
**Issue:** Storage and bandwidth costs money at scale  
**Likelihood:** LOW (free tier: 5GB storage, 1GB/day download)  
**Impact:** LOW (costs minimal for MVP, ~$0.026/GB)  
**Mitigation:**
- Compress images to reduce storage (<2MB target)
- Use thumbnails in chat (reduce bandwidth)
- Monitor usage in Firebase Console
- Implement image deletion when messages/conversations deleted
**Cost Estimate:**
- 1000 users, 50 images each = 50K images
- 50K images × 2MB = 100GB storage = ~$2.60/month
- Daily bandwidth: 1GB free, then $0.12/GB
**Status:** Acceptable for MVP

---

### Risk 3: Memory Usage (Large Images) 🟡 MEDIUM
**Issue:** Loading many large images causes memory pressure  
**Likelihood:** MEDIUM (users scroll through image-heavy chats)  
**Impact:** MEDIUM (app crashes on older devices)  
**Mitigation:**
- Use thumbnails in chat (200x200, <50KB)
- Lazy load with AsyncImage (automatic)
- Unload off-screen images
- Profile with Instruments
- Test on older devices (iPhone 8)
**Status:** Mitigated via thumbnails

---

### Risk 4: Camera/Photo Permission Denials 🟢 LOW
**Issue:** Users deny camera or photo library permissions  
**Likelihood:** MEDIUM (10-20% deny initially)  
**Impact:** LOW (can still use other features, can enable later)  
**Mitigation:**
- Clear permission request descriptions in Info.plist
- Graceful error messages with instructions
- Offer both camera and library (redundancy)
- Guide users to Settings if denied
**Status:** Mitigated

---

### Risk 5: Invalid/Corrupt Images 🟢 LOW
**Issue:** User selects invalid or corrupt image file  
**Likelihood:** LOW (iOS picker filters most)  
**Impact:** LOW (single failed upload)  
**Mitigation:**
- Validate UIImage is not nil
- Catch compression failures
- Show clear error message
- Allow retry
**Status:** Mitigated

---

## Open Questions

**None** - All decisions made, ready to implement!

---

## Timeline

**Total Estimate:** 2-3 hours

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Image utilities (compressor, picker) | 45 min | ⏳ |
| 2 | Storage service + rules | 60 min | ⏳ |
| 3 | Model & service updates | 30 min | ⏳ |
| 4 | ViewModel integration | 45 min | ⏳ |
| 5 | UI components (bubble, full-screen) | 60 min | ⏳ |
| 6 | Input updates | 30 min | ⏳ |
| 7 | Testing & polish | 30 min | ⏳ |
| **Total** | **All phases** | **2-3h** | **⏳** |

---

## Dependencies

### Requires (Complete):
- [x] PR #4: Message model (will extend with image fields) ✅
- [x] PR #5: ChatService (will extend with image support) ✅
- [x] PR #9: ChatView components (will update with images) ✅
- [x] PR #10: Real-time messaging (images use same flow) ✅
- [x] PR #11: Message status (images get status too) ✅

### Blocks:
- None - PR #14 is independent

### Enables:
- Full multimedia messaging experience
- Richer communication
- Competitive feature parity

---

## References

- Firebase Storage Docs: https://firebase.google.com/docs/storage
- UIImagePickerController: https://developer.apple.com/documentation/uikit/uiimagepickercontroller
- Image Compression: https://developer.apple.com/documentation/uikit/uiimage
- Storage Security Rules: https://firebase.google.com/docs/storage/security

---

**Ready to Build!** 🚀

This PR will complete the multimedia messaging experience, enabling users to share visual moments alongside text. It's the final piece of the core messaging feature set.

**Next:** After PR #14, we'll have feature-complete messaging: text ✅, images ✅, groups ✅, status ✅, presence ✅, typing ✅. Then we move to polish and deployment phases (PRs #15-22).

