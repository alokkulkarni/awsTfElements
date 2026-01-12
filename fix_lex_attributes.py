import json

input_file = 'connect_comprehensive_stack/contact_flows/bedrock_primary_flow.json.tftpl'

with open(input_file, 'r') as f:
    data = json.load(f)

for action in data['Actions']:
    if action['Identifier'] == 'GatewayBot':
        if 'Parameters' in action and 'LexSessionAttributes' in action['Parameters']:
            print("Removing LexSessionAttributes from GatewayBot")
            del action['Parameters']['LexSessionAttributes']

with open(input_file, 'w') as f:
    json.dump(data, f, indent=2)

print(f"Updated {input_file}")
