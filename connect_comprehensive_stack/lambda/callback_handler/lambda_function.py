"""
Lambda function to handle callback requests from customers in queue.
"""
import json
import logging
import os
import uuid
from datetime import datetime, timedelta
import boto3

logger = logging.getLogger()
logger.setLevel(os.environ.get('LOG_LEVEL', 'INFO'))

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name=os.environ.get('AWS_REGION', 'eu-west-2'))
table_name = os.environ.get('CALLBACK_TABLE_NAME', '')
table = dynamodb.Table(table_name) if table_name else None


def lambda_handler(event, context):
    """
    Handle callback request from customer in queue.
    
    Expected event from Connect:
    {
        "Details": {
            "ContactData": {
                "ContactId": "...",
                "CustomerEndpoint": {
                    "Address": "+447700900000",
                    "Type": "TELEPHONE_NUMBER"
                },
                "Queue": {
                    "ARN": "...",
                    "Name": "..."
                }
            },
            "Parameters": {}
        }
    }
    """
    logger.info(f"Received callback request: {json.dumps(event)}")
    
    try:
        # Extract customer information
        contact_data = event.get('Details', {}).get('ContactData', {})
        contact_id = contact_data.get('ContactId', 'unknown')
        
        customer_endpoint = contact_data.get('CustomerEndpoint', {})
        customer_phone = customer_endpoint.get('Address', '')
        
        queue_info = contact_data.get('Queue', {})
        queue_id = queue_info.get('ARN', '')
        queue_name = queue_info.get('Name', 'Unknown')
        
        if not customer_phone:
            logger.error("No customer phone number provided")
            return {
                'statusCode': 400,
                'callback_scheduled': False,
                'error': 'No phone number provided'
            }
        
        if not table:
            logger.error("Callback table not configured")
            return {
                'statusCode': 500,
                'callback_scheduled': False,
                'error': 'Service not configured'
            }
        
        # Create callback request
        callback_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat() + 'Z'
        ttl = int((datetime.utcnow() + timedelta(days=7)).timestamp())
        
        item = {
            'callback_id': callback_id,
            'requested_at': timestamp,
            'contact_id': contact_id,
            'customer_phone': customer_phone,
            'status': 'PENDING',
            'queue_id': queue_id,
            'queue_name': queue_name,
            'priority': 'NORMAL',
            'ttl': ttl
        }
        
        # Store in DynamoDB
        table.put_item(Item=item)
        
        logger.info(f"Callback scheduled: {callback_id} for {customer_phone}")
        
        return {
            'statusCode': 200,
            'callback_scheduled': True,
            'callback_id': callback_id,
            'callback_phone': customer_phone
        }
        
    except Exception as e:
        logger.error(f"Error scheduling callback: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'callback_scheduled': False,
            'error': str(e)
        }
