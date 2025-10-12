# agent-ready-k8s

> **AI-gesteuerte Kubernetes-Plattform-Vorlage**  
> Multi-Tenant SaaS-Plattform mit Self-Service Tenant-Erstellung, Hot-Reload-Konfiguration und Enterprise-Grade-Architektur.

---

## 📊 Architektur-Übersicht

### **Tabelle 1: Datenspeicherung - Wo liegt was?**

| Datentyp | Speicherort | Beispiel | Warum hier? | Warum NICHT woanders? |
|----------|-------------|----------|-------------|-----------------------|
| **Tenant-Metadaten** | PostgreSQL (App-DB) | `org_name="ACME Corp"`, `owner_email` | ✅ Flexible Queries (JOIN, Filter)<br>✅ Backup/Migration einfach<br>✅ Unabhängig von K8s | ❌ etcd = kein SQL, K8s-intern<br>❌ Verlust bei Cluster-Migration |
| **K8s-Konfiguration** | etcd (K8s interne DB) | Namespace, RBAC, Quotas | ✅ K8s liest/schreibt direkt<br>✅ Millisekunden-Latenz<br>✅ Distributed Consensus (HA) | ❌ PostgreSQL = zu langsam für K8s<br>❌ Keine Strong Consistency |
| **User-Daten (Notizen)** | PostgreSQL (im Pod im Namespace) | `note_id=123`, `content="Meeting Notes"` | ✅ ACID-Transaktionen<br>✅ Komplexe Queries<br>✅ Bewährte Backups (pg_dump) | ❌ etcd = Max 1.5 MB pro Key<br>❌ Nicht für App-Daten designed |
| **Secrets (Passwörter)** | etcd (verschlüsselt) ODER Azure Key Vault | DB-Passwort, API-Keys | ✅ K8s-native Injection (envFrom)<br>✅ Rotation via ESO<br>✅ Hardware-backed (HSM) | ❌ PostgreSQL = Sicherheitsrisiko<br>❌ Git = NIEMALS Secrets committen |

---

### **Tabelle 2: Tenant-Erstellung (Self-Service wie Azure)**

| Schritt | Aktion | Wo gespeichert? | Wer macht es? | Latenz |
|---------|--------|-----------------|---------------|--------|
| **1. User registriert sich** | User klickt "Create Organization" | Browser → Backend API | User | - |
| **2. Metadaten speichern** | `INSERT INTO organizations (name, owner)` | PostgreSQL | Backend API | ~10ms |
| **3. Namespace erstellen** | `kubectl create namespace org-acme` | etcd (via K8s API) | Backend → K8s API | ~50ms |
| **4. RBAC erstellen** | `kubectl create rolebinding admin` | etcd | Backend → K8s API | ~20ms |
| **5. ResourceQuota** | CPU=10, Memory=20Gi | etcd | Backend → K8s API | ~20ms |
| **6. NetworkPolicy** | Deny-all Baseline | etcd | Backend → K8s API | ~20ms |

**Gesamt:** ~120ms = **Self-Service wie Azure** ✅

---

### **Tabelle 3: Hot-Reload Config (AI-Threshold Beispiel)**

| Option | Wo gespeichert? | Hot-Reload? | Latenz | Warum nutzen? | Warum NICHT nutzen? |
|--------|-----------------|-------------|--------|---------------|---------------------|
| **PostgreSQL (Polling)** | `settings` Tabelle | ⚠️ JA (5s Verzögerung) | 0-5s | ✅ Einfach, keine Extra-Dependencies | ❌ DB-Last, nicht Echtzeit |
| **Redis Pub/Sub** | Redis Key + PUBLISH | ✅ JA | <100ms | ✅ Echtzeit<br>✅ Multi-Pod Sync | ⚠️ Extra Dependency |
| **ConfigMap + Reloader** | K8s ConfigMap | ⚠️ JA (Restart) | ~15s | ✅ K8s-native, GitOps | ❌ Pod-Restart = Downtime |
| **etcd (direkt)** | etcd Key + Watch API | ✅ JA | <50ms | ✅ K8s-intern vorhanden | ❌ Komplex, Sicherheitsrisiko<br>❌ Nicht für Apps designed |

