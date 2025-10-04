# GitHub Copilot Instructions - agent-ready-k8s

> **🎯 Zweck:** Diese Datei dient als **Inhaltsverzeichnis/Wikipedia** für das Projekt.  
> **⚠️ WICHTIG:** Diese Datei muss **immer aktuell** gehalten werden bei Änderungen!  
> **📚 Strategie:** Nur Metadaten hier → Details in `/docs/` (Token-Optimierung)

---

## ⚠️ PRIO 1: WARTUNGS-PFLICHT

**🚨 BEI JEDER STRUKTUR-ÄNDERUNG MUSS DIESE DATEI AKTUALISIERT WERDEN! 🚨**

**Wann updaten:**
- ✅ Neue Scripts/Blocks hinzugefügt → Commands-Sektion updaten
- ✅ Neue Docs-Dateien erstellt → Dokumentations-Struktur erweitern
- ✅ Ordner umbenannt/verschoben → Projekt-Struktur anpassen
- ✅ Neue bekannte Probleme → "Bekannte Probleme" ergänzen
- ✅ Tools/Versionen geändert → Stack-Sektion aktualisieren
- ✅ Phase-Status geändert → Status-Banner updaten

**Warum kritisch:**
- Agents (wie ich) lesen diese Datei zuerst
- Veraltete Infos → falsche Entscheidungen
- Neue Contributors verlassen sich darauf
- Diese Datei = Single Source of Truth für Navigation

---

## 📖 Projekt-Übersicht

**Name:** agent-ready-k8s  
**Typ:** Kubernetes Template Stack (lokal + Cloud)  
**Status Phase 1:** ✅ ABGESCHLOSSEN (1m 10s Runtime, 46/46 Tests)  
**Status Phase 2:** ⏸️ GEPLANT (GitOps + AKS)

**Was ist das?**
Ein vollautomatisches Kubernetes-Setup für lokale Entwicklung (Phase 1) mit optionalem Cloud-Deployment (Phase 2).
- **Phase 1:** Lokaler kind-Cluster + podinfo Demo in ~1 Minute
- **Phase 2:** GitOps mit Flux + Azure AKS Deployment

**Für wen?**
- Entwickler, die schnell lokale K8s-Umgebung brauchen
- Teams, die Production-Ready Template suchen
- Lernende für Kubernetes + GitOps Best Practices

**Quick Start (1 Command):**
```bash
./setup-template/setup-phase1.sh
```
→ Nach 1m 10s läuft http://demo.localhost mit podinfo v6.9.2

---

## 🗂️ Dokumentations-Struktur

### **1. Quick Start** → `/docs/quickstart/`
**Wann nutzen:** Erste Schritte, komplettes Setup von Null, ODER nach Reboot
- `Quickstart.md` - Vollständige Anleitung für Phase 1 Setup
- **Inhalt:** 
  - Tool-Installation, Cluster-Setup, Demo-Deployment
  - ⭐ **Nach Reboot:** Cluster neu starten (3 Commands, ~1 Min)
  - Fast Track (vollautomatisch, 1 Command)
  - Manuelle Schritte (Schritt-für-Schritt)
  - Troubleshooting (7 häufige Probleme)
- **Runtime:** 
  - Erstes Setup: ~4-5 Min (mit Docker-Install + Reboot)
  - Nach Reboot: ~1 Min (Images gecached!)
  - Fast Track: ~1m 10s (Tools vorhanden)
- **Ergebnis:** http://demo.localhost läuft

### **2. Roadmap** → `ROADMAP.md` (Root)
**Wann nutzen:** Überblick über Phase 1 + Phase 2, Fortschritt tracken
- **Inhalt:** Detaillierte Checklisten, Performance-Reports, Kosten
- **Status:** Aktuell (Phase 1 komplett markiert)

### **3. README** → `README.md` (Root)
**Wann nutzen:** Projekt-Übersicht, Features, Credits
- **Inhalt:** Was ist das Projekt, warum existiert es, wer nutzt es
- **Status:** 🚧 Muss aktualisiert werden (neuer Script-Pfad)

