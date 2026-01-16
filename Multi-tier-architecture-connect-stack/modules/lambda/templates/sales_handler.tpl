"""
Sales Domain Lambda Fulfillment Handler
Handles sales-related intents from Lex
"""
import json
import os
import logging
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(os.environ.get('LOG_LEVEL', 'INFO'))

# Domain configuration
DOMAIN = '${domain}'
PROJECT_NAME = '${project_name}'
ENVIRONMENT = '${environment}'

def lambda_handler(event, context):
    """
    Main Lambda handler for sales domain fulfillment
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Extract intent information
        intent_name = event.get('sessionState', {}).get('intent', {}).get('name')
        slots = event.get('sessionState', {}).get('intent', {}).get('slots', {})
        session_attributes = event.get('sessionState', {}).get('sessionAttributes', {})
        
        logger.info(f"Processing intent: {intent_name}")
        logger.info(f"Slots: {json.dumps(slots)}")
        
        # Route to appropriate intent handler
        if intent_name == 'NewAccountIntent':
            response = handle_new_account(slots, session_attributes)
        elif intent_name == 'UpgradeAccountIntent':
            response = handle_upgrade_account(slots, session_attributes)
        elif intent_name == 'SpecialOffersIntent':
            response = handle_special_offers(slots, session_attributes)
        elif intent_name == 'PricingInquiryIntent':
            response = handle_pricing_inquiry(slots, session_attributes)
        elif intent_name == 'ConsultationRequestIntent':
            response = handle_consultation_request(slots, session_attributes)
        else:
            response = handle_fallback(intent_name, slots)
        
        logger.info(f"Response: {json.dumps(response)}")
        return response
        
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        return create_error_response(str(e))

def handle_new_account(slots, session_attributes):
    """Handle new account sales inquiry"""
    account_type = get_slot_value(slots, 'AccountType', 'premium')
    interest_level = get_slot_value(slots, 'InterestLevel', 'high')
    
    return create_lex_response(
        intent_state='Fulfilled',
        message=f"Excellent! I'm connecting you with our sales team who can help you open a {account_type} account and explain all the exclusive benefits.",
        session_attributes={
            'intent': 'new_account',
            'account_type': account_type,
            'interest_level': interest_level,
            'queue': 'sales',
            'priority': 'high'
        }
    )

def handle_upgrade_account(slots, session_attributes):
    """Handle account upgrade request"""
    current_tier = get_slot_value(slots, 'CurrentTier', 'standard')
    desired_tier = get_slot_value(slots, 'DesiredTier', 'premium')
    
    return create_lex_response(
        intent_state='Fulfilled',
        message=f"Great choice! Upgrading from {current_tier} to {desired_tier} comes with fantastic benefits. Let me connect you with our upgrade specialists.",
        session_attributes={
            'intent': 'upgrade_account',
            'current_tier': current_tier,
            'desired_tier': desired_tier,
            'queue': 'sales',
            'priority': 'high'
        }
    )

def handle_special_offers(slots, session_attributes):
    """Handle special offers inquiry"""
    offer_category = get_slot_value(slots, 'OfferCategory', 'all')
    
    return create_lex_response(
        intent_state='Fulfilled',
        message=f"We have some excellent {offer_category} offers available right now! Let me connect you with our sales team who can share the details and help you take advantage of these limited-time promotions.",
        session_attributes={
            'intent': 'special_offers',
            'offer_category': offer_category,
            'queue': 'sales',
            'priority': 'high'
        }
    )

def handle_pricing_inquiry(slots, session_attributes):
    """Handle pricing inquiry"""
    product_service = get_slot_value(slots, 'ProductService')
    tier = get_slot_value(slots, 'Tier', 'standard')
    
    return create_lex_response(
        intent_state='Fulfilled',
        message=f"I'll connect you with our sales team who can provide detailed pricing information for {product_service} at the {tier} tier and discuss any available discounts.",
        session_attributes={
            'intent': 'pricing_inquiry',
            'product_service': product_service,
            'tier': tier,
            'queue': 'sales'
        }
    )

def handle_consultation_request(slots, session_attributes):
    """Handle consultation request"""
    consultation_type = get_slot_value(slots, 'ConsultationType', 'general')
    urgency = get_slot_value(slots, 'Urgency', 'normal')
    
    priority = 'high' if urgency == 'urgent' else 'normal'
    
    return create_lex_response(
        intent_state='Fulfilled',
        message=f"I'll connect you with one of our {consultation_type} consultants who can provide personalized advice and recommendations.",
        session_attributes={
            'intent': 'consultation_request',
            'consultation_type': consultation_type,
            'urgency': urgency,
            'queue': 'sales',
            'priority': priority
        }
    )

def handle_fallback(intent_name, slots):
    """Handle unknown or fallback intents"""
    return create_lex_response(
        intent_state='Failed',
        message="I'll connect you with our sales team who can better assist you with your inquiry.",
        session_attributes={
            'intent': 'fallback',
            'original_intent': intent_name,
            'queue': 'sales'
        }
    )

def get_slot_value(slots, slot_name, default=None):
    """Extract slot value safely"""
    if slots and slot_name in slots and slots[slot_name]:
        if 'value' in slots[slot_name]:
            return slots[slot_name]['value'].get('interpretedValue', default)
    return default

def create_lex_response(intent_state, message, session_attributes=None):
    """Create standardized Lex response"""
    response = {
        'sessionState': {
            'dialogAction': {
                'type': 'Close'
            },
            'intent': {
                'state': intent_state
            }
        },
        'messages': [
            {
                'contentType': 'PlainText',
                'content': message
            }
        ]
    }
    
    if session_attributes:
        response['sessionState']['sessionAttributes'] = session_attributes
    
    return response

def create_error_response(error_message):
    """Create error response"""
    return create_lex_response(
        intent_state='Failed',
        message="I apologize, but I'm experiencing technical difficulties. Let me connect you with someone who can assist you.",
        session_attributes={
            'error': error_message,
            'queue': 'general'
        }
    )
