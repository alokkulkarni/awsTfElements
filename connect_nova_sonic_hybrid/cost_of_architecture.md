# Cost Analysis: Connect Nova Sonic Hybrid Architecture

**Date:** December 1, 2025  
**Region:** Europe (London) - `eu-west-2`  
**Currency:** USD ($)

## 1. Executive Summary

This architecture leverages a **Serverless** and **Pay-As-You-Go** model. The fixed monthly costs are minimal (primarily KMS keys and phone numbers), while the majority of the cost is driven directly by traffic volume (minutes of calls, number of chat messages, and AI model tokens).

This document provides a detailed breakdown of fixed costs, variable unit costs, and projected monthly/yearly costs across four workload scenarios: **Low**, **Medium**, **High**, and **Very High**.

---

## 2. Itemized Cost Breakdown

### A. Fixed Infrastructure Costs (Recurring)
These costs apply regardless of traffic volume.

| Service | Resource | Unit Cost | Qty | Monthly Cost |
| :--- | :--- | :--- | :--- | :--- |
| **AWS KMS** | Customer Managed Key (`log_key`) | $1.00 / key | 1 | **$1.00** |
| **Amazon Connect** | DID Phone Number | ~$4.00 / month | 1 | **$4.00** |
| **DynamoDB** | `tf_locks` (Provisioned 5 RCU/5 WCU) | ~$2.90 / month | 1 | **$2.90** |
| **S3** | State Bucket & Logs Storage (< 1GB) | $0.023 / GB | 1 | **$0.02** |
| **Total Fixed** | | | | **~$7.92** |

### B. Variable Traffic Costs (Per Unit)
These costs are incurred per interaction.

| Service | Metric | Unit Price (Est.) | Notes |
| :--- | :--- | :--- | :--- |
| **Amazon Connect** | Voice Usage (Inbound) | $0.018 / minute | |
| **Amazon Connect** | Contact Lens (Analytics) | $0.015 / minute | Optional (High impact) |
| **Amazon Lex** | Text Request | $0.004 / request | |
| **Amazon Lex** | Speech Request | $0.004 / request | |
| **AWS Lambda** | Invocation (512MB, 1s avg) | ~$0.0000083 / inv | |
| **Bedrock (Haiku)** | Input Tokens (1k) | $0.00025 | Chat Model |
| **Bedrock (Haiku)** | Output Tokens (1k) | $0.00125 | Chat Model |
| **Bedrock (Nova)** | Input Tokens (1k) | ~$0.0008 (Est.) | Voice Model |
| **Bedrock (Nova)** | Output Tokens (1k) | ~$0.0032 (Est.) | Voice Model |
| **DynamoDB** | Write Request (1M) | $1.25 | Context Storage |

---

## 3. Workload Scenarios & Projections

We define the following scenarios for estimation:

*   **Low:** 100 calls/mo, 100 chat sessions/mo.
*   **Medium:** 1,000 calls/mo, 1,000 chat sessions/mo.
*   **High:** 10,000 calls/mo, 10,000 chat sessions/mo.
*   **Very High:** 100,000 calls/mo, 100,000 chat sessions/mo.

**Assumptions:**
*   **Voice Call:** 5 minutes average duration.
*   **Chat Session:** 20 turns (messages) per session.
*   **AI Usage:** Every call/chat utilizes Bedrock for intent/fulfillment.

### Scenario 1: Low Workload
*Ideal for: PoC, Dev/Test environments, or small internal tools.*

| Category | Calculation | Monthly Cost |
| :--- | :--- | :--- |
| **Fixed Costs** | Base Infrastructure | $7.92 |
| **Voice (100 calls)** | (500 mins * $0.033) + AI overhead | ~$16.74 |
| **Chat (100 sessions)** | (2,000 reqs * $0.004) + AI overhead | ~$8.75 |
| **Total Monthly** | | **~$33.41** |
| **Total Yearly** | | **~$400.92** |

### Scenario 2: Medium Workload
*Ideal for: Small Business, Departmental Helpdesk.*

