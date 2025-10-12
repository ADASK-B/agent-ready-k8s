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

---

## 🔧 FAQ: Technologie-Entscheidungen

### **Warum KubernetesClient statt dotnet-etcd?**

| Aspekt | `dotnet-etcd` | `KubernetesClient` |
|--------|---------------|-------------------|
| **Was es macht** | Spricht direkt mit etcd | Spricht mit Kubernetes API |
| **Komplexität** | ❌ Sehr low-level, etcd-Keys selbst bauen | ✅ High-level, `CreateNamespace()` fertig |
| **Sicherheit** | ❌ Direkter etcd-Zugriff = Risiko | ✅ K8s RBAC prüft Permissions |
| **Portabilität** | ❌ Nur wenn etcd direkt erreichbar | ✅ Funktioniert mit jedem K8s (AKS, EKS, GKE) |
| **Maintenance** | ❌ etcd-Struktur kann sich ändern | ✅ K8s API ist stabil (Backward-Kompatibilität) |

**Empfehlung:** Nutze `KubernetesClient` (oder Äquivalent in deiner Sprache) für 99% der Fälle.

---

### **Ist KubernetesClient mit jeder Anwendung kompatibel?**

**KURZ: JA! Jede Sprache hat einen K8s Client.**

| Sprache | K8s Client Library | NuGet/npm/pip Package |
|---------|-------------------|-----------------------|
| **C# / .NET** | `KubernetesClient` | `KubernetesClient` |
| **Python** | `kubernetes` | `kubernetes` |
| **Node.js / JavaScript** | `@kubernetes/client-node` | `@kubernetes/client-node` |
| **Go** | `client-go` | `k8s.io/client-go` |
| **Java** | Kubernetes Java Client | `io.kubernetes:client-java` |
| **Rust** | `kube-rs` | `kube` |

**Funktioniert mit ALLEN K8s-Anbietern:**
- ✅ kind (lokal)
- ✅ minikube (lokal)
- ✅ Azure AKS
- ✅ AWS EKS
- ✅ Google GKE
- ✅ On-Prem kubeadm/RKE2
- ✅ OpenShift

**Warum?** Kubernetes API ist standardisiert (k8s.io/api) → funktioniert überall gleich.

---

### **Warum nicht NUR etcd (ohne PostgreSQL)?**

**5 Gründe gegen "nur etcd":**

**1. Kein SQL = Entwickler-Hölle**
- PostgreSQL: `SELECT * FROM notes WHERE project_id = 5` → fertig
- etcd: Alle 1000+ Keys laden, in Code filtern, sortieren → 100x mehr Code

**2. Compliance unmöglich**
- PostgreSQL: `SELECT * FROM config_history WHERE changed_at >= '2025-10-01'` → Excel-Export
- etcd: Kein `WHERE`, kein `GROUP BY` → manuelles Filtern

**3. Backup = Alles oder Nichts**
- PostgreSQL: `pg_restore --schema=org_acme` → Nur diese Org
- etcd: Restore = **gesamter Cluster** → alle Tenants betroffen

**4. etcd ist klein gedacht**
- **1.5 MB pro Key** → Große Dokumente unmöglich
- **8 GB gesamte DB empfohlen** → Bei 1000 Tenants = 8 MB pro Tenant
- PostgreSQL: TB-große Datenbanken problemlos

**5. Entwickler-Ökosystem fehlt**
- PostgreSQL: ORMs, Admin-UIs, Migrations, Cloud-Managed Services
- etcd: Roh-API, kein ORM, keine Tools

---

### **Warum PostgreSQL + etcd + Redis? (Warum nicht nur eines?)**

**Jedes System für seinen Zweck:**

| System | Wofür? | Warum? | Beispiel |
|--------|--------|--------|----------|
| **etcd** | K8s-Objekte (Namespace, Quotas) | K8s liest NUR aus etcd (Millisekunden) | Namespace erstellen |
| **PostgreSQL** | App-Daten + Audit | SQL-Queries, Backup pro Tenant, Compliance | User, Projekte, Notizen, Config-History |
| **Redis** | Hot-Reload Notifications | Pub/Sub für Echtzeit-Updates (<100ms) | AI-Threshold ändern → Pods sofort updaten |

**Warum nicht nur etcd?**
- ❌ Kein SQL (keine komplexen Queries)
- ❌ Kein granulares Backup (nur ganzer Cluster)
- ❌ Nicht für App-Daten designed (1.5 MB Limit)

