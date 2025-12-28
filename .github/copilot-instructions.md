# agent-ready-k8s (link-only, single file)

> **Purpose:** Single control file for GitHub Copilot / LLM agents.
>
> **Token policy:** Do **not** expand documentation inline. Load only the minimal **linked** file(s) on demand.

---

## 🚨 Critical Rules

1. **Language:** All code, docs, commits **must be English**. Input may be any language → **Output always English**.
2. **Keyword Interpretation:** All user requests (any language) must be internally translated to **English keywords only** for routing/matching. No dual-language keyword tables.
3. **Infra guardrail (MUST):** Before any infrastructure choice/change:

```
read_file("docs/architecture/ARCHITECTURE.md")
```

4. **Docs are NOT auto-loaded.** Read only when needed via:

```
read_file("<path>")
```

5. **Maintenance:** Keep paths/triggers current whenever files/folders/scripts/stack change or a phase completes.

---

## 🧭 Agent Dispatch Policy (token-aware)

**Goal:** Route to the **minimal** relevant doc(s).

**Flow**

1. Normalize user request (lowercase, strip punctuation).
2. If the request implies **infra decision** (db/storage/networking/security/cloud/mq) → **always**:

   ```
   read_file("docs/architecture/ARCHITECTURE.md")
   ```
3. Else match the **Routing Table** (specific > generic).
4. Load **one** file first. If incomplete, load **one more** (max 2 per turn).
5. Answer using only what was read. If still unclear, ask to load a specific path.

**Action template**

```
read_file("<best-match-path>")
# optional second read if essential
answer
```

**Tie-breakers**

* **Architecture first** if any infra term matches—even if others also match.
* **Specific > generic** (e.g., Boot Routine beats README for reboot issues).
* **Ambiguous?** Ask once or propose top 2 candidate paths.

---

**Quick Routing:**
1. Infra → `ARCHITECTURE.md` ⚠️ ALWAYS
2. Goals → `goals-and-scope.md`⚠️ ALWAYS

---

## 🧪 Matching Examples

* "Which **database** for local vs **AKS**?" → `read_file("docs/architecture/ARCHITECTURE.md")`
* "What is the **project goal** and **MVP scope**?" → `read_file("docs/architecture/goals-and-scope.md")`
* "Cluster shows **CrashLoopBackOff** after **reboot**" → `read_file("docs/quickstart/Boot-Routine.md")`
* "Fresh laptop: how to **install** the stack?" → `read_file("setup-template/phase0-template-foundation/PHASE0-SETUP.md")`
* "What's the **current status** of **Phase 0**?" → `read_file("docs/roadmap/Phase-0.md")`
* "What is this project?" → `read_file("README.md")`

---

## 🧱 Anti-patterns (to save tokens)

* Auto-reading multiple docs “just in case”.
* Loading README when a specific doc matches better.
* Skipping **ARCHITECTURE.md** before infra decisions.
* Reading >2 files per turn without explicit user need.

---

## 📚 Complete Documentation Inventory

> **All 32 docs with full routing metadata.** Check before referencing.

### Root (5 docs)

| Area | Purpose | When to read (intent) | **Keywords** | **Deny (do not route if these dominate)** | Path | **Status** |
| ---- | ------- | --------------------- | ------------ | ------------------------------------------ | ---- | ---------- |
| **Overview** | Project overview & getting started | Generic overview / getting started | overview, getting started, what is this, summary, repo structure | aks, eks, gke, reboot, install, phase 0, crashloop | `README.md` | ✅ Finalized |
| **Security Policy** | Security disclosure & baseline controls | Security policy / reporting vulnerabilities / baseline controls | security, vulnerability, disclosure, reporting, baseline controls, psa, securitycontext | architecture, setup, reboot | `SECURITY.md` | ✅ Finalized |
| **Documentation Tracking** | Track documentation issues & fixes | Documentation todo list / doc fixes / doc status | documentation, doc fixes, todo, tracking, verification | architecture, setup, reboot | `DOCS_TODO.md` | ✅ Finalized |
| **Agent Guidelines** | Repository conventions for agents | Agent workflow / coding style / commit conventions | agent, guidelines, conventions, coding style, commit, pr | architecture, setup, reboot | `AGENTS.md` | ✅ Finalized |
| **Agent Routing** | Single control file for agent routing | Agent routing / documentation inventory / routing table | agent routing, copilot, routing table, documentation inventory | architecture, setup, reboot | `.github/copilot-instructions.md` | ✅ Finalized |

### docs/architecture/ (7 docs)

