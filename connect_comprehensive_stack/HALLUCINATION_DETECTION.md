# Hallucination Detection Guide

This document provides comprehensive information about the ValidationAgent, which performs real-time hallucination detection to ensure AI responses are accurate and grounded in actual tool data.

## Overview

The ValidationAgent is a critical safety component that validates every response from Claude 3.5 Sonnet before it reaches the customer. It detects when the AI model generates information that isn't supported by the actual tool results, preventing the spread of misinformation.

## Architecture

### ValidationAgent Class

Located in `lambda/bedrock_mcp/validation_agent.py`, the ValidationAgent provides:

- **validate_response()**: Main entry point for validation
- **check_fabricated_data()**: Detects facts not present in tool results
- **check_domain_boundaries()**: Ensures responses stay within banking topics
- **check_document_accuracy()**: Validates document requirements
- **check_branch_accuracy()**: Verifies branch information
- **log_hallucination()**: Records hallucinations to DynamoDB
- **publish_metrics()**: Sends metrics to CloudWatch

### Integration Flow

```
User Query → Bedrock → Tool Execution → Response Generation
                                              ↓
                                    ValidationAgent
                                              ↓
                        ┌─────────────────────┴─────────────────────┐
                        ↓                                             ↓
                  No Hallucination                            Hallucination Detected
                        ↓                                             ↓
                  Return Response                    ┌────────────────┴────────────────┐
                                                     ↓                                  ↓
                                              Low/Medium Severity              High Severity
                                                     ↓                                  ↓
                                            Regenerate Response              Safe Fallback
```

## Detection Algorithms

### 1. Fabricated Data Detection

Compares key facts in the model's response against the actual tool results.

**Algorithm:**
1. Extract key facts from response (documents, steps, timelines, branch info)
2. Compare each fact against tool results
3. Flag any information not present in tool data
4. Calculate confidence score based on match percentage

**Example:**
```
Tool Result: ["ID", "Proof of Address"]
Model Response: "You need ID, Proof of Address, and Birth Certificate"
Detection: "Birth Certificate" is fabricated (not in tool results)
```

### 2. Domain Boundary Checking

Ensures the response stays within allowed banking topics.

**Allowed Topics:**
- Account opening (branch and digital)
- Debit card information
- Branch locations and services
- General banking inquiries

**Blocked Topics:**
- Investment advice
- Cryptocurrency
- Loan approval decisions
- Personal financial advice
- Non-banking services

**Algorithm:**
1. Analyze response for topic keywords
2. Check against allowed domain list
3. Flag responses that venture into blocked topics

### 3. Document Accuracy Validation

Validates that document requirements match exactly what the tools returned.

**Algorithm:**
1. Extract document list from tool results
2. Extract document mentions from response
3. Ensure response doesn't add or remove documents
4. Verify document names match exactly

**Example:**
```
Tool Result: ["Government-issued ID", "Proof of Address"]
✓ Valid: "You'll need a government-issued ID and proof of address"
✗ Invalid: "You'll need ID, proof of address, and a utility bill"
```

### 4. Branch Information Validation

Verifies branch details (address, hours, services) match tool data.

**Algorithm:**
1. Extract branch information from tool results
2. Parse branch details from response
3. Verify address, hours, and services match
4. Flag any discrepancies

## Severity Levels

### Low Severity
**Characteristics:**
- Minor inconsistencies in phrasing
- Slight variations in terminology
- Non-critical information gaps

**Action:**
- Log to DynamoDB
- Publish metrics
- Continue with response

**Example:**
- Tool says "checking account", response says "current account"

### Medium Severity
**Characteristics:**
- Additional information not in tool results
- Missing some tool-provided information
- Moderate domain boundary violations

**Action:**
- Log to DynamoDB
- Publish metrics
- Regenerate response with stricter constraints
- Return regenerated response

**Example:**
- Adding extra documents not mentioned in tool results

### High Severity
**Characteristics:**
- Completely fabricated information
- Serious domain boundary violations
- Critical inaccuracies that could mislead customers

