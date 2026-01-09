import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Specialized Sales Bot Handler
    Handles: ProductInfo, Pricing
    """
    logger.info("Sales Agent received event: %s", json.dumps(event))
    
    intent_name = event.get('sessionState', {}).get('intent', {}).get('name', 'Unknown')
    
    if intent_name == 'ProductInfo':
        # Enhanced to cover products previously discussed in Bedrock
        message = "We offer a range of products including our Platinum Rewards credit card, everyday Debit Cards, and High-Yield Savings accounts. Which would you like to hear more about?"
        
    elif intent_name == 'Pricing':
        message = "Our Platinum card has a $95 annual fee. Standard Debit Cards are free. Savings accounts have no monthly fees with a minimum balance of $500."
        
    else:
        message = "I am the Sales Assistant. Ask me about our credit card products."

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
                "bot_source": "SalesBot",
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
