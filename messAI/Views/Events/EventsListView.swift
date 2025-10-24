import SwiftUI

/**
 * PR#20.2: Events List View
 * 
 * Full-screen sheet displaying all events for a conversation.
 * Split into "Upcoming" and "Past" sections with pull-to-refresh.
 */

struct EventsListView: View {
    let conversationId: String
    
    @StateObject private var viewModel: EventsListViewModel
    @Environment(\.dismiss) var dismiss
    
    init(conversationId: String) {
        self.conversationId = conversationId
        _viewModel = StateObject(wrappedValue: EventsListViewModel(conversationId: conversationId))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading events...")
                } else if viewModel.upcomingEvents.isEmpty && viewModel.pastEvents.isEmpty {
                    emptyState
                } else {
                    eventsList
                }
            }
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                // Offline indicator (if applicable)
                if viewModel.isOffline {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Label("Offline", systemImage: "wifi.slash")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .sheet(item: $viewModel.selectedEvent) { event in
                EventDetailView(event: event, conversationId: conversationId)
            }
        }
        .onAppear {
            print("📱 EventsListView: Appeared for conversation: \(conversationId)")
            viewModel.startListening()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView(
            "No Events Yet",
            systemImage: "calendar.badge.questionmark",
            description: Text("Events created in this chat will appear here")
        )
    }
    
    // MARK: - Events List
    
    private var eventsList: some View {
        List {
            // Upcoming events
            if !viewModel.upcomingEvents.isEmpty {
                Section {
                    ForEach(viewModel.upcomingEvents) { event in
                        EventRowView(event: event)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                print("👆 EventsListView: Tapped event: \(event.title)")
                                viewModel.selectedEvent = event
                            }
                    }
                } header: {
                    Text("Upcoming (\(viewModel.upcomingEvents.count))")
                        .font(.headline)
                }
            }
            
            // Past events
            if !viewModel.pastEvents.isEmpty {
                Section {
                    ForEach(viewModel.pastEvents) { event in
                        EventRowView(event: event)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                print("👆 EventsListView: Tapped event: \(event.title)")
                                viewModel.selectedEvent = event
                            }
                    }
                } header: {
                    Text("Past (\(viewModel.pastEvents.count))")
                        .font(.headline)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            print("🔄 EventsListView: Pull to refresh")
            await viewModel.refresh()
        }
        .overlay {
            // Error message (if any)
            if let errorMessage = viewModel.errorMessage {
                VStack {
                    Spacer()
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(uiColor: .systemBackground))
                                .shadow(radius: 4)
                        )
                        .padding()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EventsListView(conversationId: "conv_preview")
}

