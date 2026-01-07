# Queue Management Guide

This document provides comprehensive information about queue configuration, customer queue flow, callback functionality, and after-hours handling in the Connect Comprehensive Stack.

## Overview

The queue management system provides a seamless experience for customers waiting to speak with an agent, including real-time position updates, callback options, and intelligent after-hours handling.

## Architecture

### Components

1. **Service Queues**: Dedicated queues for Account, Lending, Onboarding, and General services
2. **Customer Queue Flow**: Manages the wait experience
3. **Callback Lambda**: Handles callback request processing
4. **Callback DynamoDB Table**: Stores callback requests
5. **Hours of Operation**: Defines business hours

### Queue Flow Diagram

```
Customer Request → Handover Detection → Specific Service Queue
                                              ↓
                                    Customer Queue Flow
                                              ↓
                        ┌─────────────────────┴─────────────────────┐
                        ↓                                             ↓
                  Within Hours                                  After Hours
                        ↓                                             ↓
            ┌───────────┴───────────┐                    After-Hours Message
            ↓                       ↓                                 ↓
      Agents Available      No Agents Available              Offer Callback
            ↓                       ↓                                 ↓
      Connect to Agent      Queue Experience              ┌──────────┴──────────┐
                                    ↓                     ↓                      ↓
                        ┌───────────┴───────────┐    Accept                 Decline
                        ↓                       ↓        ↓                      ↓
                Position Updates        Offer Callback  Collect Number      Goodbye
                        ↓                       ↓        ↓
                Wait in Queue           ┌───────┴───────┐
                        ↓               ↓               ↓
                Connect to Agent    Accept          Decline
                                        ↓               ↓
                                Collect Number    Continue Wait
                                        ↓
                                Callback Scheduled
                                        ↓
                                    Goodbye
```

## Service Queue Configuration

### Queue Settings

We configure specialized queues for each service line (Account, Lending, Onboarding) alongside a General queue.

```hcl
resource "aws_connect_queue" "queues" {
  for_each              = var.service_lines
  
  name                  = "${each.key}ServiceQueue"
  description           = "Queue for ${each.key} services"
  hours_of_operation_id = data.aws_connect_hours_of_operation.default.hours_of_operation_id
  
  outbound_caller_config {
    outbound_caller_id_name      = "Connect Support"
    outbound_caller_id_number_id = aws_connect_phone_number.outbound.id
  }
}
```

### Key Features

- **Unlimited Queue Size**: No maximum contact limit (max_contacts = 0)
- **Outbound Caller Config**: Configured for callback functionality
- **Hours of Operation**: Linked to business hours
- **Customer Queue Flow**: Associated for wait experience management

## Customer Queue Flow

The customer queue flow manages the entire wait experience from entry to agent connection or callback.

### Flow Components

#### 1. Initial Message
Greets the customer and sets expectations:
```
"Thank you for waiting. We'll connect you with an agent as soon as possible."
```

#### 2. Queue Position Checking
Continuously monitors the customer's position in queue:
- Checks position every 30 seconds
- Updates customer with current position
- Provides estimated wait time

#### 3. Position Announcements

**Next in Line (Position 1):**
```
"You're next in line. An agent will be with you shortly."
```

**Other Positions:**
```
"You are currently number [X] in the queue. 
Your estimated wait time is [Y] minutes."
```

#### 4. Callback Offer
After initial wait period, offers callback option:
```
"Would you like to receive a callback instead of waiting? 
Press 1 for callback, or press 2 to continue waiting."
```

#### 5. Hold Music
Plays hold music during wait periods:
- 30-second intervals between updates
- Comfort messages every 2 minutes

#### 6. Comfort Messages
Periodic reassurance messages:
```
"Thank you for your patience. An agent will be with you soon."
```

### Flow Logic

```json
{
  "initial-message": {
    "Type": "MessageParticipant",
    "Parameters": {
      "Text": "Thank you for waiting..."
    },
    "Transitions": {
      "NextAction": "check-queue-position"
    }
  },
  "check-queue-position": {
    "Type": "GetQueueMetrics",
    "Transitions": {
      "NextAction": "evaluate-position"
    }
  },
  "evaluate-position": {
    "Type": "Compare",
    "Parameters": {
      "ComparisonValue": "1"
    },
    "Transitions": {
      "Conditions": [
        {
          "Condition": "Equals",
          "NextAction": "next-in-line-message"
        },
        {
          "Condition": "NotEquals",
          "NextAction": "position-message"
        }
      ]
    }
  }
}
```

## Callback Functionality

### Callback Lambda

Located at `lambda/callback_handler/lambda_function.py`, the callback Lambda:

1. Receives callback requests from the queue flow
2. Validates phone number format
3. Stores request in DynamoDB
4. Returns success confirmation

### Lambda Handler

