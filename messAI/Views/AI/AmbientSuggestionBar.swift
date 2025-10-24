//
//  AmbientSuggestionBar.swift
//  messAI
//
//  PR#20.1: Proactive AI Agent - Ambient Suggestion Bar
//  Apple-quality minimal persistent bar with collapsed/expanded states
//

import SwiftUI

struct AmbientSuggestionBar: View {
    let opportunity: Opportunity
    let isCollapsed: Bool
    let isProcessing: Bool
    let onToggle: () -> Void
    let onApprove: () -> Void
    let onDismiss: () -> Void
    let onRSVPYes: (() -> Void)?
    let onRSVPNo: (() -> Void)?
    let onAddToCalendar: (() -> Void)?
    let onChangeResponse: (() -> Void)?
    
    // Check if user has already responded
    private var hasResponded: Bool {
        opportunity.data.userResponse != nil
    }
    
    private var userSaidYes: Bool {
        opportunity.data.userResponse == "yes"
    }
    
    private var userSaidNo: Bool {
        opportunity.data.userResponse == "no"
    }
    
    // Convenience init for non-RSVP opportunities
    init(opportunity: Opportunity, isCollapsed: Bool, isProcessing: Bool, onToggle: @escaping () -> Void, onApprove: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.opportunity = opportunity
        self.isCollapsed = isCollapsed
        self.isProcessing = isProcessing
        self.onToggle = onToggle
        self.onApprove = onApprove
        self.onDismiss = onDismiss
        self.onRSVPYes = nil
        self.onRSVPNo = nil
        self.onAddToCalendar = nil
        self.onChangeResponse = nil
    }
    
    // Full init with RSVP handlers
    init(opportunity: Opportunity, isCollapsed: Bool, isProcessing: Bool, onToggle: @escaping () -> Void, onApprove: @escaping () -> Void, onDismiss: @escaping () -> Void, onRSVPYes: (() -> Void)?, onRSVPNo: (() -> Void)?, onAddToCalendar: (() -> Void)? = nil, onChangeResponse: (() -> Void)? = nil) {
        self.opportunity = opportunity
        self.isCollapsed = isCollapsed
        self.isProcessing = isProcessing
        self.onToggle = onToggle
        self.onApprove = onApprove
        self.onDismiss = onDismiss
        self.onRSVPYes = onRSVPYes
        self.onRSVPNo = onRSVPNo
        self.onAddToCalendar = onAddToCalendar
        self.onChangeResponse = onChangeResponse
    }
    
    var body: some View {
        if isCollapsed {
            collapsedView
        } else {
            expandedView
        }
    }
    
    // MARK: - Collapsed View (Minimal 1-line)
    
    private var collapsedView: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Status icon
                Image(systemName: statusIcon)
                    .font(.body)
                    .foregroundColor(statusColor)
                
                // Event title + status
                VStack(alignment: .leading, spacing: 2) {
                    Text(opportunity.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Expand chevron
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            )
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Expanded View (Full Details)
    
    private var expandedView: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                // Header (Tappable to collapse)
                Button(action: onToggle) {
                    HStack {
                        Image(systemName: opportunity.type.icon)
                            .font(.title3)
                            .foregroundColor(opportunity.type == .rsvpManagement ? .green : .purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(opportunity.displayTitle)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        // Collapse chevron
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                // Event details
                if opportunity.type == .eventPlanning || opportunity.type == .rsvpManagement {
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
                if hasResponded, opportunity.type == .rsvpManagement, let rsvps = opportunity.data.rsvps, !rsvps.isEmpty {
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
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                    } else if opportunity.type == .rsvpManagement && !hasResponded {
                        // RSVP buttons (Yes/No)
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
                        // User said Yes - Show "Add to Calendar" + "Change Response"
                        VStack(spacing: 8) {
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
                            
                            Button(action: {
                                onChangeResponse?()
                            }) {
                                Text("Change Response")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                    } else if opportunity.type == .rsvpManagement && hasResponded && userSaidNo {
                        // User said No - Show "Change Response"
                        Button(action: {
                            onChangeResponse?()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Change Response")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                    } else {
                        // Standard action buttons
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
                
                // Dismiss button (top right)
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
    }
    
    // MARK: - Computed Properties for Collapsed State
    
    private var statusIcon: String {
        if hasResponded {
            return userSaidYes ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
        return opportunity.type.icon
    }
    
    private var statusColor: Color {
        if hasResponded {
            return userSaidYes ? .green : .gray
        }
        return opportunity.type == .rsvpManagement ? .green : .purple
    }
    
    private var statusText: String {
        if hasResponded {
            return userSaidYes ? "You're attending · Tap for details" : "You declined · Tap for details"
        }
        return "Tap to respond"
    }
    
    private var backgroundColor: Color {
        if hasResponded {
            if userSaidYes {
                return Color.green.opacity(0.08)
            } else {
                return Color.gray.opacity(0.06)
            }
        }
        return Color.purple.opacity(0.08)
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
        VStack(spacing: 20) {
            // Expanded event
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
                isCollapsed: false,
                isProcessing: false,
                onToggle: {},
                onApprove: {},
                onDismiss: {}
            )
            
            // Collapsed event (after RSVP Yes)
            AmbientSuggestionBar(
                opportunity: Opportunity(
                    id: "2",
                    type: .rsvpManagement,
                    confidence: 1.0,
                    data: OpportunityData(
                        title: "Poker Night",
                        date: "October 31",
                        time: "10PM",
                        userResponse: "yes"
                    ),
                    suggestedActions: ["rsvp"],
                    reasoning: "User RSVP'd yes",
                    timestamp: Date()
                ),
                isCollapsed: true,
                isProcessing: false,
                onToggle: {},
                onApprove: {},
                onDismiss: {}
            )
            
            Spacer()
        }
        .background(Color.gray.opacity(0.1))
    }
}

