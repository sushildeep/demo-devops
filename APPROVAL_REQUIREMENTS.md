# GitHub Actions Approval Requirements

This document outlines which workflow jobs require manual approval before execution.

## Approval Matrix

### ✅ No Approval Required
- **deployment-config** - Configuration determination
- **quality-checks** - Code formatting and validation
- **test** - Unit and integration tests
- **terraform-plan** - Terraform plan (dev or prod) - *visibility only, no approval*
- **build-images** - Build Docker images for dev or prod
- **security-scan** - Security scanning (Trivy, Bandit)

### 🔒 Approval Required (Protected Environments)

| Job | Trigger | Environment | Approval Required |
|-----|---------|-------------|------------------|
| **deploy-infrastructure** | Deploy to **prod** | prod | ✅ Yes |
| **deploy-infrastructure** | Deploy to **dev** | none | ❌ No |
| **deploy-application** | Deploy to **prod** | prod | ✅ Yes |
| **deploy-application** | Deploy to **dev** | none | ❌ No |
| **destroy-infrastructure** | Destroy **dev** | dev | ✅ **Yes** |
| **destroy-infrastructure** | Destroy **prod** | prod | ✅ **Yes** |

---

## Detailed Workflow Behavior

### 1. Build Pipeline (No Approval)
```
deployment-config
    ↓
quality-checks ──→ test
    ↓
terraform-plan (dev & prod matrix) ← No approval, runs both
```

### 2. Build & Publish Images (No Approval)
```
build-images ──→ security-scan ← No approval needed
```

### 3. Deploy to Dev (No Approval)
```
deploy-infrastructure (dev) ← No environment protection
         ↓
deploy-application (dev) ← No environment protection
```

### 4. Deploy to Prod (Requires Approval) 🔒
```
deploy-infrastructure (prod) ← Requires 'prod' environment approval
         ↓
deploy-application (prod) ← Requires 'prod' environment approval
```

### 5. Destroy Infrastructure (Requires Approval) 🔒
```
destroy-infrastructure ← Requires environment approval (dev or prod)
```

---

## Approval Flow Example

### Scenario 1: Build Images + Deploy to Dev
```
1. User triggers workflow
2. deployment-config runs
3. quality-checks & test run
4. terraform-plan runs (dev & prod)
5. build-images runs ✅ (no approval needed)
6. security-scan runs ✅ (no approval needed)
7. deploy-infrastructure (dev) runs ✅ (no approval)
8. deploy-application (dev) runs ✅ (no approval)
✅ Workflow completes automatically
```

### Scenario 2: Build Images + Deploy to Prod
```
1. User triggers workflow with app_environment = prod
2. deployment-config runs
3. quality-checks & test run
4. terraform-plan runs (dev & prod)
5. build-images runs ✅ (no approval needed)
6. security-scan runs ✅ (no approval needed)
7. deploy-infrastructure (prod) waits... 🔒
   ↓
   GitHub Actions shows: "Waiting for review: prod needs approval"
   ↓
   You must approve the deployment
   ↓
8. deploy-application (prod) waits... 🔒
   ↓
   GitHub Actions shows: "Waiting for review: prod needs approval"
   ↓
   You must approve the deployment
   ↓
✅ Workflow completes after approvals
```

### Scenario 3: Destroy Infrastructure
```
1. User triggers workflow with destroy_infrastructure = true
2. destroy-infrastructure waits... 🔒
   ↓
   GitHub Actions shows: "Waiting for review: [dev/prod] needs approval"
   ↓
   You must approve the destruction
   ↓
✅ Infrastructure destroyed after approval
```

---

## How to Approve Deployments

### Method 1: GitHub Actions Web UI
1. Go to **Actions** tab in your repository
2. Click the workflow run that's waiting for approval
3. You'll see "Review pending deployments" button
4. Click it
5. Select the environment to approve
6. Click **Approve and deploy**

### Method 2: Environment Review URL
When a workflow is waiting for approval, GitHub sends you a notification with a link. Click it to approve directly.

---

## Environment Protection Rules

### Prod Environment Protection (Required for Approval)
✅ **REQUIRED** - Must have protection rules enabled for prod deployments and destruction

```
Settings → Environments → prod → Deployment protection rules
```

**Setup instructions:**
1. Go to Settings → Environments → prod
2. Under "Deployment protection rules"
3. ✅ Check "Required reviewers"
4. Select reviewers/teams who can approve prod operations
5. ✅ Check "Prevent admins from bypassing these rules"

### Dev Environment Protection (Recommended for Destruction)
⚠️ **RECOMMENDED** - Add protection rules to require approval for destroying dev infrastructure

```
Settings → Environments → dev → Deployment protection rules
```

**Setup instructions:**
1. Go to Settings → Environments → dev
2. Under "Deployment protection rules"
3. ✅ Check "Required reviewers"
4. Select reviewers/teams who can approve destruction
5. ✅ Check "Prevent admins from bypassing these rules"

**Note:** 
- Dev deployments do NOT require approval
- Dev DESTRUCTION does require approval (if protection rules are enabled)

---

## Terraform Plan Without Approval

The `terraform-plan` job runs for **both dev and prod in a matrix** without requiring approval. This allows you to:
- See what changes will be made to both environments
- Review the plan before deploying
- Decide whether to proceed with deployment

**View the plan:**
1. Go to **Actions** → **Complete CI/CD Orchestration** → [your run]
2. Click **Terraform Plan - dev** or **Terraform Plan - prod** job
3. Scroll through logs to see planned changes

