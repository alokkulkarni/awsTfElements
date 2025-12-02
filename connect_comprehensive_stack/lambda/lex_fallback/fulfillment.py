from utils import close_dialog

def handle_check_balance(customer_data, intent_name):
    if not customer_data:
        return close_dialog("Failed", "I could not find your account details.", intent_name)
        
    balance = customer_data.get('balance')
    name = customer_data.get('name')
    return close_dialog("Fulfilled", f"Hello {name}, your current balance is {balance}.", intent_name)

def handle_loan_inquiry(event, intent_name):
    return close_dialog("Fulfilled", "We have several loan options available for SMEs. I can have a specialist contact you, or you can apply online.", intent_name)

def handle_onboarding_status(event, intent_name):
    return close_dialog("Fulfilled", "Your application is currently under review. We expect an update within 24 hours.", intent_name)
