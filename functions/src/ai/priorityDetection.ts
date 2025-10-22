/**
 * PR#17: Priority Detection - Hybrid Approach
 * 
 * Automatically detects urgent messages using a two-tier system:
 * 1. Fast keyword filter (80% of messages, <100ms, free)
 * 2. GPT-4 context analysis (20% of messages, ~2s, ~$0.002/call)
 * 
 * Designed to prevent false negatives (missing urgent messages) while
 * keeping API costs low through intelligent filtering.
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
// KEYWORD DETECTION (Fast Path - 80% of messages)
// ============================================================================

/**
 * Critical urgency keywords - immediate action required
 */
const CRITICAL_KEYWORDS = [
  'emergency',
  'urgent',
  'asap',
  'immediately',
  'right now',
  'critical',
  'serious',
  'help',
  '911',
  'sos',
  'crisis'
];

/**
 * High priority keywords - timely action needed
 */
const HIGH_KEYWORDS = [
  'important',
  'soon',
  'today',
  'tonight',
  'this morning',
  'this afternoon',
  'this evening',
  'deadline',
  'due',
  'reminder',
  "don't forget",
  'please',
  'needs',
  'required',
  'must',
  'have to'
];

/**
 * Time-sensitive patterns - specific timing changes or requirements
 */
const TIME_SENSITIVE_PATTERNS = [
  // Pickup changes
  /\b(pickup|pick up|pick-up)\s+(at|by|changed|moved|now)\s+\d{1,2}(:\d{2})?\s*(am|pm|today)?/i,
  
  // Meetings/appointments
  /\b(meeting|appointment|call)\s+(at|by|in)\s+\d{1,2}(:\d{2})?\s*(am|pm|minutes)?/i,
  
  // Deadlines
  /\b(due|deadline|submit|send|turn in)\s+(by|before|today|tonight|tomorrow)/i,
  
  // Cancellations/changes
  /\b(canceled|cancelled|postponed|rescheduled|moved|changed)/i,
  
  // Last minute
  /\b(last (chance|minute)|final (notice|reminder))/i,
  
  // Time expressions
  /\b(in \d+ (minutes?|hours?)|(within|by) \d+ (minutes?|hours?))/i
];

interface KeywordDetectionResult {
  level: 'critical' | 'high' | 'normal';
  confidence: number;
  keywords: string[];
  reason: string;
}

/**
 * Fast keyword-based detection (80% of messages)
 * Returns high confidence for clearly normal or clearly urgent messages
 */
async function keywordBasedDetection(text: string): Promise<KeywordDetectionResult> {
  const lowerText = text.toLowerCase();
  const detectedKeywords: string[] = [];
  
  // Check critical keywords
  let criticalCount = 0;
  for (const keyword of CRITICAL_KEYWORDS) {
    if (lowerText.includes(keyword)) {
      detectedKeywords.push(keyword);
      criticalCount++;
    }
  }
  
  // If ANY critical keyword found → likely critical
  if (criticalCount > 0) {
    return {
      level: 'critical',
      confidence: 0.75, // Will verify with GPT-4
      keywords: detectedKeywords,
      reason: `Critical keywords detected: ${detectedKeywords.join(', ')}`
    };
  }
  
  // Check time-sensitive patterns (strong indicators)
  let patternMatches = 0;
  for (const pattern of TIME_SENSITIVE_PATTERNS) {
    if (pattern.test(text)) {
      patternMatches++;
      detectedKeywords.push(pattern.source.substring(0, 30) + '...');
    }
  }
  
  if (patternMatches > 0) {
    return {
      level: 'high',
      confidence: 0.7, // Will verify with GPT-4
      keywords: detectedKeywords,
      reason: `Time-sensitive pattern detected (${patternMatches} matches)`
    };
  }
  
  // Check high priority keywords
  let highCount = 0;
  for (const keyword of HIGH_KEYWORDS) {
    if (lowerText.includes(keyword)) {
      detectedKeywords.push(keyword);
      highCount++;
    }
  }
  
  // Multiple high keywords → likely high priority
  if (highCount >= 2) {
    return {
      level: 'high',
      confidence: 0.65, // Will verify with GPT-4
      keywords: detectedKeywords,
      reason: `Multiple high-priority keywords: ${detectedKeywords.join(', ')}`
    };
  }
  
  // Single high keyword → maybe high, needs context
  if (highCount === 1) {
    return {
      level: 'high',
      confidence: 0.5, // Lower confidence, definitely needs GPT-4
      keywords: detectedKeywords,
      reason: `Single high-priority keyword: ${detectedKeywords[0]}`
    };
  }
  
  // No keywords → likely normal
  return {
    level: 'normal',
    confidence: 0.85, // High confidence normal, skip GPT-4
    keywords: [],
    reason: 'No urgency indicators detected'
  };
}

