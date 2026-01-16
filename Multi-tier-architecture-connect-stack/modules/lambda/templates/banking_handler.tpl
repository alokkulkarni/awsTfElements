"""
Banking Domain Lambda Fulfillment Handler
Handles banking-related intents from Lex
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
    Main Lambda handler for banking domain fulfillment
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
        if intent_name == 'AccountBalanceIntent':
            response = handle_account_balance(slots, session_attributes)
        elif intent_name == 'TransactionHistoryIntent':
            response = handle_transaction_history(slots, session_attributes)
        elif intent_name == 'AccountOpeningIntent':
            response = handle_account_opening(slots, session_attributes)
        elif intent_name == 'BranchFinderIntent':
            response = handle_branch_finder(slots, session_attributes)
        elif intent_name == 'CardIssueIntent':
            response = handle_card_issue(slots, session_attributes)
        else:
            response = handle_fallback(intent_name, slots)
        
        logger.info(f"Response: {json.dumps(response)}")
        return response
        
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        return create_error_response(str(e))

def handle_account_balance(slots, session_attributes):
    """Handle account balance inquiry"""
    account_type = get_slot_value(slots, 'AccountType')
    
    return create_lex_response(
        intent_state='Fulfilled',
        message=f"I can help you check your {account_type} account balance. For security reasons, please verify your identity with the agent who will assist you shortly.",
        session_attributes={
            'intent': 'account_balance',
            'account_type': account_type,
            'queue': 'banking'
        }
    )

def handle_transaction_history(slots, session_attributes):
    """Handle transaction history request"""
    time_period = get_slot_value(slots, 'TimePeriod', 'recent')
    
    return create_lex_response(
        intent_state='Fulfilled',
        message=f"I'll connect you with a banking specialist who can provide your {time_period} transaction history securely.",
        session_attributes={
            'intent': 'transaction_history',
            'time_period': time_period,
            'queue': 'banking'
        }
    )

def handle_account_opening(slots, session_attributes):
    """Handle account opening inquiry"""
    account_type = get_slot_value(slots, 'AccountType', 'savings')
    
    return create_lex_response(
        intent_state='Fulfilled',
        message=f"Great! You're interested in opening a {account_type} account. I'll transfer you to our account specialists who can guide you through the process and discuss the benefits.",
        session_attributes={
            'intent': 'account_opening',
            'account_type': account_type,
            'queue': 'banking'
        }
    )

def handle_branch_finder(slots, session_attributes):
    """Handle branch finder request"""
    location = get_slot_value(slots, 'Location')
    
    return create_lex_response(
        intent_state='Fulfilled',
        message=f"I can help you find branches near {location}. Let me connect you with someone who can provide the most current information about branch locations and hours.",
        session_attributes={
            'intent': 'branch_finder',
            'location': location,
            'queue': 'banking'
        }
    )

def handle_card_issue(slots, session_attributes):
    """Handle card-related issues"""
    issue_type = get_slot_value(slots, 'IssueType', 'general')
    
    return create_lex_response(
        intent_state='Fulfilled',
        message=f"I understand you have a card issue. I'll connect you with our card services team right away who can help resolve this quickly.",
        session_attributes={
            'intent': 'card_issue',
            'issue_type': issue_type,
            'queue': 'banking',
            'priority': 'high'
        }
    )

def handle_fallback(intent_name, slots):
    """Handle unknown or fallback intents"""
    return create_lex_response(
        intent_state='Failed',
        message="I'll connect you with a banking specialist who can better assist you with your inquiry.",
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
