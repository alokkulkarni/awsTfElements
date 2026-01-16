# Automated Bot Association Implementation

## Overview
Implemented automated Lex V2 bot associations with Amazon Connect using AWS CLI commands executed via Terraform `null_resource` provisioners.

## What Was Changed

### 1. Integration Module Updates

#### modules/integration/main.tf
- **Removed**: Commented-out manual association instructions
- **Added**: `null_resource.bot_associations` with AWS CLI integration
  - Automatically associates Lex V2 bots with Connect instance during deployment
  - Uses `local-exec` provisioner to run `aws connect associate-bot` command
  - Includes destroy provisioner to properly clean up associations
  - Constructs bot alias ARNs dynamically using TSTALIASID

#### modules/integration/variables.tf
- **Changed**: Replaced `bot_aliases` variable with `bot_versions`
- **New Structure**: Accepts bot ID and version for ARN construction

#### modules/integration/outputs.tf
- **Updated**: `bot_associations` output to show associated bots with details
- **Added**: `bot_association_count` output

### 2. Root Module Updates

#### main.tf
- **Changed**: Integration module call to pass `bot_versions.prod` instead of constructing alias ARNs
- Uses production bot versions from Lex module for associations

#### providers.tf
- **Added**: `hashicorp/null` provider (~> 3.0) for null_resource support

#### outputs.tf
- **Updated**: `bot_associations` output description to reflect automation
- **Updated**: `deployment_info.next_steps` to include bot verification step
- **Removed**: Duplicate output definitions

## How It Works

### Bot Association Flow
1. Terraform creates Lex bots and versions
2. Integration module receives bot version information (bot_id, bot_version)
3. `null_resource` constructs bot alias ARN:
   ```
   arn:aws:lex:region:account-id:bot-alias/bot-id/TSTALIASID
   ```
4. Executes AWS CLI command:
   ```bash
   aws connect associate-bot \
     --instance-id <instance-id> \
     --lex-v2-bot AliasArn=<bot-alias-arn> \
     --region <region>
   ```
5. On destroy, automatically disassociates bots

### What Gets Associated
All production Lex bot versions are automatically associated:
- Banking Bot
- Sales Bot
- Product Bot
- Concierge Bot

## Benefits

### Before (Manual Process)
❌ Required post-deployment manual steps
❌ Error-prone console navigation
❌ No cleanup on destroy
❌ Not repeatable/automated

### After (Automated)
✅ Fully automated during `terraform apply`
✅ Idempotent and repeatable
✅ Automatic cleanup on `terraform destroy`
✅ Version controlled and auditable
✅ Consistent across environments

## Deployment

### Prerequisites
- AWS CLI installed and configured
- Appropriate IAM permissions for `connect:AssociateBot` and `connect:DisassociateBot`

### Deploy with Bot Associations
```bash
terraform init
terraform plan
terraform apply
```

Bot associations will be created automatically after Connect instance and Lex bots are ready.

### Verify Associations
```bash
# View bot association details
terraform output bot_associations

# Check in AWS Console
# Navigate to: Amazon Connect → Contact Flows → Lex Bots
# All 4 bots should be listed and available for use in contact flows
```

## Outputs

After deployment, you'll see:

```hcl
bot_associations = {
  banking = {
    bot_id        = "3UPVRPZIUX"
    bot_name      = "banking"
    bot_alias_arn = "arn:aws:lex:eu-west-2:395402194296:bot-alias/3UPVRPZIUX/TSTALIASID"
    instance_id   = "83c2c68d-ba67-4e20-b392-3c17b8f7c52b"
  }
  concierge = {
    bot_id        = "YCVTVNJQSN"
    bot_name      = "concierge"
    bot_alias_arn = "arn:aws:lex:eu-west-2:395402194296:bot-alias/YCVTVNJQSN/TSTALIASID"
    instance_id   = "83c2c68d-ba67-4e20-b392-3c17b8f7c52b"
  }
  product = {
    bot_id        = "R0CBZBD6QG"
    bot_name      = "product"
    bot_alias_arn = "arn:aws:lex:eu-west-2:395402194296:bot-alias/R0CBZBD6QG/TSTALIASID"
    instance_id   = "83c2c68d-ba67-4e20-b392-3c17b8f7c52b"
  }
  sales = {
    bot_id        = "HSKL6HJIEB"
    bot_name      = "sales"
    bot_alias_arn = "arn:aws:lex:eu-west-2:395402194296:bot-alias/HSKL6HJIEB/TSTALIASID"
    instance_id   = "83c2c68d-ba67-4e20-b392-3c17b8f7c52b"
  }
}
```

## Technical Details

### Why null_resource?
- AWS Terraform provider doesn't support Lex V2 bot associations with Connect
- The `aws_connect_bot_association` resource only supports deprecated Lex V1
- Using AWS CLI is currently the only automated option

### TSTALIASID
This is the built-in test alias ID that AWS creates for every Lex V2 bot. It always points to the DRAFT version and is available immediately after bot creation.

### Dependencies
The null_resource depends on:
- Connect instance creation
- Lex bot creation
- Bot version creation
- Bot dependencies passed from root module

### Error Handling
- Uses `|| true` in destroy provisioner to prevent errors if bot is already disassociated
- Provides clear console output with emojis for easy tracking
- All commands use explicit region specification to avoid AWS CLI default region issues

## Troubleshooting

### Bot Already Associated Error
If you see "ResourceInUseException: Bot is already associated", this is expected on re-apply. The association is idempotent.

### AWS CLI Not Found
Ensure AWS CLI v2 is installed:
```bash
aws --version
```

### Permission Denied
Ensure your AWS credentials have:
- `connect:AssociateBot`
- `connect:DisassociateBot`
- `connect:ListBots` (for verification)

### Bot Not Showing in Console
Wait 30-60 seconds after apply completes. Sometimes there's a propagation delay in the AWS console.

## Future Enhancements

1. Add support for custom bot aliases (not just TSTALIASID)
2. Add retry logic for transient CLI failures
3. Add validation checks to confirm associations succeeded
4. Support for associating both prod and test versions

## Related Files
- `modules/integration/main.tf` - Core bot association logic
- `modules/integration/variables.tf` - Input variables
- `modules/integration/outputs.tf` - Association outputs
- `main.tf` - Module integration
- `providers.tf` - Provider requirements
- `outputs.tf` - Root outputs

## Testing

To test bot associations:
1. Deploy the stack: `terraform apply`
2. Check outputs: `terraform output bot_associations`
3. Log into Connect console
4. Navigate to Contact Flows → Lex Bots
5. Verify all 4 bots are listed
6. Create a test contact flow using one of the bots
7. Destroy and verify cleanup: `terraform destroy`
