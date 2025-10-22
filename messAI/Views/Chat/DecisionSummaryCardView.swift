//
//  DecisionSummaryCardView.swift
//  messAI
//
//  Created for PR #16: Decision Summarization Feature
//  SwiftUI card component for displaying conversation summaries
//

import SwiftUI

/// SwiftUI view that displays a conversation summary as an expandable card
/// Shows overview, decisions, action items, and key points from AI analysis
struct DecisionSummaryCardView: View {
    let summary: ConversationSummary
    let onDismiss: () -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection
            
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)
                
                // Content
                contentSection
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.purple)
            
            // Title & Metadata
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("\(summary.messageCount) messages • \(summary.shortGeneratedTimeAgo)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Expand/Collapse button
            Button(action: {
                isExpanded.toggle()
            }) {
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Overview
            overviewSection
            
            // Decisions
            if summary.hasDecisions {
                decisionsSection
            }
            
            // Action Items
            if summary.hasActionItems {
                actionItemsSection
            }
            
            // Key Points
            if summary.hasKeyPoints {
                keyPointsSection
            }
            
            // Empty state
            if !summary.hasContent {
                emptyStateSection
            }
        }
        .padding(16)
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                
                Text("Overview")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Text(summary.overview)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Decisions Section
    
    private var decisionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                
                Text("Decisions (\(summary.decisions.count))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(summary.decisions.enumerated()), id: \.offset) { index, decision in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text(decision)
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
    
    // MARK: - Action Items Section
    
    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                
                Text("Action Items (\(summary.actionItems.count))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(summary.actionItems) { item in
                    actionItemRow(item)
                }
            }
        }
    }
    
    private func actionItemRow(_ item: ActionItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Checkbox icon
            Image(systemName: "square")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                // Description
                Text(item.description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Assignee & Deadline
                HStack(spacing: 8) {
                    if let assignee = item.assignee {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(assignee)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let deadline = item.deadline {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(deadline)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Key Points Section
    
    private var keyPointsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
                
                Text("Key Points (\(summary.keyPoints.count))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(summary.keyPoints.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text(point)
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No decisions or action items detected")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct DecisionSummaryCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Full summary
            VStack {
                DecisionSummaryCardView(
                    summary: .sample,
                    onDismiss: {}
                )
                .padding()
                
                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .previewDisplayName("Full Summary")
            
            // Decisions only
            VStack {
                DecisionSummaryCardView(
                    summary: .decisionsOnly,
                    onDismiss: {}
                )
                .padding()
                
                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .previewDisplayName("Decisions Only")
            
            // Action items only
            VStack {
                DecisionSummaryCardView(
                    summary: .actionItemsOnly,
                    onDismiss: {}
                )
                .padding()
                
                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .previewDisplayName("Action Items Only")
            
            // Empty summary
            VStack {
                DecisionSummaryCardView(
                    summary: .empty,
                    onDismiss: {}
                )
                .padding()
                
                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .previewDisplayName("Empty Summary")
            
            // Dark mode
            VStack {
                DecisionSummaryCardView(
                    summary: .sample,
                    onDismiss: {}
                )
                .padding()
                
                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif

