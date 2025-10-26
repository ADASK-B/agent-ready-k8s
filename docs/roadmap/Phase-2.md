# 🗺️ Roadmap - agent-ready-k8s

**Project Goal:** Build a scalable, AI-agent-friendly Kubernetes template stack with GitOps, Hot-Reload capabilities, and multi-tenant support.

---

## 📋 Phase 2: Backend API Foundation

**Goal:** Replace test apps (podinfo) with production Backend service including database migrations, API contracts, and config hot-reload foundation.

**Status:** 🔜 **NEXT** (Planned)

**Prerequisites:**
- ✅ Phase 0 Complete (Local kind cluster, PostgreSQL, Redis, Argo CD running)
- ✅ Phase 1 Complete (GitOps transformation, all services via Argo CD)

**End-State:**
- Backend API running with Organizations, Projects, Users endpoints
- Database migrations automated (Flyway/Alembic)
- Config hot-reload contracts defined (PostgreSQL SoT + Redis Pub/Sub stubs)
- Unit + Integration tests (pytest/Testcontainers)
- Backend deployed via Helm Chart through Argo CD
- Environment overlays (dev/staging/prod) functional

---

### Block 1: Cleanup Phase 0/1 Artifacts 🧹
**Goal:** Remove temporary test apps and prepare structure for production apps

- [ ] Delete apps/podinfo/ directory (unused Kustomize structure from Block 6)
  > Remove apps/podinfo/base/ and apps/podinfo/tenants/ - these were created to fix patchesStrategicMerge but never used (podinfo runs via Helm)
- [ ] Delete apps/base/podinfo-app.yaml (Argo CD Application)
  > Remove podinfo Argo CD Application - will be replaced by backend-app.yaml
- [ ] Delete helm-charts/infrastructure/podinfo/ (vendored chart)
  > Remove podinfo Helm chart - test app no longer needed
- [ ] Verify podinfo removed from cluster
  > kubectl get all -n tenant-demo should show no podinfo resources
- [ ] Commit cleanup
  > Git commit "chore(phase2): remove podinfo test app artifacts"

---

### Block 2: Create Backend Helm Chart Structure 📦
**Goal:** Build production-grade Helm chart for Backend service

- [ ] Create helm-charts/application/backend/ directory
  > mkdir -p helm-charts/application/backend/templates
- [ ] Create backend/Chart.yaml
  > Name: backend, version: 0.1.0, description: Multi-tenant SaaS Backend API
- [ ] Create backend/values.yaml (default values)
  > Default settings: replicaCount=2, image.repository=ghcr.io/adask-b/backend, resources, probes, service, ingress, autoscaling
- [ ] Create backend/values-dev.yaml
  > Dev overrides: replicaCount=1, resources.requests.memory=256Mi, debug=true, ingress.host=api-dev.localhost
- [ ] Create backend/values-staging.yaml
  > Staging overrides: replicaCount=2, HPA enabled (min=2, max=4), ingress.host=api-staging.localhost
- [ ] Create backend/values-prod.yaml
  > Prod overrides: replicaCount=3, PDB minAvailable=2, resources tuned, ingress.host=api.example.com
- [ ] Create backend/templates/deployment.yaml
  > Deployment with multi-arch support (AMD64/ARM64), health probes (liveness/readiness/startup), securityContext (runAsNonRoot), env vars from ConfigMap/Secret
- [ ] Create backend/templates/service.yaml
  > Service type ClusterIP, port 8000 (FastAPI/Flask default), targetPort http
- [ ] Create backend/templates/ingress.yaml
  > Ingress with TLS enabled, cert-manager annotation, nginx ingressClassName, host from values
- [ ] Create backend/templates/hpa.yaml (optional)
  > HorizontalPodAutoscaler (enabled via values.autoscaling.enabled), CPU target 80%
- [ ] Create backend/templates/pdb.yaml (optional)
  > PodDisruptionBudget (enabled via values.pdb.enabled), minAvailable=1 for HA
- [ ] Create backend/templates/configmap.yaml
  > ConfigMap with non-sensitive config: LOG_LEVEL, ENVIRONMENT, DATABASE_NAME, REDIS_HOST
- [ ] Create backend/templates/secret.yaml
  > Secret placeholder (later: ExternalSecret via ESO in Phase 6) with DATABASE_PASSWORD, REDIS_PASSWORD, JWT_SECRET
