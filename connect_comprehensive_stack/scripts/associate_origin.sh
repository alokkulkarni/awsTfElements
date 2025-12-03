#!/bin/bash
set -e

INSTANCE_ID=$1
ORIGIN=$2
REGION=$3

if [ -z "$INSTANCE_ID" ] || [ -z "$ORIGIN" ] || [ -z "$REGION" ]; then
  echo "Usage: $0 <instance-id> <origin> <region>"
  exit 1
fi

echo "Associating origin $ORIGIN with instance $INSTANCE_ID in region $REGION..."

MAX_RETRIES=30
SLEEP_SECONDS=10

for ((i=1; i<=MAX_RETRIES; i++)); do
  echo "Attempt $i/$MAX_RETRIES..."
  
  # Check if instance is active (optional, but good for debugging)
  STATUS=$(aws connect describe-instance --instance-id "$INSTANCE_ID" --region "$REGION" --query 'Instance.InstanceStatus' --output text 2>/dev/null || echo "NOT_FOUND")
  
  if [ "$STATUS" == "ACTIVE" ]; then
    # Try to associate
    if aws connect associate-approved-origin --instance-id "$INSTANCE_ID" --origin "$ORIGIN" --region "$REGION"; then
      echo "Successfully associated origin."
      exit 0
    else
      echo "Failed to associate origin. Retrying in $SLEEP_SECONDS seconds..."
    fi
  else
    echo "Instance status is $STATUS. Waiting for ACTIVE state..."
  fi

  sleep $SLEEP_SECONDS
done

echo "Failed to associate origin after $MAX_RETRIES attempts."
exit 1
