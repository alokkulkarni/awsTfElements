"""
Card services and fraud detection intent handlers.
High-priority intents requiring immediate action and escalation.
"""
import logging
from typing import Dict, Any
from utils import close_dialog, elicit_slot
from handlers.resilience import with_retry, circuit_breaker, TransientError, PermanentError
import os
import boto3

logger = logging.getLogger(__name__)

# Initialize AWS services
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

FRAUD_ALERT_TOPIC = os.environ.get('FRAUD_ALERT_SNS_TOPIC', '')
FRAUD_QUEUE_ARN = os.environ.get('FRAUD_QUEUE_ARN', '')
SECURITY_TABLE = os.environ.get('SECURITY_EVENTS_TABLE', '')


def handle_activate_card(
    event: Dict[str, Any],
    customer_data: Dict[str, Any],
    session_attributes: Dict[str, str]
) -> Dict[str, Any]:
    """
    Handle card activation request.
    Validates last 4 digits and activates card.
    """
    try:
        slots = event.get('sessionState', {}).get('intent', {}).get('slots', {})
        card_last_four = slots.get('CardLastFour', {}).get('value', {}).get('interpretedValue')
        card_type = slots.get('CardType', {}).get('value', {}).get('interpretedValue', 'debit')
        
        if not card_last_four:
            return elicit_slot(
                "ActivateCard",
                "CardLastFour",
                "Please provide the last 4 digits of your card."
            )
        
        # Validate card_last_four is 4 digits
        if not card_last_four.isdigit() or len(card_last_four) != 4:
            return elicit_slot(
                "ActivateCard",
                "CardLastFour",
                "Please enter exactly 4 digits."
            )
        
        customer_id = customer_data.get('customer_id')
        
        # Call API to activate card
        try:
            result = circuit_breaker.call(
                activate_card_api,
                customer_id,
                card_last_four,
                card_type
            )
        except Exception as e:
            logger.error(f"Card activation failed: {str(e)}")
            return close_dialog(
                "Failed",
                "I'm having trouble activating your card right now. Please call our card services team at 0800-CARDS.",
                "ActivateCard"
            )
        
        if result.get('success'):
            message = (
                f"Your {card_type} card ending in {card_last_four} has been activated. "
                f"You can start using it immediately."
            )
            return close_dialog("Fulfilled", message, "ActivateCard")
        else:
            error_reason = result.get('error', 'unknown')
            if error_reason == 'invalid_card':
                message = (
                    f"I couldn't find a card ending in {card_last_four}. "
                    f"Please check the number and try again, or call us at 0800-CARDS."
                )
            else:
                message = "I couldn't activate your card. Please call us at 0800-CARDS for assistance."
            
            return close_dialog("Failed", message, "ActivateCard")
            
    except Exception as e:
        logger.error(f"Error in card activation: {str(e)}", exc_info=True)
        return close_dialog(
            "Failed",
            "I encountered an error. Please call our card services at 0800-CARDS.",
            "ActivateCard"
        )


def handle_lost_stolen_card(
    event: Dict[str, Any],
    customer_data: Dict[str, Any],
    session_attributes: Dict[str, str]
) -> Dict[str, Any]:
    """
    Handle lost/stolen card report.
    CRITICAL: Immediately block card and escalate.
    """
    try:
        slots = event.get('sessionState', {}).get('intent', {}).get('slots', {})
        card_type = slots.get('CardType', {}).get('value', {}).get('interpretedValue')
        
        if not card_type:
            return elicit_slot(
                "ReportLostStolenCard",
                "CardType",
                "Which card do you need to block? Debit or credit card?"
            )
        
        customer_id = customer_data.get('customer_id')
        customer_phone = customer_data.get('phone_number', 'Unknown')
        
        # IMMEDIATE ACTION: Block all cards of this type
        try:
            block_result = circuit_breaker.call(
                block_cards_api,
                customer_id,
                card_type,
                reason='lost_stolen'
            )
        except Exception as e:
            logger.error(f"CRITICAL: Card block failed: {str(e)}")
            # Even if API fails, escalate to agent immediately
            return close_dialog(
                "Failed",
                "This is urgent. I'm connecting you immediately with our fraud team to secure your account.",
                "TransferToAgent"
            )
        
        # Log security event
        log_security_event(
            customer_id=customer_id,
            event_type='CARD_LOST_STOLEN',
            details={
                'card_type': card_type,
                'phone': customer_phone,
                'blocked_cards': block_result.get('blocked_cards', [])
            }
        )
        
        # Send fraud alert
        send_fraud_alert(
            customer_id=customer_id,
            alert_type='CARD_LOST_STOLEN',
            severity='HIGH',
            details=f"{card_type} card reported lost/stolen"
        )
        
        blocked_count = block_result.get('count', 1)
        
        message = (
            f"I've immediately blocked your {card_type} card(s). "
            f"For your security, I'm transferring you to our fraud team "
            f"who will help you order a replacement and review recent transactions."
        )
        
        # Set high priority for queue routing
        session_attributes['Priority'] = 'HIGH'
        session_attributes['TransferReason'] = 'LostStolenCard'
        session_attributes['RequiresFraudTeam'] = 'true'
        
        logger.warning(
            f"FRAUD ALERT: Lost/stolen card reported by customer {customer_id}",
            extra={'audit': True, 'severity': 'HIGH'}
        )
        
        return {
            "sessionState": {
                "dialogAction": {"type": "Close"},
                "intent": {
                    "name": "TransferToAgent",
                    "state": "Fulfilled"
                },
                "sessionAttributes": session_attributes
            },
            "messages": [
                {"contentType": "PlainText", "content": message}
            ]
        }
        
    except Exception as e:
        logger.error(f"CRITICAL ERROR in lost/stolen handler: {str(e)}", exc_info=True)
        # Always escalate on error
        return close_dialog(
            "Failed",
            "This is urgent. Connecting you immediately with our fraud team.",
            "TransferToAgent"
        )


