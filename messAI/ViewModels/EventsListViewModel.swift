import Foundation
import FirebaseFirestore
import Combine

/**
 * PR#20.2: Events List ViewModel
 * 
 * Manages the events list for a conversation.
 * Fetches events from Firestore, splits into upcoming/past, handles real-time updates.
 */

@MainActor
class EventsListViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var upcomingEvents: [EventDocument] = []
    @Published var pastEvents: [EventDocument] = []
    @Published var selectedEvent: EventDocument?
    @Published var isLoading = false
    @Published var isOffline = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let conversationId: String
    private var listener: ListenerRegistration?
    private var cachedEvents: [EventDocument] = []
    
    // MARK: - Initialization
    
    init(conversationId: String) {
        self.conversationId = conversationId
    }
    
    deinit {
        listener?.remove()
        print("🗑️ EventsListViewModel: Deinitialized, listener removed")
    }
    
    // MARK: - Public Methods
    
    /// Start listening to events for this conversation
    func startListening() {
        print("👂 EventsListViewModel: Starting listener for conversation: \(conversationId)")
        
        let db = Firestore.firestore()
        
        listener = db.collection("events")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "createdAt", descending: false)  // Oldest first
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ EventsListViewModel: Listener error: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.errorMessage = "Failed to load events: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ EventsListViewModel: No documents in snapshot")
                    return
                }
                
                print("📥 EventsListViewModel: Received \(documents.count) events")
                
                // Parse events
                let events = documents.compactMap { EventDocument(from: $0) }
                
                Task { @MainActor in
                    // Cache for offline use
                    self.cachedEvents = events
                    
                    // Process and split into upcoming/past
                    self.processEvents(events)
                    
                    print("✅ EventsListViewModel: Processed \(self.upcomingEvents.count) upcoming, \(self.pastEvents.count) past events")
                }
            }
    }
    
    /// Load events once (no listener)
    func loadEvents() async {
        print("📥 EventsListViewModel: Loading events for conversation: \(conversationId)")
        
        isLoading = true
        errorMessage = nil
        
        // Check network status
        // TODO: Integrate NetworkMonitor if available
        // For now, assume online
        
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("events")
                .whereField("conversationId", isEqualTo: conversationId)
                .order(by: "createdAt", descending: false)
                .getDocuments()
            
            let events = snapshot.documents.compactMap { EventDocument(from: $0) }
            
            print("✅ EventsListViewModel: Loaded \(events.count) events")
            
            // Cache for offline use
            cachedEvents = events
            
            // Process and split
            processEvents(events)
            
            isLoading = false
            
        } catch {
            print("❌ EventsListViewModel: Failed to load events: \(error.localizedDescription)")
            
            // Try loading from cache
            if !cachedEvents.isEmpty {
                print("📦 EventsListViewModel: Loading from cache (\(cachedEvents.count) events)")
                processEvents(cachedEvents)
                isOffline = true
            } else {
                errorMessage = "Failed to load events: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    /// Refresh events (pull-to-refresh)
    func refresh() async {
        print("🔄 EventsListViewModel: Refreshing events")
        await loadEvents()
    }
    
    // MARK: - Private Methods
    
    /// Process events and split into upcoming and past
    private func processEvents(_ events: [EventDocument]) {
        let now = Date()
        
        // Split into upcoming and past
        upcomingEvents = events.filter { event in
            return !event.isCancelled && event.eventDate >= now
        }.sorted { $0.eventDate < $1.eventDate }  // Ascending (soonest first)
        
        pastEvents = events.filter { event in
            return event.isCancelled || event.eventDate < now
        }.sorted { $0.eventDate > $1.eventDate }  // Descending (most recent first)
        
        print("📊 EventsListViewModel: Split complete")
        print("   Upcoming: \(upcomingEvents.count) events")
        print("   Past: \(pastEvents.count) events")
    }
}

