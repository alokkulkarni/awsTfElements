import json
import os
import time
import hashlib
import boto3
from botocore.exceptions import ClientError

# Initialize clients
bedrock = boto3.client('bedrock-runtime')
lexv2 = boto3.client('lexv2-models')
dynamodb = boto3.client('dynamodb')

def handler(event, context):
    print("Received event:", json.dumps(event, indent=2))

    session_state = event.get('sessionState', {})
    intent = session_state.get('intent', {})
    intent_name = intent.get('name')
    user_message = event.get('inputTranscript', '')
    
    queue_map_str = os.environ.get('QUEUE_MAP', '{}')
    queue_map = json.loads(queue_map_str)
    faq_cache_table = os.environ.get('FAQ_CACHE_TABLE')
    
    if intent_name == "TalkToAgent":
        slots = intent.get('slots', {})
        department_slot = slots.get('Department')
        department = department_slot.get('value', {}).get('originalValue') if department_slot else None
        
        if department and department in queue_map:
            return {
                'sessionState': {
                    'dialogAction': { 'type': 'Close' },
                    'intent': { 'name': intent_name, 'state': 'Fulfilled' },
                    'sessionAttributes': {
                        'TargetQueue': department,
                        'TargetQueueArn': queue_map[department]
                    }
                },
                'messages': [{ 'contentType': 'PlainText', 'content': f"Transferring you to {department}..." }]
            }
        else:
            available_depts = ", ".join(queue_map.keys())
            return close(event, f"Sorry, I couldn't find a queue for {department}. Available departments are: {available_depts}.")

    if intent_name == "FallbackIntent":
        try:
            # 1. Check Cache
            question_hash = hashlib.sha256(user_message.lower().strip().encode('utf-8')).hexdigest()
            
            if faq_cache_table:
                try:
                    response = dynamodb.get_item(
                        TableName=faq_cache_table,
                        Key={'QuestionHash': {'S': question_hash}}
                    )
                    item = response.get('Item')
                    if item:
                        ttl = float(item.get('TTL', {}).get('N', 0))
                        if ttl > time.time():
                            print("Cache Hit! Returning cached answer.")
                            return close(event, item.get('Answer', {}).get('S'))
                except Exception as e:
                    print(f"Cache lookup failed: {e}")

            # 2. Bedrock Call
            departments = ", ".join(queue_map.keys())
            locale = os.environ.get('LOCALE', 'en_US')
            prompt = f"""You are an intelligent intent classifier for a customer service bot. 
            The available departments are: {departments}.
            The user's locale is: {locale}. Please respond appropriately for this locale.
            
            User message: "{user_message}"
            
            Instructions:
            1. If the user wants to speak to a specific department, reply with ONLY the department name (e.g., "Sales").
            2. If the user is asking a general question, reply with the answer to the question.
            """
            
            body = json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 1000,
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "text",
                                "text": prompt
                            }
                        ]
                    }
                ]
            })
            
            response = bedrock.invoke_model(
                modelId="anthropic.claude-3-haiku-20240307-v1:0",
                contentType="application/json",
                accept="application/json",
                body=body,
                guardrailIdentifier=os.environ.get('GUARDRAIL_ID'),
                guardrailVersion=os.environ.get('GUARDRAIL_VERSION'),
                trace="ENABLED"
            )
            
            response_body = json.loads(response['body'].read())
            completion = response_body['content'][0]['text'].strip()
            
            # Self-Learning Logic
            if completion in queue_map:
                print(f"Bedrock classified intent as: {completion}. Initiating self-learning...")
                
                # Update Lex (Async in Node, Sync here for simplicity or use Step Functions/SQS for true async)
                update_lex_intent(user_message, completion)
                
                return {
                    'sessionState': {
                        'dialogAction': { 'type': 'Close' },
                        'intent': { 'name': 'TalkToAgent', 'state': 'Fulfilled' },
                        'sessionAttributes': {
                            'TargetQueue': completion,
                            'TargetQueueArn': queue_map[completion]
                        }
                    },
                    'messages': [{ 'contentType': 'PlainText', 'content': f"I understand you want to speak to {completion}. Transferring you now..." }]
                }
            else:
                # General Answer - Cache it
                if faq_cache_table:
                    try:
                        ttl = int(time.time()) + (24 * 60 * 60)
                        dynamodb.put_item(
                            TableName=faq_cache_table,
                            Item={
                                'QuestionHash': {'S': question_hash},
                                'Question': {'S': user_message[:1000]},
                                'Answer': {'S': completion},
                                'TTL': {'N': str(ttl)}
                            }
                        )
                        print("Cached answer for future use.")
                    except Exception as e:
                        print(f"Cache write failed: {e}")
                
                return close(event, completion)

        except Exception as e:
            print(f"Error in Fallback/Bedrock: {e}")
            return close(event, "I'm having trouble understanding right now. Please try again.")

    return close(event, "I didn't understand that.")

def update_lex_intent(utterance, department):
    try:
        bot_id = os.environ.get('BOT_ID')
        bot_version = os.environ.get('BOT_VERSION')
        locale_id = os.environ.get('LOCALE_ID')
        intent_id = os.environ.get('INTENT_ID')
        
        # 1. Get current intent
        response = lexv2.describe_intent(
            botId=bot_id,
            botVersion=bot_version,
            localeId=locale_id,
            intentId=intent_id
        )
        
        # 2. Add utterance
        sample_utterances = response.get('sampleUtterances', [])
        sample_utterances.append({'utterance': utterance})
        
        # 3. Update Intent
        lexv2.update_intent(
            botId=bot_id,
            botVersion=bot_version,
            localeId=locale_id,
            intentId=intent_id,
            intentName=response['intentName'],
            sampleUtterances=sample_utterances,
            dialogCodeHook=response.get('dialogCodeHook'),
            fulfillmentCodeHook=response.get('fulfillmentCodeHook'),
            slotPriorities=response.get('slotPriorities'),
            intentClosingSetting=response.get('intentClosingSetting')
            # Add other fields as necessary
        )
        print(f"Successfully added utterance '{utterance}' to intent {intent_id}")
        
    except Exception as e:
        print(f"Failed to update Lex intent: {e}")

def close(event, message):
    return {
        'sessionState': {
            'dialogAction': {
                'type': 'Close',
            },
            'intent': {
                'name': event['sessionState']['intent']['name'],
                'state': 'Fulfilled',
            },
        },
        'messages': [
            {
                'contentType': 'PlainText',
                'content': message,
            },
        ],
    }