def handle_fraud_report(
    event: Dict[str, Any],
    customer_data: Dict[str, Any],
    session_attributes: Dict[str, str]
) -> Dict[str, Any]:
    """
    Handle fraud/suspicious activity report.
    CRITICAL: Immediate escalation to fraud team.
    """
    try:
        customer_id = customer_data.get('customer_id')
        customer_name = customer_data.get('name', 'Customer')
        
        # Log fraud report
        log_security_event(
            customer_id=customer_id,
            event_type='FRAUD_REPORTED',
            details={
                'reported_via': 'voice_bot',
                'timestamp': event.get('inputTimestamp', ''),
                'session_id': event.get('sessionId', '')
            }
        )
        
        # Send immediate fraud alert
        send_fraud_alert(
            customer_id=customer_id,
            alert_type='FRAUD_REPORTED',
            severity='CRITICAL',
            details=f"Customer {customer_name} reporting fraud"
        )
        
        # Set highest priority
        session_attributes['Priority'] = 'CRITICAL'
        session_attributes['TransferReason'] = 'FraudReport'
        session_attributes['RequiresFraudTeam'] = 'true'
        
        logger.critical(
            f"FRAUD REPORT: Customer {customer_id} reporting fraud",
            extra={'audit': True, 'severity': 'CRITICAL'}
        )
        
        message = (
            f"I understand you need to report fraud. I'm connecting you immediately "
            f"with our fraud prevention team who are available 24/7. "
            f"Please stay on the line."
        )
        
        return {
            "sessionState": {
                "dialogAction": {"type": "Close"},
                "intent": {
                    "name": "TransferToAgent",
                    "state": "Fulfilled"
                },
                "sessionAttributes": session_attributes
            },
            "messages": [
                {"contentType": "PlainText", "content": message}
            ]
        }
        
    except Exception as e:
        logger.error(f"CRITICAL ERROR in fraud report handler: {str(e)}", exc_info=True)
        # Always escalate
        return close_dialog(
            "Failed",
            "Connecting you immediately with our fraud team.",
            "TransferToAgent"
        )


def handle_change_pin(
    event: Dict[str, Any],
    customer_data: Dict[str, Any],
    session_attributes: Dict[str, str]
) -> Dict[str, Any]:
    """
    Handle PIN change request.
    Requires authentication and guides to secure channel.
    """
    try:
        # PIN changes should be done through secure channel
        message = (
            "For your security, I can't change your PIN through this channel. "
            "You can change your PIN:\n\n"
            "1. At any ATM using your current PIN\n"
            "2. Through our mobile app (Settings > Card Services > Change PIN)\n"
            "3. By visiting a branch with valid ID\n\n"
            "Would you like me to help with anything else?"
        )
        
        logger.info(f"PIN change request by customer {customer_data.get('customer_id')}")
        
        return close_dialog("Fulfilled", message, "ChangePIN")
        
    except Exception as e:
        logger.error(f"Error in PIN change handler: {str(e)}", exc_info=True)
        return close_dialog(
            "Failed",
            "For PIN changes, please visit an ATM or contact us at 0800-CARDS.",
            "ChangePIN"
        )


