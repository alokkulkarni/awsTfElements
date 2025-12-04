# Contact Transfer Guide

This guide explains how to transfer contacts between agents with different routing profiles (Basic → Main) in Amazon Connect.

## Overview

There are multiple ways to transfer contacts in Amazon Connect:
1. **Bot-Initiated Transfers** - Lex bot detects intent and routes to appropriate queue
2. **Agent-Initiated Transfers** - Agent manually transfers contact to another queue/agent
3. **Automatic Escalation** - Based on contact attributes or business logic

---

## Transfer Methods

### 1. Bot-Initiated Transfers (Lex Integration)

#### TransferToAgent Intent
Routes to **BasicQueue** (Basic Routing Profile agents).

**Utterances:**
- "speak to agent"
- "talk to person"
- "human agent"
- "customer service"

**Flow:**
```
Customer → Lex Bot → Lambda (TransferToAgent) → BasicQueue → Agent1 (Basic Profile)
```

**Contact Attributes Set:**
- `TargetQueue`: "BasicQueue"
- `TransferType`: "BasicAgent"
- `Priority`: "Normal"

#### TransferToSpecialist Intent
Routes to **specialized queues** (Main Routing Profile agents).

**Utterances:**
- "speak to specialist"
- "need expert help"
- "escalate"
- "senior agent"
- "specialized help"

**Flow:**
```
Customer → Lex Bot → Lambda (TransferToSpecialist) → [AccountQueue|LendingQueue|GeneralAgentQueue] → Agent2 (Main Profile)
```

**Queue Mapping:**
| Original Intent | Target Queue |
|----------------|--------------|
| CheckBalance, TransactionHistory, AccountDetails | AccountQueue |
| MortgageInquiry, LoanApplication, LoanStatus | LendingQueue |
| NewAccount, AccountOpening | OnboardingQueue |
| All others | GeneralAgentQueue |

