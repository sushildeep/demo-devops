# Configure GitHub Secrets for Terraform Plan (No Approval)

## Problem
Terraform `plan` should run WITHOUT approval, but it needs access to secrets. Since we removed the environment directive from the terraform-plan job, we need repository-level secrets.

## Solution
Add a shared repository-level secret that terraform-plan can use without approval.

---

## Step 1: Add Repository-Level Secrets

Go to: **Settings → Secrets and variables → Actions → New repository secret**

### Secret 1: TERRAFORM_STATE_BUCKET
- **Name:** `TERRAFORM_STATE_BUCKET`
- **Value:** Use your PROD bucket (e.g., `terraform-state-prod-1791194479`)
- **Why PROD?** Terraform plan should point to the main production state for consistency

### Secret 2: TERRAFORM_LOCK_TABLE
- **Name:** `TERRAFORM_LOCK_TABLE`
- **Value:** `terraform-locks`

### Secret 3: AWS_ACCOUNT_ID (for terraform-plan)
- **Name:** `AWS_ACCOUNT_ID`
- **Value:** `023644376175`

### Secret 4: AWS_ROLE_TO_ASSUME (for terraform-plan)
- **Name:** `AWS_ROLE_TO_ASSUME`
- **Value:** `arn:aws:iam::023644376175:role/GitHubActionsRole`

---

## Current Secret Configuration

### Repository-Level Secrets (for terraform-plan, no approval)
```
TERRAFORM_STATE_BUCKET = terraform-state-prod-XXXXXXXXXX
TERRAFORM_LOCK_TABLE = terraform-locks
AWS_ACCOUNT_ID = 023644376175
AWS_ROLE_TO_ASSUME = arn:aws:iam::023644376175:role/GitHubActionsRole
```

### Environment-Level Secrets (with approval gate)

**DEV Environment:**
```
AWS_ACCOUNT_ID = 023644376175
AWS_ROLE_TO_ASSUME = arn:aws:iam::023644376175:role/GitHubActionsRole
AWS_REGION = us-east-1
TERRAFORM_STATE_BUCKET = terraform-state-dev-XXXXXXXXXX
TERRAFORM_LOCK_TABLE = terraform-locks
```

**PROD Environment:**
```
AWS_ACCOUNT_ID = 023644376175
AWS_ROLE_TO_ASSUME = arn:aws:iam::023644376175:role/GitHubActionsRole
AWS_REGION = us-east-1
TERRAFORM_STATE_BUCKET = terraform-state-prod-XXXXXXXXXX
TERRAFORM_LOCK_TABLE = terraform-locks
```

---

## Approval Flow After This Change

### Terraform Plan (No Approval Required)
```
✅ terraform-plan runs for dev AND prod
   Uses repository-level secrets
   No approval gate
   Shows what WOULD change
```

### Deploy Infrastructure (Approval for Prod Only)
```
✅ deploy-infrastructure (dev) runs without approval
   Uses dev environment secrets
   
🔒 deploy-infrastructure (prod) waits for approval
   Uses prod environment secrets
   Requires explicit approval before applying changes
```

### Deploy Application (Approval for Prod Only)
```
✅ deploy-application (dev) runs without approval
   Uses dev environment secrets
   
🔒 deploy-application (prod) waits for approval
   Uses prod environment secrets
   Requires explicit approval before deploying
```

### Destroy Infrastructure (Always Approval)
```
🔒 destroy-infrastructure (dev) waits for approval
   Uses dev environment secrets
   Requires explicit approval
   
🔒 destroy-infrastructure (prod) waits for approval
   Uses prod environment secrets
   Requires explicit approval
```

---

## How It Works

### Job Access to Secrets

**terraform-plan job:**
- Uses `${{ secrets.TERRAFORM_STATE_BUCKET }}` from repository-level secrets
- Uses `${{ secrets.TERRAFORM_LOCK_TABLE }}` from repository-level secrets
- Uses `${{ secrets.AWS_ACCOUNT_ID }}` from repository-level secrets
- Uses `${{ secrets.AWS_ROLE_TO_ASSUME }}` from repository-level secrets
- ✅ NO environment protection = NO approval needed

