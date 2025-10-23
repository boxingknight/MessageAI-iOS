/**
 * PR#20.1: Detect Opportunities Cloud Function
 * 
 * Main entry point for proactive detection.
 * Analyzes conversations and returns opportunities for the AI to suggest.
 */

import { getFirestore } from 'firebase-admin/firestore';
import OpenAI from 'openai';
import * as functions from 'firebase-functions';
import { DetectionResponse, Opportunity, ConversationContext, ExistingEvent } from './types';
import { detectEventPlanning } from './eventDetection';
import { getCache, setCache, hashMessages } from './cache';

/**
 * Detect opportunities in a conversation
 */
export async function detectOpportunities(
  data: { conversationId: string },
  openai: OpenAI
): Promise<DetectionResponse> {
  const { conversationId } = data;
  
  console.log(`[DetectOpportunities] Starting for conversation: ${conversationId}`);
  
  try {
    const db = getFirestore();
    
    // Fetch recent messages (last 20)
    const messagesSnapshot = await db
      .collection(`conversations/${conversationId}/messages`)
      .orderBy('sentAt', 'desc')
      .limit(20)
      .get();
    
    if (messagesSnapshot.empty) {
      console.log('[DetectOpportunities] No messages found');
      return {
        opportunities: [],
        tokensUsed: 0,
        cost: 0,
        cached: false,
        timestamp: new Date()
      };
    }
    
    // Build message hash for caching
    const messageIds = messagesSnapshot.docs.map(doc => doc.id);
    const messageHash = hashMessages(messageIds);
    
    // Check cache
    const cachedResult = await getCache(conversationId, messageHash);
    if (cachedResult) {
      console.log('[DetectOpportunities] Returning cached result');
      return {
        ...cachedResult,
        cached: true,
        timestamp: new Date()
      };
    }
    
    // Build context from messages
    const context = await buildContext(conversationId, messagesSnapshot, db);
    console.log(`[DetectOpportunities] Context built: ${context.messageCount} messages`);
    
    // Run detection (currently only event planning, will add more in Phase 6)
    const opportunities: Opportunity[] = [];
    let totalTokens = 0;
    
    // Event Planning Detection
    const eventOpportunity = await detectEventPlanning(context, openai);
    if (eventOpportunity) {
      opportunities.push(eventOpportunity);
      totalTokens += 500; // Estimate for now
    }
    
    // Sort by confidence (highest first)
    opportunities.sort((a, b) => b.confidence - a.confidence);
    
    // Filter by confidence threshold (>0.5)
    const filteredOpportunities = opportunities.filter(opp => opp.confidence > 0.5);
    
    // Calculate cost (rough estimate)
    const cost = (totalTokens / 1000) * 0.01; // $0.01 per 1K tokens (GPT-4 Turbo avg)
    
    const response: DetectionResponse = {
      opportunities: filteredOpportunities,
      tokensUsed: totalTokens,
      cost,
      cached: false,
      timestamp: new Date()
    };
    
    // Cache the result
    await setCache(conversationId, messageHash, response);
    
    console.log(`[DetectOpportunities] Found ${filteredOpportunities.length} opportunities`);
    return response;
    
  } catch (error: any) {
    functions.logger.error('[DetectOpportunities] Error:', error);
    console.error('[DetectOpportunities] Error:', error.message, error.stack);
    
    // Return empty result instead of throwing
    return {
      opportunities: [],
      tokensUsed: 0,
      cost: 0,
      cached: false,
      timestamp: new Date()
    };
  }
}

/**
 * Build conversation context from messages
 */
async function buildContext(
  conversationId: string,
  messagesSnapshot: FirebaseFirestore.QuerySnapshot,
  db: FirebaseFirestore.Firestore
): Promise<ConversationContext> {
  // Get participant names
  const conversationDoc = await db.collection('conversations').doc(conversationId).get();
  const conversationData = conversationDoc.data();
  const participantIds: string[] = conversationData?.participantIds || [];
  
  const participantNames: { [userId: string]: string } = {};
  for (const userId of participantIds) {
    const userDoc = await db.collection('users').doc(userId).get();
    if (userDoc.exists) {
      participantNames[userId] = userDoc.data()?.displayName || 'Unknown';
    }
  }
  
  // Format messages
  const formattedMessages: string[] = [];
  for (const doc of messagesSnapshot.docs.reverse()) { // Reverse to chronological order
    const data = doc.data();
    const senderId = data.senderId || 'unknown';
    const senderName = participantNames[senderId] || 'Unknown';
    
    let timestamp = 'unknown time';
    if (data.sentAt && typeof data.sentAt.toDate === 'function') {
      timestamp = data.sentAt.toDate().toISOString();
    }
    
    const content = data.text || '[no content]';
    formattedMessages.push(`[${timestamp}] ${senderName}: ${content}`);
  }
  
  // Fetch existing events to avoid duplicates
  // Note: This query requires a composite index (conversationId + createdAt)
  let existingEvents: ExistingEvent[] = [];
  try {
    const eventsSnapshot = await db
      .collection('events')
      .where('conversationId', '==', conversationId)
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();
    
    existingEvents = eventsSnapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        title: data.title || 'Untitled Event',
        date: data.date,
        createdAt: data.createdAt?.toDate() || new Date()
      };
    });
  } catch (error: any) {
    // If index is still building, continue without existing events
    console.log('[DetectOpportunities] Could not fetch existing events (index may be building):', error.message);
    existingEvents = [];
  }
  
  return {
    recentMessages: formattedMessages.join('\n'),
    participantNames,
    messageCount: messagesSnapshot.size,
    existingEvents
  };
}

