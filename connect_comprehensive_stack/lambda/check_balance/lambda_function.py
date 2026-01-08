import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Handles Balance Check requests.
    In a real scenario, this would query a database backend.
    """
    logger.info(f"CheckBalance invoked: {json.dumps(event)}")
    
    # Mock balance response
    # In reality, you'd extract customer_id from sessionAttributes or request attributes
    balance = 1250.50
    currency = "GBP"
    
    response_text = f"The current balance on your account is {currency} {balance}."
    
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