- [ ] Create backend/templates/serviceaccount.yaml
  > ServiceAccount for Workload Identity (future: Azure AD / GCP Workload Identity / AWS IRSA)
- [ ] Create backend/templates/networkpolicy.yaml
  > NetworkPolicy: allow ingress from nginx-ingress, allow egress to PostgreSQL (5432) + Redis (6379) + DNS (53)
- [ ] Validate Helm chart
  > helm lint helm-charts/application/backend/ - should pass with 0 errors
- [ ] Test Helm template rendering
  > helm template backend helm-charts/application/backend/ --values helm-charts/application/backend/values-dev.yaml - should generate valid YAML
- [ ] Commit Backend Helm chart
  > Git commit "feat(phase2): add Backend Helm chart with dev/staging/prod overlays"

---

### Block 3: Create Argo CD Application for Backend 🔄
**Goal:** Deploy Backend via GitOps with environment-specific overlays

- [ ] Create apps/base/backend-app.yaml (Argo CD Application)
  > Application pointing to helm-charts/application/backend with dev values, namespace: backend-dev, auto-sync enabled
- [ ] Create apps/overlays/dev/ directory
  > mkdir -p apps/overlays/dev
- [ ] Create apps/overlays/dev/kustomization.yaml
  > Kustomization referencing ../../base/backend-app.yaml with valuesFiles patch (values-dev.yaml)
- [ ] Create apps/overlays/staging/ directory
  > mkdir -p apps/overlays/staging
- [ ] Create apps/overlays/staging/kustomization.yaml
  > Kustomization referencing ../../base/backend-app.yaml with valuesFiles patch (values-staging.yaml)
- [ ] Create apps/overlays/prod/ directory (placeholder)
  > mkdir -p apps/overlays/prod (not deployed yet, Oracle Cloud in Phase 5)
- [ ] Apply Backend Argo CD Application (dev)
  > kubectl apply -k apps/overlays/dev/ - Backend should appear in Argo CD
- [ ] Wait for Backend Application to sync
  > kubectl get application backend -n argocd -w - should reach Synced status (may fail initially - no container image yet)
- [ ] Commit Argo CD Application manifests
  > Git commit "feat(phase2): add Backend Argo CD Application with dev/staging overlays"

---

### Block 4: Backend Source Code Foundation 💻
**Goal:** Create Backend application structure with FastAPI/Flask

- [ ] Create app/backend/ directory structure
  > mkdir -p app/backend/src/{api,models,services,auth,config} app/backend/db/migrations app/backend/tests/{unit,integration,e2e}
- [ ] Create app/backend/requirements.txt
  > Python dependencies: fastapi, uvicorn, psycopg2-binary, redis, sqlalchemy, pydantic, pytest, pytest-asyncio, httpx
- [ ] Create app/backend/Dockerfile (multi-stage)
  > Stage 1: python:3.12-slim as builder, install deps<br>Stage 2: python:3.12-slim as runtime, copy deps + code, USER nonroot, EXPOSE 8000, CMD uvicorn
- [ ] Create app/backend/src/main.py (FastAPI app entrypoint)
  > FastAPI app with health check endpoint GET /health, GET /ready
- [ ] Create app/backend/src/config/settings.py
  > Environment variables: DATABASE_URL, REDIS_URL, LOG_LEVEL, ENVIRONMENT
- [ ] Create app/backend/tests/unit/test_health.py
  > Unit test for health check endpoint (pytest)
- [ ] Create app/backend/tests/integration/test_database.py
  > Integration test with Testcontainers (PostgreSQL) - verify DB connection
- [ ] Build Backend Docker image
  > docker build -t ghcr.io/adask-b/backend:0.1.0-dev app/backend/
- [ ] Test Backend locally
  > docker run -p 8000:8000 ghcr.io/adask-b/backend:0.1.0-dev - curl http://localhost:8000/health should return {"status": "ok"}
- [ ] Push Backend image to GHCR
  > docker push ghcr.io/adask-b/backend:0.1.0-dev (requires GitHub Personal Access Token)
- [ ] Commit Backend source code
  > Git commit "feat(phase2): add Backend FastAPI foundation with health checks"

---

### Block 5: Database Migrations (Organizations, Projects, Users) 🗄️
**Goal:** Implement database schema with PostgreSQL RLS for multi-tenancy

