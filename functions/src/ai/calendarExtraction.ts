import * as functions from 'firebase-functions';
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
 * Calendar event extracted from message
 */
interface CalendarEvent {
  id: string;
  title: string;
  date: string; // ISO 8601 date
  time?: string; // ISO 8601 time (optional for all-day events)
  endTime?: string; // ISO 8601 time (optional)
  location?: string;
  isAllDay: boolean;
  confidence: 'high' | 'medium' | 'low';
  rawText: string; // Original message text
}

/**
 * Extract calendar dates from messages (PR #15)
 * Uses GPT-4 function calling to detect and parse calendar events
 * 
 * @param data - Request data with message
 * @returns Extracted calendar events with confidence scores
 */
export async function extractCalendarDates(data: any): Promise<any> {
  const { message } = data;
  
  if (!message || typeof message !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Message text is required for calendar extraction.'
    );
  }
  
  functions.logger.info('Extracting calendar events from message', {
    messageLength: message.length,
    preview: message.substring(0, 100)
  });
  
  try {
    // Get OpenAI client (lazy initialization)
    const openai = getOpenAIClient();
    
    // Call OpenAI GPT-4 with function calling
    const completion = await openai.chat.completions.create({
      model: 'gpt-4',
      messages: [
        {
          role: 'system',
          content: `You are a calendar event extraction assistant for a messaging app used by busy parents.
Your job is to detect calendar events (dates, times, locations) in messages and extract structured data.

RULES:
1. Extract ALL calendar-related information (dates, times, locations, event descriptions)
2. For relative dates like "Thursday", "tomorrow", "next week", calculate the actual date based on today being ${new Date().toISOString().split('T')[0]}
3. For times without AM/PM, use context clues (4pm vs 4am for "4 o'clock")
4. Mark events as "high" confidence if date AND time are explicit (e.g., "Thursday at 4pm")
5. Mark as "medium" if date is clear but time is vague or missing
6. Mark as "low" if date is ambiguous (e.g., "sometime next week")
7. **CRITICAL**: Set isAllDay to FALSE if a specific time is mentioned (e.g., "at 4pm", "3:00"). Only set isAllDay to TRUE if NO specific time is mentioned.
8. Extract location if mentioned (e.g., "at the park", "Main Street")
9. Create descriptive titles (e.g., "Soccer practice" not just "practice")
10. Return empty array if no calendar events detected

Today's date: ${new Date().toISOString().split('T')[0]}
Current time: ${new Date().toISOString()}`
        },
        {
          role: 'user',
          content: message
        }
      ],
      functions: [
        {
          name: 'extract_calendar_events',
          description: 'Extract calendar events (dates, times, locations) from a message',
          parameters: {
            type: 'object',
            properties: {
              events: {
                type: 'array',
                description: 'List of calendar events found in the message',
                items: {
                  type: 'object',
                  properties: {
                    title: {
                      type: 'string',
                      description: 'Event title/description (e.g., "Soccer practice")'
                    },
                    date: {
                      type: 'string',
                      description: 'Event date in ISO 8601 format (YYYY-MM-DD)'
                    },
                    time: {
                      type: 'string',
                      description: 'Event start time in ISO 8601 format (HH:MM:SS), null for all-day events'
                    },
                    endTime: {
                      type: 'string',
                      description: 'Event end time in ISO 8601 format (HH:MM:SS), optional'
                    },
                    location: {
                      type: 'string',
                      description: 'Event location if mentioned, optional'
                    },
                    isAllDay: {
                      type: 'boolean',
                      description: 'True if no specific time mentioned (all-day event)'
                    },
                    confidence: {
                      type: 'string',
                      enum: ['high', 'medium', 'low'],
                      description: 'Confidence level: high (date+time explicit), medium (date clear, time vague), low (ambiguous)'
                    }
                  },
                  required: ['title', 'date', 'isAllDay', 'confidence']
                }
              },
              hasCalendarInfo: {
                type: 'boolean',
                description: 'True if message contains calendar-related information'
              }
            },
            required: ['events', 'hasCalendarInfo']
          }
        }
      ],
      function_call: { name: 'extract_calendar_events' },
      temperature: 0.3, // Lower temperature for more consistent extraction
    });
    
    // Parse function call response
    const functionCall = completion.choices[0]?.message?.function_call;
    
    if (!functionCall || functionCall.name !== 'extract_calendar_events') {
      functions.logger.warn('No function call in GPT-4 response');
      return {
        events: [],
        hasCalendarInfo: false,
        message: 'No calendar events detected'
      };
    }
    
    const result = JSON.parse(functionCall.arguments);
    
    // Add IDs and raw text to events
    const eventsWithIds: CalendarEvent[] = result.events.map((event: any) => {
      // Fix: If time is provided, it's NOT an all-day event
      const hasTime = event.time && event.time !== 'null' && event.time.trim() !== '';
      const isAllDay = hasTime ? false : event.isAllDay;
      
      return {
        id: generateEventId(),
        title: event.title,
        date: event.date,
        time: hasTime ? event.time : null,
        endTime: event.endTime || null,
        location: event.location || null,
        isAllDay: isAllDay,
        confidence: event.confidence,
        rawText: message
      };
    });
    
    functions.logger.info('Calendar extraction successful', {
      eventCount: eventsWithIds.length,
      hasCalendarInfo: result.hasCalendarInfo,
      confidenceLevels: eventsWithIds.map(e => e.confidence)
    });
    
    return {
      events: eventsWithIds,
      hasCalendarInfo: result.hasCalendarInfo,
      message: eventsWithIds.length > 0 
        ? `Found ${eventsWithIds.length} calendar event${eventsWithIds.length > 1 ? 's' : ''}`
        : 'No calendar events detected'
    };
    
  } catch (error: any) {
    functions.logger.error('Calendar extraction failed', {
      error: error.message,
      stack: error.stack
    });
    
    // Return graceful fallback instead of throwing
    return {
      events: [],
      hasCalendarInfo: false,
      error: 'Failed to extract calendar events. Please try again.',
      message: 'Calendar extraction failed'
    };
  }
}

/**
 * Generate unique event ID
 */
function generateEventId(): string {
  return `evt_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
}
