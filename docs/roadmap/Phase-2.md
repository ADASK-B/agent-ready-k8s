# Roadmap - Phase 2: Backend API Foundation

**Project Goal:** Build a scalable, AI-agent-friendly Kubernetes template stack with GitOps, Hot-Reload capabilities, and multi-tenant support.

---

## Overview

**Goal:** Create a minimal Backend API that proves the architecture works: tenant isolation via PostgreSQL RLS, GitOps deployment via Argo CD, and guest authentication.

**Status:** 🔜 Next

**MVP Definition:** API works, tenants isolated, GitOps deployed. No frontend required.

---

## Phase 2a: Backend Skeleton

**Goal:** Get a minimal FastAPI application running in the cluster via GitOps.

**Status:** 🔜 Next

### Block 1: Project Structure
- [ ] Create `app/backend/` directory structure
- [ ] Create `app/backend/src/` with `__init__.py`
- [ ] Create `app/backend/src/main.py` (FastAPI app)
- [ ] Create `app/backend/requirements.txt`
- [ ] Create `app/backend/README.md`

### Block 2: API Skeleton
- [ ] Implement `/health` endpoint (liveness probe)
- [ ] Implement `/ready` endpoint (readiness probe)
- [ ] Implement `/` root endpoint (API info)
- [ ] Add basic error handling
- [ ] Add structured logging (JSON format)

### Block 3: Docker Build
- [ ] Create `app/backend/Dockerfile` (multi-stage, multi-arch)
- [ ] Use Python 3.12-slim base image
- [ ] Pin all dependency versions
- [ ] Test local Docker build
- [ ] Push to GHCR (manual or document process)

### Block 4: Helm Chart
- [ ] Create `helm-charts/application/backend/Chart.yaml`
- [ ] Create `helm-charts/application/backend/values.yaml`
- [ ] Create `helm-charts/application/backend/templates/deployment.yaml`
- [ ] Create `helm-charts/application/backend/templates/service.yaml`
- [ ] Create `helm-charts/application/backend/templates/ingress.yaml`
- [ ] Add health probe configurations
- [ ] Test `helm template` locally

### Block 5: Argo CD Integration
- [ ] Create `apps/base/backend-app.yaml` (Argo CD Application)
- [ ] Configure auto-sync and self-heal
- [ ] Push changes to Git
- [ ] Verify Argo CD syncs the application
- [ ] Test `/health` endpoint via Ingress (e.g., `api.localhost`)

### Phase 2a Completion Criteria
- [ ] Backend pod running in cluster (Synced + Healthy in Argo CD)
- [ ] `/health` returns 200 OK
- [ ] `/ready` returns 200 OK
- [ ] Accessible via Ingress
- [ ] Zero Helm releases (managed by Argo CD only)

---

## Phase 2b: Core Domain (Orgs & Projects)

**Goal:** Implement Organizations and Projects with PostgreSQL RLS for tenant isolation.

**Status:** 📅 Planned

### Block 1: Database Setup
- [ ] Create `app/backend/db/migrations/V001__initial_schema.sql`
  - `organizations` table (id, name, status, created_at)
  - `projects` table (id, org_id, name, created_at)
  - RLS policies on `org_id`
- [ ] Configure migrations (Alembic or raw SQL)
- [ ] Add DB connection to FastAPI (asyncpg)
- [ ] Update `/ready` to check DB connection

### Block 2: Organizations API
- [ ] Create `app/backend/src/api/organizations.py`
- [ ] Implement `POST /orgs` (create organization)
- [ ] Implement `GET /orgs` (list organizations)
- [ ] Implement `GET /orgs/{id}` (get organization)
- [ ] Implement `DELETE /orgs/{id}` (delete organization)
- [ ] Add Pydantic models for request/response

### Block 3: Projects API
- [ ] Create `app/backend/src/api/projects.py`
- [ ] Implement `POST /orgs/{org_id}/projects` (create project)
- [ ] Implement `GET /orgs/{org_id}/projects` (list projects)
- [ ] Implement `GET /orgs/{org_id}/projects/{id}` (get project)
- [ ] Implement `DELETE /orgs/{org_id}/projects/{id}` (delete project)
- [ ] Verify RLS isolates tenants

