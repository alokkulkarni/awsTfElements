import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Specialized Banking Bot Handler
    Handles: CheckBalance, TransferMoney
    """
    logger.info("Banking Agent received event: %s", json.dumps(event))
    
    intent_name = event['sessionState']['intent']['name']
    
    if intent_name == 'CheckBalance':
        # Simple deterministic logic
        message = "Your checking account balance is $4,500.25 and your savings balance is $12,000.00."
        
    elif intent_name == 'TransferMoney':
        message = "I can help with transfers. Please log in to the mobile app for security."
        
    elif intent_name == 'GetStatement':
        message = "I've generated your latest statement. It will be sent to your registered email address within 5 minutes."

    elif intent_name == 'CancelDirectDebit':
        message = "I can help you cancel a Direct Debit. Which payee would you like to update?"

    elif intent_name == 'CancelStandingOrder':
        message = "To cancel a standing order, please specify the recipient and the amount."

    else:
        message = "I am the Banking Assistant. I can check your balance or discuss transfers."

    response = {
        "sessionState": {
            "dialogAction": {
                "type": "Close"
            },
            "intent": {
                "name": intent_name,
                "state": "Fulfilled"
            },
            "sessionAttributes": {
                "last_action": intent_name,
                "bot_source": "BankingBot",
                "status": "success"
            }
        },
        "messages": [
            {
                "contentType": "PlainText",
                "content": message
            }
        ]
    }
    
    return response
