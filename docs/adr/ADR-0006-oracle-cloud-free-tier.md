# ADR-0006: Oracle Cloud Free Tier as Production MVP Platform

**Status:** Accepted
**Date:** 2025-10-20
**Deciders:** Platform Team, CTO
**Consulted:** Security Team, FinOps
**Informed:** Development Team

---

## Context

We need a **production-ready Kubernetes environment** for Phase 4 (MVP go-live) to deploy our multi-tenant SaaS platform for **real users**. Requirements:

1. **Cost:** Free or minimal cost during MVP phase (no revenue yet)
2. **Control:** Self-managed Kubernetes (not vendor-locked managed services like AKS/EKS/GKE)
3. **Portability:** Uses same `onprem/` overlay as physical on-premises deployments
4. **Resources:** Sufficient for MVP (≥4 CPUs, ≥24 GB RAM, ≥200 GB storage)
5. **Reliability:** Production-grade SLA (≥99.9% uptime)
6. **User Access:** Public IP + domain for external users

---

## Decision

We will use **Oracle Cloud Free Tier** as the **production MVP platform** (Phase 4), deploying via the `clusters/overlays/onprem/` overlay (self-managed **kubeadm**).

**Key Decision Points:**

1. **Provider:** Oracle Cloud Infrastructure (OCI) Always Free Tier
2. **Kubernetes Distribution:** **kubeadm** (vanilla Kubernetes, upstream)
3. **Architecture:** 2 VMs (1 control-plane, 1 worker node)
4. **Overlay:** `clusters/overlays/onprem/` (same as physical on-prem)
5. **Deployment Model:** Terraform provisions VMs + kubeadm → Argo CD syncs apps

---

## Rationale

### Why Oracle Cloud Free Tier?

| Requirement | Oracle Cloud Free Tier | Alternatives (Rejected) |
|-------------|----------------------|------------------------|
| **Cost** | ✅ **$0 forever** (no credit expiration) | GitHub Codespaces: 60h/month, then $0.18/h<br>Civo: $250 credits (2-3 mo), then $5/mo<br>GKE/AKS: $300-200 credits (3-4 mo), then $$$ |
| **Resources** | ✅ **4 ARM CPUs, 24 GB RAM, 200 GB storage** (sufficient for MVP) | Raspberry Pi: ~$500 hardware, no SLA<br>Home lab: power outages, slow upload |
| **Control** | ✅ **Self-managed kubeadm** (root access, no restrictions) | AKS/EKS/GKE: Managed control plane (vendor lock-in)<br>PaaS: No Kubernetes access |
| **Portability** | ✅ Uses **`onprem/` overlay** (identical to physical on-prem) | Managed K8s: requires cloud-specific overlays (`aks/eks/gke/`) |
| **Reliability** | ✅ **~99.9% SLA** (Oracle datacenter infrastructure) | Raspberry Pi: no SLA, single point of failure<br>Home lab: ISP outages, no backup power |
| **User Access** | ✅ **2 static public IPs + 10 TB/month traffic** | Home lab: DynDNS, port forwarding, slow upload<br>Codespaces: 60h limit, ephemeral |

### Why NOT Managed Kubernetes (AKS/EKS/GKE)?

- **Cost:** Expensive after free credits expire (~$100-300/month for prod-grade cluster)
- **Vendor Lock-In:** Requires cloud-specific overlays (`aks/eks/gke/`), not portable to on-prem
- **Control Plane Lock-In:** No access to etcd, control plane logs, API server config (managed by provider)
- **Phase 4 Goal:** Validate self-managed `onprem/` overlay before physical deployment (Oracle is "on-prem in Oracle's datacenter")

### Why kubeadm (vanilla Kubernetes)?

- ✅ **Upstream Kubernetes:** Identical API/behavior to AKS/EKS/GKE (they all use kubeadm internally)
- ✅ **Full control:** Direct access to etcd, control plane logs, API server configuration
- ✅ **HA-ready:** Multi-master setup with external etcd for production scale
- ✅ **CNCF-certified:** Official conformance, guaranteed compatibility with all K8s tools
- ✅ **Portability:** Same `onprem/` overlay works on Oracle Cloud, bare-metal, VMs anywhere
- ✅ **No vendor lock-in:** No proprietary components (unlike k3s SQLite, embedded ServiceLB)
- ✅ **Enterprise-grade:** Same distribution as managed clouds, proven at scale

