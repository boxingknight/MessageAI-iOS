//
//  ProactiveAgentService.swift
//  messAI
//
//  PR#20.1: Proactive AI Agent - Background Monitoring Service
//  Monitors conversations and detects opportunities automatically
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class ProactiveAgentService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentOpportunities: [Opportunity] = []
    @Published var isMonitoring: Bool = false
    @Published var lastAnalysisTime: Date?
    @Published var error: String?
    
    // MARK: - Private Properties
    
    private var conversationId: String?
    private var messagesListener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    // Throttling: max 1 analysis per 3 seconds (reduced from 10s)
    // This allows faster detection while preventing excessive API calls
    private let throttleInterval: TimeInterval = 3.0
    private var lastAnalysisTimestamp: Date?
    
    // MARK: - Singleton
    
    static let shared = ProactiveAgentService()
    
    private init() {
        print("[ProactiveAgent] Service initialized")
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring a conversation for opportunities
    func startMonitoring(conversationId: String) {
        print("[ProactiveAgent] Starting monitoring for conversation: \(conversationId)")
        
        guard !isMonitoring else {
            print("[ProactiveAgent] Already monitoring")
            return
        }
        
        self.conversationId = conversationId
        self.isMonitoring = true
        
        // Listen to new messages
        setupMessageListener()
        
        // DON'T perform initial analysis immediately!
        // Reason: Conversation may be empty or only have old messages
        // The listener will trigger analysis when new messages arrive
        print("[ProactiveAgent] Listener active, waiting for new messages...")
    }
    
    /// Stop monitoring the current conversation
    func stopMonitoring() {
        print("[ProactiveAgent] Stopping monitoring")
        
        messagesListener?.remove()
        messagesListener = nil
        conversationId = nil
        isMonitoring = false
        currentOpportunities = []
        lastAnalysisTime = nil
        
        print("[ProactiveAgent] Monitoring stopped")
    }
    
    // MARK: - Private Methods
    
    /// Set up Firestore listener for new messages
    private func setupMessageListener() {
        guard let conversationId = conversationId else { return }
        
        let db = Firestore.firestore()
        
        // Listen to new messages (only the most recent one)
        messagesListener = db.collection("conversations/\(conversationId)/messages")
            .order(by: "sentAt", descending: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("[ProactiveAgent] Error listening to messages: \(error.localizedDescription)")
                    self.error = error.localizedDescription
                    return
                }
                
                guard snapshot?.documentChanges.contains(where: { $0.type == .added }) == true else {
                    // No new messages, just modifications
                    return
                }
                
                print("[ProactiveAgent] New message detected, checking if analysis needed")
                
                // Check if we should analyze (throttling)
                if self.shouldAnalyze() {
                    Task {
                        await self.analyzeConversation()
                    }
                } else {
                    print("[ProactiveAgent] Throttled - too soon since last analysis")
                }
            }
        
        print("[ProactiveAgent] Message listener set up")
    }
    
    /// Check if enough time has passed since last analysis (throttling)
    private func shouldAnalyze() -> Bool {
        guard let lastTimestamp = lastAnalysisTimestamp else {
            // First analysis, always allow
            return true
        }
        
        let timeSinceLastAnalysis = Date().timeIntervalSince(lastTimestamp)
        let shouldAnalyze = timeSinceLastAnalysis >= throttleInterval
        
        print("[ProactiveAgent] Time since last analysis: \(timeSinceLastAnalysis)s, throttle: \(throttleInterval)s, should analyze: \(shouldAnalyze)")
        
        return shouldAnalyze
    }
    
    /// Analyze the conversation for opportunities
    private func analyzeConversation() async {
        guard let conversationId = conversationId else {
            print("[ProactiveAgent] No conversation ID, skipping analysis")
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[ProactiveAgent] No authenticated user, skipping analysis")
            return
        }
        
        print("[ProactiveAgent] Starting analysis for conversation: \(conversationId)")
        
        do {
            // Call Cloud Function
            let result = try await AIService.shared.detectOpportunities(conversationId: conversationId)
            
            await MainActor.run {
                self.currentOpportunities = result.opportunities
                self.lastAnalysisTime = Date()
                self.error = nil
                
                // CRITICAL FIX: Only update throttle timestamp if we actually analyzed messages
                // This prevents the initial empty analysis from blocking the first real message
                if result.opportunities.count > 0 {
                    // Found opportunities → set timestamp (normal throttling)
                    self.lastAnalysisTimestamp = Date()
                    print("[ProactiveAgent] Analysis complete: \(result.opportunities.count) opportunities found")
                    print("[ProactiveAgent] Throttle timestamp updated (found opportunities)")
                } else if result.tokensUsed > 0 {
                    // No opportunities but we consumed tokens → conversation has messages
                    self.lastAnalysisTimestamp = Date()
                    print("[ProactiveAgent] Analysis complete: 0 opportunities found (but conversation analyzed)")
                    print("[ProactiveAgent] Throttle timestamp updated (tokens used: \(result.tokensUsed))")
                } else {
                    // No opportunities and no tokens → empty conversation or cached empty result
                    print("[ProactiveAgent] Analysis complete: 0 opportunities (empty/cached)")
                    print("[ProactiveAgent] Throttle timestamp NOT updated (allow retry soon)")
                }
                
                print("[ProactiveAgent] Cached: \(result.cached), Tokens: \(result.tokensUsed), Cost: $\(String(format: "%.4f", result.cost))")
                
                // Log each opportunity
                for opp in result.opportunities {
                    print("[ProactiveAgent]   - \(opp.type.displayName): \(opp.displayTitle) (confidence: \(opp.confidencePercentage)%)")
                }
            }
            
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                print("[ProactiveAgent] Analysis failed: \(error.localizedDescription)")
                // Don't update timestamp on error (allow retry)
            }
        }
    }
    
    /// Manually trigger analysis (for testing or user-initiated detection)
    func triggerAnalysis() async {
        print("[ProactiveAgent] Manual analysis triggered")
        await analyzeConversation()
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopMonitoring()
        print("[ProactiveAgent] Service deinitialized")
    }
}

