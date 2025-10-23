/**
 * PR#19: Deadline Extraction - Keyword + GPT-4 Approach
 * Version: 1.1.0 - Timezone Fix Deployed (Oct 23, 2025)
 * 
 * Automatically detects deadlines, due dates, and action items using:
 * 1. Fast keyword + date pattern filter (80% of messages, <100ms, free) - skip non-deadline messages
 * 2. GPT-4 function calling (20% of messages, ~2-3s, ~$0.003/call) - extract structured deadline data
 * 
 * Handles relative dates ("by EOD", "next Friday", "end of month") with intelligent date parsing.
 * Designed to prevent missed commitments while keeping costs low.
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

interface ExtractDeadlineRequest {
  conversationId: string;
  messageId: string;
  messageText: string;
  senderId: string;
  senderName: string;
  currentTimestamp?: number;  // Optional: server timestamp for consistent date parsing
}

interface ExtractDeadlineResponse {
  detected: boolean;               // Whether a deadline was found
  deadline?: {
    title: string;                 // Short title (e.g., "Permission slip due")
    description?: string;          // Additional details
    dueDate: string;              // ISO 8601 date/time
    isAllDay: boolean;            // All-day vs specific time
    priority: 'high' | 'medium' | 'low';  // Urgency level
    category?: string;            // Optional: 'school', 'work', 'personal', etc.
  };
  confidence: number;              // 0.0-1.0 confidence score
  reasoning?: string;              // Why this classification was made
  method: 'keyword_filter' | 'gpt4' | 'hybrid';  // Detection method used
  processingTimeMs: number;        // How long detection took
  usedGPT4: boolean;              // Whether GPT-4 was called
}

interface DeadlineFunctionCall {
  hasDeadline: boolean;
  title?: string;
  description?: string;
  dueDate?: string;               // ISO 8601 format
  isAllDay?: boolean;
  priority?: 'high' | 'medium' | 'low';
  category?: string;
  confidence?: number;
  reasoning?: string;
}

// ============================================================================
// KEYWORD FILTER (Fast Path - 80% of messages)
// ============================================================================

/**
 * Deadline keywords - indicate a possible deadline/due date
 */
const DEADLINE_KEYWORDS = [
  // Due date terms
  'due', 'deadline', 'expires', 'expiration', 'closes',
  'submit', 'turn in', 'hand in', 'send by', 'reply by',
  'rsvp by', 'respond by', 'ends', 'last day', 'final day',
  'no later than', 'cut-off', 'cutoff', 'must', 'need to',
  'has to', 'have to', 'should', 'before', 'by', 
  
  // Urgency terms
  'urgent', 'asap', 'as soon as possible', 'immediately',
  'today', 'tonight', 'tomorrow', 'this week', 'next week',
  'end of week', 'eow', 'end of day', 'eod', 'end of month',
  'eom', 'end of year', 'eoy',
  
  // Action-oriented terms
  'sign', 'return', 'bring', 'pay', 'register', 'confirm',
  'complete', 'finish', 'schedule', 'book', 'reserve'
];

/**
 * Date patterns - regex to detect date references
 */
const DATE_PATTERNS = [
  // Days of week
  /\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/i,
  
  // Month + day (e.g., "Jan 15", "December 31")
  /\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2}\b/i,
  
  // Numeric dates (e.g., "1/15", "12/31")
  /\b\d{1,2}\/\d{1,2}(?:\/\d{2,4})?\b/,
  
  // Relative dates
  /\b(today|tomorrow|tonight|this\s+week|next\s+week|this\s+month|next\s+month)\b/i,
  
  // End of period
  /\b(end\s+of|eod|eow|eom|eoy)\b/i,
  
  // Specific times
  /\b\d{1,2}:\d{2}\s*(am|pm|AM|PM)?\b/,
  /\b\d{1,2}\s*(am|pm|AM|PM)\b/
];

/**
 * Check if message contains deadline indicators
 * Returns true if we should proceed with GPT-4 analysis
 */
function containsDeadlineIndicators(messageText: string): boolean {
  const lowerText = messageText.toLowerCase();
  
  // Must have at least one deadline keyword
  const hasKeyword = DEADLINE_KEYWORDS.some(keyword => lowerText.includes(keyword));
  
  // Must have at least one date pattern
  const hasDate = DATE_PATTERNS.some(pattern => pattern.test(messageText));
  
  // Both conditions must be true
  return hasKeyword && hasDate;
}

// ============================================================================
// GPT-4 EXTRACTION (Smart Path - 20% of messages)
// ============================================================================

