import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';

// Lazy initialization of OpenAI client
function getOpenAIClient(): OpenAI {
  const apiKey = process.env.OPENAI_API_KEY || functions.config().openai?.key;
  
  if (!apiKey) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'OpenAI API key not configured. Please set OPENAI_API_KEY environment variable.'
    );
  }
  
  return new OpenAI({ apiKey });
}

/**
 * Action item extracted from conversation
 */
interface ActionItem {
  id: string;
  description: string;
  assignee?: string; // Who needs to do this (if mentioned)
  deadline?: string; // When it's due (if mentioned)
}

/**
 * Conversation summary with decisions and action items
 */
interface ConversationSummary {
  id: string;
  conversationId: string;
  overview: string; // High-level summary (1-2 sentences)
  decisions: string[]; // Key decisions made
  actionItems: ActionItem[]; // Things people need to do
  keyPoints: string[]; // Other important information
  messageCount: number; // Number of messages analyzed
  generatedAt: string; // ISO 8601 timestamp
  expiresAt: string; // Cache expiration (5 minutes)
}

/**
 * Summarize group conversation decisions and action items (PR #16)
 * Uses GPT-4 to extract decisions, action items, and key points from last 50 messages
 * 
 * @param data - Request data with conversationId
 * @returns ConversationSummary with structured summary
 */