- [ ] Create app/backend/db/migrations/V001__initial_schema.sql
  > Tables: organizations (id, name, slug, created_at), projects (id, org_id, name, slug, created_at), users (id, username, guest_id, created_at)
- [ ] Create app/backend/db/migrations/V002__enable_rls.sql
  > Enable Row-Level Security on organizations, projects, users tables - RLS policies for org_id isolation
- [ ] Create app/backend/db/migrations/V003__service_configs.sql
  > Tables: service_configs (id, service_name, config_key, config_value, version, updated_at), config_history (audit trail)
- [ ] Add Flyway/Alembic to requirements.txt
  > Add alembic for Python-based migrations (or use Flyway with Java)
- [ ] Create Kubernetes Job for migrations (helm-charts/application/backend/templates/migration-job.yaml)
  > Job runs before Deployment, executes alembic upgrade head, restartPolicy: Never
- [ ] Test migrations locally with Testcontainers
  > pytest app/backend/tests/integration/test_migrations.py - verify tables created, RLS enabled
- [ ] Commit database migrations
  > Git commit "feat(phase2): add PostgreSQL migrations with RLS for Organizations/Projects/Users"

---

### Block 6: API Endpoints (Organizations CRUD) 🌐
**Goal:** Implement Organizations API with PostgreSQL RLS enforcement

- [ ] Create app/backend/src/models/organization.py
  > SQLAlchemy model: Organization (id, name, slug, created_at, updated_at)
- [ ] Create app/backend/src/api/organizations.py
  > FastAPI router: POST /api/v1/orgs, GET /api/v1/orgs, GET /api/v1/orgs/{id}, PUT /api/v1/orgs/{id}, DELETE /api/v1/orgs/{id}
- [ ] Implement Organizations service layer (app/backend/src/services/org_service.py)
  > Business logic: create_org, get_org, list_orgs, update_org, delete_org - enforce RLS via SET LOCAL app.org_id
- [ ] Add Organizations endpoints to main.py
  > app.include_router(organizations.router, prefix="/api/v1")
- [ ] Create unit tests for Organizations service
  > app/backend/tests/unit/test_org_service.py - mock DB, test business logic
- [ ] Create integration tests for Organizations API
  > app/backend/tests/integration/test_orgs_api.py - Testcontainers + httpx, test CRUD endpoints
- [ ] Create E2E test: Create Org → List Orgs → Get Org → Delete Org
  > app/backend/tests/e2e/test_org_lifecycle.py - full lifecycle test with real DB
- [ ] Update Dockerfile to include new code
  > Rebuild Docker image with Organizations API
- [ ] Push new Backend image (v0.2.0)
  > docker build + docker push ghcr.io/adask-b/backend:0.2.0-dev
- [ ] Update apps/overlays/dev/backend-app.yaml with new image tag
  > Update image.tag: 0.2.0-dev in Helm values
- [ ] Wait for Argo CD to sync
  > Argo CD should auto-sync new image, Backend pods restart with Organizations API
- [ ] Test Organizations API on cluster
  > kubectl port-forward -n backend-dev svc/backend 8000:8000<br>curl -X POST http://localhost:8000/api/v1/orgs -d '{"name": "Demo Org", "slug": "demo-org"}'
- [ ] Commit Organizations API
  > Git commit "feat(phase2): implement Organizations CRUD API with PostgreSQL RLS"

---

### Block 7: API Endpoints (Projects CRUD) 📂
**Goal:** Implement Projects API with org_id isolation

- [ ] Create app/backend/src/models/project.py
  > SQLAlchemy model: Project (id, org_id, name, slug, created_at, updated_at)
- [ ] Create app/backend/src/api/projects.py
  > FastAPI router: POST /api/v1/orgs/{org_id}/projects, GET /api/v1/orgs/{org_id}/projects, GET /api/v1/projects/{id}, PUT /api/v1/projects/{id}, DELETE /api/v1/projects/{id}
- [ ] Implement Projects service layer
  > Business logic: create_project, get_project, list_projects_for_org, update_project, delete_project - enforce RLS
- [ ] Add Projects endpoints to main.py
  > app.include_router(projects.router, prefix="/api/v1")
- [ ] Create unit tests for Projects service
  > app/backend/tests/unit/test_project_service.py
