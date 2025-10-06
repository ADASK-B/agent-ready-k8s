# Goal (precise)

A **cloud-agnostic Kubernetes platform** that is reproducibly deployed from **one Git repository** via **GitOps** to **AKS** and **on-prem** (k3s/RKE2/kubeadm), keeping **application manifests unchanged** while **provider specifics live only in environment overlays**. The platform enforces a **security baseline** (Pod Security, least-privilege RBAC, NetworkPolicies, signed images), **standardized observability** (metrics/logs/traces), and **verifiable backups/DR**. **No click-ops**; all changes are **PR- and audit-driven**. **Success criteria:** fresh deployments of both environments from the repo; workloads reachable via **DNS+TLS**; **policy gates green**; **Velero restore proven**—within a defined time budget.

---

# Golden Rules (critical for portability & operations)

1. **Strict layering:**
   *Infra (Terraform) ⟂ Cluster add-ons (GitOps) ⟂ Apps (GitOps)*. No mixing.

2. **One repo—multiple overlays:**
   `clusters/base` (shared baseline) + `overlays/{aks,onprem,eks,gke}` for provider details only.

3. **Naming consistency everywhere:**
   Keep identical names: `ingressClassName`, `StorageClass` (e.g., `standard`), `ClusterIssuer` (e.g., `letsencrypt-prod`), Secret/ServiceAccount names.

4. **GitOps is the single source of truth:**
   No click-ops. Changes flow PR → review → merge → sync.

5. **Immutable & signed:**
   Pin images by **digest**, **sign with Cosign**, never use `:latest`.

6. **Security by default:**
   Pod Security (restricted), default-deny NetworkPolicies, least-privilege RBAC, never store secrets in the repo.

7. **Unified observability:**
   Prometheus/Grafana, Loki, **OpenTelemetry Collector**—identical across environments; shared dashboards & alerts.

8. **Backups/DR must be proven:**
   Velero + object-storage backend (cloud/on-prem). Routine restore tests are mandatory.

9. **Planned, reproducible upgrades:**
   Pin versions (K8s, CNIs, charts, CRDs); stage first; maintenance windows; runbooks.

10. **No provider lock-in inside app manifests:**
    Avoid cloud-specific ingress/storage annotations in charts.

---

# Must-have tools (Minimum Viable Platform)

**Provisioning & governance**

* **Terraform** (infra to GitOps bootstrap), remote state with locking.
* **GitOps:** **Flux** *or* **Argo CD** (choose one and be consistent).
* **Policy:** **Kyverno** *or* **OPA Gatekeeper** (policy checks before sync).

**Networking & entry**

* **Ingress:** **NGINX** *or* **Traefik** (one `IngressClass` everywhere).
* **Load balancer:** Cloud LB (AKS/EKS/GKE) ↔ **MetalLB** (on-prem).
* **DNS:** **ExternalDNS** (Azure DNS / Route 53 / Cloud DNS / internal DNS).

**Certificates & secrets**

* **cert-manager** (identical `ClusterIssuer` names).
* **External Secrets Operator (ESO)** → Azure Key Vault / AWS Secrets Manager / Google Secret Manager / Vault.

**Storage**

* Cloud CSI (Azure Disk/Files, EBS/EFS, GCE-PD/Filestore) ↔ on-prem **Longhorn** (simple) *or* **Rook-Ceph** (scale).
  Use the same `StorageClass` name.

**Observability & SRE**

* **kube-prometheus-stack**, **Loki**, **Tempo/OTel Collector** (metrics/logs/traces).
* **Alertmanager** with defined **SLOs** and runbooks.

**Backup/DR**

* **Velero** (+ CSI Snapshot CRDs), offsite object storage (S3/GCS/Azure/MinIO).

**Software supply chain**

* **Cosign** (signatures), **Trivy/Grype** (image scans), SBOM in CI.

**Optional / recommended**

* **Rancher** or **Lens** (cluster management/GUI).
* **Gateway API** (future-proof ingress), **Cilium** (eBPF) on-prem.

---

# Do’s & Don’ts by domain

## 1) Terraform & IaC

**Do**

* Separate **remote state per environment** (encrypted, locked).
* **Unify module interfaces**: a `module.cluster` with provider-specific implementations (AKS/EKS/GKE/on-prem) underneath.
* Terraform is for **networks, subnets, public IPs, DNS zones, LB primitives, registries, KMS/keystores**, **managed clusters** (AKS/EKS/GKE) or **VMs + cloud-init** (on-prem), and **GitOps bootstrap only**.
* CI auth via **OIDC/federation**—no long-lived keys.