/**
 * Use GPT-4 to extract structured deadline information
 * BUG FIX (PR#19.1): Improved prompt for accurate date/time parsing
 */
async function extractWithGPT4(
  messageText: string,
  currentDate: Date,
  userTimezone?: string
): Promise<DeadlineFunctionCall> {
  const startTime = Date.now();
  const timezone = userTimezone || 'UTC';
  
  try {
    const completion = await getOpenAI().chat.completions.create({
      model: 'gpt-4',
      messages: [
        {
          role: 'system',
          content: `You are a deadline extraction assistant. Extract deadline information from messages.

Current date/time (UTC): ${currentDate.toISOString()}
Current date/time (User TZ): ${currentDate.toLocaleString('en-US', { timeZone: timezone, hour12: true })}
Current day of week: ${currentDate.toLocaleDateString('en-US', { weekday: 'long', timeZone: timezone })}
User timezone: ${timezone} (e.g., Central Time if America/Chicago)

CRITICAL INSTRUCTIONS FOR DATE/TIME PARSING:
- ALL relative dates are FUTURE dates unless explicitly stated as past
  * "Friday" → NEXT Friday (if today is Friday, mean next week's Friday, NOT today)
  * "end of week" → THIS coming Friday/Saturday
  * "tomorrow" → the day after current date
  * "today" → current date (if time is specified and still in future)
- Parse times in 12-hour format correctly:
  * "5PM" = 17:00 (5:00 PM in ${timezone})
  * "5AM" = 05:00 (5:00 AM in ${timezone})
  * "11AM" = 11:00 (11:00 AM in ${timezone})
  * "1PM" = 13:00 (1:00 PM in ${timezone})
  * If AM/PM not specified, infer from context (5:00 is probably 5:00 PM for deadlines)
- ALL times are in user's timezone (${timezone})
- Return dueDate in ISO8601 format with correct timezone offset
- If time is ambiguous, prefer next occurrence in future
- Default to 11:59 PM for all-day deadlines

Date Parsing Examples:
- Today is Monday 2PM, "due Friday" → this coming Friday at 11:59 PM
- Today is Friday 3PM, "due Friday at 5PM" → NEXT Friday (7 days) at 5:00 PM (NOT today)
- Today is Tuesday, "due by 5PM" → today at 5:00 PM if before 5PM, otherwise tomorrow at 5:00 PM
- "due end of week" → this coming Friday at 11:59 PM

Instructions:
- Extract clear deadlines with dates and times
- Handle relative dates ("by EOD" → end of current day, "next Friday" → calculate date)
- Parse fuzzy dates ("end of month" → last day of month)
- Determine if it's all-day or specific time
- Set priority: high (urgent/immediate), medium (within week), low (later)
- Use confidence: 0.9+ (explicit date/time), 0.7-0.9 (relative date), <0.7 (ambiguous)
- If no clear deadline, set hasDeadline to false`
        },
        {
          role: 'user',
          content: `Extract deadline from this message: "${messageText}"`
        }
      ],
      functions: [{
        name: 'extract_deadline',
        description: 'Extract deadline information from a message',
        parameters: {
          type: 'object',
          properties: {
            hasDeadline: {
              type: 'boolean',
              description: 'Whether a deadline exists in the message'
            },
            title: {
              type: 'string',
              description: 'Short title for the deadline (e.g., "Permission slip", "RSVP")'
            },
            description: {
              type: 'string',
              description: 'Optional additional details about what needs to be done'
            },
            dueDate: {
              type: 'string',
              description: 'ISO 8601 deadline date/time (e.g., "2025-10-25T17:00:00Z")'
            },
            isAllDay: {
              type: 'boolean',
              description: 'True if deadline is all-day (no specific time), false if specific time'
            },
            priority: {
              type: 'string',
              enum: ['high', 'medium', 'low'],
              description: 'Priority: high (urgent/today/tomorrow), medium (this week), low (later)'
            },
            category: {
              type: 'string',
              enum: ['school', 'work', 'personal', 'event', 'payment', 'other'],
              description: 'Optional category for organization'
            },
            confidence: {
              type: 'number',
              minimum: 0,
              maximum: 1,
              description: 'Confidence score (0.0-1.0): 0.9+ explicit, 0.7-0.9 relative, <0.7 ambiguous'
            },
            reasoning: {
              type: 'string',
              description: 'Brief explanation of how the deadline was extracted'
            }
          },
          required: ['hasDeadline']
        }
      }],
      function_call: { name: 'extract_deadline' },
      temperature: 0.3  // Lower temperature for more consistent extraction
    });

    const processingTimeMs = Date.now() - startTime;
    console.log(`✅ GPT-4 extraction completed in ${processingTimeMs}ms`);

    // Parse function call result
    const functionCall = completion.choices[0]?.message?.function_call;
    if (!functionCall || !functionCall.arguments) {
      throw new Error('No function call in GPT-4 response');
    }

    const result: DeadlineFunctionCall = JSON.parse(functionCall.arguments);
    return result;

  } catch (error: any) {
    console.error('❌ GPT-4 extraction error:', error);
    throw new Error(`GPT-4 extraction failed: ${error.message}`);
  }
}

