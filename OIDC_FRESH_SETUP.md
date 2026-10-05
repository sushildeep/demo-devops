# Fresh OIDC Setup Guide - Complete From Scratch

This guide walks you through setting up GitHub Actions OIDC authentication with AWS from the beginning.

---

## Prerequisites

Before starting, ensure you have:
1. **AWS CLI installed** - Check with: `aws --version`
2. **AWS Account with admin access**
3. **GitHub repository created**
4. **Git installed** - Check with: `git --version`

---

## STEP 1: Get Your AWS Account ID

Run this command to get your AWS Account ID:

```bash
aws sts get-caller-identity
```

**Output should look like:**
```json
{
    "UserId": "AIDAI...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:root"
}
```

**Save your Account ID:** `123456789012` (this is an example - use your actual ID)

---

## STEP 2: Get Your GitHub Repository Info

You need:
- **GitHub Organization/Username** (e.g., `sushildeep`)
- **Repository Name** (e.g., `demo-devops`)
- **Branch Name** (typically `main`)

**Format needed:** `repo:OWNER/REPO:ref:refs/heads/BRANCH`

**Example:** `repo:sushildeep/demo-devops:ref:refs/heads/main`

---

## STEP 3: Create OIDC Provider in AWS

This registers GitHub as a trusted identity provider with AWS.

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --region us-east-1
```

**Expected output:**
```json
{
    "OpenIDConnectProviderArn": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
}
```

**Save this ARN.** You'll need it in the next step.

---

## STEP 4: Create Trust Policy

Create a `trust-policy.json` file. Replace the values with YOUR information:

```bash
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_GITHUB_REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF
```

**Replace these:**
- `YOUR_ACCOUNT_ID` → Your 12-digit AWS Account ID
- `YOUR_GITHUB_ORG` → Your GitHub username/organization (e.g., `sushildeep`)
- `YOUR_GITHUB_REPO` → Your repository name (e.g., `demo-devops`)

**Example for sushildeep/demo-devops:**
```bash
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:sushildeep/demo-devops:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF
```

---

## STEP 5: Create IAM Role

```bash
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://trust-policy.json \
  --region us-east-1
