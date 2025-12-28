# Known Issues

> **Last Updated:** 2025-12-28
> This document tracks known issues, limitations, and technical debt in the project.

---

## Critical Issues

### 1. ~~Plaintext Credentials in Git~~ (FIXED)

**Status:** FIXED (2025-12-28)

**Original Issue:**
- `apps/base/postgresql-app.yaml` contained hardcoded passwords (`demopass`, `postgres`)
- `apps/base/redis-app.yaml` contained hardcoded password (`redispass`)

**Resolution:**
- Changed to use Kubernetes Secrets via `existingSecret` reference
- Secrets must now be created manually before deployment
- See [docs/quickstart/local-dev.md](docs/quickstart/local-dev.md) for setup instructions

---

## Security Issues

### 2. Missing NetworkPolicies

**Status:** OPEN
**Severity:** Medium
**Planned Fix:** Phase 5+

**Description:**
No NetworkPolicies are currently deployed. The architecture document (ARCHITECTURE.md §9) requires default-deny NetworkPolicies with explicit allowlists, but this is not yet implemented.

**Impact:**
- All pods can communicate with all other pods (no network isolation)
- Violates Zero Trust principles

**Workaround:**
- For development/demo environments, this is acceptable
- Do NOT use in production without implementing NetworkPolicies first

### 3. Missing cert-manager

**Status:** OPEN
**Severity:** Medium
**Planned Fix:** Phase 4

**Description:**
cert-manager is not installed. TLS certificates must be managed manually or via self-signed certificates.

**Impact:**
- No automatic Let's Encrypt certificate provisioning
- Manual TLS certificate management required for Ingress

**Workaround:**
- Use HTTP-only access for local development
- Manual TLS setup for any external access

### 4. Missing Kyverno/OPA Policies

**Status:** OPEN
**Severity:** Medium
**Planned Fix:** Phase 5+

**Description:**
The architecture requires admission policies (Kyverno or OPA Gatekeeper) for:
- Image signature verification (Cosign)
- Block `:latest` tags
- Block `runAsRoot` containers
- Require health probes

These policies are documented but not implemented.

**Impact:**
- No admission-time security enforcement
- Unsigned images can be deployed
- Non-compliant workloads can run

---

## Infrastructure Issues

### 5. Oracle Cloud Free Tier - No SLA

**Status:** ACCEPTED RISK
**Severity:** High (for production use)

**Description:**
Per ADR-0006, Oracle Cloud Free Tier provides:
- $0 cost forever
- 4 ARM CPUs, 24 GB RAM, 200 GB storage
- **NO SLA** - Oracle may reclaim instances without notice

**Impact:**
- Not suitable for production workloads requiring uptime guarantees
- Acceptable for demo/PoC/reference implementation

**Mitigation:**
- Regular Velero backups (when implemented)
- Document restore procedure to alternative cloud (AKS/EKS/GKE)
- For production: Use Oracle Paid Tier ($100/mo, 99.95% SLA) or managed K8s

### 6. No Backup/DR Implementation

**Status:** OPEN
**Severity:** High
**Planned Fix:** Phase 5+

**Description:**
Velero is planned but not installed. There is currently no backup or disaster recovery capability.

**Impact:**
- Data loss risk if cluster fails
- No point-in-time recovery for PostgreSQL

**Workaround:**
- Manual PostgreSQL backups via `pg_dump`
- Manual Redis RDB snapshots

---

## Documentation Issues

### 7. README Shows Target State, Not Current State

**Status:** IN PROGRESS
**Severity:** Low

**Description:**
The repository structure in README.md shows the complete target architecture, not what is currently implemented. This can be misleading for new contributors.

**Resolution:**
- Adding "Current State" section to README.md
- Marking target-state sections as "Roadmap"

### 8. Missing SECURITY.md

**Status:** IN PROGRESS
**Severity:** Low

**Description:**
README.md references `SECURITY.md` for vulnerability reporting, threat model, and break-glass procedures, but this file does not exist.

**Resolution:**
- Creating SECURITY.md with appropriate content

---

## Technical Debt

### 9. podinfo Demo App Should Be Removed

**Status:** OPEN
**Planned Fix:** Phase 2a (Cleanup)

**Description:**
The podinfo demo application (`apps/base/podinfo-app.yaml`, `helm-charts/infrastructure/podinfo/`) was used for Phase 0/1 testing and should be removed before Phase 2a backend implementation.

### 10. Helm Charts Not Fully Vendored

**Status:** OPEN
**Severity:** Low

**Description:**
PostgreSQL and Redis Helm charts reference local paths but may have external dependencies not fully vendored.

**Workaround:**
- Ensure Helm repo is added before deployment
- Consider vendoring charts fully for air-gapped deployments

---

## Tracking