**Empfehlung:** PostgreSQL (Source of Truth) + Redis (Hot-Reload) ✅

---

### **Tabelle 4: Warum NICHT etcd für App-Config?**

| Problem | Konsequenz | Alternative |
|---------|------------|-------------|
| Nicht für App-Daten designed | etcd = K8s Control Plane Storage | PostgreSQL für App-Daten |
| Komplexe RBAC | Pod braucht K8s API-Zugriff = Sicherheitsrisiko | Redis = App-Level, kein K8s-Zugriff nötig |
| Keine native Watch-API für Apps | 50+ Zeilen Boilerplate-Code | Redis Pub/Sub = 5 Zeilen Code |
| Backup/Audit schwierig | etcd-Backup = gesamter Cluster (GB) | PostgreSQL-Backup = nur deine Daten (MB) |
| Skalierungs-Limit | Max 8 GB empfohlen | PostgreSQL+Redis = TB-fähig |
| Vendor Lock-In | K8s-spezifisch | PostgreSQL+Redis = überall nutzbar |

---

### **Tabelle 5: Dein System vs. Azure DevOps**

| Feature | Dein K8s-System | Azure DevOps | Vorteil |
|---------|-----------------|--------------|---------|
| **Multi-Tenancy** | Namespace pro Org | Azure Org/Projects | ✅ Gleich (beide Self-Service) |
| **Tenant-Erstellung** | API → K8s Operator | Azure Portal → ARM | ✅ Gleich (~100ms) |
| **Hot-Reload Config** | PostgreSQL + Redis Pub/Sub | Azure App Configuration + Event Grid | ✅ Dein System schneller (<100ms vs. ~500ms) |
| **Feature Flags** | Custom (Redis/DB) | Native (Azure App Config) | ⚠️ Azure besser (Out-of-Box) |
| **Kosten** | $0 (self-hosted) | $1-10/Monat (managed) | ✅ Dein System günstiger |
| **Vendor Lock-In** | ❌ NEIN (Open Source) | ✅ JA (Azure-only) | ✅ Dein System portabel |
| **Secrets Management** | ESO → Key Vault/Vault | Azure Key Vault (native) | ✅ Gleich |

---

## 📊 Tabelle 6: Workflow-Übersicht (End-to-End) - NACH SPEICHER-BEREICHEN

---

### **🗄️ BEREICH A: TENANT & INFRASTRUKTUR (PostgreSQL + etcd)**
> **Was:** Org-Erstellung, K8s-Ressourcen (Namespace, Quotas, Network)  
> **Wofür:** Grundlegende Tenant-Isolation und Ressourcen-Limits

| Schritt | User-Aktion | System-Reaktion | Wo gespeichert? | Latenz | Beispiel/Details | ⚠️ GUARDRAILS |
|---------|-------------|-----------------|-----------------|--------|------------------|----------------|
| **1a. Registrierung** | "Create Org: ACME Corp" | Backend → PostgreSQL + K8s API | PostgreSQL + etcd | ~120ms | **Org-Erstellung:**<br>• DB: `organizations` (id, name, owner_email)<br>• K8s: Namespace `org-acme` | **SAGA-Pattern:**<br>• Status: `PENDING` → K8s create → `COMMITTED`<br>• Bei Fehler: `FAILED` + kompensierende Löschung<br><br>**Idempotenz:**<br>• Operation-ID in DB + K8s-Annotation<br>• Verhindert doppelte Org bei Retry |
| **1b. Initial Storage** | System setzt Default: 10GB | Backend → K8s API | etcd + PostgreSQL | ~20ms | **Storage Init:**<br>• K8s: `ResourceQuota` (storage: 10Gi)<br>• DB: `service_configs` (Audit-Log) | **Namespace-Gate:**<br>• Policy blockt Pods bis Label `isolation-ready=true` gesetzt<br>• Verhindert Race-Conditions |
| **1c. Initial CPU/Memory** | System setzt Default: CPU=10, Memory=20Gi | Backend → K8s API | etcd + PostgreSQL | ~20ms | **Compute Init:**<br>• K8s: `ResourceQuota` (cpu: 10, memory: 20Gi)<br>• DB: `service_configs` (Audit-Log) | **Race-free Isolation:**<br>• Onboarding-Job setzt `isolation-ready=true` NACH:<br>&nbsp;&nbsp;1. Default-Deny NetworkPolicy<br>&nbsp;&nbsp;2. ResourceQuotas<br>&nbsp;&nbsp;3. RBAC |
| **1d. NetworkPolicy** | System aktiviert Isolation | Backend → K8s API | etcd | ~20ms | **Network Init:**<br>• K8s: `NetworkPolicy` (deny-all baseline) | **Cluster-Policy-Gate:**<br>• Kyverno/OPA Policy enforced:<br>• Pods in neuen Namespaces = `Pending` bis `isolation-ready=true` |