- [ ] Create integration tests for Projects API
  > app/backend/tests/integration/test_projects_api.py - CRUD with org_id isolation
- [ ] Create E2E test: Create Org → Create Project → List Projects → Delete Project
  > app/backend/tests/e2e/test_project_lifecycle.py
- [ ] Update Backend image (v0.3.0)
  > docker build + docker push ghcr.io/adask-b/backend:0.3.0-dev
- [ ] Update Helm values with new image tag
  > Git commit with image.tag: 0.3.0-dev
- [ ] Wait for Argo CD sync
  > Argo CD auto-syncs, Backend restarts with Projects API
- [ ] Test Projects API on cluster
  > curl -X POST http://localhost:8000/api/v1/orgs/1/projects -d '{"name": "Demo Project", "slug": "demo-project"}'
- [ ] Commit Projects API
  > Git commit "feat(phase2): implement Projects CRUD API with org_id isolation"

---

### Block 8: Guest Authentication (JWT Tokens) 🔐
**Goal:** Implement guest sign-in with JWT tokens (no PII, no registration)

- [ ] Create app/backend/src/auth/jwt.py
  > JWT encoding/decoding: generate_guest_token(guest_id), verify_token(token) using python-jose or PyJWT
- [ ] Create app/backend/src/api/auth.py
  > FastAPI router: POST /api/v1/auth/guest - generates JWT with guest-NNNN identifier, short TTL (24h)
- [ ] Create app/backend/src/auth/middleware.py
  > FastAPI dependency: get_current_user() - verifies JWT from Authorization: Bearer header, extracts guest_id/org_id
- [ ] Add JWT_SECRET to ConfigMap/Secret
  > Update helm-charts/application/backend/templates/secret.yaml with JWT_SECRET placeholder
- [ ] Protect Organizations/Projects endpoints with authentication
  > Add depends=[get_current_user] to all CRUD endpoints
- [ ] Create unit tests for JWT auth
  > app/backend/tests/unit/test_jwt.py - test token generation, verification, expiry
- [ ] Create integration tests for guest auth
  > app/backend/tests/integration/test_auth_api.py - test guest sign-in flow, protected endpoints
- [ ] Update Backend image (v0.4.0)
  > docker build + docker push ghcr.io/adask-b/backend:0.4.0-dev
- [ ] Update Helm values with new image tag
  > Git commit with image.tag: 0.4.0-dev
- [ ] Wait for Argo CD sync
  > Argo CD auto-syncs, Backend restarts with JWT auth
- [ ] Test guest auth on cluster
  > curl -X POST http://localhost:8000/api/v1/auth/guest → get JWT token<br>curl http://localhost:8000/api/v1/orgs -H "Authorization: Bearer <token>"
- [ ] Commit Guest Authentication
  > Git commit "feat(phase2): implement guest authentication with JWT tokens"

---

### Block 9: Config Hot-Reload Contracts (PostgreSQL SoT + Redis Stub) 🔄
**Goal:** Define config hot-reload architecture without full implementation

- [ ] Create app/backend/src/models/service_config.py
  > SQLAlchemy model: ServiceConfig (id, service_name, config_key, config_value, version, updated_at)
- [ ] Create app/backend/src/api/configs.py
  > FastAPI router: GET /api/v1/configs, PUT /api/v1/configs/{key} - read/write config to PostgreSQL
- [ ] Implement config write with Redis PUBLISH
  > On PUT /api/v1/configs/{key}: 1) Write to PostgreSQL service_configs, 2) Redis PUBLISH config:updated {"key": ..., "version": ...}
- [ ] Create app/backend/src/config/loader.py (stub)
  > Warm-load config from PostgreSQL on startup (SELECT * FROM service_configs) - store in-memory cache
- [ ] Create app/backend/src/config/subscriber.py (stub)
  > Redis Pub/Sub subscriber (asyncio task) - SUBSCRIBE config:* - on message: fetch new config from PostgreSQL and reload cache
- [ ] Create app/backend/src/config/reconcile.py (stub)
  > Background reconcile loop (runs every 5 min) - poll PostgreSQL for config changes (fallback if Redis Pub/Sub fails)
- [ ] Add config endpoints to main.py
  > app.include_router(configs.router, prefix="/api/v1")
- [ ] Create unit tests for config service
  > app/backend/tests/unit/test_config_service.py - test config read/write/cache
