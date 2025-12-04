"""
Transfer Intent Handlers for Financial Services
Handles internal transfers, external transfers, and wire transfers
"""
import os
import json
import logging
from typing import Dict, Any
from utils import close_dialog, elicit_slot

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handle_internal_transfer(intent_request: Dict[str, Any]) -> Dict[str, Any]:
    """Handle transfer between customer's own accounts"""
    logger.info("Processing InternalTransfer intent")
    
    slots = intent_request['sessionState']['intent']['slots']
    session_attributes = intent_request.get('sessionState', {}).get('sessionAttributes', {})
    
    # Check authentication
    if session_attributes.get('authenticated') != 'true':
        return close_dialog(
            intent_request,
            'Failed',
            'You must be authenticated to transfer funds. Please verify your identity first.'
        )
    
    from_account = slots.get('FromAccount', {}).get('value', {}).get('interpretedValue')
    to_account = slots.get('ToAccount', {}).get('value', {}).get('interpretedValue')
    amount = slots.get('Amount', {}).get('value', {}).get('interpretedValue')
    
    # Elicit missing slots
    if not from_account:
        return elicit_slot(intent_request, 'FromAccount', 
                          'Which account would you like to transfer from?')
    
    if not to_account:
        return elicit_slot(intent_request, 'ToAccount', 
                          'Which account would you like to transfer to?')
    
    if not amount:
        return elicit_slot(intent_request, 'Amount', 
                          'How much would you like to transfer?')
    
    # In production: Call core banking API to execute transfer
    # For now, simulate success
    logger.info(f"Internal transfer: {amount} from {from_account} to {to_account}")
    
    message = f"I've transferred £{amount} from your {from_account} to your {to_account}. The funds should be available immediately."
    
    return close_dialog(intent_request, 'Fulfilled', message)


def handle_external_transfer(intent_request: Dict[str, Any]) -> Dict[str, Any]:
    """Handle transfer to external account"""
    logger.info("Processing ExternalTransfer intent")
    
    slots = intent_request['sessionState']['intent']['slots']
    session_attributes = intent_request.get('sessionState', {}).get('sessionAttributes', {})
    
    # Check authentication
    if session_attributes.get('authenticated') != 'true':
        return close_dialog(
            intent_request,
            'Failed',
            'You must be authenticated to send payments. Please verify your identity first.'
        )
    
    payee = slots.get('Payee', {}).get('value', {}).get('interpretedValue')
    amount = slots.get('Amount', {}).get('value', {}).get('interpretedValue')
    reference = slots.get('Reference', {}).get('value', {}).get('interpretedValue')
    
    # Elicit missing slots
    if not payee:
        return elicit_slot(intent_request, 'Payee', 
                          'Who would you like to send money to?')
    
    if not amount:
        return elicit_slot(intent_request, 'Amount', 
                          'How much would you like to send?')
    
    if not reference:
        return elicit_slot(intent_request, 'Reference', 
                          'What reference would you like to include?')
    
    # In production: Call payment API with fraud checks
    logger.info(f"External transfer: {amount} to {payee}, reference: {reference}")
    
    message = f"I've sent £{amount} to {payee} with reference '{reference}'. It should arrive within 2 hours."
    
    return close_dialog(intent_request, 'Fulfilled', message)


def handle_wire_transfer(intent_request: Dict[str, Any]) -> Dict[str, Any]:
    """Handle international wire transfer"""
    logger.info("Processing WireTransfer intent")
    
    slots = intent_request['sessionState']['intent']['slots']
    session_attributes = intent_request.get('sessionState', {}).get('sessionAttributes', {})
    
    # Check authentication - wire transfers require high security
    if session_attributes.get('authenticated') != 'true':
        return close_dialog(
            intent_request,
            'Failed',
            'You must be authenticated to send international transfers. Please verify your identity first.'
        )
    
    # Wire transfers typically require agent assistance for compliance
    message = (
        "For international wire transfers, I'll connect you with a specialist who can "
        "help with SWIFT codes, beneficiary details, and regulatory requirements. "
        "Please hold while I transfer you."
    )
    
    # Set flag for agent transfer
    session_attributes['transfer_reason'] = 'wire_transfer'
    session_attributes['transfer_queue'] = 'AccountQueue'
    
    return close_dialog(intent_request, 'Fulfilled', message)
