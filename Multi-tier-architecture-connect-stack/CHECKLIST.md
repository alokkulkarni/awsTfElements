# Pre-Deployment Checklist

Use this checklist before deploying the Contact Center in a Box solution.

## ☐ Prerequisites Verification

### AWS Account Setup
- [ ] AWS account with appropriate permissions
- [ ] AWS CLI installed (`aws --version`)
- [ ] AWS CLI configured (`aws configure`)
- [ ] IAM user/role with required permissions:
  - [ ] ConnectFullAccess
  - [ ] LexV2FullAccess
  - [ ] LambdaFullAccess
  - [ ] BedrockFullAccess
  - [ ] IAMFullAccess
  - [ ] S3FullAccess
  - [ ] CloudWatchFullAccess

### Bedrock Access
- [ ] Navigate to AWS Console → Bedrock → Model Access (eu-west-2)
- [ ] Request access to Claude 3 Sonnet model
- [ ] Verify access granted: `aws bedrock list-foundation-models --region eu-west-2`

### Tools Installation
- [ ] Terraform >= 1.0 installed (`terraform version`)
- [ ] Git installed (for version control)
- [ ] jq installed (for parsing JSON outputs)
- [ ] Text editor (vim, vscode, etc.)

## ☐ Configuration

### Required Changes
- [ ] Copy `terraform.tfvars.example` to `terraform.tfvars`
- [ ] Update `connect_instance_alias` (must be globally unique)
- [ ] Update all email addresses in `connect_users` section
- [ ] Verify `project_name` and `environment` settings
- [ ] Review `region` (default: eu-west-2)

### Optional Customizations
- [ ] Customize queue configurations if needed
- [ ] Modify Lambda settings (runtime, timeout, memory)
- [ ] Update Bedrock agent instructions
- [ ] Adjust phone number settings (country code, type)
- [ ] Configure module deployment flags

## ☐ Pre-Deployment Validation

### Terraform Validation
- [ ] Run `terraform init` successfully
- [ ] Run `terraform validate` without errors
- [ ] Run `terraform fmt -recursive` to format code
- [ ] Review `terraform plan` output carefully
- [ ] Verify ~60-80 resources will be created
- [ ] Check for any error messages or warnings

### Cost Estimation
- [ ] Review estimated monthly costs (£18-55 for light usage)
- [ ] Set up AWS billing alerts
- [ ] Understand pricing for:
  - [ ] Connect (per-minute voice, per-message chat)
  - [ ] Lex (per-request)
  - [ ] Lambda (per-invocation)
  - [ ] Bedrock (per-token)
  - [ ] S3 storage

### Service Quotas
- [ ] Check Connect instance quota (default: 2 per region)
- [ ] Check Lex bot quota (default: 100 per account)
- [ ] Check Lambda function quota (default: 1000 per region)
- [ ] Request quota increases if needed

## ☐ Deployment

### Initial Deployment
- [ ] Run `terraform plan -out=tfplan`
- [ ] Review plan output thoroughly
- [ ] Run `terraform apply tfplan`
- [ ] Wait for completion (~15-20 minutes)
- [ ] Verify no errors in output

### Capture Outputs
- [ ] Run `terraform output > outputs.txt`
- [ ] Run `terraform output -json user_credentials > credentials.json`
- [ ] Run `chmod 600 credentials.json` to secure credentials
- [ ] Note the Connect login URL
- [ ] Note the phone number

### Secure Credentials
- [ ] Store `credentials.json` in secure location
- [ ] Share credentials securely with users (not via email)
- [ ] Delete `credentials.json` after distributing
- [ ] Document where passwords are stored

## ☐ Post-Deployment Verification

### AWS Console Verification
- [ ] Login to Connect console
- [ ] Verify all 5 queues exist
- [ ] Verify all users are created
- [ ] Verify phone number is claimed
- [ ] Verify routing profiles exist
- [ ] Check S3 bucket is created

### Functional Testing
- [ ] Test Lex bots (see QUICKSTART.md)
- [ ] Test Lambda functions (see QUICKSTART.md)
- [ ] Test Bedrock agent (via console)
- [ ] Login as admin user
- [ ] Login as manager user
- [ ] Login as agent user
- [ ] Test CCP functionality

### Integration Verification
- [ ] Verify Lex bots are associated with Connect
- [ ] Verify Lambda functions are associated with Connect
- [ ] Check bot-Lambda connections work
- [ ] Verify Bedrock agent is accessible

## ☐ Contact Flow Design

### Design in Console (Do Not Skip!)
- [ ] Login to Connect console as Admin
- [ ] Navigate to Routing → Contact Flows
- [ ] Create "Main Flow":
  - [ ] Add "Set logging behavior" block
  - [ ] Add "Get customer input" block
  - [ ] Integrate with Concierge bot
  - [ ] Add "Transfer to queue" blocks
  - [ ] Add error handling
  - [ ] Save and Publish
- [ ] Create "Customer Queue Flow":
  - [ ] Add hold music
  - [ ] Add queue position announcements
  - [ ] Save and Publish
- [ ] Create "Callback Flow":
  - [ ] Configure callback queue
  - [ ] Save and Publish
- [ ] Associate Main Flow with phone number