**Warum nicht nur PostgreSQL?**
- ❌ K8s kennt kein SQL (etcd ist K8s-intern)
- ❌ Keine Echtzeit-Push-Notifications (Redis Pub/Sub schneller)

**Warum nicht nur Redis?**
- ❌ Nicht persistent genug (bei Crash = Daten weg)
- ❌ Kein Audit-Log (wer änderte wann?)

---

### **Wie erstelle ich einen neuen Tenant auf laufender Plattform?**

**User-Perspektive:**
1. Frontend: `https://platform.example.com/register`
2. Formular: "ACME Corp", "admin@acme.com", Passwort
3. Button: "Create Organization"

**Backend (120ms):**

| Schritt | Was passiert | Technologie |
|---------|-------------|-------------|
| **1. API Call** | `POST /api/organizations` | Frontend → Backend |
| **2. DB Insert** | `INSERT INTO organizations (status='PENDING')` | PostgreSQL |
| **3. Namespace** | `kubectl create namespace org-acme` | KubernetesClient → etcd |
| **4. Quotas** | `kubectl create resourcequota` (CPU=10, Memory=20Gi) | KubernetesClient → etcd |
| **5. Network** | `kubectl create networkpolicy` (deny-all) | KubernetesClient → etcd |
| **6. RBAC** | `kubectl create rolebinding` (owner=admin) | KubernetesClient → etcd |
| **7. Gate** | `kubectl label namespace isolation-ready=true` | KubernetesClient → etcd |
| **8. Commit** | `UPDATE organizations SET status='COMMITTED'` | PostgreSQL |

**Ergebnis:** Isolierter Namespace, ready in ~120ms! ✅

**Wo in README?** → Tabelle 6, Bereich A (Zeilen 1a-1d)

---

### **Warum PostgreSQL + Redis für Configs (nicht nur eines)?**

**PostgreSQL = Source of Truth (Persistent):**
- Config-Änderung wird **immer** in DB gespeichert
- Audit-Log: Wer änderte wann was warum?
- Backup/Restore: Bei Disaster → DB restore → alle Configs zurück

**Redis = Hot-Reload Channel (Real-Time):**
- PostgreSQL hat **kein Push-Notification-System**
- Ohne Redis: Pods müssten DB pollen (alle 5s) → DB-Last + Delay
- Mit Redis: `PUBLISH config:ai:threshold "version=5"` → alle Pods sofort (<100ms)

**Warum beide?**
- Nur PostgreSQL = Polling-Delay (0-5s), DB-Last
- Nur Redis = Nicht persistent (Crash = Config weg), kein Audit
- **Beide = Best-of-Both-Worlds** ✅

---

### **Macht Microsoft das auch so?**

**JA, sehr ähnlich!**

| Feature | Dein System | Azure/Microsoft |
|---------|-------------|-----------------|
| **Tenant-Erstellung** | PostgreSQL (Metadata) + etcd (Namespace) | Azure SQL + ARM/Fabric Controller |
| **Hot-Reload Config** | PostgreSQL + Redis Pub/Sub | Azure App Config + Event Grid |
| **Auth** | JWT (1h TTL) | Azure AD Access Token (1h TTL) |
| **Backup** | pg_dump pro Tenant | Azure SQL per-database backup |
| **Audit** | config_history Tabelle | Azure Activity Log |

**Unterschied:**
- Azure: Event Grid (HTTP Webhooks) statt Redis Pub/Sub
- Unser System: Einfacher, keine Firewall-Config nötig, Open Source

**Fazit:** Konzeptionell identisch, nur andere Namen für gleiche Patterns! ✅

---

### **Gilt das auch für lokal (kind/minikube)?**

**JA, exakt das gleiche!**

| Komponente | Lokal (kind) | Cloud (AKS/EKS/GKE) | Unterschied? |
|------------|--------------|---------------------|--------------|
| **KubernetesClient** | ✅ Funktioniert | ✅ Funktioniert | ❌ KEIN Unterschied |
| **PostgreSQL** | ✅ StatefulSet im Cluster | ✅ Azure Database / RDS | ⚠️ Nur Hosting, API gleich |
| **Redis** | ✅ Deployment im Cluster | ✅ Azure Cache / ElastiCache | ⚠️ Nur Hosting, Pub/Sub gleich |
| **etcd** | ✅ In kind eingebaut | ✅ Managed (AKS/EKS) | ❌ KEIN Unterschied (transparent) |
| **Tenant-Erstellung** | ✅ 120ms | ✅ 120ms | ❌ KEIN Unterschied |
| **Hot-Reload** | ✅ <100ms | ✅ <100ms | ❌ KEIN Unterschied |

