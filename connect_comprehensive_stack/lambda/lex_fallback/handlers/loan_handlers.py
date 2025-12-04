"""
Loan Intent Handlers for Financial Services
Handles loan status, payments, and applications
"""
import os
import json
import logging
from typing import Dict, Any
from utils import close_dialog, elicit_slot

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handle_loan_status(intent_request: Dict[str, Any]) -> Dict[str, Any]:
    """Handle loan status inquiry"""
    logger.info("Processing LoanStatus intent")
    
    slots = intent_request['sessionState']['intent']['slots']
    session_attributes = intent_request.get('sessionState', {}).get('sessionAttributes', {})
    
    # Check authentication
    if session_attributes.get('authenticated') != 'true':
        return close_dialog(
            intent_request,
            'Failed',
            'You must be authenticated to view loan information. Please verify your identity first.'
        )
    
    loan_type = slots.get('LoanType', {}).get('value', {}).get('interpretedValue')
    
    # In production: Call lending API to get real loan data
    # Simulate response
    customer_id = session_attributes.get('customer_id', 'unknown')
    logger.info(f"Checking loan status for customer {customer_id}, loan type: {loan_type}")
    
    # Mock response
    if loan_type and 'mortgage' in loan_type.lower():
        message = (
            "Your mortgage account shows an outstanding balance of £185,432.50. "
            "Your next payment of £892.15 is due on the 15th of this month. "
            "You're currently on a 2.95% fixed rate until 2027."
        )
    elif loan_type and 'personal' in loan_type.lower():
        message = (
            "Your personal loan has an outstanding balance of £8,450.00. "
            "Your next payment of £285.00 is due on the 20th of this month. "
            "You have 30 months remaining on this loan."
        )
    else:
        message = (
            "I can see you have 2 active loans: a mortgage and a personal loan. "
            "Which one would you like to know about?"
        )
        return elicit_slot(intent_request, 'LoanType', message)
    
    return close_dialog(intent_request, 'Fulfilled', message)


def handle_loan_payment(intent_request: Dict[str, Any]) -> Dict[str, Any]:
    """Handle loan payment"""
    logger.info("Processing LoanPayment intent")
    
    slots = intent_request['sessionState']['intent']['slots']
    session_attributes = intent_request.get('sessionState', {}).get('sessionAttributes', {})
    
    # Check authentication
    if session_attributes.get('authenticated') != 'true':
        return close_dialog(
            intent_request,
            'Failed',
            'You must be authenticated to make loan payments. Please verify your identity first.'
        )
    
    loan_type = slots.get('LoanType', {}).get('value', {}).get('interpretedValue')
    payment_amount = slots.get('PaymentAmount', {}).get('value', {}).get('interpretedValue')
    
    # Elicit missing slots
    if not loan_type:
        return elicit_slot(intent_request, 'LoanType', 
                          'Which loan would you like to make a payment for?')
    
    if not payment_amount:
        return elicit_slot(intent_request, 'PaymentAmount', 
                          'How much would you like to pay?')
    
    # In production: Call lending API to process payment
    logger.info(f"Processing loan payment: {payment_amount} for {loan_type}")
    
    message = (
        f"I've scheduled a payment of £{payment_amount} for your {loan_type}. "
        f"It will be processed today and should reflect on your account tomorrow. "
        f"Would you like a confirmation sent to your registered email?"
    )
    
    return close_dialog(intent_request, 'Fulfilled', message)


def handle_loan_application(intent_request: Dict[str, Any]) -> Dict[str, Any]:
    """Handle new loan application inquiry"""
    logger.info("Processing LoanApplication intent")
    
    slots = intent_request['sessionState']['intent']['slots']
    session_attributes = intent_request.get('sessionState', {}).get('sessionAttributes', {})
    
    loan_type = slots.get('LoanType', {}).get('value', {}).get('interpretedValue')
    loan_amount = slots.get('LoanAmount', {}).get('value', {}).get('interpretedValue')
    
    # Collect basic information
    if not loan_type:
        return elicit_slot(
            intent_request, 
            'LoanType',
            'What type of loan are you interested in? We offer personal loans, mortgages, and business loans.'
        )
    
    if not loan_amount:
        return elicit_slot(
            intent_request,
            'LoanAmount',
            f'How much are you looking to borrow for your {loan_type}?'
        )
    
    # Loan applications typically need specialist assistance
    message = (
        f"Thank you for your interest in a {loan_type} for £{loan_amount}. "
        f"I'll connect you with one of our lending specialists who can discuss rates, "
        f"terms, and start your application. They'll also need to verify some information "
        f"and discuss your specific requirements. Please hold while I transfer you."
    )
    
    # Set context for agent
    session_attributes['transfer_reason'] = 'loan_application'
    session_attributes['loan_type'] = loan_type
    session_attributes['loan_amount'] = loan_amount
    session_attributes['transfer_queue'] = 'LendingQueue'
    
    return close_dialog(intent_request, 'Fulfilled', message)
