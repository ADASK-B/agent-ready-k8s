
### 1) Executive summary (5-liner)

| Key                 | Summary                                                                                                                                                                                         |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Goal                | Multi-tenant SaaS template (Org → Projects) on Kubernetes with super-simple per-project chat, ready to evolve to AI-assisted chat later                                                         |
| Tenancy             | **Organizations** (customers) own **Projects** (internal teams); strict isolation at app & DB level                                                                                             |
| Core features (MVP) | Create Org, create Project, per-user project chat (1:1 channel), mock AI responder; hot-reload configs; GitOps CD                                                                               |
| Platform            | K8s (self-managed), GitOps (Argo CD), Container runtime (containerd), IaC (Terraform), Images via OCI registry                                                                                  |
| Config & Obs        | Config SoT: SQL (+ Redis Pub/Sub for hot reload); etcd only for K8s control plane (optional app etcd later). Observability: start in-cluster (Prom/Loki/Tempo), grow to central Mimir if needed |

---

### 2) Glossary

| Term                    | Definition (concise)                                                 |
| ----------------------- | -------------------------------------------------------------------- |
| Organization (Org)      | Tenant/customer boundary; owns users & projects                      |
| Project                 | Work unit under an Org; holds members, settings, chat channels       |
| Chat                    | Per-user private channel within a project; simple text + attachments |
| Source of Truth (SoT)   | Authoritative datastore for a domain (e.g., configs in SQL)          |
| Hot-Reload              | Apply config changes at runtime without pod restarts                 |
| Config                  | User-tunable app settings (per org/project), **not** K8s resources   |
| Secrets                 | Credentials/keys; never stored in plain text configs                 |
| In-cluster vs. external | Runs inside the app cluster vs. on a separate cluster/service        |

---

### 3) RACI / Owner legend

| Role     | Owns                                                      | Examples                       |
| -------- | --------------------------------------------------------- | ------------------------------ |
| Platform | K8s cluster, Ingress, Argo CD, registries, MinIO baseline | TLS, ingress routes, Argo apps |
| App      | Backend, Frontend, schema, configs, chat logic            | APIs, UI, migrations           |
| DBA      | SQL ops: backup/PITR, indexes, RLS, auditing              | Backups, restore drills        |
| SecOps   | Secrets, policies, RBAC, image signing                    | Kyverno rules, key mgmt        |
| SRE/Obs  | Monitoring, alerting, SLOs, on-call runbooks              | Prom, Loki, Tempo, dashboards  |

---

### 4) Scope & phasing

| Capability              | MVP                                       | Phase 2+                            | Out of scope (now)       |
| ----------------------- | ----------------------------------------- | ----------------------------------- | ------------------------ |
| Org & Project lifecycle | ✅                                         | Enhancements (quota, billing)       | —                        |
| Per-user project chat   | ✅ (simple, text + attachments)            | AI assistant, threads, mentions     | Full Slack replacement   |
| Config SoT & hot-reload | ✅ SQL + Redis Pub/Sub                     | Optional etcd for app configs       | Config via K8s etcd      |
| Authentication          | ✅ Basic (email+magic link or simple OIDC) | SSO (Entra), RBAC fine-grained      | SCIM                     |
| Observability           | ✅ In-cluster Prom/Loki/Tempo              | Central Mimir (multi-cluster), SLOs | Commercial APM           |
| Secrets mgmt            | ✅ K8s Secrets (at rest encrypted)         | ESO + Vault/KeyVault                | Plain-text secrets       |
| Backups                 | ✅ SQL/MinIO scheduled                     | Cross-region, PITR drills           | “No backup” mode         |
| Compliance              | ✅ Audit logs in DB                        | DLP, retention policies per org     | Regulated industry packs |

---

## End-to-End (E2E) flows — step tables

### 5) E2E: Create Organization

| Step | Actor  | System                            | Data writes                      | Notes                                  |
| ---- | ------ | --------------------------------- | -------------------------------- | -------------------------------------- |
| 1    | Admin  | Backend API `POST /orgs`          | SQL: `organizations` (PENDING)   | RLS seeded                             |
| 2    | System | Argo CD app sync (labels per org) | —                                | Namespaces optional (single or shared) |
| 3    | System | Set defaults (quotas, policies)   | SQL: `service_configs`           | Audit trail                            |
| 4    | System | Commit org → COMMITTED            | SQL: `organizations` (COMMITTED) | Saga rollback on error                 |