| Issue | Severity | Status | Target Phase |
|-------|----------|--------|--------------|
| Plaintext credentials | Critical | FIXED | - |
| Missing NetworkPolicies | Medium | Open | Phase 5+ |
| Missing cert-manager | Medium | Open | Phase 4 |
| Missing Kyverno/OPA | Medium | Open | Phase 5+ |
| Oracle Free Tier SLA | High | Accepted | - |
| No Backup/DR | High | Open | Phase 5+ |
| README target vs current | Low | FIXED | - |
| Missing SECURITY.md | Low | FIXED | - |
| podinfo removal | Low | Open | Phase 2a |
| Helm chart vendoring | Low | Open | Phase 5+ |

---

## Project Analysis (2025-12-28)

### Executive Summary

| Aspekt | Bewertung |
|--------|-----------|
| **Architektur** | Solide und durchdacht |
| **Dokumentation** | Umfangreich, aber Target-State fokussiert |
| **Implementierung** | Phase 0/1 abgeschlossen, erhebliche Lücken zur Dokumentation |
| **Security** | Grundlegende Fixes durchgeführt (2025-12-28) |
| **Gesamturteil** | **Sinnvolles Vorhaben**, braucht pragmatischeren Ansatz |

### Was existiert (implementiert)

| Komponente | Status | Pfad |
|------------|--------|------|
| kind Cluster Config | ✅ | `kind-config.yaml` |
| Argo CD Installation | ✅ | Läuft im Cluster (v2.12.3) |
| PostgreSQL (Bitnami) | ✅ | `helm-charts/infrastructure/postgresql/` |
| Redis (Bitnami) | ✅ | `helm-charts/infrastructure/redis/` |
| NGINX Ingress (vendored) | ✅ | `helm-charts/infrastructure/ingress-nginx/` |
| podinfo Demo-App | ✅ | `helm-charts/infrastructure/podinfo/` |
| ArgoCD Applications | ✅ | `apps/base/*.yaml` (4 Apps) |
| Dokumentation | ✅ | `docs/` (~30 Markdown-Dateien) |

### Was NICHT existiert (nur dokumentiert)

| Komponente | Status | Geplanter Pfad |
|------------|--------|----------------|
| clusters/base/ (Kustomize) | ❌ | Nur `.gitkeep` in `clusters/local/` |
| clusters/overlays/ | ❌ | Kein aks/, eks/, gke/, onprem/ |
| apps/overlays/ (dev/staging/prod) | ❌ | Nicht vorhanden |
| argocd/ (Root-App, Projects) | ❌ | Verzeichnis existiert nicht |
| app/backend/ (Quellcode) | ❌ | Kein Python/FastAPI Code |
| app/frontend/ (Quellcode) | ❌ | Kein React/Vue Code |
| infra/terraform/ | ❌ | Keine Terraform Module |
| helm-charts/application/ | ❌ | Keine Backend/Frontend Charts |
| Observability Stack | ❌ | Kein Prometheus/Loki/Tempo |
| Kyverno/OPA Policies | ❌ | Keine Policy-Manifeste |
| Velero Backup | ❌ | Nicht konfiguriert |
| cert-manager | ❌ | Nicht installiert |
| External Secrets Operator | ❌ | Nicht installiert |

### Architektur-Bewertung

**Positive Aspekte:**
1. GitOps mit Argo CD - Industry Best Practice
2. PostgreSQL RLS für Tenant-Isolation - Elegante Lösung
3. Provider-portable Overlays - Ein Repo für alle Clouds
4. Config Hot-Reload via Redis Pub/Sub - Performant (<100ms)
5. Phasen-basierte Entwicklung - Strukturierter Ansatz
6. ADRs dokumentieren Entscheidungen - Gute Governance

**Kritische Punkte:**
1. **Dokumentation vs. Realität Gap** - README zeigt 20+ Komponenten, implementiert sind 6
2. **Komplexität vs. MVP** - ARCHITECTURE.md hat 1400+ Zeilen für ein Projekt ohne Backend-Code
3. **Sicherheitsprobleme** - BEHOBEN am 2025-12-28

### Empfohlene nächste Schritte

| Priorität | Aktion | Status |
|-----------|--------|--------|
| 1 | Security Fixes (Secrets, Image Pins) | ✅ Done |
| 2 | KNOWN_ISSUES.md erstellen | ✅ Done |
| 3 | CLAUDE.md Instructions | ✅ Done |
| 4 | README.md aktualisieren | ✅ Done |
| 5 | Phase 2 restructure (2a/2b/2c) | ✅ Done |
| 6 | Phase 2a: Backend skeleton | 🔜 Next |

### Entscheidungslog

| Datum | Entscheidung | Begründung |
|-------|--------------|------------|
| 2025-12-28 | Dokumentation-First Ansatz | README an Realität anpassen |
| 2025-12-28 | Security Fixes sofort | Kritische Probleme nicht aufschieben |
| 2025-12-28 | PostgreSQL 16.4.0 gepinnt | Aktuelle stabile Version |
| 2025-12-28 | Redis 7.4.1 gepinnt | Aktuelle stabile Version |
| 2025-12-28 | Phase 2 vereinfacht (8→5 Phasen) | MVP früher erreichbar, weniger Scope |
| 2025-12-28 | Frontend/Chat/Hot-Reload → Phase 5+ | Fokus auf API-first MVP |