| Category | Calculation | Monthly Cost |
| :--- | :--- | :--- |
| **Fixed Costs** | Base Infrastructure | $7.92 |
| **Voice (1k calls)** | (5,000 mins * $0.033) + AI overhead | ~$167.41 |
| **Chat (1k sessions)** | (20,000 reqs * $0.004) + AI overhead | ~$87.70 |
| **Total Monthly** | | **~$263.03** |
| **Total Yearly** | | **~$3,156.36** |

### Scenario 3: High Workload
*Ideal for: Mid-sized Enterprise Customer Support.*

| Category | Calculation | Monthly Cost |
| :--- | :--- | :--- |
| **Fixed Costs** | Base Infrastructure | $7.92 |
| **Voice (10k calls)** | (50,000 mins * $0.033) + AI overhead | ~$1,674.10 |
| **Chat (10k sessions)** | (200,000 reqs * $0.004) + AI overhead | ~$877.00 |
| **Total Monthly** | | **~$2,559.02** |
| **Total Yearly** | | **~$30,708.24** |

### Scenario 4: Very High Workload
*Ideal for: Large Enterprise, High-Volume Call Center.*

| Category | Calculation | Monthly Cost |
| :--- | :--- | :--- |
| **Fixed Costs** | Base Infrastructure | $7.92 |
| **Voice (100k calls)** | (500,000 mins * $0.033) + AI overhead | ~$16,741.00 |
| **Chat (100k sessions)** | (2,000,000 reqs * $0.004) + AI overhead | ~$8,770.00 |
| **Total Monthly** | | **~$25,518.92** |
| **Total Yearly** | | **~$306,227.04** |

---

## 4. Cost Optimization Strategies

To optimize costs without breaking the architecture, consider the following strategies:

### A. Immediate Configuration Changes (No Code Change)

1.  **Disable Contact Lens (Dev/Test/Low Priority):**
    *   **Impact:** Saves **$0.015/min** (approx. 45% of voice costs).
    *   **Action:** Set `contact_lens_enabled = false` in `main.tf` for non-production environments.
    *   **Savings (High Workload):** Saves ~$750/month.

2.  **DynamoDB Capacity Mode:**
    *   The `tf_locks` table uses **Provisioned** capacity ($2.90/mo). For a lock table that is rarely accessed, switch to **On-Demand**.
    *   **Savings:** ~$2.50/month (negligible for high scale, good for dev).

3.  **Log Retention:**
    *   Set CloudWatch Log Groups retention to **7 or 14 days** instead of "Never Expire".
    *   **Savings:** Prevents storage costs from growing indefinitely.

### B. Architectural Amendments

1.  **Lex vs. Bedrock Router:**
    *   **Current:** Lex is used for intent detection ($0.004/req), then Lambda calls Bedrock.
    *   **Optimization:** For simple intents ("Talk to Sales"), use Lex's built-in NLU without invoking Lambda/Bedrock. Only fallback to Bedrock for complex queries.
    *   **Savings:** Reduces Bedrock token costs for routine queries.

2.  **Bedrock Model Selection:**
    *   **Current:** Uses `Claude 3 Haiku` and `Nova Sonic`.
    *   **Optimization:** Use **Amazon Titan** models for simpler summarization or classification tasks. They are significantly cheaper than Claude or Nova.
    *   **Implementation:** Add a variable to switch model IDs based on complexity.

3.  **Caching (DynamoDB/DAX):**
    *   **Current:** Every chat turn might invoke Bedrock with full context.
    *   **Optimization:** Cache common answers in DynamoDB. If a user asks a FAQ, serve from DynamoDB instead of invoking Bedrock.
    *   **Savings:** Reduces Bedrock invocation costs.

4.  **S3 Lifecycle Policies:**
    *   **Current:** Chat transcripts and recordings are stored in S3.
    *   **Optimization:** Add an S3 Lifecycle Rule to transition objects to **S3 Standard-IA** after 30 days and **Glacier** after 90 days.
    *   **Savings:** Reduces long-term storage costs by ~40-80%.