### 6) E2E: Create Project

| Step | Actor     | System                             | Data writes                             | Notes                        |
| ---- | --------- | ---------------------------------- | --------------------------------------- | ---------------------------- |
| 1    | Org Admin | Backend `POST /orgs/{id}/projects` | SQL: `projects`                         | Enforce org limits           |
| 2    | System    | Init chat spaces                   | SQL: `project_members`, `chat_channels` | One private channel per user |
| 3    | System    | Config defaults for project        | SQL: `service_configs`                  | Versioned                    |

### 7) E2E: Post chat message

| Step | Actor  | System                                              | Data writes                                   | Notes               |
| ---- | ------ | --------------------------------------------------- | --------------------------------------------- | ------------------- |
| 1    | User   | Frontend → Backend `POST /chats/{channel}/messages` | SQL: `chat_messages` (+ full-text idx)        | Attachments → MinIO |
| 2    | System | Notify subscribers (WS/SSE)                         | Redis Pub/Sub (event)                         | Optional push       |
| 3    | System | Persist attachment                                  | MinIO `org/{org}/project/{p}/channel/{c}/...` | Signed URLs         |

### 8) E2E: Config change → Hot-reload

| Step | Actor    | System                     | Data writes                          | Notes                 |
| ---- | -------- | -------------------------- | ------------------------------------ | --------------------- |
| 1    | Admin    | UI `PUT /configs`          | SQL: `service_configs` (version↑)    | Append-only history   |
| 2    | Backend  | Publish change             | Redis `PUBLISH config:* "version=n"` | No secrets in events  |
| 3    | Services | On event, GET fresh config | SQL read                             | In-memory swap <100ms |

---

## Core architecture tables

### 9) Platform / Cluster

| Area           | Purpose              | Primary tech           | Placement   | HA/Backup            | Owner    | Scope |
| -------------- | -------------------- | ---------------------- | ----------- | -------------------- | -------- | ----- |
| Kubernetes     | Runtime & networking | K8s (kubeadm or cloud) | In-cluster  | Multi-AZ optional    | Platform | MVP   |
| Ingress        | North-south traffic  | NGINX Ingress          | In-cluster  | Dual replicas        | Platform | MVP   |
| GitOps CD      | Declarative deploys  | Argo CD (Helm)         | In-cluster  | HA pair optional     | Platform | MVP   |
| IaC            | Provision infra      | Terraform              | External CI | State remote backend | Platform | MVP   |
| Image registry | OCI images           | GHCR/Harbor (free)     | External    | Geo-replica optional | Platform | MVP   |

### 10) App services

| Service           | Function                      | Tech            | Endpoints            | Owner | Scope   |
| ----------------- | ----------------------------- | --------------- | -------------------- | ----- | ------- |
| Backend API       | Orgs, Projects, Chat, Configs | .NET or FastAPI | REST/OpenAPI, WS/SSE | App   | MVP     |
| Frontend          | UI                            | React/Vite      | SPA + API calls      | App   | MVP     |
| Mock AI           | Placeholder replies           | FastAPI worker  | Internal queue/API   | App   | MVP     |
| (Later) AI Assist | Real AI                       | LLM gateway     | Async events         | App   | Phase 2 |

### 11) Data & storage

| Domain              | SoT                    | Why                    | Retention       | Placement              | HA/Backup           | Owner        | Scope   |
| ------------------- | ---------------------- | ---------------------- | --------------- | ---------------------- | ------------------- | ------------ | ------- |
| Orgs/Projects/Users | **PostgreSQL** (free)  | Relational, RLS, audit | 12–36 mo        | In-cluster or external | PITR, nightly       | DBA          | MVP     |
| Chats (messages)    | **PostgreSQL** (+ FTS) | Queryable, joinable    | Per-org policy  | Same as DB             | PITR, partitioning  | DBA          | MVP     |
| Attachments         | **MinIO** (S3 API)     | Large/binary; cheap    | Size-/age-based | In-cluster (start)     | Versioning, backups | Platform     | MVP     |
| Configs (SoT)       | **PostgreSQL**         | Audit/versioning       | Indefinite      | Same as DB             | Backups             | App/DBA      | MVP     |
| Config notify       | **Redis Pub/Sub**      | Hot-reload push        | —               | In-cluster             | None (ephemeral)    | App/Platform | MVP     |
| K8s control         | **etcd (kube)**        | Control plane          | —               | Control plane          | Managed by K8s      | Platform     | MVP     |
| (Optional) App etcd | etcd                   | Native watches         | Short           | In-cluster             | Snapshots           | Platform/App | Phase 2 |

