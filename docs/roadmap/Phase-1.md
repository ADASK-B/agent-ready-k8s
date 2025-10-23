# 🗺️ Roadmap - agent-ready-k8s

**Project Goal:** Build a scalable, AI-agent-friendly Kubernetes template stack with GitOps, Hot-Reload capabilities, and multi-tenant support.

---

## 📋 Phase 1: GitOps Transformation

**Goal:** Transform Phase 0's imperative Helm installs into declarative GitOps structure (Argo CD Applications).

**Status:** 🚧 Planned

### Block 1: Vendor Infrastructure Charts 🔲
- [ ] Vendor ingress-nginx Helm chart (v4.11.3)
  > Download ingress-nginx chart from official repo and store in helm-charts/infrastructure/ for self-contained, offline-ready deployments (Oracle/air-gapped compatibility)
- [ ] Vendor PostgreSQL Helm chart (v18.1.1)
  > Download PostgreSQL chart from Bitnami and store locally - required for backend database without external dependencies
- [ ] Vendor Redis Helm chart (v23.2.1)
  > Download Redis chart from Bitnami and store locally - required for Hot-Reload Pub/Sub and caching without external dependencies
- [ ] Verify all charts stored in helm-charts/infrastructure/
  > Confirm all 4 charts (ingress-nginx, postgresql, redis, podinfo) are present with Chart.yaml and values.yaml files
- [ ] Commit vendored charts
  > Git commit all vendored charts so Argo CD Applications can reference them from the repository

### Block 2: Create GitOps Folder Structure 🔲
- [ ] Create clusters/base/ directory structure
  > Create provider-agnostic cluster configuration folders (ingress-nginx, policies, storage) - base configs shared across all environments
- [ ] Create clusters/overlays/kind/ directory
  > Create local development overlay for kind-specific configurations (port mappings, local storage)
- [ ] Create apps/base/ directory
  > Create folder for Argo CD Application manifests - these define what gets deployed and how
- [ ] Create argocd/bootstrap/ directory
  > Create folder for root Application (App-of-Apps pattern) - used in Phase 2+ for automated deployments
- [ ] Create argocd/projects/ directory
  > Create folder for Argo CD AppProjects - used in Phase 2+ for multi-tenant isolation and RBAC
- [ ] Commit folder structure
  > Git commit the new folder structure to match README.md architecture

### Block 3: Create Argo CD Applications 🔲
- [ ] Create apps/base/ingress-nginx-app.yaml
  > Define Argo CD Application pointing to vendored ingress-nginx chart (path: helm-charts/infrastructure/ingress-nginx)
- [ ] Create apps/base/postgresql-app.yaml
  > Define Argo CD Application pointing to vendored PostgreSQL chart with same credentials as Phase 0 (demouser/demopass/demodb)
- [ ] Create apps/base/redis-app.yaml
  > Define Argo CD Application pointing to vendored Redis chart with same password as Phase 0 (redispass)
- [ ] Create apps/base/podinfo-app.yaml
  > Define Argo CD Application pointing to vendored podinfo chart with 2 replicas, Redis connection, demo.localhost ingress
- [ ] Commit Application manifests
  > Git commit all 4 Application YAML files - these are the declarative deployment instructions for GitOps
- [ ] Push all changes to GitHub
  > Push to GitHub so Argo CD can sync from the repository (CRITICAL: must be in Git before applying!)

### Block 4: GitOps Migration (Helm → Argo CD) 🔲
- [ ] Delete Helm release: ingress-nginx
  > Remove imperative Helm install from Phase 0 - Argo CD will recreate it declaratively
- [ ] Delete Helm release: postgresql
  > Remove imperative Helm install from Phase 0 - Argo CD will recreate it declaratively
- [ ] Delete Helm release: redis
  > Remove imperative Helm install from Phase 0 - Argo CD will recreate it declaratively
- [ ] Delete Helm release: podinfo
  > Remove imperative Helm install from Phase 0 - Argo CD will recreate it declaratively
- [ ] Apply Argo CD Application: ingress-nginx
  > Deploy ingress-nginx via Argo CD Application (kubectl apply -f apps/base/ingress-nginx-app.yaml)
- [ ] Apply Argo CD Application: postgresql
  > Deploy PostgreSQL via Argo CD Application (kubectl apply -f apps/base/postgresql-app.yaml)
- [ ] Apply Argo CD Application: redis
  > Deploy Redis via Argo CD Application (kubectl apply -f apps/base/redis-app.yaml)
- [ ] Apply Argo CD Application: podinfo
  > Deploy podinfo via Argo CD Application (kubectl apply -f apps/base/podinfo-app.yaml)
- [ ] Wait for all Applications to sync
  > Monitor Argo CD syncing all 4 Applications from Git (watch kubectl get applications -n argocd)
- [ ] Verify all Applications show Synced + Healthy status
  > Confirm all 4 Applications are green (Synced + Healthy) in Argo CD UI and CLI

### Block 5: Validate GitOps Workflow 🔲
- [ ] Test auto-sync (modify podinfo replicas in Git)
  > Change replicas 2→3 in apps/base/podinfo-app.yaml, commit, push - verify Argo CD auto-syncs and creates 3 pods (proves git push → cluster updates works)
- [ ] Test self-heal (manually delete a pod)
  > Manually delete a podinfo pod with kubectl - verify Argo CD recreates it automatically within 30s (proves cluster drift correction works)
- [ ] Test drift correction (manually scale deployment)
  > Manually scale podinfo to 5 replicas with kubectl - verify Argo CD corrects back to 2 replicas (proves Git is source of truth)
- [ ] Verify helm list -A returns empty
  > Confirm no Helm releases exist anymore (helm list -A shows nothing) - all infrastructure now managed by Argo CD
- [ ] Verify all 4 Applications synced in Argo CD
  > Check kubectl get applications -n argocd shows 4 apps, all Synced + Healthy
- [ ] Test podinfo HTTP endpoint (http://demo.localhost)
  > Curl http://demo.localhost and verify podinfo responds with JSON (proves services still working after migration)
- [ ] Test Argo CD UI (http://argocd.local)
  > Login to Argo CD UI and verify all 4 Applications are green (Synced + Healthy) with correct pod counts

### Phase 1 Completion Criteria
- [ ] All 4 services managed by Argo CD (0 Helm releases)
- [ ] Repository structure matches README.md
- [ ] GitOps workflow validated (auto-sync, self-heal)
- [ ] All Phase 0 services still running (zero downtime)
- [ ] Changes committed and pushed to GitHub
- [ ] Stack is Oracle/multi-cloud ready
  > Prerequisites for Oracle deployment:
  > - All charts vendored in repository (no external Helm repos needed)
  > - All Application manifests committed to Git
  > - Argo CD can sync from GitHub repository
  > - Stack works offline/air-gapped (no internet dependencies)
  > - Ready to deploy: Install Argo CD on Oracle cluster → Apply apps/base/ → Auto-deploy complete stack
