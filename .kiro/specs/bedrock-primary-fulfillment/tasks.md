# Implementation Plan

## Overview

This implementation plan transforms the Connect Comprehensive Stack from a Lex-centric fallback system to a Bedrock-primary fulfillment architecture with FastMCP 2.0 tools, natural conversation flow, seamless agent handover, and comprehensive queue management.

## Implementation Tasks

- [x] 1. Update Lambda function for Bedrock-primary architecture

  - Replace fallback-based logic with primary Bedrock invocation
  - Implement FastMCP 2.0 tool definitions and handlers
  - Add conversation history management
  - Add handover detection logic
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [x] 1.1 Update lambda_function.py with primary Bedrock invocation

  - Modify lambda_handler to extract input transcript and conversation history from Lex event
  - Update call_bedrock_with_tools function with enhanced system prompt for natural conversation
  - Implement tool_use response handling with async tool execution
  - Add conversation history serialization/deserialization for session attributes
  - Implement response formatting for Lex with proper sessionState structure
  - _Requirements: 1.1, 1.2, 1.3, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8, 12.9, 12.10_

- [x] 1.2 Implement FastMCP 2.0 tool definitions

  - Define get_branch_account_opening_info tool with input schema and handler
  - Define get_digital_account_opening_info tool with input schema and handler
  - Define get_debit_card_info tool with input schema and handler
  - Define find_nearest_branch tool with input schema and handler
  - Implement tool registration with MCP server
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 1.3 Implement tool handler functions

  - Create get_branch_account_opening_info async function returning structured account opening data
  - Create get_digital_account_opening_info async function returning digital channel data
  - Create get_debit_card_info async function returning card information
  - Create find_nearest_branch async function with location-based branch lookup
  - Ensure all handlers return List[TextContent] format for MCP compatibility
  - _Requirements: 2.2, 2.3, 2.4, 2.5, 2.6, 3.6_

- [x] 1.4 Implement handover detection logic

  - Create detect_handover_need function analyzing conversation for handover triggers
  - Implement explicit agent request detection (keywords: "agent", "human", "person")
  - Implement frustration detection (keywords: "frustrated", "annoyed", "useless")
  - Implement repeated query detection (same intent 3+ times)
  - Implement capability limitation detection from Bedrock response
  - Implement tool failure counting and threshold checking
  - _Requirements: 11.1, 11.9, 11.15_

- [x] 1.5 Implement agent handover execution

  - Create initiate_agent_handover function formatting conversation summary
  - Implement conversation context extraction (main query, topics, collected info)
  - Implement queue determination logic based on handover reason
  - Format Lex response with TransferToAgent intent and session attributes
  - Add handover message selection based on reason
  - _Requirements: 11.2, 11.3, 11.4, 11.5, 11.6, 11.14_

- [x] 2. Implement validation agent for hallucination detection

  - Create ValidationAgent class with validation methods
  - Implement fabricated data detection
  - Implement domain boundary checking
  - Implement document accuracy validation
  - Implement branch information validation
  - Add hallucination logging to DynamoDB
  - Add CloudWatch metrics publishing
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 10.10_

- [x] 2.1 Create ValidationAgent class structure

  - Define ValidationAgent class with **init** method
  - Add validate_response main entry point method
  - Add check_fabricated_data method
  - Add check_domain_boundaries method
  - Add check_document_accuracy method
  - Add check_branch_accuracy method
  - Add log_hallucination method
  - Add publish_metrics method
  - _Requirements: 10.1, 10.2, 10.6, 10.7_

- [x] 2.2 Implement hallucination detection algorithms

  - Extract key facts from model response (documents, steps, timelines, branch info)
  - Compare extracted facts against tool results
  - Flag information not present in tool data
  - Check response against allowed domain topics
  - Calculate confidence scores for validation
  - _Requirements: 10.2, 10.3, 10.6_