---

### **🔐 BEREICH B: AUTHENTIFIZIERUNG (JWT Token)**
> **Was:** User-Login, Token-Generierung  
> **Wofür:** Zugriffskontrolle, Session-Management

| Schritt | User-Aktion | System-Reaktion | Wo gespeichert? | Latenz | Beispiel/Details | ⚠️ GUARDRAILS |
|---------|-------------|-----------------|-----------------|--------|------------------|----------------|
| **2. Login** | Email + Passwort | JWT Token via OAuth2-Proxy | - (ephemeral) | ~50ms | **Auth:**<br>• Token: `org_id=123`, `user_role=admin`, `permissions=[...]` | **Sofort-Widerruf:**<br>• **Option A:** Key-Rotation (kurze TTL + Signier-Keywechsel)<br>• **Option B:** JTI-Denylist (Redis/DB) für Notfälle<br><br>**TTL-Strategie:**<br>• Access-Token: 1h (wie Azure AD)<br>• Refresh-Token: 90d (sliding window)<br><br>**Security:**<br>• Token enthält `jti` (JWT ID) für Tracking<br>• Bei Compromise: `jti` in Denylist → Token ungültig |

---

### **📦 BEREICH C: BUSINESS-DATEN (PostgreSQL)**
> **Was:** User-Daten (Projekte, Notizen, Dokumente)  
> **Wofür:** Eigentliche App-Funktionalität

| Schritt | User-Aktion | System-Reaktion | Wo gespeichert? | Latenz | Beispiel/Details | ⚠️ GUARDRAILS |
|---------|-------------|-----------------|-----------------|--------|------------------|----------------|
| **3. Projekt erstellen** | "Create Project: Notes App" | Backend → PostgreSQL | PostgreSQL | ~10ms | **Project:**<br>• Tabelle: `projects` (id, name, org_id) | **Row-Level Security (RLS):**<br>• PostgreSQL-Feature aktiviert<br>• Automatische Filter nach `org_id`<br>• Backend setzt: `SET app.current_org = 123`<br><br>**Policy:**<br>• Tenant-Isolation auf DB-Ebene<br>• Queries sehen nur eigene Org-Daten |
| **4. Notiz schreiben** | "Meeting with customer" | Backend → PostgreSQL | PostgreSQL | ~10ms | **Data:**<br>• Tabelle: `notes` (id, project_id, content) | **RLS + PITR:**<br>• **RLS:** Automatische Filter nach `org_id`<br>• **PITR:** WAL-Archiving aktiv<br>• **Restore-Runbook:** 5-Minuten-RPO<br>• **Backup:** pg_dump täglich + WAL kontinuierlich |

---

### **⚙️ BEREICH D: SERVICE-CONFIGS (PostgreSQL + Redis Hot-Reload)**
> **Was:** App-Einstellungen (AI-Threshold, Email-Retries, Webhooks, Feature-Flags)  
> **Wofür:** Hot-Reload Config ohne Pod-Restart