- [ ] Create integration tests for config hot-reload
  > app/backend/tests/integration/test_config_hotreload.py - write config, verify Redis PUBLISH, verify cache reload
- [ ] Document config hot-reload architecture
  > Add docs/architecture/config-hot-reload-implementation.md - sequence diagram, contracts, SLOs (<100ms reload)
- [ ] Update Backend image (v0.5.0)
  > docker build + docker push ghcr.io/adask-b/backend:0.5.0-dev
- [ ] Update Helm values with new image tag
  > Git commit with image.tag: 0.5.0-dev
- [ ] Wait for Argo CD sync
  > Argo CD auto-syncs, Backend restarts with config hot-reload contracts
- [ ] Test config API on cluster
  > curl -X PUT http://localhost:8000/api/v1/configs/LOG_LEVEL -d '{"value": "DEBUG"}'<br>curl http://localhost:8000/api/v1/configs - verify LOG_LEVEL updated
- [ ] Commit Config Hot-Reload contracts
  > Git commit "feat(phase2): implement config hot-reload contracts (PostgreSQL SoT + Redis Pub/Sub stubs)"

---

### Block 10: OpenAPI Documentation & Error Catalog 📚
**Goal:** Generate OpenAPI spec and define error codes

- [ ] Update docs/api/openapi.yaml
  > OpenAPI 3.1 spec with all endpoints: /api/v1/orgs, /api/v1/projects, /api/v1/auth/guest, /api/v1/configs
- [ ] Add OpenAPI UI to Backend
  > FastAPI auto-generates Swagger UI at /docs - verify all endpoints documented
- [ ] Update docs/api/error-catalog.md
  > Document all error codes: ORG_NOT_FOUND (404), INVALID_ORG_SLUG (400), UNAUTHORIZED (401), FORBIDDEN (403)
- [ ] Create app/backend/src/api/errors.py
  > Custom exception handlers: OrganizationNotFound → 404, InvalidSlug → 400, Unauthorized → 401
- [ ] Add error handling to all endpoints
  > Wrap service calls with try/except, raise custom exceptions, FastAPI handles HTTP status codes
- [ ] Test error responses
  > curl http://localhost:8000/api/v1/orgs/999 - should return 404 with {"error": "ORG_NOT_FOUND", "message": "Organization 999 not found"}
- [ ] Commit OpenAPI spec and error handling
  > Git commit "docs(phase2): add OpenAPI spec and error catalog for Backend API"

---

### Block 11: Testing & Validation ✅
**Goal:** Ensure 60% unit test coverage and all integration tests passing

- [ ] Run unit tests
  > pytest app/backend/tests/unit/ --cov=app/backend/src --cov-report=html - verify >60% coverage
- [ ] Run integration tests
  > pytest app/backend/tests/integration/ - all tests passing with Testcontainers
- [ ] Run E2E tests
  > pytest app/backend/tests/e2e/ - full lifecycle tests (Create Org → Project → Auth → Config)
- [ ] Validate Helm chart linting
  > helm lint helm-charts/application/backend/ - 0 errors
- [ ] Validate Kubernetes manifests
  > kubectl kustomize apps/overlays/dev/ | kubeconform --strict - all manifests valid
- [ ] Smoke test on kind cluster
  > kubectl port-forward -n backend-dev svc/backend 8000:8000<br>Run smoke tests: health check, create org, create project, guest auth, config update
- [ ] Document test results
  > Update docs/roadmap/Phase-2.md with test coverage metrics and results
- [ ] Commit test validation results
  > Git commit "test(phase2): validate Backend API with 60%+ unit test coverage"

---

### Block 12: Phase 2 Completion & Documentation 📝
**Goal:** Finalize Phase 2 and prepare for Phase 3 (Frontend)

- [ ] Update README.md Phase status
  > Change Phase 2 status from "🔜 Next" to "✅ Complete"
- [ ] Update docs/roadmap/Phase-2.md status
  > Mark all blocks as complete, add completion date
- [ ] Create Phase 2 completion summary
  > Document: Backend API (Orgs, Projects, Auth), DB migrations, Helm chart, Environment overlays, Config hot-reload contracts, Test coverage >60%
- [ ] Clean up temporary files
  > Remove any .gitkeep files, unused directories from Phase 0/1
