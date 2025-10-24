import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/**
 * PR#20.2 Phase 4: Event Edit ViewModel
 * 
 * Manages event editing for creators.
 * Handles form validation, Firestore updates, and system messages.
 */

@MainActor
class EventEditViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var title: String
    @Published var date: String
    @Published var time: String
    @Published var location: String
    @Published var notes: String
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var showCancelConfirmation = false
    
    // MARK: - Private Properties
    
    private let event: EventDocument
    private let conversationId: String
    private let originalTitle: String
    private let originalDate: String
    private let originalTime: String
    private let originalLocation: String
    private let originalNotes: String
    private var lastSaveTime: Date?
    
    // MARK: - Computed Properties
    
    var isValid: Bool {
        return !title.trimmingCharacters(in: .whitespaces).isEmpty &&
               !date.trimmingCharacters(in: .whitespaces).isEmpty &&
               !time.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var hasChanges: Bool {
        return title != originalTitle ||
               date != originalDate ||
               time != originalTime ||
               location != originalLocation ||
               notes != originalNotes
    }
    
    // MARK: - Initialization
    
    init(event: EventDocument, conversationId: String) {
        self.event = event
        self.conversationId = conversationId
        
        // Initialize form fields with current event data
        self.title = event.title
        self.date = event.date
        self.time = event.time
        self.location = event.location ?? ""
        self.notes = event.notes ?? ""
        
        // Store original values for change detection
        self.originalTitle = event.title
        self.originalDate = event.date
        self.originalTime = event.time
        self.originalLocation = event.location ?? ""
        self.originalNotes = event.notes ?? ""
    }
    
    // MARK: - Public Methods
    
    /// Save changes to Firestore
    func saveChanges() async {
        print("💾 EventEditViewModel: Saving changes to event: \(event.id)")
        
        // Debounce (prevent rapid saves)
        if let lastSave = lastSaveTime, Date().timeIntervalSince(lastSave) < 2.0 {
            print("⚠️ Save debounced (too soon)")
            return
        }
        
        guard isValid else {
            errorMessage = "Title, date, and time are required"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        let db = Firestore.firestore()
        
        do {
            // Build update data
            var updateData: [String: Any] = [
                "title": title,
                "date": date,
                "time": time,
                "location": location,
                "notes": notes,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            // Update Firestore
            try await db.collection("events").document(event.id).updateData(updateData)
            
            lastSaveTime = Date()
            
            print("✅ Event updated successfully")
            
            // Send system message to chat
            await sendSystemMessage()
            
            isSaving = false
            
        } catch {
            print("❌ Failed to update event: \(error.localizedDescription)")
            errorMessage = "Failed to save: \(error.localizedDescription)"
            isSaving = false
        }
    }
    
    // MARK: - Private Methods
    
    /// Send system message to chat about event update
    private func sendSystemMessage() async {
        let db = Firestore.firestore()
        
        // Build change summary
        var changes: [String] = []
        
        if title != originalTitle {
            changes.append("title to '\(title)'")
        }
        if date != originalDate {
            changes.append("date to \(date)")
        }
        if time != originalTime {
            changes.append("time to \(time)")
        }
        if location != originalLocation && !location.isEmpty {
            changes.append("location to \(location)")
        }
        
        let changeText = changes.isEmpty ? "details" : changes.joined(separator: ", ")
        let messageText = "📝 Event updated: \(title) - Changed \(changeText)"
        
        do {
            // Create system message
            let messageData: [String: Any] = [
                "senderId": "system",
                "senderName": "System",
                "text": messageText,
                "sentAt": FieldValue.serverTimestamp(),
                "type": "system",
                "status": "sent"
            ]
            
            // Add to messages subcollection
            try await db.collection("conversations/\(conversationId)/messages")
                .addDocument(data: messageData)
            
            print("✅ System message sent: \(messageText)")
            
        } catch {
            print("❌ Failed to send system message: \(error.localizedDescription)")
            // Don't fail the save if system message fails
        }
    }
}