| Schritt | User-Aktion | System-Reaktion | Wo gespeichert? | Latenz | Beispiel/Details | ⚠️ GUARDRAILS |
|---------|-------------|-----------------|-----------------|--------|------------------|----------------|
| **5a. AI-Threshold** | Slider: 0.75 → 0.90 | PostgreSQL + Redis PUBLISH | PostgreSQL + Redis | ~15ms | **AI Config:**<br>• DB: `service_configs` (service='ai', key='threshold', value='0.90', version=5)<br>• Redis: `PUBLISH config:ai:threshold "version=5"`<br>• Audit: `config_history` | **Versionierung:**<br>• Monoton steigende Version-Nummer<br>• Pub/Sub trägt nur Version (kein Value)<br>• Pod holt Value aus DB bei Version-Erhöhung<br><br>**Resilienz:**<br>• Warm-Load beim Start (alle Configs aus DB)<br>• Reconcile alle 5-10 min (falls PUBLISH verpasst) |
| **5b. Email-Retries** | Max Retries: 3 → 5 | PostgreSQL + Redis PUBLISH | PostgreSQL + Redis | ~15ms | **Email Config:**<br>• DB: `service_configs` (version=12)<br>• Redis: `PUBLISH config:email:max_retries "12"` | **Append-Only History:**<br>• Nie UPDATE auf History-Tabelle<br>• Immer INSERT für neue Änderung<br>• Unveränderlicher Audit-Trail<br>• Speichert: wer, wann, alt, neu, warum |
| **5c. Webhook-URL** | URL: `https://old.com` → `https://new.com` | PostgreSQL + Redis PUBLISH | PostgreSQL + Redis | ~15ms | **Webhook:**<br>• DB: `service_configs` (service='webhook', key='url')<br>• Redis: `PUBLISH config:webhook:url "version=X"` | **Keine Secrets in Redis:**<br>• Redis trägt nur Version/Event-ID<br>• Keine sensiblen Daten in Pub/Sub<br>• Pod lädt Wert aus DB (sicher) |
| **5d. Feature-Flag** | Feature "dark_mode": OFF → ON | PostgreSQL + Redis PUBLISH | PostgreSQL + Redis | ~15ms | **Feature:**<br>• DB: `service_configs` (service='features', key='dark_mode', value='true')<br>• Redis: `PUBLISH config:features:dark_mode "version=Y"` | **Multi-Pod Sync:**<br>• PUBLISH ist Broadcast<br>• Alle 1000 Pods empfangen gleichzeitig<br>• Keine Inkonsistenzen zwischen Pods |

---

### **🔧 BEREICH E: K8S-RESSOURCEN (PostgreSQL + etcd via K8s API)**
> **Was:** Infrastruktur-Limits (Storage, CPU, Memory)  
> **Wofür:** Ressourcen-Management, verhindert noisy neighbor

| Schritt | User-Aktion | System-Reaktion | Wo gespeichert? | Latenz | Beispiel/Details | ⚠️ GUARDRAILS |
|---------|-------------|-----------------|-----------------|--------|------------------|----------------|
| **5i. Storage-Limit** | Quota: 10GB → 50GB | PostgreSQL + K8s API | PostgreSQL + etcd | ~30ms | **Storage:**<br>• DB: `quota_changes` (storage=50, effective_at=NOW())<br>• K8s: `kubectl patch resourcequota` (storage: 50Gi) | **FinOps-Tracking:**<br>• Tabelle `quota_changes` speichert Historie<br>• Felder: org_id, cpu, memory, storage, effective_at, reason, actor<br>• JOIN mit Prometheus für tatsächliche Nutzung<br>• Billing-System nutzt `effective_at` für Abrechnung<br><br>**Erwartung:**<br>• Neue Quota gilt NUR für neue Pods<br>• Laufende Pods behalten alte Limits<br>• UI zeigt: "Änderung aktiv nach Neustart" |
| **5j. CPU-Limit** | CPU: 10 → 20 Cores | PostgreSQL + K8s API | PostgreSQL + etcd | ~30ms | **Compute:**<br>• DB: `quota_changes` (cpu=20, effective_at=NOW())<br>• K8s: `kubectl patch resourcequota` (cpu: 20) | **Abrechnung:**<br>• `effective_at` = Zeitpunkt der Änderung<br>• Billing: "10 Cores 01.10-15.10, 20 Cores ab 16.10"<br>• Prometheus-Metriken für tatsächliche Auslastung<br>• Effizienz-Report: Quota vs. Nutzung |

---

### **🔥 BEREICH F: HOT-RELOAD (Redis Pub/Sub → Pod RAM)**
> **Was:** Services empfangen Config-Updates in Echtzeit  
> **Wofür:** Keine Pod-Restarts, <100ms Latenz