// ============================================================================
// TIMEZONE CONVERSION
// ============================================================================

/**
 * Convert GPT-4's "naive" UTC time to actual UTC time accounting for user timezone
 * 
 * BUG FIX (PR#19.2): GPT-4 returns times as if they're UTC, but user meant local time
 * 
 * Example:
 * - User in Central Time (UTC-5) says "5PM"
 * - GPT-4 returns "2025-10-24T17:00:00.000Z" (17:00 UTC)
 * - We interpret "17:00" as "17:00 Central" → "22:00 UTC"
 * 
 * @param naiveDate - Date from GPT-4 (treated as if time is in user's timezone)
 * @param userTimezone - IANA timezone (e.g., "America/Chicago")
 * @returns Date adjusted to correct UTC time
 */
function convertToUserTimezone(naiveDate: Date, userTimezone: string): Date {
  try {
    // Extract the time components that GPT-4 thought were local time
    const year = naiveDate.getUTCFullYear();
    const month = naiveDate.getUTCMonth(); // 0-indexed
    const day = naiveDate.getUTCDate();
    const hours = naiveDate.getUTCHours();
    const minutes = naiveDate.getUTCMinutes();
    
    console.log(`🌍 Timezone conversion:`);
    console.log(`   GPT-4 naive result: ${naiveDate.toISOString()}`);
    console.log(`   Extracted time: ${year}-${month+1}-${day} ${hours}:${minutes}`);
    console.log(`   User timezone: ${userTimezone}`);
    
    // Create TWO dates:
    // 1. A "local" date as if we're in UTC (this is what GPT-4 gave us)
    const asUTC = new Date(Date.UTC(year, month, day, hours, minutes, 0));
    
    // 2. Parse the same date/time string as if it's in the user's timezone
    // We do this by converting to a locale string and back
    const inUserTZ = new Date(asUTC.toLocaleString('en-US', { timeZone: userTimezone }));
    
    // Calculate the offset between UTC and user timezone
    const offset = asUTC.getTime() - inUserTZ.getTime();
    
    // Apply the offset to get the correct UTC time
    const correctedUTC = new Date(asUTC.getTime() + offset);
    
    console.log(`   Step 1 - as UTC: ${asUTC.toISOString()}`);
    console.log(`   Step 2 - parsed in ${userTimezone}: ${inUserTZ.toISOString()}`);
    console.log(`   Step 3 - offset: ${offset / (1000 * 60 * 60)} hours`);
    console.log(`   Step 4 - corrected UTC: ${correctedUTC.toISOString()}`);
    console.log(`   Verification - displays as: ${correctedUTC.toLocaleString('en-US', { timeZone: userTimezone, hour12: true })}`);
    
    return correctedUTC;
  } catch (error) {
    console.error(`❌ Timezone conversion failed:`, error);
    return naiveDate;
  }
}

// ============================================================================
// DATE VALIDATION
// ============================================================================

/**
 * Validate and fix extracted date to ensure it's in the future
 * BUG FIX (PR#19.1): Prevents past dates from being stored as deadlines
 */
function validateAndFixDate(parsedDate: Date, currentDate: Date): Date {
  const daysDiff = (parsedDate.getTime() - currentDate.getTime()) / (1000 * 60 * 60 * 24);
  
  // If date is in past, try to fix it
  if (daysDiff < 0) {
    console.warn(`⚠️ Detected past date (${Math.abs(daysDiff).toFixed(1)} days ago), adjusting to future`);
    
    // If it's a weekday reference, find next occurrence
    const targetDay = parsedDate.getDay();
    const adjusted = new Date(currentDate);
    
    // Find next occurrence of this day of week
    let daysToAdd = (targetDay - adjusted.getDay() + 7) % 7;
    if (daysToAdd === 0) daysToAdd = 7; // If same day, go to next week
    
    adjusted.setDate(adjusted.getDate() + daysToAdd);
    adjusted.setHours(parsedDate.getHours(), parsedDate.getMinutes(), 0, 0);
    
    console.log(`✅ Adjusted date from ${parsedDate.toISOString()} to ${adjusted.toISOString()}`);
    return adjusted;
  }
  
  // If date is more than 2 years in future, probably wrong
  if (daysDiff > 730) {
    console.warn(`⚠️ Detected far-future date (${daysDiff.toFixed(1)} days away), capping at 1 year`);
    const capped = new Date(currentDate);
    capped.setFullYear(capped.getFullYear() + 1);
    return capped;
  }
  
  return parsedDate;
}

