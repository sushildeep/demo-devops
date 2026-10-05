#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   GitHub Actions OIDC Setup from Scratch${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Step 1: Get AWS Account ID
echo -e "${YELLOW}Step 1: Getting AWS Account ID...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}❌ Failed to get AWS Account ID. Check AWS CLI configuration.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ AWS Account ID: $AWS_ACCOUNT_ID${NC}"
echo ""

# Step 2: Get GitHub Info
echo -e "${YELLOW}Step 2: Getting GitHub repository information...${NC}"
read -p "Enter your GitHub username/organization (e.g., sushildeep): " GITHUB_ORG
read -p "Enter your GitHub repository name (e.g., demo-devops): " GITHUB_REPO
read -p "Enter your branch name (default: main): " GITHUB_BRANCH
GITHUB_BRANCH=${GITHUB_BRANCH:-main}

GITHUB_REPO_FULL="repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/$GITHUB_BRANCH"
echo -e "${GREEN}✅ Repository: $GITHUB_REPO_FULL${NC}"
echo ""

# Step 3: Create OIDC Provider
echo -e "${YELLOW}Step 3: Creating OIDC Provider in AWS...${NC}"
OIDC_PROVIDER_ARN=$(aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --region us-east-1 \
  --query OpenIDConnectProviderArn \
  --output text 2>/dev/null)

if [ -z "$OIDC_PROVIDER_ARN" ]; then
    echo -e "${YELLOW}⚠️  OIDC Provider may already exist, fetching existing...${NC}"
    OIDC_PROVIDER_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
fi
echo -e "${GREEN}✅ OIDC Provider ARN: $OIDC_PROVIDER_ARN${NC}"
echo ""

# Step 4: Create Trust Policy
echo -e "${YELLOW}Step 4: Creating trust policy...${NC}"
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_PROVIDER_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "$GITHUB_REPO_FULL"
        }
      }
    }
  ]
}
EOF
echo -e "${GREEN}✅ Trust policy created${NC}"
echo ""

# Step 5: Create IAM Role
echo -e "${YELLOW}Step 5: Creating IAM Role...${NC}"
ROLE_ARN=$(aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://trust-policy.json \
  --region us-east-1 \
  --query Role.Arn \
  --output text 2>/dev/null)

if [ -z "$ROLE_ARN" ]; then
    echo -e "${YELLOW}⚠️  Role may already exist, fetching existing...${NC}"
    ROLE_ARN=$(aws iam get-role --role-name GitHubActionsRole --query Role.Arn --output text)
fi
echo -e "${GREEN}✅ IAM Role ARN: $ROLE_ARN${NC}"
echo ""

# Step 6 & 7: Create and Attach IAM Policy
echo -e "${YELLOW}Step 6: Creating IAM Policy...${NC}"
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
echo -e "${GREEN}✅ Policy created${NC}"
echo ""

echo -e "${YELLOW}Step 7: Attaching policy to role...${NC}"
aws iam put-role-policy \
  --role-name GitHubActionsRole \
  --policy-name GitHubActionsPolicy \
  --policy-document file://github-actions-policy.json
echo -e "${GREEN}✅ Policy attached${NC}"
echo ""

# Step 8: Create S3 Buckets
echo -e "${YELLOW}Step 8: Creating S3 buckets...${NC}"
TIMESTAMP=$(date +%s)
DEV_BUCKET="terraform-state-dev-$TIMESTAMP"
PROD_BUCKET="terraform-state-prod-$TIMESTAMP"

aws s3api create-bucket \
  --bucket "$DEV_BUCKET" \
  --region us-east-1 \
  --acl private 2>/dev/null || echo "Dev bucket may already exist"

aws s3api put-bucket-versioning \
  --bucket "$DEV_BUCKET" \
  --versioning-configuration Status=Enabled 2>/dev/null

aws s3api put-public-access-block \
  --bucket "$DEV_BUCKET" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" 2>/dev/null

aws s3api create-bucket \
  --bucket "$PROD_BUCKET" \
  --region us-east-1 \
  --acl private 2>/dev/null || echo "Prod bucket may already exist"

aws s3api put-bucket-versioning \
  --bucket "$PROD_BUCKET" \
  --versioning-configuration Status=Enabled 2>/dev/null

aws s3api put-public-access-block \
  --bucket "$PROD_BUCKET" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" 2>/dev/null

echo -e "${GREEN}✅ S3 Buckets created:${NC}"
echo -e "${GREEN}   Dev:  $DEV_BUCKET${NC}"
echo -e "${GREEN}   Prod: $PROD_BUCKET${NC}"
echo ""

# Step 9: Create DynamoDB Table
echo -e "${YELLOW}Step 9: Creating DynamoDB table...${NC}"
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1 2>/dev/null || echo "Table may already exist"

echo -e "${GREEN}✅ DynamoDB table created${NC}"
echo ""

# Step 10: Create GitHub Secrets file
echo -e "${YELLOW}Step 10: Creating GitHub secrets configuration...${NC}"
cat > GITHUB_SECRETS.txt << EOF
Add these secrets to your GitHub repository:
Location: GitHub → Settings → Secrets and variables → Actions

Secret 1:
  Name: AWS_ACCOUNT_ID
  Value: $AWS_ACCOUNT_ID

Secret 2:
  Name: AWS_ROLE_TO_ASSUME
  Value: $ROLE_ARN

Secret 3:
  Name: AWS_REGION
  Value: us-east-1

Secret 4:
  Name: TERRAFORM_STATE_BUCKET
  Value: $PROD_BUCKET

Secret 5:
  Name: TERRAFORM_LOCK_TABLE
  Value: terraform-locks
EOF
echo -e "${GREEN}✅ Secrets configuration saved to GITHUB_SECRETS.txt${NC}"
echo ""

# Step 11: Verification
echo -e "${YELLOW}Step 11: Verifying setup...${NC}"
echo -e "${BLUE}Checking OIDC Provider:${NC}"
aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[*].Arn' --output text

echo ""
echo -e "${BLUE}Checking IAM Role:${NC}"
aws iam get-role --role-name GitHubActionsRole --query 'Role.Arn' --output text

echo ""
echo -e "${BLUE}Checking S3 Buckets:${NC}"
aws s3 ls | grep terraform-state

echo ""
echo -e "${BLUE}Checking DynamoDB Table:${NC}"
aws dynamodb describe-table --table-name terraform-locks --query 'Table.TableStatus' --output text

echo ""
echo -e "${GREEN}✅ Verification complete!${NC}"
echo ""

# Summary
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}   OIDC Setup Complete!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "GitHub Repo: $GITHUB_REPO_FULL"
echo "IAM Role ARN: $ROLE_ARN"
echo "Dev Bucket: $DEV_BUCKET"
echo "Prod Bucket: $PROD_BUCKET"
echo "DynamoDB Table: terraform-locks"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Open GITHUB_SECRETS.txt file"
echo "2. Go to your GitHub repository settings"
echo "3. Add all 5 secrets from GITHUB_SECRETS.txt"
echo "4. Create .github/workflows/test-oidc.yml workflow file"
echo "5. Push changes to GitHub"
echo "6. Run the test workflow from Actions tab"
echo ""
echo -e "${GREEN}Good luck! 🚀${NC}"
