/**
 * PR#20.1: Proactive Agent Cloud Function Export
 */

import * as functions from 'firebase-functions';
import OpenAI from 'openai';
import { detectOpportunities } from './detectOpportunities';

/**
 * Cloud Function: Detect opportunities in conversations
 * 
 * Callable function that analyzes conversation messages and returns
 * AI-detected opportunities for event planning, priorities, deadlines, etc.
 */
export const handleDetectOpportunities = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to detect opportunities'
    );
  }

  const { conversationId } = data;

  if (!conversationId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'conversationId is required'
    );
  }

  try {
    console.log(`[ProactiveAgent] Request from user: ${context.auth.uid}, conversation: ${conversationId}`);

    // Initialize OpenAI
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY
    });

    // Detect opportunities
    const result = await detectOpportunities({ conversationId }, openai);

    console.log(`[ProactiveAgent] Returning ${result.opportunities.length} opportunities`);
    return result;

  } catch (error: any) {
    functions.logger.error('[ProactiveAgent] Error:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Failed to detect opportunities: ${error.message}`
    );
  }
});

