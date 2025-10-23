import SwiftUI

/**
 * PR#18: RSVP Section View
 * 
 * Displays RSVP tracking information below calendar cards:
 * - Summary: "5 of 12 confirmed"
 * - Expandable participant list grouped by status (yes/no/maybe/pending)
 * - Collapsible design to minimize UI clutter
 * 
 * Design: Follows in-chat display pattern for zero navigation friction
 */

struct RSVPSectionView: View {
    let summary: RSVPSummary
    let participants: [RSVPParticipant]
    let organizerName: String?  // NEW: Optional organizer name
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: - Organizer Header (if available)
            if let organizer = organizerName {
                organizerHeader(name: organizer)
            }
            
            // MARK: - Summary Row (Always Visible)
            summaryRow
            
            // MARK: - Participant List (Expandable)
            if isExpanded {
                participantList
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
    }
    
    // MARK: - Summary Row
    
    private var summaryRow: some View {
        Button(action: {
            withAnimation {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 12) {
                // RSVP Icon
                Image(systemName: "person.3.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Summary Text
                    Text(summary.summaryText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Detailed Breakdown
                    Text(summary.detailedText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Expand/Collapse Icon
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Organizer Header
    
    private func organizerHeader(name: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "person.badge.shield.checkmark.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
            
            Text("Organized by \(name)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 4)
    }
    
    // MARK: - Participant List
    
    private var participantList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.vertical, 4)
            
            // Group participants by status
            let groupedParticipants = Dictionary(grouping: participants) { $0.status }
            
            // Organizer (Always First!)
            if let organizerParticipants = groupedParticipants[.organizer], !organizerParticipants.isEmpty {
                participantGroup(
                    title: "Organizer",
                    icon: "person.badge.shield.checkmark.fill",
                    color: .blue,
                    participants: organizerParticipants
                )
            }
            
            // Yes (Confirmed)
            if let yesParticipants = groupedParticipants[.yes], !yesParticipants.isEmpty {
                participantGroup(
                    title: "Going",
                    icon: "checkmark.circle.fill",
                    color: .green,
                    participants: yesParticipants
                )
            }
            
            // Maybe (Tentative)
            if let maybeParticipants = groupedParticipants[.maybe], !maybeParticipants.isEmpty {
                participantGroup(
                    title: "Maybe",
                    icon: "questionmark.circle.fill",
                    color: .orange,
                    participants: maybeParticipants
                )
            }
            
            // No (Declined)
            if let noParticipants = groupedParticipants[.no], !noParticipants.isEmpty {
                participantGroup(
                    title: "Not Going",
                    icon: "xmark.circle.fill",
                    color: .red,
                    participants: noParticipants
                )
            }
            
            // Pending (No Response)
            if let pendingParticipants = groupedParticipants[.pending], !pendingParticipants.isEmpty {
                participantGroup(
                    title: "Pending",
                    icon: "clock.fill",
                    color: .gray,
                    participants: pendingParticipants
                )
            }
        }
    }
    
    // MARK: - Participant Group
    
    private func participantGroup(
        title: String,
        icon: String,
        color: Color,
        participants: [RSVPParticipant]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Group Header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text("(\(participants.count))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Participants
            VStack(alignment: .leading, spacing: 4) {
                ForEach(participants.sorted(by: { $0.name < $1.name })) { participant in
                    participantRow(participant)
                }
            }
        }
    }
    
    // MARK: - Participant Row
    
    private func participantRow(_ participant: RSVPParticipant) -> some View {
        HStack(spacing: 8) {
            // User Icon
            Image(systemName: participant.isOrganizer ? "person.badge.shield.checkmark.fill" : "person.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(participant.status.iconColor)
            
            // Name
            Text(participant.name)
                .font(.system(size: 13))
                .foregroundColor(participant.status.textColor)
            
            // Organizer Badge
            if participant.isOrganizer {
                Text("(Organizer)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            // Response Time (if responded)
            if let respondedAt = participant.respondedAt {
                Text(respondedAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.leading, 20)
    }
}

// MARK: - Empty State View

struct RSVPEmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.secondary)
            
            Text("No RSVPs yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Responses will appear here")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Minimal Summary View (Collapsed Only)

struct RSVPMinimalView: View {
    let summary: RSVPSummary
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            
            Text(summary.summaryText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Status Icon
            if summary.allResponded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#if DEBUG
struct RSVPSectionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // With participants (including organizer)
            RSVPSectionView(
                summary: RSVPSummary(
                    eventId: "event123",
                    totalParticipants: 12,
                    organizerCount: 1,
                    yesCount: 4,
                    noCount: 3,
                    maybeCount: 2,
                    pendingCount: 2
                ),
                participants: [
                    // Organizer
                    RSVPParticipant(
                        id: "user0",
                        name: "Sarah Johnson",
                        status: .organizer,
                        respondedAt: Date().addingTimeInterval(-10800),
                        messageId: "msg0",
                        isOrganizer: true
                    ),
                    // Others
                    RSVPParticipant(
                        id: "user1",
                        name: "Mike Chen",
                        status: .yes,
                        respondedAt: Date().addingTimeInterval(-3600),
                        messageId: "msg1",
                        isOrganizer: false
                    ),
                    RSVPParticipant(
                        id: "user2",
                        name: "Emma Wilson",
                        status: .yes,
                        respondedAt: Date().addingTimeInterval(-7200),
                        messageId: "msg2",
                        isOrganizer: false
                    ),
                    RSVPParticipant(
                        id: "user3",
                        name: "Alex Taylor",
                        status: .maybe,
                        respondedAt: Date().addingTimeInterval(-1800),
                        messageId: "msg3",
                        isOrganizer: false
                    ),
                    RSVPParticipant(
                        id: "user4",
                        name: "Jordan Lee",
                        status: .maybe,
                        respondedAt: Date().addingTimeInterval(-900),
                        messageId: "msg4",
                        isOrganizer: false
                    ),
                    RSVPParticipant(
                        id: "user5",
                        name: "Chris Brown",
                        status: .no,
                        respondedAt: Date().addingTimeInterval(-5400),
                        messageId: "msg5",
                        isOrganizer: false
                    ),
                    RSVPParticipant(
                        id: "user6",
                        name: "Jamie Davis",
                        status: .no,
                        respondedAt: Date().addingTimeInterval(-4800),
                        messageId: "msg6",
                        isOrganizer: false
                    ),
                    RSVPParticipant(
                        id: "user7",
                        name: "Pat Kim",
                        status: .pending,
                        respondedAt: nil,
                        messageId: nil,
                        isOrganizer: false
                    ),
                    RSVPParticipant(
                        id: "user8",
                        name: "Sam Wilson",
                        status: .pending,
                        respondedAt: nil,
                        messageId: nil,
                        isOrganizer: false
                    )
                ],
                organizerName: "Sarah Johnson"
            )
            
            // Empty state
            RSVPEmptyStateView()
            
            // Minimal view
            RSVPMinimalView(
                summary: RSVPSummary(
                    eventId: "event123",
                    totalParticipants: 8,
                    organizerCount: 1,
                    yesCount: 5,
                    noCount: 1,
                    maybeCount: 1,
                    pendingCount: 0
                )
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

