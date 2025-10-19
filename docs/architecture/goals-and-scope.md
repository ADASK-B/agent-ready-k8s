## 1) Executive summary (5-liner)

| Key          | Summary                                                                                                                                                                                                         |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Goal         | Multi-tenant SaaS template (Org → Projects) on Kubernetes with **ultra-simple per-user project chat** (canned actions only), upgradeable to AI later.                                                           |
| Tenancy      | **Organizations** (customers) own **Projects** (internal teams). Isolation in app + DB (RLS).                                                                                                                   |
| Core MVP     | Create Org, create Project, per-user **ephemeral chat actions** (👍/👎, Ready/Blocked/Review, “Deployed/Tests green”, simple polls), hot-reload configs, GitOps CD.                                             |
| Platform     | K8s (self-managed), Argo CD (GitOps), Terraform (infra), OCI registry, NGINX Ingress.                                                                                                                           |
| Config & Obs | Config SoT: **PostgreSQL** (+ **Redis Pub/Sub** hot-reload). etcd only for K8s control plane (optional app-etcd later). Observability: start in-cluster (Prom/Loki/Tempo), grow to central **Mimir** if needed. |

---

## 2) Glossary

| Term                    | Definition                                                                                            |
| ----------------------- | ----------------------------------------------------------------------------------------------------- |
| Organization (Org)      | Tenant/customer boundary; owns users & projects.                                                      |
| Project                 | Work unit under an Org; holds members, settings, **per-user chat**.                                   |
| Chat (MVP)              | Per-user private channel; **only canned actions** (no free text), **no PII**, **no message storage**. |
| SoT                     | Source of Truth (authoritative datastore).                                                            |
| Hot-Reload              | Apply config changes without restarts (push + in-mem swap).                                           |
| In-cluster vs. external | Runs inside app cluster vs. separate/managed platform.                                                |

---

## 3) Roles / RACI

| Role     | Owns                                              | Examples                 |
| -------- | ------------------------------------------------- | ------------------------ |
| Platform | K8s, Ingress, Argo CD, registries, MinIO baseline | TLS, routes, Argo apps   |
| App      | Backend, Frontend, schema, chat logic             | APIs, UI, migrations     |
| DBA      | SQL ops: backup/PITR, indexes, RLS, audit         | Backups, restore drills  |
| SecOps   | Secrets, RBAC/policies, image signing             | Kyverno, cosign          |
| SRE/Obs  | Monitoring, alerting, SLOs, runbooks              | Prom/Loki/Tempo, Grafana |

---

## 4) Scope & phasing

| Capability              | MVP                                                                                      | Phase 2+                                     | Out of scope (now)      |
| ----------------------- | ---------------------------------------------------------------------------------------- | -------------------------------------------- | ----------------------- |
| Orgs & Projects         | ✅                                                                                        | Quotas, billing                              | —                       |
| Chat                    | ✅ **Canned actions only** (no free text), **max 3 active chats/user/project**, ephemeral | Threads, AI assistant, mentions, attachments | Slack-like features     |
| Config SoT & hot-reload | ✅ SQL + Redis Pub/Sub                                                                    | Optional app-etcd watches                    | K8s etcd for app config |
| Auth                    | ✅ **Guest sign-in**, no registration                                                     | OIDC/SSO (Entra), roles                      | SCIM                    |
| Observability           | ✅ Prom/Loki/Tempo in-cluster                                                             | Central **Mimir/Thanos**                     | Commercial APM          |
| Secrets                 | ✅ K8s Secrets (enc at rest)                                                              | ESO→Vault/KeyVault                           | Plain-text secrets      |
| Backups                 | ✅ SQL scheduled + PITR                                                                   | Cross-region, restore drills                 | “No backup” mode        |

---

## 5) E2E flows

### 5.1 Create Organization

| Step | Actor  | System         | Data writes                     | Notes                                             |
| ---- | ------ | -------------- | ------------------------------- | ------------------------------------------------- |
| 1    | Admin  | `POST /orgs`   | SQL: `organizations(PENDING)`   | Start **SAGA** + **idempotency** (`operation_id`) |
| 2    | System | Apply defaults | SQL: `service_configs`          | Audit history                                     |
| 3    | System | Isolation gate | K8s policy & labels             | `isolation-ready=true` gate                       |
| 4    | System | Commit         | SQL: `organizations(COMMITTED)` | Rollback on error                                 |

### 5.2 Create Project