| Area | Purpose | When to read (intent) | **Keywords** | **Deny (do not route if these dominate)** | Path | **Status** |
| ---- | ------- | --------------------- | ------------ | ------------------------------------------ | ---- | ---------- |
| **Architecture** | Design decisions; golden rules; provider mapping | Any infrastructure choice / policy / platform question | architecture, design decision, golden rule, database, postgres, mysql, redis, mongo, storage, pvc, storageclass, csi, ingress, service mesh, istio, linkerd, cni, calico, cilium, load balancer, security, tls, rbac, secret, policy, mq, kafka, rabbitmq, nats, provider, aks, eks, gke, on‑prem, vendor lock | readme, overview | `docs/architecture/ARCHITECTURE.md` | ✅ Finalized |
| **Goals & Scope** | Project vision; MVP scope; multi-tenancy model | What is the goal / scope / MVP / success criteria | goal, vision, scope, mvp, phase, success criteria, tenant, multi-tenant, saas, organization, project, chat, e2e flow, raci, owner, assumptions, risks, free-first, config hot-reload, observability strategy | architecture, reboot, install, setup | `docs/architecture/goals-and-scope.md` | ✅ Finalized |
| **Deployment Model** | GitOps deployment patterns | Deployment strategy / GitOps patterns / sync policies | deployment, gitops, sync, self-heal, prune, app-of-apps, multi-tenancy | setup, reboot, boot routine | `docs/architecture/deployment-model.md` | ⚠️ DRAFT (Phase 2) |
| **Observability Strategy** | Metrics, logging, tracing stack | Observability / metrics / logging / tracing / dashboards | observability, metrics, logging, tracing, prometheus, loki, tempo, grafana, alerts | setup, reboot, boot routine | `docs/architecture/observability-strategy.md` | ⚠️ DRAFT (Phase 2) |
| **Testing Strategy** | Testing tooling & quality gates | Testing / quality gates / test tooling / coverage | testing, quality gates, pytest, k6, coverage, unit test, integration test, e2e | setup, reboot, boot routine | `docs/architecture/testing-strategy.md` | ⚠️ DRAFT (Phase 2) |
| **Learning Notes** | Research notes & findings | Research notes / learning / exploration | learning, notes, research, findings, exploration | architecture, setup, reboot | `docs/architecture/Learning-Notes-Collection.md` | ℹ️ Reference |
| **Diagram Rendering** | Mermaid diagram rendering guide | Diagram rendering / mermaid / diagram workflow | diagram, mermaid, rendering, visualization, mmdc | architecture, setup, reboot | `docs/architecture/diagrams/README.md` | ✅ Finalized |

### docs/adr/ (6 docs)

| Area | Purpose | When to read (intent) | **Keywords** | **Deny (do not route if these dominate)** | Path | **Status** |
| ---- | ------- | --------------------- | ------------ | ------------------------------------------ | ---- | ---------- |
| **ADR-0001: Config SoT** | Config source of truth = PostgreSQL | Config source of truth / database selection | config, source of truth, postgresql, database, config storage | setup, reboot, boot routine | `docs/adr/ADR-0001-config-sot-sql.md` | ✅ Accepted |
| **ADR-0002: Hot-Reload** | Hot-reload via Redis Pub/Sub | Hot-reload / redis / pubsub / config updates | hot-reload, redis, pubsub, config updates, live reload | setup, reboot, boot routine | `docs/adr/ADR-0002-hot-reload-redis.md` | ✅ Accepted |
| **ADR-0003: etcd Scope** | etcd = K8s only | etcd scope / kubernetes only / no app data | etcd, kubernetes, k8s, scope, app data | setup, reboot, boot routine | `docs/adr/ADR-0003-etcd-scope.md` | ✅ Accepted |
| **ADR-0004: Guest Auth** | Guest sign-in pattern | Guest authentication / anonymous access | guest, authentication, anonymous, sign-in | setup, reboot, boot routine | `docs/adr/ADR-0004-guest-auth.md` | ✅ Accepted |
| **ADR-0005: Canned Chat** | Canned chat implementation | Canned chat / pre-defined messages | canned chat, pre-defined messages, templates | setup, reboot, boot routine | `docs/adr/ADR-0005-canned-chat.md` | ✅ Accepted |
| **ADR-0006: Oracle Cloud** | Oracle Cloud Free Tier platform | Oracle cloud / free tier / MVP platform | oracle cloud, free tier, mvp, platform, cloud provider | setup, reboot, boot routine | `docs/adr/ADR-0006-oracle-cloud-free-tier.md` | ✅ Accepted |

### docs/api/ (2 docs)

| Area | Purpose | When to read (intent) | **Keywords** | **Deny (do not route if these dominate)** | Path | **Status** |
| ---- | ------- | --------------------- | ------------ | ------------------------------------------ | ---- | ---------- |
| **API Conventions** | API design guidelines | API design / REST conventions / API guidelines | api, rest, conventions, guidelines, endpoints, versioning | setup, reboot, boot routine | `docs/api/conventions.md` | ✅ Finalized |
| **Error Catalog** | API error codes & messages | API errors / error codes / error handling | api errors, error codes, error handling, error catalog | setup, reboot, boot routine | `docs/api/error-catalog.md` | ✅ Finalized |

### docs/quickstart/ (2 docs)

