//
//  AmbientSuggestionBar.swift
//  messAI
//
//  PR#20.1: Proactive AI Agent - Ambient Suggestion Bar
//  Beautiful slide-down bar for high-confidence AI suggestions
//

import SwiftUI

struct AmbientSuggestionBar: View {
    let opportunity: Opportunity
    let isProcessing: Bool
    let onApprove: () -> Void
    let onDismiss: () -> Void
    let onRSVPYes: (() -> Void)?
    let onRSVPNo: (() -> Void)?
    let onAddToCalendar: (() -> Void)?
    
    @State private var isExpanded: Bool = true
    
    // Check if user has already responded
    private var hasResponded: Bool {
        opportunity.data.userResponse != nil
    }
    
    private var userSaidYes: Bool {
        opportunity.data.userResponse == "yes"
    }
    
    // Convenience init for non-RSVP opportunities
    init(opportunity: Opportunity, isProcessing: Bool, onApprove: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.opportunity = opportunity
        self.isProcessing = isProcessing
        self.onApprove = onApprove
        self.onDismiss = onDismiss
        self.onRSVPYes = nil
        self.onRSVPNo = nil
        self.onAddToCalendar = nil
    }
    
    // Full init with RSVP handlers
    init(opportunity: Opportunity, isProcessing: Bool, onApprove: @escaping () -> Void, onDismiss: @escaping () -> Void, onRSVPYes: (() -> Void)?, onRSVPNo: (() -> Void)?, onAddToCalendar: (() -> Void)? = nil) {
        self.opportunity = opportunity
        self.isProcessing = isProcessing
        self.onApprove = onApprove
        self.onDismiss = onDismiss
        self.onRSVPYes = onRSVPYes
        self.onRSVPNo = onRSVPNo
        self.onAddToCalendar = onAddToCalendar
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: opportunity.type.icon)
                        .font(.title2)
                        .foregroundColor(opportunity.type == .rsvpManagement ? .green : .purple)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(opportunity.type == .rsvpManagement ? "Event Invitation" : "AI Suggestion")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(opportunity.displayTitle)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Confidence badge
                    Text("\(opportunity.confidencePercentage)%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(12)
                    
                    // Dismiss button
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                
                // Event details (if expanded and event-related)
                if isExpanded, (opportunity.type == .eventPlanning || opportunity.type == .rsvpManagement) {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if let date = opportunity.data.date, !date.isEmpty {
                            DetailRow(icon: "calendar", text: date)
                        }
                        
                        if let time = opportunity.data.time, !time.isEmpty {
                            DetailRow(icon: "clock", text: time)
                        }
                        
                        if let location = opportunity.data.location, !location.isEmpty {
                            DetailRow(icon: "mappin.and.ellipse", text: location)
                        }
                        
                        if let participants = opportunity.data.participants, !participants.isEmpty {
                            DetailRow(icon: "person.2", text: "\(participants.count) participants")
                        }
                    }
                    .font(.subheadline)
                }
                
                // RSVP List (if user has responded)
                if hasResponded, opportunity.type == .rsvpManagement, let rsvps = opportunity.data.rsvps {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RSVP Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(Array(rsvps.keys.sorted()), id: \.self) { userId in
                            if let response = rsvps[userId] {
                                HStack {
                                    Image(systemName: response == "yes" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(response == "yes" ? .green : .red)
                                    
                                    // Use display name if available, fallback to userId
                                    Text(opportunity.data.rsvpDisplayNames?[userId] ?? userId)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    Text(response.capitalized)
                                        .font(.caption)
                                        .foregroundColor(response == "yes" ? .green : .red)
                                }
                            }
                        }
                    }
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    if isProcessing {
                        // Processing state
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                    } else if opportunity.type == .rsvpManagement && !hasResponded {
                        // RSVP-specific buttons (Yes/No) - Only show if not responded yet
                        Button(action: {
                            onRSVPYes?()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Yes, I'll attend")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            onRSVPNo?()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("No, can't make it")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(10)
                        }
                    
                    } else if opportunity.type == .rsvpManagement && hasResponded && userSaidYes {
                        // User said Yes - Show "Add to Calendar" button
                        Button(action: {
                            onAddToCalendar?()
                        }) {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                Text("Add to Calendar")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        
                    } else if opportunity.type == .rsvpManagement && hasResponded {
                        // User said No - Show confirmation message
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.secondary)
                            Text("RSVP recorded. This will disappear in a moment...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        
                    } else {
                        // Standard action buttons (Create & Organize, etc.)
                        Button(action: onApprove) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text(primaryActionText)
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.purple.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(10)
                        }
                        
                        // Secondary action (optional)
                        if opportunity.suggestedActions.count > 1 {
                            Button(action: onDismiss) {
                                Text("Not Now")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.purple)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            )
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.3), value: isExpanded)
    }
    
    private var primaryActionText: String {
        switch opportunity.type {
        case .eventPlanning:
            return "Create & Organize"
        case .priorityDetection:
            return "Flag as Priority"
        case .deadlineTracking:
            return "Track Deadline"
        case .rsvpManagement:
            return "Enable RSVP"
        case .decisionSummary:
            return "Summarize Decision"
        }
    }
}

// MARK: - Supporting Views

struct DetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(text)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview

struct AmbientSuggestionBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            // High confidence event
            AmbientSuggestionBar(
                opportunity: Opportunity(
                    id: "1",
                    type: .eventPlanning,
                    confidence: 0.92,
                    data: OpportunityData(
                        title: "Emma's Birthday Party",
                        date: "Saturday, December 9",
                        time: "2:00 PM",
                        location: "Chuck E Cheese",
                        participants: ["Mom", "Dad", "Sarah"]
                    ),
                    suggestedActions: ["create_full_workflow", "dismiss"],
                    reasoning: "Detected event planning in conversation",
                    timestamp: Date()
                ),
                isProcessing: false,
                onApprove: {},
                onDismiss: {}
            )
            
            Spacer()
            
            // Processing state
            AmbientSuggestionBar(
                opportunity: Opportunity(
                    id: "2",
                    type: .eventPlanning,
                    confidence: 0.85,
                    data: OpportunityData(
                        title: "Soccer Practice",
                        date: "Tomorrow",
                        time: "4:00 PM"
                    ),
                    suggestedActions: ["create_event"],
                    reasoning: "Event detected",
                    timestamp: Date()
                ),
                isProcessing: true,
                onApprove: {},
                onDismiss: {}
            )
        }
        .background(Color.gray.opacity(0.1))
    }
}

