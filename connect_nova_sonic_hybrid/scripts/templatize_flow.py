#!/usr/bin/env python3
import json
import subprocess
import sys
import os

def get_terraform_outputs():
    """Runs terraform output -json and returns the parsed dictionary."""
    try:
        # Run terraform output in the parent directory (project root)
        result = subprocess.run(
            ["terraform", "output", "-json"],
            capture_output=True,
            text=True,
            check=True,
            cwd=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error running terraform output: {e.stderr}")
        sys.exit(1)
    except FileNotFoundError:
        print("Error: terraform command not found. Please ensure Terraform is installed.")
        sys.exit(1)

def templatize_flow(input_file, output_file, tf_outputs):
    """Reads the input JSON, replaces ARNs with template variables, and writes to output."""
    
    try:
        with open(input_file, 'r') as f:
            flow_content = f.read()
    except FileNotFoundError:
        print(f"Error: Input file '{input_file}' not found.")
        sys.exit(1)

    # 1. Replace Voice Lambda ARN
    voice_lambda_arn = tf_outputs.get("voice_lambda_arn", {}).get("value")
    if voice_lambda_arn:
        print(f"Replacing Voice Lambda ARN: {voice_lambda_arn} -> ${{voice_lambda_arn}}")
        flow_content = flow_content.replace(voice_lambda_arn, "${voice_lambda_arn}")

    # 2. Replace Lex Bot Alias ARN
    lex_bot_alias_arn = tf_outputs.get("lex_bot_alias_arn", {}).get("value")
    if lex_bot_alias_arn:
        print(f"Replacing Lex Bot Alias ARN: {lex_bot_alias_arn} -> ${{lex_bot_alias_arn}}")
        flow_content = flow_content.replace(lex_bot_alias_arn, "${lex_bot_alias_arn}")

    # 3. Replace Lex Bot Name
    lex_bot_name = tf_outputs.get("lex_bot_name", {}).get("value")
    if lex_bot_name:
        print(f"Replacing Lex Bot Name: {lex_bot_name} -> ${{lex_bot_name}}")
        flow_content = flow_content.replace(lex_bot_name, "${lex_bot_name}")

    # 4. Replace Queue ARNs
    queue_arns = tf_outputs.get("queue_arns", {}).get("value", {})
    for queue_name, queue_arn in queue_arns.items():
        print(f"Replacing Queue '{queue_name}' ARN: {queue_arn} -> ${{queues[\"{queue_name}\"]}}")
        flow_content = flow_content.replace(queue_arn, f"${{queues[\"{queue_name}\"]}}")

    # Write the result
    with open(output_file, 'w') as f:
        f.write(flow_content)
    
    print(f"\nSuccess! Templatized flow saved to: {output_file}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 templatize_flow.py <path_to_exported_flow.json> [output_path]")
        sys.exit(1)

    input_path = sys.argv[1]
    
    # Default output path is contact_flows/nova_sonic_ivr.json.tftpl
    if len(sys.argv) >= 3:
        output_path = sys.argv[2]
    else:
        # Determine project root relative to this script
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        output_path = os.path.join(project_root, "contact_flows", "nova_sonic_ivr.json.tftpl")

    print("Fetching Terraform outputs...")
    outputs = get_terraform_outputs()
    
    print(f"Processing flow: {input_path}")
    templatize_flow(input_path, output_path, outputs)
