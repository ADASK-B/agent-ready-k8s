# Enterprise‑Grade Kubernetes Platform – Architecture & Operating Model (EN)

**Version:** 1.0
**Last Updated:** 09 Oct 2025 (Europe/Berlin)
**Status:** Living document — maintained via PRs; Git history is the audit trail.

---

## 0) Executive Summary (Decision‑Grade)

**Assessment:** This architecture is target‑aligned and sufficient to achieve the stated goal: a single Git repository that reproducibly deploys an enterprise‑ready Kubernetes platform to **any environment** (managed cloud or on‑prem) via **GitOps**, with **zero application‑code changes** between environments.
**Core principle:** *One codebase, multiple overlays – identical app manifests everywhere.*
**Delivery model:** Terraform (infra & GitOps bootstrap) → Argo CD (cluster add‑ons & apps) → Zero click‑ops.

**Tightenings vs. the original draft:**

* Explicit, testable **acceptance criteria** mapped to automated checks.
* A complete **repository skeleton** (Kustomize + Argo CD app‑of‑apps).
* **Fail‑closed security** (PSA “restricted”, signature‑required, default‑deny, least‑privilege RBAC).
* **Portability guardrails** (stable names, consistent classes, strict overlay boundaries).
* **DR proof** (mandatory Velero restore drill & runbook).
* **Upgrade governance** (version pinning, staged rollout, maintenance windows, runbooks).

> **Outcome:** A platform that can be rolled out on **any on‑prem Linux** host and on **AKS/EKS/GKE** from a **single Git repo**, **without changing application manifests**.

---

## 1) Purpose & Scope

Design and operate a **production‑ready, security‑first, GitOps‑driven** Kubernetes platform that runs **identically** across local, cloud, and on‑prem environments.

**Non‑goals:** Multi‑cluster fleet; application‑specific configuration; Day‑2 automation beyond GitOps sync (we provide only observability & alerting baseline).

---

## 2) Measurable Success Criteria (with Tests)

| Objective                       | Acceptance Test (automatable)                                                         |
| ------------------------------- | ------------------------------------------------------------------------------------- |
| Fresh cluster < 30 min from Git | CI spins up kind/AKS/EKS/GKE; stopwatch from bootstrap to all add‑ons Ready < 30 min. |
| DNS + TLS green                 | `curl https://app.example.com` returns 200; certificate valid; ACME events clean.     |
| Policy gates enforced           | Negative test: unsigned image or `runAsRoot` → admission **blocked**.                 |
| Backup & restore proven         | `velero restore` of a test namespace → checksums and readiness probes OK.             |
| Full audit trail                | Git history + Kubernetes audit logs enabled; query links change to deploy event.      |
| Zero click‑ops to production    | All changes via PR→merge→sync; no portal or kubectl to prod (policy enforced).        |

---

## 3) Reference Architecture (Strict Layering)

```
┌────────────────────────────────────────────────────────────────┐
│                     Applications (tenant namespaces)           │
│  ————————————————  ————————————————  ————————————————           │
│  App A (base)      App B (base)      App C (base)              │
└────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────┐
│              Cluster Add‑ons (GitOps, immutable, pinned)       │
│  Ingress, cert‑manager, ExternalDNS, ESO, Policies,            │
│  Observability (kube‑prom‑stack, Loki, OTel/Tempo), Velero     │
└────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────┐
│ Infra (Terraform)                                              │
│  Cloud: VNet/VPC, LB IPs, DNS zones, KMS, Managed Cluster      │
│  On‑Prem: VMs + cloud‑init, networks, LB IPs, MinIO, Vault     │
└────────────────────────────────────────────────────────────────┘
```

**Separation of concerns:** *Infra (Terraform) ⟂ Cluster add‑ons (Argo CD) ⟂ Apps*. No cross‑layer mixing.

---

## 4) Repository Layout (Single Repo, Provider Overlays)