| Step | Actor     | System                     | Data writes                          | Notes                 |
| ---- | --------- | -------------------------- | ------------------------------------ | --------------------- |
| 1    | Org Admin | `POST /orgs/{id}/projects` | SQL: `projects`                      | RLS based on `org_id` |
| 2    | System    | Prepare chat metadata      | SQL: `chat_sessions` (per-user caps) | No messages table     |

### 5.3 Open/use chat (canned actions)

| Step | Actor  | System                                                                       | Data writes                                                                 | Notes                            |
| ---- | ------ | ---------------------------------------------------------------------------- | --------------------------------------------------------------------------- | -------------------------------- |
| 1    | User   | Open chat                                                                    | SQL: `chat_sessions` (ensure **≤3 active**)                                 | FIFO close oldest when 4th       |
| 2    | User   | Send action (👍/👎, Ready/Blocked/Review, “Deployed/Tests green”, poll vote) | **No message storage**; optional **aggregated counters** per channel in SQL | **No PII**, ephemeral WS fan-out |
| 3    | System | Fan-out                                                                      | Redis Pub/Sub → connected clients                                           | No persistence                   |

### 5.4 Config change → Hot-reload

| Step | Actor    | System            | Data writes                          | Notes                                       |
| ---- | -------- | ----------------- | ------------------------------------ | ------------------------------------------- |
| 1    | Admin    | UI `PUT /configs` | SQL `service_configs` (version++)    | Append-only `config_history`                |
| 2    | Backend  | Publish           | Redis `PUBLISH config:* "version=n"` | No secrets in events                        |
| 3    | Services | Fetch & swap      | SQL read → in-memory update          | Warm-load on start; reconcile loop 5–10 min |

---

## 6) Platform / Cluster

| Area                | Purpose                    | Primary tech           | Placement     | HA/Backup            | Owner    | Scope |
| ------------------- | -------------------------- | ---------------------- | ------------- | -------------------- | -------- | ----- |
| Kubernetes          | Runtime & networking       | kubeadm/AKS/EKS/GKE    | In-cluster    | Multi-AZ optional    | Platform | MVP   |
| Ingress             | North-south                | **NGINX Ingress**      | In-cluster    | 2 replicas           | Platform | MVP   |
| GitOps CD           | Declarative deploys        | **Argo CD** + **Helm** | In-cluster    | HA pair optional     | Platform | MVP   |
| IaC                 | Provision infra            | **Terraform**          | External CI   | Remote state         | Platform | MVP   |
| Registry            | OCI (images + Helm-as-OCI) | **GHCR/Harbor**        | External      | Geo-replica optional | Platform | MVP   |
| Control plane store | K8s state                  | **etcd (kube)**        | Control plane | K8s-managed          | Platform | MVP   |

---

## 7) Application services

| Service     | Function                                        | Tech            | Endpoints         | Scale   | Storage           | Owner |
| ----------- | ----------------------------------------------- | --------------- | ----------------- | ------- | ----------------- | ----- |
| Frontend    | UI (Orgs/Projects/Chat actions)                 | React/Vite      | HTTPS via Ingress | HPA 1–3 | none              | App   |
| Backend API | Orgs, Projects, **Chat sessions/caps**, Configs | .NET or FastAPI | REST + WS/SSE     | HPA 1–3 | PostgreSQL, Redis | App   |
| Mock “AI”   | Deterministic canned replies (for demo)         | FastAPI worker  | internal HTTP     | 1–2     | none              | App   |

---

## 8) Data & storage

| Domain                   | SoT                        | Why                                                   | Retention        | Placement              | HA/Backup           | Owner    | Notes                               |
| ------------------------ | -------------------------- | ----------------------------------------------------- | ---------------- | ---------------------- | ------------------- | -------- | ----------------------------------- |
| Orgs/Projects/Membership | **PostgreSQL**             | Relational + **RLS** + audit                          | 12–36 mo         | In-cluster or external | **PITR** + nightly  | DBA      | RLS on `org_id`/`project_id`        |
| Chat sessions/counters   | **PostgreSQL**             | Enforce **≤3 chats/user/project**, aggregate counters | 30–90 d          | Same as DB             | PITR                | DBA      | **No messages stored**              |
| Configs (SoT)            | **PostgreSQL**             | Versioned, auditable                                  | Indefinite       | Same as DB             | Backups             | App/DBA  | `service_configs`, `config_history` |
| Config notify            | **Redis Pub/Sub**          | Hot-reload push                                       | —                | In-cluster             | Ephemeral           | Platform | TLS, ACL, no secrets                |
| Assets (future)          | **MinIO** (optional later) | Large binaries                                        | Lifecycle policy | In-cluster (start)     | Versioning + backup | Platform | **Disabled in MVP**                 |

