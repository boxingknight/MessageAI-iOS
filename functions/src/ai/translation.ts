import * as functions from 'firebase-functions';
import { OpenAI } from 'openai';

// Initialize OpenAI (get API key from Firebase config)
const openai = new OpenAI({
  apiKey: functions.config().openai.key,
});

/**
 * Supported languages for translation
 */
export const SUPPORTED_LANGUAGES = {
  'en': 'English',
  'es': 'Spanish', 
  'fr': 'French',
  'de': 'German',
  'it': 'Italian',
  'pt': 'Portuguese',
  'ru': 'Russian',
  'ja': 'Japanese',
  'ko': 'Korean',
  'zh': 'Chinese (Simplified)',
  'ar': 'Arabic',
  'hi': 'Hindi',
  'nl': 'Dutch',
  'sv': 'Swedish',
  'no': 'Norwegian',
  'da': 'Danish',
  'fi': 'Finnish',
  'pl': 'Polish'
} as const;

export type LanguageCode = keyof typeof SUPPORTED_LANGUAGES;

/**
 * Translation request data structure
 */
interface TranslationRequest {
  messageText: string;
  targetLanguage: LanguageCode;
  sourceLanguage?: LanguageCode; // Optional, will auto-detect if not provided
  conversationId: string;
  messageId: string;
  preserveFormatting?: boolean;
}

/**
 * Translation response structure
 */
interface TranslationResponse {
  translatedText: string;
  detectedSourceLanguage: LanguageCode;
  targetLanguage: LanguageCode;
  confidence: number;
  translationMethod: 'gpt-4' | 'cached';
  processingTimeMs: number;
  tokensUsed: number;
  cost: number;
}

/**
 * Cache for translation results (in-memory, per function instance)
 * Key: hash of (sourceText + targetLanguage)
 * Value: translation result with timestamp
 */
const translationCache = new Map<string, {
  result: TranslationResponse;
  timestamp: number;
}>();

const CACHE_DURATION_MS = 24 * 60 * 60 * 1000; // 24 hours

/**
 * Generate cache key for translation
 */
function getCacheKey(text: string, targetLang: LanguageCode): string {
  // Simple hash for caching (first 100 chars + target language)
  return `${text.substring(0, 100).toLowerCase()}_${targetLang}`;
}

/**
 * Detect language of given text using GPT-4
 */
async function detectLanguage(text: string): Promise<{
  language: LanguageCode;
  confidence: number;
  tokensUsed: number;
}> {
  const startTime = Date.now();
  
  try {
    const completion = await openai.chat.completions.create({
      model: 'gpt-4',
      messages: [
        {
          role: 'system',
          content: `You are a language detection expert. Analyze the given text and return the language code.
          
Supported languages: ${Object.entries(SUPPORTED_LANGUAGES).map(([code, name]) => `${code} (${name})`).join(', ')}

Respond with ONLY a JSON object in this exact format:
{
  "language": "en",
  "confidence": 0.95
}

Where confidence is between 0.0 and 1.0 representing your certainty.`
        },
        {
          role: 'user',
          content: `Detect the language of this text: "${text}"`
        }
      ],
      max_tokens: 50,
      temperature: 0.1
    });

    const response = completion.choices[0].message.content?.trim();
    if (!response) {
      throw new Error('No response from GPT-4 language detection');
    }

    try {
      const parsed = JSON.parse(response);
      const languageCode = parsed.language as LanguageCode;
      const confidence = Math.min(Math.max(parsed.confidence || 0.5, 0.0), 1.0);

      // Validate language code
      if (!SUPPORTED_LANGUAGES[languageCode]) {
        functions.logger.warn('Unsupported language detected, defaulting to English', {
          detectedLanguage: languageCode,
          originalText: text.substring(0, 50)
        });
        return { language: 'en', confidence: 0.5, tokensUsed: completion.usage?.total_tokens || 0 };
      }

      functions.logger.info('Language detected successfully', {
        language: languageCode,
        confidence,
        processingTimeMs: Date.now() - startTime
      });

      return {
        language: languageCode,
        confidence,
        tokensUsed: completion.usage?.total_tokens || 0
      };

    } catch (parseError) {
      functions.logger.error('Failed to parse language detection response', {
        response,
        error: parseError
      });
      return { language: 'en', confidence: 0.5, tokensUsed: completion.usage?.total_tokens || 0 };
    }

  } catch (error: any) {
    functions.logger.error('Language detection failed', {
      error: error.message,
      text: text.substring(0, 50)
    });
    return { language: 'en', confidence: 0.5, tokensUsed: 0 };
  }
}

