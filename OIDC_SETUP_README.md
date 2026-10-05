# OIDC Setup - Start to Finish

This directory contains everything you need to set up GitHub Actions OIDC authentication with AWS from scratch.

## Files Included

1. **OIDC_FRESH_SETUP.md** - Detailed step-by-step guide
2. **setup-oidc.sh** - Automated setup script
3. **.github/workflows/test-oidc.yml** - Test workflow to verify OIDC setup
4. **GITHUB_SECRETS.txt** - Generated after running setup script

## Quick Start (Choose One Method)

### Method 1: Automated Setup (Recommended)

```bash
# Make script executable
chmod +x setup-oidc.sh

# Run the setup script
./setup-oidc.sh
```

The script will:
- ✅ Get your AWS Account ID automatically
- ✅ Prompt for GitHub org/repo info
- ✅ Create OIDC Provider in AWS
- ✅ Create IAM Role with proper trust policy
- ✅ Create IAM Policy with necessary permissions
- ✅ Create S3 buckets for Terraform state
- ✅ Create DynamoDB table for state locking
- ✅ Generate GITHUB_SECRETS.txt with all secrets
- ✅ Verify all AWS resources

**Time:** ~2 minutes

### Method 2: Manual Setup

Follow the detailed steps in **OIDC_FRESH_SETUP.md**

**Time:** ~10 minutes (more control, but requires typing commands)

---

## Setup Steps Overview

### Phase 1: AWS Configuration
1. Get AWS Account ID
2. Create OIDC Provider
3. Create IAM Role with trust policy
4. Create IAM Policy
5. Create S3 buckets
6. Create DynamoDB table

### Phase 2: GitHub Configuration
7. Add GitHub Secrets
8. Push test workflow

### Phase 3: Testing
9. Run test workflow
10. Verify OIDC works

---

## After Setup

### 1. Add GitHub Secrets

After running `setup-oidc.sh`, open `GITHUB_SECRETS.txt` and add each secret to your GitHub repository:

**Location:** GitHub → Settings → Secrets and variables → Actions → New repository secret

You'll need to add 5 secrets:
- `AWS_ACCOUNT_ID`
- `AWS_ROLE_TO_ASSUME`
- `AWS_REGION`
- `TERRAFORM_STATE_BUCKET`
- `TERRAFORM_LOCK_TABLE`

### 2. Push Test Workflow

```bash
git add .github/workflows/test-oidc.yml
git commit -m "Add OIDC test workflow"
git push origin main
```

### 3. Run Test Workflow

- Go to **GitHub Actions** tab
- Click **Test OIDC Setup**
- Click **Run workflow**
- Wait for it to complete

**Expected Result:** All steps pass ✅

### 4. Update Main Workflows

Once test passes, update your existing workflows to use OIDC:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
    aws-region: ${{ secrets.AWS_REGION }}
```

---

## Troubleshooting

### OIDC Test Fails with "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Check 1:** Verify GitHub org/repo in trust policy
```bash
aws iam get-role --role-name GitHubActionsRole
# Look for "token.actions.githubusercontent.com:sub" condition
```

**Check 2:** Verify trust policy is correct
```bash
# Update if needed:
aws iam update-assume-role-policy \
  --role-name GitHubActionsRole \
  --policy-document file://trust-policy.json
```

**Check 3:** Verify policy is attached
```bash
aws iam get-role-policy \
  --role-name GitHubActionsRole \
  --policy-name GitHubActionsPolicy
```

### S3 Bucket Not Found

```bash
# List all buckets
aws s3 ls

# Check bucket name in GITHUB_SECRETS.txt matches
```

### DynamoDB Table Not Found

```bash
# List tables
aws dynamodb list-tables

# Create if missing:
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

---

## Key Concepts

### OIDC (OpenID Connect)
- Allows GitHub Actions to authenticate with AWS without storing access keys
- GitHub creates a temporary JWT token
- AWS validates the token and returns temporary credentials
- Credentials automatically expire after 1 hour

### Trust Policy
- Defines which GitHub repositories can assume the IAM role
- Uses the format: `repo:OWNER/REPO:ref:refs/heads/BRANCH`

### IAM Policy
- Grants permissions to the GitHub Actions role
- Includes: ECR, S3, DynamoDB, EKS, Terraform permissions

---

## Verification Commands

```bash
# Verify OIDC Provider exists
aws iam list-open-id-connect-providers

# Verify IAM Role exists
aws iam get-role --role-name GitHubActionsRole

# Verify Policy is attached
aws iam get-role-policy \
  --role-name GitHubActionsRole \
  --policy-name GitHubActionsPolicy

# Verify S3 buckets exist
aws s3 ls

# Verify DynamoDB table exists
aws dynamodb describe-table --table-name terraform-locks
```

---

## Security Best Practices

✅ **Do:**
- Use OIDC instead of long-lived AWS access keys
- Restrict role permissions to only what's needed
- Review trust policy to match your repository
- Regularly audit GitHub secrets
- Enable versioning on S3 buckets
- Block public access on S3 buckets

❌ **Don't:**
- Store AWS credentials in GitHub
- Use overly broad IAM permissions
- Share AWS Account ID publicly
- Reuse OIDC role across multiple repositories unnecessarily
- Disable MFA on AWS account

---

## FAQ

**Q: Do I need to create separate roles for each repository?**
A: No. One role can serve multiple repositories. Just adjust the trust policy to include all repo conditions.

**Q: Can I use a different region?**
A: Yes, replace `us-east-1` with your preferred region in all commands.

**Q: How do I revoke OIDC access?**
A: Delete the IAM role: `aws iam delete-role --role-name GitHubActionsRole`

**Q: Can I limit the role to specific branches?**
A: Yes! Change the trust policy's `StringLike` condition to target specific branches.

**Q: What if I accidentally delete the role?**
A: Run `setup-oidc.sh` again - it handles re-creation.

---

## Next Steps

1. ✅ Run `setup-oidc.sh` OR follow `OIDC_FRESH_SETUP.md`
2. ✅ Add GitHub secrets from `GITHUB_SECRETS.txt`
3. ✅ Push test workflow to GitHub
4. ✅ Run test workflow from Actions tab
5. ✅ Update your main workflows to use OIDC
6. ✅ Remove any old AWS access key secrets

---

## Support

For detailed instructions, see **OIDC_FRESH_SETUP.md**

For automated setup, use **setup-oidc.sh**

Questions? Check the Troubleshooting section above.

Good luck! 🚀