| Area | Purpose | When to read (intent) | **Keywords** | **Deny (do not route if these dominate)** | Path | **Status** |
| ---- | ------- | --------------------- | ------------ | ------------------------------------------ | ---- | ---------- |
| **Boot Routine** | After‑reboot checklist; system verification | After reboot checks / down or unstable cluster | reboot, boot, startup, cluster not responding, node not ready, crashloop, pending, health check, 502, connection refused, argocd down | install, setup, phase 0, architecture | `docs/quickstart/Boot-Routine.md` | ✅ Finalized |
| **Local Dev Guide** | GitOps development workflow | Local development / dev workflow / gitops development | local dev, development, workflow, gitops, prerequisites | setup, reboot, boot routine | `docs/quickstart/local-dev.md` | ✅ Finalized |

### docs/roadmap/ (3 docs)

| Area | Purpose | When to read (intent) | **Keywords** | **Deny (do not route if these dominate)** | Path | **Status** |
| ---- | ------- | --------------------- | ------------ | ------------------------------------------ | ---- | ---------- |
| **Roadmap Phase 0** | Phase‑0 task list & status | Status / plan / progress | phase 0, task list, status, progress, roadmap, todo, backlog, milestone | reboot, install, setup, architecture | `docs/roadmap/Phase-0.md` | ✅ Finalized |
| **Phase 1 Roadmap** | Phase 1 task list & GitOps transformation | Phase 1 / gitops transformation / status / progress | phase 1, gitops, transformation, status, progress, roadmap | setup, reboot, boot routine | `docs/roadmap/Phase-1.md` | ✅ Finalized |
| **Phase 2 Roadmap** | Phase 2 Backend API (2a/2b/2c sub-phases) | Phase 2 / backend api / mvp / orgs projects auth | phase 2, backend, api, fastapi, orgs, projects, auth, jwt, rls, mvp | setup, reboot, boot routine | `docs/roadmap/Phase-2.md` | 🔜 Next |

### docs/runbooks/ (4 docs)

| Area | Purpose | When to read (intent) | **Keywords** | **Deny (do not route if these dominate)** | Path | **Status** |
| ---- | ------- | --------------------- | ------------ | ------------------------------------------ | ---- | ---------- |
| **Config Hot-Reload Debug** | Debug config hot-reload issues | Config hot-reload / redis pubsub / debug config updates | hot-reload, config, redis, pubsub, debug, config updates | setup, reboot, boot routine | `docs/runbooks/config-hot-reload.md` | ⚠️ ACTIVE (placeholders) |
| **SQL Backup & Restore** | PostgreSQL backup/restore procedures | Backup / restore / postgresql / disaster recovery | backup, restore, postgresql, pg_dump, disaster recovery, pitr | setup, reboot, boot routine | `docs/runbooks/sql-backup-restore.md` | ⚠️ DRAFT (Phase 5+) |
| **Secrets Rotation** | Secrets rotation procedures | Secrets rotation / password rotation / key rotation | secrets, rotation, password rotation, key rotation, security | setup, reboot, boot routine | `docs/runbooks/secrets-rotation.md` | ⚠️ DRAFT (Phase 5+) |
| **Incident Triage** | Incident response procedures | Incident response / triage / postmortem | incident, triage, response, postmortem, sev-1, war room | setup, reboot, boot routine | `docs/runbooks/incident-triage.md` | ⚠️ DRAFT (Phase 5+) |

### docs/legal/ (2 docs)

| Area | Purpose | When to read (intent) | **Keywords** | **Deny (do not route if these dominate)** | Path | **Status** |
| ---- | ------- | --------------------- | ------------ | ------------------------------------------ | ---- | ---------- |
| **Attributions** | Third-party attributions | Attributions / third-party / credits | attributions, third-party, credits, notice | architecture, setup, reboot | `docs/legal/NOTICE.md` | ✅ Finalized |
| **Third-Party Licenses** | Third-party license information | Third-party licenses / license info | licenses, third-party, license info, dependencies | architecture, setup, reboot | `docs/legal/LICENSE-3RD-PARTY.md` | ✅ Finalized |

### setup-template/ (1 doc)

| Area | Purpose | When to read (intent) | **Keywords** | **Deny (do not route if these dominate)** | Path | **Status** |
| ---- | ------- | --------------------- | ------------ | ------------------------------------------ | ---- | ---------- |
| **Setup Phase 0** | Local foundation; tools & components | First install / local foundation / missing tools | first install, initial setup, install, prerequisite, missing tools, kind, kubectl, helm, argocd cli, /etc/hosts, local dev, phase 0, bootstrap | reboot, crashloop, node not ready, architecture | `setup-template/phase0-template-foundation/PHASE0-SETUP.md` | ✅ Finalized |

---

**Legend:** ✅ Finalized | ⚠️ DRAFT (Phase 5+) | ⚠️ ACTIVE (placeholders) | ℹ️ Reference