- [x] 2.3 Implement hallucination response strategy

  - Define severity levels (low, medium, high)
  - Implement high severity handling (safe fallback message)
  - Implement medium severity handling (regeneration with stricter constraints)
  - Implement low severity handling (log and continue)
  - Add regeneration logic with updated system prompt
  - _Requirements: 10.3, 10.9_

- [x] 2.4 Implement hallucination logging

  - Create DynamoDB put_item calls with hallucination data structure
  - Include log_id, timestamp, user_query, tool_results, model_response
  - Include hallucination_type, severity, validation_details, action_taken
  - Include session_id and TTL for 90-day retention
  - Handle DynamoDB write failures gracefully
  - _Requirements: 10.4, 10.5_

- [x] 2.5 Implement validation metrics

  - Publish HallucinationDetectionRate metric to CloudWatch
  - Publish ValidationSuccessRate metric to CloudWatch
  - Publish ValidationLatency metric to CloudWatch
  - Include dimensions for hallucination_type and severity
  - Handle CloudWatch API failures gracefully
  - _Requirements: 10.7_

- [x] 3. Update Terraform configuration for Lambda

  - Update Lambda source directory to bedrock_mcp
  - Add FastMCP 2.0 library to requirements.txt
  - Update Lambda environment variables
  - Add DynamoDB permissions for hallucination logs
  - Update IAM role policies
  - _Requirements: 13.1, 13.2, 13.3, 13.6, 13.8_

- [x] 3.1 Update Lambda module configuration in main.tf

  - Change bedrock_mcp_lambda source_dir variable to lambda/bedrock_mcp
  - Update handler to lambda_function.lambda_handler
  - Update runtime to python3.11
  - Update timeout to 60 seconds
  - Ensure archive_file data source points to correct directory
  - _Requirements: 13.8_

- [x] 3.2 Create requirements.txt for Lambda

  - Add fastmcp==2.0.0 dependency
  - Add boto3 (latest version)
  - Add any other required dependencies
  - Place in lambda/bedrock_mcp/ directory
  - _Requirements: 13.8_

- [x] 3.3 Update Lambda environment variables

  - Set BEDROCK_MODEL_ID to anthropic.claude-3-5-sonnet-20241022-v2:0
  - Set AWS_REGION to var.region
  - Set LOG_LEVEL to INFO
  - Set ENABLE_HALLUCINATION_DETECTION to true
  - Set HALLUCINATION_TABLE_NAME to hallucination logs table name
  - _Requirements: 13.6_

- [x] 3.4 Update Lambda IAM role policies

  - Add bedrock:InvokeModel permission for Claude 3.5 Sonnet
  - Add dynamodb:PutItem permission for hallucination logs table
  - Add cloudwatch:PutMetricData permission for validation metrics
  - Ensure logs:CreateLogGroup, logs:CreateLogStream, logs:PutLogEvents permissions exist
  - _Requirements: 13.1, 13.2, 13.3_

- [x] 4. Simplify Lex bot configuration

  - Remove complex intent definitions
  - Configure single FallbackIntent
  - Update Lambda association
  - Update bot alias configuration
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 4.1 Remove existing intent definitions from variables.tf

  - Comment out or remove lex_intents variable with all intent definitions
  - Keep only FallbackIntent configuration
  - Update variable description to reflect simplified architecture
  - _Requirements: 4.1_

- [x] 4.2 Update Lex bot resource in main.tf

  - Remove aws_lexv2models_intent.intents resource block
  - Remove aws_lexv2models_intent.intents_en_us resource block
  - Keep only FallbackIntent (created by module)
  - Update bot build trigger to remove intents_hash dependency
  - _Requirements: 4.1, 4.2_

- [x] 4.3 Update bot locale build script

  - Modify null_resource.build_bot_locales to build with FallbackIntent only
  - Remove intent validation loops
  - Simplify build process
  - _Requirements: 4.2_

