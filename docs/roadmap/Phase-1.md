# 🗺️ Roadmap - agent-ready-k8s

**Project Goal:** Build a scalable, AI-agent-friendly Kubernetes template stack with GitOps, Hot-Reload capabilities, and multi-tenant support.

---

## 📋 Phase 1: GitOps Migration & Backend Core

**Goal:** Transform Phase 0's direct Helm installs into declarative GitOps (Argo CD Applications) and build backend API MVP.

**Status:** 🚧 In Progress

**Phase 0 Foundation (Current State):**
- ✅ kind cluster running (agent-k8s-local)
- ✅ Argo CD installed and accessible (http://argocd.local)
- ✅ 4 services deployed via **direct Helm install** (NOT GitOps):
  - ingress-nginx (ingress-nginx namespace)
  - PostgreSQL (demo-platform namespace)
  - Redis (demo-platform namespace)
  - podinfo (tenant-demo namespace)
- ❌ Argo CD Applications: **0** (nothing managed via GitOps yet)

**Phase 1 Target:**
- ✅ All 4 services migrated to Argo CD Applications (GitOps-managed)
- ✅ Backend API deployed via Argo CD (FastAPI + PostgreSQL + Redis)
- ✅ Full GitOps workflow: git push → auto-sync → cluster updated

---

## Phase 1a: GitOps Foundation (Week 1)

**Goal:** Migrate all Phase 0 services from direct Helm to Argo CD Applications.

### Block 1: AppProjects Creation (RBAC Foundation) 🔲
- [ ] Create argocd/projects/ directory
- [ ] Create platform AppProject (ingress-nginx, cert-manager)
  - [ ] Define sourceRepos: '*'
  - [ ] Define destinations: ingress-nginx, cert-manager namespaces
  - [ ] Set clusterResourceWhitelist: all
- [ ] Create infrastructure AppProject (PostgreSQL, Redis)
  - [ ] Define destinations: demo-platform namespace
  - [ ] Set namespaceResourceWhitelist: all
- [ ] Create tenant-apps AppProject (podinfo, backend, frontend)
  - [ ] Define destinations: tenant-* namespaces
  - [ ] Set namespaceResourceWhitelist: all
- [ ] Apply all AppProjects: `kubectl apply -f argocd/projects/`
- [ ] Validate: `kubectl get appproject -n argocd` shows 3 projects

**Files Created:**
- `argocd/projects/platform.yaml`
- `argocd/projects/infrastructure.yaml`
- `argocd/projects/tenant-apps.yaml`

---

### Block 2: Migrate ingress-nginx to Argo CD 🔲
- [ ] Create clusters/base/ingress-nginx/ directory
- [ ] Create Argo CD Application manifest (argocd-app.yaml)
  - [ ] Set project: platform
  - [ ] Set source: Helm chart (kubernetes.github.io/ingress-nginx)
  - [ ] Set targetRevision: 4.11.3 (match current Phase 0 version)
  - [ ] Configure values: NodePort, hostPort, tolerations (kind-specific)
  - [ ] Set destination: ingress-nginx namespace
  - [ ] Enable syncPolicy: automated, prune, selfHeal
- [ ] Create values.yaml (Helm overrides)
- [ ] **Delete old Helm release:** `helm uninstall ingress-nginx -n ingress-nginx`
- [ ] Commit to git: `git add clusters/base/ingress-nginx/`
- [ ] Apply Application: `kubectl apply -f clusters/base/ingress-nginx/argocd-app.yaml`
- [ ] Wait for sync: `kubectl get application ingress-nginx -n argocd -w`
- [ ] Validate: Argo CD UI shows ingress-nginx (synced ✅, healthy ✅)
- [ ] Test: `curl http://argocd.local` still returns Argo CD UI
- [ ] Test: `curl http://demo.localhost` returns 404 (podinfo not migrated yet)

**Files Created:**
- `clusters/base/ingress-nginx/argocd-app.yaml`
- `clusters/base/ingress-nginx/values.yaml`

**Expected Downtime:** ~30 seconds (ingress controller restart)

---

### Block 3: Migrate PostgreSQL to Argo CD 🔲
- [ ] Create apps/base/ directory
- [ ] Create PostgreSQL Argo CD Application manifest (postgresql-app.yaml)
  - [ ] Set project: infrastructure
  - [ ] Set source: Helm chart (bitnami/postgresql)
  - [ ] Set targetRevision: 18.0.15 (match current Phase 0 version)
  - [ ] Configure values: auth (demouser/demopass/demodb), persistence (2Gi)
  - [ ] Set destination: demo-platform namespace
  - [ ] Enable syncPolicy: automated, prune, selfHeal
- [ ] **Backup credentials (optional):** `kubectl get secret postgresql -n demo-platform -o yaml > /tmp/postgresql-backup.yaml`
- [ ] **Delete old Helm release:** `helm uninstall postgresql -n demo-platform`
- [ ] **Delete PVC (fresh start):** `kubectl delete pvc data-postgresql-0 -n demo-platform`
- [ ] Commit to git: `git add apps/base/postgresql-app.yaml`
- [ ] Apply Application: `kubectl apply -f apps/base/postgresql-app.yaml`
- [ ] Wait for sync: `kubectl get application postgresql -n argocd -w`
- [ ] Validate: Argo CD UI shows postgresql (synced ✅, healthy ✅)
- [ ] Test: `kubectl exec -it postgresql-0 -n demo-platform -- psql -U demouser -d demodb -c "\dt"`

**Files Created:**
- `apps/base/postgresql-app.yaml`

**⚠️ Data Loss Warning:** PostgreSQL database will be recreated (empty). Acceptable for Phase 1 (no production data).

---

### Block 4: Migrate Redis to Argo CD 🔲
- [ ] Create Redis Argo CD Application manifest (redis-app.yaml)
  - [ ] Set project: infrastructure
  - [ ] Set source: Helm chart (bitnami/redis)
  - [ ] Set targetRevision: 23.1.3 (match current Phase 0 version)
  - [ ] Configure values: auth (redispass), master only, no persistence
  - [ ] Set destination: demo-platform namespace
  - [ ] Enable syncPolicy: automated, prune, selfHeal
- [ ] **Delete old Helm release:** `helm uninstall redis -n demo-platform`
- [ ] Commit to git: `git add apps/base/redis-app.yaml`
- [ ] Apply Application: `kubectl apply -f apps/base/redis-app.yaml`
- [ ] Wait for sync: `kubectl get application redis -n argocd -w`
- [ ] Validate: Argo CD UI shows redis (synced ✅, healthy ✅)
- [ ] Test: `kubectl exec -it redis-master-0 -n demo-platform -- redis-cli -a redispass ping` returns `PONG`

**Files Created:**
- `apps/base/redis-app.yaml`

**⚠️ Data Loss Warning:** Redis cache will be cleared. Acceptable for Phase 1.

---

### Block 5: Migrate podinfo to Argo CD 🔲
- [ ] Create podinfo Argo CD Application manifest (podinfo-app.yaml)
  - [ ] Set project: tenant-apps
  - [ ] Set source: Helm chart (stefanprodan.github.io/podinfo)
  - [ ] Set targetRevision: 6.9.2 (match current Phase 0 version)
  - [ ] Configure values: replicaCount (2), redis connection, ingress (demo.localhost)
  - [ ] Set destination: tenant-demo namespace
  - [ ] Enable syncPolicy: automated, prune, selfHeal
- [ ] **Delete old Helm release:** `helm uninstall podinfo -n tenant-demo`
- [ ] Commit to git: `git add apps/base/podinfo-app.yaml`
- [ ] Apply Application: `kubectl apply -f apps/base/podinfo-app.yaml`
- [ ] Wait for sync: `kubectl get application podinfo -n argocd -w`
- [ ] Validate: Argo CD UI shows podinfo (synced ✅, healthy ✅)
- [ ] Test: `curl http://demo.localhost` returns JSON (podinfo v6.9.2)
- [ ] Test: `curl http://demo.localhost/cache/test` validates Redis connection

**Files Created:**
- `apps/base/podinfo-app.yaml`

---

### Block 6: Create Root App (App-of-Apps Pattern) 🔲
- [ ] Create argocd/bootstrap/ directory
- [ ] Create Root Application manifest (root-app.yaml)
  - [ ] Set project: default
  - [ ] Set source: Git repository (github.com/ADASK-B/agent-ready-k8s)
  - [ ] Set path: argocd/apps/ (directory with all Application manifests)
  - [ ] Enable directory recurse
  - [ ] Set destination: argocd namespace
  - [ ] Enable syncPolicy: automated, prune, selfHeal
- [ ] Create argocd/apps/ directory
- [ ] Move all Application manifests to argocd/apps/:
  - [ ] `cp clusters/base/ingress-nginx/argocd-app.yaml argocd/apps/ingress-nginx.yaml`
  - [ ] `cp apps/base/postgresql-app.yaml argocd/apps/postgresql.yaml`
  - [ ] `cp apps/base/redis-app.yaml argocd/apps/redis.yaml`
  - [ ] `cp apps/base/podinfo-app.yaml argocd/apps/podinfo.yaml`
- [ ] Update Application manifests: remove namespace (managed by Root App)
- [ ] Commit to git: `git add argocd/bootstrap/ argocd/apps/`
- [ ] **Delete all Applications:** `kubectl delete application --all -n argocd`
- [ ] Apply Root App: `kubectl apply -f argocd/bootstrap/root-app.yaml`
- [ ] Wait for sync: `kubectl get application root -n argocd -w`
- [ ] Validate: Argo CD UI shows root app + 4 child apps
- [ ] Validate: All child apps show "Managed by: root"

**Files Created:**
- `argocd/bootstrap/root-app.yaml`
- `argocd/apps/ingress-nginx.yaml`
- `argocd/apps/postgresql.yaml`
- `argocd/apps/redis.yaml`
- `argocd/apps/podinfo.yaml`

**⚠️ Note:** This step restructures Application manifests. For Phase 1, **skip this block** and keep Applications standalone. Root App will be implemented in Phase 2.

---

### Block 7: Test GitOps Workflow 🔲
- [ ] **Test 1: Auto-Sync (git push → cluster update)**
  - [ ] Edit `apps/base/podinfo-app.yaml`: change replicaCount: 2 → 3
  - [ ] Commit: `git add apps/base/podinfo-app.yaml && git commit -m "test: scale podinfo to 3"`
  - [ ] Push: `git push origin main`
  - [ ] Wait 60s for Argo CD auto-sync
  - [ ] Validate: `kubectl get pods -n tenant-demo | grep podinfo` shows 3 pods
  - [ ] Revert: `git revert HEAD && git push origin main`
  - [ ] Validate: `kubectl get pods -n tenant-demo | grep podinfo` shows 2 pods again

- [ ] **Test 2: Self-Heal (manual kubectl drift)**
  - [ ] Manually scale: `kubectl scale deployment podinfo -n tenant-demo --replicas=5`
  - [ ] Verify drift: `kubectl get pods -n tenant-demo | grep podinfo` shows 5 pods
  - [ ] Wait 30-60s for Argo CD self-heal
  - [ ] Validate: `kubectl get pods -n tenant-demo | grep podinfo` auto-corrected to 2 pods

- [ ] **Test 3: Prune (remove resource from git)**
  - [ ] Add ConfigMap to `apps/base/podinfo-app.yaml` (temporary test resource)
  - [ ] Commit and push
  - [ ] Verify: `kubectl get cm test-config -n tenant-demo` exists
  - [ ] Remove ConfigMap from manifest
  - [ ] Commit and push
  - [ ] Validate: `kubectl get cm test-config -n tenant-demo` returns "not found" (pruned)

- [ ] **Test 4: Rollback (git revert)**
  - [ ] Edit `apps/base/redis-app.yaml`: change memory limit 256Mi → 128Mi
  - [ ] Commit and push
  - [ ] Verify: `kubectl get pod redis-master-0 -n demo-platform -o yaml | grep memory`
  - [ ] Rollback: `git revert HEAD && git push origin main`
  - [ ] Validate: Memory limit restored to 256Mi

- [ ] **Final Validation:**
  - [ ] `helm list -A` shows **0 releases** (all migrated to Argo CD)
  - [ ] `kubectl get applications -n argocd` shows **4 applications** (all synced ✅)
  - [ ] Argo CD UI: All apps green (synced ✅, healthy ✅)
  - [ ] `curl http://demo.localhost` works (podinfo accessible)
  - [ ] `curl http://argocd.local` works (Argo CD accessible)

**GitOps Workflow Validated:** ✅

---

### Block 8: Document Argo CD Bootstrap 🔲
- [ ] Download Argo CD installation manifest:
  - [ ] `curl -o argocd/bootstrap/argocd-install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.3/manifests/install.yaml`
- [ ] Add header comment to argocd-install.yaml:
  ```yaml
  # Argo CD Installation Manifest (v2.12.3)
  # This file documents the Argo CD bootstrap for disaster recovery.
  # Argo CD is NOT managed by itself (bootstrap paradox).
  #
  # Installation command:
  # kubectl create namespace argocd
  # kubectl apply -n argocd -f argocd/bootstrap/argocd-install.yaml
  ```
- [ ] Commit to git: `git add argocd/bootstrap/argocd-install.yaml`
- [ ] Update Boot-Routine.md: reference argocd-install.yaml for fresh cluster setup
- [ ] Create docs/runbooks/argocd-recovery.md (disaster recovery procedure)

**Files Created:**
- `argocd/bootstrap/argocd-install.yaml`
- `docs/runbooks/argocd-recovery.md`

---

### Phase 1a Completion Checklist
- [ ] All 4 services visible in Argo CD UI (ingress-nginx, postgresql, redis, podinfo)
- [ ] All Applications show: Synced ✅ Healthy ✅
- [ ] `helm list -A` returns empty (0 Helm releases)
- [ ] GitOps workflow validated (auto-sync, self-heal, prune, rollback)
- [ ] Git commit: `git tag v0.1.0-phase1a && git push origin v0.1.0-phase1a`
- [ ] Phase 1a documentation complete

**Deliverables:**
```
clusters/base/ingress-nginx/
  argocd-app.yaml
  values.yaml

apps/base/
  postgresql-app.yaml
  redis-app.yaml
  podinfo-app.yaml

argocd/
  bootstrap/
    argocd-install.yaml
  projects/
    platform.yaml
    infrastructure.yaml
    tenant-apps.yaml
```

---

## Phase 1b: Backend Development (Weeks 2-4)

**Goal:** Build FastAPI backend API (CRUD operations) deployed via Argo CD from day 1.

### Block 9: Backend Project Structure & Dockerfile 🔲
- [ ] Create app/backend/ directory
- [ ] Create Python package structure:
  - [ ] `app/backend/src/__init__.py`
  - [ ] `app/backend/src/main.py` (FastAPI app)
  - [ ] `app/backend/src/config.py` (12-factor settings)
  - [ ] `app/backend/src/health.py` (/health, /ready endpoints)
  - [ ] `app/backend/src/api/__init__.py`
  - [ ] `app/backend/src/api/v1/__init__.py`
  - [ ] `app/backend/src/api/v1/hello.py` (GET /v1/hello)
- [ ] Create tests/ directory:
  - [ ] `app/backend/tests/__init__.py`
  - [ ] `app/backend/tests/test_health.py`
  - [ ] `app/backend/tests/test_hello.py`
- [ ] Create requirements.txt:
  - [ ] fastapi
  - [ ] uvicorn[standard]
  - [ ] psycopg2-binary
  - [ ] redis
  - [ ] pydantic-settings
  - [ ] pytest
  - [ ] httpx (for tests)
- [ ] Create multi-stage Dockerfile:
  - [ ] Stage 1: builder (pip install dependencies)
  - [ ] Stage 2: runtime (copy from builder, expose 8000)
  - [ ] CMD: `uvicorn src.main:app --host 0.0.0.0 --port 8000`
- [ ] Create .dockerignore (exclude tests/, __pycache__, .env)
- [ ] Implement FastAPI Hello World:
  - [ ] `GET /` → `{"message": "Backend API", "version": "0.1.0"}`
  - [ ] `GET /health` → `{"status": "healthy"}`
  - [ ] `GET /ready` → `{"status": "ready", "db": "ok", "redis": "ok"}`
  - [ ] `GET /v1/hello` → `{"message": "Hello, World!"}`
- [ ] Test locally:
  - [ ] `docker build -t backend:latest app/backend/`
  - [ ] `docker run -p 8000:8000 backend:latest`
  - [ ] `curl http://localhost:8000/health` → `{"status": "healthy"}`
  - [ ] `curl http://localhost:8000/v1/hello` → `{"message": "Hello, World!"}`
- [ ] Run unit tests:
  - [ ] `cd app/backend && pytest tests/`
  - [ ] Validate: All tests pass ✅

**Files Created:**
- `app/backend/src/main.py`
- `app/backend/src/config.py`
- `app/backend/src/health.py`
- `app/backend/src/api/v1/hello.py`
- `app/backend/tests/test_health.py`
- `app/backend/tests/test_hello.py`
- `app/backend/requirements.txt`
- `app/backend/Dockerfile`
- `app/backend/.dockerignore`

---

### Block 10: Backend Helm Chart 🔲
- [ ] Create helm-charts/application/backend/ directory
- [ ] Create Chart.yaml:
  - [ ] name: backend
  - [ ] version: 0.1.0
  - [ ] appVersion: 0.1.0
  - [ ] description: Multi-Tenant SaaS Backend API
- [ ] Create values.yaml:
  - [ ] replicaCount: 2
  - [ ] image.repository: ghcr.io/adask-b/agent-ready-k8s/backend
  - [ ] image.tag: latest
  - [ ] service.type: ClusterIP, port: 8000
  - [ ] ingress.enabled: true, host: api.localhost
  - [ ] database.host: postgresql.demo-platform.svc.cluster.local
  - [ ] redis.host: redis-master.demo-platform.svc.cluster.local
  - [ ] resources.requests: cpu 100m, memory 128Mi
  - [ ] resources.limits: cpu 500m, memory 256Mi
- [ ] Create templates/:
  - [ ] `deployment.yaml` (Deployment with 2 replicas)
  - [ ] `service.yaml` (ClusterIP service on port 8000)
  - [ ] `ingress.yaml` (Ingress for api.localhost)
  - [ ] `configmap.yaml` (DB_HOST, REDIS_HOST env vars)
  - [ ] `secret.yaml` (DB_PASSWORD, REDIS_PASSWORD from PostgreSQL/Redis secrets)
- [ ] Validate Helm chart:
  - [ ] `helm lint helm-charts/application/backend/`
  - [ ] `helm template backend helm-charts/application/backend/`
  - [ ] Check: No hardcoded secrets in values.yaml
  - [ ] Check: All templates render valid YAML

**Files Created:**
- `helm-charts/application/backend/Chart.yaml`
- `helm-charts/application/backend/values.yaml`
- `helm-charts/application/backend/templates/deployment.yaml`
- `helm-charts/application/backend/templates/service.yaml`
- `helm-charts/application/backend/templates/ingress.yaml`
- `helm-charts/application/backend/templates/configmap.yaml`
- `helm-charts/application/backend/templates/secret.yaml`

---

### Block 11: CI Pipeline (Build, Test, Sign, Push) 🔲
- [ ] Create .github/workflows/backend-ci.yml
- [ ] Configure workflow triggers:
  - [ ] `on.push.branches: [main]`
  - [ ] `on.push.paths: ['app/backend/**', '.github/workflows/backend-ci.yml']`
  - [ ] `on.pull_request.branches: [main]`
- [ ] Add jobs:
  - [ ] **test**: Run pytest (unit tests)
  - [ ] **build-and-push**:
    - [ ] Checkout code
    - [ ] Set up Docker Buildx
    - [ ] Log in to GHCR (ghcr.io)
    - [ ] Extract metadata (tags, labels)
    - [ ] Build and push Docker image
    - [ ] Install Cosign
    - [ ] Sign image with Cosign (keyless, OIDC)
- [ ] Configure permissions:
  - [ ] contents: read
  - [ ] packages: write
  - [ ] id-token: write (for Cosign)
- [ ] Test CI pipeline:
  - [ ] Commit: `git add .github/workflows/backend-ci.yml`
  - [ ] Push: `git push origin main`
  - [ ] Verify: GitHub Actions workflow runs successfully
  - [ ] Verify: Image pushed to `ghcr.io/adask-b/agent-ready-k8s/backend:main-<sha>`
  - [ ] Verify: Cosign signature exists (check workflow logs)

**Files Created:**
- `.github/workflows/backend-ci.yml`

**Validation:**
- [ ] GitHub Actions workflow completes ✅
- [ ] Docker image available at GHCR: `ghcr.io/adask-b/agent-ready-k8s/backend:main-<sha>`
- [ ] Cosign signature verified: `cosign verify ...`

---

### Block 12: Deploy Backend via Argo CD 🔲
- [ ] Create backend Argo CD Application manifest (backend-app.yaml)
  - [ ] Set project: tenant-apps
  - [ ] Set source: Git repo (github.com/ADASK-B/agent-ready-k8s)
  - [ ] Set path: helm-charts/application/backend
  - [ ] Set helm.releaseName: backend
  - [ ] Override values:
    - [ ] image.repository: ghcr.io/adask-b/agent-ready-k8s/backend
    - [ ] image.tag: main-<sha> (from CI)
    - [ ] ingress.host: api.localhost
    - [ ] database.host: postgresql.demo-platform.svc.cluster.local
    - [ ] redis.host: redis-master.demo-platform.svc.cluster.local
  - [ ] Set destination: tenant-demo namespace
  - [ ] Enable syncPolicy: automated, prune, selfHeal
- [ ] Commit to git: `git add apps/base/backend-app.yaml`
- [ ] Push: `git push origin main`
- [ ] Apply Application: `kubectl apply -f apps/base/backend-app.yaml`
- [ ] Wait for sync: `kubectl get application backend -n argocd -w`
- [ ] Validate: Argo CD UI shows backend (synced ✅, healthy ✅)
- [ ] Test endpoints:
  - [ ] `curl http://api.localhost/health` → `{"status": "healthy"}`
  - [ ] `curl http://api.localhost/ready` → `{"status": "ready", "db": "ok", "redis": "ok"}`
  - [ ] `curl http://api.localhost/v1/hello` → `{"message": "Hello, World!"}`
- [ ] Check logs: `kubectl logs -n tenant-demo -l app=backend --tail=50`
- [ ] Verify 2 replicas: `kubectl get pods -n tenant-demo | grep backend`

**Files Created:**
- `apps/base/backend-app.yaml`

**Validation:**
- [ ] Backend deployed via Argo CD ✅
- [ ] All HTTP endpoints respond correctly ✅
- [ ] Database connection successful ✅
- [ ] Redis connection successful ✅

---

### Block 13: Database Models & Alembic Migrations 🔲
- [ ] Install SQLAlchemy and Alembic:
  - [ ] Add to requirements.txt: `sqlalchemy`, `alembic`
- [ ] Create database module:
  - [ ] `app/backend/src/database/__init__.py`
  - [ ] `app/backend/src/database/base.py` (SQLAlchemy Base, engine, session)
  - [ ] `app/backend/src/database/models.py` (Organization, Project, User models)
- [ ] Initialize Alembic:
  - [ ] `cd app/backend && alembic init alembic`
  - [ ] Edit `alembic.ini`: set `sqlalchemy.url` (read from env var)
  - [ ] Edit `alembic/env.py`: import models, configure Base.metadata
- [ ] Create initial migration:
  - [ ] `alembic revision --autogenerate -m "create organizations, projects, users tables"`
  - [ ] Review migration file (alembic/versions/xxxx_create_tables.py)
  - [ ] Validate: CREATE TABLE statements for orgs, projects, users
- [ ] Test migration locally:
  - [ ] Start PostgreSQL: `docker run -e POSTGRES_PASSWORD=demopass -p 5432:5432 postgres:16`
  - [ ] Run migration: `alembic upgrade head`
  - [ ] Verify: `psql -h localhost -U postgres -c "\dt"` shows tables
- [ ] Add init container to Deployment:
  - [ ] Edit `helm-charts/application/backend/templates/deployment.yaml`
  - [ ] Add initContainers: run `alembic upgrade head` before app starts
- [ ] Rebuild Docker image (include Alembic files)
- [ ] Redeploy via Argo CD:
  - [ ] Update image.tag in backend-app.yaml
  - [ ] Commit and push
  - [ ] Verify: Argo CD syncs, init container runs migration
- [ ] Validate migration in cluster:
  - [ ] `kubectl exec -it postgresql-0 -n demo-platform -- psql -U demouser -d demodb -c "\dt"`
  - [ ] Verify: Tables exist (organizations, projects, users)

**Files Created:**
- `app/backend/src/database/base.py`
- `app/backend/src/database/models.py`
- `app/backend/alembic.ini`
- `app/backend/alembic/env.py`
- `app/backend/alembic/versions/xxxx_create_tables.py`

**Validation:**
- [ ] Alembic migration runs successfully ✅
- [ ] Database tables created in PostgreSQL ✅
- [ ] Init container completes before app starts ✅

---

### Block 14: Organization & Project CRUD APIs 🔲
- [ ] Create API endpoints:
  - [ ] `app/backend/src/api/v1/organizations.py`
    - [ ] POST /v1/organizations (create org)
    - [ ] GET /v1/organizations (list orgs)
    - [ ] GET /v1/organizations/{org_id} (get org)
    - [ ] PUT /v1/organizations/{org_id} (update org)
    - [ ] DELETE /v1/organizations/{org_id} (delete org)
  - [ ] `app/backend/src/api/v1/projects.py`
    - [ ] POST /v1/organizations/{org_id}/projects (create project)
    - [ ] GET /v1/organizations/{org_id}/projects (list projects)
    - [ ] GET /v1/projects/{project_id} (get project)
    - [ ] PUT /v1/projects/{project_id} (update project)
    - [ ] DELETE /v1/projects/{project_id} (delete project)
- [ ] Create Pydantic schemas:
  - [ ] `app/backend/src/schemas/organization.py` (OrganizationCreate, OrganizationResponse)
  - [ ] `app/backend/src/schemas/project.py` (ProjectCreate, ProjectResponse)
- [ ] Create CRUD services:
  - [ ] `app/backend/src/services/organization.py` (create, read, update, delete logic)
  - [ ] `app/backend/src/services/project.py` (create, read, update, delete logic)
- [ ] Register routers in main.py:
  - [ ] `app.include_router(organizations.router, prefix="/v1", tags=["organizations"])`
  - [ ] `app.include_router(projects.router, prefix="/v1", tags=["projects"])`
- [ ] Test CRUD operations:
  - [ ] `curl -X POST http://api.localhost/v1/organizations -d '{"name": "Acme Corp"}'`
  - [ ] `curl http://api.localhost/v1/organizations` → list of orgs
  - [ ] `curl -X POST http://api.localhost/v1/organizations/1/projects -d '{"name": "Project Alpha"}'`
  - [ ] `curl http://api.localhost/v1/organizations/1/projects` → list of projects
- [ ] Write integration tests:
  - [ ] `app/backend/tests/test_organizations.py`
  - [ ] `app/backend/tests/test_projects.py`
  - [ ] Use pytest fixtures for test database
  - [ ] Validate: All tests pass ✅

**Files Created:**
- `app/backend/src/api/v1/organizations.py`
- `app/backend/src/api/v1/projects.py`
- `app/backend/src/schemas/organization.py`
- `app/backend/src/schemas/project.py`
- `app/backend/src/services/organization.py`
- `app/backend/src/services/project.py`
- `app/backend/tests/test_organizations.py`
- `app/backend/tests/test_projects.py`

**Validation:**
- [ ] All CRUD endpoints functional ✅
- [ ] Data persisted to PostgreSQL ✅
- [ ] Integration tests pass (70%+ coverage) ✅

---

### Block 15: User Authentication (Guest Sign-In) 🔲
- [ ] Create authentication module:
  - [ ] `app/backend/src/auth/__init__.py`
  - [ ] `app/backend/src/auth/jwt.py` (JWT token generation, validation)
  - [ ] `app/backend/src/auth/dependencies.py` (get_current_user dependency)
- [ ] Create user API endpoints:
  - [ ] `app/backend/src/api/v1/auth.py`
    - [ ] POST /v1/auth/guest-signin (create guest user, return JWT)
    - [ ] GET /v1/auth/me (get current user, requires Bearer token)
- [ ] Implement JWT logic:
  - [ ] Generate JWT with user_id, org_id, exp (1 hour)
  - [ ] Use HS256 algorithm (secret from env var)
  - [ ] Add `get_current_user` dependency (validate JWT, fetch user from DB)
- [ ] Protect CRUD endpoints:
  - [ ] Add `current_user = Depends(get_current_user)` to all CRUD endpoints
  - [ ] Return 401 if no valid token
- [ ] Test authentication:
  - [ ] `curl -X POST http://api.localhost/v1/auth/guest-signin -d '{"username": "guest123"}'`
  - [ ] Extract token from response
  - [ ] `curl -H "Authorization: Bearer <token>" http://api.localhost/v1/auth/me`
  - [ ] Verify: Returns user info ✅
  - [ ] `curl -H "Authorization: Bearer <token>" http://api.localhost/v1/organizations`
  - [ ] Verify: Returns orgs (authenticated) ✅
- [ ] Write authentication tests:
  - [ ] `app/backend/tests/test_auth.py`
  - [ ] Test: guest-signin creates user ✅
  - [ ] Test: JWT token validates correctly ✅
  - [ ] Test: Invalid token returns 401 ✅
  - [ ] Test: Protected endpoints require auth ✅

**Files Created:**
- `app/backend/src/auth/jwt.py`
- `app/backend/src/auth/dependencies.py`
- `app/backend/src/api/v1/auth.py`
- `app/backend/tests/test_auth.py`

**Validation:**
- [ ] Guest sign-in working ✅
- [ ] JWT authentication functional ✅
- [ ] Protected endpoints secured ✅
- [ ] Auth tests pass ✅

---

### Block 16: Integration Tests & Coverage 🔲
- [ ] Set up pytest-cov:
  - [ ] Add to requirements.txt: `pytest-cov`, `pytest-asyncio`, `httpx`
- [ ] Create test fixtures:
  - [ ] `app/backend/tests/conftest.py`
    - [ ] Fixture: test database (SQLite in-memory or testcontainers PostgreSQL)
    - [ ] Fixture: test Redis (fakeredis or testcontainers Redis)
    - [ ] Fixture: FastAPI TestClient
    - [ ] Fixture: authenticated user (create guest, return token)
- [ ] Write integration tests:
  - [ ] Test: Full E2E flow (create org → create project → create user → assign user)
  - [ ] Test: CRUD operations with authentication
  - [ ] Test: Database transactions (rollback on error)
  - [ ] Test: Redis caching (if implemented)
- [ ] Run tests with coverage:
  - [ ] `pytest --cov=src --cov-report=term-missing --cov-report=html`
  - [ ] Target: 70%+ coverage
  - [ ] Review: Coverage report shows all modules covered
- [ ] Add coverage enforcement to CI:
  - [ ] Edit `.github/workflows/backend-ci.yml`
  - [ ] Add step: `pytest --cov=src --cov-fail-under=70`
  - [ ] Commit and push
  - [ ] Verify: CI fails if coverage <70% ✅

**Files Created:**
- `app/backend/tests/conftest.py`
- `app/backend/tests/test_integration.py`

**Validation:**
- [ ] Integration tests pass ✅
- [ ] Coverage ≥70% ✅
- [ ] CI enforces coverage gate ✅

---

### Phase 1b Completion Checklist
- [ ] Backend API deployed via Argo CD (http://api.localhost)
- [ ] Database migrations automated (Alembic init container)
- [ ] CRUD APIs functional (Organizations, Projects)
- [ ] Authentication working (guest sign-in, JWT)
- [ ] Integration tests pass (70%+ coverage)
- [ ] CI pipeline builds, tests, signs, pushes image to GHCR
- [ ] All endpoints documented in OpenAPI (http://api.localhost/docs)
- [ ] Git commit: `git tag v0.2.0-phase1b && git push origin v0.2.0-phase1b`
- [ ] Phase 1b documentation complete

**Deliverables:**
```
app/backend/
  src/
    main.py
    config.py
    health.py
    database/
    api/v1/
    auth/
    schemas/
    services/
  tests/
  Dockerfile
  requirements.txt
  alembic/

helm-charts/application/backend/
  Chart.yaml
  values.yaml
  templates/

apps/base/
  backend-app.yaml

.github/workflows/
  backend-ci.yml
```

---

## Phase 1 Final Success Criteria

**Phase 1a (GitOps Foundation):**
- [x] All 4 Phase 0 services migrated to Argo CD ✅
- [x] Argo CD UI shows 4+ applications (all synced, healthy) ✅
- [x] `helm list -A` returns empty (0 Helm releases) ✅
- [x] GitOps workflow validated (auto-sync, self-heal, prune, rollback) ✅

**Phase 1b (Backend Development):**
- [x] Backend API accessible (http://api.localhost/health) ✅
- [x] Database models + migrations automated ✅
- [x] CRUD APIs functional (Orgs, Projects) ✅
- [x] Authentication implemented (JWT, guest sign-in) ✅
- [x] CI pipeline functional (build, test, sign, push) ✅
- [x] Integration tests pass (70%+ coverage) ✅
- [x] Backend deployed via Argo CD (GitOps from day 1) ✅

**Next Phase Ready:**
- [ ] Phase 2: Frontend (React, WebSocket chat)
- [ ] Phase 3: Production hardening (TLS, RBAC, policies, observability)
- [ ] Phase 4: Oracle Cloud deployment (Terraform, kubeadm)