**Don’t**

* Don’t manage **Kubernetes objects** (Deployments/Ingress/CRDs) long-term with Terraform.
* **No secrets** in Terraform state.
* No portal changes in parallel (drift).

## 2) GitOps & manifests

**Do**

* `base/` contains add-ons (Ingress, cert-manager, ExternalDNS, storage drivers, ESO, observability, policies).
* `overlays/{aks,onprem,…}` change **only** provider specifics.
* **PR required** + automated **policy checks** before reconciliation.
* **Pin images by digest**, release notes, change freeze for critical events.
* **Admission must fail-closed** (policy or signature check failing blocks deploy).

**Don’t**

* No `kubectl apply` to production from laptops.
* No diverging object names across environments.

## 3) Networking & ingress

**Do**

* One `IngressClass` (e.g., `nginx`).
* Services use `type: LoadBalancer`; on-prem use **MetalLB** (L2/BGP, plan IP pools).
* **NetworkPolicies** default-deny; allow egress narrowly; validate CNI behavior.
* **ExternalDNS**: only provider credentials differ.

**Don’t**

* No cloud-specific ingress annotations in app charts.
* No NodePort exposure to the internet.

## 4) CNI & IP design

**Do**

* Document Pod/Service CIDRs per environment; avoid collisions with corp networks.
* On-prem: Cilium/Calico; AKS/EKS/GKE: native CNIs (plan IPs/ENIs carefully).
* Decide early on **DNS, MTU, BGP** (with MetalLB).

**Don’t**

* Don’t assume Pod-IP behavior is identical across clouds.

## 5) Storage & data

**Do**

* **Same `StorageClass` name** everywhere (e.g., `standard`).
* Use **CSI snapshots**; DB backups must be application-aware.
* On-prem: **Longhorn** (simple) or **Rook-Ceph** (HA/scale).
* Ensure **encryption at rest** for volumes/buckets; for self-managed control planes, enable **etcd encryption for Kubernetes Secrets**.

**Don’t**

* Don’t hard-code cloud-specific SC names.
* Don’t “lift & shift” PVs without a migration path.

## 6) Secrets & keys

**Do**

* **ESO** + environment secret store; rotation & least privilege.
* Secrets never in ConfigMaps, repos, or TF state.
* Encrypt secrets at rest (cloud KMS or Vault), and protect service account tokens (short-lived where possible).

**Don’t**

* No static cloud keys stored as K8s Secrets.

## 7) Identity & access

**Do**

* Workload identities: **Azure AD Workload Identity**, **EKS Pod Identity/IRSA**, **GKE Workload Identity**.
* RBAC: least privilege, dedicated ServiceAccounts per app; document technical break-glass.

**Don’t**

* No workloads with `cluster-admin`.
* No shared ServiceAccounts across services.

## 8) Security baseline

**Do**

* PodSecurity (restricted), `runAsNonRoot`, read-only root FS, drop capabilities, seccomp.
* Enforce signature verification (Kyverno/OPA + Cosign).
* Routine node/image CVE scans; plan kernel & OS patches; baseline CIS hardening.

**Don’t**

* Avoid `privileged`, `hostNetwork`, `hostPath` unless strictly required.

## 9) Observability & SRE

**Do**

* **kube-prometheus-stack**, **Loki**, **OTel Collector**; propagate trace IDs for correlation.
* Define **SLOs**, alert policies, and **runbooks**; keep signals uniform across environments.

**Don’t**

* Don’t rely on vendor-specific monitoring only (hurts portability).
* Don’t keep infinite retention (cost/perf issues).

## 10) Backup/DR

**Do**

* **Velero** with object-storage backend (cloud/MinIO).
* Routine **restore exercises** (table-top + live drill).
* Define RPO/RTO; store KMS/CA keys offsite; document escalation paths.

**Don’t**

* Don’t back up only namespaces without CRDs/cluster resources.
* Don’t accept an untested DR plan.

## 11) Releases & environments

**Do**

* **Dev → Stage → Prod** via promotion (PR).
* **Blue/Green/Canary** based on risk profile.
* Prefer **feature flags** over environment-specific code.

**Don’t**

* No hotfixes directly on production clusters.
* No diverging chart logic per environment (use values/overlays only).

## 12) Resources & scheduling

**Do**

* Set **Requests/Limits**, **HPA/VPA**, **PDBs**, **TopologySpreadConstraints**.
* Use node pools + taints/tolerations (GPU/high-mem/spot separation).
* Run critical add-ons with ≥2 replicas; anti-affinity where relevant.

**Don’t**

* Don’t overcommit without controls; avoid SPOFs.

