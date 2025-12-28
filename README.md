# Enterprise Multi-Tenant SaaS Platform on Kubernetes

> **Production-grade, provider-portable Kubernetes platform** for multi-tenant SaaS with GitOps, config hot-reload, and zero-downtime deployments.

---

## 📊 Current State (What Actually Exists)

> **Important:** This section shows what is currently implemented. The "Repository Structure" section below shows the **target architecture (roadmap)**.

| Component | Status | Description |
|-----------|--------|-------------|
| **kind Cluster** | ✅ Implemented | Local Kubernetes cluster configuration |
| **Argo CD** | ✅ Implemented | GitOps deployment (v2.12.3) |
| **PostgreSQL** | ✅ Implemented | Bitnami Helm chart (vendored) |
| **Redis** | ✅ Implemented | Bitnami Helm chart (vendored) |
| **NGINX Ingress** | ✅ Implemented | Vendored Helm chart |
| **podinfo Demo** | ✅ Implemented | Test application (to be removed in Phase 2a) |
| **Documentation** | ✅ Extensive | Architecture, ADRs, Roadmaps (~32 files) |
| **Backend API** | ❌ Not started | Planned for Phase 2 (2a/2b/2c) |
| **Frontend** | ❌ Not started | Planned for Phase 3 (Optional) |
| **Terraform IaC** | ❌ Not started | Planned for Phase 4 (Oracle Cloud) |
| **Observability** | ❌ Not started | Planned for Phase 5+ |
| **Policies** | ❌ Not started | Planned for Phase 5+ |

