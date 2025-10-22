# PR#23: Image Sharing - Implementation Checklist

**Use this as your daily todo list.** Check off items as you complete them.

---

## Pre-Implementation Setup (10 minutes)

- [ ] Read main planning document (`PR14_IMAGE_SHARING.md`) (~45 min)
- [ ] Prerequisites verified:
  - [ ] PR #4 (Message model) complete ✅
  - [ ] PR #5 (ChatService) complete ✅
  - [ ] PR #9 (ChatView) complete ✅
  - [ ] PR #10 (Real-time messaging) complete ✅
  - [ ] PR #11 (Message status) complete ✅
  - [ ] Firebase project has Storage enabled
  - [ ] Xcode open with messAI project
  - [ ] Physical iOS device available (for camera testing)

- [ ] Environment configured:
  - [ ] Xcode build successful
  - [ ] No existing linter errors
  - [ ] Firebase connected and working

- [ ] Git branch created:
  ```bash
  git checkout main
  git pull origin main
  git checkout -b feature/pr14-image-sharing
  ```

**Checkpoint:** Ready to start implementation ✓

---

## Phase 1: Core Image Utilities (45 minutes)

### 1.1: Create ImageCompressor Utility (30 minutes)

#### Create File
- [ ] Create `messAI/Utilities/ImageCompressor.swift`
- [ ] Add to Xcode project (Utilities group)

#### Add Imports
- [ ] Add imports:
  ```swift
  import UIKit
  ```

#### Implement Compression Methods
- [ ] Create `ImageCompressor` struct:
  ```swift
  struct ImageCompressor {
      // Methods will be static
  }
  ```

- [ ] Implement `compress()` method:
  ```swift
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
  ```

- [ ] Implement `resize()` helper method:
  ```swift
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
  ```

- [ ] Implement `createThumbnail()` method:
  ```swift
  static func createThumbnail(
      _ image: UIImage,
      size: CGSize = CGSize(width: 200, height: 200)
  ) -> UIImage? {
      let renderer = UIGraphicsImageRenderer(size: size)
      return renderer.image { context in
          image.draw(in: CGRect(origin: .zero, size: size))
      }
  }
  ```

#### Test Compression
- [ ] Build project (Cmd+B)
- [ ] Fix any compilation errors
- [ ] Verify methods are available

**Checkpoint:** ImageCompressor utility complete ✓

**Commit:** `git add . && git commit -m "feat(utilities): Add ImageCompressor for image optimization"`

---

### 1.2: Create ImagePicker Wrapper (15 minutes)

#### Create File
- [ ] Create `messAI/Utilities/ImagePicker.swift`
- [ ] Add to Xcode project (Utilities group)

#### Add Imports
- [ ] Add imports:
  ```swift
  import SwiftUI
  import UIKit
  ```

#### Implement ImagePicker Struct
- [ ] Create ImagePicker conforming to UIViewControllerRepresentable:
  ```swift
  struct ImagePicker: UIViewControllerRepresentable {
      @Binding var image: UIImage?
      @Environment(\.dismiss) var dismiss
      
      var sourceType: UIImagePickerController.SourceType = .photoLibrary
      
      // ... methods below
  }
  ```

- [ ] Implement `makeUIViewController`:
  ```swift
  func makeUIViewController(context: Context) -> UIImagePickerController {
      let picker = UIImagePickerController()
      picker.sourceType = sourceType
      picker.allowsEditing = false
      picker.delegate = context.coordinator
      return picker
  }
  ```

- [ ] Implement `updateUIViewController`:
  ```swift
  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
      // No updates needed
  }
  ```

- [ ] Implement `makeCoordinator`:
  ```swift
  func makeCoordinator() -> Coordinator {
      Coordinator(self)
  }
  ```

#### Implement Coordinator
- [ ] Add Coordinator class inside ImagePicker:
  ```swift
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
  ```

#### Test Build
- [ ] Build project (Cmd+B)
- [ ] Fix any compilation errors
- [ ] Verify ImagePicker is available in SwiftUI

**Checkpoint:** ImagePicker wrapper complete ✓

**Commit:** `git add . && git commit -m "feat(utilities): Add ImagePicker UIKit wrapper for SwiftUI"`

---

## Phase 2: Firebase Storage Service (60 minutes)

### 2.1: Create StorageService (45 minutes)

#### Create File
- [ ] Create `messAI/Services/StorageService.swift`
- [ ] Add to Xcode project (Services group)