```python
def lambda_handler(event, context):
    # Extract customer phone and contact ID
    customer_phone = event.get('Details', {}).get('Parameters', {}).get('CustomerPhoneNumber')
    contact_id = event.get('Details', {}).get('ContactData', {}).get('ContactId')
    
    # Store in DynamoDB
    callback_table.put_item(
        Item={
            'callback_id': str(uuid.uuid4()),
            'contact_id': contact_id,
            'customer_phone': customer_phone,
            'requested_at': datetime.utcnow().isoformat(),
            'status': 'PENDING',
            'queue_id': 'GeneralAgentQueue',
            'ttl': int(time.time()) + (7 * 24 * 60 * 60)  # 7 days
        }
    )
    
    return {
        'callback_scheduled': True,
        'callback_id': callback_id
    }
```

### DynamoDB Schema

**Table:** `{project_name}-callbacks`

```json
{
  "callback_id": "uuid-string",
  "contact_id": "connect-contact-id",
  "customer_phone": "+44XXXXXXXXXX",
  "requested_at": "2025-10-12T10:30:00Z",
  "status": "PENDING",
  "queue_id": "GeneralAgentQueue",
  "ttl": 1735689600
}
```

**Status Values:**
- `PENDING`: Callback requested, not yet processed
- `IN_PROGRESS`: Agent is calling back
- `COMPLETED`: Callback successfully completed
- `FAILED`: Callback attempt failed

**TTL:** 7 days (automatic deletion after retention period)

### Callback Flow

1. **Customer Accepts Callback**
   - Queue flow invokes callback Lambda
   - Lambda stores request in DynamoDB
   - Confirmation message played

2. **Phone Number Collection**
   ```
   "Please enter your phone number, followed by the pound key."
   ```

3. **Confirmation**
   ```
   "Thank you. We'll call you back at [phone number] as soon as an agent is available."
   ```

4. **Goodbye Message**
   ```
   "You can now hang up. We'll call you back shortly. Goodbye."
   ```

## After-Hours Handling

### Hours of Operation Check

The queue flow checks hours of operation before queueing:

```json
{
  "check-hours-of-operation": {
    "Type": "CheckHoursOfOperation",
    "Parameters": {
      "HoursOfOperationId": "hours-id"
    },
    "Transitions": {
      "Conditions": [
        {
          "Condition": "InHours",
          "NextAction": "initial-message"
        },
        {
          "Condition": "OutOfHours",
          "NextAction": "after-hours-message"
        }
      ]
    }
  }
}
```

### After-Hours Message

```
"Thank you for contacting us. Our office hours are Monday through Friday, 
9 AM to 5 PM. We're currently closed."
```

### After-Hours Callback Option

```
"Would you like us to call you back during business hours? 
Press 1 for callback, or press 2 to end the call."
```

### After-Hours Flow

1. **Hours Check**: Determine if within business hours
2. **After-Hours Message**: Inform customer of hours
3. **Callback Offer**: Offer callback during business hours
4. **Phone Collection**: If accepted, collect phone number
5. **Confirmation**: Confirm callback will occur during business hours
6. **Goodbye**: End call

## Queue Metrics

### CloudWatch Metrics

The system publishes queue metrics to CloudWatch:

#### QueueSize
- **Namespace**: AWS/Connect
- **Description**: Number of contacts in queue
- **Dimensions**: InstanceId, MetricGroup, QueueName
- **Alarm Threshold**: >10 contacts over 5 minutes

#### LongestQueueWaitTime
- **Namespace**: AWS/Connect
- **Description**: Maximum wait time in queue (seconds)
- **Dimensions**: InstanceId, MetricGroup, QueueName
- **Alarm Threshold**: >300 seconds (5 minutes)

#### ContactsHandled
- **Namespace**: AWS/Connect
- **Description**: Number of contacts handled by agents
- **Dimensions**: InstanceId, MetricGroup, QueueName
- **Aggregation**: Sum

#### ContactsAbandoned
- **Namespace**: AWS/Connect
- **Description**: Number of contacts that abandoned queue
- **Dimensions**: InstanceId, MetricGroup, QueueName
- **Aggregation**: Sum

#### Abandonment Rate
- **Calculation**: (ContactsAbandoned / (ContactsAbandoned + ContactsHandled)) * 100
- **Alarm Threshold**: >20%

### Viewing Metrics

Access queue metrics via:
1. CloudWatch Console → Metrics → AWS/Connect
2. CloudWatch Dashboard: `{project_name}-monitoring`
3. Connect Console → Metrics and Quality → Real-time metrics

## Configuration

### Queue Configuration

Update queue settings in `main.tf`:

