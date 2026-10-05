# Workflow Updates - Environment-Level Secrets

This document summarizes the changes made to use environment-level secrets in GitHub Actions workflows.

## Changes Made

### Updated File: `.github/workflows/orchestrate.yml`

#### 1. **Terraform Plan Job** (Line 251)
Added environment directive to use environment-specific secrets:

```yaml
terraform-plan:
  name: Terraform Plan - ${{ matrix.environment }}
  needs: quality-checks
  if: ${{ github.event.inputs.terraform_plan != 'false' }}
  runs-on: ubuntu-latest
  strategy:
    matrix:
      environment: [dev, prod]
  environment:
    name: ${{ matrix.environment }}  # ← ADDED
  permissions:
    id-token: write
    contents: read
```

**Effect:** 
- Terraform plan for `dev` uses secrets from `dev` environment
- Terraform plan for `prod` uses secrets from `prod` environment

#### 2. **Build Images Job** (Line 386)
Added environment directive to use app environment secrets:

```yaml
build-images:
  needs: [deployment-config]
  if: ${{ needs.deployment-config.outputs.build_images == 'true' }}
  runs-on: ubuntu-latest
  environment:
    name: ${{ needs.deployment-config.outputs.app_env }}  # ← ADDED
  permissions:
    id-token: write
    contents: read
```

**Effect:**
- Uses secrets from dev/prod environment based on `app_env` input

#### 3. **Security Scan Job** (Line 435)
Added environment directive to use app environment secrets:

```yaml
security-scan:
  needs: [deployment-config, build-images]
  if: ${{ github.event.inputs.run_security_scan != 'false' && needs.deployment-config.outputs.build_images == 'true' }}
  runs-on: ubuntu-latest
  environment:
    name: ${{ needs.deployment-config.outputs.app_env }}  # ← ADDED
  permissions:
    id-token: write
    contents: read
```

**Effect:**
- Uses secrets from dev/prod environment based on `app_env` input

#### 4. **Deploy Infrastructure Job** (Line 478)
Already has environment directive (no change needed):

```yaml
deploy-infrastructure:
  needs: [deployment-config, quality-checks, terraform-plan]
  if: ${{ needs.deployment-config.outputs.deploy_infra == 'true' && github.event.inputs.infra_action == 'apply' }}
  runs-on: ubuntu-latest
  environment:
    name: ${{ needs.deployment-config.outputs.infra_env }}  # ← Already present
  permissions:
    id-token: write
    contents: read
```

#### 5. **Deploy Application Job** (Line 555)
Already has environment directive (no change needed):

```yaml
deploy-application:
  needs: [deployment-config, build-images, deploy-infrastructure, security-scan]
  if: ${{ needs.deployment-config.outputs.deploy_app == 'true' && (github.event.inputs.deploy_infrastructure == 'false' || github.event.inputs.infra_action == 'apply' || success()) }}
  runs-on: ubuntu-latest
  environment:
    name: ${{ needs.deployment-config.outputs.app_env }}  # ← Already present
  permissions:
    id-token: write
    contents: read
```

---

## How Environment Secrets Work

### Before (Repository-Level Secrets)
```
Repository Secrets
├── AWS_ACCOUNT_ID
├── AWS_ROLE_TO_ASSUME
├── AWS_REGION
├── TERRAFORM_STATE_BUCKET
└── TERRAFORM_LOCK_TABLE
```
All jobs use the same secrets regardless of environment.

### After (Environment-Level Secrets)
```
dev Environment Secrets          prod Environment Secrets
├── AWS_ACCOUNT_ID               ├── AWS_ACCOUNT_ID
├── AWS_ROLE_TO_ASSUME           ├── AWS_ROLE_TO_ASSUME
├── AWS_REGION                   ├── AWS_REGION
├── TERRAFORM_STATE_BUCKET       ├── TERRAFORM_STATE_BUCKET
└── TERRAFORM_LOCK_TABLE         └── TERRAFORM_LOCK_TABLE
```
Each environment has its own secrets, and jobs reference them based on the environment.

---

## Environment Secret Values

### Dev Environment
| Secret | Value |
|--------|-------|
| AWS_ACCOUNT_ID | Your AWS Account ID |
| AWS_ROLE_TO_ASSUME | arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsRole |
| AWS_REGION | us-east-1 |
| TERRAFORM_STATE_BUCKET | terraform-state-dev-XXXXXXXXXX |
| TERRAFORM_LOCK_TABLE | terraform-locks |