```
repo/
├─ infra/                       # Terraform: cloud (aks/eks/gke) and onprem (vms, dns, s3/minio)
│  ├─ modules/
│  ├─ envs/
│  │  ├─ aks/
│  │  ├─ eks/
│  │  ├─ gke/
│  │  └─ onprem/
│  └─ bootstrap/                # Argo CD install + root app (via TF null_resource/helm)
├─ clusters/
│  ├─ base/                     # provider‑agnostic add‑ons (Kustomize bases)
│  │  ├─ ingress-nginx/
│  │  ├─ cert-manager/
│  │  ├─ external-dns/
│  │  ├─ external-secrets/
│  │  ├─ policies/              # Kyverno/Gatekeeper, PSA restricted, signature verify
│  │  ├─ observability/         # kube-prom-stack, Loki, Tempo/OTel Collector
│  │  ├─ storage/               # generic CSI abstractions; StorageClass name = "standard"
│  │  └─ backup-dr/             # Velero (CRDs, schedules, restores)
│  └─ overlays/
│     ├─ aks/
│     ├─ eks/
│     ├─ gke/
│     └─ onprem/
└─ apps/                        # environment‑agnostic application bases (optionally separate repo)
```

**App‑of‑apps:** A single **root** Argo CD Application points to `clusters/overlays/<provider>/root/` which aggregates all add‑ons and tenants.

---

## 5) Golden Rules (Portability & Operations)

1. **Strict layering:** Terraform (infra) ⟂ Argo CD (add‑ons & apps).
2. **One repo — multiple overlays:** `clusters/base/` shared; `clusters/overlays/{aks,eks,gke,onprem}/` provider specifics only.
3. **Naming consistency:** Same `ingressClassName`, `StorageClass` (e.g., `standard`), `ClusterIssuer` (e.g., `letsencrypt-prod`), Secrets & ServiceAccounts across environments.
4. **GitOps is the source of truth:** No click‑ops. Changes via PR→review→merge→sync.
5. **Immutable & signed:** Images pinned by digest, **Cosign**‑signed; never `:latest`.
6. **Security by default:** PSA restricted, default‑deny NetworkPolicies, least‑privilege RBAC, no secrets in Git.
7. **Unified observability:** Metrics/logs/traces identical everywhere; shared dashboards/alerts.
8. **DR must be proven:** Velero + object storage; periodic restore drills.
9. **Reproducible upgrades:** Version pins, staged rollout, runbooks.
10. **No provider lock‑in in app manifests:** No cloud annotations/storage classes in app charts.

---

## 6) Minimum Viable Platform (Tools & Responsibilities)

**Provisioning & governance**

* **Terraform** (infra + GitOps bootstrap); remote state w/ locking & encryption.
* **GitOps:** **Argo CD** (CLI‑first, declarative, app‑of‑apps).
* **Policy:** **Kyverno** *or* **OPA Gatekeeper** for admission & drift policy.

**Networking & entry**

* **Ingress:** NGINX **or** Traefik; one `IngressClass` everywhere.
* **Load balancer:** Cloud LBs (AKS/EKS/GKE) ↔ **MetalLB** (on‑prem).
* **DNS:** **ExternalDNS** (Azure DNS / Route 53 / Cloud DNS / internal DNS).

**Certificates & secrets**

* **cert-manager** (identical `ClusterIssuer` names).
* **External Secrets Operator (ESO)** → Azure Key Vault / AWS Secrets Manager / Google Secret Manager / Vault.

**Storage**

* Cloud CSI (Azure Disk/Files, EBS/EFS, GCE‑PD/Filestore) ↔ on‑prem **Longhorn** (simple) or **Rook‑Ceph** (scale).
* Use the **same `StorageClass` name** everywhere.

**Observability & SRE**

* **kube‑prometheus‑stack**, **Loki**, **Tempo/OTel Collector** (metrics/logs/traces).
* **Alertmanager** w/ SLOs & runbooks.

**Backup/DR**

* **Velero** (+ CSI Snapshot CRDs), offsite object storage (S3/GCS/Azure/MinIO).

**Supply chain**

* **Cosign** (signatures), **Trivy/Grype** (image scans), SBOMs in CI.

**Optional / recommended**

* **Rancher** or **Lens** (operator GUI).
* **Gateway API** (forward‑compatible), **Cilium** (eBPF) on‑prem.

---

## 7) Container Registry Strategy

**Purpose:** Centralized, rate‑limit‑free image distribution w/ RBAC, scanning and geo‑replication.

| Environment         | Registry               | When to Use                                                         | Cost       | Authentication    |
| ------------------- | ---------------------- | ------------------------------------------------------------------- | ---------- | ----------------- |
| Local (kind)        | **GHCR**               | Always                                                              | 0 €        | GitHub PAT        |
| Cloud (AKS/EKS/GKE) | **GHCR → ACR/ECR/GAR** | Start with GHCR; add native registry for geo‑replication/compliance | ~0–10 €/mo | Workload Identity |
| On‑Prem             | **GHCR** or **Harbor** | GHCR if internet; Harbor for air‑gapped                             | 0 € (GHCR) | PAT / Basic Auth  |

