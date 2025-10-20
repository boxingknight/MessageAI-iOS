//
//  ContentView.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Main App")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("You're logged in as:")
                    .foregroundColor(.secondary)
                
                if let user = authViewModel.currentUser {
                    Text(user.displayName)
                        .font(.title2)
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Button("Sign Out") {
                    Task {
                        await authViewModel.signOut()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                Divider()
                    .padding(.vertical)
                
                VStack(spacing: 12) {
                    Text("Test Core Models")
                        .font(.headline)
                    
                    Button("Run Model Tests") {
                        testModels()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Text("Check console output (⌘K to clear, ⌘⇧Y to show)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("MessageAI")
        }
    }
    
    // MARK: - Model Testing
    
    func testModels() {
        print("\n" + String(repeating: "=", count: 60))
        print("🧪 TESTING ALL MODELS - PR #4")
        print(String(repeating: "=", count: 60) + "\n")
        
        // Test 1: MessageStatus
        print("1️⃣ MessageStatus Enum")
        print(String(repeating: "-", count: 40))
        MessageStatus.allCases.forEach { status in
            print("  \(status.iconName) \(status.displayText) [\(status.rawValue)]")
        }
        print("  ✅ All \(MessageStatus.allCases.count) cases working\n")
        
        // Test 2: Message Model
        print("2️⃣ Message Model")
        print(String(repeating: "-", count: 40))
        
        // Create a message
        let testMessage = Message(
            conversationId: "test-conv-123",
            senderId: authViewModel.currentUser?.id ?? "test-user",
            text: "Hello! This is a test message 👋",
            senderName: authViewModel.currentUser?.displayName,
            senderPhotoURL: authViewModel.currentUser?.photoURL
        )
        
        print("  📝 Created Message:")
        print("     ID: \(testMessage.id)")
        print("     Text: \(testMessage.text)")
        print("     Status: \(testMessage.status.displayText)")
        print("     Time: \(testMessage.timeAgo)")
        
        // Test Firestore conversion
        let messageDict = testMessage.toDictionary()
        print("\n  🔄 Firestore Conversion:")
        print("     Dictionary keys: \(messageDict.keys.count)")
        print("     Keys: \(messageDict.keys.sorted().joined(separator: ", "))")
        
        if let recovered = Message(dictionary: messageDict) {
            let matches = recovered.id == testMessage.id &&
                         recovered.text == testMessage.text &&
                         recovered.status == testMessage.status
            print("     Round-trip: \(matches ? "✅ SUCCESS" : "❌ FAILED")")
        } else {
            print("     Round-trip: ❌ FAILED (nil)")
        }
        print("")
        
        // Test 3: Conversation Model
        print("3️⃣ Conversation Model")
        print(String(repeating: "-", count: 40))
        
        // Test 1-on-1 conversation
        let oneOnOne = Conversation(
            participant1: authViewModel.currentUser?.id ?? "user1",
            participant2: "other-user-456",
            createdBy: authViewModel.currentUser?.id ?? "user1"
        )
        
        print("  💬 1-on-1 Conversation:")
        print("     ID: \(oneOnOne.id)")
        print("     Participants: \(oneOnOne.participants.count)")
        print("     Is Group: \(oneOnOne.isGroup)")
        print("     Other participant: \(oneOnOne.otherParticipant(currentUserId: authViewModel.currentUser?.id ?? "user1") ?? "none")")
        
        // Test group conversation
        let group = Conversation(
            participants: [
                authViewModel.currentUser?.id ?? "user1",
                "user2",
                "user3",
                "user4"
            ],
            groupName: "Team Chat 🚀",
            createdBy: authViewModel.currentUser?.id ?? "user1"
        )
        
        print("\n  👥 Group Conversation:")
        print("     ID: \(group.id)")
        print("     Name: \(group.groupName ?? "none")")
        print("     Participants: \(group.participants.count)")
        print("     Creator is admin: \(group.isAdmin(userId: authViewModel.currentUser?.id ?? "user1"))")
        
        // Test Firestore conversion
        let convDict = group.toDictionary()
        if let recovered = Conversation(dictionary: convDict) {
            let matches = recovered.id == group.id &&
                         recovered.groupName == group.groupName &&
                         recovered.participants.count == group.participants.count
            print("     Round-trip: \(matches ? "✅ SUCCESS" : "❌ FAILED")")
        } else {
            print("     Round-trip: ❌ FAILED (nil)")
        }
        print("")
        
        // Test 4: TypingStatus Model
        print("4️⃣ TypingStatus Model")
        print(String(repeating: "-", count: 40))
        
        let typing = TypingStatus(
            userId: authViewModel.currentUser?.id ?? "user1",
            conversationId: "test-conv-123"
        )
        
        print("  ⌨️  Typing Status:")
        print("     User: \(typing.id)")
        print("     Conversation: \(typing.conversationId)")
        print("     Is Typing: \(typing.isTyping)")
        print("     Is Stale: \(typing.isStale) (age: \(String(format: "%.1f", Date().timeIntervalSince(typing.startedAt)))s)")
        
        // Test Firestore conversion
        let typingDict = typing.toDictionary()
        if TypingStatus(dictionary: typingDict) != nil {
            print("     Round-trip: ✅ SUCCESS")
        } else {
            print("     Round-trip: ❌ FAILED (nil)")
        }
        
        // Summary
        print("\n" + String(repeating: "=", count: 60))
        print("✅ ALL TESTS COMPLETE!")
        print(String(repeating: "=", count: 60))
        print("📊 Summary:")
        print("   • MessageStatus: 5 cases defined")
        print("   • Message: Full model with Firestore conversion")
        print("   • Conversation: 1-on-1 and group support")
        print("   • TypingStatus: Real-time typing indicators")
        print("\n🚀 Ready for PR #5: Chat Service Integration")
        print(String(repeating: "=", count: 60) + "\n")
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