---

## Implementation

### VM Layout (Oracle Cloud)

```
Control Plane VM (kubeadm-master):
├─ Shape: VM.Standard.A1.Flex (ARM Ampere A1)
├─ CPUs: 2 OCPUs
├─ RAM: 12 GB
├─ Storage: 100 GB Block Volume (Boot + PVCs via Longhorn)
├─ Role: kubeadm control plane (API server, scheduler, controller-manager, etcd)
└─ Public IP: xxx.xxx.xxx.xxx (for LoadBalancer services)

Worker Node VM (kubeadm-worker):
├─ Shape: VM.Standard.A1.Flex
├─ CPUs: 2 OCPUs
├─ RAM: 12 GB
├─ Storage: 100 GB Block Volume (PVCs via Longhorn)
├─ Role: Worker node (application workloads only)
└─ Public IP: yyy.yyy.yyy.yyy (MetalLB IP pool)

Total: 4 CPUs, 24 GB RAM, 200 GB Storage ✅ (within Always Free limits)
```

### Deployment Flow

```
Developer → Git Push → Terraform apply
  ↓
Terraform provisions:
  1. Oracle Compute VMs (2x ARM, cloud-init with kubeadm install)
  2. VCN (Virtual Cloud Network) + subnets + security groups
  3. Block Volumes (attached to VMs for Longhorn)
  4. Public IPs (assigned to LoadBalancer pool)
  ↓
cloud-init script on VMs:
  1. Install container runtime (containerd)
  2. Install kubeadm, kubelet, kubectl
  3. Initialize cluster: kubeadm init (master)
  4. Install CNI: kubectl apply -f calico.yaml (or Cilium)
  5. Join worker: kubeadm join <master>:6443 --token <token>
  ↓
Terraform installs Argo CD (via Helm provider):
  1. kubectl apply -f argocd-install.yaml
  2. kubectl apply -f argocd/bootstrap/root-app.yaml
  ↓
Argo CD syncs:
  1. clusters/overlays/onprem/ → MetalLB, Longhorn, NGINX, policies
  2. apps/overlays/prod/ → Backend, Frontend, PostgreSQL, Redis
  ↓
Result: Production MVP live on Oracle Cloud (accessible via https://app.yourdomain.com)
```

### Overlay Configuration (`clusters/overlays/onprem/`)

```yaml
# metallb-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: metallb-config
  namespace: metallb-system
data:
  config: |
    address-pools:
    - name: oracle-public-ips
      protocol: layer2
      addresses:
      - xxx.xxx.xxx.xxx/32  # Oracle Public IP 1
      - yyy.yyy.yyy.yyy/32  # Oracle Public IP 2

# storageclass-patch.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard  # Same name everywhere (portability!)
provisioner: driver.longhorn.io  # Longhorn on Oracle Block Storage
parameters:
  numberOfReplicas: "2"  # HA across 2 nodes
  staleReplicaTimeout: "30"

# external-dns-cloudflare.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
spec:
  template:
    spec:
      containers:
      - name: external-dns
        args:
        - --provider=cloudflare
        - --cloudflare-dns-records-per-page=100
        env:
        - name: CF_API_TOKEN
          valueFrom:
            secretKeyRef:
              name: cloudflare-credentials
              key: api-token

# external-secrets-vault.yaml (Phase 2)
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.yourdomain.com:8200"
      path: "secret"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
```

---

## Consequences

### ✅ Positive

1. **Zero Cost Forever:** No surprise bills, no credit expiration (Always Free = truly free)
2. **Production-Ready:** 99.9% SLA, datacenter infrastructure, backup power, enterprise hardware
3. **Identical to On-Prem:** Uses same `onprem/` overlay → validates deployment model for physical hardware
4. **Portability Proven:** Easy migration path to AKS/EKS/GKE later (swap overlay only, zero app changes)
5. **Vanilla Kubernetes:** kubeadm = upstream K8s, same API as managed clouds (no vendor-specific components)
6. **Real User Access:** Public IPs + domain → users can access from anywhere (not just localhost)
7. **Learning Opportunity:** Self-managed kubeadm teaches Kubernetes internals (etcd, control plane, CNI)

### ⚠️ Negative

