# Athena SQL Queries for Amazon Connect Data Lake

Once your Amazon Connect data is flowing into the Data Lake (S3 -> Glue/Athena), you can use the following standard SQL queries to analyze your contact center performance.

## Table Structure
* **Database**: `<project_name>_datalake` (e.g., `connect_comprehensive_datalake`)
* **Tables**:
  * `ctrs`: Contact Trace Records (Voice and Chat)
  * `agent_events`: Agent status changes and activity

## Metric Calculation Queries

### 1. Total Contact Volume by Queue (Daily)
Count the number of contacts handled per queue for each day.

```sql
SELECT
    DATE_PARSE(substring(InitiationTimestamp, 1, 19), '%Y-%m-%dT%H:%i:%s') AS ContactDate,
    Queue.Name AS QueueName,
    COUNT(ContactId) AS TotalContacts
FROM "connect_comprehensive_datalake"."ctrs"
WHERE InitiationTimestamp IS NOT NULL
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC;
```

### 2. Average Handle Time (AHT) by Agent
Calculate the average time an agent spends talking and doing After Contact Work (ACW).

```sql
SELECT
    Agent.Username AS AgentName,
    AVG(Agent.AgentInteractionDuration) AS AvgTalkTime,
    AVG(Agent.AfterContactWorkDuration) AS AvgACWTime,
    AVG(Agent.AgentInteractionDuration + Agent.AfterContactWorkDuration) AS AHT
FROM "connect_comprehensive_datalake"."ctrs"
WHERE Agent.Username IS NOT NULL
GROUP BY 1
ORDER BY 4 DESC;
```

### 3. Abandonment Rate by Queue
Calculate the percentage of calls that were disconnected before reaching an agent.

```sql
SELECT
    Queue.Name AS QueueName,
    COUNT(ContactId) AS TotalOffered,
    COUNT(CASE WHEN Agent.ConnectedToAgentTimestamp IS NULL AND DisconnectTimestamp IS NOT NULL THEN 1 END) AS Abandoned,
    (CAST(COUNT(CASE WHEN Agent.ConnectedToAgentTimestamp IS NULL AND DisconnectTimestamp IS NOT NULL THEN 1 END) AS DOUBLE) / COUNT(ContactId)) * 100 AS AbandonmentRate
FROM "connect_comprehensive_datalake"."ctrs"
WHERE Channel = 'VOICE'
GROUP BY 1;
```

### 4. Agent Login Duration (from Agent Events)
Estimate how long agents are logged in based on event streams (Simplistic view).

```sql
SELECT
    AgentARN,
    MIN(EventTimestamp) as LoginTime,
    MAX(EventTimestamp) as LogoutTime,
    date_diff('minute', from_iso8601_timestamp(MIN(EventTimestamp)), from_iso8601_timestamp(MAX(EventTimestamp))) as SessionDurationMinutes
FROM "connect_comprehensive_datalake"."agent_events"
WHERE EventType IN ('LOGIN', 'LOGOUT', 'STATE_CHANGE')
GROUP BY AgentARN, SUBSTR(EventTimestamp, 1, 10);
```

### 5. Transfer Rate Analysis
Identify contacts that were transferred.

```sql
SELECT
    COUNT(ContactId) AS TotalContacts,
    COUNT(CASE WHEN TransferCompletedTimestamp IS NOT NULL THEN 1 END) AS TransferredContacts,
    (CAST(COUNT(CASE WHEN TransferCompletedTimestamp IS NOT NULL THEN 1 END) AS DOUBLE) / COUNT(ContactId)) * 100 AS TransferRate
FROM "connect_comprehensive_datalake"."ctrs"
```

## QuickSight Visualization
You can connect Amazon QuickSight to these Athena tables directly.
1. Go to **QuickSight** -> **Datasets** -> **New Dataset**.
2. Select **Athena**.
3. Choose the `connect_comprehensive_datalake` database.
4. Select `ctrs` table.
5. Create an analysis to visualize:
   - **Line Chart**: Contacts over time.
   - **Bar Chart**: AHT by Agent.
   - **KPI**: Total Calls Today.

## AI & Hallucination Analytics (New)

The `ai_insights` table captures real-time validation results from the Generative AI agents.

### 4. Hallucination Rate & Validation Success
Monitor the percentage of AI responses that passed validation versus those flagged as hallucinations.

```sql
SELECT
    DATE_PARSE(substring(timestamp, 1, 10), '%Y-%m-%d') AS Date,
    COUNT(*) AS TotalResponses,
    SUM(CASE WHEN validation_success = true THEN 1 ELSE 0 END) AS ValidResponses,
    SUM(CASE WHEN hallucination_detected = true THEN 1 ELSE 0 END) AS Hallucinations,
    SUM(CASE WHEN security_violation = true THEN 1 ELSE 0 END) AS SecurityViolations,
    (CAST(SUM(CASE WHEN hallucination_detected = true THEN 1 ELSE 0 END) AS DOUBLE) / COUNT(*)) * 100 AS HallucinationRate
FROM "connect_comprehensive_datalake"."ai_insights"
GROUP BY 1
ORDER BY 1 DESC;
```

### 5. AI Latency Performance
Analyze the added latency introduced by the validation layer.