// ============================================================================
// GPT-4 DETECTION (Slow Path - 20% of messages)
// ============================================================================

interface GPT4DetectionResult {
  level: 'critical' | 'high' | 'normal';
  confidence: number;
  reasoning: string;
}

/**
 * GPT-4 context-aware detection (only for ambiguous messages)
 * Uses conversation context to determine true urgency
 */
async function gpt4BasedDetection(
  messageText: string,
  recentMessages: any[],
  keywordHints: string[]
): Promise<GPT4DetectionResult> {
  const client = getOpenAI();
  
  // Build conversation context (last 5 messages for context)
  const contextMessages = recentMessages.slice(-5).map((msg: any) => 
    `${msg.senderName}: ${msg.text}`
  ).join('\n');
  
  const systemPrompt = `You are an AI assistant helping busy parents identify urgent messages in group chats.

Your task: Analyze if this message requires immediate or timely attention.

CRITICAL urgency indicators:
- Emergency situations (medical, safety)
- Time-sensitive changes happening NOW or within 1-2 hours (pickup time changed, meeting in 30 min)
- Serious issues requiring immediate action

HIGH priority indicators:
- Important deadlines or tasks due today/tonight
- Schedule changes for today
- Important reminders for upcoming events within 24 hours
- Information that affects today's plans

NORMAL (not urgent):
- General conversation, questions, greetings
- Future plans (>24 hours away)
- Casual updates, sharing photos/stories
- Thank you messages, confirmations

Context matters:
- "Running late" at 8am (pickup at 9am) = CRITICAL
- "Running late" at 2pm (event at 7pm) = HIGH
- "See you tomorrow!" = NORMAL

Respond with JSON:
{
  "level": "critical" | "high" | "normal",
  "confidence": 0.0-1.0,
  "reasoning": "Brief explanation"
}

Keywords detected: ${keywordHints.length > 0 ? keywordHints.join(', ') : 'none'}

Recent conversation context:
${contextMessages}

Current message to analyze:
"${messageText}"`;

  try {
    const completion = await client.chat.completions.create({
      model: 'gpt-4',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: 'Analyze this message and respond with JSON.' }
      ],
      temperature: 0.3, // Lower temperature for consistent classification
      max_tokens: 150
    });
    
    const responseText = completion.choices[0]?.message?.content || '';
    
    // Try to parse JSON response
    try {
      // Extract JSON from markdown code blocks if present
      const jsonMatch = responseText.match(/```json\s*([\s\S]*?)\s*```/) || 
                       responseText.match(/\{[\s\S]*\}/);
      const jsonText = jsonMatch ? (jsonMatch[1] || jsonMatch[0]) : responseText;
      const result = JSON.parse(jsonText);
      
      return {
        level: result.level || 'normal',
        confidence: result.confidence || 0.5,
        reasoning: result.reasoning || 'GPT-4 analysis'
      };
    } catch (parseError) {
      console.error('Failed to parse GPT-4 JSON response:', responseText);
      
      // Fallback: Heuristic parsing
      const lowerResponse = responseText.toLowerCase();
      if (lowerResponse.includes('critical')) {
        return { level: 'critical', confidence: 0.7, reasoning: 'GPT-4 indicated critical' };
      } else if (lowerResponse.includes('high')) {
        return { level: 'high', confidence: 0.7, reasoning: 'GPT-4 indicated high priority' };
      } else {
        return { level: 'normal', confidence: 0.6, reasoning: 'GPT-4 indicated normal' };
      }
    }
  } catch (error: any) {
    console.error('GPT-4 detection error:', error);
    throw new functions.https.HttpsError('internal', `GPT-4 analysis failed: ${error.message}`);
  }
}

// ============================================================================
// MAIN DETECTION FUNCTION (Hybrid Approach)
// ============================================================================

