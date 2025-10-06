# 🗺️ ROADMAP - agent-ready-k8s

> **Phase 1:** Local Kubernetes setup (~1-2 min)  
> **Phase 2:** GitOps + Azure AKS (planned)

---

## 🚀 Quick Start

```bash
./setup-template/setup-phase1.sh
```

---

## ✅ Phase 1 Checklist

### **Block 1: Tools Installation**
- [ ] Docker installed and running (`docker --version`)
- [ ] kind installed (`kind version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] Helm installed (`helm version`)
- [ ] Argo CD CLI installed (`argocd version --client`)
- [ ] Task installed (`task --version`)

**Test:** `./setup-template/phase1/01-install-tools/test.sh`

---

### **Block 2: Project Structure**
- [ ] Folders created (`apps/`, `clusters/`, `infrastructure/`, `policies/`)
- [ ] `kind-config.yaml` exists in root
- [ ] `.gitignore` created

**Test:** `./setup-template/phase1/02-create-structure/test.sh`

---

### **Block 3: Templates**
- [ ] `apps/podinfo/base/` contains manifests
- [ ] `apps/podinfo/tenants/demo/` contains overlays

**Test:** `./setup-template/phase1/03-clone-templates/test.sh`

---

### **Block 4: Cluster**
- [ ] kind cluster created (`kind get clusters` → `agent-k8s-local`)
- [ ] kubectl context set (`kubectl config current-context` → `kind-agent-k8s-local`)
- [ ] Node ready (`kubectl get nodes` → `Ready`)

**Test:** `./setup-template/phase1/04-create-cluster/test.sh`

---

### **Block 5: Ingress**
- [ ] ingress-nginx namespace created
- [ ] Ingress controller pod running (`kubectl get pods -n ingress-nginx`)

**Test:** `./setup-template/phase1/05-deploy-ingress/test.sh`

---

### **Block 6: Demo App**
- [ ] `tenant-demo` namespace created
- [ ] podinfo pods running (`kubectl get pods -n tenant-demo` → `2/2 Running`)
- [ ] Ingress created (`kubectl get ingress -n tenant-demo`)
- [ ] HTTP endpoint works (`curl http://demo.localhost` → HTTP 200)
- [ ] Browser works (`http://demo.localhost` → podinfo UI)

**Test:** `./setup-template/phase1/06-deploy-podinfo/test.sh`

---

## 🎯 Phase 1 Complete When:

| Check | Command | Expected | Status |
|-------|---------|----------|--------|
| **Cluster** | `kind get clusters` | `agent-k8s-local` | ⬜ |
| **Nodes** | `kubectl get nodes` | 1 node Ready | ⬜ |
| **Ingress** | `kubectl get pods -n ingress-nginx` | 1/1 Running | ⬜ |
| **podinfo** | `kubectl get pods -n tenant-demo` | 2/2 Running | ⬜ |
| **HTTP** | `curl http://demo.localhost` | HTTP 200 | ⬜ |
| **Browser** | Open `http://demo.localhost` | podinfo UI | ⬜ |

---

## 📋 Phase 2 Checklist (Cloud-Agnostic Deployment)

> **Goal:** Deploy from one Git repo to **AKS** and **On-Prem** with identical app manifests  
> **Architecture:** `base/` (portable) + `overlays/{aks,onprem}` (provider-specific)

### **Base Layer (Portable - works everywhere)**

#### **GitOps & CI/CD**
- [ ] Argo CD installed in cluster (`argocd` namespace)
- [ ] Argo CD Applications created (`clusters/base/`)
- [ ] GitHub Actions CI/CD pipeline configured
- [ ] Branch protection + PR workflow active
- [ ] Policy checks before sync (Kyverno/OPA)

#### **Certificates & DNS**
- [ ] cert-manager installed (identical `ClusterIssuer` names)
- [ ] ExternalDNS installed (provider-agnostic config)
- [ ] TLS certificates working (Let's Encrypt)

#### **Security & Policies**
- [ ] Kyverno or OPA Gatekeeper installed
- [ ] Pod Security Standards enforced (restricted)
- [ ] Default-deny NetworkPolicies active
- [ ] Image signature verification (Cosign)
- [ ] Admission controller fail-closed

#### **Secrets Management**
- [ ] External Secrets Operator (ESO) installed
- [ ] Secret stores configured per environment
- [ ] Secrets never in Git/Terraform state

#### **Observability**
- [ ] kube-prometheus-stack deployed (Prometheus + Grafana + Alertmanager)
- [ ] Loki deployed (log aggregation)
- [ ] OpenTelemetry Collector deployed (traces)
- [ ] SLOs defined with alert routes
- [ ] Dashboards created and tested

#### **Backup & DR**
- [ ] Velero installed with object storage backend
- [ ] Backup schedules configured
- [ ] Restore test passed (mandatory!)
- [ ] RPO/RTO documented

---

### **AKS Overlay (Azure-specific)**

#### **Infrastructure (Terraform)**
- [ ] Azure Resource Group created
- [ ] VNet + Subnets configured (CIDR plan documented)
- [ ] AKS cluster deployed (managed control plane)
- [ ] Azure Container Registry (ACR) created
- [ ] Azure Key Vault created
- [ ] Azure DNS zone configured

#### **Cluster Configuration**
- [ ] Azure CNI configured
- [ ] Azure Disk CSI driver (StorageClass: `standard`)
- [ ] Azure Files CSI driver (for shared storage)
- [ ] Azure Load Balancer configured
- [ ] Azure AD Workload Identity enabled
- [ ] Network Policies enabled

#### **Add-ons**
- [ ] ExternalDNS → Azure DNS
- [ ] ESO → Azure Key Vault
- [ ] cert-manager → AzureDNS solver
- [ ] Velero → Azure Blob Storage

#### **Testing**
- [ ] Ingress reachable via public DNS
- [ ] TLS green (Let's Encrypt cert)
- [ ] Workload identity working
- [ ] Velero backup/restore successful

---

### **On-Prem Overlay (Self-hosted)**

#### **Infrastructure**
- [ ] VMs/Bare-metal provisioned (Terraform/Proxmox/vSphere)
- [ ] k3s/RKE2/kubeadm cluster deployed
- [ ] Load balancer IPs planned (MetalLB pool)
- [ ] Internal DNS or Cloudflare configured
- [ ] Storage backend ready (NFS/Ceph/Longhorn)

#### **Cluster Configuration**
- [ ] Cilium or Calico CNI installed
- [ ] Longhorn or Rook-Ceph CSI (StorageClass: `standard`)
- [ ] MetalLB deployed (L2 or BGP mode)
- [ ] Network Policies enabled

#### **Add-ons**
- [ ] ExternalDNS → Internal DNS/Cloudflare
- [ ] ESO → HashiCorp Vault or Sealed Secrets
- [ ] cert-manager → HTTP-01 or internal CA
- [ ] Velero → MinIO (S3-compatible)

#### **Testing**
- [ ] Ingress reachable via internal/external DNS
- [ ] TLS working (Let's Encrypt or internal CA)
- [ ] MetalLB assigning IPs correctly
- [ ] Velero backup/restore successful

---

### **Cross-Environment Validation**

- [ ] Same app manifests work in both AKS and On-Prem
- [ ] Only overlay values differ (no code changes)
- [ ] Consistent naming: IngressClass, StorageClass, ClusterIssuer
- [ ] GitOps workflow: `git push` → auto-deploy in both
- [ ] Rollback tested: `git revert` → old version restored
- [ ] Policy gates green in both environments
- [ ] No vendor lock-in: can switch provider without app changes

---

## 🎯 Phase 2 Complete When:

| Check | Command | Expected (AKS) | Expected (On-Prem) | Status |
|-------|---------|----------------|-------------------|--------|
| **Argo CD** | `argocd app list` | All synced | All synced | ⬜ |
| **Ingress** | `curl https://demo.domain.com` | HTTP 200 + TLS | HTTP 200 + TLS | ⬜ |
| **DNS** | `nslookup demo.domain.com` | Azure DNS IP | MetalLB IP | ⬜ |
| **Storage** | `kubectl get sc standard` | Azure Disk | Longhorn/Ceph | ⬜ |
| **Secrets** | ESO sync test | From Key Vault | From Vault/Sealed | ⬜ |
| **Policies** | Deploy `:latest` image | ❌ BLOCKED | ❌ BLOCKED | ⬜ |
| **Monitoring** | Open Grafana | Dashboards visible | Dashboards visible | ⬜ |
| **Backup** | `velero restore` test | ✅ Successful | ✅ Successful | ⬜ |
| **GitOps** | `git push` → auto-deploy | ✅ 3-5 min | ✅ 3-5 min | ⬜ |

---

## 🧹 Cleanup

```bash
# Delete cluster
kind delete cluster --name agent-k8s-local

# Remove generated files
rm -rf apps/ clusters/ infrastructure/ policies/ kind-config.yaml
```

---

**Last Updated:** 06.01.2025  
**Status:** Phase 1 ready to start 🚀
