# Amazon Connect Routing Profiles

This document explains the routing profiles configured in this Connect instance and their differences.

## Overview

Routing profiles determine which queues an agent can handle, what types of contacts (voice, chat, task) they receive, and how many concurrent contacts they can manage.

---

## Basic Routing Profile

**Target Users:** Entry-level agents, training scenarios, testing

### Configuration
- **Concurrency Limits:**
  - Voice: 1 concurrent call
  - Chat: 2 concurrent chats
  - Task: 1 concurrent task
  
- **Queue Assignments:**
  - **BasicQueue** (Priority 1)
    - Handles VOICE and CHAT channels
    - First priority for incoming contacts
  - **GeneralAgentQueue** (Priority 2)
    - Handles VOICE and CHAT channels
    - Backup queue when BasicQueue is busy

### Use Cases
- New agents learning the system
- Testing chat and voice functionality
- Simple customer inquiries
- Training environments

### Characteristics
- **Lower task concurrency** (1 vs 10) - Reduces cognitive load for new agents
- **Multiple queue routing** - Provides exposure to different contact types
- **Backup queue support** - Ensures contacts are handled even if primary queue is full

---

## Main Routing Profile

**Target Users:** Senior agents, outbound calling teams

### Configuration
- **Concurrency Limits:**
  - Voice: 1 concurrent call
  - Chat: 2 concurrent chats
  - Task: 10 concurrent tasks
  
- **Queue Assignments:**
  - **GeneralAgentQueue only** (Priority 1)
    - Handles VOICE and CHAT channels
    - Focused on general customer service

### Use Cases
- Experienced agents handling complex inquiries
- High-volume task processing
- Outbound calling campaigns
- Specialized customer service

### Characteristics
- **High task concurrency** (10) - Can manage multiple background tasks
- **Outbound calling enabled** - Can make outbound calls
- **Single focused queue** - Streamlined for efficiency
- **Simplified routing** - Less queue switching

---

## Comparison Table

| Feature | Basic Routing Profile | Main Routing Profile | Specialist Profiles (Account, Lending, Onboarding) |
|---------|----------------------|---------------------|----------------------------------------------------|
| **Voice Concurrency** | 1 | 1 | 1 |
| **Chat Concurrency** | 2 | 2 | 2 |
| **Task Concurrency** | 1 | 10 | 10 |
| **Number of Queues** | 2 (Basic + General) | 1 (General) | 1 (Specific Service Queue) |
| **Outbound Calling** | Yes | Yes | Yes |
| **Complexity** | Lower | Higher | Higher |
| **Best For** | New agents, testing | Senior Managers | Subject Matter Experts |

---

## Agent Assignments

### Agent 1 (`agent1`)
- **Profile:** Basic Routing Profile
- **Security Profile:** Agent (Standard Access)
- **Role:** Junior Generalist
- **Scope:** Handles BasicQueue (P1) and GeneralAgentQueue (P2 backup). Limited task capacity.

### Agent 2 (`agent2`)
- **Profile:** Main Routing Profile
- **Security Profile:** CallCenterManager (Monitoring, Barge-in, Takeover)
- **Role:** Senior Manager / Supervisor
- **Scope:** Handles GeneralAgentQueue (P1). High task capacity (10). Capabilities to monitor and intercept calls from all other agents.

### Agent 3 (`agent3`)
- **Profile:** Account Services Routing Profile
- **Security Profile:** Agent (Standard Access)
- **Role:** Account Specialist
- **Scope:** Dedicated exclusively to the AccountQueue (P1).

### Agent 4 (`agent4`)
- **Profile:** Lending Services Routing Profile
- **Security Profile:** Agent (Standard Access)
- **Role:** Lending Specialist
- **Scope:** Dedicated exclusively to the LendingQueue (P1).

### Agent 5 (`agent5`)
- **Profile:** Onboarding Services Routing Profile
- **Security Profile:** Agent (Standard Access)
- **Role:** Onboarding Specialist
- **Scope:** Dedicated exclusively to the OnboardingQueue (P1).

---

## Special Profiles (New)

### Account Services Routing Profile
- **Target:** Specialists in account maintenance.
- **Queues:** AccountQueue only.
- **Concurrency:** Voice (1), Chat (2), Task (10).

### Lending Services Routing Profile
- **Target:** Loan officers and mortgage support.
- **Queues:** LendingQueue only.
- **Concurrency:** Voice (1), Chat (2), Task (10).

### Onboarding Services Routing Profile
- **Target:** New customer acquisition.
- **Queues:** OnboardingQueue only.
- **Concurrency:** Voice (1), Chat (2), Task (10).

---

## Transfer Capabilities (Quick Connects)

We have enabled **Global Queue Visibility**. This means:
*   Every agent, regardless of their profile (Basic vs. Specialist), can see **all queues** in their transfer list.
*   **Mechanism**: Queue Quick Connects have been created and associated with every queue in the instance.
*   **Experience**: An agent in the Account Queue can natively transfer a customer to the Lending Queue properly maintaining context and without incurring external telephony charges.

## Queue Priority Explained

Priority determines the order in which queues are checked for contacts:
- **Priority 1:** Checked first (highest priority)
- **Priority 2:** Checked if Priority 1 queues are full/unavailable

In **Basic Routing Profile:**
- BasicQueue contacts are attempted first (Priority 1)
- If BasicQueue has no contacts, GeneralAgentQueue is checked (Priority 2)

In **Main Routing Profile:**
- Only GeneralAgentQueue is configured (Priority 1)
- Simpler, more focused routing

---

## When to Use Which Profile

### Use Basic Routing Profile when:
- Training new agents
- Testing chat/voice functionality
- Handling simple customer inquiries
- Need for queue redundancy/failover
- Lower concurrent task load is desired

### Use Main Routing Profile when:
- Agent is experienced with the system
- High task throughput is needed
- Focus on a single primary queue
- Outbound calling is a primary function
- Efficiency over redundancy

---

## Technical Implementation

All profiles are managed in `main.tf`.

```terraform
# Service Lines Routing Profiles (Account, Lending, Onboarding)
resource "aws_connect_routing_profile" "service_lines" {
  for_each = var.service_lines
  # ... Maps to respective ServiceQueue (Priority 1)
}

# Basic Routing Profile - Entry-level with multiple queues
resource "aws_connect_routing_profile" "basic" {
  # ... BasicQueue (Priority 1) + GeneralAgentQueue (Priority 2)
}

# Main Routing Profile - Advanced with single queue
resource "aws_connect_routing_profile" "main" {
  # ... GeneralAgentQueue only (Priority 1)
}
```

The profiles are assigned to agents specifically:
- `agent1` → Basic Routing Profile
- `agent2` → Main Routing Profile (Manager)
- `agent3`, `agent4`, `agent5` → Respective Specialist Profiles

---

## Testing Recommendations

1. **Basic Profile Testing:**
   - Log in as `agent1`
   - Initiate Test Chat from AWS Console
   - Verify chat appears in CCP
   - Test Lex bot interactions
   - Monitor BasicQueue metrics

2. **Main Profile Testing:**
   - Log in as `agent2`
   - Test voice calls
   - Verify high task concurrency
   - Test outbound calling
   - Monitor GeneralAgentQueue metrics

---

## Modifications

To modify routing profiles, update `main.tf` and run:

```bash
terraform plan
terraform apply
```

To change an agent's routing profile, update the `routing_profile_id` in their user resource and reapply terraform.
