/**
 * PR#18: RSVP Tracking - Hybrid Approach
 * 
 * Automatically detects RSVP responses (yes/no/maybe) using a two-tier system:
 * 1. Fast keyword filter (80% of messages, <100ms, free) - skip non-RSVP messages
 * 2. GPT-4 function calling (20% of messages, ~2s, ~$0.003/call) - classify response
 * 
 * Designed to track event attendance automatically while keeping costs low.
 * Links RSVPs to recent calendar events (from PR#15) with AI suggestion + user confirmation.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Lazy-load OpenAI to avoid deployment issues
let openai: any = null;
function getOpenAI() {
  if (!openai) {
    const OpenAI = require('openai');
    const apiKey = functions.config().openai?.key;
    if (!apiKey) {
      throw new Error('OpenAI API key not configured');
    }
    openai = new OpenAI({ apiKey });
  }
  return openai;
}

const db = admin.firestore();

// ============================================================================
// INTERFACES
// ============================================================================

interface DetectRSVPRequest {
  conversationId: string;
  messageId: string;
  messageText: string;
  senderId: string;
  senderName: string;
  recentEventIds?: string[];  // Optional: pre-fetched event IDs to check
}

interface DetectRSVPResponse {
  detected: boolean;            // Whether this is an RSVP response
  status?: 'yes' | 'no' | 'maybe';  // RSVP status (if detected)
  eventId?: string;             // Linked event ID (if detected)
  confidence: number;           // 0.0-1.0 confidence score
  reasoning?: string;           // Why this classification was made
  method: 'keyword' | 'gpt4' | 'hybrid';  // Detection method used
  processingTimeMs: number;     // How long detection took
  usedGPT4: boolean;           // Whether GPT-4 was called
}

interface RSVPFunctionCall {
  detected: boolean;
  status?: 'yes' | 'no' | 'maybe';
  eventId?: string;
  confidence: number;
  reasoning?: string;
}

// ============================================================================
// KEYWORD FILTER (Fast Path - 80% of messages)
// ============================================================================

/**
 * RSVP keywords - these indicate a possible RSVP response
 * If none of these are present, we can skip GPT-4 analysis entirely
 */
const RSVP_KEYWORDS = [
  // Affirmative responses
  'yes', 'yeah', 'yep', 'sure', 'ok', 'okay', 
  'count me in', 'i\'ll be there', 'we\'ll be there', 
  'definitely', 'absolutely', 'for sure', 'sounds good',
  'we\'re in', 'i\'m in', 'coming', 'attending', 'will attend',
  'can make it', 'see you there', 'looking forward',
  
  // Negative responses
  'no', 'nope', 'nah', 'sorry', 
  'can\'t make it', 'won\'t make it', 'unable to',
  'not coming', 'not attending', 'can\'t come',
  'have to skip', 'have to pass', 'skip this one',
  'unfortunately', 'regret', 'miss this', 'decline',
  
  // Uncertain responses
  'maybe', 'possibly', 'perhaps', 'might',
  'not sure', 'unsure', 'tentative', 'probably',
  'depends', 'let me check', 'need to check',
  'see how it goes', 'play it by ear'
];

/**
 * Check if message contains any RSVP keywords (case-insensitive)
 * Returns true if we should proceed with GPT-4 analysis
 */
function hasRSVPKeyword(messageText: string): boolean {
  const lowerText = messageText.toLowerCase();
  return RSVP_KEYWORDS.some(keyword => lowerText.includes(keyword));
}

// ============================================================================
// EVENT FETCHING (Context for GPT-4)
// ============================================================================

/**
 * Fetch recent calendar events from conversation (from PR#15)
 * Returns array of event IDs and their details for context
 */