/**
 * Translate text using GPT-4
 */
async function translateWithGPT4(
  text: string,
  sourceLanguage: LanguageCode,
  targetLanguage: LanguageCode,
  preserveFormatting: boolean = true
): Promise<{
  translatedText: string;
  tokensUsed: number;
}> {
  const startTime = Date.now();
  
  try {
    const sourceLangName = SUPPORTED_LANGUAGES[sourceLanguage];
    const targetLangName = SUPPORTED_LANGUAGES[targetLanguage];

    const systemPrompt = `You are a professional translator. Translate the given text from ${sourceLangName} to ${targetLangName}.

IMPORTANT RULES:
1. Maintain the original tone and style (casual, formal, emotional, etc.)
2. Preserve any emojis, symbols, or special characters exactly as they are
3. ${preserveFormatting ? 'Preserve line breaks, spacing, and formatting' : 'Output clean, natural text'}
4. If the text contains names, dates, or proper nouns, keep them unchanged unless translation is needed for clarity
5. For messaging context: maintain the conversational, natural feel
6. If the text is already in the target language, return it unchanged
7. Respond with ONLY the translated text, no explanations or meta-commentary

Examples:
- "Hello! 😊 How are you?" → "¡Hola! 😊 ¿Cómo estás?" (Spanish)
- "Meeting at 3pm tomorrow" → "Reunión a las 3pm mañana" (Spanish)
- "Can you pick up Emma from school?" → "¿Puedes recoger a Emma de la escuela?" (Spanish)`;

    const completion = await openai.chat.completions.create({
      model: 'gpt-4',
      messages: [
        {
          role: 'system',
          content: systemPrompt
        },
        {
          role: 'user',
          content: text
        }
      ],
      max_tokens: Math.max(Math.ceil(text.length * 1.5), 100),
      temperature: 0.3 // Low temperature for consistent translations
    });

    const translatedText = completion.choices[0].message.content?.trim();
    if (!translatedText) {
      throw new Error('No translation received from GPT-4');
    }

    functions.logger.info('Translation completed successfully', {
      sourceLanguage,
      targetLanguage,
      originalLength: text.length,
      translatedLength: translatedText.length,
      processingTimeMs: Date.now() - startTime,
      tokensUsed: completion.usage?.total_tokens || 0
    });

    return {
      translatedText,
      tokensUsed: completion.usage?.total_tokens || 0
    };

  } catch (error: any) {
    functions.logger.error('Translation with GPT-4 failed', {
      error: error.message,
      sourceLanguage,
      targetLanguage,
      textLength: text.length
    });
    throw error;
  }
}

/**
 * Main translation function
 * Called by processAI router with 'translation' feature
 */