---

## Common Workflows

### ✅ Fast Dev Deployment (Typical Development)
```bash
# Trigger with:
- build_images: true
- deploy_infrastructure: false
- deploy_application: true
- app_environment: dev
- run_tests: true

# Result: Build, test, and deploy to dev automatically ✅
```

### 🔒 Careful Prod Deployment (Release)
```bash
# Trigger with:
- build_images: true
- terraform_plan: true
- infra_environment: prod
- deploy_infrastructure: true
- infra_action: apply
- deploy_application: true
- app_environment: prod
- run_tests: true

# Result:
# 1. Build & test automatically ✅
# 2. Plan infrastructure for prod ✅
# 3. Wait for approval before deploying to prod 🔒
```

### 🔥 Infrastructure Cleanup (Destroy)
```bash
# Trigger with:
- destroy_infrastructure: true
- infra_environment: [dev or prod]

# Result: Wait for approval before destroying 🔒
```

---

## Modified Workflow Configuration

The following jobs were updated:

### 1. build-images
```yaml
# BEFORE: environment: name: ${{ needs.deployment-config.outputs.app_env }}
# AFTER: (no environment directive)
# Result: ✅ No approval required
```

### 2. security-scan
```yaml
# BEFORE: environment: name: ${{ needs.deployment-config.outputs.app_env }}
# AFTER: (no environment directive)
# Result: ✅ No approval required
```

### 3. deploy-infrastructure
```yaml
# BEFORE: environment: name: ${{ needs.deployment-config.outputs.infra_env }}
# AFTER: environment: name: ${{ needs.deployment-config.outputs.infra_env == 'prod' && 'prod' || '' }}
# Result: ✅ Dev deploys auto-approve, 🔒 Prod requires approval
```

### 4. deploy-application
```yaml
# BEFORE: environment: name: ${{ needs.deployment-config.outputs.app_env }}
# AFTER: environment: name: ${{ needs.deployment-config.outputs.app_env == 'prod' && 'prod' || '' }}
# Result: ✅ Dev deploys auto-approve, 🔒 Prod requires approval
```

### 5. destroy-infrastructure
```yaml
# BEFORE: environment: name: ${{ needs.deployment-config.outputs.infra_env == 'prod' && 'prod' || 'dev' }}
# AFTER: (no changes)
# Result: 🔒 Always requires approval (dev or prod)
```

---

## Testing Approval Requirements

### Test 1: Build to Dev (Should Complete Automatically)
1. Go to **Actions** → **Complete CI/CD Orchestration** → **Run workflow**
2. Set:
   - `build_images: true`
   - `run_tests: true`
   - `deploy_application: true`
   - `app_environment: dev`
3. Click **Run workflow**
4. **Expected:** All jobs complete without waiting for approval ✅

### Test 2: Deploy to Prod (Should Wait for Approval)
1. Go to **Actions** → **Complete CI/CD Orchestration** → **Run workflow**
2. Set:
   - `build_images: true`
   - `deploy_infrastructure: true`
   - `infra_action: apply`
   - `infra_environment: prod`
   - `deploy_application: true`
   - `app_environment: prod`
3. Click **Run workflow**
4. **Expected:** Workflow waits at `deploy-infrastructure (prod)` and `deploy-application (prod)` 🔒
5. Click "Review pending deployments" to approve

### Test 3: Destroy Infrastructure (Should Wait for Approval)
1. Go to **Actions** → **Complete CI/CD Orchestration** → **Run workflow**
2. Set:
   - `destroy_infrastructure: true`
   - `infra_environment: dev`
3. Click **Run workflow**
4. **Expected:** Workflow waits at `destroy-infrastructure` 🔒
5. Click "Review pending deployments" to approve

---

## Destruction Approval Details

### 🔥 All Destruction Operations Require Approval

The `destroy-infrastructure` job **ALWAYS** requires approval, regardless of environment:

```yaml
destroy-infrastructure:
  environment:
    name: ${{ needs.deployment-config.outputs.infra_env }}
    # Routes to 'dev' or 'prod' environment for approval
```

### Destroy Dev Infrastructure
```
1. User triggers: destroy_infrastructure = true, infra_environment = dev
2. destroy-infrastructure waits for approval... 🔒
3. Routes to 'dev' environment protection rules
4. If dev has protection rules → requires approval
5. If dev has no rules → runs immediately (NOT SAFE)
```

**To prevent accidents, ensure dev environment HAS protection rules enabled.**

### Destroy Prod Infrastructure
```
1. User triggers: destroy_infrastructure = true, infra_environment = prod
2. destroy-infrastructure waits for approval... 🔒
3. Routes to 'prod' environment protection rules
4. Requires approval (prod must have rules) ✅
```

**Prod approval is MANDATORY** - prod environment must have protection rules enabled.

---

## Summary

| Category | Requires Approval |
|----------|-------------------|
| Build & Test | ❌ No |
| Deploy to Dev | ❌ No |
| Deploy to Prod | 🔒 Yes |
| **Destroy Dev** | 🔒 **Yes** (if rules enabled) |
| **Destroy Prod** | 🔒 **Yes** (required) |

This ensures:
- ✅ Fast development cycles (dev deploys automatically)
- 🔒 Safe production deployments (require explicit approval)
- 🔒 Protected destructive operations (prevent accidents on all environments)

Good luck! 🚀