---

## 🛠️ Technischer Stack

### **Phase 1 - Lokal (✅ ABGESCHLOSSEN)**
- **Container:** Docker 28.5.0
- **K8s:** kind v0.20.0 (Cluster: agent-k8s-local, K8s v1.27.3)
- **Tools:** kubectl v1.34.1, Helm v3.19.0, Flux CLI v2.7.0, Task 3.45.4
- **Ingress:** ingress-nginx (hostPort-Mode für kind)
- **Demo-App:** podinfo v6.9.2 (2 Replicas)
- **URL:** http://demo.localhost

### **Phase 2 - Cloud (⏸️ GEPLANT)**
- **GitOps:** Flux v2.7.0 (Auto-Deploy bei Git-Push)
- **Cloud:** Azure AKS (Free Tier Control Plane, 3 Nodes)
- **CI/CD:** GitHub Actions (Trivy, Gitleaks, kubeconform)
- **Secrets:** Sealed Secrets (verschlüsselt in Git)
- **TLS:** cert-manager + Let's Encrypt
- **Kosten:** ~88€/Monat (geschätzt)

---

## 📁 Projekt-Struktur

```
agent-ready-k8s/
├── .github/
│   └── copilot-instructions.md    ← Diese Datei (Inhaltsverzeichnis)
├── docs/
│   └── quickstart/
│       └── Quickstart.md          ← Vollständige Setup-Anleitung
├── setup-template/
│   ├── setup-phase1.sh            ← Master-Script (1 Command)
│   └── phase1/                    ← 6 Blocks (action + test)
│       ├── 01-install-tools/
│       ├── 02-create-structure/
│       ├── 03-clone-templates/
│       ├── 04-create-cluster/
│       ├── 05-deploy-ingress/
│       └── 06-deploy-podinfo/
├── apps/podinfo/                  ← FluxCD GitOps Manifeste
│   ├── base/
│   └── tenants/demo/
├── clusters/                      ← Cluster-Konfigurationen
│   ├── local/                     (Phase 1)
│   └── production/                (Phase 2)
├── infrastructure/                ← Shared Infra (Ingress, Sealed Secrets)
├── policies/                      ← OPA/Gatekeeper Policies
├── kind-config.yaml               ← kind Cluster Config (Ports 80/443)
├── ROADMAP.md                     ← Detaillierte Phase 1+2 Checklisten
└── README.md                      ← Projekt-Übersicht
```

---

## 🚀 Wichtigste Commands

### **Phase 1 - Komplettes Setup**
```bash
# Vollautomatisches Setup (1m 10s)
./setup-template/setup-phase1.sh

# Cluster-Status prüfen
kubectl get pods -A
curl http://demo.localhost

# Cluster löschen (Neustart)
kind delete cluster --name agent-k8s-local
rm -rf apps/ clusters/ infrastructure/ policies/ kind-config.yaml
```

### **Nach Reboot - Cluster neu starten** ⭐
```bash
cd ~/agent-ready-k8s

# Option 1: Nur Cluster (Git-Manifeste unverändert, ~1 Min)
./setup-template/phase1/04-create-cluster/create.sh  # ~10s (Images gecached!)
./setup-template/phase1/05-deploy-ingress/deploy.sh  # ~25s
./setup-template/phase1/06-deploy-podinfo/deploy.sh  # ~8s

# Option 2: Vollautomatisch (~1m 10s, überschreibt apps/)
./setup-template/setup-phase1.sh

# Test
curl http://demo.localhost
```

**Warum so schnell nach Reboot?** Docker Images sind gecached (kindest/node, ingress-nginx, podinfo)!

### **Phase 1 - Einzelne Blocks testen**
```bash
# Block 1-2: Tools
./setup-template/phase1/01-install-tools/test.sh

# Block 5: Cluster
./setup-template/phase1/04-create-cluster/test.sh

# Block 7: podinfo
./setup-template/phase1/06-deploy-podinfo/test.sh
```