**Contact Attributes Set:**
- `TargetQueue`: [Mapped queue name]
- `TransferType`: "Specialist"
- `Priority`: "High"
- `OriginalIntent`: [Customer's original request]

---

### 2. Agent-Initiated Transfers (CCP Quick Connects)

Agents can manually transfer contacts using the CCP interface.

#### Setup Quick Connects

Quick Connects need to be configured in `main.tf`:

```terraform
resource "aws_connect_quick_connect" "to_specialist" {
  instance_id = module.connect_instance.id
  name        = "Transfer to Specialist"
  description = "Transfer to Main Routing Profile specialist"
  
  quick_connect_config {
    quick_connect_type = "QUEUE"
    queue_config {
      contact_flow_id = aws_connect_contact_flow.transfer_flow.id
      queue_id        = aws_connect_queue.queues["GeneralAgentQueue"].queue_id
    }
  }
}

resource "aws_connect_quick_connect" "to_account_specialist" {
  instance_id = module.connect_instance.id
  name        = "Transfer to Account Specialist"
  description = "Transfer to Account Services Queue"
  
  quick_connect_config {
    quick_connect_type = "QUEUE"
    queue_config {
      contact_flow_id = aws_connect_contact_flow.transfer_flow.id
      queue_id        = aws_connect_queue.queues["AccountQueue"].queue_id
    }
  }
}
```

#### Using Quick Connects in CCP

1. Agent accepts contact from BasicQueue
2. Click "Transfer" button in CCP
3. Select quick connect:
   - "Transfer to Specialist" → GeneralAgentQueue (Main Profile)
   - "Transfer to Account Specialist" → AccountQueue (Main Profile)
4. Contact is transferred to new queue
5. Agent on Main Routing Profile receives contact

---

### 3. Contact Flow-Based Transfer

Use contact flow blocks to route based on attributes.

#### Transfer Flow Example

```json
{
  "Type": "Transfer",
  "Parameters": {
    "TransferToQueue": {
      "QueueId": "${general_queue_id}"
    }
  },
  "Transitions": {
    "NextAction": "success-block",
    "Errors": [
      {
        "NextAction": "error-block",
        "ErrorType": "NoMatchingError"
      }
    ]
  }
}
```

#### Conditional Routing Based on Attributes

```json
{
  "Type": "CheckAttribute",
  "Parameters": {
    "Attribute": "TransferType",
    "ComparisonValue": "Specialist"
  },
  "Transitions": {
    "NextAction": "transfer-to-specialist-queue",
    "Conditions": [
      {
        "NextAction": "transfer-to-basic-queue",
        "Condition": {
          "Operator": "Equals",
          "Operands": ["BasicAgent"]
        }
      }
    ]
  }
}
```

---

## Implementation Steps

### Step 1: Deploy Updated Lambda

```bash
cd connect_comprehensive_stack
terraform apply
```

This deploys:
- Updated Lambda with `TransferToSpecialist` handler
- New Lex intent for specialist transfers
- Updated contact attributes

### Step 2: Test Bot Transfer

#### Test Basic Agent Transfer:
1. Start Test Chat in AWS Console
2. Type: "I need to speak to an agent"
3. Lex triggers `TransferToAgent` intent
4. Contact routed to BasicQueue
5. Agent1 (Basic Profile) receives contact

#### Test Specialist Transfer:
1. Start Test Chat
2. Type: "I need specialist help with my account"
3. Lex triggers `TransferToSpecialist` intent
4. Lambda determines: Account-related → AccountQueue
5. Agent2 (Main Profile) receives contact

### Step 3: Configure Quick Connects (Optional)

Add to `main.tf` and apply to enable agent-initiated transfers.

### Step 4: Update Contact Flows (Optional)

Modify contact flows to check `TargetQueue` attribute and route accordingly.

---

## Transfer Scenarios

### Scenario 1: Basic to Specialist (via Bot)
```
1. Customer chats with Lex bot
2. Customer asks complex question: "I need help with a mortgage application"
3. Customer says: "This is complicated, I need specialist help"
4. Lex recognizes TransferToSpecialist intent
5. Lambda sets TargetQueue = "LendingQueue"
6. Contact transferred to LendingQueue
7. Agent2 (Main Profile with LendingQueue) receives contact
```

### Scenario 2: Agent Warm Transfer
```
1. Agent1 (Basic Profile) handling contact
2. Realizes customer needs specialist
3. Agent1 clicks "Transfer" in CCP
4. Selects "Transfer to Account Specialist" quick connect
5. Agent1 speaks with Agent2 first (warm transfer)
6. Agent1 completes transfer
7. Agent2 (Main Profile) now owns contact
```

### Scenario 3: Agent Cold Transfer
```
1. Agent1 (Basic Profile) handling contact
2. Clicks "Transfer" → Select queue
3. Chooses GeneralAgentQueue
4. Contact immediately transferred (cold transfer)
5. Agent2 (Main Profile) receives contact
```

---

## Testing Transfers

### Test 1: Basic Agent Transfer
```bash
# In Test Chat
> "I need to speak with someone"
Expected: Routed to BasicQueue, Agent1 answers

# Verify attributes
aws connect get-contact-attributes \
  --instance-id 9e31575b-30e2-483a-9b4d-1010575f3424 \
  --initial-contact-id <CONTACT_ID>

# Should see: TargetQueue = "BasicQueue"
```

### Test 2: Specialist Transfer
```bash
# In Test Chat
> "I have a complex loan question, need specialist"
Expected: Routed to LendingQueue, Agent2 answers

# Verify attributes
# Should see: 
#   TargetQueue = "LendingQueue"
#   TransferType = "Specialist"
#   Priority = "High"
```

### Test 3: Agent-Initiated Transfer
1. Log in as Agent1 (Basic Profile)
2. Accept contact from BasicQueue
3. Use CCP transfer functionality
4. Transfer to GeneralAgentQueue
5. Log in as Agent2 (Main Profile) in another browser
6. Verify Agent2 receives transferred contact

---

## Queue & Routing Profile Mapping

| Queue | Routing Profile | Agent | Use Case |
|-------|----------------|-------|----------|
| BasicQueue | Basic | agent1 | General inquiries, first contact |
| GeneralAgentQueue | Basic, Main | agent1, agent2 | General support, overflow |
| AccountQueue | Main | agent2 | Account services (balance, transactions) |
| LendingQueue | Main | agent2 | Loan applications, mortgages |
| OnboardingQueue | Main | agent2 | New account opening |

---

## Contact Attributes for Transfer

Lambda sets these attributes for intelligent routing:

```python
transfer_attributes = {
    'TransferReason': 'SpecialistRequired_LoanApplication',
    'CustomerName': 'John Doe',
    'CustomerId': '12345',
    'IsAuthenticated': 'true',
    'Priority': 'High',
    'TargetQueue': 'LendingQueue',
    'TransferType': 'Specialist',
    'OriginalIntent': 'LoanApplication'
}
```

These attributes can be used in contact flows for:
- Conditional routing
- Agent screen pops
- Reporting and analytics
- Priority queuing

---

## CCP Transfer UI

Agents see transfer options in the CCP:
- **Quick Connect** dropdown
- **Transfer to Queue** option
- **Transfer to Agent** (if configured)

To enable in custom CCP (`ccp_site/index.html.tftpl`):

```javascript
connect.contact(function(contact) {
  // Add transfer button handlers
  const transferBtn = document.getElementById('transfer-btn');
  
  transferBtn.addEventListener('click', function() {
    const agent = new connect.Agent();
    const conn = contact.getAgentConnection();
    
    // Get quick connects
    agent.getEndpoints(agent.getAllQueueARNs(), {
      success: function(data) {
        // Display quick connect options
        showTransferOptions(data.endpoints);
      }
    });
  });
});
```

---

## Troubleshooting

### Transfer Not Working
1. Check routing profile has target queue assigned
2. Verify queue is enabled for CHAT/VOICE channel
3. Check agent status (must be Available)
4. Review CloudWatch logs for Lambda errors

### Contact Stuck in Queue
1. Verify agents are online and Available
2. Check routing profile media concurrency limits
3. Review queue hours of operation
4. Check queue maximum contacts limit

### Attributes Not Passing
1. Verify Lambda returns sessionAttributes
2. Check contact flow attribute mapping
3. Review contact attribute storage limits (32KB)

---

## Best Practices

1. **Use Intent-Based Routing** - Let Lex/Lambda determine optimal queue
2. **Set Priority Appropriately** - High priority for specialist transfers
3. **Warm Transfers Preferred** - Allow agents to brief specialists
4. **Monitor Transfer Metrics** - Track transfer rates and outcomes
5. **Train Agents** - Ensure agents know when to escalate
6. **Document Transfer Reasons** - Use clear TransferReason attributes

---

## Monitoring Transfers

### CloudWatch Metrics
- `CallsBreachingConcurrencyQuota` - Queue overload
- `ContactFlowErrors` - Transfer failures
- `ContactsTransferred` - Transfer volume

### Lambda Logs
```bash
aws logs tail /aws/lambda/connect-comprehensive-lex-fallback --follow --filter-pattern "transfer"
```

### Contact Search
```bash
aws connect search-contacts \
  --instance-id 9e31575b-30e2-483a-9b4d-1010575f3424 \
  --search-criteria '{"AgentIds":["agent1-id"]}'
```

---

## Summary

- **TransferToAgent**: Routes to BasicQueue (Basic Profile)
- **TransferToSpecialist**: Routes to specialized queues (Main Profile)
- **Quick Connects**: Enable agent-initiated transfers
- **Contact Attributes**: Pass context between agents
- **Queue Mapping**: Intent-based routing to appropriate specialists

Deploy with `terraform apply` to enable all transfer functionality.
