import * as functions from 'firebase-functions';
import { requireAuth, getUserId } from '../middleware/auth';
import { checkRateLimit } from '../middleware/rateLimit';
import { validateRequest, validateFeature, validateMessage } from '../middleware/validation';
import { extractCalendarDates } from './calendarExtraction';
import { summarizeDecisions } from './decisionSummary';
import { detectUrgency, detectPriority } from './priorityDetection';
import { extractRSVP } from './rsvpTracking';
import { extractDeadlines } from './deadlineExtraction';
import { eventPlanningAgent } from './eventPlanningAgent';

/**
 * Main AI processing function
 * Routes requests to appropriate AI features
 */
export const processAI = functions
  .runWith({
    memory: '512MB',
    timeoutSeconds: 30,
    maxInstances: 10
  })
  .https.onCall(async (data, context) => {
    const startTime = Date.now();
    
    try {
      // 1. Require authentication
      requireAuth(context);
      const userId = getUserId(context);
      
      functions.logger.info('AI request received', {
        userId,
        feature: data.feature,
        hasMessage: !!data.message,
        hasContext: !!data.context
      });
      
      // 2. Validate request
      validateRequest(data, ['feature']);
      validateFeature(data.feature);
      
      if (data.message) {
        validateMessage(data.message);
      }
      
      // 3. Check rate limiting (100 req/hour/user)
      await checkRateLimit(userId);
      
      // 4. Route to appropriate AI feature
      const result = await routeAIFeature(data);
      
      // 5. Add metadata
      const processingTime = Date.now() - startTime;
      const response = {
        ...result,
        processingTimeMs: processingTime,
        modelUsed: 'gpt-4',
        processedAt: new Date().toISOString()
      };
      
      functions.logger.info('AI request completed', {
        userId,
        feature: data.feature,
        processingTimeMs: processingTime
      });
      
      return response;
      
    } catch (error: any) {
      const processingTime = Date.now() - startTime;
      
      functions.logger.error('AI request failed', {
        error: error.message,
        code: error.code,
        userId: context.auth?.uid,
        feature: data?.feature,
        processingTimeMs: processingTime
      });
      
      // Map known errors to user-friendly messages
      if (error.code === 'unauthenticated') {
        throw error; // Already formatted
      }
      
      if (error.code === 'resource-exhausted') {
        throw error; // Already formatted
      }
      
      if (error.code === 'invalid-argument') {
        throw error; // Already formatted
      }
      
      // Unknown error
      throw new functions.https.HttpsError(
        'internal',
        'AI processing failed. Please try again later.'
      );
    }
  });

/**
 * Route request to appropriate AI feature
 */
async function routeAIFeature(data: any): Promise<any> {
  switch (data.feature) {
    case 'calendar':
      return await extractCalendarDates(data);
    
    case 'decision':
      return await summarizeDecisions(data);
    
    case 'urgency':
      return await detectUrgency(data);
    
    case 'priority':
      return await detectPriority(data);
    
    case 'rsvp':
      return await extractRSVP(data);
    
    case 'deadline':
      return await extractDeadlines(data);
    
    case 'agent':
      return await eventPlanningAgent(data);
    
    default:
      // This should never happen due to validation
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Unknown AI feature: ${data.feature}`
      );
  }
}

