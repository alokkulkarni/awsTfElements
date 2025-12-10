"""
Validation Agent for detecting and managing hallucinations in Bedrock responses.
"""
import json
import logging
import os
import re
import uuid
from datetime import datetime, timedelta
from typing import Any, Dict, List, Tuple
import boto3

logger = logging.getLogger()

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb', region_name=os.environ.get('AWS_REGION', 'eu-west-2'))
cloudwatch = boto3.client('cloudwatch', region_name=os.environ.get('AWS_REGION', 'eu-west-2'))


class ValidationAgent:
    """Agent for validating Bedrock responses and detecting hallucinations."""
    
    def __init__(self):
        """Initialize the validation agent."""
        self.enabled = os.environ.get('ENABLE_HALLUCINATION_DETECTION', 'true').lower() == 'true'
        self.table_name = os.environ.get('HALLUCINATION_TABLE_NAME', '')
        self.table = dynamodb.Table(self.table_name) if self.table_name else None
        
        # Allowed domain topics
        self.allowed_topics = [
            'account opening', 'checking account', 'savings account', 'business account', 'student account',
            'debit card', 'card ordering', 'branch location', 'branch finder',
            'documents required', 'identification', 'proof of address',
            'digital banking', 'online banking', 'mobile app'
        ]
    
    def validate_response(self, user_query: str, tool_results: Dict[str, Any], 
                         model_response: str, session_id: str = None) -> Tuple[bool, Dict[str, Any]]:
        """
        Main validation entry point.
        Returns: (is_valid: bool, validation_details: dict)
        """
        if not self.enabled:
            return (True, {"validation_enabled": False})
        
        validation_details = {
            "checks_performed": [],
            "issues_found": [],
            "confidence_score": 1.0,
            "severity": "none"
        }
        
        # Check for fabricated data
        fabricated_check = self.check_fabricated_data(tool_results, model_response)
        validation_details["checks_performed"].append("fabricated_data")
        if not fabricated_check["passed"]:
            validation_details["issues_found"].append(fabricated_check)
            validation_details["confidence_score"] *= 0.5
        
        # Check domain boundaries
        domain_check = self.check_domain_boundaries(model_response)
        validation_details["checks_performed"].append("domain_boundary")
        if not domain_check["passed"]:
            validation_details["issues_found"].append(domain_check)
            validation_details["confidence_score"] *= 0.7
        
        # Check document accuracy if tool results contain documents
        if tool_results and 'documents_required' in str(tool_results):
            doc_check = self.check_document_accuracy(tool_results, model_response)
            validation_details["checks_performed"].append("document_accuracy")
            if not doc_check["passed"]:
                validation_details["issues_found"].append(doc_check)
                validation_details["confidence_score"] *= 0.6
        
        # Check branch accuracy if tool results contain branch info
        if tool_results and 'branches' in str(tool_results):
            branch_check = self.check_branch_accuracy(tool_results, model_response)
            validation_details["checks_performed"].append("branch_accuracy")
            if not branch_check["passed"]:
                validation_details["issues_found"].append(branch_check)
                validation_details["confidence_score"] *= 0.6
        
        # Determine severity
        if len(validation_details["issues_found"]) == 0:
            validation_details["severity"] = "none"
            is_valid = True
        elif validation_details["confidence_score"] < 0.3:
            validation_details["severity"] = "high"
            is_valid = False
        elif validation_details["confidence_score"] < 0.6:
            validation_details["severity"] = "medium"
            is_valid = False
        else:
            validation_details["severity"] = "low"
            is_valid = True  # Allow but log
        
        # Log if hallucination detected
        if not is_valid or validation_details["severity"] != "none":
            self.log_hallucination(
                user_query=user_query,
                tool_results=tool_results,
                model_response=model_response,
                validation_details=validation_details,
                session_id=session_id
            )
        
        # Publish metrics
        self.publish_metrics(validation_details)
        
        return (is_valid, validation_details)
    
    def check_fabricated_data(self, tool_results: Dict[str, Any], model_response: str) -> Dict[str, Any]:
        """Detect information not present in tool results."""
        if not tool_results:
            return {"passed": True, "type": "fabricated_data"}
        
        # Convert tool results to string for searching
        tool_data_str = json.dumps(tool_results).lower()
        
        # Look for specific claims in the response
        fabricated_indicators = []
        
        # Check for specific document requirements mentioned in response but not in tool data
        doc_patterns = [
            r'proof of income', r'employment letter', r'tax returns', r'credit check',
            r'reference letter', r'guarantor', r'co-signer'
        ]
        
        for pattern in doc_patterns:
            if re.search(pattern, model_response.lower()) and pattern not in tool_data_str:
                fabricated_indicators.append(f"Mentioned '{pattern}' not in tool results")
        
        # Check for specific fees mentioned
        fee_patterns = [r'\£\d+', r'fee of', r'charge of', r'cost of']
        response_fees = []
        for pattern in fee_patterns:
            matches = re.findall(pattern, model_response.lower())
            response_fees.extend(matches)
        
        # Verify fees are in tool data
        for fee in response_fees:
            if fee not in tool_data_str and 'fee' in model_response.lower():
                fabricated_indicators.append(f"Mentioned fee '{fee}' not in tool results")
        
        passed = len(fabricated_indicators) == 0
        return {
            "passed": passed,
            "type": "fabricated_data",
            "details": fabricated_indicators if not passed else []
        }
    
    def check_domain_boundaries(self, model_response: str) -> Dict[str, Any]:
        """Ensure response stays within banking service domain."""
        response_lower = model_response.lower()
        
        # Topics that are out of scope
        off_topic_keywords = [
            'mortgage', 'loan application', 'credit card', 'investment', 'stocks',
            'insurance', 'pension', 'cryptocurrency', 'forex', 'trading'
        ]
        
        off_topic_found = []
        for keyword in off_topic_keywords:
            if keyword in response_lower:
                off_topic_found.append(keyword)
        
        passed = len(off_topic_found) == 0
        return {
            "passed": passed,
            "type": "domain_boundary",
            "details": off_topic_found if not passed else []
        }
    
    def check_document_accuracy(self, tool_results: Dict[str, Any], model_response: str) -> Dict[str, Any]:
        """Validate document requirements match tool data."""
        try:
            # Extract documents from tool results
            tool_data_str = json.dumps(tool_results)
            tool_data = json.loads(tool_data_str) if isinstance(tool_data_str, str) else tool_results
            
            documents_in_tool = []
            if 'documents_required' in str(tool_data):
                # Try to extract the documents list
                if isinstance(tool_data, dict) and 'documents_required' in tool_data:
                    documents_in_tool = tool_data['documents_required']
                elif isinstance(tool_data, str):
                    # Parse JSON string
                    parsed = json.loads(tool_data)
                    if 'documents_required' in parsed:
                        documents_in_tool = parsed['documents_required']
            
            if not documents_in_tool:
                return {"passed": True, "type": "document_accuracy"}
            
            # Check if response mentions documents not in the tool results
            response_lower = model_response.lower()
            tool_docs_lower = [doc.lower() for doc in documents_in_tool]
            
            # Common document types to check
            doc_types = [
                'passport', 'driving licence', 'photo id', 'proof of address',
                'utility bill', 'bank statement', 'national insurance',
                'student id', 'acceptance letter', 'business registration'
            ]
            
            mismatches = []
            for doc_type in doc_types:
                mentioned_in_response = doc_type in response_lower
                in_tool_results = any(doc_type in tool_doc for tool_doc in tool_docs_lower)
                
                if mentioned_in_response and not in_tool_results:
                    mismatches.append(f"'{doc_type}' mentioned but not in tool results")
            
            passed = len(mismatches) == 0
            return {
                "passed": passed,
                "type": "document_accuracy",
                "details": mismatches if not passed else []
            }
        except Exception as e:
            logger.error(f"Error checking document accuracy: {str(e)}")
            return {"passed": True, "type": "document_accuracy", "error": str(e)}
    
    def check_branch_accuracy(self, tool_results: Dict[str, Any], model_response: str) -> Dict[str, Any]:
        """Validate branch information matches tool data."""
        try:
            # Extract branch info from tool results
            tool_data_str = json.dumps(tool_results)
            
            # Check if response mentions specific branch details not in tool results
            response_lower = model_response.lower()
            
            # Look for phone numbers, addresses, hours
            phone_pattern = r'\d{3,4}\s?\d{3,4}\s?\d{4}'
            phones_in_response = re.findall(phone_pattern, model_response)
            
            mismatches = []
            for phone in phones_in_response:
                if phone not in tool_data_str:
                    mismatches.append(f"Phone number '{phone}' not in tool results")
            
            # Check for specific street names or postcodes
            postcode_pattern = r'[A-Z]{1,2}\d{1,2}\s?\d[A-Z]{2}'
            postcodes_in_response = re.findall(postcode_pattern, model_response)
            
            for postcode in postcodes_in_response:
                if postcode not in tool_data_str:
                    mismatches.append(f"Postcode '{postcode}' not in tool results")
            
            passed = len(mismatches) == 0
            return {
                "passed": passed,
                "type": "branch_accuracy",
                "details": mismatches if not passed else []
            }
        except Exception as e:
            logger.error(f"Error checking branch accuracy: {str(e)}")
            return {"passed": True, "type": "branch_accuracy", "error": str(e)}
    
    def log_hallucination(self, user_query: str, tool_results: Dict[str, Any],
                         model_response: str, validation_details: Dict[str, Any],
                         session_id: str = None):
        """Log detected hallucination to DynamoDB."""
        if not self.table:
            logger.warning("Hallucination table not configured, skipping log")
            return
        
        try:
            log_id = str(uuid.uuid4())
            timestamp = datetime.utcnow().isoformat() + 'Z'
            ttl = int((datetime.utcnow() + timedelta(days=90)).timestamp())
            
            # Determine hallucination type from issues
            hallucination_types = [issue.get("type", "unknown") for issue in validation_details.get("issues_found", [])]
            primary_type = hallucination_types[0] if hallucination_types else "unknown"
            
            item = {
                'log_id': log_id,
                'timestamp': timestamp,
                'user_query': user_query,
                'tool_name': 'bedrock_mcp',
                'tool_results': json.dumps(tool_results) if tool_results else '{}',
                'model_response': model_response,
                'hallucination_type': primary_type,
                'severity': validation_details.get('severity', 'unknown'),
                'validation_details': json.dumps(validation_details),
                'action_taken': 'logged',
                'session_id': session_id or 'unknown',
                'ttl': ttl
            }
            
            self.table.put_item(Item=item)
            logger.info(f"Logged hallucination: {log_id} - Type: {primary_type}, Severity: {validation_details.get('severity')}")
            
        except Exception as e:
            logger.error(f"Error logging hallucination: {str(e)}")
    
    def publish_metrics(self, validation_details: Dict[str, Any]):
        """Publish validation metrics to CloudWatch."""
        try:
            namespace = 'BedrockValidation'
            
            # Hallucination detection rate
            hallucination_detected = 1 if validation_details.get('severity') != 'none' else 0
            cloudwatch.put_metric_data(
                Namespace=namespace,
                MetricData=[
                    {
                        'MetricName': 'HallucinationDetectionRate',
                        'Value': hallucination_detected,
                        'Unit': 'Count',
                        'Dimensions': [
                            {'Name': 'Severity', 'Value': validation_details.get('severity', 'unknown')}
                        ]
                    }
                ]
            )
            
            # Validation success rate
            validation_success = 1 if validation_details.get('severity') == 'none' else 0
            cloudwatch.put_metric_data(
                Namespace=namespace,
                MetricData=[
                    {
                        'MetricName': 'ValidationSuccessRate',
                        'Value': validation_success,
                        'Unit': 'Count'
                    }
                ]
            )
            
            # Confidence score
            cloudwatch.put_metric_data(
                Namespace=namespace,
                MetricData=[
                    {
                        'MetricName': 'ValidationConfidenceScore',
                        'Value': validation_details.get('confidence_score', 1.0),
                        'Unit': 'None'
                    }
                ]
            )
            
        except Exception as e:
            logger.error(f"Error publishing metrics: {str(e)}")