**Action:**
- Log to DynamoDB
- Publish metrics
- Return safe fallback message
- Do NOT regenerate (prevent repeated hallucinations)

**Example:**
- Inventing branch locations that don't exist
- Providing incorrect account opening procedures

## Response Strategies

### Regeneration (Medium Severity)

When medium severity hallucinations are detected, the system regenerates the response with a stricter system prompt:

```python
stricter_prompt = """
CRITICAL: You MUST only use information from the tool results.
Do NOT add any information that is not explicitly in the tool results.
Do NOT make assumptions or inferences.
If information is not in the tool results, say you don't have that information.
"""
```

The regeneration happens automatically and transparently to the user.

### Safe Fallback (High Severity)

For high severity hallucinations, a safe fallback message is returned:

```
"I apologize, but I want to make sure I give you accurate information. 
Let me connect you with a specialist who can help you with that."
```

This triggers an automatic handover to a human agent.

## Logging

### DynamoDB Schema

Hallucinations are logged to the `{project_name}-hallucination-logs` table:

```json
{
  "log_id": "uuid-string",
  "timestamp": "2025-10-12T10:30:00Z",
  "session_id": "session-uuid",
  "user_query": "How do I open an account?",
  "tool_results": {
    "tool_name": "get_branch_account_opening_info",
    "result": ["ID", "Proof of Address"]
  },
  "model_response": "You need ID, Proof of Address, and Birth Certificate",
  "hallucination_type": "fabricated_data",
  "severity": "medium",
  "validation_details": {
    "fabricated_items": ["Birth Certificate"],
    "confidence_score": 0.67
  },
  "action_taken": "regenerated",
  "ttl": 1735689600
}
```

**TTL:** 90 days (automatic deletion after retention period)

### Log Fields

- **log_id**: Unique identifier for the log entry
- **timestamp**: ISO 8601 timestamp of detection
- **session_id**: Connect session identifier
- **user_query**: Original user question
- **tool_results**: Complete tool execution results
- **model_response**: The response that contained hallucination
- **hallucination_type**: Type of hallucination detected
- **severity**: low, medium, or high
- **validation_details**: Specific details about what was detected
- **action_taken**: Action taken (logged, regenerated, fallback)
- **ttl**: Unix timestamp for automatic deletion

## Metrics

### CloudWatch Metrics

The ValidationAgent publishes metrics to the `Connect/BedrockMCP` namespace:

#### HallucinationDetectionRate
- **Type**: Percentage
- **Description**: Percentage of responses with detected hallucinations
- **Dimensions**: hallucination_type, severity
- **Alarm Thresholds**:
  - High: >10% over 5 minutes
  - Medium: >5% over 15 minutes

#### ValidationSuccessRate
- **Type**: Percentage
- **Description**: Percentage of validations that passed
- **Dimensions**: None
- **Target**: >95%

#### ValidationLatency
- **Type**: Milliseconds
- **Description**: Time taken to validate a response
- **Dimensions**: None
- **Target**: <100ms

### Viewing Metrics

Access metrics via:
1. CloudWatch Console → Metrics → Connect/BedrockMCP
2. CloudWatch Dashboard: `{project_name}-monitoring`
3. CloudWatch Alarms for automated notifications

## Examples of Detected Hallucinations

### Example 1: Fabricated Documents

**User Query:** "What do I need to open a savings account?"

**Tool Result:**
```json
{
  "documents": ["Government-issued ID", "Proof of Address"]
}
```

**Model Response (Hallucinated):**
"To open a savings account, you'll need:
1. Government-issued ID
2. Proof of Address
3. Social Security Number
4. Employment verification letter"

**Detection:**
- Fabricated: "Social Security Number"
- Fabricated: "Employment verification letter"
- Severity: Medium
- Action: Regenerated

**Corrected Response:**
"To open a savings account, you'll need:
1. Government-issued ID
2. Proof of Address"

### Example 2: Invented Branch Location

**User Query:** "Where is your nearest branch to Manchester?"

**Tool Result:**
```json
{
  "branch_name": "London Main Branch",
  "address": "123 High Street, London"
}
```