### 12) Config & secrets

| Type          | Store                     | Pattern                       | Notes                | Owner    | Scope |
| ------------- | ------------------------- | ----------------------------- | -------------------- | -------- | ----- |
| App config    | SQL (SoT)                 | Versioned rows + Redis notify | No secrets in events | App/DBA  | MVP   |
| Secrets       | K8s Secrets (AES at rest) | Mount as env/vol              | ESO→Vault later      | SecOps   | MVP   |
| System config | Helm values               | Git-tracked                   | Through Argo CD      | Platform | MVP   |

### 13) Observability & alerting (recommendation path)

| Layer      | MVP (in-cluster)          | Grow-up (central)                 | When to upgrade               | Owner   |
| ---------- | ------------------------- | --------------------------------- | ----------------------------- | ------- |
| Metrics    | Prometheus                | **Mimir** (central, multi-tenant) | Cross-cluster, long retention | SRE/Obs |
| Logs       | Loki                      | Loki (central)                    | Many clusters/teams           | SRE/Obs |
| Traces     | Tempo                     | Tempo (central)                   | Cross-cluster tracing         | SRE/Obs |
| Gateway    | Alloy/OTel Collector      | Same (HA)                         | Higher ingestion              | SRE/Obs |
| Dashboards | Grafana                   | Grafana (org-multi-tenant)        | Shared platform               | SRE/Obs |
| Alerts     | Prom rules + Alertmanager | Central AM                        | Global SLOs                   | SRE/Obs |

### 14) CI/CD

| Area     | Purpose                    | Tech                           | Pipeline highlights                                                 | Owner    | Scope |
| -------- | -------------------------- | ------------------------------ | ------------------------------------------------------------------- | -------- | ----- |
| CI       | Build/test images          | GitHub Actions/Azure Pipelines | Build (Docker/BuildKit or Buildpacks), test, SBOM, sign, push (OCI) | App      | MVP   |
| CD       | GitOps deploy              | Argo CD                        | Helm charts/values per env, PR-based promotes                       | Platform | MVP   |
| Registry | OCI (images & Helm as OCI) | GHCR/Harbor                    | Immutable tags, digest pinning                                      | Platform | MVP   |

### 15) Security & compliance

| Control     | Tooling                | Baseline                     | Owner   | Scope |
| ----------- | ---------------------- | ---------------------------- | ------- | ----- |
| Network     | NetworkPolicy          | Deny-all baseline, allowlist | SecOps  | MVP   |
| Policy      | Kyverno/Gatekeeper     | Image provenance, NS guards  | SecOps  | MVP   |
| Image trust | cosign                 | Keyless or KMS-backed        | SecOps  | MVP   |
| AuthN       | Simple OIDC/magic link | JWT short TTL                | App     | MVP   |
| AuthZ       | RBAC per org/project   | DB RLS + app checks          | App/DBA | MVP   |
| Audit       | DB audit tables        | Who/when/what                | DBA     | MVP   |

### 16) Operations & runbooks

| Runbook                    | Cadence        | Owner    | Notes                   |
| -------------------------- | -------------- | -------- | ----------------------- |
| SQL backup & restore drill | Weekly/monthly | DBA      | PITR verified           |
| MinIO backup/versioning    | Weekly         | Platform | Lifecycle rules         |
| Redis health               | Daily          | Platform | Ephemeral; restart safe |
| Argo app drift             | Daily          | Platform | Sync policy & PR flow   |
| TLS rotation               | Per cert       | SecOps   | ACME/internal PKI       |
| Incident triage            | On alert       | SRE/Obs  | Logs/metrics/traces     |

---

## Cost & alternatives (free-first, swappable)

### 17) Cost/alt matrix

