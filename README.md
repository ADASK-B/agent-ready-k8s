# agent-ready-k8s

> **AI-Driven Kubernetes Platform Template**  
> Multi-tenant SaaS platform with self-service tenant creation, hot-reload configuration, and enterprise-grade architecture.

---

## 📊 Architecture Overview

### **Tabelle 1: Data Storage - Where Everything Lives**

| Data Type | Storage | Example | Why Here? | Why NOT Elsewhere? |
|-----------|---------|---------|-----------|-------------------|
| **Tenant Metadata** | PostgreSQL (App-DB) | `org_name="ACME Corp"`, `owner_email` | ✅ Flexible Queries (JOIN, Filter)<br>✅ Backup/Migration easy<br>✅ Independent from K8s | ❌ etcd = no SQL, K8s-internal<br>❌ Loss on cluster migration |
| **K8s Configuration** | etcd (K8s internal DB) | Namespace, RBAC, Quotas | ✅ K8s reads/writes directly<br>✅ Millisecond latency<br>✅ Distributed Consensus (HA) | ❌ PostgreSQL = too slow for K8s<br>❌ No Strong Consistency |
| **User Data (Notes)** | PostgreSQL (in Pod in Namespace) | `note_id=123`, `content="Meeting Notes"` | ✅ ACID transactions<br>✅ Complex queries<br>✅ Proven backups (pg_dump) | ❌ etcd = Max 1.5 MB per key<br>❌ Not designed for app data |
| **Secrets (Passwords)** | etcd (encrypted) OR Azure Key Vault | DB-Password, API-Keys | ✅ K8s-native injection (envFrom)<br>✅ Rotation via ESO<br>✅ Hardware-backed (HSM) | ❌ PostgreSQL = security risk<br>❌ Git = NEVER commit secrets |

---

### **Tabelle 2: Tenant Creation (Self-Service like Azure)**

| Step | Action | Stored Where? | Who Does It? | Latency |
|------|--------|---------------|--------------|---------|
| **1. User registers** | User clicks "Create Organization" | Browser → Backend API | User | - |
| **2. Store metadata** | `INSERT INTO organizations (name, owner)` | PostgreSQL | Backend API | ~10ms |
| **3. Create Namespace** | `kubectl create namespace org-acme` | etcd (via K8s API) | Backend → K8s API | ~50ms |
| **4. Create RBAC** | `kubectl create rolebinding admin` | etcd | Backend → K8s API | ~20ms |
| **5. ResourceQuota** | CPU=10, Memory=20Gi | etcd | Backend → K8s API | ~20ms |
| **6. NetworkPolicy** | Deny-all baseline | etcd | Backend → K8s API | ~20ms |

**Total:** ~120ms = **Self-Service like Azure** ✅

---

### **Tabelle 3: Hot-Reload Config (AI-Threshold Example)**

| Option | Stored Where? | Hot-Reload? | Latency | Why Use? | Why NOT Use? |
|--------|---------------|-------------|---------|----------|--------------|
| **PostgreSQL (Polling)** | `settings` table | ⚠️ YES (5s delay) | 0-5s | ✅ Simple, no extra deps | ❌ DB load, not real-time |
| **Redis Pub/Sub** | Redis key + PUBLISH | ✅ YES | <100ms | ✅ Real-time<br>✅ Multi-pod sync | ⚠️ Extra dependency |
| **ConfigMap + Reloader** | K8s ConfigMap | ⚠️ YES (restart) | ~15s | ✅ K8s-native, GitOps | ❌ Pod restart = downtime |
| **etcd (direct)** | etcd key + Watch API | ✅ YES | <50ms | ✅ K8s-internal available | ❌ Complex, security risk<br>❌ Not designed for apps |

**Recommendation:** PostgreSQL (Source of Truth) + Redis (Hot-Reload) ✅

---

### **Tabelle 4: Why NOT etcd for App Config?**

| Problem | Consequence | Alternative |
|---------|-------------|-------------|
| Not designed for app data | etcd = K8s Control Plane Storage | PostgreSQL for app data |
| Complex RBAC | Pod needs K8s API access = security risk | Redis = app-level, no K8s access needed |
| No native Watch API for apps | 50+ lines boilerplate code | Redis Pub/Sub = 5 lines code |
| Backup/Audit difficult | etcd backup = entire cluster (GB) | PostgreSQL backup = only your data (MB) |
| Scaling limit | Max 8 GB recommended | PostgreSQL+Redis = TB-capable |
| Vendor lock-in | K8s-specific | PostgreSQL+Redis = usable everywhere |

---

### **Tabelle 5: Your System vs. Azure DevOps**