### Block 4: Testing
- [ ] Create `app/backend/tests/` directory
- [ ] Add unit tests for API endpoints
- [ ] Add integration tests with Testcontainers (PostgreSQL)
- [ ] Verify RLS prevents cross-tenant access
- [ ] Add pytest configuration

### Phase 2b Completion Criteria
- [ ] Can create/list/get/delete Organizations via API
- [ ] Can create/list/get/delete Projects via API
- [ ] RLS prevents cross-tenant data access
- [ ] All tests pass
- [ ] Migrations run on deploy

---

## Phase 2c: Guest Authentication

**Goal:** Implement guest sign-in with JWT tokens (no PII, no registration).

**Status:** 📅 Planned

### Block 1: JWT Infrastructure
- [ ] Create `app/backend/src/auth/jwt.py`
- [ ] Implement JWT generation (guest-NNNN identifier)
- [ ] Configure short TTL (e.g., 1 hour)
- [ ] Store JWT secret in Kubernetes Secret

### Block 2: Auth Endpoints
- [ ] Implement `POST /auth/guest` (generate guest token)
- [ ] Implement `GET /auth/me` (get current user info)

### Block 3: Auth Middleware
- [ ] Create auth middleware for protected routes
- [ ] Extract `org_id` from JWT claims
- [ ] Set PostgreSQL session variable for RLS
- [ ] Protect Orgs/Projects endpoints

### Block 4: Integration Testing
- [ ] Test full flow: guest login → create org → create project
- [ ] Verify RLS works with JWT-based org_id
- [ ] Test token expiration handling
- [ ] Test invalid token rejection

### Phase 2c Completion Criteria
- [ ] Guest can obtain JWT via `/auth/guest`
- [ ] JWT required for Orgs/Projects endpoints
- [ ] RLS uses org_id from JWT
- [ ] Tokens expire correctly
- [ ] All integration tests pass

---

## MVP Complete

After Phase 2c, the **MVP is complete**:

| Capability | Status |
|------------|--------|
| Backend API running | ✅ |
| Orgs/Projects CRUD | ✅ |
| PostgreSQL RLS isolation | ✅ |
| Guest JWT authentication | ✅ |
| GitOps deployment (Argo CD) | ✅ |
| Helm chart for backend | ✅ |

**What's NOT in MVP (moved to Phase 5+):**
- Config hot-reload (Redis Pub/Sub)
- Real-time chat (WebSocket/SSE)
- Observability (Prometheus/Loki/Tempo)
- DR/Backup (Velero)

---

## Cleanup Tasks (Before Phase 2a)

- [ ] Delete `apps/podinfo/` directory (unused Kustomize structure)
- [ ] Delete `apps/base/podinfo-app.yaml` (Argo CD Application)
- [ ] Delete `helm-charts/infrastructure/podinfo/` (vendored chart)
- [ ] Verify podinfo removed from cluster
- [ ] Commit cleanup

---

## File Structure After Phase 2

```
app/
└── backend/
    ├── src/
    │   ├── __init__.py
    │   ├── main.py
    │   ├── api/
    │   │   ├── organizations.py
    │   │   └── projects.py
    │   ├── auth/
    │   │   ├── jwt.py
    │   │   └── middleware.py
    │   └── db/
    │       └── connection.py
    ├── db/
    │   └── migrations/
    │       └── V001__initial_schema.sql
    ├── tests/
    │   ├── unit/
    │   └── integration/
    ├── Dockerfile
    ├── requirements.txt
    └── README.md

helm-charts/
└── application/
    └── backend/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── deployment.yaml
            ├── service.yaml
            └── ingress.yaml

apps/
└── base/
    └── backend-app.yaml
```

---

## Key Dependencies

```
# app/backend/requirements.txt
fastapi==0.109.0
uvicorn[standard]==0.27.0
pydantic==2.5.3
sqlalchemy==2.0.25
asyncpg==0.29.0
python-jose[cryptography]==3.3.0
pytest==7.4.4
httpx==0.26.0
testcontainers[postgresql]==3.7.1
```

---

## Next Steps (Optional)

| Phase | Scope |
|-------|-------|
| Phase 3 | Frontend dashboard (React) |
| Phase 4 | Oracle Cloud deployment (Terraform) |
| Phase 5+ | Chat, hot-reload, observability, DR |
