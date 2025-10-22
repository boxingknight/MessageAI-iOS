import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const RATE_LIMIT_PER_HOUR = 100;

/**
 * Check and enforce rate limiting for AI requests
 * Limits: 100 requests per hour per user
 * @param userId - User ID to check rate limit for
 * @throws HttpsError if rate limit exceeded
 */
export async function checkRateLimit(userId: string): Promise<void> {
  // Create hour bucket key
  const hourKey = Math.floor(Date.now() / 3600000);
  const rateLimitRef = admin.firestore()
    .collection('rateLimits')
    .doc(`${userId}_${hourKey}`);
  
  try {
    // Get current count
    const doc = await rateLimitRef.get();
    const count = doc.exists ? (doc.data()?.count || 0) : 0;
    
    // Check if limit exceeded
    if (count >= RATE_LIMIT_PER_HOUR) {
      functions.logger.warn('Rate limit exceeded', { userId, count });
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Too many AI requests. You've used ${count}/${RATE_LIMIT_PER_HOUR} requests this hour. Please try again later.`
      );
    }
    
    // Increment counter
    await rateLimitRef.set({
      count: count + 1,
      lastRequest: admin.firestore.FieldValue.serverTimestamp(),
      userId: userId
    }, { merge: true });
    
    functions.logger.info('Rate limit check passed', { 
      userId, 
      count: count + 1,
      limit: RATE_LIMIT_PER_HOUR 
    });
    
  } catch (error: any) {
    if (error.code === 'resource-exhausted') {
      throw error; // Re-throw rate limit errors
    }
    functions.logger.error('Rate limit check failed', { error, userId });
    // Continue on error (fail open) - don't block users due to Firestore issues
  }
}

/**
 * Get current rate limit status for a user
 */
export async function getRateLimitStatus(userId: string): Promise<{
  used: number;
  limit: number;
  remaining: number;
}> {
  const hourKey = Math.floor(Date.now() / 3600000);
  const rateLimitRef = admin.firestore()
    .collection('rateLimits')
    .doc(`${userId}_${hourKey}`);
  
  const doc = await rateLimitRef.get();
  const used = doc.exists ? (doc.data()?.count || 0) : 0;
  
  return {
    used,
    limit: RATE_LIMIT_PER_HOUR,
    remaining: Math.max(0, RATE_LIMIT_PER_HOUR - used)
  };
}