| Area          | Free default                | Paid option (if customer) | Migration effort          |
| ------------- | --------------------------- | ------------------------- | ------------------------- |
| Relational DB | **PostgreSQL**              | SQL Server / Azure SQL    | Low (ORM, dialect checks) |
| Object store  | **MinIO**                   | S3 / Azure Blob           | Low (S3 API compatible)   |
| Pub/Sub       | **Redis** (OSS)             | Redis Enterprise          | Low (endpoint swap)       |
| Images/Charts | **GHCR / Harbor**           | ACR/ECR/GCR               | Low (OCI standard)        |
| Observability | **Prom+Loki+Tempo+Grafana** | Datadog/New Relic         | Medium (agent/exporters)  |
| Ingress       | **NGINX Ingress**           | NGINX Plus / F5           | Low (annotations)         |
| Secrets       | **K8s Secrets**             | Vault/KeyVault            | Medium (ESO wiring)       |
| GitOps        | **Argo CD**                 | —                         | —                         |

---

## Assumptions & constraints

### 18) Assumptions

| Assumption                          | Why it matters                  |
| ----------------------------------- | ------------------------------- |
| Single primary app cluster at start | Simpler ops and lower cost      |
| 5-minute acceptable downtime        | Enables pragmatic HA choices    |
| Storage & power are “given”         | Focus on software stack only    |
| Free-first tools                    | Customer can swap to paid later |

### 19) Risks & mitigations

| Risk           | Impact              | Mitigation                             |
| -------------- | ------------------- | -------------------------------------- |
| Config drift   | Unexpected behavior | GitOps + sync policies + alerts        |
| Chat growth    | Large tables        | Partitioning, FTS, MinIO for big files |
| Secrets sprawl | Breach risk         | Centralize via ESO→Vault later         |
| Scale plateau  | Performance issues  | HPA, DB tuning, move to central Mimir  |

---

## Org/Project/Chat data model snapshot

### 20) Minimal schema view

| Entity          | Key fields                                       | Notes                             |
| --------------- | ------------------------------------------------ | --------------------------------- |
| organizations   | id, name, owner_id, status                       | `COMMITTED/FAILED`; audit         |
| projects        | id, org_id, name                                 | FK → orgs; RLS on org_id          |
| users           | id, org_id, email                                | Org-scoped                        |
| project_members | project_id, user_id, role                        | Access control                    |
| chat_channels   | id, project_id, user_id                          | One private per user per project  |
| chat_messages   | id, channel_id, user_id, text, ts                | FTS indexes; attachments to MinIO |
| service_configs | scope (org/project/service), key, value, version | Append-only history               |
| config_history  | id, who, when, old/new, reason                   | Audit                             |

---

## MinIO tenancy & placement

### 21) Object storage strategy

| Topic               | MVP choice                                                                                      | Alternatives                                   |
| ------------------- | ----------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| Placement           | **In-cluster** MinIO (1–3 nodes)                                                                | External MinIO / S3/Blob later                 |
| Multi-tenant layout | Bucket per org *or* per project; prefix hierarchy (`org/{org}/project/{proj}/channel/{chan}/…`) | Centralized bucket with strict prefix policies |
| Access              | Signed URLs via backend                                                                         | Direct SDK if needed                           |
| Lifecycle           | Retain X days/GB per org                                                                        | Customer-specific tiering                      |
| Backup              | Versioning + periodic backup                                                                    | Cross-region if needed                         |

---

### 22) Final recommendation snapshot

| Layer         | Recommendation                                                                                                                                                    |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Configs       | **SQL as SoT + Redis Pub/Sub** for hot-reload (simple, auditable). Add **app-etcd** only if you truly need native watches.                                        |
| Observability | Start **in-cluster** (Prom/Loki/Tempo/Grafana). If retention/scale/tenants grow, move metrics to a **central Mimir** cluster; keep logs/traces central as needed. |
| Storage       | **PostgreSQL + MinIO** by default. Swap to MSSQL/S3 if a customer requires.                                                                                       |
| GitOps        | **Argo CD with Helm (OCI or charts)**, values per env/org; digest-pinned.                                                                                         |
| Security      | K8s Secrets (enc-at-rest) now; ESO→Vault/KeyVault later; cosign for images; Kyverno baseline.                                                                     |
