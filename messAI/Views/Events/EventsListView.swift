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
                    loadingState
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
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading events...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading events")
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView(
            "No Events Yet",
            systemImage: "calendar.badge.questionmark",
            description: Text("Events created in this chat will appear here")
        )
        .accessibilityLabel("No events")
        .accessibilityHint("Events created in this chat will appear here")
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
                        .accessibilityLabel("\(viewModel.upcomingEvents.count) upcoming events")
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
                        .accessibilityLabel("\(viewModel.pastEvents.count) past events")
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            print("🔄 EventsListView: Pull to refresh")
            await viewModel.refresh()
        }
        .overlay {
            // Error message with retry button
            if let errorMessage = viewModel.errorMessage {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        
                        Button(action: {
                            Task {
                                await viewModel.refresh()
                            }
                        }) {
                            Label("Try Again", systemImage: "arrow.clockwise")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .accessibilityLabel("Retry loading events")
                        .accessibilityHint("Attempts to load events again")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
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

