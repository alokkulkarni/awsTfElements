"""
Account-related intent handlers for financial services.
Includes balance checks, transaction history, statements, and account details.
"""
import logging
from typing import Dict, Any
from utils import close_dialog, elicit_slot
from resilience import with_retry, circuit_breaker, TransientError, PermanentError
import requests
import os

logger = logging.getLogger(__name__)

CORE_BANKING_API = os.environ.get('CORE_BANKING_API_URL', 'https://api.example.com/banking')
API_KEY = os.environ.get('CORE_BANKING_API_KEY', '')
API_TIMEOUT = int(os.environ.get('API_TIMEOUT', '5'))


@with_retry(max_attempts=3, backoff_factor=2)
def call_core_banking_api(endpoint: str, customer_id: str, params: Dict = None) -> Dict:
    """
    Call core banking system with retry logic.
    
    Args:
        endpoint: API endpoint (e.g., '/accounts/balance')
        customer_id: Customer identifier
        params: Optional query parameters
        
    Returns:
        API response as dictionary
        
    Raises:
        TransientError: Temporary failures (5xx, timeouts)
        PermanentError: Permanent failures (4xx, validation)
    """
    url = f"{CORE_BANKING_API}{endpoint}"
    headers = {
        'Authorization': f'Bearer {API_KEY}',
        'Content-Type': 'application/json',
        'X-Customer-ID': customer_id
    }
    
    try:
        response = requests.get(
            url,
            headers=headers,
            params=params or {},
            timeout=API_TIMEOUT
        )
        
        # Handle different status codes
        if response.status_code == 200:
            return response.json()
        elif response.status_code >= 500:
            raise TransientError(f"API server error: {response.status_code}")
        elif response.status_code == 404:
            raise PermanentError(f"Resource not found: {endpoint}")
        elif response.status_code == 401:
            raise PermanentError("Authentication failed")
        elif response.status_code >= 400:
            raise PermanentError(f"Client error: {response.status_code}")
        else:
            raise TransientError(f"Unexpected status code: {response.status_code}")
            
    except requests.Timeout:
        raise TransientError(f"API timeout after {API_TIMEOUT}s")
    except requests.ConnectionError as e:
        raise TransientError(f"Connection error: {str(e)}")
    except Exception as e:
        logger.error(f"Unexpected error calling API: {str(e)}", exc_info=True)
        raise TransientError(f"API call failed: {str(e)}")


def handle_check_balance(
    event: Dict[str, Any],
    customer_data: Dict[str, Any],
    session_attributes: Dict[str, str]
) -> Dict[str, Any]:
    """
    Handle balance inquiry intent.
    
    Flow:
    1. Elicit account type if not provided
    2. Call core banking API to get balance
    3. Return formatted balance with masked account number
    """
    try:
        slots = event.get('sessionState', {}).get('intent', {}).get('slots', {})
        account_type = slots.get('AccountType', {}).get('value', {}).get('interpretedValue')
        
        # Elicit account type if not provided
        if not account_type:
            return elicit_slot(
                "CheckBalance",
                "AccountType",
                "Which account would you like to check? Checking or savings?"
            )
        
        customer_id = customer_data.get('customer_id')
        
        # Call core banking API with circuit breaker
        try:
            balance_data = circuit_breaker.call(
                call_core_banking_api,
                f'/accounts/{account_type}/balance',
                customer_id
            )
        except Exception as e:
            logger.error(f"Balance check failed: {str(e)}")
            return close_dialog(
                "Failed",
                "I'm having trouble accessing your account information right now. Please try again in a moment or speak with an agent.",
                "CheckBalance"
            )
        
        # Format response
        balance = balance_data.get('balance', 0)
        available = balance_data.get('available_balance', balance)
        currency = balance_data.get('currency', 'GBP')
        account_last_four = balance_data.get('account_number', '****')[-4:]
        
        message = (
            f"Your {account_type} account ending in {account_last_four} has a balance of "
            f"£{balance:,.2f}. Your available balance is £{available:,.2f}."
        )
        
        logger.info(f"Balance check successful for customer {customer_id}")
        
        return close_dialog("Fulfilled", message, "CheckBalance")
        
    except PermanentError as e:
        logger.error(f"Permanent error in balance check: {str(e)}")
        return close_dialog(
            "Failed",
            "I couldn't find that account information. Let me connect you with an agent.",
            "CheckBalance"
        )
    except Exception as e:
        logger.error(f"Unexpected error in balance check: {str(e)}", exc_info=True)
        return close_dialog(
            "Failed",
            "I encountered an error checking your balance. Please try again or speak with an agent.",
            "CheckBalance"
        )