**Model Response (Hallucinated):**
"Our nearest branch to Manchester is at 456 Market Street, Manchester, open 9am-5pm Monday-Friday."

**Detection:**
- Fabricated: Entire branch location
- Severity: High
- Action: Safe fallback + agent handover

**Fallback Response:**
"I apologize, but I want to make sure I give you accurate information. Let me connect you with a specialist who can help you find the nearest branch."

### Example 3: Domain Boundary Violation

**User Query:** "Should I invest in cryptocurrency?"

**Model Response (Hallucinated):**
"Cryptocurrency can be a good investment if you're willing to accept high risk. I recommend starting with Bitcoin or Ethereum..."

**Detection:**
- Domain violation: Investment advice
- Domain violation: Cryptocurrency discussion
- Severity: High
- Action: Safe fallback

**Fallback Response:**
"I'm here to help with account opening and banking services. For investment advice, I'd recommend speaking with a financial advisor."

## Troubleshooting

### High Hallucination Rate

**Symptoms:**
- CloudWatch alarm triggered
- Multiple hallucination logs in DynamoDB
- Customers reporting incorrect information

**Diagnosis:**
1. Check DynamoDB logs for patterns
2. Review tool responses for completeness
3. Examine system prompt for clarity
4. Check Bedrock model configuration

**Solutions:**
- Update system prompt with more explicit instructions
- Enhance tool responses with more complete data
- Adjust validation thresholds if too sensitive
- Consider model fine-tuning if persistent

### False Positives

**Symptoms:**
- Valid responses being flagged as hallucinations
- Regeneration happening unnecessarily
- Validation latency increasing

**Diagnosis:**
1. Review validation_details in DynamoDB logs
2. Check confidence scores
3. Examine tool result formats
4. Test validation logic with known-good responses

**Solutions:**
- Adjust confidence thresholds
- Update validation algorithms for edge cases
- Improve tool result formatting
- Add synonyms/variations to validation logic

### Validation Timeouts

**Symptoms:**
- ValidationTimeouts metric increasing
- Lambda timeouts
- Slow response times

**Diagnosis:**
1. Check ValidationLatency metric
2. Review Lambda execution time
3. Examine validation algorithm complexity
4. Check DynamoDB write latency

**Solutions:**
- Optimize validation algorithms
- Increase Lambda timeout (currently 60s)
- Add caching for repeated validations
- Parallelize validation checks

## Best Practices

### 1. Monitor Regularly
- Check CloudWatch dashboard daily
- Review hallucination logs weekly
- Analyze trends monthly

### 2. Update Tool Responses
- Ensure tools return complete information
- Use consistent formatting
- Include all relevant details

### 3. Refine System Prompts
- Be explicit about using only tool data
- Provide examples of correct behavior
- Update based on hallucination patterns

### 4. Test Thoroughly
- Test with edge cases
- Verify validation logic with known scenarios
- Perform regression testing after changes

### 5. Document Patterns
- Keep track of common hallucination types
- Document false positives
- Share learnings with team

## Configuration

### Enable/Disable Validation

Validation is controlled via environment variable:

```hcl
environment_variables = {
  ENABLE_HALLUCINATION_DETECTION = "true"  # Set to "false" to disable
}
```

**Note:** Disabling validation is NOT recommended for production.

### Adjust Severity Thresholds

Thresholds are defined in `validation_agent.py`:

```python
# Confidence score thresholds
LOW_SEVERITY_THRESHOLD = 0.9    # >90% match
MEDIUM_SEVERITY_THRESHOLD = 0.7  # 70-90% match
# <70% match = HIGH severity
```

### Customize Alarm Thresholds

Alarms are configured in `main.tf`:

```hcl
# High severity alarm
threshold = 10.0  # 10% hallucination rate

# Medium severity alarm
threshold = 5.0   # 5% hallucination rate
```

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Overall system architecture
- [README.md](README.md) - Deployment and configuration
- [QUEUE_MANAGEMENT.md](QUEUE_MANAGEMENT.md) - Queue and handover details