async function fetchRecentEvents(
  conversationId: string, 
  recentEventIds?: string[]
): Promise<Array<{id: string, title: string, date: string}>> {
  console.log('📅 Fetching recent events for conversation:', conversationId);
  
  try {
    // If event IDs provided, fetch those specific events
    if (recentEventIds && recentEventIds.length > 0) {
      console.log(`Using provided event IDs: ${recentEventIds.join(', ')}`);
      const events = [];
      for (const eventId of recentEventIds.slice(0, 5)) {
        const eventDoc = await db.collection('events').doc(eventId).get();
        if (eventDoc.exists) {
          const data = eventDoc.data();
          events.push({
            id: eventId,
            title: data?.title || 'Untitled Event',
            date: data?.date || 'Unknown date'
          });
        }
      }
      return events;
    }
    
    // Otherwise, fetch events from recent messages with calendar data
    const recentMessages = await db
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .where('aiMetadata.calendarEvents', '!=', null)
      .orderBy('aiMetadata.calendarEvents')
      .orderBy('sentAt', 'desc')
      .limit(10)
      .get();
    
    console.log(`Found ${recentMessages.size} messages with calendar events`);
    
    const events: Array<{id: string, title: string, date: string}> = [];
    const seenIds = new Set<string>();
    
    recentMessages.forEach(doc => {
      const aiMetadata = doc.data().aiMetadata;
      if (aiMetadata?.calendarEvents) {
        aiMetadata.calendarEvents.forEach((event: any) => {
          if (event.id && !seenIds.has(event.id)) {
            seenIds.add(event.id);
            events.push({
              id: event.id,
              title: event.title || 'Untitled Event',
              date: event.date || 'Unknown date'
            });
          }
        });
      }
    });
    
    console.log(`Extracted ${events.length} unique events`);
    return events.slice(0, 5);  // Return max 5 most recent
    
  } catch (error) {
    console.error('Error fetching recent events:', error);
    return [];
  }
}

// ============================================================================
// GPT-4 RSVP DETECTION (Slow Path - 20% of messages)
// ============================================================================

/**
 * Use GPT-4 function calling to detect and classify RSVP responses
 * Only called if keyword filter passes
 */
async function detectRSVPWithGPT4(
  messageText: string,
  senderName: string,
  recentEvents: Array<{id: string, title: string, date: string}>
): Promise<RSVPFunctionCall> {
  console.log('🤖 Calling GPT-4 for RSVP detection...');
  
  const ai = getOpenAI();
  
  // Build events context for prompt
  const eventsContext = recentEvents.length > 0
    ? `Recent events in this conversation:\n${recentEvents.map((e, i) => 
        `${i + 1}. "${e.title}" on ${e.date} (ID: ${e.id})`
      ).join('\n')}`
    : 'No recent events found in this conversation.';
  
  try {
    const completion = await ai.chat.completions.create({
      model: 'gpt-4',
      messages: [
        {
          role: 'system',
          content: `You are an RSVP detection assistant for busy parents managing group chats.

Your job: Analyze messages and detect if they contain an RSVP response (yes/no/maybe) to an event invitation.

RSVP Classification Rules:
- YES: Affirmative responses ("yes", "count me in", "we'll be there", "definitely", "sure", "ok")
- NO: Negative responses ("no", "can't make it", "sorry, we can't", "not attending", "have to pass")
- MAYBE: Uncertain responses ("maybe", "not sure", "possibly", "tentative", "depends", "need to check")

Event Linking Rules:
- If recent events exist AND the message clearly responds to one, provide that event ID
- If no clear link to a specific event, return null for eventId
- If message says "yes to soccer practice", link to the soccer practice event
- If message just says "yes" with multiple recent events, link to the MOST RECENT one

Confidence Scoring:
- 0.9-1.0: Very clear RSVP ("Yes, we'll be there!")
- 0.7-0.9: Clear RSVP with context ("Count me in")
- 0.5-0.7: Likely RSVP but ambiguous ("Maybe")
- 0.3-0.5: Possible RSVP but uncertain
- 0.0-0.3: Probably not an RSVP

${eventsContext}`
        },
        {
          role: 'user',
          content: `Message from ${senderName}: "${messageText}"

Is this an RSVP response? If yes, classify as yes/no/maybe and optionally link to an event ID.`
        }
      ],
      functions: [
        {
          name: 'detect_rsvp',
          description: 'Detect and classify RSVP response in a message',
          parameters: {
            type: 'object',
            properties: {
              detected: {
                type: 'boolean',
                description: 'Whether this message contains an RSVP response'
              },
              status: {
                type: 'string',
                enum: ['yes', 'no', 'maybe'],
                description: 'RSVP status if detected (yes/no/maybe)'
              },
              eventId: {
                type: 'string',
                description: 'ID of the event being responded to (if clear from context)'
              },
              confidence: {
                type: 'number',
                description: 'Confidence score 0.0-1.0 for this classification'
              },
              reasoning: {
                type: 'string',
                description: 'Brief explanation of why this classification was made'
              }
            },
            required: ['detected', 'confidence', 'reasoning']
          }
        }
      ],
      function_call: { name: 'detect_rsvp' },
      temperature: 0.3  // Lower temperature for more consistent classification
    });
    
    const functionCall = completion.choices[0].message.function_call;
    if (!functionCall || !functionCall.arguments) {
      console.warn('No function call in GPT-4 response');
      return {
        detected: false,
        confidence: 0.0,
        reasoning: 'GPT-4 did not return a valid function call'
      };
    }
    
    const result: RSVPFunctionCall = JSON.parse(functionCall.arguments);
    console.log('✅ GPT-4 result:', result);
    
    return result;
    
  } catch (error) {
    console.error('Error calling GPT-4:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to analyze RSVP with GPT-4',
      { error: String(error) }
    );
  }
}