---

## 9) Config & secrets

| Type          | Store                         | Pattern                                                                   | Security                     | Owner    | Scope |
| ------------- | ----------------------------- | ------------------------------------------------------------------------- | ---------------------------- | -------- | ----- |
| App config    | **SQL (SoT)**                 | Monotonic `version`; Redis **version-only** events; warm-load + reconcile | DB auth + RLS                | App/DBA  | MVP   |
| Secrets       | **K8s Secrets** (enc at rest) | Mounted env/vol                                                           | ESO→Vault/KeyVault (Phase 2) | SecOps   | MVP   |
| System config | Helm values                   | Git-tracked via Argo CD                                                   | Reviews/PRs                  | Platform | MVP   |

---

## 10) Observability (recommended path)

| Layer      | MVP (in-cluster)          | Grow-up (central)                 | When to upgrade               | Owner   |
| ---------- | ------------------------- | --------------------------------- | ----------------------------- | ------- |
| Metrics    | **Prometheus**            | **Mimir** (central, multi-tenant) | Retention/scale/multi-cluster | SRE/Obs |
| Logs       | **Loki**                  | Loki (central)                    | Many teams/clusters           | SRE/Obs |
| Traces     | **Tempo**                 | Tempo (central)                   | Cross-cluster tracing         | SRE/Obs |
| Gateway    | Alloy / OTel Collector    | Same (HA)                         | Higher ingest                 | SRE/Obs |
| Dashboards | Grafana                   | Grafana (org-multi-tenant)        | Shared platform               | SRE/Obs |
| Alerts     | Prom rules + Alertmanager | Central AM                        | Global SLOs                   | SRE/Obs |

---

## 11) CI/CD & supply chain

| Area     | Purpose           | Tech                           | Pipeline highlights                                                                                                     | Owner    | Scope |
| -------- | ----------------- | ------------------------------ | ----------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| CI       | Build/test images | GitHub Actions/Azure Pipelines | Build (Docker/BuildKit or Buildpacks) → Test → **SBOM (syft)** → **Vuln scan (Trivy)** → **Sign (cosign)** → Push (OCI) | App      | MVP   |
| CD       | GitOps deploy     | **Argo CD**                    | Helm charts/values per env, PR-based promotions, drift detection                                                        | Platform | MVP   |
| Registry | OCI               | **GHCR / Harbor**              | Immutable tags, digest pinning, Helm-as-OCI                                                                             | Platform | MVP   |

---

## 12) Security & compliance guardrails

| Control          | Baseline                                                             |
| ---------------- | -------------------------------------------------------------------- |
| **No PII**       | Guest users only; **no analytics**, no personal data stored.         |
| Network          | NetworkPolicy deny-all + allowlists.                                 |
| Policy           | Kyverno/Gatekeeper: labels, images, signatures, namespace gates.     |
| Image trust      | **cosign** keyless/KMS.                                              |
| AuthN            | Guest sign-in, JWT short TTL, **JTI denylist** for emergency revoke. |
| AuthZ            | App RBAC + **PostgreSQL RLS** on `org_id`/`project_id`.              |
| Audit            | `config_history`, org/project lifecycle audit.                       |
| SAGA/Idempotency | `operation_id`, `PENDING/COMMITTED/FAILED`, compensations.           |
| Redis hardening  | TLS, ACL, backoff, no secrets in channels.                           |

---

## 13) Operations & runbooks

| Runbook                     | Cadence        | Owner    | Notes                 |
| --------------------------- | -------------- | -------- | --------------------- |
| SQL backup + **PITR drill** | Weekly/monthly | DBA      | Target RPO 5 min      |
| Argo app drift review       | Daily          | Platform | Enforce sync policies |
| Redis health                | Daily          | Platform | Ephemeral; restart OK |
| TLS rotation                | Per-cert       | SecOps   | ACME/internal PKI     |
| Incident triage             | On alert       | SRE/Obs  | Logs/metrics/traces   |
| Config reconcile            | 5–10 min loop  | App      | Heals missed events   |

---

## 14) Cost & alternatives (free-first, swappable)

