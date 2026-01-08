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