```

**Expected output:**
```json
{
    "Role": {
        "RoleName": "GitHubActionsRole",
        "Arn": "arn:aws:iam::123456789012:role/GitHubActionsRole",
        ...
    }
}
```

**Save the Role ARN:** `arn:aws:iam::123456789012:role/GitHubActionsRole`

---

## STEP 6: Create IAM Policy

Create the policy JSON file:

```bash
cat > github-actions-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:CreateRepository",
        "ecr:DescribeRepositories"
      ],
      "Resource": "arn:aws:ecr:us-east-1:*:repository/*"
    },
    {
      "Sid": "S3StateAccess",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetBucketVersioning",
        "s3:ListBucketVersions"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-*",
        "arn:aws:s3:::terraform-state-*/*"
      ]
    },
    {
      "Sid": "DynamoDBLocking",
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:DeleteItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:*:table/terraform-locks"
    },
    {
      "Sid": "EKSAccess",
      "Effect": "Allow",
      "Action": [
        "eks:DescribeClusters",
        "eks:ListClusters",
        "eks:DescribeNodegroup",
        "eks:ListNodegroups"
      ],
      "Resource": "arn:aws:eks:us-east-1:*:cluster/*"
    },
    {
      "Sid": "TerraformFullAccess",
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "rds:*",
        "iam:*",
        "s3:*",
        "cloudformation:*",
        "logs:*",
        "sns:*",
        "sqs:*",
        "kms:*",
        "autoscaling:*",
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
```

---

## STEP 7: Attach Policy to Role

```bash
aws iam put-role-policy \
  --role-name GitHubActionsRole \
  --policy-name GitHubActionsPolicy \
  --policy-document file://github-actions-policy.json
```

**Verify it was attached:**
```bash
aws iam get-role-policy \
  --role-name GitHubActionsRole \
  --policy-name GitHubActionsPolicy
```

---

## STEP 8: Create S3 Buckets for Terraform State

### Create Dev Bucket:
```bash
aws s3api create-bucket \
  --bucket terraform-state-dev-$(date +%s) \
  --region us-east-1 \
  --acl private

aws s3api put-bucket-versioning \
  --bucket terraform-state-dev-$(date +%s) \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block \
  --bucket terraform-state-dev-$(date +%s) \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### Create Prod Bucket:
```bash
aws s3api create-bucket \
  --bucket terraform-state-prod-$(date +%s) \
  --region us-east-1 \
  --acl private

aws s3api put-bucket-versioning \
  --bucket terraform-state-prod-$(date +%s) \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block \
  --bucket terraform-state-prod-$(date +%s) \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

**Verify buckets:**
```bash
aws s3 ls | grep terraform-state
```

**Note the bucket names, you'll need them later.**

---

## STEP 9: Create DynamoDB Table for State Locking

```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

**Verify:**
```bash
aws dynamodb describe-table \
  --table-name terraform-locks \
  --query 'Table.TableStatus'
```

Should output: `"ACTIVE"`

---

## STEP 10: Add GitHub Secrets

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these 4 secrets:

### Secret 1: AWS_ACCOUNT_ID
- **Name:** `AWS_ACCOUNT_ID`
- **Value:** `123456789012` (your actual Account ID)

### Secret 2: AWS_ROLE_TO_ASSUME
- **Name:** `AWS_ROLE_TO_ASSUME`
- **Value:** `arn:aws:iam::123456789012:role/GitHubActionsRole` (use your Account ID)

### Secret 3: AWS_REGION
- **Name:** `AWS_REGION`
- **Value:** `us-east-1`

### Secret 4: TERRAFORM_STATE_BUCKET
- **Name:** `TERRAFORM_STATE_BUCKET`
- **Value:** `terraform-state-prod-XXXXXXXXXX` (your prod bucket name from Step 8)

### Secret 5: TERRAFORM_LOCK_TABLE
- **Name:** `TERRAFORM_LOCK_TABLE`
- **Value:** `terraform-locks`

---

## STEP 11: Verify OIDC Setup

### Check OIDC Provider:
```bash
aws iam list-open-id-connect-providers
```

Should show your GitHub OIDC provider ARN.

### Check IAM Role:
```bash
aws iam get-role --role-name GitHubActionsRole
```

### Check Role Policy:
```bash
aws iam get-role-policy \
  --role-name GitHubActionsRole \
  --policy-name GitHubActionsPolicy
```

### Check S3 Buckets:
```bash
aws s3 ls | grep terraform-state
```

### Check DynamoDB:
```bash
aws dynamodb describe-table --table-name terraform-locks
```

---

## STEP 12: Test OIDC with GitHub Actions

Create a test workflow file at `.github/workflows/test-oidc.yml`:

```yaml
name: Test OIDC Setup

on:
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Test AWS Access
        run: |
          echo "Testing AWS access..."
          aws sts get-caller-identity
          echo "✅ AWS access successful!"

      - name: Test S3 Access
        run: |
          echo "Testing S3 bucket access..."
          aws s3 ls ${{ secrets.TERRAFORM_STATE_BUCKET }}
          echo "✅ S3 access successful!"

      - name: Test DynamoDB Access
        run: |
          echo "Testing DynamoDB access..."
          aws dynamodb describe-table --table-name ${{ secrets.TERRAFORM_LOCK_TABLE }}
          echo "✅ DynamoDB access successful!"

      - name: Test ECR Access
        run: |
          echo "Testing ECR access..."
          aws ecr get-authorization-token
          echo "✅ ECR access successful!"
```

Push this to GitHub and run it manually from **Actions** → **Test OIDC Setup** → **Run workflow**.

---

## Troubleshooting

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Solution:**
1. Check trust-policy.json has correct GitHub org/repo
2. Verify `token.actions.githubusercontent.com:aud` is set to `sts.amazonaws.com`
3. Re-apply trust policy:
```bash
aws iam update-assume-role-policy \
  --role-name GitHubActionsRole \
  --policy-document file://trust-policy.json
```

### Error: "User: arn:aws:iam::... is not authorized"

**Solution:**
1. Verify policy is attached:
```bash
aws iam get-role-policy \
  --role-name GitHubActionsRole \
  --policy-name GitHubActionsPolicy
```
2. Re-attach if needed:
```bash
aws iam put-role-policy \
  --role-name GitHubActionsRole \
  --policy-name GitHubActionsPolicy \
  --policy-document file://github-actions-policy.json
```

### Error: "NoSuchBucket"

**Solution:**
```bash
aws s3 ls  # Check bucket names
aws s3api create-bucket \
  --bucket terraform-state-prod-XXXXXXXXXX \
  --region us-east-1
```

### Error: "ResourceNotFoundException" (DynamoDB)

**Solution:**
```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

---

## Quick Summary

| Step | What to Do | Command |
|------|-----------|---------|
| 1 | Get Account ID | `aws sts get-caller-identity` |
| 2 | Create OIDC Provider | Step 3 command |
| 3 | Create Trust Policy | Create trust-policy.json |
| 4 | Create IAM Role | Step 5 command |
| 5 | Create IAM Policy | Create github-actions-policy.json |
| 6 | Attach Policy | Step 7 command |
| 7 | Create S3 Buckets | Step 8 commands |
| 8 | Create DynamoDB Table | Step 9 command |
| 9 | Add GitHub Secrets | GitHub Settings |
| 10 | Verify Setup | Verification commands |
| 11 | Test with Workflow | Create test-oidc.yml |

---

## Next Steps

1. ✅ Follow Steps 1-12 above
2. ✅ Push test-oidc.yml to GitHub
3. ✅ Run the test workflow
4. ✅ Once test passes, update your main workflow to use OIDC
5. ✅ Remove any AWS access keys from your GitHub secrets

Good luck! 🚀
