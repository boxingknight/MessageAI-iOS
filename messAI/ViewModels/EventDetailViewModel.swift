import Foundation
import FirebaseFirestore
import FirebaseAuth
import EventKit
import Combine

/**
 * PR#20.2: Event Detail ViewModel
 * 
 * Manages event detail display and actions (add to calendar, edit, cancel, change RSVP).
 * Phase 2: Calendar integration (EventKit)
 * Phase 3-5: Edit, cancel, RSVP management
 */

@MainActor
class EventDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var event: EventDocument
    @Published var displayNames: [String: String] = [:]  // userId -> displayName
    @Published var isCreator = false
    @Published var currentUserRSVP: String?
    @Published var errorMessage: String?
    @Published var showEditModal = false
    @Published var showCancelConfirmation = false
    @Published var showChangeRSVP = false
    @Published var isAddedToCalendar = false
    @Published var isProcessing = false
    
    // MARK: - Private Properties
    
    private let conversationId: String
    var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? ""
    }
    private var listener: ListenerRegistration?
    private let eventStore = EKEventStore()
    
    // MARK: - Initialization
    
    init(event: EventDocument, conversationId: String) {
        self.event = event
        self.conversationId = conversationId
        self.isCreator = (event.createdBy == Auth.auth().currentUser?.uid)
        self.currentUserRSVP = event.rsvps?[Auth.auth().currentUser?.uid ?? ""]
    }
    
    deinit {
        listener?.remove()
        print("🗑️ EventDetailViewModel: Deinitialized, listener removed")
    }
    
    // MARK: - Public Methods
    
    /// Start listening to event updates
    func startListening() {
        print("👂 EventDetailViewModel: Starting listener for event: \(event.id)")
        
        let db = Firestore.firestore()
        
        listener = db.collection("events").document(event.id)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ EventDetailViewModel: Listener error: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.errorMessage = "Failed to load event updates: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let snapshot = snapshot,
                      let updatedEvent = EventDocument(from: snapshot) else {
                    print("⚠️ EventDetailViewModel: Failed to parse event snapshot")
                    return
                }
                
                print("📥 EventDetailViewModel: Event updated: \(updatedEvent.title)")
                
                Task { @MainActor in
                    self.event = updatedEvent
                    self.currentUserRSVP = updatedEvent.rsvps?[self.currentUserId]
                    
                    // Fetch display names for any new participants
                    await self.fetchDisplayNames()
                }
            }
    }
    
    /// Fetch display names for all participants
    func fetchDisplayNames() async {
        print("📥 EventDetailViewModel: Fetching display names for \(event.participants.count) participants")
        
        let db = Firestore.firestore()
        
        for userId in event.participants {
            // Skip if we already have this name
            if displayNames[userId] != nil {
                continue
            }
            
            do {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let displayName = userDoc.data()?["displayName"] as? String {
                    displayNames[userId] = displayName
                    print("   ✅ Fetched name for \(userId): \(displayName)")
                } else {
                    displayNames[userId] = "User"
                }
            } catch {
                print("   ❌ Failed to fetch name for \(userId): \(error.localizedDescription)")
                displayNames[userId] = "User"
            }
        }
    }
    
    // MARK: - Phase 2: Calendar Integration
    
    /// Add event to iOS Calendar
    func addToCalendar() async {
        print("📅 EventDetailViewModel: Adding event to calendar: \(event.title)")
        
        isProcessing = true
        
        do {
            // Request calendar permissions
            let granted = try await eventStore.requestFullAccessToEvents()
            
            guard granted else {
                errorMessage = "Calendar access denied. Please enable in Settings > messAI > Calendars."
                isProcessing = false
                print("❌ Calendar access denied")
                return
            }
            
            print("✅ Calendar access granted")
            
            // Create EKEvent
            let ekEvent = EKEvent(eventStore: eventStore)
            ekEvent.title = event.title
            ekEvent.startDate = event.eventDate
            
            // Set end date (1 hour after start, or same day for all-day events)
            if event.time.lowercased() == "all day" {
                ekEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.eventDate) ?? event.eventDate
                ekEvent.isAllDay = true
            } else {
                ekEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.eventDate) ?? event.eventDate
                ekEvent.isAllDay = false
            }
            
            // Add location and notes
            if let location = event.location, !location.isEmpty {
                ekEvent.location = location
            }
            
            if let notes = event.notes, !notes.isEmpty {
                ekEvent.notes = notes
            } else {
                ekEvent.notes = "Event from messAI"
            }
            
            // Set calendar (default)
            ekEvent.calendar = eventStore.defaultCalendarForNewEvents
            
            // Save to calendar
            try eventStore.save(ekEvent, span: .thisEvent)
            
            print("✅ Event added to calendar: \(event.title)")
            
            isAddedToCalendar = true
            isProcessing = false
            
        } catch {
            print("❌ Failed to add event to calendar: \(error.localizedDescription)")
            errorMessage = "Failed to add to calendar: \(error.localizedDescription)"
            isProcessing = false
        }
    }
    
    // MARK: - Phase 3-5: Placeholder Methods (to be implemented)
    
    /// Change user's RSVP response
    func changeRSVP(to response: String) async {
        print("🎫 EventDetailViewModel: Changing RSVP to: \(response)")
        // TODO: Implement in Phase 3
    }
    
    /// Cancel event (creator only)
    func cancelEvent() async {
        print("🗑️ EventDetailViewModel: Cancelling event")
        // TODO: Implement in Phase 5
    }
}