- [x] 4.4 Verify Lambda permission for Lex invocation

  - Ensure aws_lambda_permission.lex_invoke exists
  - Verify source_arn includes correct bot alias pattern
  - Verify principal is lexv2.amazonaws.com
  - _Requirements: 4.3, 13.4_

- [x] 5. Create simplified contact flow with input preservation

  - Create new contact flow template
  - Implement greeting via Lex connection
  - Add intent checking logic
  - Add error handling with agent transfer
  - Add queue management
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 5.10_

- [x] 5.1 Create primary contact flow template

  - Create contact_flows/bedrock_primary_flow.json.tftpl
  - Implement connect-to-lex action with inline greeting text
  - Implement check-intent action to detect TransferToAgent
  - Implement error-handler action with professional message
  - Implement transfer-to-agent action with queue routing
  - Implement disconnect action
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.8, 11.10, 11.11, 11.12_

- [x] 5.2 Add intent checking logic to contact flow

  - Add CheckAttribute action comparing IntentName to TransferToAgent
  - Route to transfer-to-agent if match
  - Route to disconnect if no match (normal completion)
  - Handle NoMatchingCondition error by routing to disconnect
  - _Requirements: 5.4, 11.1, 11.2, 11.14_

- [x] 5.3 Implement error handling in contact flow

  - Catch NoMatchingError from connect-to-lex
  - Catch NoMatchingCondition from connect-to-lex
  - Route all errors to error-handler action
  - Error-handler displays professional message without technical details
  - Error-handler routes to transfer-to-agent
  - _Requirements: 5.8, 11.10, 11.11, 11.12, 11.16, 11.17, 11.18_

- [x] 5.4 Create contact flow resource in main.tf

  - Add aws_connect_contact_flow resource for bedrock_primary_flow
  - Use templatefile to inject lex_bot_alias_arn and general_agent_queue_arn
  - Set type to "CONTACT_FLOW"
  - Set description explaining Bedrock-primary architecture
  - Add depends_on for Lex bot alias and queue
  - _Requirements: 5.1, 5.2, 5.3, 13.5_

- [x] 6. Implement customer queue flow for wait management

  - Create customer queue flow template
  - Implement position checking and updates
  - Implement callback option
  - Implement hold music and comfort messages
  - Implement after-hours handling
  - _Requirements: 11.7, 11.8, 11.9, 11.10, 11.11, 11.12, 11.13_

- [x] 6.1 Create customer queue flow template

  - Create contact_flows/customer_queue_flow.json.tftpl
  - Implement initial-message action with thank you message
  - Implement check-queue-position action
  - Implement next-in-line-message for position 1
  - Implement position-message with dynamic position and wait time
  - Implement offer-callback action with input collection
  - Implement play-hold-music action
  - Implement wait-30-seconds action
  - Implement comfort-message action
  - Create loop back to check-queue-position
  - _Requirements: 11.7, 11.8, 11.9, 11.12_

- [x] 6.2 Implement callback flow logic

  - Add callback-flow action invoking Lambda function
  - Add collect-callback-number action for phone number input
  - Add callback-confirmation action with confirmation message
  - Add goodbye-message action for call end
  - Route callback choice to callback flow
  - _Requirements: 11.9, 11.11_

- [x] 6.3 Implement after-hours handling

  - Add check-hours-of-operation action before queueing
  - Add after-hours-message action explaining hours
  - Add get-callback-choice action for after-hours callback
  - Route to callback collection if chosen
  - Route to goodbye if declined
  - _Requirements: 11.7, 11.9_

- [x] 6.4 Create customer queue flow resource in main.tf

  - Add aws_connect_contact_flow resource for customer_queue_flow
  - Set type to "CUSTOMER_QUEUE"
  - Use templatefile to inject hold_music_arn and callback_lambda_arn
  - Add depends_on for Lambda function and prompts
  - _Requirements: 11.7, 11.8_

- [x] 6.5 Associate customer queue flow with queue

  - Update aws_connect_queue.general_agent_queue configuration
  - Set max_contacts to 0 (unlimited queue size)
  - Configure outbound_caller_config
  - Note: Queue flow association may need AWS CLI command in null_resource
  - _Requirements: 11.7, 11.13_