### **Phase 2 - GitOps (Geplant)**
```bash
# Flux Bootstrap
flux bootstrap github --owner=ADASK-B --repository=agent-ready-k8s --branch=main --path=clusters/local

# Änderungen deployen
git add apps/podinfo/tenants/demo/patch.yaml
git commit -m "feat: scale to 3 replicas"
git push  # → Flux deployed automatisch
```

---

## 🔧 Bekannte Probleme & Fixes

### **Problem: System Pods nicht sofort Ready**
- **Symptom:** Test schlägt fehl direkt nach Cluster-Erstellung
- **Fix:** Retry-Logik (3×2s) in `04-create-cluster/test.sh`
- **Lösung:** ✅ Implementiert

### **Problem: HTTP 503 nach podinfo Deploy**
- **Symptom:** curl http://demo.localhost gibt 503
- **Fix:** Retry-Logik (5×3s) für Ingress-Propagation
- **Lösung:** ✅ Implementiert in `06-deploy-podinfo/test.sh`

### **Problem: kind Port-Mapping 80/443 nicht möglich**
- **Symptom:** NodePort kann nicht auf 80/443 binden
- **Fix:** `hostPort.enabled=true` statt `nodePorts.http=80`
- **Lösung:** ✅ Implementiert in `05-deploy-ingress/deploy.sh`

### **Problem: FluxCD Repo hat keine staging-Manifeste**
- **Symptom:** Clone-Script findet keine Tenant-Overlays
- **Fix:** Fallback-Erstellung in `03-clone-templates/clone.sh`
- **Lösung:** ✅ Implementiert

---

## 📊 Performance-Metriken (Phase 1)

```
Runtime:        1m 9.6s (statt geschätzt 20-30 min)
Tests:          46/46 bestanden (100%)
Setup-Methode:  Vollautomatisch (1 Befehl)
Retry-Fixes:    2 (System Pods, HTTP Endpoint)
```

**Block-Breakdown (Erstes Setup):**
- Tools:      7/7 Tests ✅  ~5s
- Struktur:  10/10 Tests ✅  ~2s
- Manifeste:  5/5 Tests ✅  ~5s
- Cluster:    5/5 Tests ✅ ~17s
- Ingress:    7/7 Tests ✅ ~20s
- podinfo:   12/12 Tests ✅  ~8s

**Nach Reboot (Images gecached):** ⭐
- Cluster:    5/5 Tests ✅ ~10s (statt 17s)
- Ingress:    7/7 Tests ✅ ~25s (statt 45s)
- podinfo:   12/12 Tests ✅  ~8s (unverändert)
- **TOTAL:**              **~43s** 🚀 (statt 1m 10s)

---

## 🎯 Next Steps für Agent

1. **Bei Fragen zum Setup:** Lese `/docs/quickstart/Quickstart.md`
2. **Nach Reboot / "starte es wieder":** Siehe Quickstart.md → "Nach Reboot" Sektion ⭐
3. **Für Phase 1/2 Details:** Lese `ROADMAP.md`
4. **Bei Test-Fehlern:** Prüfe "Bekannte Probleme & Fixes" (oben)
5. **Für Projekt-Kontext:** Lese `README.md`

---

## ⚠️ Wartungs-Regeln

1. **Diese Datei aktualisieren** bei:
   - Neuen Scripts/Blocks
   - Neuen Docs-Dateien
   - Geänderten Commands
   - Neuen bekannten Problemen
   - Struktur-Änderungen

2. **Docs-Dateien aktualisieren** bei:
   - Tool-Versionen ändern
   - Runtime-Verbesserungen
   - Neue Features/Blocks
   - Geänderte Workflows

3. **ROADMAP.md aktualisieren** bei:
   - Abgeschlossenen Tasks
   - Neuen Phase-2-Plänen
   - Performance-Änderungen

---

**Letzte Aktualisierung:** 04.10.2025  
**Version:** Phase 1 Complete (v1.0)