| Schritt | User-Aktion | System-Reaktion | Wo gespeichert? | Latenz | Beispiel/Details | ⚠️ GUARDRAILS |
|---------|-------------|-----------------|-----------------|--------|------------------|----------------|
| **6. Service empfängt** | Redis SUBSCRIBE Event | Pod Memory: neuer Wert | Pod RAM | <100ms | **Mechanismus:**<br>• Background-Thread: `SUBSCRIBE config:*`<br>• Bei Event: Versionsprüfung + DB-Abfrage<br>• Update: `self.config[key] = new_value`<br>• Kein Restart, kein Downtime | **Redis-Härtung:**<br>• **TLS:** Verschlüsselte Verbindung (rediss://)<br>• **ACL:** User-basierte Zugriffsrechte, nur SUBSCRIBE erlaubt<br>• **Keine Secrets:** Redis trägt nur Versions-IDs<br><br>**Resilienz:**<br>• Backoff + Replay bei Reconnect<br>• Pod holt aktuelle Versionen aus DB nach Neustart<br>• Exponentielles Backoff: 1s, 2s, 4s, 8s, max 60s<br><br>**Warm-Load:**<br>• Pod startet → lädt ALLE Configs aus DB<br>• Dann subscribe zu Redis für Updates<br>• Kein "kalter Start" mit fehlenden Configs<br><br>**Reconcile:**<br>• Alle 5-10 min: DB-Version vs. lokale Version<br>• Falls Drift erkannt → Nachladen<br>• Verhindert "verpasste" PUBLISH-Events |
| **7. Nächster Request** | Nutzt neuen Wert | - | - | - | **Beispiele:**<br>• AI: `if score > self.threshold` (0.90)<br>• Email: `retry < self.max_retries` (5)<br>• API: `if rpm > self.rate_limit` → HTTP 429 | **Monitoring:**<br>• Metric: `config_version{org_id, service, key}`<br>• Alert: "Config-Version zwischen Pods unterschiedlich"<br>• Dashboard: Durchschnittliche Hot-Reload-Latenz<br>• Ziel: <100ms vom Backend-UPDATE bis Pod-Anwendung |

---

## 🎯 Kern-Prinzipien - NACH SPEICHER-BEREICHEN

| Prinzip | Regel | Warum? | Beispiel | Anti-Pattern |
|---------|-------|--------|----------|--------------|
| **PostgreSQL = Source of Truth** | Alle Configs → DB (immer) | Audit, Backup, Migration | • `service_configs` Tabelle<br>• `config_history` (Audit-Log)<br>• pg_dump = alle Configs exportiert | ❌ Configs nur in Redis (nicht persistent)<br>❌ Configs nur in etcd (kein Audit) |
| **Redis = Hot-Reload Channel** | Config-Änderung → PUBLISH | Echtzeit (<100ms), Multi-Pod Sync | • `PUBLISH config:ai:threshold "version=5"`<br>• Alle AI-Pods empfangen gleichzeitig<br>• Kein Polling, kein Restart | ❌ DB Polling alle 5s (Delay + Last)<br>❌ ConfigMap ändern → Pod neu starten (Downtime) |
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
│  ├─ config_history (Audit-Log: wer, wann, was)             │
│  └─ quota_changes (FinOps: CPU/Memory/Storage Historie)    │
└─────────────────────────────────────────────────────────────┘
                             ↓ (speichert + notifiziert)
┌─────────────────────────────────────────────────────────────┐
│  Redis (Hot-Reload Channel)                                 │
│  ├─ Channels: config:ai:*, config:email:*, config:api:*    │
│  ├─ TLS verschlüsselt (rediss://)                          │
│  └─ ACL: nur SUBSCRIBE erlaubt, keine Secrets              │
└─────────────────────────────────────────────────────────────┘
                             ↓ (SUBSCRIBE)
┌─────────────────────────────────────────────────────────────┐
│  Pod RAM (Service Memory)                                   │
│  ├─ self.threshold = 0.90  (Hot-Reload <100ms)             │
│  ├─ Warm-Load beim Start (alle Configs aus DB)             │
│  └─ Reconcile alle 5-10 min (falls PUBLISH verpasst)       │
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

## 🎯 MINI-CHECKLIST (Sofort nutzbar)

| # | Guardrail | Beschreibung | Wo implementieren? |
|---|-----------|--------------|-------------------|
| **1** | **Idempotenz & SAGA** | Operation-ID in DB + K8s-Annotation, Status `PENDING/COMMITTED/FAILED`, kompensierende Löschung bei Fehler | Backend API |
| **2** | **Namespace-Gate** | Kyverno/OPA Policy blockt Pods bis Label `isolation-ready=true` gesetzt ist | Cluster-Policy |
| **3** | **RLS aktiv** | Row-Level Security auf PostgreSQL-Ebene, automatische Tenant-Isolation | PostgreSQL |
| **4** | **Config-Versionierung** | Monotone Version-Nummer, Pub/Sub trägt nur org_id + key + version (kein Value) | DB Schema + Backend |
| **5** | **Redis-Härtung** | TLS verschlüsselt, ACL-basierte Zugriffsrechte, keine Secrets in Topics, Warm-Load + Reconcile | Redis Config + Deployment |
| **6** | **FinOps-Tabellen** | `quota_changes` Tabelle mit effective_at, JOIN mit Prometheus-Metriken für Kosten-Reports | PostgreSQL + Prometheus |
| **7** | **JTI-Denylist** | JWT-ID in Denylist für Sofort-Widerruf bei Token-Compromise | Redis/PostgreSQL |
| **8** | **PITR-Runbook** | WAL-Archiving aktiv, dokumentierter Restore-Prozess mit 5-Minuten-RPO | PostgreSQL Config + Doku |
| **9** | **Reconcile-Loop** | Alle 5-10 min: Prüfe DB-Version vs. lokale Config-Version, lade nach bei Drift | Pod Background-Thread |
| **10** | **FinOps-Transparenz** | UI zeigt "Neue Quota gilt ab Restart", `effective_at` Timestamp für Abrechnungs-Genauigkeit | UI + Billing-System |

---

## 📚 Dokumentation

- **[Architecture Guide](/docs/architecture/ARCHITECTURE.md)** - Enterprise-Grade Referenz-Architektur (10/10 Qualität)
- **[Quickstart](/docs/quickstart/Quickstart.md)** - Setup-Guide und Troubleshooting
- **[Roadmap](/ROADMAP.md)** - Phasen-Checklisten und Fortschritt

---

## 🚀 Quick Start

```bash
# Phase 1: Lokale Entwicklung (kind cluster)
./setup-template/setup-phase1.sh

# Status prüfen
kubectl get pods -A
kind get clusters
```

---

## 🛠️ Tech Stack

### **Kern-Infrastruktur**
- **Kubernetes:** kind (lokal), AKS/EKS/GKE (Cloud)
- **GitOps:** Argo CD, Kustomize
- **Datenbank:** PostgreSQL (StatefulSet)
- **Cache:** Redis (Hot-Reload Config, Pub/Sub)
- **Secrets:** External Secrets Operator → Azure Key Vault/AWS Secrets Manager/HashiCorp Vault

### **Sicherheit**
- **Image Signing:** Cosign (keyless OIDC/KMS/Vault)
- **Policy Engine:** Kyverno/OPA Gatekeeper
- **Network:** NetworkPolicies (deny-all baseline)
- **RBAC:** Multi-Tenant-Isolation pro Namespace

### **Observability**
- **Metriken:** kube-prometheus-stack (Prometheus + Grafana)
- **Logs:** Loki
- **Traces:** Tempo/OpenTelemetry Collector
- **Dashboards:** SLO Burn Rate, Certificate Expiry, External Probe Health

---

## 🎯 Use Cases

✅ **Multi-Tenant SaaS-Plattformen** (wie Azure DevOps, GitLab, Shopify)  
✅ **AI/ML-Plattformen** mit Hot-Reload Model-Configs  
✅ **Developer-Plattformen** mit Self-Service Projekt-Erstellung  
✅ **Enterprise-Grade Infrastruktur** (ISO 27001, NIS2, SOC 2 ready)

---

## 📄 Lizenz

MIT License - siehe [LICENSE](LICENSE)

---

## 🤝 Contributing

Dies ist ein AI-agent-freundliches Template. Alle Code, Docs und Commits müssen in **Englisch** sein.

**Update [`.github/copilot-instructions.md`](.github/copilot-instructions.md)** bei strukturellen Änderungen!
