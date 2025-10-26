# Enterprise-Grade Kubernetes Platform – Architecture & Operating Model (EN)

**Version:** 1.0
**Last Updated:** 10 Oct 2025 (Europe/Berlin)
**Status:** Living document — maintained via PRs; Git history is the audit trail.

---

## Table of Contents

### 📋 Core Architecture (Must-Read)
- [§0 Executive Summary](#0-executive-summary-decision-grade)
- [§1 Purpose & Scope](#1-purpose--scope)
- [§2 Measurable Success Criteria](#2-measurable-success-criteria-with-tests)
- [§3 Reference Architecture](#3-reference-architecture-strict-layering)
- [§4 Repository Layout](#4-repository-layout-single-repo-provider-overlays)
- [§5 Golden Rules](#5-golden-rules-portability--operations)

### 🔧 Implementation Details
- [§6 Minimum Viable Platform](#6-minimum-viable-platform-tools--responsibilities)
- [§7 Container Registry Strategy](#7-container-registry-strategy)
- [§8 Cluster Options & Decision Guide](#8-cluster-options--decision-guide)
- [§9 Do's & Don'ts (By Domain)](#9-dos--donts-by-domain)
- [§10 Provider Mapping](#10-provider-mapping-compact)

### 👥 Multi-Tenancy & Security
- [§11 Multi-Tenancy Model](#11-multi-tenancy-model)
- [§11.5 Tenant Onboarding & Access Pattern](#115-tenant-onboarding--access-pattern-optional-azure-devops-alignment)
- [§11.6 Tenant Offboarding & Deletion](#116-tenant-offboarding--deletion)
- [§12 Security Baseline](#12-security-baseline-fail-closed)

### 📊 Observability & SRE
- [§13 Observability Baseline](#13-observability-baseline)
- [§13.5 SLOs, SLIs & Error Budgets](#135-slos-slis--error-budgets-platform-defaults)
- [§14 Backup & Disaster Recovery](#14-backup--disaster-recovery)

### 🌐 Networking & Storage
- [§15 DNS, TLS & Certificates](#15-dns-tls--certificates)
- [§16 Storage Strategy](#16-storage-strategy)
- [§16.5 etcd Management](#165-etcd-management-self-managed-clusters-only)

### 🔄 GitOps & Operations
- [§17 GitOps & Argo CD Pattern](#17-gitops--argo-cd-pattern)
- [§18 Promotion & Releases](#18-promotion--releases)
- [§18.1 Change-Management Gates](#181-change-management-gates-required-checks-before-prod)
- [§19 Upgrade Runbook](#19-upgrade-runbook-k8s--add-ons)
- [§20 Pre-Flight Checklist](#20-pre-flight-checklist-before-first-apply)
- [§21 Go-Live Checklist](#21-go-live-checklist-per-environment)
- [§22 Weekly Ops Routine](#22-weekly-ops-routine-short)

### ⚠️ Governance & Best Practices
- [§23 Anti-Patterns](#23-anti-patterns-red-card)
- [§24 ADRs, Naming & Conventions](#24-adrs-naming--conventions)
- [§25 Overlay Guidance](#25-overlay-guidance-what-may-differ-by-provider)
- [§26 Example Test Scenarios](#26-example-test-scenarios-portability-contracts)
- [§27 Governance & Process](#27-governance--process)
- [§28 Readiness to Scale](#28-readiness-to-scale-future-architecture-considerations)
- [§29 Conclusion](#29-conclusion)

### 🔐 Advanced Topics
- [§30 Threat Model & Risk Register](#30-threat-model-stride-lite--risk-register)
- [§31 Supply-Chain Attestations & SLSA](#31-supply-chain-attestations--slsa)
- [§32 Node OS Baseline & CIS Controls](#32-node-os-baseline--cis-controls)
- [§33 Air-Gapped Mode & Private PKI](#33-air-gapped-mode--private-pki)
- [§34 Platform Conformance Tests](#34-platform-conformance-tests)
- [§35 Cost & Sizing Guardrails](#35-cost--sizing-guardrails)
- [§36 Private PKI & mTLS Option](#36-private-pki--mtls-option)
- [§37 Version & Support Policy](#37-version--support-policy)
- [§38 Root of Trust & Key Management](#38-root-of-trust--key-management)
- [§39 Incident Response & Forensics](#39-incident-response--forensics)
- [§40 Platform Decommission & Exit Runbook](#40-platform-decommission--exit-runbook)

---

## 0) Executive Summary (Decision-Grade)

**Assessment:** This architecture is target-aligned and sufficient to achieve the stated goal: a single Git repository that reproducibly deploys an enterprise-ready Kubernetes platform to **any environment** (managed cloud or on-prem) via **GitOps**, with **zero application-code changes** between environments.
**Core principle:** *One codebase, multiple overlays – identical app manifests everywhere.*
**Delivery model:** Terraform (infra & GitOps bootstrap) → Argo CD (cluster add-ons & apps) → Zero click-ops.

**Tightenings vs. the original draft:**

* Explicit, testable **acceptance criteria** mapped to automated checks.
* A complete **repository skeleton** (Kustomize + Argo CD app-of-apps).
* **Fail-closed security** (PSA “restricted”, signature-required, default-deny, least-privilege RBAC).
* **Portability guardrails** (stable names, consistent classes, strict overlay boundaries).
* **DR proof** (mandatory Velero restore drill & runbook).
* **Upgrade governance** (version pinning, staged rollout, maintenance windows, runbooks).
* **Advanced capabilities:** Threat model & risk register, SLO/SLI + error budgets, change-management gates, SLSA attestations, OS/CIS baseline, platform conformance tests, cost/sizing guardrails, air-gapped & private PKI options, and Azure DevOps alignment.

> **Outcome:** A platform that can be rolled out on **any on-prem Linux** host and on **AKS/EKS/GKE** from a **single Git repo**, **without changing application manifests**.

---

## 1) Purpose & Scope

Design and operate a **production-ready, security-first, GitOps-driven** Kubernetes platform that runs **identically** across local, cloud, and on-prem environments.

**Non-goals:** Multi-cluster fleet; application-specific configuration; Day-2 automation beyond GitOps sync (we provide only observability & alerting baseline).

---

## 2) Measurable Success Criteria (with Tests)

| Objective                       | Acceptance Test (automatable)                                                         |
| ------------------------------- | ------------------------------------------------------------------------------------- |
| Fresh cluster < 30 min from Git | CI spins up kind/AKS/EKS/GKE; stopwatch from bootstrap to all add-ons Ready < 30 min. |
| DNS + TLS green                 | `curl https://app.example.com` returns 200; certificate valid; ACME events clean.     |
| Policy gates enforced           | Negative test: unsigned image or `runAsRoot` → admission **blocked**.                 |
| Backup & restore proven         | `velero restore` of a test namespace → checksums and readiness probes OK.             |
| Full audit trail                | Git history + Kubernetes audit logs enabled; query links change to deploy event.      |
| Zero click-ops to production    | All changes via PR→merge→sync; no portal or kubectl to prod (policy enforced).        |

---

## 3) Reference Architecture (Strict Layering)

```
┌────────────────────────────────────────────────────────────────┐
│                     Applications (tenant namespaces)           │
│  ————————————————  ————————————————  ————————————————           │
│  App A (base)      App B (base)      App C (base)              │
└────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────┐
│              Cluster Add-ons (GitOps, immutable, pinned)       │
│  Ingress, cert-manager, ExternalDNS, ESO, Policies,            │
│  Observability (kube-prom-stack, Loki, OTel/Tempo), Velero     │
└────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────┐
│ Infra (Terraform)                                              │
│  Cloud: VNet/VPC, LB IPs, DNS zones, KMS, Managed Cluster      │
│  On-Prem/Oracle: VMs + cloud-init, networks, LB IPs, MinIO, Vault │
└────────────────────────────────────────────────────────────────┘
```

**Separation of concerns:** *Infra (Terraform) ⟂ Cluster add-ons (Argo CD) ⟂ Apps*. No cross-layer mixing.

**Infrastructure note:** Oracle Cloud Free Tier follows the **On-Prem** pattern (self-managed VMs + k3s), not the Cloud pattern (managed Kubernetes services).

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
│  │  └─ onprem/                # Also used for Oracle Cloud Free Tier
│  └─ bootstrap/                # Argo CD install + root app (via TF null_resource/helm)
├─ clusters/
│  ├─ base/                     # provider-agnostic add-ons (Kustomize bases)
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
│     └─ onprem/                # Self-managed kubeadm (physical or Oracle Cloud)
└─ apps/                        # environment-agnostic application bases (optionally separate repo)
```

**App-of-apps:** A single **root** Argo CD Application points to `clusters/overlays/<provider>/root/` which aggregates all add-ons and tenants.

**Note on `onprem/` overlay:** This overlay is used for **all self-managed Kubernetes deployments**, including:
* Physical on-premises servers (Raspberry Pi, NUC, datacenter rack servers)
* **Oracle Cloud Free Tier** (self-managed k3s on Oracle VMs)
* Home lab setups
* Any environment where you control the Kubernetes control plane (not AKS/EKS/GKE managed services)

---

## 5) Golden Rules (Portability & Operations)

1. **Strict layering:** Terraform (infra) ⟂ Argo CD (add-ons & apps).
2. **One repo — multiple overlays:** `clusters/base/` shared; `clusters/overlays/{aks,eks,gke,onprem}/` provider specifics only.
3. **Naming consistency:** Same `ingressClassName`, `StorageClass` (e.g., `standard`), `ClusterIssuer` (e.g., `letsencrypt-prod`), Secrets & ServiceAccounts across environments.
4. **GitOps is the source of truth:** No click-ops. Changes via PR→review→merge→sync.
5. **Immutable & signed:** Images pinned by digest, **Cosign**-signed; never `:latest`.
6. **Security by default:** PSA restricted, default-deny NetworkPolicies, least-privilege RBAC, no secrets in Git.
7. **Unified observability:** Metrics/logs/traces identical everywhere; shared dashboards/alerts.
8. **DR must be proven:** Velero + object storage; periodic restore drills.
9. **Reproducible upgrades:** Version pins, staged rollout, runbooks.
10. **No provider lock-in in app manifests:** No cloud annotations/storage classes in app charts.

---

## 6) Minimum Viable Platform (Tools & Responsibilities)

**Provisioning & governance**

* **Terraform** (infra + GitOps bootstrap); remote state w/ locking & encryption.
* **GitOps:** **Argo CD** (CLI-first, declarative, app-of-apps).
* **Policy:** **Kyverno** *or* **OPA Gatekeeper** for admission & drift policy.

**Networking & entry**

* **Ingress:** NGINX **or** Traefik; one `IngressClass` everywhere.
* **Load balancer:** Cloud LBs (AKS/EKS/GKE) ↔ **MetalLB** (on-prem).
* **DNS:** **ExternalDNS** (Azure DNS / Route 53 / Cloud DNS / internal DNS).

**Certificates & secrets**

* **cert-manager** (identical `ClusterIssuer` names).
* **External Secrets Operator (ESO)** → Azure Key Vault / AWS Secrets Manager / Google Secret Manager / Vault.

**Storage**

* Cloud CSI (Azure Disk/Files, EBS/EFS, GCE-PD/Filestore) ↔ on-prem **Longhorn** (simple) or **Rook-Ceph** (scale).
* Use the **same `StorageClass` name** everywhere.

**Observability & SRE**

* **kube-prometheus-stack**, **Loki**, **Tempo/OTel Collector** (metrics/logs/traces).
* **Alertmanager** w/ SLOs & runbooks.

**Backup/DR**

* **Velero** (+ CSI Snapshot CRDs), offsite object storage (S3/GCS/Azure/MinIO).

**Supply chain**

* **Cosign** (signatures), **Trivy/Grype** (image scans), SBOMs in CI.

**Optional / recommended**

* **Rancher** or **Lens** (operator GUI).
* **Gateway API** (forward-compatible), **Cilium** (eBPF) on-prem.

---

## 7) Container Registry Strategy

**Purpose:** Centralized, rate-limit-free image distribution w/ RBAC, scanning and geo-replication.

| Environment         | Registry               | When to Use                                                         | Cost       | Authentication    |
| ------------------- | ---------------------- | ------------------------------------------------------------------- | ---------- | ----------------- |
| Local (kind)        | **GHCR**               | Always                                                              | 0 €        | GitHub PAT        |
| Cloud (AKS/EKS/GKE) | **GHCR → ACR/ECR/GAR** | Start with GHCR; add native registry for geo-replication/compliance | ~0–10 €/mo | Workload Identity |
| On-Prem / **Oracle Cloud** | **GHCR** or **Harbor** | GHCR if internet; Harbor for air-gapped                       | 0 € (GHCR) | PAT / Basic Auth  |

**Rules:** Pin by **digest**; verify **Cosign** signatures via policy; `${REGISTRY}` variable in bases, set per overlay; pull secret named `registry-credentials` consistently.

**Multi-architecture support (ARM/AMD):**
* **Build:** Use `docker buildx` or `kaniko` to create **multi-arch manifests** (linux/amd64, linux/arm64).
* **Promotion:** Promote images by **digest** (not tag) to ensure bit-identical binaries across environments; prevents node-arch drift on-prem (mixed AMD/ARM clusters).
* **Validation:** CI tests run on both AMD64 and ARM64 runners; block merge if either arch fails.
* **Oracle Cloud note:** Always Free Tier uses **ARM64 only** (Ampere A1); ensure all images include `linux/arm64` architecture.

---

## 8) Cluster Options & Decision Guide

| Environment      | Cluster Type | Distribution            | Setup Complexity   | Resources  | Control Plane    | Cost |
| ---------------- | ------------ | ----------------------- | ------------------ | ---------- | ---------------- | ---- |
| Local (dev/test) | Ephemeral    | **kind**                | Low (1 command)    | ~2+ GB RAM | Local Docker     | Free |
| Cloud (prod)     | Managed      | **AKS/EKS/GKE**         | Medium (Terraform) | Managed    | Provider-managed | $$$ |
| On-Prem (prod)   | Self-managed | **k3s** or **kubeadm** or **RKE2** | Medium-High | 4+ GB RAM | Self-managed | Hardware cost |
| **Oracle Cloud Free Tier (prod)** | **Self-managed** | **k3s** (recommended) | **Medium** | **4 ARM CPUs, 24 GB RAM** | **Self-managed** | **Free (forever)** |

**Use kind** for local tests and CI parity.
**Use managed cloud** when you want a managed control plane & cloud integrations.
**Use Oracle Cloud Free Tier** for production-ready self-managed clusters **without cost** (uses `onprem/` overlay).
**Use k3s** for lightweight ARM/on-prem setups; **kubeadm** for standard on-prem; **RKE2** for hardened/FIPS contexts.
All are **CNCF-certified** → API-compatible; app manifests run unchanged.

### 8.1) Oracle Cloud Free Tier Details (Recommended for MVP Production)

**Why Oracle Cloud Free Tier is ideal for this project:**
* **Self-managed Kubernetes** (full control, no vendor lock-in) using the **same `onprem/` overlay** as physical on-prem.
* **Always Free resources** (no credit expiration, no surprise billing):
  * 4x ARM Ampere A1 CPUs (Cortex-A76 equivalent)
  * 24 GB RAM (split across VMs as needed)
  * 200 GB Block Storage (for etcd, PVCs, Longhorn)
  * 2x Public IPv4 addresses (for LoadBalancer services)
  * 10 TB outbound traffic/month
* **⚠️ NO SLA** (Free Tier = best-effort, Oracle may reclaim instances) - suitable for demo/reference implementation. For production with uptime requirements, use Oracle Paid Tier ($100/mo, 99.95% SLA) or managed K8s (AKS/EKS/GKE).
* **Same tooling as physical on-prem**: MetalLB, Longhorn/Rook-Ceph, Cilium/Calico, Vault, ExternalDNS.

**Recommended VM layout:**
```
Control Plane VM (Master):
├─ 2 ARM CPUs
├─ 12 GB RAM
├─ 100 GB Block Storage
└─ k3s server (control plane + etcd)

Worker Node VM:
├─ 2 ARM CPUs
├─ 12 GB RAM
├─ 100 GB Block Storage
└─ k3s agent (application workloads)
```

**Use cases:**
* **Phase 4 (MVP Production):** Deploy multi-tenant SaaS for real users without infrastructure cost.
* **Staging environment:** Persistent staging cluster that mirrors production (unlike ephemeral Codespaces).
* **Learning/PoC:** Production-grade Kubernetes without commitment.

**Caveats:**
* **Resource limits:** Cannot scale beyond 4 CPUs/24 GB without paid tier.
* **ARM architecture only:** Ensure all images support `linux/arm64` (see §7 multi-arch).
* **Single region:** No built-in multi-region HA (use Velero + object storage for DR).
* **Account suspension risk:** Oracle may suspend accounts for ToS violations (rare, but document backup strategy).

---

## 9) Do’s & Don’ts (By Domain)

### Terraform & IaC

**Do:** Separate remote state per environment; unify module interfaces; use Terraform for infra primitives & GitOps bootstrap; CI auth via OIDC.
**Don’t:** Manage Deployments/CRDs long-term with Terraform; store secrets in state; allow portal drift.

### GitOps & manifests

**Do:** `base/` holds add-ons; overlays alter only provider specifics; PR mandatory; pin images; fail-closed admission.
**Don’t:** `kubectl apply` to prod; diverging names across environments.

### Networking & ingress

**Do:** One `IngressClass`; `Service` type LB (MetalLB on-prem); default-deny NetworkPolicies; ExternalDNS everywhere.
**Don’t:** Cloud-specific ingress annotations in apps; internet-facing NodePorts.


### Egress & External Dependencies

**Allowed egress targets (enforced via NetworkPolicies):**
* **DNS:** Cluster CoreDNS (UDP/53) + external DNS (overlay variable: `${EXTERNAL_DNS_IPS}` → e.g., 1.1.1.1, 8.8.8.8 public or corporate DNS).
* **NTP:** Public NTP pools (UDP/123) or internal time servers.
* **OCSP/CRL:** Certificate revocation checks (HTTP/80, HTTPS/443).
* **Registries:** GHCR, ACR/ECR/GAR, Harbor (allow by **FQDN** via Cilium/Calico DNS policies + IP ranges as fallback).
* **Cloud APIs:** Azure/AWS/GCP for Workload Identity, ESO, CSI (HTTPS/443).

**Deny by default:** All egress blocked (deny-all baseline per namespace, see §11).

**FQDN-based policies:** Prefer DNS-aware policies (Cilium CiliumNetworkPolicy, Calico GlobalNetworkPolicy with DNS) over static IPs; run monthly IP drift tests (verify registry IPs haven't changed).
### CNI & IP design

**Do:** Document Pod/Service CIDRs; pick Cilium/Calico on-prem; plan MTU/BGP (MetalLB).
**Don’t:** Assume identical Pod IP behavior across clouds.

### Storage & data

**Do:** Same `StorageClass` name; enable CSI snapshots; encrypt at rest (see §16.5.3 for etcd encryption); KMS or Vault for secret stores.
**Don't:** Hard-code cloud SC names; forklift PVs without migration.

### Secrets & keys

**Do:** ESO + native secret store; rotate; least privilege; short-lived SA tokens.
**Don’t:** Static cloud keys as Kubernetes Secrets; secrets in Git/TF state.

### Identity & access

**Do:** Workload identity (Azure AD WI / IRSA / GKE WI); least-privilege RBAC per SA; document break-glass.
**Don’t:** `cluster-admin` for workloads; shared SAs.

### Security baseline

**Do:** PSA restricted; `runAsNonRoot`, read-only rootFS, drop caps, seccomp; image signature verification; node/image CVE scans; CIS baselines (see §32 for OS hardening).
**Don't:** `privileged`, `hostNetwork`, `hostPath` unless justified & reviewed.

### Observability & SRE

**Do:** kube-prom-stack, Loki, OTel; propagate trace IDs; SLOs & runbooks.
**Don’t:** Vendor-locked monitoring only; unlimited retention.

### Backup/DR

**Do:** Velero + object storage; periodic restore drills (see §14 for DR objectives); store KMS/CA keys offsite; define RPO/RTO.
**Don't:** Namespace-only backups without CRDs/cluster scope; untested DR.

### Releases & environments

**Do:** Dev→Stage→Prod via promotions; Blue/Green/Canary; feature flags.
**Don’t:** Hotfixes directly on prod; diverging chart logic per env.

### Resources & scheduling

**Do:** Requests/Limits, HPA/VPA, PDBs, TopologySpread; taints/tolerations; ≥2 replicas for critical add-ons with anti-affinity.
**Don’t:** Overcommit blindly; single-replica SPOFs.

### Compliance & data residency

**Do:** Classify data; encrypt in transit/at rest; review audit logs.
**Don’t:** PII in logs; mix tenants in a namespace.

### Upgrades & changes

**Do:** Release calendar, semver pins, staged dry-run, health checks & CRD migrations.
**Don’t:** Competing CNIs/ingresses in prod “just to try”.

### FinOps / cost

**Do:** Label for cost centers; quotas; cap log/trace retention; autoscale stateless; capacity plan on-prem.
**Don’t:** Orphan LBs/DNS/disks/images; leave cleanup unscheduled.

---

## 10) Provider Mapping (Compact)

| Component         | AKS                     | EKS                         | GKE                         | On-Prem / **Oracle Cloud Free Tier**          |
| ----------------- | ----------------------- | --------------------------- | --------------------------- | --------------------------------------------- |
| Registry          | GHCR or ACR             | GHCR or ECR                 | GHCR or GAR                 | **GHCR** or Harbor                            |
| Ingress/LB        | NGINX/AGIC + Azure LB   | AWS LB Controller (ALB/NLB) | GKE Ingress/Gateway + GCLB  | **NGINX/Traefik + MetalLB** (Oracle Public IP)|
| CNI               | Azure CNI               | VPC CNI                     | Dataplane V2/Calico         | **Cilium/Calico**                             |
| Block storage     | Azure Disk (CSI)        | EBS (CSI)                   | GCE-PD (CSI)                | **Longhorn/Rook-Ceph** (Oracle Block Storage) |
| Shared FS         | Azure Files (CSI)       | EFS (CSI)                   | Filestore (CSI)             | **NFS/CEPHFS** (between VMs)                  |
| DNS               | Azure DNS (ExternalDNS) | Route 53 (ExternalDNS)      | Cloud DNS (ExternalDNS)     | **Cloudflare/internal** (ExternalDNS)         |
| Secrets           | Azure Key Vault (ESO)   | AWS Secrets Manager (ESO)   | Google Secret Manager (ESO) | **Vault/Sealed Secrets** (via ESO)            |
| Workload identity | Azure AD WI             | EKS Pod Identity / IRSA     | GKE WI                      | **K8s SA ↔ Vault/JWT**                        |

**Note:** Oracle Cloud Free Tier uses the **same `onprem/` overlay** as physical on-prem infrastructure. All tools, configurations, and manifests are identical to traditional self-managed Kubernetes deployments.

### 10.1) High Availability Requirements (per Provider)

| Requirement | AKS | EKS | GKE | On-Prem (kubeadm/RKE2) | **Oracle Cloud Free Tier** |
|-------------|-----|-----|-----|------------------------|----------------------------|
| **Min Nodes/AZ** | ≥ 2 per AZ (≥ 6 total for 3 AZs) | ≥ 2 per AZ (≥ 6 total) | ≥ 2 per Zone (≥ 6 total) | ≥ 3 nodes across failure domains (rack/switch/power) | **2 nodes only** (resource limit) |
| **Control Plane SLA** | 99.95% (multi-AZ) / 99.9% (single-AZ) | 99.95% (multi-AZ) | 99.95% (regional) / 99.5% (zonal) | Self-managed (target 99.9% via etcd quorum) | **NO SLA** (best-effort, demo/ref only) |
| **PodDisruptionBudget** | `minAvailable: 2` for critical add-ons | `minAvailable: 2` | `minAvailable: 2` | `minAvailable: 2` (or 50% if ≥ 4 replicas) | `minAvailable: 1` (limited resources) |
| **Anti-Affinity** | `topologyKey: topology.kubernetes.io/zone` | `topologyKey: topology.kubernetes.io/zone` | `topologyKey: topology.kubernetes.io/zone` | `topologyKey: kubernetes.io/hostname` (nodes) + rack labels if available |
| **PriorityClass** | `system-cluster-critical` (add-ons), `high-priority` (workloads) | Same | Same | Same |
| **Node Autoscaling** | Cluster Autoscaler or KEDA | Cluster Autoscaler / Karpenter | GKE Autopilot / Cluster Autoscaler | Manual or custom autoscaler (Cluster API) |
| **etcd Quorum** | Managed by AKS | Managed by EKS | Managed by GKE | **3 or 5 members** (see §16.5.1) |

**Enforcement:** Kyverno/OPA policies validate PDBs and anti-affinity for critical workloads; CI checks block PRs missing these settings.

---

## 11) Multi-Tenancy Model

* **Isolation:** One namespace per team/app; default-deny; per-namespace RBAC bindings.
* **Quotas:** ResourceQuota + LimitRange per tenant; SLOs per service.
* **Access:** GitHub/AAD groups map to RBAC roles; break-glass documented.
* **Network:** Namespace-scoped ingress/egress; shared ingress with unique hostnames; shared observability with label-based dashboards.

### 11.7) Break-Glass Access (Emergency Admin)

**Purpose:** Controlled emergency access for critical incidents when normal RBAC is insufficient or compromised.

**Triggers:**
* Control plane failure (Argo CD/GitOps down, cannot sync changes).
* Identity provider outage (Azure AD/GitHub OIDC unavailable).
* Security incident requiring immediate isolation (compromised service account).

**Break-glass credentials:**
* **Storage:** Sealed in secure offline vault (password manager, HSM, physical safe); require 2-person retrieval.
* **Type:** Kubernetes ServiceAccount with `cluster-admin` role; **1-hour TTL** token (generated on-demand).
* **Access path:** Only from **dedicated bastion host** (IP allowlisted in API server `--authorization-webhook-config`).

**Activation procedure:**
1. Incident Commander declares break-glass necessity; logs reason in incident ticket.
2. Two authorized personnel retrieve sealed credentials from vault.
3. Generate short-lived token: `kubectl create token break-glass-admin --duration=1h`.
4. Connect via bastion host; perform emergency action; document all commands in incident log.
5. Revoke token immediately after use (or wait for 1h expiry).
6. Post-incident: Rotate break-glass SA; review audit logs; update runbooks.

**Audit trail:**
* All break-glass API calls logged to Kubernetes audit log + Loki (cannot be disabled).
* Alert fires on break-glass SA usage → escalates to security team + management.
* Monthly review: Verify no unauthorized break-glass usage; test retrieval procedure (dry-run).

### 11.5) Tenant Onboarding & Access Pattern (optional Azure DevOps alignment)

* **Identity source:** Enterprise IdP (Azure AD / Entra ID or GitHub) as the **single IdP** for both Git and Kubernetes (OIDC).
* **Group mapping:** `aad-group: platform-admins`, `team-<name>-maintainers`, `team-<name>-developers` → ClusterRoles via RBAC manifests in Git.
* **Namespace package:** A reusable Kustomize "tenant package" creates: namespace, LimitRange, ResourceQuota, NetworkPolicies (default-deny), RoleBindings, Grafana folder, Alertmanager route.
* **Azure DevOps optional:** Project bootstrap mirrors the above: repos with branch protection, service connections via OIDC, environments for Dev/Stage/Prod, and pipelines that **only** push digests & provenance (no direct kubectl).
* **Login model:** Human access via `kubelogin`/`kubectl oidc-login`; workload access via Workload Identity (IRSA/AAD WI/GKE WI) or Vault-JWT on-prem.

### 11.6) Tenant Offboarding & Deletion

**Purpose:** Define safe, auditable process for tenant removal with data retention compliance and resource cleanup.

#### 11.6.1) Offboarding Trigger Conditions

* Tenant project end-of-life (business decision).
* Compliance violation requiring immediate isolation.
* Non-payment or contract termination (commercial scenarios).
* Security incident requiring full tenant wipe.

#### 11.6.2) Pre-Deletion Checklist

* [ ] **Business approval:** Written confirmation from tenant owner + platform leadership.
* [ ] **Data retention review:** Verify compliance with GDPR/legal hold requirements (see §11.6.3).
* [ ] **Backup verification:** Ensure final Velero backup exists; test restore to ephemeral namespace.
* [ ] **Dependencies audit:** Check for cross-namespace dependencies (Service references, NetworkPolicies, shared ConfigMaps).
* [ ] **Notification:** 30-day advance notice to tenant (unless emergency); documented in ticket.

#### 11.6.3) Data Retention & Archival

* **Default retention:** **90 days** after offboarding approval (GDPR "right to be forgotten" compliant).
* **Extended retention:** Legal hold or audit requirements may extend to **7 years**; stored offline (encrypted object storage).
* **Archival process:**
  1. **Velero backup:** Final namespace backup with all PVCs, Secrets (encrypted), ConfigMaps.
  2. **Logs export:** Extract audit logs, application logs (Loki), and metrics (Prometheus snapshots) to cold storage.
  3. **SBOM snapshot:** Archive all image SBOMs for tenant workloads (compliance/forensics).
* **Access control:** Archived data accessible only to legal/compliance teams; MFA + audit trail required.

#### 11.6.4) Deletion Procedure (Phased)

**Phase 1: Isolation (Day 0)**
1. Revoke tenant RBAC (remove RoleBindings/ClusterRoleBindings).
2. Apply NetworkPolicy deny-all (block all ingress/egress).
3. Scale all Deployments/StatefulSets to **0 replicas** (preserve PVCs).
4. Disable Ingress (remove or comment out Ingress resources).
5. Revoke ExternalSecrets access (ESO stops syncing secrets).

**Phase 2: Resource Cleanup (Day 7-30, after retention period)**
1. Delete workloads: Deployments, StatefulSets, DaemonSets, Jobs, CronJobs.
2. Delete PVCs (after final backup verification); CSI driver handles PV deletion.
3. Delete Secrets, ConfigMaps (wiped from etcd via EncryptionConfiguration).
4. Delete NetworkPolicies, ResourceQuotas, LimitRanges.
5. Remove DNS records (ExternalDNS cleanup or manual).
6. Revoke cloud IAM roles (Workload Identity bindings).

**Phase 3: Namespace Deletion (Day 30+)**
1. Final verification: `kubectl get all,pvc,secrets -n <tenant-namespace>` returns empty.
2. Delete namespace: `kubectl delete namespace <tenant-namespace>`.
3. Verify etcd cleanup: Namespace tombstone removed after etcd compaction (see §16.5.4).

**Phase 4: Audit & Cleanup (Day 30+)**
1. Remove tenant from Grafana folders, Alertmanager routes.
2. Update RBAC Git manifests (remove tenant group mappings).
3. Close offboarding ticket with audit trail (who, when, what deleted, backup location).

#### 11.6.5) Emergency Wipe (Security Incident)

* **Trigger:** Confirmed compromise, malware, or data exfiltration.
* **Timeline:** **< 1 hour** from incident declaration to isolation.
* **Process:**
  1. Immediately apply Phase 1 (Isolation) via GitOps emergency PR (bypasses normal approval).
  2. Trigger forensic snapshot (see §39: Incident Response) before deletion.
  3. Notify security/legal teams; place tenant data under legal hold if required.
  4. Proceed with Phases 2-4 only after forensic review completion.

#### 11.6.6) Compliance & Audit Trail

* **Audit log:** All offboarding actions logged to centralized audit system (Loki + object storage).
* **Approval chain:** Ticket system (Jira/ServiceNow) tracks approvals, data retention decisions, deletion timeline.
* **Verification:** Quarterly audit reviews random offboarding cases; validates data wipe + retention compliance.
* **GDPR compliance:** "Right to be forgotten" requests processed within **30 days**; proof-of-deletion certificate issued.

---

## 12) Security Baseline (Fail-Closed)

* **Policy:** Kyverno/Gatekeeper enforce PSA restricted, signature verification (Cosign), no `:latest`, no root, no privileged, proper health probes, required labels/owners.
* **Supply chain:** Signed images, SBOM generation, Trivy/Grype scans in CI; block if critical CVEs without exception (see §31 for SLSA attestations).
* **Secrets:** ESO materialization; short TTL tokens; at-rest encryption via KMS or Vault; etcd encryption on self-managed control planes (see §16.5.3 for details).
* **Audit:** K8s audit policy enabled; logs shipped to Loki; change links back to Git commit.

### 12.1) Data Classification & Log Hygiene

**Data classification labels (mandatory on all resources):**
* `data-classification: public` — Public data, no restrictions.
* `data-classification: internal` — Internal business data, basic access control.
* `data-classification: confidential` — Sensitive data (PII, credentials), encryption + strict RBAC.
* `data-classification: restricted` — Highly sensitive (financial, health), compliance-required controls.

**Log redaction rules (enforced in Loki/Vector):**
* **Auto-redact:** Credit card numbers (regex), Social Security Numbers, API keys, passwords, tokens.
* **PII ban:** No names, emails, addresses in application logs; use correlation IDs instead.
* **Audit logs:** Do NOT redact (compliance requires full trail); separate retention (≥ 2 years).
* **Enforcement:** Loki LogQL queries block queries returning redacted fields; CI checks scan log statements for PII patterns.

**Log retention by class (consolidated):**

| Log Class | Retention (Prod) | Retention (Stage/Dev) | Storage Tier | Rationale |
|-----------|-----------------|----------------------|--------------|-----------|
| **Application Logs** | 30 days | 7 days | Hot (Loki) | Debugging, performance analysis |
| **Infrastructure Logs** (K8s events, CNI, CSI) | 30 days | 7 days | Hot (Loki) | Cluster troubleshooting |
| **Audit Logs** (K8s API, RBAC, policy) | **≥ 2 years** | 90 days | Cold (S3/Blob) | Compliance (ISO 27001, SOC 2, NIS2) |
| **Forensic/Incident Logs** | **≥ 2 years** (legal hold: 7 years) | N/A | WORM (immutable) | Evidence preservation, legal |
| **Metrics** (Prometheus) | 15 days | 7 days | Hot (TSDB) | SLO/SLI tracking |
| **Traces** (Tempo) | 3 days | 1 day | Hot | Performance profiling |

*Retention extends automatically during legal hold (see §39.5).*

---

## 13) Observability Baseline

* **Metrics:** kube-prometheus-stack (Prometheus, Alertmanager, Grafana).
* **Logs:** Loki (promtail/Vector).
* **Traces:** Tempo + OpenTelemetry Collector; W3C trace propagation.
* **Dashboards/Alerts:** Shared dashboards versioned in Git; Alertmanager routes per team; SLOs stored as code.

**Mandatory baseline dashboards (must exist in all environments):**
1. **SLO Burn Rate** - Multi-window burn rate alerts (1h/6h); error budget remaining; historical trends.
2. **Certificate Expiry** - All cert-manager certs grouped by namespace; alert < 14 days; renewal history.
3. **External Probe Health** - Synthetic monitoring results (§13.6); DNS/TLS/HTTP status per endpoint; P95 latency.

*These 3 dashboards are required for audits; templates versioned in `observability/dashboards/` in Git.*

### 13.5) SLOs, SLIs & Error Budgets (platform defaults)

* **APIs (Ingress path `/healthz`)**: **99.9%** monthly availability target; burn-rate alerts at 2%/1h and 5%/6h.
* **GitOps sync latency (P95)**: **≤ 2 min** from merge to applied in lower envs; **≤ 10 min** in prod windows.
* **Control-plane health**: `apiserver_request_total{code!~"5.."}` P99 error rate < **0.1%**.
* **Logging ingestion delay (P95)**: **≤ 30 sec**; Traces end-to-end **≤ 2 sec**.
* **DR objectives**: **RTO ≤ 60 min**, **RPO ≤ 15 min** for platform components.
  Numbers are defaults; teams may tighten.

### 13.6) External Synthetic Monitoring (Blackbox)

**Purpose:** Validate platform reachability from **outside** the cluster (detect DNS/TLS/network failures invisible to internal monitoring).

**Tools:** Prometheus Blackbox Exporter (external VM/VPS) or cloud-native (Azure Monitor, AWS CloudWatch Synthetics, Datadog).

**Checks (every 1-5 min):**
* **DNS resolution:** Resolve ingress FQDNs (app.example.com) via public DNS; alert if NXDOMAIN or timeout.
* **TLS certificate validity:** Probe HTTPS endpoints; alert if cert expires < 14 days or chain invalid.
* **HTTP availability:** GET `/healthz` or app root; expect 200; alert if ≥ 3 consecutive failures.
* **Latency thresholds:** P95 response time ≤ 500ms; alert if exceeded.

**Alarm chaining:** External synthetic failure → escalates to SEV-2 if internal monitoring shows healthy (indicates DNS/LB/WAF issue).

---

## 14) Backup & Disaster Recovery

* **Velero:** Schedules + on-demand; include CRDs/cluster scope; object storage backend (S3/Azure/GS/MinIO).
* **Keys:** Offsite storage of CA/KMS keys and Argo CD admin recovery; document restoration steps.
* **Drills:** Monthly smoke (1 namespace); quarterly full app restore; record RPO/RTO results.
* **etcd backups:** For self-managed clusters, see §16.5.6 for etcd snapshot procedures.

---

## 15) DNS, TLS & Certificates

* **DNS:** ExternalDNS manages A/AAAA/CNAME; cloud credentials only differ per overlay.
* **TLS:** cert-manager with `ClusterIssuer` names **identical** across environments (e.g., `letsencrypt-staging`, `letsencrypt-prod`).
* **ACME:** HTTP-01 via shared ingress; fallback to DNS-01 when required (wildcards/private).

---

## 16) Storage Strategy

* **Naming:** `StorageClass` **`standard`** everywhere; overlays bind to provider-specific CSIs.
* **On-Prem:** Prefer **Longhorn** for simplicity or **Rook-Ceph** for HA/scale; document failure domains & replication.
* **Snapshots:** CSI VolumeSnapshotClass defined & tested; app-aware DB backups separate from PVC snapshots.
* **Encryption:** At-rest encryption via cloud KMS or LUKS; for etcd-specific encryption see §16.5.3.

---

## 16.5) etcd Management (Self-Managed Clusters Only)

**Scope:** Applies to **on-prem kubeadm/RKE2** clusters. Managed cloud (AKS/EKS/GKE) owns etcd lifecycle; do **not** modify it.

**Why it matters:** etcd is the single source of truth for cluster state. Data loss or corruption equals **full control-plane outage** and potential **tenant data exposure**. Treat it as Tier-0.

### 16.5.1 Topology & Sizing

* **Topology choices**

  * **Stacked control-plane (default kubeadm):** etcd runs as a static pod on control-plane nodes. *Pros:* simpler ops. *Cons:* failure domains coupled; watch I/O contention.
  * **External etcd cluster:** dedicated nodes/VMs. *Pros:* isolation, independent lifecycle, better for large clusters/strict compliance. *Cons:* more components to manage.
* **HA quorum:** Use **3** members (tolerates 1 failure) or **5** (tolerates 2). Never even numbers.
* **Hardware (per etcd node):** **2 vCPU, 8 GB RAM**, **NVMe/SSD** with stable low-latency fsync (≈≥3000 IOPS), **dedicated disk** (separate from kubelet workloads).
* **Network:** Inter-member latency **< 10 ms p99**; avoid WAN links or unstable networks.

### 16.5.2 Versioning & Lifecycle

* **Version pinning:** Keep etcd aligned with the Kubernetes minor version supported by kubeadm/RKE2; do **not** skip minors.
* **Rolling upgrades:**

  1. Take a verified snapshot.
  2. Upgrade **one member at a time**.
  3. After finishing, **defragment** and clear alarms.
* **Downgrades:** Not supported across arbitrary minors; use **restore from snapshot** runbook if rollback is required.

### 16.5.3 Security (mTLS, Encryption, Access)

* **mTLS required** on **client (2379)** and **peer (2380)** ports; prefer a **dedicated etcd CA**. SANs must include node FQDNs and IPs.
* **Certificate rotation:** Automate and rotate ≤ **90 days**; stagger per member to preserve quorum.
* **Kubernetes Secrets encryption:** Enable **EncryptionConfiguration** for Secrets at rest (encrypts Secret values in etcd); reference: §12 Security Baseline for ESO + KMS integration.
* **Disk encryption:** Also enable **disk encryption** (LUKS or cloud-provider disk encryption) for defense-in-depth.
* **Access control:** Limit shell access; run `etcdctl` only from a bastion using short-lived credentials; audit every admin command.

### 16.5.4 Storage, Compaction & Defragmentation

* **Filesystem:** ext4 or XFS with `noatime`; **swap disabled** on hosts.
* **Quota:** Set `--quota-backend-bytes` to **8–16 GiB** (medium clusters). Page at **≥70%** utilization.
* **Auto-compaction:** Enable periodic revision compaction (e.g., every **5 minutes**).
* **Defragmentation:** Schedule **weekly** defrag (or when DB size > 70% of quota). Defrag **one member at a time**, validate cluster health between steps.
* **WAL/log dir:** Place WAL on the fastest disk (ideally dedicated NVMe) for stable fsync.

### 16.5.5 Monitoring & Alerting (minimum)

Track in Prometheus and alert on:

* `etcd_server_has_leader == 0` — **critical** (page immediately).
* Spikes in `etcd_server_leader_changes_seen_total` — consensus instability.
* `etcd_disk_wal_fsync_duration_seconds{quantile="0.99"} > 0.025` — disk I/O problems.
* `etcd_mvcc_db_total_size_in_bytes / quota-backend-bytes > 0.8` — NOSPACE risk.
* Rising `etcd_server_proposals_failed_total` — write/consensus failures.
* Abnormal drops in gRPC traffic (received/sent bytes) — stalls.

**Dashboard:** Grafana panel with leader status, peer latency, DB size, defrag history, fsync p99, active alarms — versioned in Git.

### 16.5.6 Backup & Restore (Runbooks)

**Backups**

1. `etcdctl snapshot save /backup/etcd-$(date +%F-%H%M).db` with proper mTLS env vars.
2. Verify via `etcdctl snapshot status`; checksum; encrypt at rest; ship to offsite object storage (S3/MinIO/Azure Blob).
3. **Retention:** ≥ **7 days** (align to RPO). Keep ≥ **3** generations across failure domains.

**Restore — stacked control-plane (kubeadm)**

1. Safe-stop API server (cordon/drain control-plane node if needed).
2. `etcdctl snapshot restore` **to a new data dir**; update static pod at `/etc/kubernetes/manifests/etcd.yaml` (new data dir and **new cluster-token**).
3. Start etcd; verify `etcdctl endpoint status/health`.
4. Start API server; confirm overall cluster readiness.

**Restore — external etcd**

1. Stop etcd on target member; restore into a new dir; update systemd unit or static-pod manifest.
2. Rejoin members sequentially; wait for stable leader between steps.

**Drill policy:** **Quarterly full restore** in Stage (API served by restored etcd) **plus** **monthly smoke** (snapshot + status verification). Record and review **RTO/RPO** results.

### 16.5.7 Failure Testing & Quorum Hygiene

* Intentionally stop one member to validate alerting and quorum behavior.
* Simulate disk-full to exercise NOSPACE handling, compaction, and defrag runbooks.
* Inject controlled network delay to validate peer-latency alerts.

### 16.5.8 Recommended Defaults (quick reference)

| Setting                 | Recommended                  | Rationale                       |
| ----------------------- | ---------------------------- | ------------------------------- |
| Members                 | 3 (small/medium) / 5 (large) | Quorum tolerance to failures    |
| `--quota-backend-bytes` | 8–16 GiB                     | Avoid NOSPACE; allow headroom   |
| Auto-compaction         | Every 5 min                  | Limits historical revisions     |
| Defrag cadence          | Weekly or >70% DB size       | Reclaims space; stabilizes perf |
| WAL location            | Dedicated SSD/NVMe           | Low fsync latency               |
| Cert rotation           | ≤ 90 days                    | Crypto hygiene                  |
| Snapshot cadence        | Every 6–12 h                 | Meets common RPOs               |
| Leader loss alert       | Immediate page               | Prevents full outage            |

**Don’ts**

* Don’t run a **single etcd node** in production.
* Don’t place etcd on bursty/shared disks without IOPS guarantees.
* Don’t co-locate heavy I/O workloads on etcd hosts; taint nodes if stacked.
* Don’t skip restore drills — untested backups are not backups.

---

## 17) GitOps & Argo CD Pattern

* **Root app:** App-of-apps points to overlay root; sync waves order CRDs → operators → add-ons → tenants.
* **Policies:** Argo projects per tenant; deny cross-namespace references; read-only to cluster-scoped resources unless approved.
* **Sync:** Auto-sync enabled in lower envs; manual sync with PR approval in prod; health & sync windows defined.
* **Drift:** Alert on drift; block manual changes in prod.

---

## 18) Promotion & Releases

* **Flow:** Dev → Stage → Prod via PRs (image digest bumps only).
* **Strategies:** Blue/Green or Canary (via ingress or Service mesh if adopted).
* **Freeze:** Change freeze windows around critical business dates.
* **Rollback:** Declarative rollbacks via Git revert; DNS toggle for Blue/Green.

**Multi-arch promotion:**
* Images promoted by **digest** (e.g., `sha256:abc123...`) to ensure identical manifest across environments.
* Prevents arch-specific bugs (AMD workload scheduled on ARM node or vice versa).
* CI verifies manifest includes both `linux/amd64` and `linux/arm64` before promotion approval.

### 18.1) Change-Management Gates (required checks before Prod)

* **Policy bundle pass:** PSA restricted, Kyverno/Gatekeeper constraints, default-deny NP tests.
* **Signature + provenance:** `cosign verify` **and** `verify-attestation` (SLSA provenance present; see §31 for SLSA details).
* **Vulnerability budget:** No **Critical** CVEs; **High** CVEs must have approved exceptions w/ expiry.
* **Conformance tests green:** §34 suite (ingress, PVC, ESO, policies, DR smoke) passed in Stage within last 24h.
* **SLO impact check:** No open P1 incidents; error-budget not exhausted (see §13.5 for SLO definitions).

**Policy tests as code:**
* **Tools:** `kyverno-cli test` or `gator test` (OPA Gatekeeper) + `kuttl` for integration tests.
* **Location:** `tests/policy/` in Git repository.
* **Coverage:** Positive cases (valid workloads pass) + negative cases (invalid workloads blocked: unsigned image, runAsRoot, missing probes).
* **CI integration:** Policy tests run on every PR; block merge if any test fails.

---

## 19) Upgrade Runbook (K8s & Add-ons)

1. Review upstream change logs; update ADR if breaking changes.
2. Bump versions in a **stage** branch; CI runs conformance & policy tests.
3. Deploy to **kind** + **Stage**; execute synthetic checks & chaos tests (optional).
4. Announce maintenance window; backup etcd (self-managed) & Velero preflight; freeze non-essential changes.
5. Upgrade prod in waves (CRDs first, then operators, then components); verify health & SLOs.
6. Post-upgrade validation; unfreeze; publish release notes.

---

## 20) Pre-Flight Checklist (before first apply)

* [ ] CIDR plan (Pod/Service/VNet/VPC) approved; no corporate collisions.
* [ ] DNS zones & ACME challenge path specified.
* [ ] Storage strategy (SC name, driver) confirmed.
* [ ] Registry choice & credentials prepared; image signing keys ready.
* [ ] Secret backends & ESO providers permissioned.
* [ ] Observability targets & alert routes defined.
* [ ] Velero backend (bucket/MinIO) available; access verified.
* [ ] GitOps bootstrap repo with branch protection & CI OIDC ready.
* [ ] Policy set (Kyverno/OPA) tested; admission fail-closed.
* [ ] Runbooks, break-glass accounts, and audit policy documented.

---

## 21) Go-Live Checklist (per environment)

* [ ] Argo CD synced, **drift = 0**; all add-ons **Ready**.
* [ ] Ingress reachable; DNS records correct; **TLS green**.
* [ ] NetworkPolicies enforced (positive/negative tests).
* [ ] Storage PVC lifecycle & snapshots validated.
* [ ] ESO secrets materialize & rotate.
* [ ] Observability dashboards & alerts live; test alerts received.
* [ ] Velero restore **passed** (smoke).
* [ ] SLO dashboards live; on-call informed; freeze window set.
* [ ] Backout plan rehearsed.

---

## 22) Weekly Ops Routine (short)

* [ ] Review pending updates (cluster/add-ons).
* [ ] Triage vulnerabilities (images/nodes).
* [ ] Inspect cost drivers (LBs/disks/logs).
* [ ] Perform a Velero restore smoke (1 namespace).
* [ ] Resolve policy violations/drift.

---

## 23) Anti-Patterns (Red Card)

* Cloud annotations or provider SC names in app charts.
* `kubectl apply` to production from laptops.
* Secrets/keys in Git or Terraform state.
* Mutable tags (`:latest`) or unsigned images.
* Missing default-deny or weak RBAC.
* Backups without restore drills.
* Inconsistent names (Issuer/Ingress/SC) across environments.
* Parallel click-ops alongside Terraform/GitOps.

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
* **CSI drivers:** Azure Disk/Files, EBS/EFS, GCE-PD/Filestore vs. Longhorn/Ceph.
* **Workload identity:** AAD WI / IRSA / GKE WI vs. Vault-JWT.

> **Everything else stays constant** (ingress class name, storage class name, issuer names, RBAC patterns, observability stack, policy sets).

---

## 26) Example Test Scenarios (Portability Contracts)

* Deploy a reference app with: Ingress (host), PVC (`standard`), Secret (ESO), ConfigMap, HPA.
* Negative admission tests: unsigned image, `runAsRoot`, missing probes, `:latest`.
* Network tests: namespace default-deny, allow only needed egress (DNS, registry).
* DR test: backup+restore of app namespace; assert identical DNS/TLS post-restore.

---

## 27) Governance & Process

* **Change management:** PR templates require risk, rollback & observability notes.
* **Approvals:** Two-person rule for prod changes; security review for policy relaxations.
* **Exceptions:** Time-bound with expiry; tracked in Git; alert on expiry.
* **Audits:** Quarterly review of RBAC, policies, and DR results.

### 27.1) Change Process RACI

| Role | Change Types | Responsibilities |
|------|-------------|------------------|
| **Developer** | App manifests (base/overlays) | Submits PR; writes tests; validates in Dev/Stage |
| **Platform SRE** | Add-on upgrades, infra changes | Reviews changes; approves infra PRs; executes deployments |
| **Security Team** | Policy changes, RBAC, secret configs | Mandatory review for security-critical changes; approves/rejects |
| **Change Approver (CAB)** | Production changes (normal) | Final approval for Prod PRs (two-person rule) |
| **Incident Commander** | Emergency fast-track | Can bypass CAB for SEV-1/2 incidents; audit trail required |

### 27.2) Emergency Fast-Track (Bypass)

* **Trigger:** SEV-1 incident requiring immediate hotfix (control plane down, active breach).
* **Process:**
  1. Incident Commander declares emergency; opens fast-track PR with `[EMERGENCY]` tag.
  2. Single approver sufficient (normal: two-person rule); security team notified async.
  3. Deploy directly to Prod via Argo CD sync (skip Dev/Stage soak).
  4. **Post-incident:** Mandatory postmortem (§39.3); retroactive CAB review within 24h; update runbooks.
* **Audit trail:** All fast-track changes logged to compliance system; monthly report to leadership.
* **Limits:** ≤ 2 fast-tracks/month acceptable; > 2 triggers process review (too many emergencies = broken process).

### 27.3) Compliance Control Mapping

| Framework | Control | Addressed in Section | Notes |
|-----------|---------|---------------------|-------|
| **ISO 27001** | A.9.4.1 (Access Control) | §11, §12 (RBAC, Workload Identity) | Least-privilege RBAC per tenant |
| **ISO 27001** | A.12.3.1 (Backup) | §14 (Velero, etcd snapshots) | Quarterly restore drills |
| **ISO 27001** | A.12.6.1 (Audit Logs) | §12 (K8s audit policy, Loki) | Centralized audit logs, 90d retention |
| **ISO 27001** | A.14.2.5 (Secure Development) | §31, §38 (SLSA, Cosign signatures) | Signed images, SBOM, CVE gates |
| **NIS2** | Art. 21 (Incident Reporting) | §39 (Incident Response, <72h) | SEV-1/2 incidents escalated, postmortems |
| **NIS2** | Art. 21 (Supply Chain) | §31, §38 (SLSA, Key Management) | Provenance attestations, SBOM retention |
| **SOC 2** | CC6.1 (Logical Access) | §11.5, §12 (OIDC, MFA, RBAC) | Azure AD/GitHub OIDC, break-glass documented |
| **SOC 2** | CC7.2 (Change Management) | §27 (PR reviews, CAB, audit trail) | Two-person rule, Git history as audit |
| **SOC 2** | CC8.1 (Risk Assessment) | §30 (Threat Model, Risk Register) | Quarterly risk review, tracked in Git |
| **PCI-DSS** | Req 2 (Secure Defaults) | §12 (PSA restricted, default-deny) | No privileged containers, network isolation |
| **PCI-DSS** | Req 10 (Audit Trails) | §12, §39 (Audit logs, forensics) | All access logged, WORM storage for incidents |

*This mapping is reviewed during annual audits; update as controls evolve.*

---

## 28) Readiness to Scale (Future Architecture Considerations)

* **Gateway API** to replace classic Ingress incrementally.
* **Cilium** with eBPF for advanced networking & policy; cluster mesh if multi-cluster becomes required.
* **Fleet management** (Argo CD + Projects or Rancher) for multi-cluster scenarios.
* **SPIFFE/SPIRE** for workload identity hardening if compliance demands it.

---

## 29) Conclusion

This document provides **decision-grade guardrails** that keep the platform portable, secure, and reproducible. If followed, it will **lead directly to the stated goal**: a platform you can bring up on any on-prem Linux machine **and** any major cloud (AKS/EKS/GKE) from the **same Git repository**, with identical application manifests and **no manual clicks** to production.

> **Action:** Implement the repo skeleton, bootstrap Terraform + Argo CD, and enforce the policies as code. Keep this document updated via PRs as architectural decisions evolve.

---

## 30) Threat Model (STRIDE-Lite) & Risk Register

**Assets:** cluster control plane, tenant namespaces, images & SBOMs, secrets/KMS keys, Git history, CI credentials, object storage (Velero).
**Trust boundaries:** developer → Git; CI → registry; Argo CD → cluster; ESO → secret store; users → ingress.

| Risk                       | Scenario                            | Control (this doc)                                                           | Owner        |
| -------------------------- | ----------------------------------- | ---------------------------------------------------------------------------- | ------------ |
| R1: Supply-chain tampering | Malicious image or pipeline step    | Cosign + SLSA provenance (§31); verify-attestation; PR reviews; policy fail-closed | Platform Sec |
| R2: Secret exfiltration    | Misconfigured RBAC or logs          | Least-privilege RBAC; default-deny; ESO (§12); audit policy; PII ban in logs       | Platform Sec |
| R3: Data loss              | etcd/PV corruption                  | Velero (§14) + etcd snapshots (§16.5.6); tested restores; RPO/RTO; runbooks                  | SRE          |
| R4: Config drift           | Manual kubectl/portal changes       | GitOps only (§17); drift alerts; deny changes in prod                              | Platform Eng |
| R5: Lateral movement       | Network open by default             | Namespace default-deny (§9); egress allowlists; CNI policy                        | Platform Sec |
| R6: Key/Cert expiry        | Certificates/tokens expire silently | Rotation ≤90d (§16.5.3); alerting on expiry; runbooks                                  | SRE          |

*Maintain this table in Git; review quarterly.*

---

## 31) Supply-Chain Attestations & SLSA

* **Current baseline:** SLSA **Level 2** (signed provenance, isolated builds).
* **Provenance:** Build systems emit SLSA provenance (builder, source, digest, dependencies).
* **Admission:** Policies require **both** `cosign verify` and `cosign verify-attestation --type slsaprovenance`.
* **Artifacts:** Store SBOMs (SPDX/CycloneDX) alongside images; gate on vulnerable components per policy.

---

## 32) Node OS Baseline & CIS Controls

* **Supported OS images:** Ubuntu LTS 22.04/24.04 or RHEL 9.x, containerd.
* **Hardening:** CIS Kubernetes & OS baselines; disable swap; strict sysctls; kubelet readonly port off; TLS everywhere.
* **Patching:** Monthly OS patch windows; emergency out-of-band for critical CVEs; drift tracked in Git.
* **Access:** SSH disabled or via bastion; auditd enabled; sudoers minimal.

---

## 33) Air-Gapped Mode & Private PKI

* **Registry mirror:** Harbor (images + signatures + provenance).
* **Chart/OCI mirror:** Internal artifact store; periodic sync from upstream.
* **DNS & ACME:** Internal DNS; cert-manager with **private CA** (Vault or step-ca); see §36 for mTLS configuration.
* **ExternalDNS:** Disabled or internal provider only.
* **Outbound policy:** Deny egress by default; whitelists for mirrors only.

---

## 34) Platform Conformance Tests

* **Tools:** kuttl/sonobuoy + custom probes.
* **Scope:** Ingress reachability, TLS cert issuance, PVC bind/snapshot/restore, ESO secret materialization, policy negatives, DR smoke (see §14 for DR procedures).
* **Gating:** Required green in Stage before Prod (see §18.1 for change gates).
* **Frequency:** On every chart bump; nightly in Stage.

---

## 35) Cost & Sizing Guardrails

* **Node shapes (minimum):** 2 vCPU/8 GB for worker; 2 vCPU/8 GB for control-plane (self-managed).
* **Retention defaults:** Logs 30d (prod)/7d (stage); Traces 3d; Metrics 15d.
* **Autoscaling:** Enable HPA; conservative VPA; spot/preemptible for stateless.
* **Budgets:** Alert on monthly spend growth > 20% or per-tenant cost > agreed SLO.

### 35.1) FinOps Chargeback/Showback Schema

**Cost allocation via labels:**
* `cost-center: <code>` — Maps to organizational cost center (mandatory for all namespaces/workloads).
* `team: <name>` — Team owner (used for showback reports).
* `project: <id>` — Project code (correlates to budget).
* `environment: dev|stage|prod` — Cost segregation by environment.

**Chargeback workflow:**
1. Cloud provider cost export (Azure Cost Management, AWS Cost Explorer, GCP Billing) → BigQuery/Data Lake.
2. Kubernetes resource metrics (CPU/RAM requests, PVC size) → Prometheus → aggregated by labels.
3. Join cloud costs + K8s metrics → cost-per-label report (monthly).
4. Publish to finance dashboard (Power BI, Grafana); send invoices to cost-center owners.

**Standard FinOps KPIs:**
* **Cost per namespace:** Total cloud + licensing costs divided by namespaces.
* **Resource efficiency:** Actual usage / requested resources (target: ≥ 70% for prod workloads).
* **Waste index:** Idle resources (pods scaled to 0, orphaned PVCs/LBs) as % of total spend (target: < 5%).

**Rightsizing loop:**
1. VPA recommender runs weekly; suggests new requests/limits based on P95 usage.
2. Platform team reviews recommendations; opens PRs to adjust tenant quotas.
3. HPA/VPA signals fed back to cost dashboard; track savings from rightsizing.

---

## 36) Private PKI & mTLS Option

* For internal services or regulated tenants, enable platform-wide **mTLS** using mesh (optional) or Gateway API + cert-manager Issuers backed by Vault/step-ca.
* Maintain separate **public** (Let's Encrypt, §15) and **private** (internal CA) Issuers; names consistent across environments.
* For air-gapped deployments, see §33 for private CA configuration.

---

## 37) Version & Support Policy

**Purpose:** Define supported component versions, upgrade cadence, End-of-Life handling, and compatibility matrix to ensure predictable platform lifecycle management.

### 37.1) Supported Component Versions

| Component | Supported Versions | Support Duration | Upgrade Cadence | Notes |
|-----------|-------------------|------------------|-----------------|-------|
| **Kubernetes** | N, N-1, N-2 (latest 3 minors) | ~14 months per minor | Quarterly (within 60 days of upstream release) | Align with CNCF support window |
| **Argo CD** | Latest stable + previous minor | ~6 months per minor | Bi-annually or as needed | Pin to stable releases only |
| **cert-manager** | Latest stable (v1.x series) | Until v2.x stable | Annually or security-driven | Monitor CRD API changes |
| **ingress-nginx** | Latest stable (v1.x series) | ~12 months per minor | Semi-annually | Test canary deployments first |
| **Kyverno/OPA** | Latest stable | ~6 months per minor | As needed (policy-driven) | Validate policy compatibility |
| **Velero** | Latest stable + previous minor | ~6 months per minor | Annually or DR-test-driven | Backup compatibility critical |
| **kube-prometheus-stack** | Latest stable (aligned with K8s) | Matches K8s support | Quarterly with K8s upgrades | CRD compatibility with K8s |
| **Loki** | Latest stable (v2.x or v3.x) | ~12 months per major | Annually | Storage schema migrations require planning |
| **Longhorn/Rook-Ceph** | Latest stable | ~12 months per minor | Annually | On-prem only; test PVC migrations |
| **MetalLB** | Latest stable | ~12 months per minor | Annually | On-prem only; BGP config stability |

### 37.2) Kubernetes Version Support & EoL

* **Support window:** Latest **3 Kubernetes minors** (N, N-1, N-2).
* **Upgrade timeline:**
  * **Dev/Stage:** Within **30 days** of upstream stable release.
  * **Production:** Within **60 days** after Dev/Stage validation.
* **EoL handling:**
  * **90 days before EoL:** Alert via dashboards; open upgrade ADR.
  * **60 days before EoL:** Freeze new workloads on EoL version.
  * **30 days before EoL:** Mandatory upgrade (block deployments if not upgraded).
* **Emergency patches:** Critical CVEs (CVSS ≥ 9.0) trigger out-of-band upgrades within **7 days**.

### 37.3) Add-on Compatibility Matrix

| Kubernetes Version | Argo CD | cert-manager | ingress-nginx | Kyverno | Velero | Notes |
|-------------------|---------|--------------|---------------|---------|--------|-------|
| **1.30.x** | v2.12+ | v1.15+ | v1.11+ | v1.12+ | v1.14+ | Current stable |
| **1.29.x** | v2.10+ | v1.14+ | v1.10+ | v1.11+ | v1.13+ | Supported |
| **1.28.x** | v2.9+ | v1.13+ | v1.9+ | v1.10+ | v1.12+ | Near EoL |

*This matrix is maintained in Git; update quarterly or when major version bumps occur.*

### 37.4) CNI & CSI Driver Support

| Provider | CNI | CNI Version | CSI Driver | CSI Version | Support |
|----------|-----|-------------|------------|-------------|---------|
| **AKS** | Azure CNI | Managed by AKS | Azure Disk/Files CSI | v1.30+ | Cloud-managed |
| **EKS** | VPC CNI | Managed by EKS | EBS/EFS CSI | v1.33+/v2.0+ | Cloud-managed |
| **GKE** | Dataplane V2 | Managed by GKE | GCE-PD/Filestore CSI | v1.14+ | Cloud-managed |
| **On-Prem** | Cilium v1.16+ or Calico v3.28+ | Self-managed | Longhorn v1.7+ / Rook-Ceph v1.14+ | Self-managed | Pin versions in overlay |

### 37.5) Upgrade Governance Process

1. **Upstream monitoring:** Subscribe to CNCF/vendor security lists; track CVEs via Dependabot/Renovate.
2. **Quarterly reviews:** Platform team reviews supported versions; flags EoL candidates.
3. **ADR requirement:** Major version bumps (K8s minor, Argo CD major) require Architecture Decision Record.
4. **Staged rollout:** Dev → Stage → Prod (min 7 days soak per environment).
5. **Rollback criteria:** Health check failures or SLO breach (>10% error budget burn) → immediate rollback.
6. **Documentation:** Update §19 (Upgrade Runbook) and this section after each major upgrade.

### 37.6) End-of-Support Enforcement

* **Automated checks:** CI/CD pipelines **block** deployments to clusters running **EoL Kubernetes versions** (N-3 or older).
* **Dashboard visibility:** Grafana panel shows days-until-EoL for all clusters and add-ons.
* **Executive reporting:** Monthly report to platform leadership on version compliance and pending upgrades.

---

## 38) Root of Trust & Key Management

**Purpose:** Define cryptographic key strategy for image signing, attestation verification, and supply-chain trust anchors. Ensures consistent key lifecycle across environments.

### 38.1) Cosign Key Strategy

| Scenario | Key Type | Storage | Rotation | Use Case |
|----------|----------|---------|----------|----------|
| **Dev/Stage** | **Keyless (OIDC)** | GitHub/GitLab OIDC token | N/A (ephemeral) | CI signatures via Fulcio/Rekor; no key management |
| **Production (Cloud)** | **KMS-backed** | Azure Key Vault / AWS KMS / Google Secret Manager | ≤ 90 days | Long-lived keys with HSM backing; manual rotation |
| **Production (On-Prem)** | **Vault-backed** | HashiCorp Vault (Transit Engine) | ≤ 90 days | Self-hosted HSM or software keys; automated rotation |
| **Air-Gapped** | **Offline keys** | Hardware Security Module (HSM) | ≤ 90 days | Isolated signing; TUF/Rekor mirror for transparency |

**Default choice:** Start with **keyless OIDC** (Fulcio + Rekor) for simplicity; migrate to **KMS/Vault** when compliance requires long-lived keys.

### 38.2) Key Rotation & Lifecycle

* **Rotation cadence:** ≤ **90 days** for all long-lived keys (KMS/Vault/HSM).
* **Rotation process:**
  1. Generate new key in KMS/Vault; retain old key for **grace period** (30 days).
  2. Sign new images with new key; verify old signatures during grace period.
  3. Update Kyverno/OPA policies to accept **both** old + new public keys.
  4. After grace period: revoke old key; remove from policy.
* **Emergency rotation:** Compromised keys rotated within **24 hours**; incident response triggered (see §39).
* **Audit trail:** All key operations (creation, rotation, revocation) logged to centralized audit system (Loki).

### 38.3) Transparency Logs (Rekor/TUF)

* **Public Rekor (Sigstore):** Used for keyless OIDC signatures; public transparency log.
* **Private Rekor instance:** Required for **air-gapped** or **regulated** environments; self-hosted with backup.
* **TUF (The Update Framework):** Mirror TUF metadata for air-gapped environments; validate package integrity.
* **Retention:** Rekor entries retained for **≥ 1 year** (compliance-dependent); backed up offsite.

### 38.4) SBOM Storage & Retention

* **Format:** **CycloneDX** (preferred) or **SPDX**; stored as OCI artifacts alongside images.
* **Storage location:**
  * **Cloud:** OCI registry (ACR/ECR/GAR/GHCR) with SBOM media type.
  * **On-Prem:** Harbor registry with SBOM support enabled.
* **Retention policy:**
  * **Active images:** SBOM retained as long as image is in use + **90 days**.
  * **Archived images:** SBOM retained for **≥ 2 years** (audit/compliance).
  * **Vulnerability updates:** SBOMs re-scanned weekly; CVE metadata appended.
* **Access control:** SBOMs readable by security/audit teams; encrypted at rest.

### 38.5) Vulnerability & Risk Acceptance Process

* **Baseline:** **Block Critical CVEs**; **High CVEs** require time-bound exception (≤ 90 days).
* **Risk acceptance workflow:**
  1. Developer/team submits exception request via PR (template in Git).
  2. Exception includes: CVE ID, affected component, business justification, compensating controls, expiry date.
  3. Security team reviews; approves/rejects via PR review.
  4. Approved exceptions stored as policy annotations (Kyverno/OPA); alert on expiry.
* **Re-validation:** Expired exceptions **auto-block** deployments; require renewal or remediation.
* **Audit:** Quarterly review of all active exceptions; revoke if no longer justified.

### 38.6) Key Distribution & Trust Anchors

* **Public keys:** Stored in Git (`trust-anchors/` directory); protected by branch protection + required reviews.
* **Kubernetes integration:** Public keys materialized as ConfigMaps/Secrets via Kustomize overlays.
* **Policy enforcement:** Kyverno/OPA Gatekeeper policies reference ConfigMaps; verify image signatures on admission.
* **Trust rotation:** New public keys deployed **before** old keys revoked (overlap period ensures zero downtime).

### 38.7) Air-Gapped Mirror Strategy

* **Rekor mirror:** Self-hosted Rekor instance; periodic sync from public Sigstore (if connected).
* **TUF mirror:** Local TUF repository mirroring upstream package metadata; validates integrity.
* **Key escrow:** Offline HSM stores root keys; intermediate keys in Vault for daily operations.
* **Sync cadence:** Weekly sync of transparency logs and metadata when air-gap permits (sneakernet or controlled connection).

### 38.8) SBOM & Attestation Visibility (Workload Trust Dashboard)

**Purpose:** Provide real-time visibility into image trust posture for security teams and auditors.

**Implementation:**
* **Grafana dashboard tile:** "Image Trust Status" per namespace/workload.
* **Portal/UI integration:** Custom Kubernetes dashboard (e.g., K9s plugin, Lens extension, web UI) showing:
  * ✅ **Signature verified** (Cosign signature valid, public key matches).
  * ✅ **Provenance present** (SLSA attestation found, builder identity confirmed).
  * ✅ **CVE scan recent** (last scan < 7 days; no Critical CVEs).
  * ⚠️ **Warning states:** Signature missing, provenance outdated, High CVEs present.
  * ❌ **Blocked:** Critical CVE or policy violation.

**Data source:** Query Kubernetes admission logs (Kyverno/OPA decisions) + container registry metadata (SBOM, scan results) via API.

**Alerting:** Fire alert if > 5% of workloads in namespace show trust warnings; escalate to security team.

**Don'ts:**
* Don't store private keys in Git, Terraform state, or Kubernetes Secrets (use KMS/Vault).
* Don't skip grace periods during key rotation (causes signature verification failures).
* Don't allow unsigned images in production (enforce via admission policy).
* Don't ignore SBOM retention policies (audit/compliance violations).

---

## 39) Incident Response & Forensics

**Purpose:** Define severity levels, response timelines, evidence preservation procedures, and roles for handling security incidents and platform outages.

### 39.1) Severity Levels & Definitions

| SEV | Definition | Examples | Initial Response Time | MTTA Target | MTTR Target |
|-----|------------|----------|----------------------|-------------|-------------|
| **SEV-1 (Critical)** | Total platform outage or active security breach | Control plane down; data exfiltration; ransomware; all tenants offline | **< 15 min** | **< 30 min** | **< 4 hours** |
| **SEV-2 (High)** | Major degradation or security vulnerability | Single AZ failure; etcd member down; CVE CVSS ≥ 9.0 exploit active | **< 30 min** | **< 1 hour** | **< 8 hours** |
| **SEV-3 (Medium)** | Partial service impact or elevated risk | Ingress intermittent; DNS delays; non-exploited CVE CVSS ≥ 7.0 | **< 2 hours** | **< 4 hours** | **< 24 hours** |
| **SEV-4 (Low)** | Minor issue or informational alert | Single pod crash-looping; metrics gap; config drift detected | **< 8 hours** | **< 24 hours** | **< 7 days** |

* **MTTA (Mean Time to Acknowledge):** Time from alert to incident declared + responder assigned.
* **MTTR (Mean Time to Recover):** Time from incident declaration to service fully restored.

### 39.2) Incident Response RACI

| Role | Responsibility | SEV-1/2 Involvement | SEV-3/4 Involvement |
|------|----------------|---------------------|---------------------|
| **Incident Commander (IC)** | Declares severity; coordinates response; authorizes changes; communicates status | Mandatory (on-call rotation) | As needed |
| **Platform SRE** | Triages alerts; executes runbooks; gathers diagnostics; implements fixes | Primary responder | Primary responder |
| **Security Team** | Analyzes security incidents; preserves evidence; coordinates forensics; liaises with legal | Mandatory for security incidents | Consulted if security-related |
| **Application Teams** | Provides app-specific context; tests fixes; validates recovery | Consulted if tenant-specific | Informed via status page |
| **Management/CTO** | Approves major decisions (emergency changes, customer comms, legal actions) | Informed within 1 hour (SEV-1) | Informed via weekly report |

### 39.3) Incident Response Workflow

**Phase 1: Detection & Triage (0-15 min)**
1. **Alert fires:** Prometheus/Alertmanager → PagerDuty/Opsgenie → On-call SRE paged.
2. **Initial assessment:** SRE reviews dashboards (Grafana), logs (Loki), traces (Tempo); determines severity.
3. **Incident declaration:** If SEV-1/2, SRE escalates to Incident Commander; opens incident channel (Slack/Teams).
4. **Notification:** IC posts status to internal status page; if customer-facing, external comms team notified.

**Phase 2: Containment & Stabilization (15 min - 4 hours)**
1. **Containment:** Isolate affected components (scale down, network segmentation, revoke credentials).
2. **Evidence preservation:** If security incident, trigger forensic snapshot (see §39.4) **before** remediation.
3. **Mitigation:** Execute runbook (§19 Upgrade, §16.5.6 etcd restore, §14 Velero restore); apply emergency patches.
4. **Validation:** Verify service health (smoke tests, SLO checks); confirm no ongoing data loss.

**Phase 3: Recovery & Communication (1-8 hours)**
1. **Full restore:** Bring all components to healthy state; re-enable traffic; validate end-to-end flows.
2. **Monitoring:** Heightened monitoring for 24 hours post-recovery (watch for flapping, cascading failures).
3. **Status update:** IC posts "incident resolved" with timeline, impact summary, preliminary root cause.

**Phase 4: Post-Incident Review (Within 7 days)**
1. **Blameless postmortem:** Team reviews timeline, decisions, what worked/didn't.
2. **Root cause analysis:** 5-Whys or Fishbone; document contributing factors.
3. **Action items:** Prioritized backlog items (runbook updates, monitoring gaps, architectural fixes).
4. **Documentation:** Publish postmortem (internal wiki/Git); share learnings in all-hands.

### 39.4) Forensics & Evidence Preservation

**Trigger conditions:**
* Confirmed or suspected security breach (data exfiltration, unauthorized access, malware).
* Compliance incident requiring audit trail (GDPR breach, SOC 2 violation).
* Legal hold request from legal/compliance team.

**Evidence collection (within 1 hour of incident declaration):**
1. **Snapshot VMs/Nodes:** Cloud provider snapshots (Azure/AWS/GCP) or on-prem disk images; preserve **before** patching.
2. **etcd backup:** Immediate etcd snapshot (see §16.5.6); stored offsite with encryption.
3. **Logs export:** Extract audit logs (Kubernetes API server), application logs (Loki), network flow logs (CNI) for affected time window (T-24h to T+1h).
4. **Memory dumps:** If malware suspected, capture node memory dumps (optional; requires forensic tools).
5. **Git state:** Record Git commit SHAs for all affected manifests/images; preserve PR history.
6. **Access logs:** Export IAM/RBAC access logs; identify who/what touched affected resources.

**Chain of custody:**
* All evidence stored in **write-once/read-many** (WORM) object storage (S3 Object Lock / Azure Immutable Blob).
* Access restricted to security/legal teams; MFA + audit trail required.
* Evidence retention: **≥ 2 years** (compliance-dependent); longer if litigation pending.

**Forensic analysis:**
* Perform offline analysis; **do not analyze on production cluster**.
* Use isolated forensic workstation (air-gapped or dedicated VPC/VNet).
* Document findings in incident report; coordinate with legal before sharing externally.

### 39.5) Legal Hold & Data Preservation

* **Trigger:** Legal/compliance team issues hold notice (litigation, regulatory investigation).
* **Scope:** Freeze deletion of **all** logs, backups, snapshots, Git history related to affected tenant/timeframe.
* **Duration:** Until legal releases hold (weeks to years).
* **Process:**
  1. Platform team receives hold notice; IC coordinates with legal.
  2. Update retention policies: Disable automated log deletion (Loki), backup expiry (Velero), etcd compaction.
  3. Tag affected resources in object storage (S3 tags, Azure Blob metadata) with legal hold marker.
  4. Document scope in incident ticket; monthly reminders to verify hold still active.

### 39.6) Communication Plan

| Audience | Channel | Frequency | Content |
|----------|---------|-----------|---------|
| **Internal responders** | Incident Slack/Teams channel | Real-time | Technical updates, decisions, asks |
| **Application teams** | Internal status page | Every 30 min (SEV-1/2) | Impact, ETA, workarounds |
| **Management** | Slack + email summary | Hourly (SEV-1), 4-hourly (SEV-2) | Business impact, timeline, decisions needed |
| **Customers (if external)** | External status page (e.g., Statuspage.io) | Every hour | Non-technical summary, ETA, affected services |
| **Post-incident** | Email + wiki | Within 7 days | Postmortem, root cause, action items |

### 39.7) Table-Top Exercises & Preparedness

* **Cadence:** **Quarterly** for SEV-1 scenarios; **bi-annually** for SEV-2.
* **Scenarios:**
  * **etcd quorum loss:** Practice §16.5.6 restore from snapshot.
  * **Security breach:** Simulate compromised service account; practice isolation + forensics.
  * **Cloud region failure:** Multi-AZ failover (if supported) or full DR restore (§14).
  * **Supply-chain attack:** Unsigned image deployed; practice policy enforcement + rollback.
* **Participants:** Platform SRE, Security, on-call rotation, Incident Commander.
* **Outcomes:** Document gaps in runbooks, tooling, or training; prioritize fixes.
* **Metrics:** Track MTTA/MTTR during drills; compare to targets; improve response times.

### 39.8) Incident Metrics & Reporting

* **Dashboard:** Grafana panel shows:
  * Incidents by severity (last 30/90 days).
  * MTTA/MTTR trends (are we improving?).
  * Top incident categories (etcd, ingress, storage, security).
* **Executive report:** Monthly summary:
  * Total incidents (by SEV).
  * Critical incidents (SEV-1/2) with impact summary.
  * Action item completion rate from postmortems.
  * Forecast: Are we trending better/worse?

**Don'ts:**
* Don't delay incident declaration to "investigate more" (declare, then adjust severity).
* Don't skip evidence preservation in security incidents (legal/compliance risk).
* Don't ignore postmortem action items (technical debt compounds).
* Don't blame individuals in postmortems (focus on systems/processes).

---

## 40) Platform Decommission & Exit Runbook

**Purpose:** Safe, auditable process for complete platform shutdown (cluster, infra, data) with compliance.

### 40.1) Decommission Triggers

* Business decision to sunset platform or migrate to alternative.
* Cloud provider migration (lift-and-shift).
* End of project/contract requiring full teardown.
* Security incident requiring infrastructure wipe.

### 40.2) Pre-Decommission Checklist

* [ ] **Business approval:** Executive sign-off; documented reason.
* [ ] **Tenant notification:** 90-day advance notice (unless emergency).
* [ ] **Data inventory:** All PVCs, Secrets, backups, logs requiring retention.
* [ ] **Compliance review:** Confirm retention obligations (GDPR, contracts).

### 40.3) Data Archival & Retention

* **Velero backups:** Final full backup; store offsite (S3/Azure/GCS) with WORM protection.
* **Logs & metrics:** Export Loki (last 90d), Prometheus snapshots, audit logs to cold storage.
* **Git history:** Archive manifests, Terraform state to secure offline storage.
* **Certificates & keys:** Export CA certs, backup keys; store in secure vault.
* **Retention:** Default **7 years** (compliance); verify with legal.

### 40.4) Phased Decommission Procedure

**Phase 1: Workload Shutdown (Day 0-30)**
1. Scale tenant workloads to 0 replicas.
2. Disable Ingress (remove DNS records).
3. Revoke external access (Workload Identity, ESO, API keys).
4. Final Velero backup + verification.

**Phase 2: Infrastructure Cleanup (Day 30-60)**
1. Delete all namespaces: `kubectl delete namespace --all`.
2. Destroy cluster via Terraform or manual teardown.
3. Cleanup cloud resources: LBs, public IPs, DNS zones, PVs, Key Vaults, IAM roles.
4. Delete Terraform state backend after verifying no dependencies.

**Phase 3: Security Hygiene (Day 60+)**
1. Revoke Cosign keys (KMS/Vault), etcd encryption keys.
2. Generate final audit report; store with archival data.
3. Verify cleanup: $0 cloud spend, no orphaned resources.

### 40.5) Post-Decommission Validation

* [ ] Cloud billing shows **$0** monthly charges.
* [ ] DNS queries return **NXDOMAIN**.
* [ ] No active service principals or IAM roles.
* [ ] Archival data accessible only to legal/compliance (MFA + audit).
* [ ] Decommission report filed with date, approvers, audit trail.