- [x] 7. Create callback Lambda function

  - Implement Lambda handler for callback requests
  - Add DynamoDB table for callback storage
  - Implement callback scheduling logic
  - Add IAM permissions
  - _Requirements: 11.9, 11.11_

- [x] 7.1 Create callback Lambda function code

  - Create lambda/callback_handler/lambda_function.py
  - Implement lambda_handler extracting customer phone and contact ID
  - Implement DynamoDB put_item for callback request storage
  - Include callback_id, contact_id, customer_phone, requested_at, status, queue_id
  - Return success response with callback_scheduled flag
  - _Requirements: 11.9, 11.11_

- [x] 7.2 Create DynamoDB table for callbacks

  - Add module.callback_table using dynamodb module
  - Set hash_key to callback_id
  - Set range_key to requested_at
  - Enable TTL with 7-day retention
  - Add GSI on status for querying pending callbacks
  - _Requirements: 11.11_

- [x] 7.3 Create callback Lambda resource in main.tf

  - Add data.archive_file.callback_zip for Lambda package
  - Add aws_iam_role.callback_lambda_role with assume role policy
  - Add aws_iam_role_policy.callback_lambda_policy with DynamoDB permissions
  - Add module.callback_lambda using lambda module
  - Set environment variables for callback table name
  - _Requirements: 11.9, 11.11_

- [x] 8. Create DynamoDB table for hallucination logs

  - Define table schema
  - Create Terraform resource
  - Configure TTL and indexes
  - _Requirements: 10.4, 10.5, 13.9_

- [x] 8.1 Create hallucination logs table resource

  - Add module.hallucination_logs_table using dynamodb module
  - Set hash_key to log_id
  - Set range_key to timestamp
  - Enable TTL with ttl_attribute_name set to ttl (90-day retention)
  - Add GSI on hallucination_type for analysis queries
  - Add GSI on timestamp for time-series queries
  - _Requirements: 10.4, 10.5, 13.9_

- [x] 9. Configure CloudWatch alarms for monitoring

  - Create alarms for hallucination detection rate
  - Create alarms for error rates
  - Create alarms for queue metrics
  - Create dashboard for validation metrics
  - _Requirements: 10.7, 13.10_

- [x] 9.1 Create hallucination detection alarms

  - Add aws_cloudwatch_metric_alarm for HallucinationDetectionRate > 10% (5-min window)
  - Add aws_cloudwatch_metric_alarm for HallucinationDetectionRate > 5% (15-min window)
  - Set alarm actions to SNS topic for notifications
  - _Requirements: 10.7, 13.10_

- [x] 9.2 Create error rate alarms

  - Add aws_cloudwatch_metric_alarm for Lambda error rate > 5% (5-min window)
  - Add aws_cloudwatch_metric_alarm for Bedrock API errors > 10/hour
  - Add aws_cloudwatch_metric_alarm for validation timeouts > 5/hour
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 9.3 Create queue management alarms

  - Add aws_cloudwatch_metric_alarm for queue size > 10 (5-min window)
  - Add aws_cloudwatch_metric_alarm for average wait time > 5 minutes
  - Add aws_cloudwatch_metric_alarm for abandonment rate > 20%
  - _Requirements: 11.7, 11.8_

- [x] 9.4 Create CloudWatch dashboard

  - Add aws_cloudwatch_dashboard resource
  - Include widgets for hallucination metrics
  - Include widgets for conversation metrics
  - Include widgets for queue metrics
  - Include widgets for error rates
  - _Requirements: 10.7_

- [x] 10. Remove deprecated components

  - Remove old fallback Lambda code
  - Remove complex Lex intent definitions
  - Remove old contact flow templates
  - Clean up unused variables
  - _Requirements: 4.1, 4.2_