**Rules:** Pin by **digest**; verify **Cosign** signatures via policy; `${REGISTRY}` variable in bases, set per overlay; pull secret named `registry-credentials` consistently.

---

## 8) Cluster Options & Decision Guide

| Environment      | Cluster Type | Distribution            | Setup Complexity   | Resources  | Control Plane    |
| ---------------- | ------------ | ----------------------- | ------------------ | ---------- | ---------------- |
| Local (dev/test) | Ephemeral    | **kind**                | Low (1 command)    | ~2+ GB RAM | Local Docker     |
| Cloud (prod)     | Managed      | **AKS/EKS/GKE**         | Medium (Terraform) | Managed    | Provider‑managed |
| On‑Prem (prod)   | Self‑managed | **kubeadm** or **RKE2** | High               | 4+ GB RAM  | Self‑managed     |

**Use kind** for local tests and CI parity.
**Use managed cloud** when you want a managed control plane & cloud integrations.
**Use kubeadm** for standard on‑prem; **RKE2** for hardened/FIPS contexts.
All are **CNCF‑certified** → API‑compatible; app manifests run unchanged.

---

## 9) Do’s & Don’ts (By Domain)

### Terraform & IaC

**Do:** Separate remote state per environment; unify module interfaces; use Terraform for infra primitives & GitOps bootstrap; CI auth via OIDC.
**Don’t:** Manage Deployments/CRDs long‑term with Terraform; store secrets in state; allow portal drift.

### GitOps & manifests

**Do:** `base/` holds add‑ons; overlays alter only provider specifics; PR mandatory; pin images; fail‑closed admission.
**Don’t:** `kubectl apply` to prod; diverging names across environments.

### Networking & ingress

**Do:** One `IngressClass`; `Service` type LB (MetalLB on‑prem); default‑deny NetworkPolicies; ExternalDNS everywhere.
**Don’t:** Cloud‑specific ingress annotations in apps; internet‑facing NodePorts.

### CNI & IP design

**Do:** Document Pod/Service CIDRs; pick Cilium/Calico on‑prem; plan MTU/BGP (MetalLB).
**Don’t:** Assume identical Pod IP behavior across clouds.

### Storage & data

**Do:** Same `StorageClass` name; enable CSI snapshots; encrypt at rest; etcd secret encryption on self‑managed.
**Don’t:** Hard‑code cloud SC names; forklift PVs without migration.

### Secrets & keys

**Do:** ESO + native secret store; rotate; least privilege; short‑lived SA tokens.
**Don’t:** Static cloud keys as Kubernetes Secrets; secrets in Git/TF state.

### Identity & access

**Do:** Workload identity (Azure AD WI / IRSA / GKE WI); least‑privilege RBAC per SA; document break‑glass.
**Don’t:** `cluster-admin` for workloads; shared SAs.

### Security baseline

**Do:** PSA restricted; `runAsNonRoot`, read‑only rootFS, drop caps, seccomp; image signature verification; node/image CVE scans; CIS baselines.
**Don’t:** `privileged`, `hostNetwork`, `hostPath` unless justified & reviewed.

### Observability & SRE

**Do:** kube‑prom‑stack, Loki, OTel; propagate trace IDs; SLOs & runbooks.
**Don’t:** Vendor‑locked monitoring only; unlimited retention.

### Backup/DR

**Do:** Velero + object storage; periodic restore drills; store KMS/CA keys offsite; define RPO/RTO.
**Don’t:** Namespace‑only backups without CRDs/cluster scope; untested DR.

### Releases & environments

**Do:** Dev→Stage→Prod via promotions; Blue/Green/Canary; feature flags.
**Don’t:** Hotfixes directly on prod; diverging chart logic per env.

### Resources & scheduling

**Do:** Requests/Limits, HPA/VPA, PDBs, TopologySpread; taints/tolerations; ≥2 replicas for critical add‑ons with anti‑affinity.
**Don’t:** Overcommit blindly; single‑replica SPOFs.

### Compliance & data residency

**Do:** Classify data; encrypt in transit/at rest; review audit logs.
**Don’t:** PII in logs; mix tenants in a namespace.

### Upgrades & changes

**Do:** Release calendar, semver pins, staged dry‑run, health checks & CRD migrations.
**Don’t:** Competing CNIs/ingresses in prod “just to try”.

