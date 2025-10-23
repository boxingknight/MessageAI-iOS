/**
 * PR#20.1: Event Planning Detection
 * 
 * Detects event planning opportunities in conversations using GPT-4.
 */

import OpenAI from 'openai';
import { Opportunity, ConversationContext } from './types';
import * as functions from 'firebase-functions';

/**
 * Detect event planning opportunities
 */
export async function detectEventPlanning(
  context: ConversationContext,
  openai: OpenAI
): Promise<Opportunity | null> {
  try {
    console.log('[Event Detection] Starting detection...');
    
    // Build system prompt
    const systemPrompt = `You are an AI assistant that detects event planning opportunities in parent group chats.

Analyze the conversation and determine if parents are discussing planning an event (birthday party, playdate, school event, etc.).

Extract:
- Event title/name
- Event type (birthday party, playdate, sports practice, school event, etc.)
- Date (if mentioned)
- Time (if mentioned)
- Location (if mentioned)
- Participants (names mentioned)
- Any additional notes

Return a confidence score (0.0-1.0):
- 0.9-1.0: Explicit event planning ("Let's have Emma's birthday party Saturday")
- 0.7-0.8: Strong implicit planning ("Should we get together this weekend?")
- 0.5-0.6: Vague discussion ("Maybe we should plan something")
- <0.5: No event planning detected

Return null if confidence < 0.5.

Also avoid suggesting duplicate events. Check existing events and return null if the same event already exists.`;

    // Build user prompt
    const existingEventsStr = context.existingEvents?.length
      ? `\n\nExisting events (avoid duplicates):\n${context.existingEvents.map(e => `- ${e.title} on ${e.date}`).join('\n')}`
      : '';
    
    const userPrompt = `Conversation (${context.messageCount} messages):
${context.recentMessages}
${existingEventsStr}

Analyze this conversation for event planning opportunities.`;

    // Call GPT-4
    const response = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ],
      temperature: 0.3,
      response_format: { type: 'json_object' },
      max_tokens: 500
    });

    const result = JSON.parse(response.choices[0].message.content || '{}');
    console.log('[Event Detection] GPT-4 result:', JSON.stringify(result, null, 2));

    // Validate result
    if (!result || result.confidence < 0.5) {
      console.log('[Event Detection] Confidence too low or no event detected');
      return null;
    }

    // Build opportunity
    const opportunity: Opportunity = {
      type: 'event_planning',
      confidence: result.confidence || 0,
      data: {
        title: result.title,
        eventType: result.eventType,
        date: result.date,
        time: result.time,
        location: result.location,
        participants: result.participants || [],
        notes: result.notes
      },
      suggestedActions: buildActions(result),
      reasoning: result.reasoning || 'Event planning detected in conversation',
      timestamp: new Date()
    };

    console.log('[Event Detection] Opportunity created with confidence:', opportunity.confidence);
    return opportunity;

  } catch (error: any) {
    functions.logger.error('[Event Detection] Error:', error);
    console.error('[Event Detection] Error:', error.message);
    return null; // Fail gracefully
  }
}

/**
 * Build suggested actions based on extracted data
 */
function buildActions(result: any): string[] {
  const actions: string[] = [];
  
  if (result.confidence > 0.8) {
    actions.push('create_full_workflow'); // Full workflow (event + invites + RSVP + deadline)
    actions.push('create_event_only'); // Just create the event
  } else if (result.confidence > 0.6) {
    actions.push('ask_for_details'); // Need more information
    actions.push('create_draft'); // Create draft for review
  } else {
    actions.push('manual_planning'); // Open modal agent
  }
  
  actions.push('dismiss'); // Always allow dismissal
  
  return actions;
}

