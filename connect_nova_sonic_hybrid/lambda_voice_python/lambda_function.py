import json
import os
import boto3

# Note: In a real production scenario, this Lambda would likely be a WebSocket handler 
# or a containerized service to maintain the persistent bidirectional stream.
# This code demonstrates the API usage and Guardrail integration.

bedrock = boto3.client('bedrock-runtime')

def handler(event, context):
    print("Received Voice Stream Event:", json.dumps(event, indent=2))
    
    queue_map_str = os.environ.get('QUEUE_MAP', '{}')
    queue_map = json.loads(queue_map_str)
    departments = ", ".join(queue_map.keys())
    print("Available Queues:", departments)
    
    audio_chunk = event.get('audioChunk')
    
    try:
        locale = os.environ.get('LOCALE', 'en_US')
        body = json.dumps({
            "audio": audio_chunk,
            "stream": True,
            "locale": locale,
            "systemPrompt": f"""You are a helpful voice assistant. 
            If the user asks to speak to a human agent or a specific department, output the tag [HANDOVER: DepartmentName].
            Available departments: {departments}.
            If the department is not found, output [HANDOVER: Default]."""
        })
        
        response = bedrock.invoke_model_with_response_stream(
            modelId="amazon.nova-sonic-v1:0", # Hypothetical Model ID
            contentType="application/json",
            accept="application/json",
            body=body,
            guardrailIdentifier=os.environ.get('GUARDRAIL_ID'),
            guardrailVersion=os.environ.get('GUARDRAIL_VERSION'),
            trace="ENABLED"
        )
        
        stream = response.get('body')
        if stream:
            for event in stream:
                chunk = event.get('chunk')
                if chunk:
                    decoded = chunk.get('bytes').decode('utf-8')
                    print("Received Stream Chunk:", decoded)
                    
                    if "guardrail_intervention" in decoded:
                        print("Content blocked by Guardrail")
                        return {
                            'statusCode': 400,
                            'body': "Content blocked"
                        }
                    
                    # Check for Handover Signal
                    if "[HANDOVER:" in decoded:
                        import re
                        match = re.search(r'\[HANDOVER: (.*?)\]', decoded)
                        if match:
                            department = match.group(1)
                            target_arn = queue_map.get(department) or queue_map.get('Default') or list(queue_map.values())[0]
                            print(f"Handover requested to {department} ({target_arn})")
                            
                            return {
                                'statusCode': 200,
                                'action': "transfer",
                                'targetQueue': department,
                                'targetQueueArn': target_arn,
                                'message': f"Transferring you to {department}..."
                            }
        
        return {
            'statusCode': 200,
            'body': "Stream processed"
        }
        
    except Exception as e:
        print(f"Error processing voice stream: {e}")
        return {
            'statusCode': 500,
            'body': str(e)
        }
