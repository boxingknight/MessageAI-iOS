import SwiftUI

/**
 * PR#20.2: Event Detail View
 * 
 * Displays full event details including date, time, location, RSVPs,
 * and provides action buttons (Add to Calendar, Edit, Cancel, Change RSVP).
 * 
 * Phase 2: Calendar integration (Add to Calendar button)
 * Phase 3-5: Edit, Cancel, Change RSVP
 */

struct EventDetailView: View {
    let conversationId: String
    
    @StateObject private var viewModel: EventDetailViewModel
    @Environment(\.dismiss) var dismiss
    
    init(event: EventDocument, conversationId: String) {
        self.conversationId = conversationId
        _viewModel = StateObject(wrappedValue: EventDetailViewModel(event: event, conversationId: conversationId))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Event info section
                    eventInfoSection
                    
                    Divider()
                    
                    // RSVP section
                    rsvpSection
                    
                    Divider()
                    
                    // Actions section
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
        .confirmationDialog("Change Your Response", isPresented: $viewModel.showChangeRSVP) {
            Button("✅ Yes, I'll attend") {
                Task {
                    await viewModel.changeRSVP(to: "yes")
                }
            }
            
            Button("❌ No, can't make it") {
                Task {
                    await viewModel.changeRSVP(to: "no")
                }
            }
            
            Button("⏳ Maybe") {
                Task {
                    await viewModel.changeRSVP(to: "maybe")
                }
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Update your RSVP for \(viewModel.event.title)")
        }
        .onAppear {
            print("📱 EventDetailView: Appeared for event: \(viewModel.event.title)")
            viewModel.startListening()
            Task {
                await viewModel.fetchDisplayNames()
            }
        }
    }
    
    // MARK: - Event Info Section
    
    private var eventInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon + Title
            HStack {
                Text(viewModel.event.icon)
                    .font(.system(size: 48))
                
                Text(viewModel.event.title)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // Date
            Label(viewModel.event.formattedDate, systemImage: "calendar")
                .font(.body)
            
            // Time
            Label(viewModel.event.formattedTime, systemImage: "clock")
                .font(.body)
            
            // Location (if available)
            if let location = viewModel.event.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.body)
            }
            
            // Creator
            Label(viewModel.event.creatorText(currentUserId: viewModel.currentUserId), systemImage: "person.circle")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Cancelled badge (if applicable)
            if viewModel.event.isCancelled {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("This event has been cancelled")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - RSVP Section
    
    private var rsvpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RSVP Status (\(viewModel.event.rsvps?.count ?? 0) responded)")
                .font(.headline)
            
            if let rsvps = viewModel.event.rsvps, !rsvps.isEmpty {
                // Display each RSVP with display name
                ForEach(Array(rsvps.keys.sorted()), id: \.self) { userId in
                    if let response = rsvps[userId] {
                        HStack {
                            Image(systemName: rsvpIcon(for: response))
                                .foregroundColor(rsvpColor(for: response))
                            
                            Text(viewModel.displayNames[userId] ?? "Loading...")
                                .font(.body)
                            
                            Spacer()
                            
                            Text(response.capitalized)
                                .font(.caption)
                                .foregroundColor(rsvpColor(for: response))
                        }
                    }
                }
                
                // Current user's response (highlighted)
                if let userResponse = viewModel.currentUserRSVP {
                    HStack {
                        Text("Your Response:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(userResponse.capitalized)
                            .font(.subheadline)
                            .foregroundColor(rsvpColor(for: userResponse))
                        
                        Image(systemName: rsvpIcon(for: userResponse))
                            .foregroundColor(rsvpColor(for: userResponse))
                    }
                    .padding(12)
                    .background(rsvpColor(for: userResponse).opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                // No RSVPs yet
                Text("No responses yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Show summary from event
                Text(viewModel.event.rsvpSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Phase 2: Add to Calendar button
            if !viewModel.event.isCancelled {
                Button(action: {
                    Task {
                        await viewModel.addToCalendar()
                    }
                }) {
                    HStack {
                        if viewModel.isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: viewModel.isAddedToCalendar ? "checkmark.circle.fill" : "calendar.badge.plus")
                        }
                        Text(viewModel.isAddedToCalendar ? "Added to Calendar" : "Add to Calendar")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isAddedToCalendar ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isAddedToCalendar || viewModel.isProcessing)
            }
            
            // Phase 3-5: Additional buttons (placeholders)
            if viewModel.isCreator && !viewModel.event.isCancelled {
                // Edit button (creator only) - Phase 4
                Button(action: {
                    print("👆 EventDetailView: Edit Event tapped (Phase 4)")
                }) {
                    Label("Edit Event", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(10)
                }
                .disabled(true)
                
                // Cancel button (creator only) - Phase 5
                Button(action: {
                    print("👆 EventDetailView: Cancel Event tapped (Phase 5)")
                }) {
                    Label("Cancel Event", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                }
                .disabled(true)
            } else if !viewModel.isCreator && !viewModel.event.isCancelled {
                // Change RSVP button (participants) - Phase 3
                Button(action: {
                    print("👆 EventDetailView: Change Response tapped")
                    viewModel.showChangeRSVP = true
                }) {
                    Label("Change Response", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(10)
                }
                .disabled(viewModel.isProcessing)
            }
            
            // Error message (if any)
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Phase status indicator
            Text("Phases 2-3 Complete ✅ | Phases 4-5: Coming soon")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Helper Methods
    
    private func rsvpIcon(for response: String) -> String {
        switch response {
        case "yes": return "checkmark.circle.fill"
        case "no": return "xmark.circle.fill"
        case "maybe": return "questionmark.circle.fill"
        default: return "clock.fill"
        }
    }
    
    private func rsvpColor(for response: String) -> Color {
        switch response {
        case "yes": return .green
        case "no": return .red
        case "maybe": return .yellow
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    // Note: Preview requires a valid EventDocument
    // For now, this will show a placeholder
    Text("Event Detail View Preview")
        .font(.title)
}