interface PriorityDetectionResponse {
  level: 'critical' | 'high' | 'normal';
  confidence: number;
  method: 'keyword' | 'gpt4' | 'hybrid';
  keywords?: string[];
  reasoning: string;
  processingTimeMs: number;
  usedGPT4: boolean;
}

/**
 * Main priority detection function with hybrid approach
 * 
 * Flow:
 * 1. Keyword filter (fast, free)
 * 2. If confidence > 0.8 → return (80% of messages)
 * 3. If confidence <= 0.8 → GPT-4 analysis (20% of messages)
 * 4. Return highest confidence result
 */
export async function detectPriority(data: any): Promise<PriorityDetectionResponse> {
  const startTime = Date.now();
  
  const { 
    messageText,
    conversationId
  } = data;
  
  // Validation
  if (!messageText || typeof messageText !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'messageText is required');
  }
  
  if (!conversationId) {
    throw new functions.https.HttpsError('invalid-argument', 'conversationId is required');
  }
  
  console.log(`[Priority Detection] Starting for conversation ${conversationId}...`);
  
  try {
    // Step 1: Quick keyword filter (always runs, <100ms)
    const keywordResult = await keywordBasedDetection(messageText);
    console.log(`[Priority Detection] Keyword result: ${keywordResult.level} (confidence: ${keywordResult.confidence})`);
    
    // If high confidence normal → skip GPT-4 (saves money!)
    if (keywordResult.level === 'normal' && keywordResult.confidence >= 0.85) {
      const processingTimeMs = Date.now() - startTime;
      console.log(`[Priority Detection] Fast path (normal) - ${processingTimeMs}ms`);
      
      return {
        level: keywordResult.level,
        confidence: keywordResult.confidence,
        method: 'keyword',
        keywords: keywordResult.keywords,
        reasoning: keywordResult.reason,
        processingTimeMs,
        usedGPT4: false
      };
    }
    
    // Step 2: Fetch recent messages for context (if we'll use GPT-4)
    console.log('[Priority Detection] Fetching recent messages for GPT-4 context...');
    const messagesSnapshot = await db
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .orderBy('sentAt', 'desc')
      .limit(5)
      .get();
    
    const recentMessages = messagesSnapshot.docs.map(doc => {
      const data = doc.data();
      return {
        text: data.text || '',
        senderName: data.senderName || 'Unknown',
        sentAt: data.sentAt
      };
    });
    
    // Step 3: GPT-4 context analysis
    console.log('[Priority Detection] Running GPT-4 analysis...');
    const gpt4Result = await gpt4BasedDetection(
      messageText,
      recentMessages,
      keywordResult.keywords
    );
    console.log(`[Priority Detection] GPT-4 result: ${gpt4Result.level} (confidence: ${gpt4Result.confidence})`);
    
    // Step 4: Combine results (prefer GPT-4 if high confidence)
    const finalResult = gpt4Result.confidence > 0.6 ? gpt4Result : keywordResult;
    
    const processingTimeMs = Date.now() - startTime;
    console.log(`[Priority Detection] Hybrid result: ${finalResult.level} - ${processingTimeMs}ms`);
    
    return {
      level: finalResult.level,
      confidence: finalResult.confidence,
      method: 'hybrid',
      keywords: keywordResult.keywords,
      reasoning: `Keyword: ${keywordResult.reason}. GPT-4: ${gpt4Result.reasoning}`,
      processingTimeMs,
      usedGPT4: true
    };
    
  } catch (error: any) {
    console.error('[Priority Detection] Error:', error);
    
    // Fallback to keyword-only result on error
    const processingTimeMs = Date.now() - startTime;
    const keywordResult = await keywordBasedDetection(messageText);
    
    return {
      level: keywordResult.level,
      confidence: keywordResult.confidence * 0.8, // Reduce confidence due to error
      method: 'keyword',
      keywords: keywordResult.keywords,
      reasoning: `${keywordResult.reason} (GPT-4 fallback due to error)`,
      processingTimeMs,
      usedGPT4: false
    };
  }
}

/**
 * Legacy function name for backward compatibility
 */
export async function detectUrgency(data: any): Promise<any> {
  const result = await detectPriority(data);
  return {
    urgencyLevel: result.level,
    isUrgent: result.level !== 'normal',
    confidence: result.confidence,
    method: result.method,
    reasoning: result.reasoning,
    usedGPT4: result.usedGPT4
  };
}
