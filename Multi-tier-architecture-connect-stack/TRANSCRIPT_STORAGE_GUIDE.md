# Call Transcript Storage with PII Redaction

## Overview

This deployment configures secure call transcript storage with PII (Personally Identifiable Information) redaction, storing both original and redacted versions in separate S3 buckets with appropriate security controls.

## Architecture

### Storage Buckets

1. **Original Transcripts Bucket** (Secure, Restricted Access)
   - Bucket: `${project_name}-${environment}-original-transcripts-${account_id}`
   - Contains: Original transcripts with ALL data including PII
   - Encryption: AWS KMS with dedicated transcript encryption key
   - Access: Restricted to Connect service and specific admin roles only
   - Data Classification: **Confidential - Contains PII**
   - Compliance: 7-year retention for regulatory requirements

2. **Redacted Transcripts Bucket** (Analytics-Ready)
   - Bucket: `${project_name}-${environment}-redacted-transcripts-${account_id}`
   - Contains: PII-redacted transcripts safe for analytics
   - Encryption: AES256 (standard S3 encryption)
   - Access: Available for analytics, data lake, and Athena queries
   - Data Classification: **Public - PII Redacted**
   - Compliance: 7-year retention for analytics

3. **General Connect Storage**
   - Bucket: `${project_name}-${environment}-connect-storage-${account_id}`
   - Contains: Call recordings, attachments, reports
   - Encryption: AES256
   - Access: Standard Connect service access

### PII Entities Redacted

The following PII entities are automatically redacted from transcripts:
- **NAME**: Person names
- **ADDRESS**: Physical addresses
- **EMAIL**: Email addresses
- **PHONE**: Phone numbers
- **SSN**: Social Security Numbers
- **CREDIT_DEBIT_NUMBER**: Credit/debit card numbers
- **CREDIT_DEBIT_CVV**: Card CVV codes
- **CREDIT_DEBIT_EXPIRY**: Card expiration dates

### Security Controls

#### Original Transcripts Bucket Security
1. **KMS Encryption**: Dedicated KMS key with 30-day deletion window
2. **Bucket Policy Enforcement**:
   - Deny all unencrypted uploads
   - Deny insecure transport (non-HTTPS)
   - Allow only Connect service write access
   - Require KMS encryption for all objects
3. **IAM Restrictions**: Only specific roles can access original transcripts
4. **Versioning**: Enabled for audit trail
5. **Public Access**: Completely blocked

#### Redacted Transcripts Bucket Security
1. **Standard Encryption**: AES256
2. **Bucket Policy**:
   - Deny insecure transport
   - Allow Connect service read/write
   - Open for analytics tools (Athena, Glue, QuickSight)
3. **Versioning**: Enabled
4. **Public Access**: Blocked (private to account)

### Lifecycle Management

#### Original Transcripts Lifecycle
```
Day 0:     STANDARD storage
Day 30:    → STANDARD_IA (Infrequent Access)
Day 90:    → GLACIER (Archive)
Day 365:   → DEEP_ARCHIVE (Long-term archive)
Day 2555:  → Deleted (7 years retention)
```

**Cost Optimization**: Original transcripts move to cheaper storage as they age, with Deep Archive for long-term compliance.

#### Redacted Transcripts Lifecycle
```
Day 0:     STANDARD storage (Hot for analytics)
Day 30:    → STANDARD_IA
Day 90:    → GLACIER
Day 2555:  → Deleted (7 years retention)
```

**Analytics-Ready**: Redacted transcripts stay in accessible storage longer for data lake queries.

### Data Flow

```
┌─────────────────────┐
│  Customer Call      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Contact Lens       │
│  Real-Time Analysis │
└─────┬─────────┬─────┘
      │         │
      │         │ PII Detection
      │         │ & Redaction
      │         │
      ▼         ▼
┌─────────┐   ┌──────────────┐
│Original │   │  Redacted    │
│Bucket   │   │  Bucket      │
│(Secure) │   │(Analytics)   │
└─────────┘   └──────┬───────┘
                     │
                     ▼
              ┌──────────────┐
              │  Data Lake   │
              │  (Athena)    │
              └──────────────┘
```

## Manual Configuration Steps

⚠️ **Important**: Contact Lens real-time transcript storage with PII redaction must be configured manually in the AWS Console after Terraform deployment.

### Post-Deployment Configuration

