import * as functions from 'firebase-functions';

/**
 * Validate request has required fields
 * @param data - Request data to validate
 * @param requiredFields - Array of required field names
 * @throws HttpsError if validation fails
 */
export function validateRequest(data: any, requiredFields: string[]): void {
  // Check if data exists
  if (!data) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Request data is required.'
    );
  }
  
  // Check each required field
  const missingFields: string[] = [];
  for (const field of requiredFields) {
    if (data[field] === undefined || data[field] === null) {
      missingFields.push(field);
    }
  }
  
  if (missingFields.length > 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Missing required fields: ${missingFields.join(', ')}`
    );
  }
}

/**
 * Validate AI feature type
 * @param feature - Feature name to validate
 * @throws HttpsError if invalid feature
 */
export function validateFeature(feature: string): void {
  const validFeatures = [
    'calendar',
    'decision',
    'urgency',
    'rsvp',
    'deadline',
    'agent'
  ];
  
  if (!validFeatures.includes(feature)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Invalid AI feature: ${feature}. Valid features: ${validFeatures.join(', ')}`
    );
  }
}

/**
 * Validate message text
 * @param message - Message text to validate
 * @throws HttpsError if invalid
 */
export function validateMessage(message: string): void {
  if (!message || typeof message !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Message must be a non-empty string.'
    );
  }
  
  if (message.length > 5000) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Message too long. Maximum 5000 characters.'
    );
  }
}