// ============================================================================
// MAIN EXTRACTION FUNCTION
// ============================================================================

/**
 * Extract deadline from message using hybrid approach
 * Returns structured deadline data or null if no deadline detected
 * BUG FIX (PR#19.1): Now uses timezone and validates dates
 */
export async function detectDeadline(
  request: ExtractDeadlineRequest
): Promise<ExtractDeadlineResponse> {
  const startTime = Date.now();
  const userTimezone = (request as any).userTimezone || 'UTC';
  
  console.log('🎯 Deadline detection started for message:', request.messageId);
  console.log('   Message text:', request.messageText);
  console.log('   User timezone:', userTimezone);

  try {
    // ========================================
    // STEP 1: Keyword Filter (Fast Path)
    // ========================================
    
    const hasIndicators = containsDeadlineIndicators(request.messageText);
    
    if (!hasIndicators) {
      const processingTimeMs = Date.now() - startTime;
      console.log(`✅ No deadline indicators found (${processingTimeMs}ms). Skipping GPT-4.`);
      
      return {
        detected: false,
        confidence: 1.0,
        method: 'keyword_filter',
        processingTimeMs,
        usedGPT4: false
      };
    }

    console.log('✓ Deadline indicators found. Proceeding to GPT-4 analysis...');

    // ========================================
    // STEP 2: GPT-4 Extraction (Smart Path)
    // ========================================
    
    const currentDate = request.currentTimestamp 
      ? new Date(request.currentTimestamp * 1000)  // BUG FIX: Convert from seconds to ms
      : new Date();

    const gpt4Result = await extractWithGPT4(request.messageText, currentDate, userTimezone);

    // ========================================
    // STEP 3: Process GPT-4 Result
    // ========================================
    
    if (!gpt4Result.hasDeadline) {
      const processingTimeMs = Date.now() - startTime;
      console.log(`✅ GPT-4 determined no deadline present (${processingTimeMs}ms)`);
      
      return {
        detected: false,
        confidence: gpt4Result.confidence || 0.8,
        reasoning: gpt4Result.reasoning,
        method: 'gpt4',
        processingTimeMs,
        usedGPT4: true
      };
    }

    // Validate required fields
    if (!gpt4Result.title || !gpt4Result.dueDate) {
      throw new Error('GPT-4 returned incomplete deadline data');
    }

    // BUG FIX (PR#19.2): Convert GPT-4's naive UTC time to actual UTC accounting for timezone
    // GPT-4 returns "17:00 UTC" when user means "17:00 Central", so we need to adjust
    const parsedDate = new Date(gpt4Result.dueDate);
    const timezoneAdjustedDate = convertToUserTimezone(parsedDate, userTimezone);
    
    // BUG FIX (PR#19.1): Validate and fix date if it's in the past
    const validatedDate = validateAndFixDate(timezoneAdjustedDate, currentDate);
    const validatedDateISO = validatedDate.toISOString();

    const processingTimeMs = Date.now() - startTime;
    console.log(`✅ Deadline detected: "${gpt4Result.title}" due ${validatedDateISO} (${processingTimeMs}ms)`);

    return {
      detected: true,
      deadline: {
        title: gpt4Result.title,
        description: gpt4Result.description,
        dueDate: validatedDateISO,  // Use validated date
        isAllDay: gpt4Result.isAllDay ?? false,
        priority: gpt4Result.priority || 'medium',
        category: gpt4Result.category
      },
      confidence: gpt4Result.confidence || 0.8,
      reasoning: gpt4Result.reasoning,
      method: 'hybrid',
      processingTimeMs,
      usedGPT4: true
    };

  } catch (error: any) {
    const processingTimeMs = Date.now() - startTime;
    console.error('❌ Deadline detection error:', error);
    
    // Return error state (don't throw - client can handle gracefully)
    return {
      detected: false,
      confidence: 0.0,
      reasoning: `Error: ${error.message}`,
      method: 'gpt4',
      processingTimeMs,
      usedGPT4: true
    };
  }
}

// ============================================================================
// FIRESTORE INTEGRATION (Optional - For Deadline Storage)
// ============================================================================