**See also:** [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for known problems and project analysis.

---

## 🎯 What is this?

A **complete enterprise reference implementation** for building **multi-tenant SaaS platforms** on Kubernetes with:

- **Organizations → Projects → Chat** hierarchy (tenant isolation via PostgreSQL RLS + Kubernetes namespaces)
- **Per-user ephemeral chat** (canned actions only, ≤3 active/user/project, **no PII**, WebSocket/SSE)
- **Config hot-reload** (PostgreSQL SoT + Redis Pub/Sub, <100ms + reconcile loop fallback)
- **GitOps-native** (Argo CD app-of-apps, Helm, Kustomize, **zero manual kubectl to production**)
- **Provider-portable** (identical app manifests on **kind**, **Oracle Cloud Free Tier**, **AKS/EKS/GKE**)
- **Security by default** (PSA restricted, Cosign-signed images, default-deny NetworkPolicies, RLS)

**Goal:** Deploy **once**, run **anywhere** – from local development (kind) to production (Oracle Cloud, AKS, EKS, GKE, on-prem kubeadm) using a **single Git repository** with **provider-specific overlays** and **environment-specific values**.

---

## 📐 Repository Structure (Target State / Roadmap)

> **⚠️ This is the TARGET architecture.** Many directories shown below do not exist yet. See "Current State" section above for what is actually implemented.
>
> **Key Concept:** `clusters/` = **Provider** overlays (AKS/EKS/GKE/Oracle/on-prem), `apps/` = **Environment** overlays (dev/staging/prod), `helm-charts/` = Application definitions.

```
.
├─ README.md
├─ LICENSE
├─ SECURITY.md                                # Threat model, secrets rotation, break-glass, SBOM/signing
├─ CODEOWNERS                                 # Code ownership (platform/security/app teams)
├─ .gitignore
├─ .pre-commit-config.yaml                    # Pre-commit hooks (YAML lint, Terraform fmt)
├─ renovate.json                              # Renovate auto-updates (Helm charts, Docker images, GH Actions)
├─ Makefile                                   # make build/test/push/deploy/lint
│
├─ .github/workflows/
│  ├─ ci.yml                                  # Build → Test (unit/integration) → SBOM (syft) → Sign (Cosign) → Push (GHCR/Harbor)
│  ├─ cd-validate.yml                         # Helm lint, kubeconform, Kyverno policy checks, conformance tests
│  ├─ enforce-image-digests.yml               # Block :latest, enforce SHA256 digests in all manifests
│  └─ diagram-check.yml                       # Mermaid syntax validation (keep diagrams in sync)
│
├─ docs/
│  ├─ architecture/
│  │  ├─ goals-and-scope.md                   # 📋 **START HERE**: Project charter, MVP scope, E2E flows, RACI
│  │  ├─ ARCHITECTURE.md                      # 🏛️ Enterprise design decisions, golden rules, provider mapping, SLOs
│  │  ├─ deployment-model.md                  # GitOps (Argo CD app-of-apps), Helm vs Kustomize, sync waves, health checks
│  │  ├─ observability-strategy.md            # Metrics/Logs/Traces catalog, dashboards, SLOs, alerting
│  │  ├─ testing-strategy.md                  # Test pyramid (60% unit, 30% integration, 10% E2E), coverage gates
│  │  └─ diagrams/                            # Mermaid diagrams (git-diffable, CI-validated)
│  │     ├─ README.md                         # How to maintain/render diagrams
│  │     ├─ system-context.mmd                # C4 Level 1: System context (users, external systems)
│  │     ├─ container-diagram.mmd             # C4 Level 2: Containers/components (NGINX, Backend, DB, Redis)
│  │     ├─ deployment-view.mmd               # CI→CD→K8s deployment flow (Git → Argo CD → Sync)
│  │     ├─ data-flow.mmd                     # E2E: Create Org → Project → Open Chat → Canned Action
│  │     ├─ config-hot-reload.mmd             # PostgreSQL SoT + Redis Pub/Sub + reconcile loop sequence
│  │     └─ observability-stack.mmd           # Prometheus/Loki/Tempo/Grafana (+ Mimir upgrade path)
│  │
│  ├─ adr/                                    # Architecture Decision Records (ADRs)
│  │  ├─ ADR-0001-config-sot-sql.md           # Why PostgreSQL (not etcd/ConfigMaps) for config SoT
│  │  ├─ ADR-0002-hot-reload-redis.md         # Why Redis Pub/Sub (not polling/etcd watches) for hot-reload
│  │  ├─ ADR-0003-etcd-scope.md               # Why etcd ONLY for K8s control plane (app-etcd optional Phase 5+)
│  │  ├─ ADR-0004-guest-auth.md               # Why guest sign-in (no PII, no registration, GDPR-friendly)
│  │  ├─ ADR-0005-canned-chat.md              # Why canned actions only (no free text, no message storage)
│  │  └─ ADR-0006-oracle-cloud-strategy.md    # Why Oracle Cloud Free Tier as production MVP (Phase 4)
│  │
│  ├─ legal/                                  # Legal & compliance documents
│  │  ├─ NOTICE.md                            # Third-party notices, attributions
│  │  └─ LICENSE-3RD-PARTY.md                 # Third-party licenses (dependencies)
│  │
│  ├─ api/
│  │  ├─ openapi.yaml                         # OpenAPI 3.1 spec (single source of truth for all endpoints)
│  │  ├─ conventions.md                       # REST API: versioning (/v1), auth (Bearer JWT), idempotency, pagination, rate limits
│  │  └─ error-catalog.md                     # Domain error codes ↔ HTTP status mapping (e.g., ORG_NOT_FOUND → 404)
│  │
│  ├─ runbooks/
│  │  ├─ sql-backup-restore.md                # PostgreSQL: PITR, WAL archiving, restore drills (monthly)
│  │  ├─ config-hot-reload.md                 # Troubleshoot: Redis Pub/Sub failures, reconcile loop gaps, version drift
│  │  ├─ secrets-rotation.md                  # Rotate: DB/Redis passwords, JWT keys, TLS certs (90-day cycle)
│  │  └─ incident-triage.md                   # SEV-1/2/3/4 response workflow, on-call procedures
│  │
│  └─ quickstart/
│     ├─ Boot-Routine.md                      # **Post-reboot cluster health checklist** (after VM restart)
│     └─ local-dev.md                         # Run locally: kind cluster + Argo CD + seed data
│
├─ infra/                                      # ⚙️ Infrastructure as Code (Terraform)
│  ├─ terraform/
│  │  ├─ modules/
│  │  │  ├─ cluster/                          # Reusable: AKS/EKS/GKE managed clusters OR kubeadm VMs
│  │  │  ├─ network/                          # VPC/VNet + subnets + security groups/NSGs
│  │  │  └─ dns/                              # DNS zones + ExternalDNS IAM/RBAC setup
│  │  │
│  │  ├─ envs/                                # Provider-specific environments
│  │  │  ├─ aks/                              # Azure Kubernetes Service (managed)
│  │  │  │  ├─ main.tf
│  │  │  │  ├─ variables.tf
│  │  │  │  └─ terraform.tfvars              # Azure-specific: resource group, region, node pools
│  │  │  │
│  │  │  ├─ eks/                              # AWS Elastic Kubernetes Service (managed)
│  │  │  │  ├─ main.tf
│  │  │  │  ├─ variables.tf
│  │  │  │  └─ terraform.tfvars              # AWS-specific: VPC, subnets, IAM roles, node groups
│  │  │  │
│  │  │  ├─ gke/                              # Google Kubernetes Engine (managed)
│  │  │  │  ├─ main.tf
│  │  │  │  ├─ variables.tf
│  │  │  │  └─ terraform.tfvars              # GCP-specific: project, region, node pools
│  │  │  │
│  │  │  └─ onprem/                           # Self-managed kubeadm (Oracle Cloud / physical on-prem)
│  │  │     ├─ main.tf                        # Provision VMs (Oracle Compute / bare-metal)
│  │  │     ├─ variables.tf
│  │  │     ├─ terraform.tfvars               # Oracle-specific: compartment, availability domain, ARM shapes
│  │  │     └─ cloud-init.yaml                # kubeadm install script (multi-step: kubeadm init, CNI, join)
│  │  │
│  │  └─ README.md                            # Terraform usage: init, plan, apply, destroy
│  │
│  └─ bootstrap/                              # 🚀 Argo CD installation + Root App (Terraform-managed)
│     ├─ argocd-install.tf                    # Install Argo CD via Helm provider
│     └─ root-app.yaml.tpl                    # Template for Root App (parameterized by provider/env)
│
├─ clusters/                                   # 🔧 Platform add-ons (Kustomize-based, provider-portable)
│  ├─ base/                                    # Provider-agnostic base manifests
│  │  ├─ ingress-nginx/
│  │  │  ├─ kustomization.yaml
│  │  │  ├─ argocd-app.yaml                   # Argo CD Application (NOT Flux HelmRelease - we use Argo CD only)
│  │  │  └─ values.yaml                       # Default values (ingressClass: nginx)
│  │  │
│  │  ├─ cert-manager/
│  │  │  ├─ kustomization.yaml
│  │  │  ├─ argocd-app.yaml                   # Argo CD Application (Helm chart reference)
│  │  │  └─ clusterissuer.yaml                # ClusterIssuer: letsencrypt-prod (DNS-01 or HTTP-01)
│  │  │
│  │  ├─ external-dns/
│  │  │  ├─ kustomization.yaml
│  │  │  └─ deployment.yaml                   # ExternalDNS controller (provider set via overlay)
│  │  │
│  │  ├─ external-secrets/
│  │  │  ├─ kustomization.yaml
│  │  │  ├─ argocd-app.yaml                   # Argo CD Application (ESO Helm chart)
│  │  │  └─ secretstore.yaml                  # Generic SecretStore (provider set via overlay)
│  │  │
│  │  ├─ policies/                            # 🔐 Policy enforcement (Kyverno/Gatekeeper)
│  │  │  ├─ kyverno/
│  │  │  │  ├─ kustomization.yaml
│  │  │  │  ├─ require-labels.yaml            # Enforce: owner, team, app labels
│  │  │  │  ├─ require-probes.yaml            # Enforce: liveness + readiness probes
│  │  │  │  ├─ restrict-root.yaml             # Block: runAsRoot, privileged containers
│  │  │  │  ├─ verify-signatures.yaml         # Verify: Cosign image signatures (keyless or KMS)
│  │  │  │  └─ default-deny-networkpolicy.yaml # Default: deny all traffic (allowlist via app overlays)
│  │  │  │
│  │  │  └─ gatekeeper/                       # Alternative: OPA Gatekeeper (if preferred over Kyverno)
│  │  │     ├─ kustomization.yaml
│  │  │     └─ constraints/
│  │  │
│  │  ├─ observability/                       # 📊 Metrics, logs, traces (in-cluster start, Mimir later)
│  │  │  ├─ kustomization.yaml
│  │  │  ├─ prometheus/
│  │  │  │  ├─ argocd-app.yaml                # Argo CD Application → kube-prometheus-stack chart
│  │  │  │  └─ values.yaml
│  │  │  ├─ loki/
│  │  │  │  ├─ argocd-app.yaml                # Argo CD Application → Loki chart
│  │  │  │  └─ values.yaml
│  │  │  ├─ tempo/
│  │  │  │  ├─ argocd-app.yaml                # Argo CD Application → Tempo chart
│  │  │  │  └─ values.yaml
│  │  │  └─ grafana/
│  │  │     └─ dashboards/                    # Pre-built dashboards (mounted as ConfigMaps)
│  │  │        ├─ golden-signals.json
│  │  │        ├─ business-metrics.json
│  │  │        └─ infrastructure.json
│  │  │
│  │  ├─ storage/                             # 💾 Generic StorageClass abstraction
│  │  │  ├─ kustomization.yaml
│  │  │  └─ storageclass-template.yaml        # Name: "standard" (provisioner set via overlay)
│  │  │
│  │  └─ backup-dr/                           # 💼 Velero (backup/restore for disaster recovery)
│  │     ├─ kustomization.yaml
│  │     ├─ argocd-app.yaml                   # Argo CD Application → Velero chart
│  │     ├─ backup-schedule.yaml              # Daily full backup, 7-day retention
│  │     └─ restore-test.yaml                 # Monthly restore drill (automated test)
│  │
│  └─ overlays/                               # 🌍 Provider-specific configurations (patches only!)
│     │
│     ├─ kind/                                # 🧪 Local development (Docker-based kind cluster)
│     │  ├─ kustomization.yaml                # Bases: ../base/* + local patches
│     │  ├─ ingress-nginx-patch.yaml          # hostPort for localhost access
│     │  ├─ storageclass-patch.yaml           # Provisioner: rancher.io/local-path
│     │  └─ external-dns-disable.yaml         # Disable ExternalDNS (no real DNS)
│     │
│     ├─ aks/                                 # ☁️ Azure Kubernetes Service (managed control plane)
│     │  ├─ kustomization.yaml
│     │  ├─ storageclass-patch.yaml           # Provisioner: disk.csi.azure.com (Azure Disk)
│     │  ├─ external-dns-azure.yaml           # Provider: azure, Azure DNS zone
│     │  ├─ workload-identity-patch.yaml      # Azure AD Workload Identity (OIDC federation)
│     │  └─ external-secrets-keyvault.yaml    # SecretStore: Azure Key Vault
│     │
│     ├─ eks/                                 # ☁️ AWS Elastic Kubernetes Service (managed)
│     │  ├─ kustomization.yaml
│     │  ├─ storageclass-patch.yaml           # Provisioner: ebs.csi.aws.com (AWS EBS)
│     │  ├─ external-dns-route53.yaml         # Provider: aws, Route 53 hosted zone
│     │  ├─ irsa-patch.yaml                   # IAM Roles for Service Accounts (IRSA)
│     │  └─ external-secrets-secretsmanager.yaml # SecretStore: AWS Secrets Manager
│     │
│     ├─ gke/                                 # ☁️ Google Kubernetes Engine (managed)
│     │  ├─ kustomization.yaml
│     │  ├─ storageclass-patch.yaml           # Provisioner: pd.csi.storage.gke.io (GCE Persistent Disk)
│     │  ├─ external-dns-clouddns.yaml        # Provider: google, Cloud DNS zone
│     │  ├─ workload-identity-patch.yaml      # GKE Workload Identity (IAM binding)
│     │  └─ external-secrets-secretmanager.yaml # SecretStore: Google Secret Manager
│     │
│     └─ onprem/                              # 🏠 Self-managed kubeadm (Oracle Cloud / physical hardware)
│        ├─ kustomization.yaml
│        ├─ metallb-config.yaml               # MetalLB: L2 mode, IP pool from Oracle Public IPs or physical LAN
│        ├─ storageclass-patch.yaml           # Provisioner: driver.longhorn.io (Longhorn on Oracle Block Storage or local disks)
│        ├─ external-dns-cloudflare.yaml      # Provider: cloudflare (or internal DNS)
│        └─ external-secrets-vault.yaml       # SecretStore: HashiCorp Vault (self-hosted)
│
├─ apps/                                       # 📦 Application layer (Helm chart references + env overlays)
│  │
│  ├─ base/                                    # Environment-agnostic Argo CD Application manifests
│  │  ├─ backend-app.yaml                     # Argo CD Application → helm-charts/application/backend
│  │  ├─ frontend-app.yaml                    # Argo CD Application → helm-charts/application/frontend
│  │  └─ postgresql-app.yaml                  # Argo CD Application → helm-charts/infrastructure/postgresql
│  │
│  └─ overlays/                               # Environment-specific value overrides (dev/staging/prod)
│     ├─ dev/
│     │  ├─ kustomization.yaml
│     │  └─ values-patch.yaml                 # Patch: replicaCount=1, resources.requests.memory=256Mi
│     │
│     ├─ staging/
│     │  ├─ kustomization.yaml
│     │  └─ values-patch.yaml                 # Patch: replicaCount=2, autoscaling enabled
│     │
│     └─ prod/
│        ├─ kustomization.yaml
│        └─ values-patch.yaml                 # Patch: replicaCount=3, PDB minAvailable=2, resources tuned
│
├─ argocd/                                     # 🔄 Argo CD configuration (App-of-Apps pattern)
│  ├─ bootstrap/
│  │  └─ root-app.yaml                        # **Root Application** (points to clusters/overlays/<provider> + apps/overlays/<env>)
│  │
│  └─ projects/
│     ├─ platform.yaml                        # AppProject: platform add-ons (ingress, cert-manager, policies)
│     └─ applications.yaml                    # AppProject: tenant applications (backend, frontend, DB)
│
├─ helm-charts/                                # 📦 Helm Charts (application definitions)
│  │
│  ├─ infrastructure/                         # Wrapped/vendored infrastructure charts (optional)
│  │  ├─ postgresql/
│  │  │  ├─ Chart.yaml                        # Bitnami PostgreSQL chart (vendored or dependency)
│  │  │  └─ values.yaml                       # Default: HA disabled, auth via Secrets, RLS enabled
│  │  │
│  │  ├─ redis/
│  │  │  ├─ Chart.yaml
│  │  │  └─ values.yaml                       # Default: standalone, Pub/Sub enabled, ACL configured
│  │  │
│  │  ├─ minio/                               # Object storage (Phase 5+, disabled in MVP)
│  │  │  ├─ Chart.yaml
│  │  │  └─ values.yaml
│  │  │
│  │  └─ ingress-nginx/                       # NGINX Ingress Controller (if not using upstream directly)
│  │     ├─ Chart.yaml
│  │     └─ values.yaml
│  │
│  └─ application/                            # 🚀 Application Helm Charts (our services)
│     │
│     ├─ backend/
│     │  ├─ Chart.yaml                        # name: backend, version: 0.1.0
│     │  ├─ values.yaml                       # **Default values** (all environments inherit)
│     │  ├─ values-dev.yaml                   # Dev overrides: debug=true, replicas=1
│     │  ├─ values-staging.yaml               # Staging overrides: replicas=2, HPA enabled
│     │  ├─ values-prod.yaml                  # Prod overrides: replicas=3, PDB, resource limits
│     │  └─ templates/
│     │     ├─ deployment.yaml                # Deployment: multi-arch (AMD64/ARM64), health probes
│     │     ├─ service.yaml                   # Service: ClusterIP
│     │     ├─ ingress.yaml                   # Ingress: TLS, cert-manager annotation
│     │     ├─ hpa.yaml                       # HorizontalPodAutoscaler (optional, enabled via values)
│     │     ├─ pdb.yaml                       # PodDisruptionBudget (minAvailable=1)
│     │     ├─ networkpolicy.yaml             # NetworkPolicy: allow ingress from NGINX, egress to DB/Redis
│     │     ├─ configmap.yaml                 # ConfigMap: non-sensitive app config
│     │     ├─ secret.yaml                    # Secret: references ExternalSecret (ESO)
│     │     └─ serviceaccount.yaml            # ServiceAccount: Workload Identity bindings
│     │
│     └─ frontend/
│        ├─ Chart.yaml
│        ├─ values.yaml
│        ├─ values-dev.yaml
│        ├─ values-staging.yaml
│        ├─ values-prod.yaml
│        └─ templates/                        # Similar structure to backend
│
├─ observability/                              # 📊 Observability assets (dashboards, alerts, policies)
│  │
│  ├─ grafana/
│  │  ├─ dashboards/                          # Pre-built Grafana dashboards (imported as ConfigMaps)
│  │  │  ├─ golden-signals.json               # RED metrics: Rate, Errors, Duration (P50/P95/P99)
│  │  │  ├─ business-metrics.json             # Domain: orgs_total, projects_active, chat_sessions_active
│  │  │  └─ infrastructure.json               # Infrastructure: PostgreSQL conn pool, Redis mem, CPU/RAM
│  │  │
│  │  └─ alerts/                              # Prometheus alerting rules (imported as ConfigMaps)
│  │     ├─ slos.yaml                         # SLO alerts: API latency P95 >500ms, error rate >1%
│  │     └─ infrastructure.yaml               # Infra alerts: DB down, Redis connection failures, disk >80%
│  │
│  └─ policies/                               # ⚠️ DEPRECATED: Moved to clusters/base/policies/ (kept for reference)
│     └─ README.md                            # Note: Policies now in clusters/base/policies/
│
├─ app/                                        # 💻 Application source code (Backend + Frontend)
│  │
│  ├─ backend/
│  │  ├─ src/
│  │  │  ├─ api/                              # REST API endpoints (FastAPI/Flask or .NET Core)
│  │  │  │  ├─ organizations.py               # POST /orgs, GET /orgs/{id}
│  │  │  │  ├─ projects.py                    # POST /orgs/{id}/projects
│  │  │  │  ├─ chat.py                        # WebSocket /chat, canned actions only
│  │  │  │  └─ configs.py                     # PUT /configs (hot-reload trigger)
│  │  │  │
│  │  │  ├─ models/                           # Domain models (SQLAlchemy or Entity Framework)
│  │  │  │  ├─ organization.py
│  │  │  │  ├─ project.py
│  │  │  │  ├─ chat_session.py
│  │  │  │  └─ service_config.py
│  │  │  │
│  │  │  ├─ services/                         # Business logic
│  │  │  │  ├─ org_service.py                 # SAGA orchestration (PENDING → COMMITTED → FAILED)
│  │  │  │  ├─ chat_service.py                # Enforce ≤3 active chats/user/project
│  │  │  │  └─ config_service.py              # Hot-reload: SQL write + Redis PUBLISH + reconcile loop
│  │  │  │
│  │  │  ├─ auth/                             # Authentication & authorization
│  │  │  │  ├─ jwt.py                         # Guest sign-in: generate JWT (guest-NNNN), short TTL
│  │  │  │  └─ middleware.py                  # Verify JWT, extract org_id/user_id
│  │  │  │
│  │  │  └─ config/                           # Config hot-reload logic
│  │  │     ├─ loader.py                      # Warm-load from SQL on startup
│  │  │     ├─ subscriber.py                  # Redis Pub/Sub: SUBSCRIBE config:* → fetch new version
│  │  │     └─ reconcile.py                   # Background loop: poll SQL every 5-10 min (fallback)
│  │  │
│  │  ├─ db/
│  │  │  └─ migrations/                       # Database migrations (Flyway/Alembic naming: V001__)
│  │  │     ├─ V001__initial_schema.sql       # Tables: organizations, projects, users (RLS enabled)
│  │  │     ├─ V002__chat_sessions.sql        # Table: chat_sessions (constraint: ≤3 active/user/project)
│  │  │     ├─ V003__service_configs.sql      # Tables: service_configs (SoT), config_history (audit)
│  │  │     └─ V004__audit_tables.sql         # Audit: org lifecycle (SAGA states), config changes
│  │  │
│  │  ├─ tests/
│  │  │  ├─ unit/                             # Unit tests (pytest/xUnit): services, models
│  │  │  ├─ integration/                      # Integration tests (Testcontainers: PostgreSQL + Redis)
│  │  │  └─ e2e/                              # E2E API tests: Create Org → Project → Chat → Hot-reload
│  │  │
│  │  ├─ test-fixtures/                       # Test data: sample orgs/projects, fake JWTs, canned chat actions
│  │  ├─ Dockerfile                           # Multi-stage build: builder → runtime (AMD64 + ARM64)
│  │  ├─ requirements.txt                     # Python deps (or package.json for Node.js)
│  │  └─ README.md                            # Backend: architecture, local dev, testing
│  │
│  └─ frontend/
│     ├─ src/
│     │  ├─ components/                       # React/Vue components (reusable UI)
│     │  ├─ pages/                            # Pages: Organizations, Projects, Chat (canned actions UI)
│     │  └─ api/                              # API client (auto-generated from openapi.yaml via Orval/OpenAPI Generator)
│     │
│     ├─ tests/                               # E2E UI tests (Playwright/Cypress): login → create org → chat
│     ├─ Dockerfile                           # Multi-stage: npm build → nginx runtime
│     ├─ package.json
│     └─ README.md                            # Frontend: architecture, local dev, testing
│
├─ tools/
│  ├─ scripts/
│  │  ├─ dev-kind-up.sh                       # 🚀 Start local kind cluster + install platform add-ons + Argo CD
│  │  ├─ seed-demo-data.sh                    # Seed: 3 demo orgs, 5 projects, 10 users, sample chat sessions
│  │  ├─ lint-all.sh                          # Lint: YAML (yamllint), Helm (helm lint), Terraform (tflint), OpenAPI (spectral)
│  │  ├─ gen-sbom.sh                          # Generate SBOM: syft → SPDX JSON, trivy → vulnerabilities
│  │  └─ render-diagrams.sh                   # Mermaid → PNG (mermaid-cli, optional for offline docs)
│  │
│  ├─ codegen/
│  │  └─ openapi-codegen.config.json          # OpenAPI client/server stub generation (Orval config)
│  │
│  └─ ct/
│     └─ config.yaml                          # Helm chart-testing (ct lint, ct install)
│
└─ setup-template/
   └─ phase0-template-foundation/
      └─ PHASE0-SETUP.md                      # Phase 0 setup guide: kind cluster + Argo CD + GitOps bootstrap
```

## 🔐 Security Highlights (§12)

- **🚫 No PII**: Guest sign-in (`guest-NNNN`), no registration, no email/phone/name stored
- **🔒 PostgreSQL RLS**: Row-level security on `org_id`/`project_id` enforces **automatic tenant isolation** (no app-level checks needed)
- **✍️ Image Signing**: Cosign keyless (OIDC via GitHub Actions) or KMS-backed; admission policies **verify signatures before deployment**
- **🚧 Default-Deny NetworkPolicies**: All traffic blocked by default; **allowlists explicit** (e.g., backend → PostgreSQL:5432, backend → Redis:6379)
- **🔑 Secrets Management**: K8s Secrets (encrypted at rest) → Phase 5+: **External Secrets Operator (ESO)** → Vault/Key Vault/Secrets Manager
- **📜 Audit Trail**: PostgreSQL `config_history` (all config changes), Kubernetes audit logs (all API calls), Git history (all infra/app changes)

See [SECURITY.md](SECURITY.md) for vulnerability reporting, threat model, break-glass procedures.

---

## 🎯 Project Phases & Roadmap

| Phase | Status | Deliverables |
|-------|--------|--------------|
| **Phase 0** | ✅ **Complete** | Local foundation: kind cluster, PostgreSQL, Redis, Argo CD, NGINX Ingress |
| **Phase 1** | ✅ **Complete** | GitOps transformation: vendored charts, Argo CD apps, auto-sync/self-heal |
| **Phase 2a** | 🔜 **Next** | Backend skeleton: FastAPI + /health + Dockerfile + Helm chart + Argo CD App |
| **Phase 2b** | 📅 Planned | Core domain: Orgs/Projects CRUD + PostgreSQL RLS + DB migrations |
| **Phase 2c** | 📅 Planned | Guest Auth: JWT generation + auth middleware + integration tests |
| **→ MVP** | 🎯 | **API works, tenants isolated, GitOps deployed** |
| **Phase 3** | 📅 Optional | Frontend dashboard (React) + basic UI for Orgs/Projects |
| **Phase 4** | 📅 Optional | Oracle Cloud deployment: Terraform modules + DNS/ACME |
| **Phase 5+** | 📅 Future | Real-time chat, config hot-reload, observability, DR, OIDC/SSO |

**Current Focus:** Phase 2a – Backend skeleton.

> **Note:** Phases 3-4 are optional for MVP. Phase 5+ contains enterprise features that can be added incrementally.

---

## 🛠️ Tech Stack (Rationale)

| Layer | Technology | Why Chosen | Alternatives Considered |
|-------|-----------|------------|------------------------|
| **Orchestration** | Kubernetes (kubeadm/AKS/EKS/GKE) | CNCF-certified, provider-portable, mature ecosystem | Docker Swarm (less features), Nomad (smaller ecosystem), k3s (less features) |
| **GitOps** | Argo CD | Declarative, app-of-apps pattern, drift detection, Kubernetes-native | Flux (less UI), Jenkins (imperative, not GitOps) |
| **IaC** | Terraform | Multi-cloud, remote state, modular, provider-agnostic | Pulumi (less adoption), ARM/CloudFormation (cloud-locked) |
| **Ingress** | NGINX Ingress | Stable, widely supported, cloud-neutral, mature | Traefik (fewer features), Istio (too heavy for MVP) |
| **Database** | PostgreSQL | **RLS** (automatic tenant isolation), ACID, PITR, JSON support | MySQL (no RLS), MongoDB (no ACID), SQL Server (Windows-heavy) |
| **Cache/Pub-Sub** | Redis | Pub/Sub for hot-reload, simple, fast, in-memory | RabbitMQ (overkill), Kafka (too heavy), NATS (less mature) |
| **Observability** | Prometheus, Loki, Tempo, Grafana | CNCF-standard, in-cluster start, **Mimir upgrade path**, vendor-neutral | Datadog (expensive), New Relic (vendor lock-in), ELK Stack (heavy) |
| **Secrets** | ESO → Vault/Key Vault | External secret store, **rotation-friendly**, multi-cloud abstraction | Sealed Secrets (no rotation), SOPS (manual, file-based) |
| **Backup/DR** | Velero | Kubernetes-native, **cross-provider**, volume snapshots | Custom scripts (not portable), Kasten (commercial) |
| **Policies** | Kyverno | Kubernetes-native, **easier than OPA** for common cases, validate/mutate/generate | OPA Gatekeeper (steeper learning curve), PSP (deprecated) |

**Decision Drivers:** Free-first (swap paid later), vendor-neutral (no lock-in), enterprise-ready (compliance, audit, DR).

---

## 📖 License

See [LICENSE](LICENSE).
