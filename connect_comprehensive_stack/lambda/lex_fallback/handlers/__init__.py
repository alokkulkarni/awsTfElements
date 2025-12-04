"""
Financial Services Intent Handlers
Modular intent handlers for account, card, transfer, and loan services
"""

from .account_handlers import (
    handle_check_balance,
    handle_transaction_history,
    handle_account_details,
    handle_request_statement
)

from .card_handlers import (
    handle_activate_card,
    handle_lost_stolen_card,
    handle_fraud_report,
    handle_change_pin,
    handle_dispute_transaction
)

from .transfer_handlers import (
    handle_internal_transfer,
    handle_external_transfer,
    handle_wire_transfer
)

from .loan_handlers import (
    handle_loan_status,
    handle_loan_payment,
    handle_loan_application
)

__all__ = [
    'handle_check_balance',
    'handle_transaction_history',
    'handle_account_details',
    'handle_request_statement',
    'handle_activate_card',
    'handle_lost_stolen_card',
    'handle_fraud_report',
    'handle_change_pin',
    'handle_dispute_transaction',
    'handle_internal_transfer',
    'handle_external_transfer',
    'handle_wire_transfer',
    'handle_loan_status',
    'handle_loan_payment',
    'handle_loan_application'
]