## 13) Compliance & data residency

**Do**

* Classify data (PII/logs/backups); **encrypt in transit & at rest**.
* Enable and review **audit logs** (API server, CI/CD, GitOps controllers).

**Don’t**

* No PII in logs; no tenant mixing in the same namespace.

## 14) Upgrades & changes

**Do**

* Release calendar, semver pinning, **staged dry-run**, maintenance windows.
* Post-upgrade health checks (API, CRD migrations, dashboard diffs).

**Don’t**

* Don’t run competing CNIs/ingress controllers “just to test” in prod.

## 15) FinOps / cost

**Do**

* Label/tag resources (cost centers); quotas; bound log/trace retention.
* Cloud: autoscaling, spot/preemptible for stateless. On-prem: capacity planning & power policies.

**Don’t**

* No orphaned LBs/DNS/disks/images; routine cleanup jobs.

---

# Provider mapping (compact)

| Component         | AKS                        | EKS                         | GKE                         | On-prem                           |
| ----------------- | -------------------------- | --------------------------- | --------------------------- | --------------------------------- |
| Ingress/LB        | NGINX/AGIC + Azure LB      | AWS LB Controller (ALB/NLB) | GKE Ingress/Gateway + GCLB  | NGINX/Traefik + **MetalLB**       |
| CNI               | Azure CNI                  | VPC CNI                     | Dataplane V2/Calico         | Cilium/Calico                     |
| Block storage     | Azure Disk (CSI)           | EBS (CSI)                   | GCE-PD (CSI)                | **Longhorn**/**Rook-Ceph**        |
| Shared FS         | Azure Files (CSI)          | EFS (CSI)                   | Filestore (CSI)             | NFS/CEPHFS                        |
| DNS               | Azure DNS (ExternalDNS)    | Route 53 (ExternalDNS)      | Cloud DNS (ExternalDNS)     | Internal/Cloudflare (ExternalDNS) |
| Secrets           | Azure Key Vault (ESO)      | AWS Secrets Manager (ESO)   | Google Secret Manager (ESO) | Vault/Sealed Secrets (ESO)        |
| Workload identity | Azure AD Workload Identity | EKS Pod Identity / IRSA     | Workload Identity           | K8s SA ↔ Vault/JWT                |

---

# Pre-flight checklist (before the first `apply`)

* [ ] CIDR plan (Pod/Service/VNet/VPC) documented and collision-free.
* [ ] DNS zones & domains (internal/external) decided; ACME challenge path defined.
* [ ] Storage strategy per environment (SC name, driver) agreed.
* [ ] Registry strategy (ACR/ECR/GAR/Harbor), mirrors & pull secrets prepared.
* [ ] Secret backends & ESO providers with permissions in place.
* [ ] Observability targets & SLOs with alert routes defined.
* [ ] Velero backend (bucket/MinIO) available with access.
* [ ] GitOps bootstrap repo, branch protection, CI OIDC configured.
* [ ] Policy set (Kyverno/OPA) defined & tested (admission fail-closed).
* [ ] Runbooks, break-glass access, and audit trail documented.

---

# Go-live checklist (per environment)

* [ ] Flux/Argo synced, **drift = 0**; all add-ons Ready.
* [ ] Ingress reachable, DNS records correct, **TLS green**.
* [ ] NetworkPolicies enforced (positive/negative connectivity tests).
* [ ] Storage PVC/PV lifecycle validated; snapshots functioning.
* [ ] ESO secrets materialize and rotate successfully.
* [ ] Observability: metrics/logs/traces visible; alerts firing in test.
* [ ] Velero: **restore test passed**.
* [ ] SLO dashboards live; on-call informed; freeze window set.
* [ ] Backout plan ready (DNS rollback/blue-green).

---

# Weekly ops routine (short)

* [ ] Review pending updates (cluster/add-ons); schedule rollouts.
* [ ] Triage vulnerability reports (images/nodes).
* [ ] Inspect cost drivers (LBs/disks/logs).
* [ ] Perform a Velero restore smoke (1 namespace).
* [ ] Fix policy violations/drift.

---

# Anti-patterns (red card)

* Cloud annotations / SC names in app charts.
* `kubectl apply` to prod from developer laptops.
* Secrets/keys in repo or TF state.
* `:latest` / mutable tags; unsigned images.
* No default-deny or missing RBAC segmentation.
* Backups without restore drills.
* Inconsistent names across environments (Issuer/Ingress/SC).
* Click-ops in portals alongside Terraform/GitOps.

**Last Updated:** 06.01.2025  
**Status:** Living document - update when architectural decisions change