```hcl
resource "aws_connect_queue" "queues" {
  for_each = var.queues

  instance_id           = module.connect_instance.id
  name                  = each.key
  description           = each.value.description
  hours_of_operation_id = data.aws_connect_hours_of_operation.default.hours_of_operation_id
  
  outbound_caller_config {
    outbound_caller_id_name      = "Connect Support"
    outbound_caller_id_number_id = aws_connect_phone_number.outbound.id
  }
}
```

### Customer Queue Flow Configuration

The customer queue flow is defined in `contact_flows/customer_queue_flow.json.tftpl`:

**Template Variables:**
- `callback_lambda_arn`: ARN of callback Lambda function

### Hours of Operation

Configure business hours in Connect Console:
1. Navigate to Routing → Hours of operation
2. Select "Basic Hours" (or create custom)
3. Set business hours (e.g., Mon-Fri 9am-5pm)

## Troubleshooting

### High Queue Size

**Symptoms:**
- Queue size alarm triggered
- Long wait times
- High abandonment rate

**Diagnosis:**
1. Check agent availability
2. Review queue metrics in CloudWatch
3. Check agent routing profiles
4. Verify agents are logged in

**Solutions:**
- Add more agents to queue
- Adjust routing profile priorities
- Enable additional queues
- Review staffing levels

### Callback Not Working

**Symptoms:**
- Customers not receiving callbacks
- Callback Lambda errors
- DynamoDB write failures

**Diagnosis:**
1. Check Lambda logs for errors
2. Verify DynamoDB table exists
3. Check IAM permissions
4. Test Lambda independently

**Solutions:**
- Fix Lambda code errors
- Verify DynamoDB table configuration
- Update IAM role permissions
- Test with sample phone numbers

### High Abandonment Rate

**Symptoms:**
- Abandonment rate alarm triggered
- Customers hanging up before agent connection
- Negative customer feedback

**Diagnosis:**
1. Check average wait times
2. Review queue position update frequency
3. Analyze abandonment patterns (time of day, wait time)
4. Check callback offer timing

**Solutions:**
- Reduce wait times (add agents)
- Offer callback earlier in wait
- Improve comfort messages
- Adjust queue flow timing

### After-Hours Issues

**Symptoms:**
- Customers reaching queue outside business hours
- After-hours message not playing
- Hours check not working

**Diagnosis:**
1. Verify hours of operation configuration
2. Check contact flow hours check logic
3. Review timezone settings
4. Test during and outside business hours

**Solutions:**
- Update hours of operation
- Fix contact flow hours check
- Verify timezone configuration
- Test thoroughly

## Best Practices

### 1. Monitor Queue Metrics
- Check CloudWatch dashboard daily
- Review abandonment rates weekly
- Analyze wait time trends
- Adjust staffing based on patterns

### 2. Optimize Wait Experience
- Keep position updates frequent (every 30 seconds)
- Offer callback after 2-3 minutes
- Use pleasant hold music
- Provide realistic wait time estimates

### 3. Callback Management
- Process callbacks promptly
- Update callback status in DynamoDB
- Monitor callback success rate
- Follow up on failed callbacks

### 4. After-Hours Handling
- Clearly communicate business hours
- Offer callback for after-hours contacts
- Set customer expectations
- Process after-hours callbacks first thing

### 5. Agent Availability
- Ensure adequate staffing
- Monitor agent status
- Use routing profiles effectively
- Balance workload across agents

## Testing

### Test Scenarios

#### 1. Normal Queue Flow
```
1. Trigger agent handover
2. Enter queue
3. Verify position updates
4. Wait for agent connection
5. Verify successful handover
```

#### 2. Callback Request
```
1. Enter queue
2. Wait for callback offer
3. Accept callback
4. Enter phone number
5. Verify DynamoDB entry
6. Verify confirmation message
```

#### 3. After-Hours
```
1. Set hours to closed
2. Trigger agent handover
3. Verify after-hours message
4. Test callback offer
5. Verify callback scheduled
```

#### 4. Queue Abandonment
```
1. Enter queue
2. Wait in queue
3. Hang up before agent connection
4. Verify abandonment metric
```

### Test Commands

**Check Queue Metrics:**
```bash
aws connect get-metric-data \
  --instance-id <instance-id> \
  --start-time <start> \
  --end-time <end> \
  --filters Queue=<queue-id> \
  --metrics CONTACTS_IN_QUEUE OLDEST_CONTACT_AGE
```

**List Callback Requests:**
```bash
aws dynamodb scan \
  --table-name <project-name>-callbacks \
  --filter-expression "status = :status" \
  --expression-attribute-values '{":status":{"S":"PENDING"}}'
```

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Overall system architecture
- [README.md](README.md) - Deployment and configuration
- [HALLUCINATION_DETECTION.md](HALLUCINATION_DETECTION.md) - Validation agent details
- [ROUTING_PROFILES.md](ROUTING_PROFILES.md) - Routing profile configuration