**Was ist identisch?**
- ✅ Namespace erstellen: `kubectl create namespace` (gleich)
- ✅ PostgreSQL: SQL-Queries (gleich)
- ✅ Redis Pub/Sub: Channels (gleich)
- ✅ KubernetesClient Code: Keine Änderung nötig (gleich)

**Einziger Unterschied:**
- Lokal: PostgreSQL + Redis im Cluster deployen (Helm Charts)
- Cloud: PostgreSQL + Redis als Managed Service nutzen (Azure Database, Azure Cache)

**Vorteil:** Entwickeln auf kind → Deployen auf AKS → **Zero Code Changes!** 🚀

---

### **Was muss die App mitbringen für Tenant-Erstellung?**

**4 Komponenten:**

#### **1. Backend API mit Kubernetes-Zugriff**

**Braucht:**
- ✅ Kubernetes Client Library (KubernetesClient für C#, kubernetes für Python, @kubernetes/client-node für Node.js)
- ✅ ServiceAccount mit RBAC-Permissions (darf Namespaces, ResourceQuotas, NetworkPolicies erstellen)

#### **2. Datenbank-Verbindung (PostgreSQL)**

**Braucht:**
- ✅ PostgreSQL-Instanz (im Cluster oder Managed Service)
- ✅ 4 Tabellen:
  - `organizations` (id, name, owner_email, status, operation_id)
  - `service_configs` (org_id, service, key, value, version)
  - `config_history` (config_id, old_value, new_value, changed_by, changed_at)
  - `quota_changes` (org_id, cpu, memory, storage, effective_at)

#### **3. Redis-Verbindung (für Hot-Reload)**

**Braucht:**
- ✅ Redis-Instanz (im Cluster oder Managed Service)
- ✅ Pub/Sub Support (Standard-Feature)
- ⚠️ Optional für Production: TLS + ACL

#### **4. Frontend (UI für User)**

**Braucht:**
- ✅ Registrierungs-Formular (Org Name, Owner Email, Passwort)
- ✅ API-Call: `POST /api/organizations`

---

### **Minimal-Setup Übersicht**

| Komponente | Was installieren? | Konfiguration |
|------------|-------------------|---------------|
| **Backend** | FastAPI/Node.js/ASP.NET + KubernetesClient | ServiceAccount + RBAC ClusterRole |
| **PostgreSQL** | Helm: `bitnami/postgresql` | 4 Tabellen (organizations, service_configs, config_history, quota_changes) |
| **Redis** | Helm: `bitnami/redis` | Standard-Config (kein TLS für lokal) |
| **Frontend** | React/Vue/Angular App | Registrierungs-Formular + API-Integration |

---

### **Backend RBAC-Permissions (benötigt)**

Backend ServiceAccount braucht folgende Kubernetes-Rechte:

| Ressource | Verben | Warum? |
|-----------|--------|--------|
| **namespaces** | create, get, list, patch, delete | Tenant-Namespaces verwalten |
| **resourcequotas** | create, get, list, patch | CPU/Memory/Storage-Limits setzen |
| **networkpolicies** | create, get, list | Netzwerk-Isolation (deny-all baseline) |
| **rolebindings** | create, get, list | Owner → Admin-Rolle im Namespace |

---

### **Checkliste: Bereit für Tenant-Erstellung?**

- [ ] Backend mit KubernetesClient installiert
- [ ] Backend hat ServiceAccount + RBAC Permissions
- [ ] PostgreSQL läuft (im Cluster oder extern)
- [ ] PostgreSQL hat 4 Tabellen erstellt
- [ ] Redis läuft (im Cluster oder extern)
- [ ] Frontend kann `POST /api/organizations` aufrufen
- [ ] Test: Backend kann Namespaces erstellen (`kubectl auth can-i create namespace`)

**Alles ✅? Dann bereit für ersten Tenant!** 🚀

---

## 🎯 Tenant-Erstellung: End-to-End Flow Chart

### **Tenant sofort erstellen (120ms Total)**

```
┌─────────────────────────────────────────────────────────────────┐
│           TENANT SOFORT ERSTELLEN (120ms Total)                 │
└─────────────────────────────────────────────────────────────────┘


👤 USER (Browser)
│
│  Klickt: "Create Organization: ACME Corp"
│
▼

┌────────────────────────────────────────────────────────────────┐
│  🖥️  BACKEND API                                               │
│                                                                 │
│  ⏱️ 10ms  → PostgreSQL: Org speichern                         │
│              INSERT INTO organizations (name, status='PENDING')│
│              ↓                                                 │
│              💾 PostgreSQL (App-DB): Tenant-Metadaten         │
│                                                                 │
│  ⏱️ 50ms  → Kubernetes: Namespace erstellen                   │
│              kubectl create namespace org-acme                 │
│              ↓                                                 │
│              💾 etcd (K8s-DB): Namespace-Objekt               │
│                                                                 │
│  ⏱️ 20ms  → Kubernetes: CPU/Memory Limits                     │
│              kubectl create resourcequota (cpu=10, memory=20Gi)│
│              ↓                                                 │
│              💾 etcd (K8s-DB): ResourceQuota-Objekt           │
│                                                                 │
│  ⏱️ 20ms  → Kubernetes: Netzwerk-Isolation                    │
│              kubectl create networkpolicy deny-all             │
│              ↓                                                 │
│              💾 etcd (K8s-DB): NetworkPolicy-Objekt           │
│                                                                 │
│  ⏱️ 20ms  → Kubernetes: Admin-Rechte                          │
│              kubectl create rolebinding admin                  │
│              ↓                                                 │
│              💾 etcd (K8s-DB): RoleBinding-Objekt             │
│                                                                 │
│  ⏱️ 5ms   → PostgreSQL: Status updaten                        │
│              UPDATE organizations SET status='COMMITTED'       │
│              ↓                                                 │
│              💾 PostgreSQL (App-DB): Status gespeichert       │
│                                                                 │
│  ✅ Backend behält Objekt im RAM für HTTP-Response            │
└────────────────────────────────────────────────────────────────┘
│
│  HTTP 201: { id: 123, name: "ACME Corp", status: "COMMITTED" }
│  ↓
│  Frontend fügt Org zur lokalen Liste hinzu (kein neuer API-Call!)
│
▼

👤 USER (Dashboard)
│
│  ✅ Tenant "ACME Corp" erscheint SOFORT in Liste!
│
│  User kann JETZT:
│  ├─ ✅ Pods starten (Namespace in etcd ✓)
│  ├─ ✅ Projekte erstellen (Org in PostgreSQL ✓)
│  ├─ ✅ Team einladen (RBAC in etcd ✓)
│  └─ ✅ Alles nutzen (keine Wartezeit!)
```

---

### **Was ist jetzt wo gespeichert?**

```
💾 PostgreSQL (App-Datenbank):
   ├─ organizations: { id: 123, name: "ACME Corp", status: "COMMITTED" }
   ├─ Zweck: Tenant-Metadaten, User-Daten, Audit-Logs
   └─ Geladen: Bei Login, Dashboard-Aufruf (SELECT)

💾 etcd (Kubernetes-Datenbank):
   ├─ Namespace: org-acme
   ├─ ResourceQuota: cpu=10, memory=20Gi, storage=50Gi
   ├─ NetworkPolicy: deny-all (Isolation)
   ├─ RoleBinding: admin für Owner
   ├─ Zweck: K8s-Ressourcen
   └─ Geladen: K8s-Controller watchen LIVE (sofort aktiv!)

💾 Redis (Hot-Reload, später bei Config-Änderungen):
   ├─ Noch nicht genutzt bei Tenant-Erstellung
   └─ Wird genutzt für: Config-Updates (z.B. AI-Threshold ändern)
```

---

### **Timeline (120ms)**

```
  0ms ─────┬───────────────────────────────────────────────────┐
           │ User klickt "Create Org"                          │
           └───────────────────────────────────────────────────┘
           
 10ms ─────┬───────────────────────────────────────────────────┐
           │ ✅ Org in PostgreSQL gespeichert (status=PENDING) │
           │    💾 INSERT INTO organizations                   │
           └───────────────────────────────────────────────────┘
           
 60ms ─────┬───────────────────────────────────────────────────┐
           │ ✅ Namespace in etcd gespeichert                  │
           │    💾 kubectl create namespace → etcd             │
           └───────────────────────────────────────────────────┘
           
 80ms ─────┬───────────────────────────────────────────────────┐
           │ ✅ CPU/Memory Limits in etcd                      │
           │    💾 kubectl create resourcequota → etcd         │
           └───────────────────────────────────────────────────┘
           
100ms ─────┬───────────────────────────────────────────────────┐
           │ ✅ Netzwerk-Isolation in etcd                     │
           │    💾 kubectl create networkpolicy → etcd         │
           └───────────────────────────────────────────────────┘
           
120ms ─────┬───────────────────────────────────────────────────┐
           │ ✅ Admin-Rechte in etcd                           │
           │    💾 kubectl create rolebinding → etcd           │
           │                                                   │
           │ ✅ Status in PostgreSQL (status=COMMITTED)        │
           │    💾 UPDATE organizations                        │
           │                                                   │
           │ ✅ TENANT IST SOFORT NUTZBAR! 🎉                  │
           └───────────────────────────────────────────────────┘
           
           │ Backend sendet: HTTP 201 { id: 123, ... }
           │ Frontend fügt zur Liste hinzu (RAM)
           │
           ▼
           
       👤 USER sieht: "ACME Corp" in Dashboard
       
       ✅ Kann SOFORT Pods starten (etcd hat Namespace)
       ✅ Kann SOFORT Projekte erstellen (PostgreSQL hat Org)
       ✅ Kann SOFORT Team einladen (etcd hat RBAC)
       
       KEINE WARTEZEIT! 🚀
```

---

### **Warum zwei Datenbanken (PostgreSQL + etcd)?**

| Datenbank | Wofür? | Beispiele | Warum? |
|-----------|--------|-----------|--------|
| **PostgreSQL** | App-Daten | • Tenant-Metadaten (Name, Owner, Status)<br>• Business-Daten (Projekte, Notizen)<br>• Audit-Logs (Wer änderte was wann?)<br>• Config-History (AI-Threshold-Änderungen) | ✅ SQL-Queries möglich (JOIN, Filter, Reports)<br>✅ Backup/Restore pro Tenant<br>✅ Bewährte Tools (pg_dump, PITR) |
| **etcd** | K8s-Ressourcen | • Namespace, Quotas<br>• NetworkPolicies, RBAC<br>• Pods, Deployments | ✅ K8s liest NUR aus etcd (Millisekunden-Latenz)<br>✅ K8s-Controller watchen LIVE (Event-Driven)<br>❌ Kein SQL, nicht für App-Daten designed |
| **Redis** | Hot-Reload | • AI-Threshold, Email-Retries<br>• Feature-Flags, Webhooks | ✅ Real-Time Config-Updates (<100ms)<br>✅ Pub/Sub für Multi-Pod-Sync<br>✅ Keine Pod-Restarts nötig |

---

### **Warum sehe ich Tenant sofort im Dashboard?**

```
Backend (nach Tenant-Erstellung):
┌──────────────────────────────────────┐
│ newOrg = {                           │
│   id: 123,                           │
│   name: "ACME Corp",                 │
│   status: "COMMITTED"                │
│ }                                    │
│                                      │
│ Backend behält Objekt im RAM         │
│ Sendet an Frontend: HTTP 201         │
└──────────────────────────────────────┘
           ↓
Frontend (React/Vue):
┌──────────────────────────────────────┐
│ orgList = [                          │
│   { id: 1, name: "Old Org" },        │
│   { id: 123, name: "ACME Corp" } ← ✅ │
│ ]                                    │
│                                      │
│ Fügt zur Liste hinzu (kein SELECT!)  │
│ Re-rendert sofort → User sieht Org   │
└──────────────────────────────────────┘

⚡ Kein neuer API-Call, kein SELECT nötig!
⚡ Frontend nutzt HTTP 201 Response direkt!
```

**Vergleich:**

| Methode | Zeit | DB-Last |
|---------|------|---------|
| ❌ Schlecht: POST → GET /api/organizations → SELECT | 170ms | Hoch (2 Queries) |
| ✅ Optimal: POST → HTTP 201 Response → Frontend fügt hinzu | 120ms | Niedrig (1 Query) |

---

## ⚖️ Tabelle: kubectl/KubernetesClient vs. dotnet-etcd

| Was? | dotnet-etcd (Direkt) | kubectl/KubernetesClient (K8s API) | Gewinner |
|------|---------------------|-----------------------------------|----------|
| **Komplexität** | 200+ Zeilen Code | 5 Zeilen Code | ✅ K8s API |
| **Sicherheit** | Root-Zugriff zu ALLEN Cluster-Daten (auch Secrets!) | RBAC: Nur erlaubte Operationen | ✅ K8s API |
| **Cloud (AKS/EKS/GKE)** | ❌ Funktioniert NICHT (etcd versteckt) | ✅ Funktioniert überall | ✅ K8s API |
| **Lokal (kind/minikube)** | ⚠️ Funktioniert (braucht Zertifikate) | ✅ Funktioniert (automatisch) | ✅ K8s API |
| **Bei K8s-Update** | ❌ Code bricht (etcd-Schema ändert sich) | ✅ Code bleibt (Backward-Kompatibilität) | ✅ K8s API |
| **Fehler-Handling** | ❌ Manuell (etcd gibt nur Key/Value) | ✅ Automatisch (HTTP 409, 403, etc.) | ✅ K8s API |
| **Audit-Log** | ❌ Keine Nachvollziehbarkeit (wer, wann?) | ✅ Jede Aktion geloggt | ✅ K8s API |
| **Backup/Restore** | ❌ Nur gesamter Cluster | ✅ Pro Namespace/Ressource | ✅ K8s API |
| **Testing** | ❌ Braucht echtes etcd | ✅ Mocks möglich | ✅ K8s API |
| **Setup** | ❌ Zertifikate + Endpoints konfigurieren | ✅ 1 Zeile: `InClusterConfig()` | ✅ K8s API |
| **Performance** | 50ms (aber unsicher) | 70ms (sicher validiert) | ⚖️ K8s API (20ms mehr für Sicherheit ok) |
| **Community** | Sehr klein (nur etcd-Experten) | Millionen Entwickler | ✅ K8s API |

---

### 🎯 Fazit: Wann was nutzen?

| Wann? | Was nutzen? | Warum? |
|-------|-------------|--------|
| **Normale App** | ✅ KubernetesClient | Sicher, einfach, funktioniert überall |
| **Cloud (AKS/EKS/GKE)** | ✅ KubernetesClient | dotnet-etcd funktioniert nicht |
| **Tenant erstellen** | ✅ KubernetesClient | 5 Zeilen statt 200+ |
| **Cluster-Backup** | `etcdctl snapshot` | Nur für Admins |
| **App-Entwicklung** | ❌ **NIEMALS dotnet-etcd** | Sicherheitsrisiko + nicht portabel |

**Kurz gesagt:**  
- **dotnet-etcd** = wie Datenbank direkt auf Festplatte schreiben (riskant, komplex)  
- **KubernetesClient** = wie SQL-Datenbank nutzen (sicher, einfach, Standard)

**➡️ Nutze IMMER KubernetesClient!** ✅

---

## 🗺️ Entscheidungsbaum: Was nutzen für Multi-Tenant SaaS?

```
┌─────────────────────────────────────────────────────────────┐
│  Du baust eine Multi-Tenant SaaS-Plattform                  │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │  Tenant erstellen?    │
        └───────────────────────┘
                    │
                    ▼
            ✅ KubernetesClient
            (NICHT dotnet-etcd!)
                    │
                    ├─ CreateNamespaceAsync()
                    ├─ CreateResourceQuotaAsync()
                    └─ CreateNetworkPolicyAsync()
                    
                    
        ┌───────────────────────┐
        │  App-Configs ändern?  │
        └───────────────────────┘
                    │
                    ▼
        ✅ PostgreSQL + Redis Pub/Sub
        (NICHT dotnet-etcd!)
                    │
                    ├─ PostgreSQL: UPDATE service_configs
                    └─ Redis: PUBLISH config:*
```

---

## 🏗️ Kompletter Architektur-Flow: Alle Komponenten

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  🎯 Multi-Tenant SaaS-Plattform: Kompletter Architektur-Flow               │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
        ┌───────────────────────────────────────────────┐
        │  1️⃣ TENANT ERSTELLEN                          │
        │  (Namespace, Quotas, RBAC, NetworkPolicies)  │
        └───────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
        ┌─────────────────────┐         ┌─────────────────────┐
        │  📝 PostgreSQL      │         │  ☸️  Kubernetes API  │
        │  (App-DB)           │         │  (via KubernetesClient) │
        └─────────────────────┘         └─────────────────────┘
                    │                               │
                    │                               ▼
                    │                   ┌─────────────────────┐
                    │                   │  💾 etcd             │
                    │                   │  (K8s-interne DB)   │
                    │                   └─────────────────────┘
                    │
                    ├─ Speichert:
                    │  • organizations (id, name, owner, status)
                    │  • quota_changes (cpu, memory, storage, effective_at)
                    │  • config_history (Audit-Log)
                    │
                    └─ Tool: 
                       ✅ Npgsql / Entity Framework / Dapper


        ┌───────────────────────────────────────────────┐
        │  2️⃣ BUSINESS-DATEN                           │
        │  (User, Projekte, Notizen, Dokumente)        │
        └───────────────────────────────────────────────┘
                                    │
                                    ▼
                        ┌─────────────────────┐
                        │  📝 PostgreSQL      │
                        │  (Im Tenant-Pod)    │
                        └─────────────────────┘
                                    │
                                    ├─ Speichert:
                                    │  • projects (id, name, org_id)
                                    │  • notes (id, content, project_id)
                                    │  • documents (id, file_path)
                                    │
                                    ├─ Features:
                                    │  • Row-Level Security (RLS)
                                    │  • PITR Backup (WAL-Archiving)
                                    │
                                    └─ Tool:
                                       ✅ Npgsql / Entity Framework / Dapper


        ┌───────────────────────────────────────────────┐
        │  3️⃣ APP-CONFIGS (Hot-Reload)                 │
        │  (AI-Threshold, Email-Retries, Feature-Flags)│
        └───────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
        ┌─────────────────────┐         ┌─────────────────────┐
        │  📝 PostgreSQL      │         │  🔥 Redis Pub/Sub    │
        │  (Source of Truth)  │         │  (Hot-Reload Channel)│
        └─────────────────────┘         └─────────────────────┘
                    │                               │
                    ├─ Speichert:                   ├─ Sendet:
                    │  • service_configs            │  • PUBLISH config:ai:threshold
                    │    (service, key, value,      │  • PUBLISH config:email:retries
                    │     version, org_id)          │  • PUBLISH config:features:dark_mode
                    │  • config_history             │
                    │    (old_value, new_value,     ├─ Empfangen:
                    │     changed_by, changed_at)   │  • Pods: SUBSCRIBE config:*
                    │                               │  • Update in RAM (<100ms)
                    ├─ Tool:                        │
                    │  ✅ Npgsql / Dapper           └─ Tool:
                    │                                  ✅ StackExchange.Redis


        ┌───────────────────────────────────────────────┐
        │  4️⃣ K8S-RESSOURCEN ANPASSEN                  │
        │  (CPU/Memory/Storage Quotas erhöhen)         │
        └───────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
        ┌─────────────────────┐         ┌─────────────────────┐
        │  📝 PostgreSQL      │         │  ☸️  Kubernetes API  │
        │  (Audit + FinOps)   │         │  (via KubernetesClient) │
        └─────────────────────┘         └─────────────────────┘
                    │                               │
                    ├─ Speichert:                   ▼
                    │  • quota_changes          ┌─────────────────────┐
                    │    (cpu, memory, storage, │  💾 etcd             │
                    │     effective_at,         │  (K8s-interne DB)   │
                    │     reason, actor)        └─────────────────────┘
                    │                                   │
                    │                                   ├─ Speichert:
                    │                                   │  • ResourceQuota (cpu, memory, storage)
                    │                                   │  • LimitRange
                    │                                   │
                    ├─ Tool:                            └─ Tool:
                    │  ✅ Npgsql / Dapper                  ✅ KubernetesClient.PatchNamespacedResourceQuotaAsync()


        ┌───────────────────────────────────────────────┐
        │  5️⃣ SECRETS (Passwörter, API-Keys)           │
        │  (DB-Passwort, External-API-Keys)            │
        └───────────────────────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │  🔐 External Secrets Operator  │
                    │  (ESO)                        │
                    └───────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
        ┌─────────────────────┐         ┌─────────────────────┐
        │  ☁️  Azure Key Vault│         │  💾 etcd             │
        │  (oder Vault/AWS SM)│         │  (K8s Secret-Objekt)│
        └─────────────────────┘         └─────────────────────┘
                    │                               │
                    ├─ Speichert:                   ├─ Speichert (verschlüsselt):
                    │  • db-password                │  • Secret aus Key Vault
                    │  • api-key-stripe             │  • Auto-Sync via ESO
                    │  • smtp-password              │
                    │                               ├─ Injected in Pod:
                    ├─ Features:                    │  • envFrom: secretRef
                    │  • Auto-Rotation              │  • volumeMount: /secrets/
                    │  • HSM-backed                 │
                    │  • Audit-Log                  └─ Tool:
                    │                                  ✅ ESO erstellt K8s Secret automatisch
                    └─ Tool:
                       ✅ Azure.Security.KeyVault / ESO


        ┌───────────────────────────────────────────────┐
        │  6️⃣ AUTHENTICATION (Login, JWT)              │
        │  (User-Login, Token-Management)              │
        └───────────────────────────────────────────────┘
                                    │
                                    ▼
                        ┌─────────────────────┐
                        │  🔑 JWT Token       │
                        │  (Stateless)        │
                        └─────────────────────┘
                                    │
                                    ├─ Token enthält:
                                    │  • org_id, user_id, role
                                    │  • jti (JWT ID für Widerruf)
                                    │  • exp (1h TTL)
                                    │
                                    ├─ Signiert mit:
                                    │  • RSA Key aus Azure Key Vault
                                    │
                                    └─ Widerruf bei Notfall:
                                       ┌─────────────────────┐
                                       │  🔥 Redis           │
                                       │  (JTI-Denylist)     │
                                       └─────────────────────┘
                                                │
                                                ├─ Speichert:
                                                │  • jti (JWT ID)
                                                │  • TTL = Token Expiry
                                                │
                                                └─ Tool:
                                                   ✅ StackExchange.Redis


        ┌───────────────────────────────────────────────┐
        │  7️⃣ OBSERVABILITY (Metriken, Logs, Traces)   │
        │  (Monitoring, Alerting, Debugging)           │
        └───────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┬───────────────┐
                    ▼                               ▼               ▼
        ┌─────────────────────┐         ┌─────────────────┐  ┌──────────────┐
        │  📊 Prometheus      │         │  📝 Loki        │  │  🔍 Tempo    │
        │  (Metriken)         │         │  (Logs)         │  │  (Traces)    │
        └─────────────────────┘         └─────────────────┘  └──────────────┘
                    │                               │               │
                    ├─ Sammelt:                     ├─ Sammelt:     ├─ Sammelt:
                    │  • CPU/Memory Usage           │  • Pod Logs   │  • Request Spans
                    │  • Request Rate (RPS)         │  • App Logs   │  • Latency
                    │  • Error Rate                 │               │
                    │  • config_version{org,key}    │               │
                    │                               │               │
                    ├─ Speichert:                   ├─ Speichert:   ├─ Speichert:
                    │  • Time-Series (15d-90d)      │  • Object     │  • Object
                    │                               │    Storage    │    Storage
                    │                               │                │
                    ├─ Visualisierung:              └─ Tool:        └─ Tool:
                    │  • Grafana Dashboards            ✅ Promtail     ✅ OpenTelemetry
                    │  • Alerts (PagerDuty)                              Collector
                    │
                    └─ Tool:
                       ✅ kube-prometheus-stack
```

---

## 📋 Tool-Übersicht: Was nutzen für was?

| Komponente | Tool | NuGet Package | Zweck |
|------------|------|---------------|-------|
| **Tenant erstellen** | ✅ KubernetesClient | `KubernetesClient` | Namespace, Quotas, RBAC → etcd |
| **Tenant-Metadaten** | ✅ PostgreSQL | `Npgsql` / `EF Core` | organizations, quota_changes |
| **Business-Daten** | ✅ PostgreSQL | `Npgsql` / `Dapper` | projects, notes, documents |
| **App-Configs (Source of Truth)** | ✅ PostgreSQL | `Npgsql` / `Dapper` | service_configs, config_history |
| **Hot-Reload Channel** | ✅ Redis Pub/Sub | `StackExchange.Redis` | PUBLISH/SUBSCRIBE config:* |
| **Secrets** | ✅ Azure Key Vault + ESO | `Azure.Security.KeyVault` | Passwörter, API-Keys → etcd (via ESO) |
| **JWT Token** | ✅ JWT + Redis | `System.IdentityModel.Tokens.Jwt` | Auth, JTI-Denylist |
| **Metriken** | ✅ Prometheus | - | CPU, Memory, RPS, Error Rate |
| **Logs** | ✅ Loki | - | Pod Logs, App Logs |
| **Traces** | ✅ Tempo | `OpenTelemetry` | Request Spans, Latency |

---

## ❌ Was du NIEMALS nutzen sollst

| ❌ NICHT nutzen | Warum nicht? | ✅ Stattdessen |
|----------------|--------------|----------------|
| **dotnet-etcd** | Root-Zugriff, nicht portabel, komplex | KubernetesClient |
| **Direct etcd Access** | Sicherheitsrisiko, keine Cloud-Support | KubernetesClient |
| **ConfigMap für Hot-Reload** | Pod-Restart = Downtime | PostgreSQL + Redis |
| **Secrets in Git** | NIEMALS Secrets committen! | Azure Key Vault + ESO |
| **Secrets in PostgreSQL** | Sicherheitsrisiko | Azure Key Vault + ESO |

---

```
