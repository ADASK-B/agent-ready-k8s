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

## 📊 Tabelle 6: Workflow-Übersicht (End-to-End) - NACH SPEICHER-BEREICHEN

---

### **🗄️ BEREICH A: TENANT & INFRASTRUKTUR (PostgreSQL + etcd)**
> **Was:** Org-Erstellung, K8s-Ressourcen (Namespace, Quotas, Network)  
> **Wofür:** Grundlegende Tenant-Isolation und Ressourcen-Limits

| Schritt | User-Aktion | System-Reaktion | Wo gespeichert? | Latenz | Beispiel/Details |
|---------|-------------|-----------------|-----------------|--------|------------------|
| **1a. Registrierung** | "Create Org: ACME Corp" | Backend → PostgreSQL + K8s API | PostgreSQL + etcd | ~120ms | **Org-Erstellung:**<br>• DB: `organizations` (id, name, owner_email)<br>• K8s: `kubectl create namespace org-acme` |
| **1b. Initial Storage** | System setzt Default: 10GB | Backend → K8s API | etcd + PostgreSQL | ~20ms | **Storage Init:**<br>• K8s: `ResourceQuota` (storage: 10Gi)<br>• DB: `service_configs` (Audit-Log) |
| **1c. Initial CPU/Memory** | System setzt Default: CPU=10, Memory=20Gi | Backend → K8s API | etcd + PostgreSQL | ~20ms | **Compute Init:**<br>• K8s: `ResourceQuota` (cpu: 10, memory: 20Gi)<br>• DB: `service_configs` (Audit-Log) |
| **1d. NetworkPolicy** | System aktiviert Isolation | Backend → K8s API | etcd | ~20ms | **Network Init:**<br>• K8s: `NetworkPolicy` (deny-all baseline) |

---

### **🔐 BEREICH B: AUTHENTIFIZIERUNG (JWT Token)**
> **Was:** User-Login, Token-Generierung  
> **Wofür:** Zugriffskontrolle, Session-Management

| Schritt | User-Aktion | System-Reaktion | Wo gespeichert? | Latenz | Beispiel/Details |
|---------|-------------|-----------------|-----------------|--------|------------------|
| **2. Login** | Email + Passwort | JWT Token via OAuth2-Proxy | - (ephemeral) | ~50ms | **Auth:**<br>• Token: `org_id=123`, `user_role=admin`, `permissions=[...]` |

---

### **📦 BEREICH C: BUSINESS-DATEN (PostgreSQL)**
> **Was:** User-Daten (Projekte, Notizen, Dokumente)  
> **Wofür:** Eigentliche App-Funktionalität

| Schritt | User-Aktion | System-Reaktion | Wo gespeichert? | Latenz | Beispiel/Details |
|---------|-------------|-----------------|-----------------|--------|------------------|
| **3. Projekt erstellen** | "Create Project: Notes App" | Backend → PostgreSQL | PostgreSQL | ~10ms | **Project:**<br>• Tabelle: `projects` (id, name, org_id) |
| **4. Notiz schreiben** | "Meeting with customer" | Backend → PostgreSQL | PostgreSQL | ~10ms | **Data:**<br>• Tabelle: `notes` (id, project_id, content) |

---

### **⚙️ BEREICH D: SERVICE-CONFIGS (PostgreSQL + Redis Hot-Reload)**
> **Was:** App-Einstellungen (AI-Threshold, Email-Retries, Webhooks, Feature-Flags)  
> **Wofür:** Hot-Reload Config ohne Pod-Restart

