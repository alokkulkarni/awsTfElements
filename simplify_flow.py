import json

file_path = '/Users/alokkulkarni/Documents/Development/awsTfElements/connect_comprehensive_stack/contact_flows/bedrock_primary_flow.json.tftpl'

with open(file_path, 'r') as f:
    data = json.load(f)

# Find SetQueueForTransfer and modify it
for action in data['Actions']:
    if action['Identifier'] == 'SetQueueForTransfer':
        action['Type'] = 'TransferContactToQueue'
        action['Transitions']['NextAction'] = 'Disconnect'
        # Reset errors to standard or empty for TransferContactToQueue
        action['Transitions']['Errors'] = [
            {"NextAction": "Disconnect", "ErrorType": "NoMatchingError"},
            {"NextAction": "Disconnect", "ErrorType": "QueueAtCapacity"}
        ]
        break

# Remove callback blocks
blocks_to_remove = ['SetCallbackNumber', 'NotifyCallbackCreation', 'TransferToQueue']
data['Actions'] = [a for a in data['Actions'] if a['Identifier'] not in blocks_to_remove]

with open(file_path, 'w') as f:
    json.dump(data, f, indent=2)

print("Simplified flow to use direct TransferContactToQueue")
