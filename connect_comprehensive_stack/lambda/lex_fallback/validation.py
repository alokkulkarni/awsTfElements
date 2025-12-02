import os
import json
import logging
import boto3
import uuid
import time
import urllib.request
import urllib.error
from utils import elicit_slot, close_dialog

logger = logging.getLogger()

ENABLE_VOICE_ID = os.environ.get('ENABLE_VOICE_ID', 'false').lower() == 'true'
ENABLE_PIN_VALIDATION = os.environ.get('ENABLE_PIN_VALIDATION', 'false').lower() == 'true'
ENABLE_COMPANION_AUTH = os.environ.get('ENABLE_COMPANION_AUTH', 'false').lower() == 'true'

AUTH_TABLE_NAME = os.environ.get('AUTH_STATE_TABLE_NAME')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
CRM_API_ENDPOINT = os.environ.get('CRM_API_ENDPOINT')
CRM_API_KEY = os.environ.get('CRM_API_KEY')

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')
auth_table = dynamodb.Table(AUTH_TABLE_NAME) if AUTH_TABLE_NAME else None

def get_customer_from_crm(phone_number):
    """Calls the external CRM API to fetch customer details."""
    if not CRM_API_ENDPOINT:
        logger.error("CRM_API_ENDPOINT not set")
        return None

    url = f"{CRM_API_ENDPOINT}?phoneNumber={phone_number}"
    req = urllib.request.Request(url)
    if CRM_API_KEY:
        req.add_header('x-api-key', CRM_API_KEY)
    
    try:
        with urllib.request.urlopen(req) as response:
            if response.status == 200:
                data = json.loads(response.read().decode())
                logger.info(f"CRM Lookup successful for {phone_number}")
                return data
            else:
                logger.warning(f"CRM Lookup failed: {response.status}")
                return None
    except urllib.error.HTTPError as e:
        if e.code == 404:
            logger.info(f"Customer not found in CRM: {phone_number}")
        else:
            logger.error(f"CRM API Error: {e}")
        return None
    except Exception as e:
        logger.error(f"CRM Connection Error: {e}")
        return None

def initiate_companion_auth(user_id):
    """Creates an auth request and sends a push notification."""
    request_id = str(uuid.uuid4())
    try:
        auth_table.put_item(Item={
            'request_id': request_id,
            'user_id': user_id,
            'status': 'PENDING',
            'created_at': int(time.time()),
            'ttl': int(time.time()) + 300
        })
        
        message = {
            "request_id": request_id,
            "user_id": user_id,
            "message": "Please approve the transaction."
        }
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=json.dumps(message),
            Subject="Auth Request"
        )
        return request_id
    except Exception as e:
        logger.error(f"Error initiating auth: {e}")
        return None

def check_companion_auth_status(request_id):
    """Checks the status of the auth request."""
    try:
        resp = auth_table.get_item(Key={'request_id': request_id})
        item = resp.get('Item')
        if not item:
            return 'UNKNOWN'
        return item.get('status', 'PENDING')
    except Exception as e:
        logger.error(f"Error checking auth status: {e}")
        return 'ERROR'

def get_customer_identity(event):
    """Extracts ANI and looks up customer in CRM API."""
    session_attributes = event.get('sessionState', {}).get('sessionAttributes', {})
    phone_number = session_attributes.get('PhoneNumber') or session_attributes.get('x-amz-lex:phoneNumber')
    
    if not phone_number:
        # Fallback for testing if not connected to telephony
        phone_number = "+15550100" 
    
    customer = get_customer_from_crm(phone_number)
    return phone_number, customer

def is_authenticated(session_attributes):
    """Checks if the user has already passed validation."""
    return session_attributes.get('isAuthenticated') == 'true'

def start_verification(original_intent, customer_id=None):
    """Initiates the verification flow."""
    session_attributes = {"originalIntent": original_intent}
    
    if ENABLE_COMPANION_AUTH and customer_id:
        req_id = initiate_companion_auth(customer_id)
        if req_id:
            session_attributes['auth_request_id'] = req_id
            return {
                "sessionState": {
                    "dialogAction": {
                        "type": "ElicitSlot",
                        "slotToElicit": "PIN" # Reusing PIN slot as a dummy wait mechanism
                    },
                    "intent": {
                        "name": "VerifyIdentity",
                        "state": "InProgress"
                    },
                    "sessionAttributes": session_attributes
                },
                "messages": [
                    {
                        "contentType": "PlainText",
                        "content": "I've sent a request to your mobile app. Please approve it to continue."
                    }
                ]
            }

    return {
        "sessionState": {
            "dialogAction": {
                "type": "ElicitSlot",
                "slotToElicit": "PIN"
            },
            "intent": {
                "name": "VerifyIdentity",
                "state": "InProgress"
            },
            "sessionAttributes": session_attributes
        },
        "messages": [
            {
                "contentType": "PlainText",
                "content": "For security, I need to verify your identity. Please say your 4-digit PIN."
            }
        ]
    }

def handle_verification(event, customer_data):
    """Validates the PIN provided by the user."""
    session_attributes = event.get('sessionState', {}).get('sessionAttributes', {})
    auth_req_id = session_attributes.get('auth_request_id')

    # 3. Companion App Auth Check
    if ENABLE_COMPANION_AUTH and auth_req_id:
        # Polling loop (Simple implementation for demo)
        # In production, consider using Connect Loop or longer timeouts
        for _ in range(4): # Poll for ~8 seconds
            status = check_companion_auth_status(auth_req_id)
            if status == 'APPROVED':
                return complete_verification(event, True)
            elif status == 'DECLINED':
                 return close_dialog("Failed", "Unable to process req.", "VerifyIdentity")
            time.sleep(2)
        
        # If still pending, prompt again (keeps session alive)
        return elicit_slot("VerifyIdentity", "PIN", "I'm still waiting for approval from your app.")

    slots = event['sessionState']['intent']['slots']
    pin_slot = slots.get('PIN')
    
    if not pin_slot:
        return elicit_slot("VerifyIdentity", "PIN", "Please say your 4-digit PIN.")
        
    user_pin = pin_slot.get('value', {}).get('interpretedValue')
    
    # 1. Voice ID Check (Biometric)
    if ENABLE_VOICE_ID:
        voice_status = session_attributes.get('VoiceIdStatus') # AUTHENTICATED, OPT_OUT, etc.
        if voice_status == 'AUTHENTICATED':
            return complete_verification(event, True)

    # 2. PIN Check (Knowledge)
    if ENABLE_PIN_VALIDATION:
        if customer_data and customer_data.get('pin') == user_pin:
            return complete_verification(event, True)
        else:
            # Failed PIN
            return close_dialog("Failed", "That PIN was incorrect. I cannot proceed with your request.", "VerifyIdentity")
            
    # If no validation enabled but we are here, just pass (insecure mode)
    return complete_verification(event, True)

def complete_verification(event, success):
    session_attributes = event.get('sessionState', {}).get('sessionAttributes', {})
    original_intent = session_attributes.get('originalIntent', 'CheckBalance')
    
    session_attributes['isAuthenticated'] = 'true'
    
    # Return to the original intent
    return {
        "sessionState": {
            "dialogAction": {
                "type": "Delegate"
            },
            "intent": {
                "name": original_intent,
                "state": "ReadyForFulfillment"
            },
            "sessionAttributes": session_attributes
        },
        "messages": [
            {
                "contentType": "PlainText",
                "content": "Thank you. Your identity has been verified."
            }
        ]
    }
