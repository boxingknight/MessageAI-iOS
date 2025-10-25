import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { detectPriority } from './priorityDetection';

const db = admin.firestore();

/**
 * Firestore trigger: Auto-detect priority when messages are created
 * 
 * This ensures all users see the same priority highlighting by processing
 * priority detection server-side when the message is first created.
 * 
 * Triggered on: conversations/{conversationId}/messages/{messageId} onCreate
 */
export const onMessageCreated = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const { conversationId, messageId } = context.params;
    const messageData = snapshot.data();
    
    // Skip if message doesn't have text content
    if (!messageData.text || typeof messageData.text !== 'string') {
      console.log(`[MessageTrigger] Skipping message ${messageId} - no text content`);
      return;
    }
    
    // Skip if aiMetadata.priorityLevel already exists (avoid duplicate processing)
    if (messageData.aiMetadata?.priorityLevel) {
      console.log(`[MessageTrigger] Skipping message ${messageId} - priority already detected`);
      return;
    }
    
    console.log(`[MessageTrigger] Auto-detecting priority for message ${messageId} in conversation ${conversationId}`);
    
    try {
      // Call the existing priority detection logic
      const priorityResult = await detectPriority({
        messageText: messageData.text,
        conversationId: conversationId
      });
      
      console.log(`[MessageTrigger] Priority detected: ${priorityResult.level} (confidence: ${priorityResult.confidence})`);
      
      // Update the message document with priority metadata
      const aiMetadata = {
        ...messageData.aiMetadata,
        priorityLevel: priorityResult.level,
        priorityConfidence: priorityResult.confidence,
        priorityMethod: priorityResult.method,
        priorityKeywords: priorityResult.keywords || [],
        priorityReasoning: priorityResult.reasoning,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        processingTimeMs: priorityResult.processingTimeMs,
        usedGPT4: priorityResult.usedGPT4
      };
      
      // Update the message document
      await snapshot.ref.update({
        aiMetadata: aiMetadata
      });
      
      console.log(`[MessageTrigger] ✅ Updated message ${messageId} with priority: ${priorityResult.level}`);
      
    } catch (error) {
      console.error(`[MessageTrigger] ❌ Failed to detect priority for message ${messageId}:`, error);
      
      // Don't throw - we don't want to fail message creation if priority detection fails
      // Just log the error and continue
    }
  });