def handle_dispute_transaction(
    event: Dict[str, Any],
    customer_data: Dict[str, Any],
    session_attributes: Dict[str, str]
) -> Dict[str, Any]:
    """
    Handle transaction dispute.
    Collect details and create dispute case.
    """
    try:
        slots = event.get('sessionState', {}).get('intent', {}).get('slots', {})
        amount = slots.get('TransactionAmount', {}).get('value', {}).get('interpretedValue')
        date = slots.get('TransactionDate', {}).get('value', {}).get('interpretedValue')
        
        if not amount:
            return elicit_slot(
                "DisputeTransaction",
                "TransactionAmount",
                "What was the transaction amount you want to dispute?"
            )
        
        if not date:
            return elicit_slot(
                "DisputeTransaction",
                "TransactionDate",
                "When did this transaction occur?"
            )
        
        customer_id = customer_data.get('customer_id')
        
        # Create dispute case
        try:
            case_result = create_dispute_case(
                customer_id=customer_id,
                amount=amount,
                date=date,
                source='voice_bot'
            )
        except Exception as e:
            logger.error(f"Dispute case creation failed: {str(e)}")
            return close_dialog(
                "Failed",
                "I'm having trouble creating your dispute. Let me connect you with an agent who can help.",
                "TransferToAgent"
            )
        
        case_number = case_result.get('case_number', 'Unknown')
        
        message = (
            f"I've created a dispute case (#{case_number}) for the £{amount} transaction on {date}. "
            f"Our disputes team will investigate within 10 business days. "
            f"You'll receive updates via email and SMS. "
            f"Is there anything else I can help you with?"
        )
        
        logger.info(f"Dispute case {case_number} created for customer {customer_id}")
        
        return close_dialog("Fulfilled", message, "DisputeTransaction")
        
    except Exception as e:
        logger.error(f"Error in dispute handler: {str(e)}", exc_info=True)
        return close_dialog(
            "Failed",
            "Let me connect you with an agent to file your dispute.",
            "TransferToAgent"
        )


# Helper functions

def activate_card_api(customer_id: str, last_four: str, card_type: str) -> Dict:
    """Mock API call for card activation."""
    # In production, call actual card management API
    logger.info(f"Activating card for customer {customer_id}, last 4: {last_four}")
    return {
        'success': True,
        'card_id': f"card_{last_four}",
        'activated_at': '2024-01-01T12:00:00Z'
    }


def block_cards_api(customer_id: str, card_type: str, reason: str) -> Dict:
    """Block all cards of specified type immediately."""
    logger.warning(f"BLOCKING {card_type} cards for customer {customer_id}, reason: {reason}")
    # In production, call actual card management API
    return {
        'count': 1,
        'blocked_cards': [f"{card_type}_card_1234"],
        'blocked_at': '2024-01-01T12:00:00Z'
    }


def log_security_event(customer_id: str, event_type: str, details: Dict):
    """Log security event to DynamoDB for audit trail."""
    if not SECURITY_TABLE:
        logger.warning("SECURITY_TABLE not configured, skipping event log")
        return
    
    try:
        table = dynamodb.Table(SECURITY_TABLE)
        import time
        table.put_item(Item={
            'customer_id': customer_id,
            'timestamp': int(time.time()),
            'event_type': event_type,
            'details': json.dumps(details),
            'ttl': int(time.time()) + (90 * 24 * 60 * 60)  # 90 days retention
        })
        logger.info(f"Security event logged: {event_type} for customer {customer_id}")
    except Exception as e:
        logger.error(f"Failed to log security event: {str(e)}")


def send_fraud_alert(customer_id: str, alert_type: str, severity: str, details: str):
    """Send immediate fraud alert to operations team."""
    if not FRAUD_ALERT_TOPIC:
        logger.warning("FRAUD_ALERT_TOPIC not configured, skipping alert")
        return
    
    try:
        message = {
            'customer_id': customer_id,
            'alert_type': alert_type,
            'severity': severity,
            'details': details,
            'timestamp': event.get('inputTimestamp', ''),
            'requires_immediate_action': True
        }
        
        sns.publish(
            TopicArn=FRAUD_ALERT_TOPIC,
            Subject=f"FRAUD ALERT: {alert_type} - {severity}",
            Message=json.dumps(message),
            MessageAttributes={
                'severity': {'DataType': 'String', 'StringValue': severity},
                'customer_id': {'DataType': 'String', 'StringValue': customer_id}
            }
        )
        
        logger.warning(f"Fraud alert sent: {alert_type} for customer {customer_id}")
    except Exception as e:
        logger.error(f"Failed to send fraud alert: {str(e)}")


def create_dispute_case(customer_id: str, amount: str, date: str, source: str) -> Dict:
    """Create dispute case in case management system."""
    import random
    case_number = f"DSP{random.randint(100000, 999999)}"
    
    logger.info(f"Creating dispute case {case_number} for customer {customer_id}")
    
    # In production, integrate with case management system
    return {
        'case_number': case_number,
        'status': 'open',
        'created_at': '2024-01-01T12:00:00Z'
    }


# Export handlers
__all__ = [
    'handle_activate_card',
    'handle_lost_stolen_card',
    'handle_fraud_report',
    'handle_change_pin',
    'handle_dispute_transaction'
]
