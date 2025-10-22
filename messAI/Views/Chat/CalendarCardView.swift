import SwiftUI
import EventKit

/// SwiftUI view that displays an extracted calendar event as a card
struct CalendarCardView: View {
    let event: CalendarEvent
    let onAddToCalendar: (CalendarEvent) -> Void
    
    @State private var isAdding = false
    @State private var showSuccessCheckmark = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with calendar icon
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text("Calendar Event")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Confidence indicator
                confidenceIndicator
            }
            
            Divider()
            
            // Event details
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(event.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Date
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(event.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    if let timeRange = event.formattedTimeRange {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(timeRange)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    } else if event.isAllDay {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("All day")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Location (if available)
                if let location = event.location {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            // Add to Calendar button
            Button(action: {
                addToCalendar()
            }) {
                HStack {
                    if showSuccessCheckmark {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if isAdding {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                    
                    Text(showSuccessCheckmark ? "Added to Calendar" : "Add to Calendar")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(showSuccessCheckmark ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                .foregroundColor(showSuccessCheckmark ? .green : .blue)
                .cornerRadius(8)
            }
            .disabled(isAdding || showSuccessCheckmark)
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Confidence Indicator
    
    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            
            Text(event.confidence.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(confidenceColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var confidenceColor: Color {
        switch event.confidence {
        case .high:
            return .green
        case .medium:
            return .orange
        case .low:
            return .red
        }
    }
    
    // MARK: - Actions
    
    private func addToCalendar() {
        isAdding = true
        
        // Call the callback to handle calendar addition
        onAddToCalendar(event)
        
        // Show success state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAdding = false
            showSuccessCheckmark = true
            
            // Hide checkmark after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSuccessCheckmark = false
                }
            }
        }
    }
}

// MARK: - Preview

struct CalendarCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // High confidence event with time
            CalendarCardView(
                event: CalendarEvent(
                    id: "1",
                    title: "Soccer Practice",
                    date: Date(),
                    time: Date().addingTimeInterval(3600),
                    endTime: Date().addingTimeInterval(7200),
                    location: "Main Field",
                    isAllDay: false,
                    confidence: .high,
                    rawText: "Soccer practice Thursday at 4pm"
                ),
                onAddToCalendar: { _ in }
            )
            
            // Medium confidence all-day event
            CalendarCardView(
                event: CalendarEvent(
                    id: "2",
                    title: "School Picture Day",
                    date: Date().addingTimeInterval(86400),
                    time: nil,
                    endTime: nil,
                    location: nil,
                    isAllDay: true,
                    confidence: .medium,
                    rawText: "Picture day is tomorrow"
                ),
                onAddToCalendar: { _ in }
            )
            
            // Low confidence event
            CalendarCardView(
                event: CalendarEvent(
                    id: "3",
                    title: "Parent-Teacher Conference",
                    date: Date().addingTimeInterval(172800),
                    time: Date().addingTimeInterval(172800 + 3600 * 15),
                    endTime: nil,
                    location: "Room 203",
                    isAllDay: false,
                    confidence: .low,
                    rawText: "Conference sometime next week at the school"
                ),
                onAddToCalendar: { _ in }
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}

