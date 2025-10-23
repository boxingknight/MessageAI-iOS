import SwiftUI
import Combine

/**
 * PR#19: Deadlines Section View
 * 
 * Displays a collapsible list of deadlines in a conversation:
 * - Summary: "3 active deadlines"
 * - Expandable list grouped by status (overdue/due-soon/upcoming)
 * - Countdown timers update automatically
 * - Collapsible design to minimize UI clutter
 * 
 * Design: Follows RSVP section pattern for consistency
 */

struct DeadlinesSectionView: View {
    let deadlines: [Deadline]
    let onDeadlineTap: ((Deadline) -> Void)?
    let onDeadlineComplete: ((Deadline) -> Void)?
    
    @State private var isExpanded: Bool = false
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()  // Update every minute
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: - Summary Row (Always Visible)
            summaryRow
            
            // MARK: - Deadlines List (Expandable)
            if isExpanded {
                deadlinesList
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
        .onReceive(timer) { _ in
            currentTime = Date()  // Update current time for countdown
        }
    }
    
    // MARK: - Summary Row
    
    private var summaryRow: some View {
        Button(action: {
            withAnimation {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 12) {
                // Deadline Icon
                Image(systemName: "flag.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(urgentDeadlineColor)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Summary Text
                    Text(summaryText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Breakdown
                    Text(breakdownText)
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
    
    // MARK: - Deadlines List
    
    private var deadlinesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.vertical, 4)
            
            // Group deadlines by time status
            let groupedDeadlines = Dictionary(grouping: activeDeadlines) { $0.timeStatus }
            
            // Overdue (if any)
            if let overdue = groupedDeadlines[.overdue], !overdue.isEmpty {
                deadlineGroup(
                    title: "Overdue",
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    deadlines: overdue.sorted { $0.dueDate < $1.dueDate }
                )
            }
            
            // Critical (due within 1 hour)
            if let critical = groupedDeadlines[.critical], !critical.isEmpty {
                deadlineGroup(
                    title: "Due Very Soon",
                    icon: "clock.badge.exclamationmark.fill",
                    color: .red,
                    deadlines: critical.sorted { $0.dueDate < $1.dueDate }
                )
            }
            
            // Due Soon (due within 24 hours)
            if let dueSoon = groupedDeadlines[.dueSoon], !dueSoon.isEmpty {
                deadlineGroup(
                    title: "Due Today",
                    icon: "clock.fill",
                    color: .orange,
                    deadlines: dueSoon.sorted { $0.dueDate < $1.dueDate }
                )
            }
            
            // Approaching (due within 3 days)
            if let approaching = groupedDeadlines[.approaching], !approaching.isEmpty {
                deadlineGroup(
                    title: "Due This Week",
                    icon: "calendar.badge.exclamationmark",
                    color: .orange,
                    deadlines: approaching.sorted { $0.dueDate < $1.dueDate }
                )
            }
            
            // Upcoming (more than 3 days)
            if let upcoming = groupedDeadlines[.upcoming], !upcoming.isEmpty {
                deadlineGroup(
                    title: "Upcoming",
                    icon: "calendar",
                    color: .blue,
                    deadlines: upcoming.sorted { $0.dueDate < $1.dueDate }
                )
            }
        }
    }
    
    // MARK: - Deadline Group
    
    private func deadlineGroup(
        title: String,
        icon: String,
        color: Color,
        deadlines: [Deadline]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Group Header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text("(\(deadlines.count))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Deadlines
            VStack(alignment: .leading, spacing: 8) {
                ForEach(deadlines) { deadline in
                    deadlineRow(deadline)
                }
            }
        }
    }
    
    // MARK: - Deadline Row
    
    private func deadlineRow(_ deadline: Deadline) -> some View {
        Button(action: {
            onDeadlineTap?(deadline)
        }) {
            HStack(spacing: 8) {
                // Priority Icon
                Image(systemName: deadline.priority.icon)
                    .font(.system(size: 13))
                    .foregroundColor(deadline.priority.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Title
                    Text(deadline.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    // Countdown + Due Date
                    HStack(spacing: 8) {
                        Text(deadline.countdownText)
                            .font(.system(size: 11))
                            .foregroundColor(deadline.isOverdue ? .red : .secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                        
                        Text(deadline.relativeDueDate)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Complete Button
                Button(action: {
                    onDeadlineComplete?(deadline)
                }) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(deadline.isOverdue ? Color.red.opacity(0.3) : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Computed Properties
    
    /// Active deadlines (not completed or cancelled)
    private var activeDeadlines: [Deadline] {
        return deadlines.filter { $0.isActive }
    }
    
    /// Count of active deadlines
    private var activeCount: Int {
        return activeDeadlines.count
    }
    
    /// Count of overdue deadlines
    private var overdueCount: Int {
        return activeDeadlines.filter { $0.isOverdue }.count
    }
    
    /// Summary text (e.g., "3 active deadlines")
    private var summaryText: String {
        if activeCount == 0 {
            return "No active deadlines"
        } else if activeCount == 1 {
            return "1 active deadline"
        } else {
            return "\(activeCount) active deadlines"
        }
    }
    
    /// Breakdown text (e.g., "2 overdue, 1 upcoming")
    private var breakdownText: String {
        if activeCount == 0 {
            return "You're all caught up!"
        }
        
        var parts: [String] = []
        
        if overdueCount > 0 {
            parts.append("\(overdueCount) overdue")
        }
        
        let upcomingCount = activeCount - overdueCount
        if upcomingCount > 0 {
            parts.append("\(upcomingCount) upcoming")
        }
        
        return parts.joined(separator: ", ")
    }
    
    /// Urgent deadline color (red if any overdue, orange if due soon, blue otherwise)
    private var urgentDeadlineColor: Color {
        if overdueCount > 0 {
            return .red
        } else if activeDeadlines.contains(where: { $0.timeStatus == .critical || $0.timeStatus == .dueSoon }) {
            return .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Empty State View

struct DeadlinesEmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "flag")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.secondary)
            
            Text("No deadlines")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Deadlines will appear here")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#if DEBUG
struct DeadlinesSectionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // With mixed deadlines
            DeadlinesSectionView(
                deadlines: [
                    Deadline.previewOverdue,
                    Deadline.previewDueSoon,
                    Deadline.previewUpcoming,
                    Deadline.previewCompleted
                ],
                onDeadlineTap: { deadline in
                    print("Tapped deadline: \(deadline.title)")
                },
                onDeadlineComplete: { deadline in
                    print("Completed deadline: \(deadline.title)")
                }
            )
            
            // Empty state
            DeadlinesEmptyStateView()
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