#### Add Imports
- [ ] Add imports:
  ```swift
  import FirebaseStorage
  import UIKit
  ```

#### Create Error Enum
- [ ] Add StorageError enum at bottom of file:
  ```swift
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

#### Create StorageService Class
- [ ] Add class with @MainActor:
  ```swift
  @MainActor
  class StorageService {
      private let storage = Storage.storage()
      private let storageRef: StorageReference
      
      init() {
          self.storageRef = storage.reference()
      }
      
      // Methods below
  }
  ```

#### Implement Main Upload Method
- [ ] Add `uploadImage()` method:
  ```swift
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
  ```

#### Implement Upload Helper
- [ ] Add `uploadData()` private method:
  ```swift
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
  ```

#### Implement Additional Methods
- [ ] Add `downloadImage()` method:
  ```swift
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
  ```

- [ ] Add `deleteImage()` method:
  ```swift
  func deleteImage(at urlString: String) async throws {
      let ref = storage.reference(forURL: urlString)
      try await ref.delete()
  }
  ```

#### Test Build
- [ ] Build project (Cmd+B)
- [ ] Fix any compilation errors
- [ ] Verify StorageService compiles

**Checkpoint:** StorageService complete ✓

**Commit:** `git add . && git commit -m "feat(services): Add StorageService for Firebase Storage integration"`

---

### 2.2: Firebase Storage Security Rules (15 minutes)

#### Create Rules File
- [ ] Create `firebase/storage.rules` (if doesn't exist)

#### Write Security Rules
- [ ] Add storage rules:
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

#### Deploy Rules
- [ ] Open terminal in project root
- [ ] Deploy storage rules:
  ```bash
  firebase deploy --only storage
  ```
- [ ] Verify deployment successful
- [ ] Check Firebase Console > Storage > Rules

**Checkpoint:** Storage rules deployed ✓

**Commit:** `git add firebase/storage.rules && git commit -m "feat(firebase): Add Storage security rules for chat images"`

---

## Phase 3: Model & Service Updates (30 minutes)

### 3.1: Update Message Model (15 minutes)

#### Open Message Model
- [ ] Open `messAI/Models/Message.swift`

#### Add Image Fields
- [ ] Add properties to Message struct:
  ```swift
  // Image support
  var imageURL: String?
  var thumbnailURL: String?
  var imageWidth: Int?
  var imageHeight: Int?
  var imageSize: Int?
  ```

#### Add Computed Properties
- [ ] Add computed properties after existing properties:
  ```swift
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
  ```

#### Update Initializer
- [ ] Update `init()` to include image parameters (make them optional with defaults):
  ```swift
  init(
      id: String = UUID().uuidString,
      conversationId: String,
      senderId: String,
      text: String,
      imageURL: String? = nil,           // NEW
      thumbnailURL: String? = nil,       // NEW
      imageWidth: Int? = nil,            // NEW
      imageHeight: Int? = nil,           // NEW
      imageSize: Int? = nil,             // NEW
      sentAt: Date = Date(),
      deliveredAt: Date? = nil,
      readAt: Date? = nil,
      status: MessageStatus = .sending,
      deliveredTo: [String] = [],
      readBy: [String] = []
  ) {
      self.id = id
      self.conversationId = conversationId
      self.senderId = senderId
      self.text = text
      self.imageURL = imageURL          // NEW
      self.thumbnailURL = thumbnailURL  // NEW
      self.imageWidth = imageWidth      // NEW
      self.imageHeight = imageHeight    // NEW
      self.imageSize = imageSize        // NEW
      self.sentAt = sentAt
      self.deliveredAt = deliveredAt
      self.readAt = readAt
      self.status = status
      self.deliveredTo = deliveredTo
      self.readBy = readBy
  }
  ```

#### Update Firestore Conversion
- [ ] Update `toDictionary()` method to include image fields:
  ```swift
  func toDictionary() -> [String: Any] {
      var dict: [String: Any] = [
          "id": id,
          "conversationId": conversationId,
          "senderId": senderId,
          "text": text,
          "sentAt": Timestamp(date: sentAt),
          "status": status.rawValue,
          "deliveredTo": deliveredTo,
          "readBy": readBy
      ]
      
      // Add optional fields
      if let deliveredAt = deliveredAt {
          dict["deliveredAt"] = Timestamp(date: deliveredAt)
      }
      if let readAt = readAt {
          dict["readAt"] = Timestamp(date: readAt)
      }
      
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
  ```

- [ ] Update `init?(dictionary:)` to parse image fields:
  ```swift
  init?(dictionary: [String: Any]) {
      // ... existing fields ...
      
      // Parse image fields
      self.imageURL = dictionary["imageURL"] as? String
      self.thumbnailURL = dictionary["thumbnailURL"] as? String
      self.imageWidth = dictionary["imageWidth"] as? Int
      self.imageHeight = dictionary["imageHeight"] as? Int
      self.imageSize = dictionary["imageSize"] as? Int
  }
  ```

#### Test Build
- [ ] Build project (Cmd+B)
- [ ] Fix any compilation errors
- [ ] Verify Message model compiles

**Checkpoint:** Message model supports images ✓

**Commit:** `git add . && git commit -m "feat(models): Add image fields to Message model"`

---

### 3.2: Update ChatService (15 minutes)

#### Open ChatService
- [ ] Open `messAI/Services/ChatService.swift`

#### Update sendMessage Method
- [ ] Verify `sendMessage()` already handles optional fields correctly
- [ ] No changes needed - existing method will pass through image fields via `message.toDictionary()`

#### Test Build
- [ ] Build project (Cmd+B)
- [ ] Verify no compilation errors

**Checkpoint:** ChatService supports image messages ✓

**Commit:** `git add . && git commit -m "chore(services): Verify ChatService handles image messages"`

---

## Phase 4: ViewModel Integration (45 minutes)

### 4.1: Update ChatViewModel (30 minutes)

#### Open ChatViewModel
- [ ] Open `messAI/ViewModels/ChatViewModel.swift`

#### Add Properties
- [ ] Add image upload state properties:
  ```swift
  // Image upload state
  @Published var imageUploadProgress: Double = 0.0
  @Published var isUploadingImage: Bool = false
  @Published var uploadError: String?
  ```

#### Add StorageService Instance
- [ ] Add StorageService property after authService:
  ```swift
  private let storageService = StorageService()
  ```

#### Implement sendImageMessage Method
- [ ] Add new method after existing `sendMessage()`:
  ```swift
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
              
              // 4. Add to messages array immediately (optimistic UI)
              await MainActor.run {
                  messages.append(message)
              }
              
              // 5. Send message to Firestore
              try await chatService.sendMessage(message)
              
              // 6. Success
              await MainActor.run {
                  isUploadingImage = false
                  imageUploadProgress = 0.0
              }
              
          } catch {
              await MainActor.run {
                  isUploadingImage = false
                  uploadError = error.localizedDescription
                  // Remove optimistic message on failure
                  if let index = messages.firstIndex(where: { $0.hasImage && $0.status == .sending }) {
                      messages.remove(at: index)
                  }
              }
          }
      }
  }
  ```

#### Add Retry Method
- [ ] Add retry method for failed uploads:
  ```swift
  /// Retry failed image upload
  func retryImageUpload() {
      uploadError = nil
      // Note: Would need to store original UIImage to retry
      // For MVP, user can select image again
  }
  ```

#### Test Build
- [ ] Build project (Cmd+B)
- [ ] Fix any compilation errors

**Checkpoint:** ChatViewModel can upload images ✓

**Commit:** `git add . && git commit -m "feat(viewmodels): Add image upload to ChatViewModel"`

---

### 4.2: Add Upload Progress UI (15 minutes)

#### Update ChatViewModel Progress Tracking
- [ ] Verify progress properties are @Published (done above)
- [ ] Progress updates happen on @MainActor (done above)

#### Test Build
- [ ] Build project (Cmd+B)
- [ ] Verify no errors

**Checkpoint:** Upload progress infrastructure ready ✓

**Commit:** `git add . && git commit -m "feat(viewmodels): Add upload progress tracking"`

---

## Phase 5: UI Components (60 minutes)

### 5.1: Update MessageBubbleView (30 minutes)

#### Open MessageBubbleView
- [ ] Open `messAI/Views/Chat/MessageBubbleView.swift`

#### Add State for Full-Screen
- [ ] Add state property at top of struct:
  ```swift
  @State private var showFullImage = false
  ```

#### Update Body to Show Images
- [ ] Inside the VStack (after sender name, before text), add image display:
  ```swift
  // Image (if present)
  if message.hasImage {
      MessageImageView(message: message)
          .onTapGesture {
              showFullImage = true
          }
  }
  ```

- [ ] Update text display to only show if not empty:
  ```swift
  // Text (if present)
  if !message.text.isEmpty {
      Text(message.text)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
  }
  ```

#### Add Sheet Modifier
- [ ] Add sheet modifier at end of main VStack:
  ```swift
  .sheet(isPresented: $showFullImage) {
      if let imageURL = message.imageURL {
          FullScreenImageView(imageURL: imageURL, message: message)
      }
  }
  ```

#### Test Build
- [ ] Build project (Cmd+B)
- [ ] Note: Will have error about MessageImageView - creating next

**Checkpoint:** MessageBubbleView structure updated ✓

---

#### Create MessageImageView Component
- [ ] Add new struct at bottom of MessageBubbleView.swift file:
  ```swift
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
  ```

#### Test Build
- [ ] Build project (Cmd+B)
- [ ] Note: Will have error about FullScreenImageView - creating next

**Checkpoint:** MessageImageView component complete ✓

**Commit:** `git add . && git commit -m "feat(views): Add image display to MessageBubbleView"`

---

### 5.2: Create FullScreenImageView (30 minutes)

#### Create File
- [ ] Create `messAI/Views/Chat/FullScreenImageView.swift`
- [ ] Add to Xcode project (Views/Chat group)

#### Add Imports
- [ ] Add imports:
  ```swift
  import SwiftUI
  ```

#### Implement FullScreenImageView
- [ ] Create view struct:
  ```swift
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
  
  // MARK: - Preview
  
  #Preview {
      FullScreenImageView(
          imageURL: "https://via.placeholder.com/1920x1080",
          message: Message(
              conversationId: "test",
              senderId: "user1",
              text: "",
              imageURL: "https://via.placeholder.com/1920x1080",
              thumbnailURL: "https://via.placeholder.com/200"
          )
      )
  }
  ```

#### Test Build
- [ ] Build project (Cmd+B)
- [ ] Fix any compilation errors
- [ ] Test preview if possible

**Checkpoint:** FullScreenImageView complete ✓

**Commit:** `git add . && git commit -m "feat(views): Add FullScreenImageView with pinch-to-zoom"`

---

## Phase 6: Input Updates (30 minutes)

### 6.1: Update MessageInputView (20 minutes)

#### Open MessageInputView
- [ ] Open `messAI/Views/Chat/MessageInputView.swift`

#### Update Signature
- [ ] Add image callback parameter:
  ```swift
  struct MessageInputView: View {
      @Binding var text: String
      let onSend: () -> Void
      let onImageSelect: (UIImage) -> Void  // NEW
      
      // ... rest of struct
  }
  ```

#### Add State Properties
- [ ] Add state properties after existing @State variables:
  ```swift
  @State private var showImagePicker = false
  @State private var showActionSheet = false
  @State private var selectedImage: UIImage?
  @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
  ```

#### Update Body with Image Button
- [ ] Add image button before text input in HStack:
  ```swift
  // Image button
  Button(action: {
      showActionSheet = true
  }) {
      Image(systemName: "photo.fill")
          .font(.title3)
          .foregroundColor(.blue)
  }
  ```

#### Add Action Sheet
- [ ] Add modifier after HStack closing:
  ```swift
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
  ```

#### Add Image Picker Sheet
- [ ] Add sheet modifier after confirmationDialog:
  ```swift
  .sheet(isPresented: $showImagePicker) {
      ImagePicker(image: $selectedImage, sourceType: imageSourceType)
  }
  ```

#### Add onChange Handler
- [ ] Add onChange modifier after sheets:
  ```swift
  .onChange(of: selectedImage) { _, newImage in
      if let image = newImage {
          onImageSelect(image)
          selectedImage = nil
      }
  }
  ```

#### Update Preview
- [ ] Update preview to include image callback:
  ```swift
  #Preview {
      MessageInputView(
          text: .constant(""),
          onSend: { print("Send tapped") },
          onImageSelect: { image in print("Image selected: \(image.size)") }
      )
  }
  ```

#### Test Build
- [ ] Build project (Cmd+B)
- [ ] Fix any compilation errors

**Checkpoint:** MessageInputView supports image selection ✓

**Commit:** `git add . && git commit -m "feat(views): Add image selection to MessageInputView"`

---

### 6.2: Update ChatView Integration (10 minutes)

#### Open ChatView
- [ ] Open `messAI/Views/Chat/ChatView.swift`

#### Find MessageInputView Usage
- [ ] Locate MessageInputView in body

#### Update MessageInputView Call
- [ ] Add onImageSelect parameter:
  ```swift
  MessageInputView(
      text: $messageText,
      onSend: {
          viewModel.sendMessage(messageText)
          messageText = ""
      },
      onImageSelect: { image in
          viewModel.sendImageMessage(image)
      }
  )
  ```

#### Test Build
- [ ] Build project (Cmd+B)
- [ ] Fix any compilation errors

**Checkpoint:** ChatView wired to send images ✓

**Commit:** `git add . && git commit -m "feat(views): Wire image selection to ChatView"`

---

## Phase 7: Testing & Polish (30 minutes)

### 7.1: Comprehensive Testing (20 minutes)

#### Build Test
- [ ] Clean build folder (Cmd+Shift+K)
- [ ] Build project (Cmd+B)
- [ ] Verify 0 errors, 0 warnings

#### Functional Tests (on Device/Simulator)
- [ ] Launch app
- [ ] Navigate to a conversation
- [ ] Test image button appears in input
- [ ] Test action sheet appears on tap
- [ ] Test photo library picker opens
- [ ] Test camera picker opens (device only)
- [ ] Select image from library
- [ ] Verify image sends
- [ ] Verify thumbnail appears in chat
- [ ] Tap thumbnail
- [ ] Verify full-screen view opens
- [ ] Test pinch-to-zoom (1x to 5x)
- [ ] Test Done button dismisses
- [ ] Send another image
- [ ] Verify multiple images display correctly

#### Cross-Device Test (if two devices available)
- [ ] Device A: Send image
- [ ] Device B: Verify receives image within 2-3 seconds
- [ ] Device B: Tap to view full-screen
- [ ] Verify works both directions

#### Edge Case Tests
- [ ] Try sending very large image (10MB+)
  - Expected: Compresses to <2MB
- [ ] Try sending while offline
  - Expected: Queues for upload when online
- [ ] Try tapping image with no imageURL
  - Expected: Handles gracefully (shouldn't happen)

**Checkpoint:** All tests passing ✓

---

### 7.2: Error Handling & Polish (10 minutes)

#### Test Error Scenarios
- [ ] Deny photo library permission
  - Expected: System alert with explanation
- [ ] Deny camera permission
  - Expected: System alert with explanation
- [ ] Force upload failure (airplane mode)
  - Expected: Error message in ChatView
- [ ] Verify retry works (if implemented)

#### Performance Check
- [ ] Profile with Instruments (Time Profiler)
- [ ] Check compression time (<2s for 4K image)
- [ ] Check memory usage (reasonable)
- [ ] Check for memory leaks

#### UI Polish
- [ ] Verify image bubbles look good
- [ ] Verify full-screen animation smooth
- [ ] Verify zoom gesture responsive
- [ ] Check dark mode appearance
- [ ] Check different device sizes

**Checkpoint:** All polished and working ✓

---

## Final Checks

### Code Quality
- [ ] No compiler warnings
- [ ] No force unwraps (!) except where safe
- [ ] Proper error handling throughout
- [ ] Clean, readable code
- [ ] Comments where needed

### Documentation
- [ ] Code comments added for complex logic
- [ ] StorageService methods documented
- [ ] ImageCompressor methods documented

### Git Cleanup
- [ ] All work committed
- [ ] No leftover test files
- [ ] Clean working directory

---

## Completion Checklist

- [ ] All phases complete (1-7)
- [ ] All tests passing
- [ ] Firebase Storage rules deployed
- [ ] Zero compiler errors
- [ ] Zero compiler warnings
- [ ] Image selection works (library + camera)
- [ ] Image compression works (<2MB)
- [ ] Image upload works with progress
- [ ] Images display in chat bubbles
- [ ] Full-screen view works with zoom
- [ ] Cross-device image sharing works
- [ ] Documentation complete
- [ ] Complete summary written
- [ ] PR_PARTY README updated
- [ ] Memory bank updated
- [ ] Ready to merge! 🎉

---

**Final Commit:**
```bash
git add .
git commit -m "feat(pr14): Complete image sharing implementation

- StorageService for Firebase Storage
- ImageCompressor for optimization
- ImagePicker for selection
- Message model image fields
- ChatViewModel upload logic
- MessageBubbleView image display
- FullScreenImageView with zoom
- MessageInputView image button
- Firebase Storage security rules

All tests passing, ready for production."
```

**Push to GitHub:**
```bash
git push origin feature/pr14-image-sharing
```

**Merge to Main:**
```bash
git checkout main
git merge feature/pr14-image-sharing
git push origin main
```

---

**Status:** ✅ PR #14 COMPLETE! Image sharing fully implemented! 🎉

**Next:** PR #15 - Offline Support & Network Monitoring (or continue with remaining MVP features)