- [x] 10.1 Remove old Lambda code files

  - Delete lambda/lex_fallback/lex_handler.py
  - Delete lambda/lex_fallback/fulfillment.py
  - Delete lambda/lex_fallback/validation.py
  - Delete lambda/lex_fallback/utils.py
  - Keep only lambda/bedrock_mcp/lambda_function.py
  - _Requirements: 1.1_

- [x] 10.2 Remove old contact flow templates

  - Delete contact_flows/main_flow.json.tftpl (if not used)
  - Delete contact_flows/voice_ivr_flow.json.tftpl (if not used)
  - Delete contact_flows/auth_module_flow.json.tftpl (if not used)
  - Keep only bedrock_primary_flow.json.tftpl and customer_queue_flow.json.tftpl
  - _Requirements: 5.1_

- [x] 10.3 Clean up variables.tf

  - Remove lex_fallback_lambda variable (deprecated)
  - Remove enable_voice_id variable (not used in new architecture)
  - Remove enable_pin_validation variable (not used in new architecture)
  - Remove enable_companion_auth variable (not used in new architecture)
  - Remove mock_data variable (not used in new architecture)
  - Keep only bedrock_mcp_lambda variable
  - _Requirements: 4.1_

- [x] 10.4 Update outputs.tf

  - Remove outputs for deprecated resources
  - Add output for hallucination_logs_table_name
  - Add output for callback_table_name
  - Add output for bedrock_primary_flow_id
  - Add output for customer_queue_flow_id
  - _Requirements: 13.7_

- [x] 11. Update documentation

  - Update README.md with new architecture
  - Update ARCHITECTURE.md with Bedrock-primary design
  - Add HALLUCINATION_DETECTION.md guide
  - Add QUEUE_MANAGEMENT.md guide
  - _Requirements: All_

- [x] 11.1 Update README.md

  - Replace fallback architecture description with Bedrock-primary
  - Update features list to include FastMCP 2.0 tools
  - Update features list to include hallucination detection
  - Update features list to include seamless agent handover
  - Update deployment instructions if needed
  - Update configuration section with new variables
  - _Requirements: All_

- [x] 11.2 Update ARCHITECTURE.md

  - Replace architecture diagram with Bedrock-primary flow
  - Update component descriptions for Lambda, Lex, Contact Flow
  - Add section on FastMCP 2.0 tools
  - Add section on validation agent
  - Add section on queue management
  - Update data flow sequences
  - _Requirements: All_

- [x] 11.3 Create HALLUCINATION_DETECTION.md

  - Document validation agent architecture
  - Explain detection algorithms
  - Provide examples of detected hallucinations
  - Document response strategies
  - Explain logging and metrics
  - Provide troubleshooting guide
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 10.10_

- [x] 11.4 Create QUEUE_MANAGEMENT.md

  - Document queue configuration
  - Explain customer queue flow
  - Document callback functionality
  - Explain after-hours handling
  - Provide queue metrics guide
  - Provide troubleshooting guide
  - _Requirements: 11.7, 11.8, 11.9, 11.10, 11.11, 11.12, 11.13_

- [ ] 12. Write unit tests

  - Test Lambda handler functions
  - Test tool implementations
  - Test validation agent
  - Test handover detection
  - _Requirements: All_

- [ ] 12.1 Write Lambda handler tests

  - Test event parsing with valid Lex event
  - Test event parsing with invalid event format
  - Test conversation history retrieval and parsing
  - Test Bedrock invocation with tools
  - Test tool_use response handling
  - Test direct response handling
  - Test response formatting for Lex
  - Test error handling scenarios
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 8.1, 8.2, 8.3, 8.4, 8.5_

- [ ] 12.2 Write tool implementation tests

  - Test get_branch_account_opening_info with each account type
  - Test get_digital_account_opening_info with each account type
  - Test get_debit_card_info with each card type
  - Test find_nearest_branch with various locations
  - Test tool error handling with invalid parameters
  - Test tool response format compliance
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [ ] 12.3 Write validation agent tests

  - Test fabricated data detection with known hallucination examples
  - Test domain boundary checking with off-topic responses
  - Test document accuracy validation
  - Test branch information validation
  - Test hallucination logging
  - Test metrics publishing
  - Test false positive and false negative rates
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7_