```sql
SELECT
    DATE_PARSE(substring(timestamp, 1, 13), '%Y-%m-%dT%H') AS Hour,
    AVG(latency_ms) AS AvgLatencyMs,
    APPROX_PERCENTILE(latency_ms, 0.95) AS P95LatencyMs,
    MAX(latency_ms) AS MaxLatencyMs
FROM "connect_comprehensive_datalake"."ai_insights"
GROUP BY 1
ORDER BY 1 DESC;
```

### 6. Recent Security Violations
Investigate potential data leakage or security attempts.

```sql
SELECT
    timestamp,
    request_id,
    user_query,
    model_response,
    validation_details
FROM "connect_comprehensive_datalake"."ai_insights"
WHERE security_violation = true
ORDER BY timestamp DESC
LIMIT 10;
```

## Advanced Contact Lens Analytics

### 7. Agent Quality: Sentiment & Interruptions
Identify calls where the customer was unhappy but the agent interrupted frequently (Potential Training Need).

```sql
SELECT 
    cl.ContactId,
    ctr.Agent.Username,
    cl.Sentiment.OverallSentiment.Customer AS CustomerSentiment,
    cl.ConversationCharacteristics.Interruptions.TotalCount AS Interruptions,
    cl.Categories.MatchedCategories[1] AS PrimaryCategory
FROM "connect_comprehensive_datalake"."contact_lens_analysis" cl
JOIN "connect_comprehensive_datalake"."ctrs" ctr ON cl.ContactId = ctr.ContactId
WHERE cl.Sentiment.OverallSentiment.Customer < 0 
AND cl.ConversationCharacteristics.Interruptions.TotalCount > 3
ORDER BY CustomerSentiment ASC;
```


### 6. IVR Containment vs Agent Transfer
Analyze how many contacts were resolved in the IVR versus transferred to an agent.

```sql
SELECT
 	CASE
 		WHEN Agent.ConnectedToAgentTimestamp IS NULL AND Queue.EnqueueTimestamp IS NULL THEN 'Self-Served / Contained'
 		WHEN Agent.ConnectedToAgentTimestamp IS NULL AND Queue.EnqueueTimestamp IS NOT NULL THEN 'Abandoned in Queue'
 		WHEN Agent.ConnectedToAgentTimestamp IS NOT NULL THEN 'Agent Handled'
 		ELSE 'Other'
 	END AS JourneyOutcome,
 	COUNT(ContactId) AS Count,
 	(CAST(COUNT(ContactId) AS DOUBLE) * 100.0 / SUM(COUNT(ContactId)) OVER()) AS Percentage
FROM "connect_comprehensive_datalake"."ctrs"
GROUP BY 1
ORDER BY 2 DESC;
```

### 7. Customer Journey Fallout
Identify where customers are dropping off based on disconnect reasons.

```sql
SELECT
    DisconnectReason,
    COUNT(ContactId) AS Count,
    (CAST(COUNT(ContactId) AS DOUBLE) * 100.0 / SUM(COUNT(ContactId)) OVER()) AS Percentage
FROM "connect_comprehensive_datalake"."ctrs"
WHERE Agent.ConnectedToAgentTimestamp IS NULL -- Only look at calls that didn't reach an agent
GROUP BY 1
ORDER BY 2 DESC;
```

## Lifecycle & Live Metrics (Real-Time Events)

The `lifecycle_events` table captures granular `Amazon Connect Contact Event` data (e.g., Queued, Connected, Disconnected) in real-time.

### 8. Live Queue Backlog (Point-in-Time)
Calculate the current number of queued contacts by comparing 'Queued' events vs 'Endpoints' (Connected/Disconnected) in a time window.
*Note: Athena is eventually consistent. For true real-time, consider DynamoDB streams.*

```sql
SELECT 
    detail.queueInfo.queueArn,
    SUM(CASE WHEN detail_type = 'Contact Queued' THEN 1 ELSE 0 END) AS ContactsQueued,
    SUM(CASE WHEN detail_type IN ('Contact Connected to Agent', 'Contact Disconnected') THEN 1 ELSE 0 END) AS ContactsProcessed,
    (SUM(CASE WHEN detail_type = 'Contact Queued' THEN 1 ELSE 0 END) - 
     SUM(CASE WHEN detail_type IN ('Contact Connected to Agent', 'Contact Disconnected') THEN 1 ELSE 0 END)) AS EstimatedBacklog
FROM "connect_comprehensive_datalake"."lifecycle_events"
WHERE time > to_iso8601(current_timestamp - interval '1' hour) -- Look at last hour activity
GROUP BY detail.queueInfo.queueArn
```

### 9. Task Creation & Completion
Monitor Task interactions specifically.

```sql
SELECT
    InitiationMethod,
    COUNT(ContactId) AS TotalTasks,
    COUNT(CASE WHEN DisconnectReason = 'CONTACT_FLOW_DISCONNECT' THEN 1 END) AS SystemCompleted,
    COUNT(CASE WHEN Agent.ConnectedToAgentTimestamp IS NOT NULL THEN 1 END) AS AgentHandled
FROM "connect_comprehensive_datalake"."ctrs"
WHERE InitiationMethod = 'TASK'
GROUP BY 1;
```
