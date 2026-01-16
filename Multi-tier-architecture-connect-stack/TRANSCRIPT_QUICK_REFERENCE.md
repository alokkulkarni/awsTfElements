# Transcript Storage Quick Reference Card

## 📋 Quick Overview

### Two Storage Buckets
1. **Original** (Secure): Contains PII, KMS encrypted, restricted access
2. **Redacted** (Analytics): PII removed, AES256, general analytics use

---

## 🚀 Deployment Commands

```bash
# 1. Validate
terraform validate

# 2. Plan
terraform plan -out=tfplan

# 3. Apply
terraform apply tfplan

# 4. Get bucket info
terraform output transcript_storage_summary
```

---

## ⚙️ Manual Configuration (Required!)

After Terraform deployment:

1. **AWS Console** → **Amazon Connect** → **Your Instance**
2. **Data storage** → **Contact Lens** tab
3. Enable **Real-time contact analysis**
4. Configure buckets:
   - Original: `cc-demo-dev-original-transcripts-395402194296`
   - Redacted: `cc-demo-dev-redacted-transcripts-395402194296`
5. Enable PII redaction (8 entity types)
6. **Save**

---

## 🔐 Security Summary

| Feature | Original Bucket | Redacted Bucket |
|---------|----------------|-----------------|
| Encryption | KMS | AES256 |
| Access | Connect only | Analytics allowed |
| PII | ✅ Contains | ❌ Removed |
| Public | ❌ Blocked | ❌ Blocked |
| Versioning | ✅ Enabled | ✅ Enabled |

---

## 💰 Cost Timeline (per GB)

| Days | Storage Class | Cost/GB/mo |
|------|--------------|------------|
| 0-30 | STANDARD | $0.023 |
| 30-90 | STANDARD_IA | $0.0125 |
| 90-365 | GLACIER | $0.004 |
| 365+ | DEEP_ARCHIVE* | $0.00099 |
| 2555 | DELETE | $0 |

*Only for original transcripts

---

## 🔍 Verification Commands

```bash
# Check buckets exist
aws s3 ls | grep -E "original|redacted"

# Check KMS key
terraform output transcript_encryption_key

# Verify encryption
aws s3api head-object \
  --bucket $(terraform output -raw original_transcripts_bucket.name) \
  --key RealTimeAnalysis/Original/[file]

# Check lifecycle
aws s3api get-bucket-lifecycle-configuration \
  --bucket $(terraform output -raw original_transcripts_bucket.name)
```

---

## 🛠️ Troubleshooting

| Issue | Solution |
|-------|----------|
| PII not redacted | Check Contact Lens config in Console |
| Access denied | Verify KMS key permissions |
| No transcripts | Enable media streaming in Contact Flow |
| High costs | Check lifecycle policies are working |

---

## 📊 Athena Query Template

```sql
-- Create external table for redacted transcripts
CREATE EXTERNAL TABLE redacted_transcripts (
  contactId STRING,
  timestamp TIMESTAMP,
  transcript STRING,
  sentiment STRING
)
STORED AS JSON
LOCATION 's3://cc-demo-dev-redacted-transcripts-395402194296/RealTimeAnalysis/Redacted/';

-- Query transcripts
SELECT contactId, transcript, sentiment
FROM redacted_transcripts
WHERE date >= '2026-01-01'
LIMIT 100;
```

---

## 🔒 Access Pattern

```
┌─────────────────────┬─────────────┬─────────────┐
│ Role                │ Original    │ Redacted    │
├─────────────────────┼─────────────┼─────────────┤
│ Connect Service     │ ✅ Write    │ ✅ R/W      │
│ Data Analysts       │ ❌ Denied   │ ✅ Read     │
│ Compliance Team     │ ✅ Read*    │ ✅ Read     │
│ Athena/QuickSight   │ ❌ Denied   │ ✅ Read     │
└─────────────────────┴─────────────┴─────────────┘
```
*Requires KMS key access

---

## 📖 Documentation

- Full Guide: `TRANSCRIPT_STORAGE_GUIDE.md`
- Summary: `TRANSCRIPT_STORAGE_SUMMARY.md`
- Architecture: `TRANSCRIPT_ARCHITECTURE_DIAGRAM.md`

---

## ⚠️ Important Notes

1. ⚠️ **Manual config required** after Terraform deployment
2. 🔒 **Never disable KMS** on original bucket
3. 📊 **Use redacted bucket** for all analytics
4. 🗑️ **7-year retention** for compliance
5. ✅ **Test PII redaction** with sample call

---

## 🆘 Support

CloudWatch Logs: `/aws/connect/${instance_id}`
CloudTrail: Check S3 data events
Terraform Output: `terraform output transcript_storage_summary`

---

## 🎯 Key Terraform Resources

```
# New Resources (Count: ~15)
- aws_s3_bucket.original_transcripts
- aws_s3_bucket.redacted_transcripts
- aws_kms_key.transcript_encryption
- aws_s3_bucket_policy (x2)
- aws_s3_bucket_lifecycle_configuration (x2)
- + versioning, encryption, public access blocks
```

---

## ✅ Post-Deployment Checklist

- [ ] Terraform apply successful
- [ ] Buckets created and encrypted
- [ ] Contact Lens configured in Console
- [ ] PII redaction enabled
- [ ] Test call completed
- [ ] Transcripts appearing in both buckets
- [ ] PII actually redacted (verified)
- [ ] CloudTrail logging data events
- [ ] Lifecycle policies active
- [ ] Athena table created (optional)

---

**Version**: 1.0  
**Last Updated**: 2026-01-16  
**Region**: eu-west-2  
**Project**: cc-demo-dev
