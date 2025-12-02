import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

bedrock = boto3.client('bedrock-runtime')
dynamodb = boto3.client('dynamodb')

TABLE_NAME = os.environ.get('INTENT_TABLE_NAME')

def lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))
    
    session_state = event.get('sessionState', {})
    intent = session_state.get('intent', {})
    input_transcript = event.get('inputTranscript', '')
    
    if not input_transcript:
        return close_dialog("Failed", "I didn't catch that. Could you please repeat?")

    # Call Bedrock to classify
    try:
        classification = classify_with_bedrock(input_transcript)
        logger.info("Bedrock classification: %s", classification)
        
        predicted_intent = classification.get('intent')
        confidence = classification.get('confidence', 0)
        
        if predicted_intent == "TransferToAgent" or confidence < 0.7:
            # Fallback to human agent
            return delegate_to_intent("TransferToAgent")
        
        if predicted_intent == "NewIntent":
            # Log new intent candidate
            log_new_intent(input_transcript)
            return close_dialog("Fulfilled", "I'm not sure how to help with that yet, but I've noted it down. Let me connect you to someone who can help.")

        # If mapped to existing intent
        return delegate_to_intent(predicted_intent)

    except Exception as e:
        logger.error("Error calling Bedrock: %s", str(e))
        return delegate_to_intent("TransferToAgent")

def classify_with_bedrock(text):
    # Placeholder for Bedrock invocation
    # In a real scenario, you'd construct a prompt for Claude/Titan
    prompt = f"""
    Classify the following text into an intent:
    Text: "{text}"
    Intents: CheckBalance, BookFlight, TransferToAgent
    Return JSON with 'intent' and 'confidence'.
    """
    
    body = json.dumps({
        "prompt": prompt,
        "max_tokens_to_sample": 200,
        "temperature": 0.1
    })
    
    # Mock response for now as we don't have a real model ID in this context
    # response = bedrock.invoke_model(body=body, modelId='anthropic.claude-v2', accept='application/json', contentType='application/json')
    # response_body = json.loads(response.get('body').read())
    # return json.loads(response_body.get('completion'))
    
    return {"intent": "TransferToAgent", "confidence": 0.9}

def log_new_intent(text):
    if TABLE_NAME:
        dynamodb.put_item(
            TableName=TABLE_NAME,
            Item={
                'utterance': {'S': text},
                'timestamp': {'S': str(context.aws_request_id)} # simplified
            }
        )

def close_dialog(fulfillment_state, message):
    return {
        "sessionState": {
            "dialogAction": {
                "type": "Close"
            },
            "intent": {
                "name": "FallbackIntent",
                "state": fulfillment_state
            }
        },
        "messages": [
            {
                "contentType": "PlainText",
                "content": message
            }
        ]
    }

def delegate_to_intent(intent_name):
    return {
        "sessionState": {
            "dialogAction": {
                "type": "Delegate"
            },
            "intent": {
                "name": intent_name,
                "state": "ReadyForFulfillment"
            }
        }
    }
