import SwiftUI

/**
 * PR#19: Deadline Card View
 * 
 * Displays a deadline with countdown timer and status indicator.
 * Shows:
 * - Title and description
 * - Countdown timer ("Due in 2 days" → "Due in 3 hours" → "OVERDUE")
 * - Status badge (upcoming/due-soon/overdue)
 * - Priority indicator
 * - Tap to mark complete/view details
 * 
 * Design: Follows calendar card pattern for consistency
 */

struct DeadlineCardView: View {
    let deadline: Deadline
    let onTap: (() -> Void)?
    let onComplete: (() -> Void)?
    
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()  // Update every minute
    
    init(deadline: Deadline, onTap: (() -> Void)? = nil, onComplete: (() -> Void)? = nil) {
        self.deadline = deadline
        self.onTap = onTap
        self.onComplete = onComplete
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header Row (Status Badge + Countdown)
            headerRow
            
            Divider()
                .padding(.vertical, 8)
            
            // MARK: - Content (Title + Description + Due Date)
            contentSection
            
            // MARK: - Footer (Priority + Actions)
            if !deadline.isCompleted {
                Divider()
                    .padding(.vertical, 8)
                
                footerSection
            }
        }
        .padding(12)
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 2)
        )
        .onTapGesture {
            onTap?()
        }
        .onReceive(timer) { _ in
            currentTime = Date()  // Update current time for countdown
        }
    }
    
    // MARK: - Header Row
    
    private var headerRow: some View {
        HStack(spacing: 8) {
            // Status Badge
            statusBadge
            
            Spacer()
            
            // Countdown Timer
            countdownView
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: deadline.timeStatus.icon)
                .font(.system(size: 12, weight: .semibold))
            
            Text(deadline.timeStatus.displayName)
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
        }
        .foregroundColor(deadline.timeStatus.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(deadline.timeStatus.backgroundColor)
        .cornerRadius(6)
    }
    
    private var countdownView: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 12))
            
            Text(deadline.countdownText)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(deadline.isOverdue ? .red : .secondary)
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            HStack(spacing: 8) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 14))
                    .foregroundColor(deadline.priority.color)
                
                Text(deadline.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Completed checkmark
                if deadline.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.green)
                }
            }
            
            // Description (if available)
            if let description = deadline.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Due Date
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(deadline.relativeDueDate)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        HStack(spacing: 12) {
            // Priority Indicator
            HStack(spacing: 4) {
                Image(systemName: deadline.priority.icon)
                    .font(.system(size: 11))
                
                Text(deadline.priority.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(deadline.priority.color)
            
            // Category (if available)
            if let category = deadline.category {
                HStack(spacing: 4) {
                    Image(systemName: category.icon)
                        .font(.system(size: 11))
                    
                    Text(category.displayName)
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Mark Complete Button
            if deadline.isActive {
                Button(action: {
                    onComplete?()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 12))
                        
                        Text("Complete")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Styling
    
    private var backgroundColor: Color {
        if deadline.isCompleted {
            return Color(.systemGray6)
        } else if deadline.isOverdue {
            return Color.red.opacity(0.05)
        } else if deadline.timeStatus == .critical || deadline.timeStatus == .dueSoon {
            return Color.orange.opacity(0.05)
        } else {
            return Color(.systemBackground)
        }
    }
    
    private var borderColor: Color {
        if deadline.isCompleted {
            return Color.green.opacity(0.3)
        } else if deadline.isOverdue {
            return Color.red.opacity(0.3)
        } else if deadline.timeStatus == .critical {
            return Color.red.opacity(0.3)
        } else if deadline.timeStatus == .dueSoon {
            return Color.orange.opacity(0.3)
        } else {
            return Color.blue.opacity(0.3)
        }
    }
}

// MARK: - Minimal Deadline View (Compact)

struct DeadlineMinimalView: View {
    let deadline: Deadline
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: "flag.fill")
                .font(.system(size: 12))
                .foregroundColor(deadline.priority.color)
            
            // Title
            Text(deadline.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            // Countdown
            Text(deadline.countdownText)
                .font(.system(size: 12))
                .foregroundColor(deadline.isOverdue ? .red : .secondary)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Deadline Status Row (For Lists)

struct DeadlineStatusRow: View {
    let deadline: Deadline
    let onTap: (() -> Void)?
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 12) {
                // Priority Icon
                Image(systemName: deadline.priority.icon)
                    .font(.system(size: 16))
                    .foregroundColor(deadline.priority.color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(deadline.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    // Countdown + Category
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            
                            Text(deadline.countdownText)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(deadline.isOverdue ? .red : .secondary)
                        
                        if let category = deadline.category {
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text(category.displayName)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Status Badge
                if deadline.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(deadline.isOverdue ? Color.red.opacity(0.3) : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct DeadlineCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Upcoming deadline
            DeadlineCardView(
                deadline: Deadline.previewUpcoming,
                onTap: {
                    print("Tapped upcoming deadline")
                },
                onComplete: {
                    print("Completed upcoming deadline")
                }
            )
            
            // Due soon deadline
            DeadlineCardView(
                deadline: Deadline.previewDueSoon,
                onTap: {
                    print("Tapped due soon deadline")
                },
                onComplete: {
                    print("Completed due soon deadline")
                }
            )
            
            // Overdue deadline
            DeadlineCardView(
                deadline: Deadline.previewOverdue,
                onTap: {
                    print("Tapped overdue deadline")
                },
                onComplete: {
                    print("Completed overdue deadline")
                }
            )
            
            // Completed deadline
            DeadlineCardView(
                deadline: Deadline.previewCompleted,
                onTap: {
                    print("Tapped completed deadline")
                }
            )
            
            // Minimal view
            DeadlineMinimalView(deadline: Deadline.previewDueSoon)
            
            // Status row
            DeadlineStatusRow(deadline: Deadline.previewUpcoming, onTap: {
                print("Tapped status row")
            })
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