### Export and Deploy (Optional)
- [ ] Export all flows as JSON
- [ ] Save to `modules/contact_flows/flows/`
- [ ] Update `terraform.tfvars`: `deploy_contact_flows = true`
- [ ] Run `terraform apply` to deploy flows

## ☐ Monitoring Setup

### CloudWatch
- [ ] Create CloudWatch dashboard
- [ ] Set up alarms for:
  - [ ] High error rates
  - [ ] Queue overflow
  - [ ] No available agents
  - [ ] High abandon rate
- [ ] Configure SNS notifications

### Logging
- [ ] Verify Connect logs are flowing
- [ ] Verify Lambda logs are present
- [ ] Verify Lex conversation logs
- [ ] Check Bedrock agent logs

### Metrics
- [ ] Review Connect metrics dashboard
- [ ] Check queue performance metrics
- [ ] Monitor agent metrics
- [ ] Review bot analytics in Lex console

## ☐ User Training

### Documentation Distribution
- [ ] Share README.md with team
- [ ] Share QUICKSTART.md with new users
- [ ] Distribute user credentials securely
- [ ] Provide Connect login URL

### Agent Training
- [ ] CCP overview and navigation
- [ ] How to handle voice calls
- [ ] How to handle chat conversations
- [ ] Understanding contact attributes
- [ ] Using soft phone features
- [ ] Callback management
- [ ] Reporting and metrics

### Admin Training
- [ ] User management
- [ ] Queue management
- [ ] Routing profile configuration
- [ ] Contact flow design
- [ ] Reporting and analytics
- [ ] Security and compliance

## ☐ Go-Live Preparation

### Final Testing
- [ ] End-to-end voice call test
- [ ] End-to-end chat test
- [ ] Test all queues
- [ ] Test callback functionality
- [ ] Load testing (if needed)
- [ ] Security audit

### Documentation
- [ ] Document any customizations
- [ ] Update runbooks
- [ ] Document escalation procedures
- [ ] Create knowledge base articles

### Communication
- [ ] Notify stakeholders of go-live date
- [ ] Prepare go-live announcement
- [ ] Set up support channels
- [ ] Plan for 24/7 coverage (if needed)

## ☐ Ongoing Maintenance

### Weekly Tasks
- [ ] Review CloudWatch logs for errors
- [ ] Check queue performance metrics
- [ ] Monitor agent utilization
- [ ] Review abandoned call rates

### Monthly Tasks
- [ ] Cost analysis and optimization
- [ ] Review bot accuracy and training
- [ ] Update Lambda dependencies
- [ ] Security patch review

### Quarterly Tasks
- [ ] Comprehensive security audit
- [ ] Disaster recovery test
- [ ] Performance optimization review
- [ ] User feedback collection

### As Needed
- [ ] Add new users via Terraform
- [ ] Add new queues via Terraform
- [ ] Update bot training
- [ ] Modify contact flows
- [ ] Scale resources

## ☐ Backup and Disaster Recovery

### Backup Strategy
- [ ] Enable Terraform remote state (S3 + DynamoDB)
- [ ] Regular state file backups
- [ ] Export and version control contact flows
- [ ] Document configuration settings
- [ ] Test restore procedure

### Disaster Recovery Plan
- [ ] Document RTO and RPO requirements
- [ ] Test failover procedures
- [ ] Document rollback procedures
- [ ] Maintain runbooks
- [ ] Regular DR drills

## ☐ Compliance and Governance

### Security Compliance
- [ ] Review IAM policies
- [ ] Verify encryption at rest
- [ ] Verify encryption in transit
- [ ] Enable GuardDuty (if required)
- [ ] Configure AWS Config (if required)

### Data Governance
- [ ] Configure data retention policies
- [ ] Set up S3 lifecycle policies
- [ ] Configure CloudWatch log retention
- [ ] Document data handling procedures
- [ ] GDPR/compliance review (if applicable)

### Tagging
- [ ] Verify all resources are tagged
- [ ] Review tag compliance
- [ ] Update tags as needed

## ☐ Final Checklist

### Before Going Live
- [ ] All tests passed
- [ ] All users trained
- [ ] Monitoring configured
- [ ] Backups configured
- [ ] Documentation complete
- [ ] Stakeholders informed
- [ ] Support plan in place
- [ ] Escalation procedures documented

### Day of Go-Live
- [ ] All hands on deck
- [ ] Monitor closely for first 24 hours
- [ ] Be ready to rollback if needed
- [ ] Document any issues
- [ ] Communicate status regularly

### Post Go-Live
- [ ] Collect feedback
- [ ] Review metrics
- [ ] Optimize as needed
- [ ] Document lessons learned
- [ ] Plan for iterations

---

## 📝 Notes Section

Use this space to track your progress and notes:

```
Date: __________
Deployed by: __________
Environment: __________
Instance Alias: __________
Region: __________

Issues encountered:
-
-
-

Resolutions:
-
-
-

Next steps:
-
-
-
```

---

## ✅ Completion Sign-off

- [ ] All checklist items completed
- [ ] System tested and verified
- [ ] Users trained
- [ ] Documentation updated
- [ ] Ready for production

**Signed:** ________________  
**Date:** ________________  
**Role:** ________________

---

**Need Help?** Refer to:
- [QUICKSTART.md](QUICKSTART.md) - Quick deployment
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Detailed guide
- [README.md](README.md) - Complete documentation
- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture details
