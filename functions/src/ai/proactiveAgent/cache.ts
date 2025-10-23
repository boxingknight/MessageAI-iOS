/**
 * PR#20.1: Caching Layer
 * 
 * Implements caching for detection results to reduce API costs.
 * Cache TTL: 5 minutes (300 seconds)
 */

import { getFirestore } from 'firebase-admin/firestore';
import { DetectionResponse, CacheEntry } from './types';
import * as crypto from 'crypto';

const CACHE_TTL = 300; // 5 minutes in seconds
const CACHE_COLLECTION = 'opportunityCache';

/**
 * Generate hash from message IDs for cache key
 */
export function hashMessages(messageIds: string[]): string {
  const content = messageIds.join('-');
  return crypto.createHash('md5').update(content).digest('hex');
}

/**
 * Get cached detection result
 */
export async function getCache(
  conversationId: string,
  messageHash: string
): Promise<DetectionResponse | null> {
  try {
    const db = getFirestore();
    const cacheKey = `${conversationId}-${messageHash}`;
    
    const doc = await db.collection(CACHE_COLLECTION).doc(cacheKey).get();
    
    if (!doc.exists) {
      console.log('[Cache] Miss - no cached data');
      return null;
    }
    
    const data = doc.data() as CacheEntry;
    
    // Check if cache is still valid (within TTL)
    const age = (Date.now() - data.timestamp.getTime()) / 1000; // seconds
    if (age > CACHE_TTL) {
      console.log(`[Cache] Expired - age: ${age}s > TTL: ${CACHE_TTL}s`);
      // Delete expired cache
      await db.collection(CACHE_COLLECTION).doc(cacheKey).delete();
      return null;
    }
    
    console.log(`[Cache] Hit - age: ${age}s, ${data.data.opportunities.length} opportunities`);
    return data.data;
    
  } catch (error: any) {
    console.error('[Cache] Error getting cache:', error.message);
    return null; // Fail gracefully
  }
}

/**
 * Set cache with detection result
 */
export async function setCache(
  conversationId: string,
  messageHash: string,
  data: DetectionResponse
): Promise<void> {
  try {
    const db = getFirestore();
    const cacheKey = `${conversationId}-${messageHash}`;
    
    const cacheEntry: CacheEntry = {
      data,
      timestamp: new Date(),
      conversationHash: messageHash
    };
    
    await db.collection(CACHE_COLLECTION).doc(cacheKey).set(cacheEntry);
    console.log(`[Cache] Set - ${data.opportunities.length} opportunities cached`);
    
  } catch (error: any) {
    console.error('[Cache] Error setting cache:', error.message);
    // Don't throw - caching is optional
  }
}

/**
 * Clear all expired cache entries (cleanup)
 */
export async function clearExpiredCache(): Promise<void> {
  try {
    const db = getFirestore();
    const cutoff = new Date(Date.now() - (CACHE_TTL * 1000));
    
    const snapshot = await db.collection(CACHE_COLLECTION)
      .where('timestamp', '<', cutoff)
      .limit(100)
      .get();
    
    if (snapshot.empty) {
      console.log('[Cache] No expired entries to clear');
      return;
    }
    
    const batch = db.batch();
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`[Cache] Cleared ${snapshot.size} expired entries`);
    
  } catch (error: any) {
    console.error('[Cache] Error clearing expired cache:', error.message);
  }
}