- [ ] Final commit and push
  > Git commit "chore(phase2): complete Backend API foundation - ready for Frontend (Phase 3)"<br>git push origin main
- [ ] Verify Argo CD Applications
  > kubectl get applications -n argocd - should show 4 apps: ingress-nginx, postgresql, redis, backend (all Synced + Healthy)
- [ ] Document known issues
  > Add DOCS_TODO.md entries for Phase 2+ improvements: ESO integration, NetworkPolicy enforcement, PodDisruptionBudget testing
- [ ] Announce Phase 2 completion
  > Ready for Phase 3: Frontend shell with React/Vue + tenant dashboards

---

## 📊 Phase 2 Success Criteria

| **Criterion** | **Target** | **Validation** |
|---------------|-----------|----------------|
| **Backend API Running** | ✅ Organizations + Projects CRUD functional | curl tests pass, Postman collection works |
| **Database Migrations** | ✅ PostgreSQL RLS enabled, 3 migrations applied | psql -c "\dt" shows organizations, projects, service_configs with RLS policies |
| **Guest Authentication** | ✅ JWT sign-in working, protected endpoints enforced | curl POST /auth/guest → token, curl /orgs with token → success |
| **Config Hot-Reload Contracts** | ✅ PostgreSQL SoT + Redis Pub/Sub stubs implemented | curl PUT /configs/LOG_LEVEL → Redis PUBLISH event logged |
| **Test Coverage** | ✅ >60% unit test coverage, all integration tests pass | pytest --cov shows >60%, pytest integration/ all green |
| **Helm Chart** | ✅ Backend Helm chart with dev/staging/prod values | helm lint passes, kubectl kustomize generates valid YAML |
| **Argo CD Deployment** | ✅ Backend deployed via GitOps (dev overlay) | kubectl get application backend -n argocd shows Synced + Healthy |
| **OpenAPI Documentation** | ✅ All endpoints documented in openapi.yaml | /docs shows Swagger UI with all endpoints |
| **Error Handling** | ✅ Error catalog documented, custom exceptions implemented | Error responses match docs/api/error-catalog.md |
| **No podinfo Artifacts** | ✅ podinfo removed from cluster and Git | kubectl get all -n tenant-demo returns empty, apps/podinfo/ deleted |

---

## 🔗 Dependencies & Prerequisites

**Phase 2 requires:**
- ✅ Phase 0: Local kind cluster operational
- ✅ Phase 1: GitOps (Argo CD) functional
- ✅ PostgreSQL running (from Phase 0/1)
- ✅ Redis running (from Phase 0/1)
- 🆕 Docker/Podman for building Backend images
- 🆕 GitHub Container Registry (GHCR) access for pushing images
- 🆕 Python 3.12+ for Backend development

**Phase 2 delivers foundation for:**
- 📅 Phase 3: Frontend shell (React/Vue dashboards)
- 📅 Phase 4: Real-time chat backend (WebSocket/SSE)
- 📅 Phase 5: Oracle Cloud deployment (production rollout)

---

## 📝 Notes & Lessons Learned

*(To be filled during Phase 2 execution)*

- **Kustomize vs Helm:** Environment overlays (dev/staging/prod) work better with Helm values files than Kustomize patches for complex Helm charts
- **Testcontainers:** Essential for integration testing with real PostgreSQL/Redis - no mocks for DB/cache
- **RLS Enforcement:** `SET LOCAL app.org_id` must be called on every request - consider SQLAlchemy event listener for automation
- **JWT Secrets:** Use different secrets per environment (dev/staging/prod) - rotate quarterly
- **Config Hot-Reload:** Redis Pub/Sub is primary, reconcile loop is fallback - test both paths
- **Image Tagging:** Use semantic versioning (0.1.0, 0.2.0) for Backend images, avoid :latest in production

---

## 🚀 Next Steps After Phase 2

1. **Phase 3:** Frontend shell with Organizations/Projects dashboards
2. **Backend Enhancements:** Add rate limiting, request ID tracing, structured logging
3. **Observability:** Add Prometheus metrics (/metrics endpoint), OpenTelemetry tracing
4. **Security:** Implement NetworkPolicy enforcement, PodSecurityPolicy/PSA restricted mode
5. **CI/CD:** GitHub Actions workflow for Backend (build → test → push → update Helm values)