1. **Resource Limits:** Cannot scale beyond 4 CPUs/24 GB without paying (but sufficient for MVP 100-1000 users)
2. **ARM-Only:** All images must support `linux/arm64` (forces multi-arch CI from day 1)
3. **Single Region:** No built-in multi-region HA (mitigation: Velero backups to S3, restore to new region if needed)
4. **Account Suspension Risk:** Oracle may suspend accounts for ToS violations (rare, but document backup strategy)
5. **Upgrade Path Unclear:** If free tier changes, need migration plan (mitigation: Terraform makes re-deployment easy)
6. **Manual kubeadm Setup:** More complex than managed K8s (requires CNI installation, etcd management)

### 🛠️ Mitigations

1. **Multi-Arch Images:** CI builds `linux/amd64` AND `linux/arm64` manifests (docker buildx) from day 1
2. **Velero Backups:** Daily backups to S3-compatible storage (MinIO or Backblaze B2, $0.005/GB/month)
3. **DR Plan:** Document "Restore to AKS/GKE" procedure (tested quarterly)
4. **Monitoring:** Alert if Oracle account shows warnings (Terraform state S3 backup prevents data loss)
5. **Terraform IaC:** Full infra as code → can re-deploy to new Oracle account or migrate to AKS/EKS in <1 hour

---

## Alternatives Considered

### 1. Raspberry Pi Cluster (On-Prem at Home)

**Pros:**
- Full hardware control
- Learning experience (bare-metal Kubernetes)

**Cons:**
- ❌ Hardware cost: ~$500 (3x RPi 5 8GB + SSDs + switch + power)
- ❌ No SLA: Power outages, ISP downtime → users cannot access
- ❌ Slow upload: Home internet upload speed insufficient for real users
- ❌ DynDNS complexity: Dynamic IPs require DNS updates, SSL cert challenges
- ❌ Single point of failure: No datacenter backup power, no redundant networking

**Decision:** Rejected (better for homelab learning, not production MVP).

### 2. GitHub Codespaces (Ephemeral Development)

**Pros:**
- 60 hours/month free
- kind cluster works out-of-the-box
- Port forwarding for HTTPS

**Cons:**
- ❌ Time-limited: 60h/month = ~2h/day (not 24/7 availability)
- ❌ Ephemeral: Stops after inactivity, no persistent storage
- ❌ Not production: Cannot give users "always-on" access

**Decision:** Rejected (good for demos, not production).

### 3. Civo Cloud (Managed k3s)

**Pros:**
- $250 free credits (~2-3 months)
- Cheapest managed K8s ($5/month after)
- k3s-based (same as Oracle approach)

**Cons:**
- ❌ Managed control plane: Vendor lock-in, requires `civo/` overlay
- ❌ Credits expire: Need payment method after 2-3 months
- ❌ Not self-managed: Cannot validate `onprem/` overlay

**Decision:** Rejected (good for scale-out later, not MVP validation).

### 4. Google Cloud Free Tier (GKE Autopilot)

**Pros:**
- $300 credits (~4 months)
- Managed control plane (less ops burden)
- Auto-scaling, auto-upgrades

**Cons:**
- ❌ Vendor lock-in: Requires `gke/` overlay (not portable to on-prem)
- ❌ Credits expire: ~$100-200/month after
- ❌ Managed only: Cannot learn self-managed Kubernetes

**Decision:** Rejected (use for scale-out in Phase 5+, not MVP).

---

## Related ADRs

- **ADR-0003**: etcd scope (kubeadm uses external etcd or stacked etcd, full control vs k3s SQLite)
- **ADR-0001**: Config SoT (PostgreSQL works identically on Oracle Cloud ARM as AMD64)
- **ADR-0002**: Hot-reload (Redis Pub/Sub works identically across providers)

---

## Review & Approval

- **Reviewed by:** Platform Team (2025-10-20)
- **Approved by:** CTO (2025-10-20)
- **Next Review:** After Phase 4 completion (validate production readiness) OR if Oracle changes Always Free terms

---

## References

- [Oracle Cloud Always Free Resources](https://www.oracle.com/cloud/free/)
- [kubeadm Documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [ARCHITECTURE.md §8: Cluster Options](../architecture/ARCHITECTURE.md#8-cluster-options--decision-guide)
- [Terraform Oracle Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs)
