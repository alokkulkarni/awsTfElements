import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Handles Standing Order Cancellation.
    """
    logger.info(f"CancelStandingOrder invoked: {json.dumps(event)}")
    
    # Mock cancellation logic
    response_text = "Your standing order has been cancelled as requested. No further payments will be taken."
    
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