1. **Navigate to Amazon Connect Console**
   ```
   AWS Console → Amazon Connect → Your Instance → Data storage
   ```

2. **Enable Contact Lens**
   - Go to "Data storage" section
   - Click on "Contact Lens" tab
   - Enable "Real-time contact analysis"

3. **Configure Original Transcripts Storage**
   - S3 bucket: `${project_name}-${environment}-original-transcripts-${account_id}`
   - Prefix: `RealTimeAnalysis/Original`
   - Encryption: Will use KMS key automatically

4. **Configure Redacted Transcripts Storage**
   - S3 bucket: `${project_name}-${environment}-redacted-transcripts-${account_id}`
   - Prefix: `RealTimeAnalysis/Redacted`
   - Encryption: Will use AES256 automatically

5. **Enable PII Redaction**
   - Check "Enable PII redaction"
   - Select the following entity types:
     - ☑ NAME
     - ☑ ADDRESS
     - ☑ EMAIL
     - ☑ PHONE
     - ☑ SSN
     - ☑ CREDIT_DEBIT_NUMBER
     - ☑ CREDIT_DEBIT_CVV
     - ☑ CREDIT_DEBIT_EXPIRY

6. **Additional Settings**
   - Redaction character: `[PII]` (default)
   - Confidence threshold: High (recommended)
   - Language: English (expand as needed)

7. **Save Configuration**

### Verification

After configuration, verify the setup:

```bash
# Check Original Transcripts Bucket
aws s3 ls s3://${project_name}-${environment}-original-transcripts-${account_id}/RealTimeAnalysis/Original/

# Check Redacted Transcripts Bucket
aws s3 ls s3://${project_name}-${environment}-redacted-transcripts-${account_id}/RealTimeAnalysis/Redacted/

# Verify encryption on original bucket
aws s3api head-object \
  --bucket ${project_name}-${environment}-original-transcripts-${account_id} \
  --key RealTimeAnalysis/Original/[sample-file]
```

## Access Patterns

### Who Can Access What?

| Role | Original Transcripts | Redacted Transcripts | Use Case |
|------|---------------------|----------------------|----------|
| Connect Service | Write Only | Write Only | Store transcripts |
| Compliance Team | Read (with KMS key) | Read | Audit & investigations |
| Data Analysts | ❌ No Access | Read | Analytics & insights |
| Data Lake | ❌ No Access | Read | Athena queries |
| QuickSight | ❌ No Access | Read | Dashboards |
| General Users | ❌ No Access | ❌ No Access | N/A |

### Granting Access to Original Transcripts

⚠️ **Restricted Access**: Original transcripts contain PII and should only be accessed by authorized personnel.

To grant read access to original transcripts:

```bash
# Create a role/user policy
aws iam put-role-policy \
  --role-name ComplianceAuditorRole \
  --policy-name OriginalTranscriptAccess \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        "Resource": [
          "arn:aws:s3:::${project_name}-${environment}-original-transcripts-*",
          "arn:aws:s3:::${project_name}-${environment}-original-transcripts-*/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        "Resource": "${transcript_kms_key_arn}"
      }
    ]
  }'
```

### Accessing Redacted Transcripts for Analytics

Redacted transcripts are safe for general analytics use:

```sql
-- Athena Query Example
CREATE EXTERNAL TABLE IF NOT EXISTS redacted_transcripts (
  contactId STRING,
  timestamp TIMESTAMP,
  channel STRING,
  transcript STRING,
  sentiment STRING
)
STORED AS JSON
LOCATION 's3://${project_name}-${environment}-redacted-transcripts-${account_id}/RealTimeAnalysis/Redacted/';

-- Query transcripts
SELECT 
  contactId,
  timestamp,
  transcript,
  sentiment
FROM redacted_transcripts
WHERE date >= '2026-01-01'
AND sentiment = 'NEGATIVE';
```

## Monitoring & Compliance

### CloudWatch Metrics

Monitor transcript storage:

```bash
# Bucket size metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name BucketSizeBytes \
  --dimensions Name=BucketName,Value=${bucket_name} \
  --start-time 2026-01-01T00:00:00Z \
  --end-time 2026-01-31T23:59:59Z \
  --period 86400 \
  --statistics Average
```

### CloudTrail Auditing

All access to original transcripts is logged:
- S3 data events enabled for original transcripts bucket
- CloudTrail logs stored in separate audit bucket
- 90-day CloudWatch Logs retention for alerts