export async function summarizeDecisions(data: any): Promise<any> {
  const { conversationId } = data;
  
  if (!conversationId || typeof conversationId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Conversation ID is required for summarization.'
    );
  }
  
  functions.logger.info('Summarizing conversation', {
    conversationId,
  });
  
  try {
    // 1. Fetch last 50 messages from Firestore (RAG pipeline)
    const db = admin.firestore();
    const messagesSnapshot = await db
      .collection('messages')
      .where('conversationId', '==', conversationId)
      .orderBy('timestamp', 'desc')
      .limit(50)
      .get();
    
    if (messagesSnapshot.empty) {
      throw new functions.https.HttpsError(
        'not-found',
        'No messages found in this conversation.'
      );
    }
    
    // 2. Build conversation context (reverse to chronological order)
    const messages = messagesSnapshot.docs
      .reverse()
      .map(doc => {
        const data = doc.data();
        return {
          senderName: data.senderName || 'Unknown',
          text: data.text,
          timestamp: data.timestamp?.toDate().toISOString() || new Date().toISOString()
        };
      });
    
    functions.logger.info('Messages fetched for summarization', {
      conversationId,
      messageCount: messages.length
    });
    
    // 3. Check if there are enough messages to summarize
    if (messages.length < 5) {
      return {
        hasSummary: false,
        message: 'Not enough messages to generate meaningful summary (minimum 5 messages).',
        messageCount: messages.length
      };
    }
    
    // 4. Build context string for GPT-4
    const conversationContext = messages
      .map(m => `${m.senderName}: ${m.text}`)
      .join('\n');
    
    // 5. Call OpenAI GPT-4 for summarization
    const openai = getOpenAIClient();
    
    const completion = await openai.chat.completions.create({
      model: 'gpt-4',
      messages: [
        {
          role: 'system',
          content: `You are an intelligent conversation summarization assistant for a messaging app used by busy parents.
Your job is to analyze group chat conversations and extract:
1. KEY DECISIONS made by the group
2. ACTION ITEMS (things people need to do)
3. IMPORTANT POINTS (other critical information)

RULES:
1. **Decisions**: Clear choices or agreements made by the group (e.g., "Meeting moved to Friday", "Budget approved")
2. **Action Items**: Tasks assigned or volunteered for (e.g., "Sarah will bring cookies", "Mike to set up tables")
   - Include WHO (assignee) if mentioned
   - Include WHEN (deadline) if mentioned
3. **Key Points**: Other important info that doesn't fit above (e.g., "New playground approved", "$500 budget")
4. **Overview**: 1-2 sentence high-level summary of the entire conversation
5. Be concise - each item should be one clear sentence
6. Focus on ACTIONABLE and DECISION-related content, not small talk
7. If no clear decisions/actions, return empty arrays (don't force it)
8. Extract exact names when mentioned (don't use generic "someone")
9. Prioritize recent messages (later messages may override earlier ones)
10. Return only JSON, no additional text

Today's date: ${new Date().toISOString().split('T')[0]}`
        },
        {
          role: 'user',
          content: `Analyze this conversation and extract decisions, action items, and key points:\n\n${conversationContext}`
        }
      ],
      functions: [
        {
          name: 'extract_summary',
          description: 'Extract decisions, action items, and key points from conversation',
          parameters: {
            type: 'object',
            properties: {
              overview: {
                type: 'string',
                description: 'High-level summary of the conversation (1-2 sentences)'
              },
              decisions: {
                type: 'array',
                description: 'Key decisions made by the group',
                items: {
                  type: 'string'
                }
              },
              actionItems: {
                type: 'array',
                description: 'Action items with assignee and deadline if mentioned',
                items: {
                  type: 'object',
                  properties: {
                    description: {
                      type: 'string',
                      description: 'What needs to be done'
                    },
                    assignee: {
                      type: 'string',
                      description: 'Who is responsible (if mentioned)'
                    },
                    deadline: {
                      type: 'string',
                      description: 'When it is due (if mentioned)'
                    }
                  },
                  required: ['description']
                }
              },
              keyPoints: {
                type: 'array',
                description: 'Other important information',
                items: {
                  type: 'string'
                }
              }
            },
            required: ['overview', 'decisions', 'actionItems', 'keyPoints']
          }
        }
      ],
      function_call: { name: 'extract_summary' },
      temperature: 0.3, // Lower temperature for consistency
    });
    
    // 6. Parse GPT-4 response
    const functionCall = completion.choices[0]?.message?.function_call;
    
    if (!functionCall || !functionCall.arguments) {
      functions.logger.error('GPT-4 did not return function call', {
        conversationId,
        response: completion.choices[0]?.message
      });
      throw new functions.https.HttpsError(
        'internal',
        'Failed to generate summary. Please try again.'
      );
    }
    
    const summaryData = JSON.parse(functionCall.arguments);
    
    // 7. Validate and structure response
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 5 * 60 * 1000); // 5 minutes from now
    
    const summary: ConversationSummary = {
      id: `summary_${conversationId}_${Date.now()}`,
      conversationId,
      overview: summaryData.overview || 'No summary available',
      decisions: summaryData.decisions || [],
      actionItems: (summaryData.actionItems || []).map((item: any, index: number) => ({
        id: `action_${Date.now()}_${index}`,
        description: item.description,
        assignee: item.assignee || undefined,
        deadline: item.deadline || undefined
      })),
      keyPoints: summaryData.keyPoints || [],
      messageCount: messages.length,
      generatedAt: now.toISOString(),
      expiresAt: expiresAt.toISOString()
    };
    
    functions.logger.info('Summary generated successfully', {
      conversationId,
      messageCount: messages.length,
      decisionsCount: summary.decisions.length,
      actionItemsCount: summary.actionItems.length,
      keyPointsCount: summary.keyPoints.length
    });
    
    // 8. Store summary in Firestore (/summaries collection)
    await db.collection('summaries').doc(summary.id).set({
      ...summary,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt)
    });
    
    functions.logger.info('Summary stored in Firestore', {
      conversationId,
      summaryId: summary.id
    });
    
    // 9. Return summary
    return {
      hasSummary: true,
      summary
    };
    
  } catch (error: any) {
    functions.logger.error('Failed to generate summary', {
      conversationId,
      error: error.message,
      stack: error.stack
    });
    
    // Re-throw known errors
    if (error.code && error.code.startsWith('firebase-functions/')) {
      throw error;
    }
    
    // Handle OpenAI API errors
    if (error.response?.status === 429) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'AI service is currently busy. Please try again in a moment.'
      );
    }
    
    if (error.response?.status === 401) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'AI service configuration error. Please contact support.'
      );
    }
    
    // Generic error
    throw new functions.https.HttpsError(
      'internal',
      'Failed to generate summary. Please try again later.'
    );
  }
}

