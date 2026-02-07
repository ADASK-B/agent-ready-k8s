# Cloud Capabilities – What Can You Do?

> **Quick Answer:** Deploy a production-ready, multi-tenant SaaS platform to **any cloud provider** (AKS, EKS, GKE, Oracle Cloud) or **on-premises** using a **single Git repository** with GitOps automation.

---

## 🚀 What This Platform Enables in the Cloud

### 1. Multi-Cloud Deployment (Provider Portable)

Deploy identical applications across multiple cloud providers **without changing application code**:

| Provider | Type | Use Case | Status |
|----------|------|----------|--------|
| **Local (kind)** | Development | Fast local development & testing | ✅ Phase 0/1 Complete |
| **Oracle Cloud Free Tier** | Production (Free) | MVP production deployment (self-managed k3s on VMs) | 🎯 Planned (Phase 4) |
| **Azure (AKS)** | Managed K8s | Enterprise Azure deployments | 📋 Architecture Ready |
| **AWS (EKS)** | Managed K8s | Enterprise AWS deployments | 📋 Architecture Ready |
| **Google Cloud (GKE)** | Managed K8s | Enterprise GCP deployments | 📋 Architecture Ready |
| **On-Premises** | Self-Managed | Data center deployments (kubeadm) | 📋 Architecture Ready |

**Key Benefit:** Write once, deploy anywhere – `apps/` manifests are 100% portable.

---

### 2. Cloud-Native Platform Services

#### ✅ Currently Implemented (Phase 0/1)
- **GitOps Automation:** Argo CD for declarative deployments
- **Container Orchestration:** Kubernetes (kind cluster locally)
- **Ingress/Load Balancing:** NGINX Ingress Controller
- **Data Persistence:** PostgreSQL (config source of truth)
- **Caching/Pub-Sub:** Redis (config hot-reload notifications)
- **Helm Chart Management:** Vendored charts for infrastructure components

#### 🔜 Coming Soon (Phase 2-5)
- **Multi-Tenant SaaS:** Organizations → Projects → Chat hierarchy
- **Config Hot-Reload:** PostgreSQL + Redis Pub/Sub (<100ms updates)
- **Security Controls:** Pod Security Admission, Network Policies, Image Signing
- **Observability:** Prometheus, Loki, Tempo, Grafana
- **Infrastructure as Code:** Terraform for cloud provisioning
- **Disaster Recovery:** Velero backups, PITR for databases

---

### 3. Cloud Provider Integrations

The platform automatically integrates with cloud-native services based on your deployment target:

| Service Type | AKS (Azure) | EKS (AWS) | GKE (Google) | Oracle/On-Prem |
|--------------|-------------|-----------|--------------|----------------|
| **Load Balancer** | Azure Load Balancer | AWS ALB/NLB | Google Cloud Load Balancer | MetalLB |
| **DNS** | Azure DNS | Route 53 | Cloud DNS | CoreDNS + ExternalDNS |
| **Storage** | Azure Disk/Files | EBS/EFS | GCE Persistent Disk | Longhorn/Rook-Ceph |
| **Secrets** | Azure Key Vault | AWS Secrets Manager | GCP Secret Manager | Kubernetes Secrets |
| **Container Registry** | ACR | ECR | GAR | GHCR/Harbor |
| **Monitoring** | Azure Monitor (opt) | CloudWatch (opt) | Cloud Monitoring (opt) | Prometheus Stack |
| **Identity** | Azure AD Workload Identity | IRSA | GKE Workload Identity | Service Accounts |

---

### 4. Multi-Tenancy & Isolation

Deploy secure, isolated environments for multiple customers/teams:

- **Namespace Isolation:** Each tenant gets dedicated Kubernetes namespace(s)
- **Database Row-Level Security (RLS):** PostgreSQL enforces org/project isolation
- **Network Policies:** Default-deny traffic with explicit allowlists
- **Resource Quotas:** CPU/memory limits per tenant
- **RBAC:** Fine-grained access control

**Architecture:** Organizations own Projects; Projects contain Users and Chat sessions.

---

### 5. Developer Experience

#### Local Development (Works Today ✅)
```bash
# One command setup
./setup-template/phase0-template-foundation/setup-phase0.sh

# Access services
# - Argo CD: https://argocd.local
# - PostgreSQL: postgresql://postgres@localhost:5432
# - Redis: redis://localhost:6379
```

#### Cloud Deployment (Coming in Phase 4 🔜)
```bash
# Provision cloud infrastructure
cd infra/terraform/envs/aks  # or eks/gke/onprem
terraform apply

# Deploy applications (automated via Argo CD)
# No manual kubectl commands needed – GitOps handles everything
```

---

### 6. Security & Compliance

| Feature | Status | Description |
|---------|--------|-------------|
| **Pod Security Standards** | 📋 Planned | Enforce "restricted" baseline by default |
| **Image Signing** | 📋 Planned | Cosign-based signature verification |
| **Network Segmentation** | 📋 Planned | Default-deny NetworkPolicies |
| **Secret Management** | ✅ Partial | Kubernetes Secrets (External Secrets Operator planned) |
| **TLS Everywhere** | ✅ Ready | NGINX Ingress with cert-manager |
| **Audit Logging** | 📋 Planned | Config history, org/project lifecycle audit |

