import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Handles Statement Generation requests.
    """
    logger.info(f"GetStatement invoked: {json.dumps(event)}")
    
    # Mock statement generation logic
    response_text = "I have generated your latest statement. It has been sent to your registered email address."
    
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
