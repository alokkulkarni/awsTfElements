# Voice Call Setup Documentation

## Phone Numbers

### Claimed Numbers
1. **DID**: +442046468831 (ID: bfe2e250-9aaf-4d50-8461-a24e8fc0fcf4)
2. **Toll-Free**: +448085023925 (ID: 9e7c69c6-8b71-4409-8d7a-242a3933da52)

### Contact Flow Association
Both phone numbers are associated with **MainIVRFlow** (ID: 2a866517-2d03-4ab5-99af-b66b5f0f27e1)

## Call Flow

When a customer calls either phone number:

1. **Lex Bot Interaction**: Call is immediately connected to the Lex bot
   - Bot: "How can I help you?"
   - Customer can ask questions or request help

2. **Available Intents** (19 total):
   - Check account balance
   - View transaction history
   - Apply for loan
   - Check loan status
   - Open new account
   - Check onboarding status
   - Transfer to human agent
   - Transfer to specialist
   - And more...

3. **Transfer to Agent**:
   - Customer says: "transfer to agent", "speak to someone", "human please"
   - Routes to: BasicQueue (if using TransferToAgent intent)
   - Routes to: Specialized queues (if using TransferToSpecialist intent)
     - Account issues → AccountQueue
     - Loan inquiries → LendingQueue
     - New accounts → OnboardingQueue
     - General → GeneralAgentQueue

## Agent Availability

Agents must be logged into CCP and set status to "Available" to receive calls:
- **CCP URL**: https://d1u89oc8a8oxut.cloudfront.net
- **Agent Credentials**:
  - agent1 (Basic Profile): password Password123!
  - agent2 (Main Profile): password Password123!

## Testing Voice Calls

1. Log in as an agent in CCP
2. Set status to "Available"
3. Call +442046468831 or +448085023925
4. Interact with Lex bot or request transfer
5. Agent should receive the call

## Technical Notes

### Issue with Voice Entry Flow
- Attempted to create separate VoiceEntryFlow and VoiceIVRFlow
- All attempts failed with InvalidContactFlowException
- Even minimal flows (just disconnect) failed validation via Terraform
- Root cause: Unknown - may be Terraform provider issue or JSON encoding

### Workaround Implemented
- Associated phone numbers directly with MainIVRFlow
- MainIVRFlow provides Lex bot interaction which handles voice well
- Lex bot can route to queues via TransferToAgent and TransferToSpecialist intents
- This provides functional voice call handling

### Future Enhancements
- May need to create DTMF menu flows via AWS Console UI (not Terraform)
- Could add hours-of-operation check before Lex interaction
- Could add different entry points for DID vs Toll-Free numbers

## Related Documentation
- ROUTING_PROFILES.md - Routing profile configuration
- TRANSFER_GUIDE.md - Transfer mechanisms and queue routing
- README.md - Overall system architecture
