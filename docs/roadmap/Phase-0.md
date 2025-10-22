# 🗺️ Roadmap - agent-ready-k8s

**Project Goal:** Build a scalable, AI-agent-friendly Kubernetes template stack with GitOps, Hot-Reload capabilities, and multi-tenant support.

---

## 📋 Phase 0: Template Foundation (Local Development)

**Goal:** Create a complete local Kubernetes foundation with databases, GitOps, and reference application.

**Status:** ✅ Complete

### Block 1: Tool Installation & Validation ✅
- [x] Install Docker Engine CE
- [x] Install kind (Kubernetes IN Docker)
- [x] Install kubectl
- [x] Install Helm
- [x] Install Argo CD CLI
- [x] Install k9s (optional)
- [x] Install Task runner (optional)
- [x] Validate all tool installations with tests

### Block 2: Project Structure Creation ✅
- [x] Create GitOps folder structure (apps/, clusters/, infrastructure/, policies/)
- [x] Create app base manifests directory (apps/podinfo/base/)
- [x] Create tenant overlay directory (apps/podinfo/tenants/demo/)
- [x] Create cluster configurations (clusters/local/, clusters/production/)
- [x] Create infrastructure sources directory
- [x] Create infrastructure controllers directory
- [x] Create policy templates
- [x] Generate kind cluster configuration (kind-config.yaml)
- [x] Add .gitkeep files to maintain structure
- [x] Validate folder structure

### Block 3: Template Manifests Cloning ✅
- [x] Clone podinfo repository from GitHub
- [x] Extract Kubernetes manifests from podinfo
- [x] Copy base manifests to apps/podinfo/base/
- [x] Create kustomization.yaml for base
- [x] Create tenant overlay for demo namespace
- [x] Configure tenant-specific settings
- [x] Validate manifest structure
- [x] Clean up temporary files

### Block 4: Kubernetes Cluster Creation ✅
- [x] Create kind cluster with custom config
- [x] Configure port mappings (80:80, 443:443)
- [x] Wait for cluster to be ready
- [x] Verify node status
- [x] Verify system pods running
- [x] Validate kubectl connectivity
- [x] Check Kubernetes version

### Block 5: Ingress Controller Deployment ✅
- [x] Add ingress-nginx Helm repository
- [x] Create ingress-nginx namespace
- [x] Deploy ingress-nginx via Helm (NodePort for kind)
- [x] Wait for ingress controller pod to be ready
- [x] Verify ingress service created
- [x] Verify admission webhook configured
- [x] Test ingress controller readiness

### Block 6: Database Deployment (PostgreSQL + Redis) ✅
- [x] Create demo-platform namespace with labels
- [x] Add Bitnami Helm repository
- [x] Deploy PostgreSQL (Bitnami chart)
  - [x] Configure credentials (demouser/demopass/demodb)
  - [x] Set up persistent storage
  - [x] Wait for PostgreSQL pod to be ready
- [x] Deploy Redis (Bitnami chart)
  - [x] Configure password (redispass)
  - [x] Set up master configuration
  - [x] Wait for Redis pod to be ready
- [x] Test PostgreSQL connection (kubectl exec)
- [x] Test Redis connection (kubectl exec)
- [x] Validate both databases operational

### Block 7: Argo CD Deployment (GitOps) ✅
- [x] Create argocd namespace
- [x] Apply Argo CD manifests (v2.12.3)
- [x] Patch argocd-server service for Ingress
- [x] Create Ingress for argocd.local
- [x] Wait for Argo CD pods to be ready (all 7 pods)
- [x] Retrieve admin password from secret
- [x] Verify Argo CD server readiness
- [x] Validate Ingress configuration
- [x] Test admin password retrieval
- [x] Document access credentials

### Block 8: podinfo Demo Application Deployment ✅
- [x] **Vendor podinfo Helm chart** (self-contained, no external dependencies)
  - [x] Download podinfo chart v6.9.2: `helm pull podinfo/podinfo --version 6.9.2 --untar`
  - [x] Store in repository: `helm-charts/infrastructure/podinfo/`
  - [x] Verify chart files (Chart.yaml, values.yaml, templates/)
