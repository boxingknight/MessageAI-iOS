import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

// Export Cloud Functions
export { processAI } from './ai/processAI';
export { handleDetectOpportunities as detectOpportunities } from './ai/proactiveAgent/index';

