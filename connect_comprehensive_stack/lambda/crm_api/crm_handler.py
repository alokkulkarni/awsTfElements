import json
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Mock Database (In-Memory for this demo, but represents a real DB)
MOCK_DB = {
    "+15550100": {
        "customer_id": "CUST-001",
        "name": "John Doe",
        "pin": "1234",
        "balance": "$15,450.00",
        "status": "ACTIVE"
    },
    "+447700900000": {
        "customer_id": "CUST-002",
        "name": "Jane Smith",
        "pin": "5678",
        "balance": "£2,300.00",
        "status": "ACTIVE"
    }
}

def lambda_handler(event, context):
    """
    Mock CRM API.
    Expected: GET /customer?phoneNumber=...
    Headers: x-api-key (Simple security check)
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    # 1. Security Check
    api_key = event.get('headers', {}).get('x-api-key')
    expected_key = os.environ.get('API_KEY')
    
    if not expected_key or api_key != expected_key:
        logger.warning("Unauthorized access attempt")
        return {
            'statusCode': 403,
            'body': json.dumps({'message': 'Forbidden'})
        }

    # 2. Parse Input
    query_params = event.get('queryStringParameters', {})
    phone_number = query_params.get('phoneNumber')

    if not phone_number:
        return {
            'statusCode': 400,
            'body': json.dumps({'message': 'Missing phoneNumber parameter'})
        }

    # 3. Lookup Customer
    customer = MOCK_DB.get(phone_number)

    if customer:
        logger.info(f"Customer found: {customer['customer_id']}")
        return {
            'statusCode': 200,
            'body': json.dumps(customer)
        }
    else:
        logger.info(f"Customer not found for {phone_number}")
        return {
            'statusCode': 404,
            'body': json.dumps({'message': 'Customer not found'})
        }