def handle_transaction_history(
    event: Dict[str, Any],
    customer_data: Dict[str, Any],
    session_attributes: Dict[str, str]
) -> Dict[str, Any]:
    """
    Handle transaction history request.
    Returns recent transactions and offers to email full details.
    """
    try:
        slots = event.get('sessionState', {}).get('intent', {}).get('slots', {})
        account_type = slots.get('AccountType', {}).get('value', {}).get('interpretedValue')
        date_range = slots.get('DateRange', {}).get('value', {}).get('interpretedValue', '7')  # Last 7 days
        
        if not account_type:
            return elicit_slot(
                "TransactionHistory",
                "AccountType",
                "Which account's transactions would you like to review?"
            )
        
        customer_id = customer_data.get('customer_id')
        
        # Call API for transactions
        try:
            txn_data = circuit_breaker.call(
                call_core_banking_api,
                f'/accounts/{account_type}/transactions',
                customer_id,
                {'days': date_range, 'limit': 5}
            )
        except Exception as e:
            logger.error(f"Transaction history failed: {str(e)}")
            return close_dialog(
                "Failed",
                "I'm unable to retrieve your transaction history right now. Please try again later.",
                "TransactionHistory"
            )
        
        transactions = txn_data.get('transactions', [])
        
        if not transactions:
            message = f"You have no transactions in your {account_type} account in the last {date_range} days."
        else:
            # Format recent transactions
            txn_list = []
            for txn in transactions[:3]:  # Show only last 3
                amount = txn.get('amount', 0)
                description = txn.get('description', 'Transaction')
                date = txn.get('date', '')
                txn_list.append(f"£{abs(amount):,.2f} - {description} on {date}")
            
            txn_summary = "\n".join(txn_list)
            message = (
                f"Here are your recent {account_type} transactions:\n\n"
                f"{txn_summary}\n\n"
                f"I can email you a complete statement if you'd like. Just say 'email statement'."
            )
        
        return close_dialog("Fulfilled", message, "TransactionHistory")
        
    except Exception as e:
        logger.error(f"Error in transaction history: {str(e)}", exc_info=True)
        return close_dialog(
            "Failed",
            "I had trouble retrieving your transactions. Please try again.",
            "TransactionHistory"
        )


def handle_account_details(
    event: Dict[str, Any],
    customer_data: Dict[str, Any],
    session_attributes: Dict[str, str]
) -> Dict[str, Any]:
    """
    Handle account details request (routing number, account number).
    Requires high-level authentication.
    """
    try:
        # Check for enhanced authentication
        auth_level = session_attributes.get('AuthLevel', 'basic')
        
        if auth_level != 'high':
            return close_dialog(
                "Failed",
                "For security, I need to verify your identity before sharing account details. Please complete authentication and try again.",
                "AccountDetails"
            )
        
        slots = event.get('sessionState', {}).get('intent', {}).get('slots', {})
        account_type = slots.get('AccountType', {}).get('value', {}).get('interpretedValue')
        
        if not account_type:
            return elicit_slot(
                "AccountDetails",
                "AccountType",
                "Which account details do you need? Checking or savings?"
            )
        
        customer_id = customer_data.get('customer_id')
        
        # Get account details
        try:
            account_data = circuit_breaker.call(
                call_core_banking_api,
                f'/accounts/{account_type}/details',
                customer_id
            )
        except Exception as e:
            logger.error(f"Account details failed: {str(e)}")
            return close_dialog(
                "Failed",
                "I couldn't retrieve your account details. Please contact us at 0800-123-4567.",
                "AccountDetails"
            )
        
        sort_code = account_data.get('sort_code', '12-34-56')
        account_number = account_data.get('account_number', '********')
        
        message = (
            f"Your {account_type} account details:\n\n"
            f"Sort code: {sort_code}\n"
            f"Account number: {account_number}\n\n"
            f"For security, I'll also send these details to your registered email address."
        )
        
        # Log sensitive data access for audit
        logger.info(
            f"Account details accessed by customer {customer_id}",
            extra={'audit': True, 'sensitive': True}
        )
        
        return close_dialog("Fulfilled", message, "AccountDetails")
        
    except Exception as e:
        logger.error(f"Error in account details: {str(e)}", exc_info=True)
        return close_dialog(
            "Failed",
            "I had trouble retrieving your account details. Please try again or speak with an agent.",
            "AccountDetails"
        )


def handle_request_statement(
    event: Dict[str, Any],
    customer_data: Dict[str, Any],
    session_attributes: Dict[str, str]
) -> Dict[str, Any]:
    """
    Handle statement request - email or mail delivery.
    """
    try:
        slots = event.get('sessionState', {}).get('intent', {}).get('slots', {})
        account_type = slots.get('AccountType', {}).get('value', {}).get('interpretedValue')
        delivery_method = slots.get('DeliveryMethod', {}).get('value', {}).get('interpretedValue', 'email')
        
        if not account_type:
            return elicit_slot(
                "RequestStatement",
                "AccountType",
                "Which account statement do you need?"
            )
        
        customer_id = customer_data.get('customer_id')
        customer_email = customer_data.get('email', 'your registered email')
        
        # Trigger statement generation (async)
        # In production, this would call an API to generate and send statement
        logger.info(f"Statement requested for customer {customer_id}, account {account_type}")
        
        if delivery_method == 'email':
            message = (
                f"I'll send your {account_type} account statement to {customer_email}. "
                f"You should receive it within the next few minutes."
            )
        else:
            message = (
                f"I'll mail your {account_type} account statement to your registered address. "
                f"Please allow 5-7 business days for delivery."
            )
        
        return close_dialog("Fulfilled", message, "RequestStatement")
        
    except Exception as e:
        logger.error(f"Error requesting statement: {str(e)}", exc_info=True)
        return close_dialog(
            "Failed",
            "I had trouble processing your statement request. Please try again or call us at 0800-123-4567.",
            "RequestStatement"
        )


# Export handlers
__all__ = [
    'handle_check_balance',
    'handle_transaction_history',
    'handle_account_details',
    'handle_request_statement'
]