| Feature | Your K8s System | Azure DevOps | Advantage |
|---------|-----------------|--------------|-----------|
| **Multi-Tenancy** | Namespace per Org | Azure Org/Projects | ✅ Same (both self-service) |
| **Tenant Creation** | API → K8s Operator | Azure Portal → ARM | ✅ Same (~100ms) |
| **Hot-Reload Config** | PostgreSQL + Redis Pub/Sub | Azure App Configuration + Event Grid | ✅ Your system faster (<100ms vs. ~500ms) |
| **Feature Flags** | Custom (Redis/DB) | Native (Azure App Config) | ⚠️ Azure better (out-of-box) |
| **Costs** | $0 (self-hosted) | $1-10/month (managed) | ✅ Your system cheaper |
| **Vendor Lock-In** | ❌ NO (Open Source) | ✅ YES (Azure-only) | ✅ Your system portable |
| **Secrets Management** | ESO → Key Vault/Vault | Azure Key Vault (native) | ✅ Same |

---

### **Tabelle 6: End-to-End Workflow**

| Step | User Action | System Reaction | Stored Where? | Latency |
|------|-------------|-----------------|---------------|---------|
| **1. Registration** | "Create Org: ACME Corp" | Backend → PostgreSQL + K8s API | PostgreSQL + etcd | ~120ms |
| **2. Login** | Email + Password | JWT Token via OAuth2-Proxy | - | ~50ms |
| **3. Create Project** | "Create Project: Notes App" | Backend → PostgreSQL (project_id) | PostgreSQL | ~10ms |
| **4. Write Note** | "Meeting with customer" | Backend → PostgreSQL (notes table) | PostgreSQL (in Namespace Pod) | ~10ms |
| **5. Change AI-Threshold** | Slider: 0.75 → 0.90 | PostgreSQL + Redis PUBLISH | PostgreSQL + Redis | ~15ms |
| **6. AI Receives Update** | Redis SUBSCRIBE Event | Pod Memory: `threshold = 0.90` | Pod RAM | <100ms |
| **7. Next AI Request** | Uses new threshold | - | - | - |

---

## 🎯 Core Principles

| Principle | Rule | Why? |
|-----------|------|------|
| **Separation of Concerns** | etcd = K8s, PostgreSQL = App, Redis = Cache | Each system for its purpose |
| **Self-Service** | User creates tenant → API → Operator → Namespace | Like Azure (no manual intervention) |
| **Hot-Reload** | PostgreSQL (Persistent) + Redis (Real-Time) | Best of both worlds |
| **Cloud-Agnostic** | Open Source Stack (K8s, PostgreSQL, Redis) | No vendor lock-in |

---

## 📚 Documentation

- **[Architecture Guide](/docs/architecture/ARCHITECTURE.md)** - Enterprise-grade reference architecture (10/10 quality)
- **[Quickstart](/docs/quickstart/Quickstart.md)** - Setup guide and troubleshooting
- **[Roadmap](/ROADMAP.md)** - Phase checklists and progress tracking

---

## 🚀 Quick Start

```bash
# Phase 1: Local Development (kind cluster)
./setup-template/setup-phase1.sh

# Check status
kubectl get pods -A
kind get clusters
```

---

## 🛠️ Tech Stack

### **Core Infrastructure**
- **Kubernetes:** kind (local), AKS/EKS/GKE (cloud)
- **GitOps:** Argo CD, Kustomize
- **Database:** PostgreSQL (StatefulSet)
- **Cache:** Redis (hot-reload config, Pub/Sub)
- **Secrets:** External Secrets Operator → Azure Key Vault/AWS Secrets Manager/HashiCorp Vault

### **Security**
- **Image Signing:** Cosign (keyless OIDC/KMS/Vault)
- **Policy Engine:** Kyverno/OPA Gatekeeper
- **Network:** NetworkPolicies (deny-all baseline)
- **RBAC:** Multi-tenant isolation per namespace

### **Observability**
- **Metrics:** kube-prometheus-stack (Prometheus + Grafana)
- **Logs:** Loki
- **Traces:** Tempo/OpenTelemetry Collector
- **Dashboards:** SLO Burn Rate, Certificate Expiry, External Probe Health

---

## 🎯 Use Cases

✅ **Multi-tenant SaaS platforms** (like Azure DevOps, GitLab, Shopify)  
✅ **AI/ML platforms** with hot-reload model configs  
✅ **Developer platforms** with self-service project creation  
✅ **Enterprise-grade infrastructure** (ISO 27001, NIS2, SOC 2 ready)

---

## 📄 License

MIT License - see [LICENSE](LICENSE)

---

## 🤝 Contributing

This is an AI-agent-friendly template. All code, docs, and commits must be in **English**.

**Update [`.github/copilot-instructions.md`](.github/copilot-instructions.md)** when making structural changes!
