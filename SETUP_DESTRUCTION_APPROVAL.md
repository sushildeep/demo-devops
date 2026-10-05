# Setup Destruction Approval Requirements

This guide explains how to ensure that destroying infrastructure requires approval in both dev and prod environments.

## Current Setup

The workflow is configured so that **ALL destruction operations require approval**:

```yaml
destroy-infrastructure:
  environment:
    name: ${{ needs.deployment-config.outputs.infra_env }}  # dev or prod
```

This means destruction operations will use the GitHub environment protection rules for either dev or prod.

---

## Required: Set Up Prod Environment Protection

### ✅ MANDATORY - Prod Must Have Protection Rules

**Why?** Destroying prod infrastructure is critical and must require approval.

### Step-by-Step Setup

1. **Go to GitHub Repository Settings**
   - Click on **Settings** tab in your repository
   - Scroll down to **Environments** section
   - Click on **prod** environment

2. **Add Deployment Protection Rules**
   - Scroll to "Deployment protection rules"
   - Check the box: **"Required reviewers"**
   - Click **Add** to add reviewers/teams who can approve

3. **Select Approval Requirements**
   - Add yourself or your team as reviewers
   - Example: sushildeep (your username)
   - You can add multiple reviewers (they all need to approve OR at least 1)

4. **Prevent Admin Override**
   - Check the box: **"Prevent admins from bypassing these rules"**
   - This ensures even admins cannot skip approval for destruction

5. **Save Changes**
   - Changes are saved automatically

### Screenshot Guide

```
GitHub Repository
  ↓
Settings (top menu)
  ↓
Environments (left sidebar)
  ↓
Click "prod"
  ↓
"Deployment protection rules" section
  ↓
Check "Required reviewers" ✅
Check "Prevent admins from bypassing" ✅
  ↓
Save
```

---

## Recommended: Set Up Dev Environment Protection

### ⚠️ RECOMMENDED - Dev Protection for Destruction Safety

**Why?** While dev deployments are fast, destroying dev infrastructure should still require approval to prevent accidents.

### Step-by-Step Setup

1. **Go to GitHub Repository Settings**
   - Click on **Settings** tab in your repository
   - Scroll down to **Environments** section
   - Click on **dev** environment

2. **Add Deployment Protection Rules**
   - Scroll to "Deployment protection rules"
   - Check the box: **"Required reviewers"**
   - Click **Add** to add reviewers/teams who can approve

3. **Select Approval Requirements**
   - Add yourself or your team as reviewers
   - Example: sushildeep (your username)

4. **Prevent Admin Override**
   - Check the box: **"Prevent admins from bypassing these rules"**

5. **Save Changes**
   - Changes are saved automatically

### Important Notes

- **Dev DEPLOYMENTS are NOT protected** - they auto-approve (fast iteration)
- **Dev DESTRUCTION IS protected** - requires approval (prevent accidents)
- This allows fast dev iteration but safe dev cleanup

---

## Verification

### Check Prod Environment Rules

```bash
# After setting up protection rules, verify by:
1. Go to Settings → Environments → prod
2. See "Deployment protection rules" with checkmarks
3. See your reviewers listed
```

### Check Dev Environment Rules (Optional)

```bash
# To verify dev destruction protection:
1. Go to Settings → Environments → dev
2. If protection rules exist, see "Deployment protection rules"
3. This is optional but recommended
```

---

## How It Works in Practice

### Destroying Prod Infrastructure

**Workflow:**
```
User runs: destroy_infrastructure = true, infra_environment = prod
         ↓
Workflow starts destroy-infrastructure job
         ↓
Routes to 'prod' environment
         ↓
Checks protection rules on 'prod' ✅ (MUST exist)
         ↓
Waits for approval from required reviewers 🔒
         ↓
You see: "Waiting for review: prod needs approval"
         ↓
You approve in GitHub Actions
         ↓
Infrastructure is destroyed
```

### Destroying Dev Infrastructure

**Workflow:**
```
User runs: destroy_infrastructure = true, infra_environment = dev
         ↓
Workflow starts destroy-infrastructure job
         ↓
Routes to 'dev' environment
         ↓
Checks protection rules on 'dev' (if set up)
         ↓
If rules exist → waits for approval 🔒
If no rules → runs immediately ⚠️
         ↓
You see: "Waiting for review: dev needs approval" (if rules exist)
         ↓
You approve in GitHub Actions
         ↓
Infrastructure is destroyed
```

---

## Complete Approval Requirements Matrix

After setup:

| Operation | Environment | Approval Required |
|-----------|-------------|------------------|
| Build | Any | ❌ No |
| Deploy | Dev | ❌ No |
| Deploy | Prod | 🔒 Yes |
| Destroy | Dev | 🔒 Yes (recommended) |
| Destroy | Prod | 🔒 Yes (required) |

---

## Testing Destruction Approval

### Test 1: Destroy Dev (With Rules)

1. Go to **Actions** → **Complete CI/CD Orchestration**
2. Click **Run workflow**
3. Set:
   - `destroy_infrastructure: true`
   - `infra_environment: dev`
4. Click **Run workflow**
5. **Expected:** Workflow waits at destroy-infrastructure 🔒
6. Click "Review pending deployments"
7. Click "Approve and deploy"
8. **Result:** Dev infrastructure is destroyed ✅

### Test 2: Destroy Prod (Required)

1. Go to **Actions** → **Complete CI/CD Orchestration**
2. Click **Run workflow**
3. Set:
   - `destroy_infrastructure: true`
   - `infra_environment: prod`
4. Click **Run workflow**
5. **Expected:** Workflow waits at destroy-infrastructure 🔒
6. Click "Review pending deployments"
7. Click "Approve and deploy"
8. **Result:** Prod infrastructure is destroyed ✅

---

## Troubleshooting

### Approval Not Required for Destruction

**Problem:** Destroy workflow runs without waiting for approval

**Solution:**
1. Check if environment has protection rules enabled
2. Go to Settings → Environments → [dev/prod]
3. Verify "Required reviewers" is checked
4. If not, add reviewers

### Can't Approve Destruction

**Problem:** "Approve and deploy" button not visible

**Solution:**
1. Ensure you are in the required reviewers list
2. Go to Settings → Environments → [dev/prod]
3. Check who the required reviewers are
4. If not listed, ask someone who is listed to approve

### Protection Rules Not Showing

**Problem:** "Deployment protection rules" section not visible

**Solution:**
1. Go to Settings → Environments
2. Environment may need to be created first
3. You already have dev and prod, so they should show
4. Click on the environment to see rules section

---

## Summary

✅ **Protect Prod Destruction:**
1. Settings → Environments → prod
2. Check "Required reviewers"
3. Add reviewers
4. Check "Prevent admins from bypassing"

✅ **Recommended: Protect Dev Destruction:**
1. Settings → Environments → dev
2. Check "Required reviewers"
3. Add reviewers
4. Check "Prevent admins from bypassing"

✅ **Result:**
- Fast dev deployments (no approval)
- Safe dev destruction (requires approval)
- Safe prod deployments (requires approval)
- Safe prod destruction (requires approval)

Good luck! 🚀