### Compliance Reports

Generate compliance reports:

```bash
# List all original transcripts
aws s3api list-objects-v2 \
  --bucket ${project_name}-${environment}-original-transcripts-${account_id} \
  --query 'Contents[].{Key:Key,Size:Size,LastModified:LastModified}' \
  --output table

# Check lifecycle transitions
aws s3api get-bucket-lifecycle-configuration \
  --bucket ${project_name}-${environment}-original-transcripts-${account_id}
```

## Cost Optimization

### Storage Cost Breakdown

Based on average transcript sizes (10KB per minute of conversation):

| Storage Tier | Days | Cost per GB/month | Typical Use |
|--------------|------|-------------------|-------------|
| STANDARD | 0-30 | $0.023 | Active transcripts |
| STANDARD_IA | 30-90 | $0.0125 | Recent analysis |
| GLACIER | 90-365 | $0.004 | Compliance |
| DEEP_ARCHIVE | 365+ | $0.00099 | Long-term archive |

**Example**: 10,000 calls/month at 10 minutes average:
- Month 1: 1GB at $0.023 = $0.023
- Month 2: 1GB at $0.0125 = $0.0125
- Month 4: 1GB at $0.004 = $0.004
- Year 2+: 12GB at $0.00099 = $0.012

**Total annual cost**: ~$0.50 for 120,000 minutes of transcripts

### Cost Optimization Tips

1. **Adjust retention periods**: Reduce from 7 years if not required
2. **Archive redacted earlier**: Move redacted to Glacier at Day 60 instead of 90
3. **Delete non-compliant data**: Remove test data regularly
4. **Use lifecycle policies**: Let AWS automatically transition to cheaper storage

## Troubleshooting

### Common Issues

#### 1. Access Denied to Original Transcripts

**Problem**: Cannot read original transcripts even with S3 permissions

**Solution**: Ensure you also have KMS key permissions:
```bash
aws kms describe-key --key-id ${transcript_kms_key_id}
```

#### 2. PII Not Being Redacted

**Problem**: Redacted transcripts still contain PII

**Solution**:
- Verify Contact Lens PII redaction is enabled in Console
- Check confidence threshold (lower for more aggressive redaction)
- Confirm entity types are selected
- Review language settings

#### 3. Transcripts Not Appearing in S3

**Problem**: No transcripts in either bucket

**Solution**:
- Verify Contact Lens is enabled on instance
- Check Contact Flow has "Start media streaming" block
- Ensure storage configuration is saved in Console
- Review IAM permissions for Connect service role

#### 4. High Storage Costs

**Problem**: Storage costs higher than expected

**Solution**:
- Check lifecycle policies are applied: `aws s3api get-bucket-lifecycle-configuration`
- Verify objects are transitioning: `aws s3api list-objects-v2 --query 'Contents[?StorageClass]'`
- Remove test data: `aws s3 rm s3://bucket/test/ --recursive`

## Best Practices

### Security
1. ✅ Never disable KMS encryption on original transcripts bucket
2. ✅ Regularly audit access logs via CloudTrail
3. ✅ Use separate IAM roles for different access patterns
4. ✅ Enable MFA delete on original transcripts bucket for production
5. ✅ Rotate KMS keys annually

### Operations
1. ✅ Test PII redaction with sample calls after deployment
2. ✅ Monitor bucket sizes and set CloudWatch alarms
3. ✅ Document who has access to original transcripts
4. ✅ Regularly review and update PII entity types
5. ✅ Keep lifecycle policies aligned with compliance requirements

### Analytics
1. ✅ Use redacted transcripts for all analytics queries
2. ✅ Set up Athena/Glue catalog for easy querying
3. ✅ Create QuickSight dashboards on redacted data only
4. ✅ Use Amazon Comprehend for additional insights
5. ✅ Archive analytics results separately

## Related Documentation

- [AWS Connect Contact Lens Documentation](https://docs.aws.amazon.com/connect/latest/adminguide/analyze-conversations.html)
- [S3 Lifecycle Policies](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
- [KMS Key Policies](https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html)
- [PII Detection in Amazon Comprehend](https://docs.aws.amazon.com/comprehend/latest/dg/how-pii.html)

## Support

For issues or questions:
1. Check CloudWatch Logs for Connect instance
2. Review CloudTrail for access attempts
3. Verify bucket policies and KMS key policies
4. Contact AWS Support with instance ID and error details
