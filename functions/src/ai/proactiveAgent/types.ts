/**
 * PR#20.1: Proactive AI Agent - Type Definitions
 * 
 * Defines all TypeScript interfaces and types for the proactive agent system.
 */

/**
 * Types of opportunities the AI can detect
 */
export type OpportunityType = 
  | 'event_planning'
  | 'priority_detection'
  | 'deadline_tracking'
  | 'rsvp_management'
  | 'decision_summary';

/**
 * An opportunity detected by the AI
 */
export interface Opportunity {
  type: OpportunityType;
  confidence: number; // 0.0-1.0
  data: OpportunityData;
  suggestedActions: string[];
  reasoning: string;
  timestamp?: Date;
}

/**
 * Data specific to each opportunity type
 */
export interface OpportunityData {
  // Event Planning
  title?: string;
  eventType?: string;
  date?: string; // ISO8601
  time?: string;
  location?: string;
  participants?: string[];
  notes?: string;
  
  // Priority Detection
  priorityLevel?: 'critical' | 'high' | 'normal';
  urgentReason?: string;
  
  // Deadline Tracking
  deadline?: string; // ISO8601
  task?: string;
  
  // RSVP Management
  eventReference?: string;
  needsRSVP?: boolean;
  
  // Decision Summary
  decision?: string;
  decisionParticipants?: string[];
  agreedActions?: string[];
}

/**
 * Response from detectOpportunities function
 */
export interface DetectionResponse {
  opportunities: Opportunity[];
  tokensUsed: number;
  cost: number;
  cached: boolean;
  timestamp: Date;
}

/**
 * Context for detection (conversation messages)
 */
export interface ConversationContext {
  recentMessages: string; // Formatted messages
  participantNames: { [userId: string]: string };
  messageCount: number;
  existingEvents?: ExistingEvent[];
}

/**
 * Existing events to avoid duplicates
 */
export interface ExistingEvent {
  id: string;
  title: string;
  date?: string;
  createdAt: Date;
}

/**
 * Cache entry structure
 */
export interface CacheEntry {
  data: DetectionResponse;
  timestamp: Date;
  conversationHash: string;
}

/**
 * Detection function signature
 */
export type DetectionFunction = (
  context: ConversationContext
) => Promise<Opportunity | null>;