export async function translateMessage(data: any): Promise<TranslationResponse> {
  const startTime = Date.now();
  
  try {
    // Extract and validate request data
    const {
      messageText,
      targetLanguage,
      sourceLanguage,
      conversationId,
      messageId,
      preserveFormatting = true
    } = data as TranslationRequest;

    // Validate inputs
    if (!messageText || typeof messageText !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'messageText is required and must be a string'
      );
    }

    if (!targetLanguage || !SUPPORTED_LANGUAGES[targetLanguage]) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `targetLanguage must be one of: ${Object.keys(SUPPORTED_LANGUAGES).join(', ')}`
      );
    }

    if (messageText.trim().length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'messageText cannot be empty'
      );
    }

    if (messageText.length > 2000) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'messageText too long (max 2000 characters)'
      );
    }

    functions.logger.info('Translation request received', {
      conversationId,
      messageId,
      targetLanguage,
      sourceLanguage: sourceLanguage || 'auto-detect',
      textLength: messageText.length,
      preserveFormatting
    });

    // Check cache first
    const cacheKey = getCacheKey(messageText, targetLanguage);
    const cached = translationCache.get(cacheKey);
    
    if (cached && (Date.now() - cached.timestamp) < CACHE_DURATION_MS) {
      functions.logger.info('Translation cache hit', {
        cacheKey: cacheKey.substring(0, 50),
        cacheAge: Date.now() - cached.timestamp
      });
      
      return {
        ...cached.result,
        translationMethod: 'cached',
        processingTimeMs: Date.now() - startTime
      };
    }

    let detectedSourceLanguage: LanguageCode;
    let totalTokensUsed = 0;
    let detectionConfidence = 1.0;

    // Step 1: Detect source language if not provided
    if (!sourceLanguage) {
      const detection = await detectLanguage(messageText);
      detectedSourceLanguage = detection.language;
      detectionConfidence = detection.confidence;
      totalTokensUsed += detection.tokensUsed;

      functions.logger.info('Source language detected', {
        detectedLanguage: detectedSourceLanguage,
        confidence: detectionConfidence
      });
    } else {
      detectedSourceLanguage = sourceLanguage;
    }

    // Step 2: Check if translation is needed
    if (detectedSourceLanguage === targetLanguage) {
      functions.logger.info('No translation needed - same language', {
        language: detectedSourceLanguage
      });
      
      const response: TranslationResponse = {
        translatedText: messageText,
        detectedSourceLanguage,
        targetLanguage,
        confidence: 1.0,
        translationMethod: 'cached',
        processingTimeMs: Date.now() - startTime,
        tokensUsed: totalTokensUsed,
        cost: totalTokensUsed * 0.00003 // Rough GPT-4 cost estimate
      };

      return response;
    }

    // Step 3: Translate with GPT-4
    const translation = await translateWithGPT4(
      messageText,
      detectedSourceLanguage,
      targetLanguage,
      preserveFormatting
    );

    totalTokensUsed += translation.tokensUsed;

    // Step 4: Build response
    const response: TranslationResponse = {
      translatedText: translation.translatedText,
      detectedSourceLanguage,
      targetLanguage,
      confidence: detectionConfidence,
      translationMethod: 'gpt-4',
      processingTimeMs: Date.now() - startTime,
      tokensUsed: totalTokensUsed,
      cost: totalTokensUsed * 0.00003 // Rough GPT-4 cost estimate ($0.03 per 1K tokens)
    };

    // Step 5: Cache the result
    translationCache.set(cacheKey, {
      result: response,
      timestamp: Date.now()
    });

    // Clean up old cache entries (simple cleanup)
    if (translationCache.size > 1000) {
      const now = Date.now();
      for (const [key, value] of translationCache.entries()) {
        if (now - value.timestamp > CACHE_DURATION_MS) {
          translationCache.delete(key);
        }
      }
    }

    functions.logger.info('Translation completed successfully', {
      conversationId,
      sourceLanguage: detectedSourceLanguage,
      targetLanguage,
      confidence: detectionConfidence,
      tokensUsed: totalTokensUsed,
      processingTimeMs: response.processingTimeMs,
      cost: response.cost
    });

    return response;

  } catch (error: any) {
    const processingTime = Date.now() - startTime;
    
    functions.logger.error('Translation failed', {
      error: error.message,
      processingTimeMs: processingTime,
      conversationId: data.conversationId,
      targetLanguage: data.targetLanguage
    });

    // Re-throw HttpsError as-is
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    // Handle OpenAI API errors
    if (error.type === 'insufficient_quota') {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Translation service temporarily unavailable. Please try again later.'
      );
    }

    if (error.type === 'rate_limit_exceeded') {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Too many translation requests. Please try again in a moment.'
      );
    }

    // Generic error
    throw new functions.https.HttpsError(
      'internal',
      'Translation failed. Please try again.'
    );
  }
}

/**
 * Get list of supported languages
 */
export function getSupportedLanguages(): typeof SUPPORTED_LANGUAGES {
  return SUPPORTED_LANGUAGES;
}

/**
 * Clear translation cache (for testing/maintenance)
 */
export function clearTranslationCache(): void {
  translationCache.clear();
  functions.logger.info('Translation cache cleared');
}