### FinOps / cost

**Do:** Label for cost centers; quotas; cap log/trace retention; autoscale stateless; capacity plan on‑prem.
**Don’t:** Orphan LBs/DNS/disks/images; leave cleanup unscheduled.

---

## 10) Provider Mapping (Compact)

| Component         | AKS                     | EKS                         | GKE                         | On‑Prem                           |
| ----------------- | ----------------------- | --------------------------- | --------------------------- | --------------------------------- |
| Registry          | GHCR or ACR             | GHCR or ECR                 | GHCR or GAR                 | GHCR or Harbor                    |
| Ingress/LB        | NGINX/AGIC + Azure LB   | AWS LB Controller (ALB/NLB) | GKE Ingress/Gateway + GCLB  | NGINX/Traefik + **MetalLB**       |
| CNI               | Azure CNI               | VPC CNI                     | Dataplane V2/Calico         | Cilium/Calico                     |
| Block storage     | Azure Disk (CSI)        | EBS (CSI)                   | GCE‑PD (CSI)                | **Longhorn**/**Rook‑Ceph**        |
| Shared FS         | Azure Files (CSI)       | EFS (CSI)                   | Filestore (CSI)             | NFS/CEPHFS                        |
| DNS               | Azure DNS (ExternalDNS) | Route 53 (ExternalDNS)      | Cloud DNS (ExternalDNS)     | Internal/Cloudflare (ExternalDNS) |
| Secrets           | Azure Key Vault (ESO)   | AWS Secrets Manager (ESO)   | Google Secret Manager (ESO) | Vault/Sealed Secrets (via ESO)    |
| Workload identity | Azure AD WI             | EKS Pod Identity / IRSA     | GKE WI                      | K8s SA ↔ Vault/JWT                |

---

## 11) Multi‑Tenancy Model

* **Isolation:** One namespace per team/app; default‑deny; per‑namespace RBAC bindings.
* **Quotas:** ResourceQuota + LimitRange per tenant; SLOs per service.
* **Access:** GitHub/AAD groups map to RBAC roles; break‑glass documented.
* **Network:** Namespace‑scoped ingress/egress; shared ingress with unique hostnames; shared observability with label‑based dashboards.

---

## 12) Security Baseline (Fail‑Closed)

* **Policy:** Kyverno/Gatekeeper enforce PSA restricted, signature verification (Cosign), no `:latest`, no root, no privileged, proper health probes, required labels/owners.
* **Supply chain:** Signed images, SBOM generation, Trivy/Grype scans in CI; block if critical CVEs without exception.
* **Secrets:** ESO materialization; short TTL tokens; at‑rest encryption (KMS or Vault); etcd encryption on self‑managed control planes.
* **Audit:** K8s audit policy enabled; logs shipped to Loki; change links back to Git commit.

---

## 13) Observability Baseline

* **Metrics:** kube‑prometheus‑stack (Prometheus, Alertmanager, Grafana).
* **Logs:** Loki (promtail/Vector).
* **Traces:** Tempo + OpenTelemetry Collector; W3C trace propagation.
* **Dashboards/Alerts:** Shared dashboards versioned in Git; Alertmanager routes per team; SLOs stored as code.

---

## 14) Backup & Disaster Recovery

* **Velero:** Schedules + on‑demand; include CRDs/cluster scope; object storage backend (S3/Azure/GS/MinIO).
* **Keys:** Offsite storage of CA/KMS keys and Argo CD admin recovery; document restoration steps.
* **Drills:** Monthly smoke (1 namespace); quarterly full app restore; record RPO/RTO results.

---

## 15) DNS, TLS & Certificates

* **DNS:** ExternalDNS manages A/AAAA/CNAME; cloud credentials only differ per overlay.
* **TLS:** cert‑manager with `ClusterIssuer` names **identical** across environments (e.g., `letsencrypt-staging`, `letsencrypt-prod`).
* **ACME:** HTTP‑01 via shared ingress; fallback to DNS‑01 when required (wildcards/private).

---

## 16) Storage Strategy

* **Naming:** `StorageClass` **`standard`** everywhere; overlays bind to provider‑specific CSIs.
* **On‑Prem:** Prefer **Longhorn** for simplicity or **Rook‑Ceph** for HA/scale; document failure domains & replication.
* **Snapshots:** CSI VolumeSnapshotClass defined & tested; app‑aware DB backups separate from PVC snapshots.

---

## 16.5) etcd Management (Self‑Managed Clusters Only)

**Scope:** Applies to **on‑prem kubeadm/RKE2 only**. Managed cloud (AKS/EKS/GKE) handles etcd automatically.

**Purpose:** etcd is Kubernetes' central database storing all cluster state, secrets, configurations, and **multi‑tenancy namespace isolation**. Loss or corruption of etcd means **total cluster failure** affecting all tenants.

**High Availability Requirements:**
* **3 or 5 etcd nodes** (odd number for quorum): 3 nodes tolerate 1 failure; 5 nodes tolerate 2 failures.
* **Dedicated nodes** separate from workload nodes: etcd requires consistent low‑latency disk I/O.
* **Geographic distribution** (multi‑datacenter): ensure network latency < 10ms between etcd nodes.
* **No single‑node etcd in production**: violates HA principle; creates single point of failure.

**Encryption at Rest (Mandatory):**
* **Enable Kubernetes EncryptionConfiguration** for Secrets stored in etcd.
* **Rotate encryption keys annually**: maintain old key during migration; document rotation procedure in runbook.
* **Protect encryption key files** with OS‑level permissions (600, root‑only access).
* **Multi‑tenancy critical**: without encryption, all tenant secrets readable from etcd data files.

**Backup Strategy:**
* **Automated snapshots** every 6–12 hours; store offsite (S3/MinIO/Azure Blob).
* **Retention policy**: minimum 7 days; align with RPO/RTO requirements.
* **Test restores quarterly** as part of DR drill (Section 14); untested backups are not backups.
* **Store alongside Velero**: etcd snapshots complement application‑level backups.

**Monitoring & Alerting:**
* **Critical metrics**: Leader election status, database size growth, peer latency, disk IOPS saturation.
* **Alert thresholds**: Leader loss, peer latency > 100ms, disk space > 80%, WAL sync duration spikes.
* **Dashboard**: Include etcd health in platform observability (Section 13); version in Git.

**Disaster Recovery:**
* **Document restore runbook** in Git: stop API server → restore snapshot → reconfigure data‑dir → restart cluster.
* **Practice in stage environment** quarterly; record time‑to‑recovery; update RPO/RTO.
* **Offsite key storage**: CA certificates, encryption keys, Argo CD admin credentials.

**Don'ts:**
* Don't run etcd on high‑I/O shared disks (use dedicated SSD/NVMe).
* Don't skip encryption at rest (compliance violation; tenant secrets exposed).
* Don't assume backups work without restore testing (Section 14 drill mandate).
* Don't run single‑node etcd in production (no HA = SPOF for all tenants).

---

## 17) GitOps & Argo CD Pattern

* **Root app:** App‑of‑apps points to overlay root; sync waves order CRDs → operators → add‑ons → tenants.
* **Policies:** Argo projects per tenant; deny cross‑namespace references; read‑only to cluster‑scoped resources unless approved.
* **Sync:** Auto‑sync enabled in lower envs; manual sync with PR approval in prod; health & sync windows defined.
* **Drift:** Alert on drift; block manual changes in prod.

---

## 18) Promotion & Releases

* **Flow:** Dev → Stage → Prod via PRs (image digest bumps only).
* **Strategies:** Blue/Green or Canary (via ingress or Service mesh if adopted).
* **Freeze:** Change freeze windows around critical business dates.
* **Rollback:** Declarative rollbacks via Git revert; DNS toggle for Blue/Green.

---

## 19) Upgrade Runbook (K8s & Add‑ons)

1. Review upstream change logs; update ADR if breaking changes.
2. Bump versions in a **stage** branch; CI runs conformance & policy tests.
3. Deploy to **kind** + **Stage**; execute synthetic checks & chaos tests (optional).
4. Announce maintenance window; backup etcd (self‑managed) & Velero preflight; freeze non‑essential changes.
5. Upgrade prod in waves (CRDs first, then operators, then components); verify health & SLOs.
6. Post‑upgrade validation; unfreeze; publish release notes.

---

## 20) Pre‑Flight Checklist (before first apply)

* [ ] CIDR plan (Pod/Service/VNet/VPC) approved; no corporate collisions.
* [ ] DNS zones & ACME challenge path specified.
* [ ] Storage strategy (SC name, driver) confirmed.
* [ ] Registry choice & credentials prepared; image signing keys ready.
* [ ] Secret backends & ESO providers permissioned.
* [ ] Observability targets & alert routes defined.
* [ ] Velero backend (bucket/MinIO) available; access verified.
* [ ] GitOps bootstrap repo with branch protection & CI OIDC ready.
* [ ] Policy set (Kyverno/OPA) tested; admission fail‑closed.
* [ ] Runbooks, break‑glass accounts, and audit policy documented.

---

## 21) Go‑Live Checklist (per environment)

* [ ] Argo CD synced, **drift = 0**; all add‑ons **Ready**.
* [ ] Ingress reachable; DNS records correct; **TLS green**.
* [ ] NetworkPolicies enforced (positive/negative tests).
* [ ] Storage PVC lifecycle & snapshots validated.
* [ ] ESO secrets materialize & rotate.
* [ ] Observability dashboards & alerts live; test alerts received.
* [ ] Velero restore **passed** (smoke).
* [ ] SLO dashboards live; on‑call informed; freeze window set.
* [ ] Backout plan rehearsed.

---

## 22) Weekly Ops Routine (short)

* [ ] Review pending updates (cluster/add‑ons).
* [ ] Triage vulnerabilities (images/nodes).
* [ ] Inspect cost drivers (LBs/disks/logs).
* [ ] Perform a Velero restore smoke (1 namespace).
* [ ] Resolve policy violations/drift.

---

## 23) Anti‑Patterns (Red Card)

* Cloud annotations or provider SC names in app charts.
* `kubectl apply` to production from laptops.
* Secrets/keys in Git or Terraform state.
* Mutable tags (`:latest`) or unsigned images.
* Missing default‑deny or weak RBAC.
* Backups without restore drills.
* Inconsistent names (Issuer/Ingress/SC) across environments.
* Parallel click‑ops alongside Terraform/GitOps.

---

## 24) ADRs, Naming & Conventions

* **ADRs:** Every significant decision (CNI, ingress, storage, policy engine) recorded with context, options, decision, consequences.
* **Names:**

  * IngressClass: `nginx`
  * StorageClass: `standard`
  * ClusterIssuers: `letsencrypt-staging`, `letsencrypt-prod`
  * Pull secret: `registry-credentials`
  * Team namespaces: `team-<name>`; apps: `app-<name>`
* **Labels/Annotations:** `owner`, `team`, `cost-center`, `app`, `env`, `version`, `commit`.

---

## 25) Overlay Guidance (What May Differ by Provider)

* **Load Balancer:** Cloud LB vs. MetalLB IP pools/BGP.
* **DNS credentials:** Azure/Route53/CloudDNS vs. internal provider.
* **CSI drivers:** Azure Disk/Files, EBS/EFS, GCE‑PD/Filestore vs. Longhorn/Ceph.
* **Workload identity:** AAD WI / IRSA / GKE WI vs. Vault‑JWT.

> **Everything else stays constant** (ingress class name, storage class name, issuer names, RBAC patterns, observability stack, policy sets).

---

## 26) Example Test Scenarios (Portability Contracts)

* Deploy a reference app with: Ingress (host), PVC (`standard`), Secret (ESO), ConfigMap, HPA.
* Negative admission tests: unsigned image, `runAsRoot`, missing probes, `:latest`.
* Network tests: namespace default‑deny, allow only needed egress (DNS, registry).
* DR test: backup+restore of app namespace; assert identical DNS/TLS post‑restore.

---

## 27) Governance & Process

* **Change management:** PR templates require risk, rollback & observability notes.
* **Approvals:** Two‑person rule for prod changes; security review for policy relaxations.
* **Exceptions:** Time‑bound with expiry; tracked in Git; alert on expiry.
* **Audits:** Quarterly review of RBAC, policies, and DR results.

---

## 28) Readiness to Scale (Future‑Proofing)

* **Gateway API** to replace classic Ingress incrementally.
* **Cilium** with eBPF for advanced networking & policy; cluster mesh later if needed.
* **Fleet mgmt** (Argo CD + Projects or Rancher) once multi‑cluster is in scope.
* **SPIFFE/SPIRE** for workload identity hardening if required.

---

## 29) Conclusion

This document provides **decision‑grade guardrails** that keep the platform portable, secure, and reproducible. If followed, it will **lead directly to the stated goal**: a platform you can bring up on any on‑prem Linux machine **and** any major cloud (AKS/EKS/GKE) from the **same Git repository**, with identical application manifests and **no manual clicks** to production.

> **Action:** Implement the repo skeleton, bootstrap Terraform + Argo CD, and enforce the policies as code. Keep this document updated via PRs as architectural decisions evolve.