| Schritt | User-Aktion | System-Reaktion | Wo gespeichert? | Latenz | Beispiel/Details |
|---------|-------------|-----------------|-----------------|--------|------------------|
| **5a. AI-Threshold** | Slider: 0.75 → 0.90 | PostgreSQL + Redis PUBLISH | PostgreSQL + Redis | ~15ms | **AI Config:**<br>• DB: `service_configs` (service='ai', key='threshold', value='0.90')<br>• Redis: `PUBLISH config:ai:threshold "0.90"`<br>• Audit: `config_history` |
| **5b. AI-Model** | Model: "gpt-4" → "gpt-4o" | PostgreSQL + Redis PUBLISH | PostgreSQL + Redis | ~15ms | **AI Model:**<br>• DB: `service_configs` (key='model', value='gpt-4o')<br>• Redis: `PUBLISH config:ai:model "gpt-4o"` |
| **5c. Email-Retries** | Max Retries: 3 → 5 | PostgreSQL + Redis PUBLISH | PostgreSQL + Redis | ~15ms | **Email Config:**<br>• DB: `service_configs` (service='email', key='max_retries', value='5')<br>• Redis: `PUBLISH config:email:max_retries "5"` |
| **5d. Email-Timeout** | Timeout: 30s → 60s | PostgreSQL + Redis PUBLISH | PostgreSQL + Redis | ~15ms | **Email Timeout:**<br>• DB: `service_configs` (key='timeout_seconds', value='60')<br>• Redis: `PUBLISH config:email:timeout_seconds "60"` |
| **5e. Webhook-URL** | URL: `https://old.com` → `https://new.com` | PostgreSQL + Redis PUBLISH | PostgreSQL + Redis | ~15ms | **Webhook:**<br>• DB: `service_configs` (service='webhook', key='url')<br>• Redis: `PUBLISH config:webhook:url "..."` |
| **5f. Rate-Limit** | Limit: ∞ → 1000 req/min | PostgreSQL + Redis PUBLISH | PostgreSQL + Redis | ~15ms | **API Limit:**<br>• DB: `service_configs` (service='api', key='rate_limit', value='1000')<br>• Redis: `PUBLISH config:api:rate_limit "1000"` |
| **5g. Log-Level** | Level: INFO → DEBUG | PostgreSQL + Redis PUBLISH | PostgreSQL + Redis | ~15ms | **Logging:**<br>• DB: `service_configs` (service='logging', key='level', value='DEBUG')<br>• Redis: `PUBLISH config:logging:level "DEBUG"` |
| **5h. Feature-Flag** | Feature "dark_mode": OFF → ON | PostgreSQL + Redis PUBLISH | PostgreSQL + Redis | ~15ms | **Feature:**<br>• DB: `service_configs` (service='features', key='dark_mode', value='true')<br>• Redis: `PUBLISH config:features:dark_mode "true"` |

---

### **🔧 BEREICH E: K8S-RESSOURCEN (PostgreSQL + etcd via K8s API)**
> **Was:** Infrastruktur-Limits (Storage, CPU, Memory)  
> **Wofür:** Ressourcen-Management, verhindert noisy neighbor

| Schritt | User-Aktion | System-Reaktion | Wo gespeichert? | Latenz | Beispiel/Details |
|---------|-------------|-----------------|-----------------|--------|------------------|
| **5i. Storage-Limit** | Quota: 10GB → 50GB | PostgreSQL + K8s API | PostgreSQL + etcd | ~30ms | **Storage:**<br>• DB: `service_configs` UPDATE value='50'<br>• K8s: `kubectl patch resourcequota` (storage: 50Gi) |
| **5j. CPU-Limit** | CPU: 10 → 20 Cores | PostgreSQL + K8s API | PostgreSQL + etcd | ~30ms | **Compute:**<br>• DB: `service_configs` UPDATE value='20'<br>• K8s: `kubectl patch resourcequota` (cpu: 20) |

---

### **🔥 BEREICH F: HOT-RELOAD (Redis Pub/Sub → Pod RAM)**
> **Was:** Services empfangen Config-Updates in Echtzeit  
> **Wofür:** Keine Pod-Restarts, <100ms Latenz

