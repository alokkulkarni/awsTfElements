import boto3
import os
import time
import logging

logger = logging.getLogger()
dynamodb = boto3.client('dynamodb')
TABLE_NAME = os.environ.get('INTENT_TABLE_NAME')

def close_dialog(fulfillment_state, message, intent_name):
    return {
        "sessionState": {
            "dialogAction": {
                "type": "Close"
            },
            "intent": {
                "name": intent_name,
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

def elicit_slot(intent_name, slot_name, message):
    return {
        "sessionState": {
            "dialogAction": {
                "type": "ElicitSlot",
                "slotToElicit": slot_name
            },
            "intent": {
                "name": intent_name,
                "state": "InProgress"
            }
        },
        "messages": [
            {
                "contentType": "PlainText",
                "content": message
            }
        ]
    }

def log_new_intent(text):
    if TABLE_NAME:
        try:
            dynamodb.put_item(
                TableName=TABLE_NAME,
                Item={
                    'utterance': {'S': text},
                    'timestamp': {'S': str(int(time.time()))}
                }
            )
        except Exception as e:
            logger.error(f"Error logging intent: {e}")

def classify_with_bedrock(text):
    # Mock response for now, can be replaced with actual Bedrock call
    # bedrock = boto3.client('bedrock-runtime')
    return {"intent": "TransferToAgent", "confidence": 0.9}
