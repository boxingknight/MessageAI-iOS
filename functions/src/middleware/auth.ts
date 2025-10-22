import * as functions from 'firebase-functions';

/**
 * Require authentication for AI requests
 * @throws HttpsError if not authenticated
 */
export function requireAuth(context: functions.https.CallableContext): void {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be logged in to use AI features.'
    );
  }
}

/**
 * Get authenticated user ID
 * @throws HttpsError if not authenticated
 */
export function getUserId(context: functions.https.CallableContext): string {
  requireAuth(context);
  return context.auth!.uid;
}

