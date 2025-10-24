import SwiftUI

/**
 * PR#20.2: Event Row View
 * 
 * Reusable row component for displaying an event in the list.
 * Shows icon, title, date/time, RSVP summary, and cancelled badge.
 */

struct EventRowView: View {
    let event: EventDocument
    
    var body: some View {
        HStack(spacing: 12) {
            // Event icon
            Text(event.icon)
                .font(.system(size: 32))
            
            VStack(alignment: .leading, spacing: 4) {
                // Event title
                Text(event.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Date & time
                HStack(spacing: 4) {
                    Text(event.formattedDate)
                    Text("at")
                        .foregroundColor(.secondary)
                    Text(event.formattedTime)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                // RSVP summary
                if !event.rsvpSummary.isEmpty {
                    Text(event.rsvpSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Cancelled badge (if applicable)
            if event.isCancelled {
                Text("Cancelled")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview("Upcoming Event") {
    List {
        EventRowView(event: sampleUpcomingEvent)
    }
}

#Preview("Cancelled Event") {
    List {
        EventRowView(event: sampleCancelledEvent)
    }
}

// MARK: - Sample Data

private var sampleUpcomingEvent: EventDocument {
    EventDocument(from: createMockSnapshot(
        id: "event1",
        data: [
            "title": "Soccer Practice",
            "conversationId": "conv1",
            "createdBy": "user1",
            "date": "Monday",
            "time": "4PM",
            "location": "Central Park",
            "participants": ["user1", "user2", "user3"],
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "status": "pending",
            "rsvps": ["user1": "yes", "user2": "yes"]
        ]
    ))!
}

private var sampleCancelledEvent: EventDocument {
    EventDocument(from: createMockSnapshot(
        id: "event2",
        data: [
            "title": "Birthday Party",
            "conversationId": "conv1",
            "createdBy": "user1",
            "date": "October 31",
            "time": "7PM",
            "location": "John's house",
            "participants": ["user1", "user2", "user3", "user4"],
            "createdAt": Timestamp(date: Date().addingTimeInterval(-86400)),
            "updatedAt": Timestamp(date: Date().addingTimeInterval(-3600)),
            "status": "cancelled",
            "rsvps": ["user1": "yes", "user2": "no", "user3": "yes"]
        ]
    ))!
}

// MARK: - Mock Helpers

import FirebaseFirestore

private func createMockSnapshot(id: String, data: [String: Any]) -> DocumentSnapshot {
    // Create a mock DocumentSnapshot for preview
    // In production, this would come from Firestore
    let mockRef = Firestore.firestore().collection("events").document(id)
    
    // This is a workaround for previews - in production, EventDocument is initialized from real Firestore snapshots
    // For now, we'll create a custom initializer in EventDocument for previews
    fatalError("Mock snapshot not implemented - use real Firestore data or create preview helper")
}