- [ ] 12.4 Write handover detection tests

  - Test explicit agent request detection
  - Test frustration detection
  - Test repeated query detection
  - Test capability limitation detection
  - Test tool failure counting
  - Test handover message selection
  - _Requirements: 11.1, 11.2, 11.9, 11.15_

- [ ] 13. Perform integration testing

  - Test end-to-end conversation flow
  - Test agent handover scenarios
  - Test queue management
  - Test error scenarios
  - _Requirements: All_

- [ ] 13.1 Test end-to-end conversation flows

  - Test simple query without tools
  - Test tool-based query (account opening)
  - Test tool-based query (debit card info)
  - Test tool-based query (branch finder)
  - Test multi-turn conversation with context
  - Test conversation history persistence
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [ ] 13.2 Test agent handover scenarios

  - Test explicit agent request
  - Test frustration-based handover
  - Test capability limitation handover
  - Test error-based handover
  - Test conversation context passing to agent
  - Test handover message delivery
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.14, 11.15, 11.16, 11.17, 11.18_

- [ ] 13.3 Test queue management scenarios

  - Test queue entry with available agents
  - Test queue entry with no available agents
  - Test position updates during wait
  - Test callback request flow
  - Test after-hours handling
  - Test queue full scenarios
  - _Requirements: 11.7, 11.8, 11.9, 11.10, 11.11, 11.12, 11.13_

- [ ] 13.4 Test error and edge case scenarios

  - Test Bedrock API errors
  - Test tool execution errors
  - Test validation errors
  - Test Lex integration errors
  - Test timeout scenarios
  - Test hallucination detection and recovery
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 10.1, 10.2, 10.3, 10.9, 10.10_

- [ ] 14. Implement comprehensive audit and monitoring

  - Implement structured logging in Lambda
  - Verify S3 storage configuration for recordings and transcripts
  - Add Contact Trace Records storage configuration
  - Configure S3 lifecycle policies
  - Configure CloudTrail for S3 access auditing
  - Implement PII redaction capability (optional)
  - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7, 13.8, 13.9, 13.10, 13.11, 13.12_

- [ ] 14.1 Implement StructuredLogger class in Lambda

  - Create StructuredLogger class with session_id and contact_id initialization
  - Implement log_event method with JSON formatting
  - Implement log_conversation_start method
  - Implement log_user_input method
  - Implement log_bedrock_invocation method
  - Implement log_bedrock_response method
  - Implement log_tool_invocation method
  - Implement log_validation_check method
  - Implement log_handover_decision method
  - Implement log_conversation_end method
  - _Requirements: 13.1, 13.2, 13.3, 13.7_

- [ ] 14.2 Integrate structured logging into lambda_handler

  - Initialize StructuredLogger at start of lambda_handler
  - Log conversation_start event with channel and customer info
  - Log user_input event for each user message
  - Log bedrock_invocation event before calling Bedrock
  - Log bedrock_response event after receiving Bedrock response
  - Log tool_invocation event for each tool call
  - Log validation_check event after validation
  - Log handover_decision event when handover is triggered
  - Log conversation_end event with metrics
  - _Requirements: 13.1, 13.2, 13.3, 13.7, 13.12_

- [x] 14.3 Verify and enhance S3 storage configuration

  - Verify aws_connect_instance_storage_config.chat_transcripts exists
  - Verify aws_connect_instance_storage_config.call_recordings exists
  - Add aws_connect_instance_storage_config.contact_trace_records
  - Verify KMS encryption is configured for all storage configs
  - Verify bucket prefixes are set correctly
  - _Requirements: 13.4, 13.5, 13.6, 13.10, 14.11, 14.12_