/**
 * Store detected deadline in Firestore subcollection
 * Collection structure: /conversations/{conversationId}/deadlines/{deadlineId}
 * 
 * BUG FIX (PR#19.1): Prevents duplicate deadlines by checking if one already exists for this message
 */
export async function storeDeadline(
  conversationId: string,
  messageId: string,
  senderId: string,
  deadline: ExtractDeadlineResponse['deadline']
): Promise<string> {
  if (!deadline) {
    throw new Error('No deadline data to store');
  }

  // BUG FIX: Check if deadline already exists for this message (prevents duplicates in group chats)
  const existingQuery = await db
    .collection('conversations')
    .doc(conversationId)
    .collection('deadlines')
    .where('messageId', '==', messageId)
    .where('status', '==', 'active')
    .limit(1)
    .get();
  
  if (!existingQuery.empty) {
    const existingId = existingQuery.docs[0].id;
    console.log(`⚠️ Deadline already exists for message ${messageId}, returning existing ID: ${existingId}`);
    return existingId;
  }

  const deadlineRef = db
    .collection('conversations')
    .doc(conversationId)
    .collection('deadlines')
    .doc();  // Auto-generate ID

  const deadlineData = {
    id: deadlineRef.id,
    conversationId,
    messageId,
    createdBy: senderId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    
    // Deadline details
    title: deadline.title,
    description: deadline.description || null,
    dueDate: admin.firestore.Timestamp.fromDate(new Date(deadline.dueDate)),
    isAllDay: deadline.isAllDay,
    priority: deadline.priority,
    category: deadline.category || null,
    
    // Status tracking
    status: 'active',  // 'active', 'completed', 'cancelled'
    completedAt: null,
    completedBy: null,
    
    // Metadata
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await deadlineRef.set(deadlineData);
  
  console.log(`✅ Deadline stored: ${deadlineRef.id} for message ${messageId}`);
  return deadlineRef.id;
}

/**
 * Update deadline status (e.g., mark as completed)
 */
export async function updateDeadlineStatus(
  conversationId: string,
  deadlineId: string,
  status: 'active' | 'completed' | 'cancelled',
  userId: string
): Promise<void> {
  const deadlineRef = db
    .collection('conversations')
    .doc(conversationId)
    .collection('deadlines')
    .doc(deadlineId);

  const updates: any = {
    status,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  if (status === 'completed') {
    updates.completedAt = admin.firestore.FieldValue.serverTimestamp();
    updates.completedBy = userId;
  }

  await deadlineRef.update(updates);
  console.log(`✅ Deadline ${deadlineId} status updated to: ${status}`);
}

// ============================================================================
// CLOUD FUNCTION WRAPPER (Called by processAI.ts router)
// ============================================================================

/**
 * Main entry point for deadline extraction (called from processAI.ts)
 * Expected request format:
 * {
 *   feature: 'deadline',
 *   conversationId: string,
 *   messageId: string,
 *   messageText: string,
 *   senderId: string,
 *   senderName: string,
 *   currentTimestamp?: number,
 *   storeInFirestore?: boolean  // Optional: auto-store deadline
 * }
 */
export async function extractDeadlines(data: any): Promise<any> {
  console.log('🎯 extractDeadlines called with data:', {
    conversationId: data.conversationId,
    messageId: data.messageId,
    messageTextLength: data.messageText?.length
  });

  // Validate required fields
  if (!data.conversationId || !data.messageId || !data.messageText) {
    throw new Error('Missing required fields: conversationId, messageId, messageText');
  }

  // Extract deadline
  const request: ExtractDeadlineRequest = {
    conversationId: data.conversationId,
    messageId: data.messageId,
    messageText: data.messageText,
    senderId: data.senderId || 'unknown',
    senderName: data.senderName || 'Unknown User',
    currentTimestamp: data.currentTimestamp
  };

  const result = await detectDeadline(request);

  // Optionally store in Firestore
  if (data.storeInFirestore && result.detected && result.deadline) {
    try {
      const deadlineId = await storeDeadline(
        data.conversationId,
        data.messageId,
        data.senderId,
        result.deadline
      );
      
      return {
        ...result,
        deadlineId,
        stored: true
      };
    } catch (error: any) {
      console.error('❌ Failed to store deadline:', error);
      // Return result anyway, just note storage failed
      return {
        ...result,
        stored: false,
        storageError: error.message
      };
    }
  }

  return result;
}

// ============================================================================
// EXPORTS
// ============================================================================

export {
  ExtractDeadlineRequest,
  ExtractDeadlineResponse,
  containsDeadlineIndicators,
  extractWithGPT4
};
