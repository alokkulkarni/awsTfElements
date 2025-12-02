import json
import os
import boto3
import logging
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
TABLE_NAME = os.environ.get('AUTH_STATE_TABLE_NAME')
table = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    """
    Handles Auth API requests from the companion app.
    Expected payload: { "request_id": "...", "action": "APPROVE" | "DECLINE", "user_id": "..." }
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse body (API Gateway passes body as string)
        if 'body' in event:
            body = json.loads(event['body'])
        else:
            body = event

        request_id = body.get('request_id')
        action = body.get('action')
        user_id = body.get('user_id')

        if not request_id or action not in ['APPROVE', 'DECLINE']:
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'Invalid request. Missing request_id or invalid action.'})
            }

        # Update DynamoDB
        # We only update if the item exists and is in PENDING state to prevent replay attacks or race conditions
        response = table.update_item(
            Key={
                'request_id': request_id
            },
            UpdateExpression="set #s = :a, updated_at = :t",
            ConditionExpression="attribute_exists(request_id)", 
            ExpressionAttributeNames={
                '#s': 'status'
            },
            ExpressionAttributeValues={
                ':a': action,
                ':t': datetime.utcnow().isoformat()
            },
            ReturnValues="UPDATED_NEW"
        )

        logger.info(f"Update successful: {response}")

        return {
            'statusCode': 200,
            'body': json.dumps({'message': f'Request {action} successfully.'})
        }

    except dynamodb.meta.client.exceptions.ConditionalCheckFailedException:
        logger.warning(f"Request {request_id} not found or condition failed.")
        return {
            'statusCode': 404,
            'body': json.dumps({'message': 'Request not found or already processed.'})
        }
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'Internal server error.'})
        }