| Area          | Free default                | Paid option (if customer) | Migration effort       |
| ------------- | --------------------------- | ------------------------- | ---------------------- |
| Relational DB | **PostgreSQL**              | SQL Server / Azure SQL    | Low (ORM/dialect)      |
| Object store  | **MinIO** (later)           | S3 / Azure Blob           | Low (S3 API)           |
| Pub/Sub       | **Redis OSS**               | Redis Enterprise          | Low (endpoint swap)    |
| Registry      | **GHCR / Harbor**           | ACR/ECR/GCR               | Low (OCI)              |
| Observability | **Prom+Loki+Tempo+Grafana** | Datadog/New Relic         | Medium (agents/export) |
| Ingress       | **NGINX Ingress**           | F5/NGINX Plus             | Low (annotations)      |
| Secrets       | **K8s Secrets**             | Vault/KeyVault            | Medium (ESO wiring)    |
| GitOps        | **Argo CD**                 | —                         | —                      |

---

## 15) Assumptions & constraints

| Assumption                          | Why it matters                 |
| ----------------------------------- | ------------------------------ |
| Single primary app cluster at start | Simpler ops, lower cost.       |
| 5-minute acceptable downtime        | Pragmatic HA choices.          |
| Free-first tooling                  | Customers can swap paid later. |
| No PII                              | Eases DSGVO exposure for MVP.  |

---

## 16) Risks & mitigations

| Risk          | Impact              | Mitigation                                |
| ------------- | ------------------- | ----------------------------------------- |
| Config drift  | Unexpected behavior | GitOps + sync policies + alerts           |
| Chat misuse   | PII typed into UI   | **No free text**; canned actions only     |
| Scale plateau | Performance issues  | HPA, DB tuning, central Mimir when needed |
| Secret sprawl | Breach risk         | ESO→Vault/KeyVault in Phase 2             |

---

## 17) Ownership & repos

| Area                  | Owner        | Repo        |
| --------------------- | ------------ | ----------- |
| App code (FE/BE/Mock) | Product eng  | `app-git`   |
| Helm & Argo apps      | Platform eng | `ops-git`   |
| Infra-as-Code         | Platform eng | `infra-git` |
| Docs & runbooks       | Both         | `docs-git`  |

---

## 18) Minimal DB schema (heads-up)

> All with **RLS** on `org_id` / `project_id`.

| Table             | Key fields                                                                           | Notes                    |
| ----------------- | ------------------------------------------------------------------------------------ | ------------------------ |
| `organizations`   | id, name, status(`PENDING/COMMITTED/FAILED`), created_at                             | SAGA statuses            |
| `projects`        | id, org_id, name, created_at                                                         | FK → orgs                |
| `users`           | id, org_id, user_key (guest-NNNN)                                                    | Non-PII identifier       |
| `project_members` | project_id, user_id, role                                                            | Access control           |
| `chat_sessions`   | id, org_id, project_id, user_id, opened_at, closed_at                                | **Enforce ≤3 active**    |
| `chat_counters`   | channel_id, metric (👍/👎/Ready/Blocked/Review/choiceX), value                       | Optional aggregates only |
| `service_configs` | id, org_id, scope(service/project), key, value_json, version, updated_by, updated_at | SoT                      |
| `config_history`  | id, org_id, key, old_json, new_json, version, actor, reason, ts                      | Audit                    |

> **No `chat_messages` table in MVP.** No free text is stored.

---

## 19) MinIO strategy (future, not MVP)

| Topic     | MVP          | Phase 2                      |
| --------- | ------------ | ---------------------------- |
| Placement | Not required | In-cluster MinIO (1–3 nodes) |
| Tenancy   | —            | Bucket or prefix per Org     |
| Access    | —            | Signed URLs via backend      |
| Lifecycle | —            | Per-Org size/age policies    |
| Backup    | —            | Versioning + backup jobs     |

---

## 20) Final recommendation snapshot

| Layer         | Recommendation                                                                                                                                        |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Configs       | **SQL as SoT + Redis Pub/Sub** (simple, auditable, fast). Consider **app-etcd** only if you truly need native watches everywhere.                     |
| Observability | Start **in-cluster** (Prom/Loki/Tempo/Grafana). Move metrics to a **central Mimir** cluster when retention/scale/multi-cluster needs arise.           |
| Security      | Guest sign-in; **no PII**; short-lived JWT + JTI denylist; RLS; Kyverno; cosign.                                                                      |
| Operations    | PITR for DB, reconcile loop for config, drift detection via Argo, runbooks for backup/restore and TLS rotation.                                       |
| Chat          | **Canned-actions only**, ephemeral WS fan-out, no message storage, ≤3 active chats per user per project; future AI/chat upgrades are straightforward. |
