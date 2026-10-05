# OIDC Setup Verification & Fixes

## ✅ What Was Fixed

### IAM Role Trust Policy Updated
The `GitHubActionsRole` trust policy was updated to include your GitHub repository:

**Before:**
```
repo:AdvikCrop/micro-service:*
```

**After:**
```
repo:sushildeep/demo-devops:*
```

This allows GitHub Actions from your repository to assume the IAM role.

---

## ✅ AWS Configuration Status

Your AWS account is properly configured:

| Component | Status | Details |
|-----------|--------|---------|
| AWS Account ID | ✅ | 023644376175 |
| OIDC Provider | ✅ | arn:aws:iam::023644376175:oidc-provider/token.actions.githubusercontent.com |
| IAM Role | ✅ | GitHubActionsRole (updated) |
| Trust Policy | ✅ | repo:sushildeep/demo-devops:* |
| S3 Buckets | ✅ | terraform-state-dev-*, terraform-state-prod-* |
| DynamoDB Table | ✅ | terraform-locks |

---

## 🔍 GitHub Configuration Checklist

Now verify that your GitHub environment secrets are correctly set up.

### Required Environment Secrets - DEV

Go to: **Settings → Environments → dev → Environment secrets**

Make sure these 5 secrets exist:

```
✅ AWS_ACCOUNT_ID = 023644376175
✅ AWS_ROLE_TO_ASSUME = arn:aws:iam::023644376175:role/GitHubActionsRole
✅ AWS_REGION = us-east-1
✅ TERRAFORM_STATE_BUCKET = terraform-state-dev-XXXXXXXXXX
✅ TERRAFORM_LOCK_TABLE = terraform-locks
```

### Required Environment Secrets - PROD

Go to: **Settings → Environments → prod → Environment secrets**

Make sure these 5 secrets exist:

```
✅ AWS_ACCOUNT_ID = 023644376175
✅ AWS_ROLE_TO_ASSUME = arn:aws:iam::023644376175:role/GitHubActionsRole
✅ AWS_REGION = us-east-1
✅ TERRAFORM_STATE_BUCKET = terraform-state-prod-XXXXXXXXXX
✅ TERRAFORM_LOCK_TABLE = terraform-locks
```

**Note:** Check your S3 bucket names from your AWS console (they might have timestamps like `-1791194479`)

---

## 🚀 Next Steps

1. **Verify GitHub Secrets**
   - Go to Settings → Environments → dev
   - Confirm all 5 secrets are present
   - Repeat for prod environment

2. **Verify Workflow Permissions**
   - Check that workflow has: `permissions: id-token: write`
   - This is required for OIDC authentication

3. **Test OIDC**
   - Run the test workflow from Actions tab
   - Go to Actions → Test OIDC Setup → Run workflow
   - Wait for it to complete

4. **Run Terraform Plan**
   - Go to Actions → Complete CI/CD Orchestration → Run workflow
   - Set terraform_plan: true, infra_environment: dev
   - Wait for it to complete

---

## 🔧 Troubleshooting

### If You Still Get "Credentials could not be loaded"

**Step 1: Verify Trust Policy**
```bash
aws iam get-role --role-name GitHubActionsRole --query 'Role.AssumeRolePolicyDocument'
```

Should show:
```json
"token.actions.githubusercontent.com:sub": "repo:sushildeep/demo-devops:*"
```

**Step 2: Verify GitHub Secrets**
- Go to Settings → Environments → dev (or prod)
- Check if all 5 secrets exist
- Check secret values are correct

**Step 3: Verify Workflow Permissions**
```yaml
permissions:
  id-token: write
  contents: read
```

This MUST be present in jobs that use OIDC.

**Step 4: Clear GitHub Cache**
- Go to Actions tab
- Click "Clear all caches" (if available)
- Re-run the workflow

### If Still Failing

Check the workflow logs for the exact error:
1. Go to Actions → workflow name → failed run
2. Click the job that failed (Configure AWS credentials)
3. Check the error message
4. Common issues:
   - Wrong AWS_ROLE_TO_ASSUME value
   - Wrong AWS_ACCOUNT_ID
   - Secrets not found in environment
   - Missing `id-token: write` permission

---

## AWS Verification Commands

```bash
# Verify OIDC Provider
aws iam list-open-id-connect-providers

# Verify IAM Role
aws iam get-role --role-name GitHubActionsRole

# Verify Trust Policy
aws iam get-role --role-name GitHubActionsRole --query 'Role.AssumeRolePolicyDocument'

# Verify Role Policy
aws iam get-role-policy --role-name GitHubActionsRole --policy-name GitHubActionsPolicy

# Verify S3 Buckets
aws s3 ls

# Verify DynamoDB
aws dynamodb describe-table --table-name terraform-locks
```

---

## Configuration Summary

Your OIDC setup is configured as follows:

```
GitHub Repository: sushildeep/demo-devops
AWS Account ID: 023644376175
IAM Role: GitHubActionsRole
OIDC Provider: token.actions.githubusercontent.com

Trust Policy allows:
- Any ref (branch, tag, environment)
- repo:sushildeep/demo-devops:*

Environment Secrets:
- dev environment secrets point to dev resources
- prod environment secrets point to prod resources
```

This means:
- ✅ GitHub Actions can authenticate with AWS OIDC
- ✅ No long-lived AWS credentials needed
- ✅ Automatic credential rotation
- ✅ Better audit trail

---

## Ready to Test!

Once you verify the GitHub environment secrets are set up correctly, you're ready to:

1. ✅ Test OIDC with Test OIDC Setup workflow
2. ✅ Run Terraform plan for dev
3. ✅ Build and push Docker images
4. ✅ Deploy to dev (no approval)
5. ✅ Deploy to prod (with approval)
6. ✅ Destroy infrastructure (with approval)

Good luck! 🚀