- [ ] 14.4 Configure S3 lifecycle policies

  - Add aws_s3_bucket_lifecycle_configuration resource
  - Configure rule for call-recordings: 90 days → Glacier, 7 years expiration
  - Configure rule for chat-transcripts: 90 days → Glacier, 7 years expiration
  - Configure rule for contact-trace-records: 90 days expiration
  - Verify lifecycle policies are applied correctly
  - _Requirements: 13.9, 14.13_

- [ ] 14.5 Configure CloudTrail for S3 auditing

  - Create aws_s3_bucket.cloudtrail_logs resource
  - Configure KMS encryption for CloudTrail bucket
  - Create aws_s3_bucket_policy.cloudtrail_policy allowing CloudTrail writes
  - Create aws_cloudtrail.connect_storage_trail resource
  - Configure data event selector for Connect storage bucket
  - Enable logging and verify trail is active
  - _Requirements: 13.11, 14.14_

- [ ] 14.6 Implement PII redaction capability (optional)

  - Create redact_pii function using Amazon Comprehend
  - Add ENABLE_PII_REDACTION environment variable
  - Add comprehend:DetectPiiEntities permission to Lambda IAM role
  - Integrate PII redaction into logging functions
  - Test PII redaction with sample data
  - _Requirements: 13.8_

- [ ] 14.7 Create CloudWatch Logs Insights queries

  - Document query for finding handover conversations
  - Document query for finding tool invocations by session
  - Document query for finding hallucination detections
  - Document query for calculating average conversation duration
  - Document query for finding most used tools
  - Add queries to documentation
  - _Requirements: 13.1, 13.2, 13.3, 13.7_

- [ ] 15. Deploy and validate

  - Deploy to development environment
  - Perform smoke tests
  - Monitor metrics and logs
  - Validate audit logging
  - Deploy to production
  - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7, 14.8, 14.9, 14.10, 14.11, 14.12, 14.13, 14.14_

- [ ] 15.1 Deploy to development environment

  - Run terraform plan to review changes
  - Run terraform apply to deploy stack
  - Verify all resources created successfully
  - Check CloudWatch logs for Lambda initialization
  - Verify Lex bot built successfully
  - Verify contact flows published
  - Verify S3 buckets created with encryption
  - Verify CloudTrail enabled and logging
  - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7, 14.8, 14.9, 14.10, 14.11, 14.12, 14.13, 14.14_

- [ ] 15.2 Perform smoke tests

  - Test basic conversation via Connect
  - Test tool invocation
  - Test agent handover
  - Test queue management
  - Verify hallucination detection logging
  - Check CloudWatch metrics
  - _Requirements: All_

- [ ] 15.3 Validate audit logging

  - Verify structured logs appear in CloudWatch
  - Verify all event types are logged correctly
  - Verify conversation transcripts stored in S3
  - Verify call recordings stored in S3 (if voice enabled)
  - Verify Contact Trace Records stored in S3
  - Verify CloudTrail logs S3 access events
  - Run CloudWatch Logs Insights queries to validate data
  - Verify log retention policies are applied
  - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7, 13.9, 13.11_

- [ ] 15.4 Monitor and validate metrics

  - Monitor HallucinationDetectionRate metric
  - Monitor conversation completion rate
  - Monitor handover rate and reasons
  - Monitor queue metrics
  - Monitor error rates
  - Review CloudWatch logs for issues
  - Verify conversation metrics (duration, turns, tools_used, resolution_status)
  - _Requirements: 10.7, 11.19, 13.12_

- [ ] 15.5 Production deployment
  - Create production deployment plan
  - Schedule deployment window
  - Deploy to production with terraform apply
  - Monitor metrics closely for first 24 hours
  - Monitor audit logs for completeness
  - Verify S3 storage is receiving recordings and transcripts
  - Have rollback plan ready
  - Document any issues and resolutions
  - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7, 14.8, 14.9, 14.10, 14.11, 14.12, 14.13, 14.14_
