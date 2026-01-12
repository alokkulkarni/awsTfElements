import json
import os

file_path = '/Users/alokkulkarni/Documents/Development/awsTfElements/connect_comprehensive_stack/contact_flows/bedrock_primary_flow.json.tftpl'

with open(file_path, 'r') as f:
    data = json.load(f)

def clean_node(node):
    if isinstance(node, dict):
        # Remove ConditionType if present
        if 'ConditionType' in node:
            del node['ConditionType']
        # Recurse
        for key, value in node.items():
            clean_node(value)
    elif isinstance(node, list):
        for item in node:
            clean_node(item)

clean_node(data)

with open(file_path, 'w') as f:
    json.dump(data, f, indent=2)

print("Successfully removed ConditionType fields.")