**deploy-infrastructure job:**
- When `infra_env = dev`: Uses dev environment secrets (no approval)
- When `infra_env = prod`: Uses prod environment secrets (approval required)
- Overrides state bucket to match environment

**deploy-application job:**
- When `app_env = dev`: Uses dev environment secrets (no approval)
- When `app_env = prod`: Uses prod environment secrets (approval required)

---

## Step-by-Step Setup

### 1. Find Your S3 Bucket Names
```bash
aws s3 ls | grep terraform-state
```

Example output:
```
2026-10-05 15:34:34 terraform-state-dev-1791194479
2026-10-05 15:34:50 terraform-state-prod-1791194479
```

### 2. Go to GitHub Settings
- Repository → Settings
- Secrets and variables
- Actions
- Click "New repository secret"

### 3. Add TERRAFORM_STATE_BUCKET
- Name: `TERRAFORM_STATE_BUCKET`
- Value: `terraform-state-prod-1791194479` (use the PROD bucket)
- Click "Add secret"

### 4. Add TERRAFORM_LOCK_TABLE
- Name: `TERRAFORM_LOCK_TABLE`
- Value: `terraform-locks`
- Click "Add secret"

### 5. Add AWS_ACCOUNT_ID
- Name: `AWS_ACCOUNT_ID`
- Value: `023644376175`
- Click "Add secret"

### 6. Add AWS_ROLE_TO_ASSUME
- Name: `AWS_ROLE_TO_ASSUME`
- Value: `arn:aws:iam::023644376175:role/GitHubActionsRole`
- Click "Add secret"

---

## Verification Checklist

After adding repository-level secrets:

- [ ] `TERRAFORM_STATE_BUCKET` secret exists
- [ ] `TERRAFORM_LOCK_TABLE` secret exists
- [ ] `AWS_ACCOUNT_ID` secret exists
- [ ] `AWS_ROLE_TO_ASSUME` secret exists
- [ ] Environment `dev` has 5 environment secrets
- [ ] Environment `prod` has 5 environment secrets
- [ ] Workflow file has no `environment:` in terraform-plan job

---

## Test the Setup

### Test 1: Terraform Plan Runs Without Approval
1. Go to **Actions** → **Complete CI/CD Orchestration** → **Run workflow**
2. Set:
   - `terraform_plan: true`
   - `infra_environment: dev`
3. Click "Run workflow"
4. **Expected:** terraform-plan-dev runs immediately without waiting for approval ✅
5. **Check:** Logs should show it's using terraform-state-prod bucket from repository secrets

### Test 2: Deploy to Dev (No Approval)
1. Go to **Actions** → **Complete CI/CD Orchestration** → **Run workflow**
2. Set:
   - `deploy_infrastructure: true`
   - `infra_action: apply`
   - `infra_environment: dev`
3. Click "Run workflow"
4. **Expected:** deploy-infrastructure runs without approval ✅
5. **Check:** Should complete automatically

### Test 3: Deploy to Prod (Requires Approval)
1. Go to **Actions** → **Complete CI/CD Orchestration** → **Run workflow**
2. Set:
   - `deploy_infrastructure: true`
   - `infra_action: apply`
   - `infra_environment: prod`
3. Click "Run workflow"
4. **Expected:** Waits for approval 🔒
5. **Check:** "Waiting for review: prod needs approval"

---

## Summary

| Job | Approval? | Uses Secrets From |
|-----|-----------|-------------------|
| terraform-plan | ❌ No | Repository-level |
| deploy-infrastructure (dev) | ❌ No | dev environment |
| deploy-infrastructure (prod) | 🔒 Yes | prod environment |
| deploy-application (dev) | ❌ No | dev environment |
| deploy-application (prod) | 🔒 Yes | prod environment |
| destroy-infrastructure (dev) | 🔒 Yes | dev environment |
| destroy-infrastructure (prod) | 🔒 Yes | prod environment |

Perfect! Now you have:
- ✅ Plan runs fast without approval
- 🔒 Deploy to prod requires approval
- 🔒 Destroy requires approval
- ✅ Dev operations are fast

Good luck! 🚀
