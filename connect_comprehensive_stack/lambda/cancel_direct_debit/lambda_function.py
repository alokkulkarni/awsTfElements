import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Handles Direct Debit Cancellation.
    """
    logger.info(f"CancelDirectDebit invoked: {json.dumps(event)}")
    
    # Mock cancellation logic
    response_text = "I've successfully cancelled that direct debit for you. You will receive a confirmation text shortly."
    
    return {
        "sessionState": {
            "dialogAction": {
                "type": "Close"
            },
            "intent": {
                "name": event['sessionState']['intent']['name'],
                "state": "Fulfilled"
            }
        },
        "messages": [
            {
                "contentType": "PlainText",
                "content": response_text
            }
        ]
    }