---

### 7. Cost Optimization

#### Free Tier Options
- **Local Development:** kind (100% free, runs on laptop)
- **Oracle Cloud Free Tier:** 4 ARM CPUs, 24 GB RAM, 200 GB storage (forever free)
  - ⚠️ **No SLA** – best for MVP/demo, not business-critical production
  - See [ADR-0006](adr/ADR-0006-oracle-cloud-free-tier.md) for details

#### Paid Cloud Options
- **AKS/EKS/GKE:** ~$100-300/month for production-grade clusters
- **Oracle Paid Tier:** ~$100/month with 99.95% SLA

**Recommendation:** Start with Oracle Cloud Free Tier for MVP, migrate to managed Kubernetes (AKS/EKS/GKE) when SLA requirements increase.

---

### 8. What You Can Build

Using this platform, you can deploy:

✅ **Multi-tenant SaaS applications** with organization/project hierarchy  
✅ **Real-time collaboration tools** with WebSocket/SSE support  
✅ **Microservices architectures** with service mesh readiness  
✅ **Data-intensive workloads** with PostgreSQL + Redis  
✅ **Stateful applications** with persistent storage (CSI drivers)  
✅ **API-first services** with OpenAPI/REST conventions  
✅ **Event-driven systems** with Redis Pub/Sub (Kafka/NATS ready)  

---

## 🔍 Quick Start Guides

| I Want To... | Read This |
|--------------|-----------|
| **Understand the architecture** | [ARCHITECTURE.md](architecture/ARCHITECTURE.md) |
| **See project goals & MVP scope** | [goals-and-scope.md](architecture/goals-and-scope.md) |
| **Set up local development** | [PHASE0-SETUP.md](../setup-template/phase0-template-foundation/PHASE0-SETUP.md) |
| **Deploy to Oracle Cloud Free Tier** | [ADR-0006](adr/ADR-0006-oracle-cloud-free-tier.md) |
| **Understand design decisions** | [Architecture Decision Records](adr/) |
| **Troubleshoot cluster issues** | [Boot-Routine.md](quickstart/Boot-Routine.md) |
| **Learn GitOps workflow** | [local-dev.md](quickstart/local-dev.md) |

---

## 📊 Current Implementation Status

| Phase | Focus | Status |
|-------|-------|--------|
| **Phase 0** | Foundation (kind, GitOps, networking) | ✅ Complete |
| **Phase 1** | GitOps transformation | ✅ Complete |
| **Phase 2** | Backend API (Orgs/Projects/Auth) | 🔜 Next |
| **Phase 3** | Frontend UI | 📋 Planned |
| **Phase 4** | Oracle Cloud deployment | 📋 Planned |
| **Phase 5+** | Observability, Policies, Scale | 📋 Planned |

**See:** [Phase Roadmaps](roadmap/) for detailed task lists.

---

## 🎯 Key Differentiators

What makes this cloud platform special:

1. **True Portability:** Same app manifests run on kind, Oracle Cloud, AKS, EKS, GKE, on-prem
2. **GitOps Native:** Zero manual kubectl in production – everything via Git + Argo CD
3. **Config Hot-Reload:** Update configs without pod restarts (<100ms)
4. **Security First:** Fail-closed defaults, signed images, network isolation
5. **Free Production Option:** Oracle Cloud Free Tier for MVP (no cost)
6. **Developer Friendly:** One-command local setup, fast iteration cycles
7. **Enterprise Ready:** Multi-tenancy, RBAC, audit logging, DR planning

---

## 🤔 Common Questions

### Can I run this without cloud providers?
**Yes!** The platform works identically on-premises with self-managed kubeadm clusters.

### Which cloud provider should I choose?
- **Learning/MVP:** Start with kind (local) + Oracle Cloud Free Tier
- **Production (Azure shops):** AKS
- **Production (AWS shops):** EKS
- **Production (Google shops):** GKE
- **Hybrid/multi-cloud:** On-prem kubeadm

### Do I need to rewrite my apps for each cloud?
**No!** Applications use cloud-agnostic abstractions (Kubernetes APIs). Only infrastructure components use provider-specific overlays.

### What about vendor lock-in?
**Minimal risk.** The platform uses standard Kubernetes APIs. Provider-specific code lives only in `clusters/overlays/{aks,eks,gke,onprem}/`.

---

## 📞 Next Steps

1. **Read:** [goals-and-scope.md](architecture/goals-and-scope.md) – Understand project vision
2. **Setup:** [PHASE0-SETUP.md](../setup-template/phase0-template-foundation/PHASE0-SETUP.md) – Run locally in 10 minutes
3. **Explore:** Browse [Architecture Decision Records](adr/) – Learn why we made key choices
4. **Contribute:** See [AGENTS.md](../AGENTS.md) – Contribution guidelines

---

**Last Updated:** 2026-02-07  
**Maintained by:** Platform Team  
**Feedback:** Open an issue or submit a PR