- [x] Create tenant-demo namespace with label
- [x] Deploy podinfo v6.9.2 **from LOCAL chart** (not external repo!)
  - [x] Use local chart: `helm install podinfo ./helm-charts/infrastructure/podinfo/`
  - [x] Configure 2 replicas
  - [x] Connect to Redis (redis-master.demo-platform:6379)
  - [x] Set Redis password via cache parameter
- [x] Create Ingress for demo.localhost
- [x] Wait for podinfo pods to be ready
- [x] Verify Helm release status
- [x] Validate pod count and readiness
- [x] Verify service ClusterIP
- [x] Validate Ingress configuration

**Result:** podinfo chart vendored at `helm-charts/infrastructure/podinfo/` (27 files, ~20KB)
**No external dependencies:** Works offline, air-gapped, full control

### Phase 0 Completion Tasks
- [x] Run complete Phase 0 setup (setup-phase0.sh)
- [x] Verify all 65 tests pass (100%)
- [x] Add domains to /etc/hosts (demo.localhost, argocd.local) - Automated in deploy scripts
- [x] Test podinfo HTTP endpoint - Automated in test scripts
- [x] Test Argo CD HTTP endpoint - Automated in test scripts
- [x] Login to Argo CD web UI - Manual browser test
- [x] Verify PostgreSQL and Redis connectivity
- [x] Document all credentials and access URLs
- [x] Create Phase 0 completion documentation

---

## 📦 Phase 0 Git Commit Strategy

### What Was Committed (And Why)

| Path/File | Committed? | Reason |
|-----------|------------|--------|
| `helm-charts/infrastructure/podinfo/` (27 files) | ✅ **YES** | **Required for Phase 1 GitOps:** Argo CD Applications will reference this vendored chart. Self-contained deployment (no external dependencies). Production-ready (works offline/air-gapped). |
| `setup-template/.../08-deploy-podinfo/deploy.sh` | ✅ **YES** | **Vendoring logic:** Script auto-downloads chart if missing, stores in repo. Makes Phase 0 repeatable and self-contained. |
| `apps/` (generated structure) | ❌ **NO** | **Runtime artifact:** Created by setup scripts. Will be populated in Phase 1 with Argo CD Application manifests. Not needed for Phase 0. |
| `clusters/` (generated structure) | ❌ **NO** | **Runtime artifact:** Created by setup scripts. Will be populated in Phase 1 with cluster-specific configs. Not needed for Phase 0. |
| `infrastructure/` (generated structure) | ❌ **NO** | **Runtime artifact:** Created by setup scripts. Will be populated in Phase 1 with infrastructure manifests. Not needed for Phase 0. |
| `policies/` (generated structure) | ❌ **NO** | **Runtime artifact:** Created by setup scripts. Will be populated in Phase 1 with policy templates. Not needed for Phase 0. |
| `kind-config.yaml` (generated) | ❌ **NO** | **Runtime config:** Cluster configuration for local development. Generated by scripts, not needed in repo. |
| Helm releases (postgresql, redis, podinfo) | ❌ **NO** | **Cluster state:** Deployed via `helm install` (imperative). Phase 1 will replace with Argo CD Applications (declarative GitOps). |

### Why Only Vendored Charts?

**Phase 0 = Imperative Foundation (temporary)**
- Helm releases run in cluster (not in Git)
- Scripts deploy via `helm install` commands
- Purpose: Local development and validation

**Phase 1 = GitOps Transformation (permanent)**
- Argo CD Applications in Git (`apps/`)
- Applications reference vendored charts: `path: helm-charts/infrastructure/podinfo`
- Argo CD syncs from Git → deploys to cluster
- **Vendored chart MUST be committed** for Argo CD to access it!

### Next Steps After This Commit

1. **Push to GitHub:** `git push origin main`
2. **Start Phase 1:** Create Argo CD Application manifests
3. **Phase 1 Commit:** Will include `apps/`, `clusters/`, `infrastructure/` (declarative GitOps)
4. **Cloud-Ready:** After Phase 1 commit, stack is deployable to Oracle/Azure/AWS (GitOps-ready)

**Commit Size:** 27 files, 1628 insertions, ~20KB vendored chart
**Validation:** Phase 0 setup completes in 3m 15s, all 65 tests pass, podinfo v6.9.2 running at http://demo.localhost