| Schritt | User-Aktion | System-Reaktion | Wo gespeichert? | Latenz | Beispiel/Details |
|---------|-------------|-----------------|-----------------|--------|------------------|
| **6. Service empfängt** | Redis SUBSCRIBE Event | Pod Memory: neuer Wert | Pod RAM | <100ms | **Mechanismus:**<br>• Background-Thread: `SUBSCRIBE config:*`<br>• Bei Event: `self.config[key] = new_value`<br>• Kein Restart, kein Downtime |
| **7. Nächster Request** | Nutzt neuen Wert | - | - | - | **Beispiele:**<br>• AI: `if score > self.threshold` (0.90)<br>• Email: `retry < self.max_retries` (5)<br>• API: `if rpm > self.rate_limit` → HTTP 429 |

---

## 🎯 Core Principles - NACH SPEICHER-BEREICHEN

| Prinzip | Regel | Warum? | Beispiel | Anti-Pattern |
|---------|-------|--------|----------|--------------|
| **PostgreSQL = Source of Truth** | Alle Configs → DB (immer) | Audit, Backup, Migration | • `service_configs` Tabelle<br>• `config_history` (Audit-Log)<br>• pg_dump = alle Configs exportiert | ❌ Configs nur in Redis (nicht persistent)<br>❌ Configs nur in etcd (kein Audit) |
| **Redis = Hot-Reload Channel** | Config-Änderung → PUBLISH | Echtzeit (<100ms), Multi-Pod sync | • `PUBLISH config:ai:threshold "0.90"`<br>• Alle AI-Pods empfangen gleichzeitig<br>• Kein Polling, kein Restart | ❌ DB Polling alle 5s (Delay)<br>❌ ConfigMap ändern → Pod neu starten |
| **etcd = K8s-Ressourcen ONLY** | Nur CPU, Memory, Storage, Network | K8s-intern, nicht für Apps | • `ResourceQuota` (cpu, memory, storage)<br>• `NetworkPolicy` (deny-all)<br>• `RoleBinding` (RBAC) | ❌ App-Configs in etcd (kein Audit)<br>❌ User-Daten in etcd (1.5 MB Limit) |
| **Separation by Type** | **App-Config** → PostgreSQL+Redis<br>**K8s-Ressourcen** → PostgreSQL+etcd | Klare Trennung | • **App:** AI-Threshold, Email-Retries<br>• **K8s:** CPU-Quota, Storage-Limit | ❌ Alles in einem System mischen |

---

## 📊 Visuelle Übersicht: Wo liegt was?

```
┌─────────────────────────────────────────────────────────────┐
│  PostgreSQL (App-DB)                                        │
│  ├─ organizations (Tenant-Metadaten)                        │
│  ├─ projects (Business-Daten)                               │
│  ├─ notes (User-Daten)                                      │
│  ├─ service_configs (App-Configs + K8s-Ressourcen-Mirror)  │
│  └─ config_history (Audit-Log: wer, wann, was)             │
└─────────────────────────────────────────────────────────────┘
                             ↓ (speichert + notifiziert)
┌─────────────────────────────────────────────────────────────┐
│  Redis (Hot-Reload Channel)                                 │
│  └─ Channels: config:ai:*, config:email:*, config:api:*    │
└─────────────────────────────────────────────────────────────┘
                             ↓ (SUBSCRIBE)
┌─────────────────────────────────────────────────────────────┐
│  Pod RAM (Service Memory)                                   │
│  └─ self.threshold = 0.90  (Hot-Reload <100ms)             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  etcd (K8s Control Plane)                                   │
│  ├─ /registry/namespaces/org-acme                          │
│  ├─ /registry/resourcequotas/org-acme (CPU, Memory, Storage)│
│  ├─ /registry/networkpolicies/org-acme (deny-all)          │
│  └─ /registry/rbac/rolebindings/org-acme (admin)           │
└─────────────────────────────────────────────────────────────┘
```

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
