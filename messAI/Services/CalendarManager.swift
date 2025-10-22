import Foundation
import EventKit
import Combine

/// Manager for handling iOS Calendar integration
@MainActor
class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    @Published var hasCalendarAccess = false
    
    private init() {
        checkCalendarAccess()
    }
    
    // MARK: - Permissions
    
    /// Check current calendar access status
    func checkCalendarAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        hasCalendarAccess = (status == .fullAccess || status == .authorized)
    }
    
    /// Request calendar access from user
    func requestCalendarAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    hasCalendarAccess = granted
                }
                return granted
            } else {
                return await withCheckedContinuation { continuation in
                    eventStore.requestAccess(to: .event) { [weak self] granted, error in
                        Task { @MainActor in
                            self?.hasCalendarAccess = granted
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
        } catch {
            print("❌ CalendarManager: Error requesting calendar access: \(error)")
            return false
        }
    }
    
    // MARK: - Adding Events
    
    /// Add a calendar event to the user's default calendar
    func addEvent(_ calendarEvent: CalendarEvent) async throws -> String {
        // Ensure we have calendar access
        if !hasCalendarAccess {
            let granted = await requestCalendarAccess()
            if !granted {
                throw CalendarError.accessDenied
            }
        }
        
        // Convert CalendarEvent to EKEvent
        let event = calendarEvent.toEKEvent(eventStore: eventStore)
        
        // Use default calendar
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Save event
        do {
            try eventStore.save(event, span: .thisEvent)
            print("✅ CalendarManager: Event saved successfully: \(event.title ?? "Untitled")")
            return event.eventIdentifier
        } catch {
            print("❌ CalendarManager: Error saving event: \(error)")
            throw CalendarError.saveFailed(error.localizedDescription)
        }
    }
    
    /// Check if an event with similar details already exists (within 24 hours)
    func eventExists(title: String, date: Date) -> Bool {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? date
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        
        let events = eventStore.events(matching: predicate)
        
        // Check for matching title
        return events.contains { event in
            event.title?.lowercased() == title.lowercased()
        }
    }
}

// MARK: - Calendar Errors

enum CalendarError: LocalizedError {
    case accessDenied
    case saveFailed(String)
    case eventNotFound
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access denied. Please enable calendar access in Settings."
        case .saveFailed(let message):
            return "Failed to save event: \(message)"
        case .eventNotFound:
            return "Event not found in calendar."
        }
    }
}

