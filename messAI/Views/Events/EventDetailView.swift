import SwiftUI

/**
 * PR#20.2: Event Detail View
 * 
 * Displays full event details including date, time, location, RSVPs,
 * and provides action buttons (Add to Calendar, Edit, Cancel, Change RSVP).
 * 
 * This is a placeholder for Phase 1. Will be fully implemented in later phases.
 */

struct EventDetailView: View {
    let event: EventDocument
    let conversationId: String
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Event info section
                    eventInfoSection
                    
                    Divider()
                    
                    // RSVP section (placeholder)
                    rsvpSection
                    
                    Divider()
                    
                    // Actions section (placeholder)
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
    
    // MARK: - Event Info Section
    
    private var eventInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon + Title
            HStack {
                Text(event.icon)
                    .font(.system(size: 48))
                
                Text(event.title)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // Date
            Label(event.formattedDate, systemImage: "calendar")
                .font(.body)
            
            // Time
            Label(event.formattedTime, systemImage: "clock")
                .font(.body)
            
            // Location (if available)
            if let location = event.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.body)
            }
            
            // Creator (placeholder)
            Label("Created by User", systemImage: "person.circle")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - RSVP Section (Placeholder)
    
    private var rsvpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RSVP Status")
                .font(.headline)
            
            // Placeholder text
            Text("RSVP list will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Show summary for now
            Text(event.rsvpSummary)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Actions Section (Placeholder)
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Placeholder button
            Button(action: {
                print("👆 EventDetailView: Add to Calendar tapped (not implemented yet)")
            }) {
                Label("Add to Calendar", systemImage: "calendar.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
            }
            
            Text("More actions coming in Phase 2-5")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    EventDetailView(
        event: sampleEvent,
        conversationId: "conv_preview"
    )
}

// MARK: - Sample Data

private var sampleEvent: EventDocument {
    // Create a sample event for preview
    // This would normally come from Firestore
    // For now, we'll use a workaround
    
    // TODO: Add a convenience initializer to EventDocument for previews
    fatalError("Preview not implemented yet - need to add preview initializer to EventDocument")
}