// ============================================================================
// MAIN CLOUD FUNCTION
// ============================================================================

/**
 * Detect RSVP responses in messages using hybrid approach
 * 
 * Flow:
 * 1. Keyword filter (fast) - skip if no RSVP keywords
 * 2. Fetch recent events (context)
 * 3. GPT-4 analysis (slow) - classify RSVP if keywords found
 * 
 * Returns RSVP status, confidence, linked event ID, and metadata
 */
export async function extractRSVP(data: any): Promise<DetectRSVPResponse> {
  const request: DetectRSVPRequest = data;
  const startTime = Date.now();
  console.log('🎯 RSVP Detection starting for message:', request.messageId);
  
  const {
    conversationId,
    messageId,
    messageText,
    senderName,
    recentEventIds
  } = request;
  
  // Validate inputs
  if (!messageText || !conversationId || !messageId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: messageText, conversationId, messageId'
    );
  }
  
  // STEP 1: Keyword filter (fast path)
  console.log('Step 1: Keyword filter...');
  const hasKeyword = hasRSVPKeyword(messageText);
  
  if (!hasKeyword) {
    const processingTime = Date.now() - startTime;
    console.log(`✅ No RSVP keywords found (${processingTime}ms). Skipping GPT-4.`);
    
    return {
      detected: false,
      confidence: 0.0,
      method: 'keyword',
      processingTimeMs: processingTime,
      usedGPT4: false
    };
  }
  
  console.log('✓ RSVP keywords found. Proceeding to GPT-4 analysis...');
  
  // STEP 2: Fetch recent events for context
  console.log('Step 2: Fetching recent events...');
  const recentEvents = await fetchRecentEvents(conversationId, recentEventIds);
  console.log(`Found ${recentEvents.length} recent events`);
  
  // STEP 3: GPT-4 analysis (slow path)
  console.log('Step 3: GPT-4 analysis...');
  const gpt4Result = await detectRSVPWithGPT4(
    messageText,
    senderName,
    recentEvents
  );
  
  const processingTime = Date.now() - startTime;
  console.log(`✅ RSVP detection complete (${processingTime}ms)`);
  
  return {
    detected: gpt4Result.detected,
    status: gpt4Result.status,
    eventId: gpt4Result.eventId,
    confidence: gpt4Result.confidence,
    reasoning: gpt4Result.reasoning,
    method: 'hybrid',
    processingTimeMs: processingTime,
    usedGPT4: true
  };
}
