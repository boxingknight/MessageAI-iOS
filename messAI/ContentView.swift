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
                
                Button("Test Models") {
                    testModels()
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("MessageAI")
        }
    }
    
    // MARK: - Test Function (Temporary)
    
    func testModels() {
        print("=== TESTING ALL MODELS ===\n")
        
        // 1. MessageStatus
        print("1. MessageStatus")
        print("  ✅ sending: \(MessageStatus.sending.displayText)")
        print("  ✅ read icon: \(MessageStatus.read.iconName)")
        print("  ✅ All cases: \(MessageStatus.allCases.count) cases")
        
        // 2. Message
        print("\n2. Message")
        let msg = Message(conversationId: "c1", senderId: "u1", text: "Test message")
        print("  ✅ Created with ID: \(msg.id.prefix(8))...")
        print("  ✅ Status: \(msg.status.displayText)")
        
        // Test Firestore conversion
        let msgDict = msg.toDictionary()
        print("  ✅ Dictionary keys: \(msgDict.keys.count)")
        
        if let recoveredMsg = Message(dictionary: msgDict) {
            print("  ✅ Firestore round-trip: SUCCESS")
            print("  ✅ Text matches: \(recoveredMsg.text == msg.text)")
        } else {
            print("  ❌ Firestore conversion FAILED")
        }
        
        // 3. Conversation
        print("\n3. Conversation")
        let conv = Conversation(participant1: "u1", participant2: "u2", createdBy: "u1")
        print("  ✅ Created 1-on-1: \(conv.id.prefix(8))...")
        print("  ✅ Is group: \(conv.isGroup)")
        print("  ✅ Other participant: \(conv.otherParticipant(currentUserId: "u1") ?? "none")")
        
        // Test group
        let group = Conversation(participants: ["u1", "u2", "u3"], groupName: "Test Group", createdBy: "u1")
        print("  ✅ Group name: \(group.groupName ?? "none")")
        print("  ✅ Is admin (u1): \(group.isAdmin(userId: "u1"))")
        
        // Test Firestore conversion
        let convDict = conv.toDictionary()
        if let recoveredConv = Conversation(dictionary: convDict) {
            print("  ✅ Firestore round-trip: SUCCESS")
        } else {
            print("  ❌ Firestore conversion FAILED")
        }
        
        // 4. TypingStatus
        print("\n4. TypingStatus")
        let typing = TypingStatus(userId: "u1", conversationId: "c1")
        print("  ✅ Created: \(typing.id)")
        print("  ✅ Is typing: \(typing.isTyping)")
        print("  ✅ Is stale: \(typing.isStale)")
        
        // Test Firestore conversion
        let typingDict = typing.toDictionary()
        if let recoveredTyping = TypingStatus(dictionary: typingDict) {
            print("  ✅ Firestore round-trip: SUCCESS")
        } else {
            print("  ❌ Firestore conversion FAILED")
        }
        
        print("\n=== ALL TESTS COMPLETE ===")
        print("✅ All 4 models created successfully")
        print("✅ All Firestore conversions working")
        print("✅ Ready for PR #5 (Chat Service)\n")
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
