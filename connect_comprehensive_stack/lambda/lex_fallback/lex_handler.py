import json
import logging
from utils import close_dialog, delegate_to_intent, classify_with_bedrock, log_new_intent
from validation import get_customer_identity, is_authenticated, start_verification, handle_verification
from fulfillment import handle_check_balance, handle_loan_inquiry, handle_onboarding_status

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))
    
    session_state = event.get('sessionState', {})
    intent = session_state.get('intent', {})
    session_attributes = session_state.get('sessionAttributes', {})
    input_transcript = event.get('inputTranscript', '')
    
    if not input_transcript and intent.get('name') != 'VerifyIdentity':
        return close_dialog("Failed", "I didn't catch that. Could you please repeat?", intent.get('name'))

    # 1. Identify Customer (Passive ANI Match)
    customer_id, customer_data = get_customer_identity(event)
    
    # 2. Handle Validation Logic (if in VerifyIdentity intent)
    if intent.get('name') == 'VerifyIdentity':
        return handle_verification(event, customer_data)

    # 3. Handle Fulfillment
    intent_name = intent.get('name')
    
    if intent_name == 'CheckBalance':
        # Security Check: Requires Validation (DISABLED FOR TESTING)
        # if not is_authenticated(session_attributes):
        #     return start_verification(intent_name)
        return handle_check_balance(customer_data, intent_name)
        
    elif intent_name == 'LoanInquiry':
        # Public Info: No Validation Required
        return handle_loan_inquiry(event, intent_name)
        
    elif intent_name == 'OnboardingStatus':
        # Security Check: Requires Validation (DISABLED FOR TESTING)
        # if not is_authenticated(session_attributes):
        #     return start_verification(intent_name)
        return handle_onboarding_status(event, intent_name)

    # 4. Fallback / Bedrock Classification
    try:
        classification = classify_with_bedrock(input_transcript)
        logger.info("Bedrock classification: %s", classification)
        
        predicted_intent = classification.get('intent')
        confidence = classification.get('confidence', 0)
        
        if predicted_intent == "TransferToAgent" or confidence < 0.7:
            return delegate_to_intent("TransferToAgent")
        
        if predicted_intent == "NewIntent":
            log_new_intent(input_transcript)
            return close_dialog("Fulfilled", "I'm not sure how to help with that yet, but I've noted it down. Let me connect you to someone who can help.", "FallbackIntent")

        return delegate_to_intent(predicted_intent)

    except Exception as e:
        logger.error("Error calling Bedrock: %s", str(e))
        return delegate_to_intent("TransferToAgent")