### Prod Environment
| Secret | Value |
|--------|-------|
| AWS_ACCOUNT_ID | Your AWS Account ID |
| AWS_ROLE_TO_ASSUME | arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsRole |
| AWS_REGION | us-east-1 |
| TERRAFORM_STATE_BUCKET | terraform-state-prod-XXXXXXXXXX |
| TERRAFORM_LOCK_TABLE | terraform-locks |

---

## Job Flow with Environment Secrets

```
1. deployment-config
   └─ Determines build/deploy configuration
   
2. quality-checks & test
   └─ No AWS access needed
   
3. terraform-plan
   ├─ Uses dev environment secrets → dev Terraform state
   └─ Uses prod environment secrets → prod Terraform state
   
4. build-images
   ├─ If app_env=dev → uses dev environment secrets
   └─ If app_env=prod → uses prod environment secrets
   
5. security-scan
   ├─ If app_env=dev → uses dev environment secrets
   └─ If app_env=prod → uses prod environment secrets
   
6. deploy-infrastructure
   ├─ If infra_env=dev → uses dev environment secrets
   └─ If infra_env=prod → uses prod environment secrets
   
7. deploy-application
   ├─ If app_env=dev → uses dev environment secrets
   └─ If app_env=prod → uses prod environment secrets
```

---

## Benefits of Environment-Level Secrets

✅ **Separation of Concerns**
- Dev secrets are isolated from prod secrets
- Easier to manage different credentials per environment

✅ **Enhanced Security**
- Environment protection rules can require approvals
- Can restrict who can deploy to prod
- Audit trail per environment

✅ **Clear Audit Trail**
- See exactly which environment used which secrets
- Easier to track credential usage

✅ **Flexible Permission Management**
- Different teams can manage dev vs prod secrets
- Can require additional approvals for prod deployments

---

## Testing the Workflow

### Run Terraform Plan for Dev
1. Go to **Actions** → **Complete CI/CD Orchestration** → **Run workflow**
2. Set:
   - `Deploy infrastructure?` → `false`
   - `Run Terraform plan and drift detection?` → `true`
   - `Infrastructure environment` → `dev`
3. Click **Run workflow**
4. Watch the logs - it should use **dev environment secrets**

### Run Terraform Plan for Prod
1. Go to **Actions** → **Complete CI/CD Orchestration** → **Run workflow**
2. Set:
   - `Deploy infrastructure?` → `false`
   - `Run Terraform plan and drift detection?` → `true`
   - `Infrastructure environment` → `prod`
3. Click **Run workflow**
4. Watch the logs - it should use **prod environment secrets**

---

## Troubleshooting

### Workflow Can't Access Secrets
**Problem:** "Secret not found" error in logs

**Solution:**
1. Check if environment-level secrets are added to GitHub
2. Go to Settings → Environments → [dev/prod] → Environment secrets
3. Verify all 5 secrets are present
4. Check that job has `environment: name: dev` or `environment: name: prod`

### Wrong Bucket Being Used
**Problem:** Terraform using wrong state bucket

**Solution:**
1. Check the TERRAFORM_STATE_BUCKET value for each environment
2. Verify it matches the actual S3 bucket names
3. Ensure dev uses dev bucket and prod uses prod bucket

### Approval Required Error
**Problem:** Job fails with "Approval required"

**Solution:**
1. This is expected for protected environments
2. Go to the workflow run and approve the deployment
3. Check environment protection rules in Settings → Environments

---

## Next Steps

1. ✅ Verify environment-level secrets are added to both dev and prod
2. ✅ Run test workflow to verify OIDC setup
3. ✅ Run orchestrate workflow with terraform_plan enabled
4. ✅ Monitor logs to confirm correct environment secrets are used
5. ✅ Test with build_images enabled to verify ECR access

---

## Related Documentation

- [OIDC_SETUP_README.md](OIDC_SETUP_README.md) - OIDC setup instructions
- [OIDC_FRESH_SETUP.md](OIDC_FRESH_SETUP.md) - Detailed OIDC setup steps
- [.github/workflows/orchestrate.yml](.github/workflows/orchestrate.yml) - Main workflow file

Good luck! 🚀
