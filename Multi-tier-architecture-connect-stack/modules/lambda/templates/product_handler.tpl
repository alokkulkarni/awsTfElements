"""
Product Domain Lambda Fulfillment Handler
Handles product-related intents from Lex
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
    Main Lambda handler for product domain fulfillment
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
        if intent_name == 'ProductInformationIntent':
            response = handle_product_information(slots, session_attributes)
        elif intent_name == 'ProductComparisonIntent':
            response = handle_product_comparison(slots, session_attributes)
        elif intent_name == 'ProductFeaturesIntent':
            response = handle_product_features(slots, session_attributes)
        elif intent_name == 'ProductAvailabilityIntent':
            response = handle_product_availability(slots, session_attributes)
        elif intent_name == 'ProductSpecificationsIntent':
            response = handle_product_specifications(slots, session_attributes)
        else:
            response = handle_fallback(intent_name, slots)
        
        logger.info(f"Response: {json.dumps(response)}")
        return response
        
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        return create_error_response(str(e))

def handle_product_information(slots, session_attributes):
    """Handle product information request"""
    product_name = get_slot_value(slots, 'ProductName')
    
    return create_lex_response(
        intent_state='Fulfilled',
        message=f"I'll connect you with our product specialist who can provide detailed information about {product_name} and answer all your questions.",
        session_attributes={
            'intent': 'product_information',
            'product_name': product_name,
            'queue': 'product'
        }
    )

def handle_product_comparison(slots, session_attributes):
    """Handle product comparison request"""
    product1 = get_slot_value(slots, 'ProductOne')
    product2 = get_slot_value(slots, 'ProductTwo')
    
    return create_lex_response(
        intent_state='Fulfilled',
        message=f"Great question! Let me connect you with a product expert who can compare {product1} and {product2} and help you choose the best option for your needs.",
        session_attributes={
            'intent': 'product_comparison',
            'product_one': product1,
            'product_two': product2,
            'queue': 'product'
        }
    )

def handle_product_features(slots, session_attributes):
    """Handle product features inquiry"""
    product_name = get_slot_value(slots, 'ProductName')
    feature_category = get_slot_value(slots, 'FeatureCategory', 'all')
    
    return create_lex_response(
        intent_state='Fulfilled',
        message=f"I'll connect you with someone who can explain the {feature_category} features of {product_name} in detail.",
        session_attributes={
            'intent': 'product_features',
            'product_name': product_name,
            'feature_category': feature_category,
            'queue': 'product'
        }
    )

def handle_product_availability(slots, session_attributes):
    """Handle product availability check"""
    product_name = get_slot_value(slots, 'ProductName')
    location = get_slot_value(slots, 'Location', 'your area')
    
    return create_lex_response(
        intent_state='Fulfilled',
        message=f"Let me check the availability of {product_name} in {location}. I'll connect you with someone who can provide real-time availability information.",
        session_attributes={
            'intent': 'product_availability',
            'product_name': product_name,
            'location': location,
            'queue': 'product'
        }
    )

def handle_product_specifications(slots, session_attributes):
    """Handle product specifications request"""
    product_name = get_slot_value(slots, 'ProductName')
    spec_type = get_slot_value(slots, 'SpecificationType', 'technical')
    
    return create_lex_response(
        intent_state='Fulfilled',
        message=f"I'll connect you with our product specialist who can provide the {spec_type} specifications for {product_name}.",
        session_attributes={
            'intent': 'product_specifications',
            'product_name': product_name,
            'spec_type': spec_type,
            'queue': 'product'
        }
    )

def handle_fallback(intent_name, slots):
    """Handle unknown or fallback intents"""
    return create_lex_response(
        intent_state='Failed',
        message="I'll connect you with a product specialist who can better assist you with your inquiry.",
        session_attributes={
            'intent': 'fallback',
            'original_intent': intent_name,
            'queue': 'general'
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
