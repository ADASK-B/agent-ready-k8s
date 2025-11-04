# Local GitOps Development - Inhaltsverzeichnis (ENTWURF)

> **Zweck:** Praktischer Guide für lokale Entwicklung mit Argo CD + kind cluster

---

## 📑 Inhaltsverzeichnis

| # | Bereich | Wofür brauchst du das? |
|---|---------|------------------------|
| [**1**](#1-häufige-fragen--setup-walkthrough) | **🚀 Häufige Fragen + Setup** | Service anpassen? K8s Config ändern? Auf welches Repo hören? Neue App hinzufügen? + Kompletter Setup-Walkthrough |
| [**2**](#2-was-brauchst-du-installiert-prerequisites) | **Was brauchst du installiert?** | Tools installieren (Docker, kind, kubectl, Helm, Argo CD CLI) |
| [**3**](#3-wie-startest-du-den-stack) | **Wie startest du den Stack?** | Cluster hochfahren (1 Befehl → alles läuft) |
| [**4**](#4-repository-struktur-wo-liegt-was) | **Repository-Struktur: Wo liegt was?** | Verstehen wo du was änderst (`apps/`, `helm-charts/`) |
| [**5**](#5-auf-was-hört-dein-argo-cd) | **Auf was hört dein Argo CD?** | Welches Repo, Branch, Ordner? Wie ändern? |
| [**6**](#6-wie-bearbeitest-du-servicesapps) | **Wie bearbeitest du Services/Apps?** | Lokal testen vs GitOps Flow (wann was?) |
| [**7**](#7-wie-änderst-du-argo-cd-config-selbst) | **Wie änderst du Argo CD Config?** | Neue App hinzufügen, Branch umstellen, Sync-Policy ändern |
| [**8**](#8-häufige-befehle-cheatsheet) | **Häufige Befehle (Cheatsheet)** | Schnelle Referenz (sync, logs, port-forward) |
| [**9**](#9-troubleshooting-was-tun-wenn) | **Troubleshooting** | Was tun wenn Pods crashen, Argo CD nicht synced |
| [**10**](#10-best-practices) | **Best Practices** | Fehler vermeiden (DO/DON'T) |

---
---

### **1. 🚀 Häufige Fragen + Setup-Ablauf: Von 0 bis lokale GitOps-Umgebung läuft**

> **Einfache Fragen & Antworten** für Entwickler ohne Kubernetes-Erfahrung.

---

#### **❓ Häufige Fragen für Einsteiger**

| Frage | Antwort |
|-------|---------|
| **🔧 Wie passe ich einen Service/Pod an?** (z.B. mehr Replicas, anderes Image) | **Was du änderst:** Die Konfiguration deines Services liegt in `values.yaml` – das ist eine einfache Datei mit Einstellungen wie "wie viele Kopien sollen laufen?" oder "welches Image soll verwendet werden?"<br><br>**Wie es funktioniert:**<br>• Du änderst Werte in `values.yaml` (z.B. `replicaCount: 3` statt `replicaCount: 1`)<br>• Kubernetes liest diese Datei und startet entsprechend viele Pods<br>• Mit Git pushst du die Änderung → Argo CD sieht den neuen Commit → deployed automatisch<br><br>**Wichtig:** Lokal testen BEVOR du pushst! Erstelle einen Test-Namespace, installiere dort deine geänderte Config, schau ob's funktioniert, dann erst zu Git committen. |
| **⚙️ Wie passe ich Kubernetes-Config an?** (z.B. Namespaces, Policies, Ingress) | **Was ist der Unterschied?**<br>• **Cluster-weite Sachen** (z.B. neue Namespaces, Security Policies) liegen unter `clusters/base/` – das gilt für ALLES im Cluster<br>• **Service-spezifische Sachen** (z.B. Ingress-Route für deine App) liegen unter `helm-charts/infrastructure/<app>/templates/`<br><br>**Beispiel Namespace:** Ein Namespace ist wie ein "Ordner" in Kubernetes – verschiedene Teams können getrennt arbeiten. Du legst eine Datei `namespaces.yaml` an mit Namen + Labels, committed zu Git → Argo CD erstellt den Namespace automatisch.<br><br>**Beispiel Ingress:** Damit deine App von außen erreichbar ist (z.B. `http://myapp.local`), brauchst du eine Ingress-Config – das ist wie ein "Türschild" das sagt "Anfragen an myapp.local gehen zu Service XYZ". |
| **🎯 Wo sage ich, auf welches Repo/Branch gehört werden soll?** | **Was Argo CD macht:** Es überwacht ein Git-Repository und deployed automatisch, was dort committet wird. Aber woher weiß Argo CD WELCHES Repo? Welcher Branch?<br><br>**Die Antwort:** In jeder Argo CD Application-Datei (`apps/base/<app>-app.yaml`) steht:<br>• `repoURL` = welches Git-Repository (z.B. GitHub URL)<br>• `targetRevision` = welcher Branch (z.B. `main` oder `dev`)<br>• `path` = welcher Ordner im Repo (z.B. `helm-charts/infrastructure/podinfo`)<br><br>**Warum wichtig?** Wenn du einen Feature-Branch testest, änderst du `targetRevision: main` zu `targetRevision: feature-xyz` → Argo CD deployed dann aus deinem Feature-Branch statt main! |
| **📦 Wie füge ich eine neue App hinzu?** (z.B. Backend API) | **Was du verstehen musst:**<br>Eine "App" in Argo CD ist eigentlich nur eine Konfigurationsdatei die sagt "Schau in Git-Repo X, Ordner Y, und deploye was dort liegt".<br><br>**3 Teile die zusammengehören:**<br>• **Helm Chart** = Deine App-Definition (Deployment, Service, Ingress) – liegt unter `helm-charts/infrastructure/<app>/`<br>• **Argo CD Application** = Verbindung zwischen Argo CD und deinem Helm Chart – Datei `apps/base/<app>-app.yaml`<br>• **Root App** = Master-Liste aller Apps – enthält `<app>-app.yaml` als Referenz<br><br>**Warum Root App?** Argo CD nutzt "App of Apps" Pattern: Eine Root-App verwaltet alle anderen Apps. Wenn du eine neue App hinzufügst, trägst du sie in Root App ein → Argo CD sieht sie automatisch. |
| **🔄 Wie funktioniert Auto-Sync? Wann deployed Argo CD?** | **Das Konzept:** Argo CD ist wie ein Wachhund der auf Git aufpasst. Alle 3 Minuten schaut er nach: "Gibt's neue Commits? Hat sich was geändert?"<br><br>**Was passiert bei einem Commit:**<br>• Du pushst Code zu Git (z.B. `git push origin main`)<br>• Argo CD wartet bis zu 3 Minuten (Polling-Intervall)<br>• Argo CD sieht: "Oh, Git hat neue Version!" → vergleicht mit Cluster<br>• Unterschied gefunden? → Argo CD deployed automatisch die neue Version<br><br>**Manuell schneller:** Mit `argocd app sync <app>` sagst du "Deploy JETZT, warte nicht 3 Minuten"<br><br>**Ausschalten:** Wenn du Auto-Sync nicht willst (z.B. manuelles Freigabe-Prozess), setze `syncPolicy.automated: null` in der App-Config. |
| **🛠️ Wie teste ich Änderungen OHNE sie live zu deployen?** | **Das Problem:** Du willst nicht direkt in Production testen, sondern erst schauen ob's funktioniert.<br><br>**Die Lösung - Test-Namespace:** Kubernetes hat "Namespaces" = isolierte Bereiche. Argo CD überwacht nur bestimmte Namespaces (z.B. `tenant-demo`, `demo-platform`). Wenn du einen Namespace erstellst der NICHT in Argo CD konfiguriert ist (z.B. `test-myapp`) → Argo CD ignoriert ihn!<br><br>**Warum das gut ist:**<br>• Du kannst dort wild experimentieren ohne dass Argo CD eingreift<br>• Du installierst mit Helm direkt (nicht via Git), testest deine Änderungen<br>• Funktioniert alles? → Committed zu Git → Argo CD deployed dann offiziell<br>• Funktioniert nicht? → Lösche Test-Namespace, keiner merkt's<br><br>**Wichtig:** Test-Namespaces immer aufräumen nach dem Test! |
| **📝 Welche Dateien muss ich ändern für...?** | **Die Logik dahinter:** GitOps bedeutet "Infrastructure as Code" – ALLES ist in Dateien definiert. Hier die Mapping-Regeln:<br><br>**App-Einstellungen** (Image, Replicas, Env-Vars): `values.yaml` im Helm Chart<br>**Kubernetes-Ressourcen** (Service-Port, Ingress-Host): `templates/*.yaml` im Helm Chart<br>**Argo CD Verhalten** (Repo, Branch, Auto-Sync): `apps/base/<app>-app.yaml`<br>**Cluster-weite Settings** (Namespaces, Policies): `clusters/base/`<br><br>**Faustregel:** "App-spezifisch → Helm Chart" vs "Cluster-weit → clusters/" vs "Argo CD Steuerung → apps/" |
| **📦 Wo müssen Helm Charts liegen?** | **Die Struktur erklärt:**<br>Helm Charts sind "Pakete" die deine App definieren. Alle Charts liegen unter `helm-charts/infrastructure/<service-name>/`<br><br>**Warum "infrastructure"?** Trennung der Konzepte:<br>• `helm-charts/infrastructure/` = Die DEFINITION deiner Services (Code, Manifests)<br>• `apps/` = Argo CD Applications (Verbindung zwischen Argo CD und Helm Charts)<br><br>**Struktur eines Charts:**<br>• `Chart.yaml` = Metadaten (Name, Version, Beschreibung)<br>• `values.yaml` = Konfiguration (was sich oft ändert: Image-Tag, Replicas, Ports)<br>• `templates/` = Kubernetes Manifests (deployment.yaml, service.yaml, ingress.yaml)<br><br>**Beispiel:** Podinfo-Chart unter `helm-charts/infrastructure/podinfo/` wird von Argo CD Application `apps/base/podinfo-app.yaml` referenziert. |
| **💡 Was ist ein Helm Chart? Wofür wird er verwendet?** | **Einfach erklärt:** Ein Helm Chart ist ein "Template-Paket" für Kubernetes-Apps.<br><br>**Das Problem ohne Helm:** Du müsstest für jede Umgebung (dev/staging/prod) separate YAML-Dateien pflegen – copy/paste, fehleranfällig, Chaos bei 10+ Dateien.<br><br>**Die Lösung mit Helm:** Du schreibst Templates mit Platzhaltern (z.B. `{{ .Values.replicaCount }}`). Die konkreten Werte stehen in `values.yaml`. Willst du für prod andere Werte? → Erstelle `values-prod.yaml` mit anderen Zahlen!<br><br>**Beispiel:**<br>Template: `replicas: {{ .Values.replicaCount }}`<br>Dev-Values: `replicaCount: 1` → deployed 1 Pod<br>Prod-Values: `replicaCount: 5` → deployed 5 Pods<br><br>**Vorteil:** 1 Chart-Definition → unendlich viele Umgebungen mit unterschiedlichen Werten. DRY-Prinzip (Don't Repeat Yourself). |
| **🆕 Wie füge ich einen neuen Service in K8s ein?** | **Das Konzept verstehen:**<br>"Service in K8s einfügen" heißt eigentlich: Sage Kubernetes "Starte diese Container-App mit diesen Einstellungen".<br><br>**Die 3 Schichten:**<br>1. **Helm Chart** = Deine App-Definition (WAS soll laufen? Welches Image? Welche Ports?)<br>2. **Argo CD Application** = Brücke zwischen Argo CD und Helm Chart (WO im Git liegt der Chart? Welcher Branch?)<br>3. **Root App Integration** = Registriere neue App bei Argo CD (Damit Argo CD sie überhaupt sieht)<br><br>**Der Workflow:**<br>• Helm Chart erstellen = Kubernetes-Manifests schreiben (deployment.yaml, service.yaml)<br>• Argo CD App erstellen = Sage Argo CD "Überwache diesen Chart in Git"<br>• Root App erweitern = Füge neue App zur Master-Liste hinzu<br>• Git Commit → Argo CD sieht neue App → deployed automatisch<br><br>**Wichtig:** Reihenfolge beachten! Erst Chart, dann Argo CD App, dann Root App. |
| **🔄 Wie reagiert Argo CD automatisch auf neue Container-Images?** | **Erst mal klären: Was ist was?**<br>Es gibt 2 getrennte Welten die oft verwechselt werden:<br><br>**1. Container Registry** (z.B. Docker Hub, GitHub Container Registry, ACR):<br>• Hier landen deine **fertigen Container-Images** (kompilierte Apps als Docker-Image)<br>• Beispiel: `ghcr.io/user/backend:v1.2.3` oder `myregistry.azurecr.io/myapp:latest`<br>• Das sind KEINE Helm Charts! Nur ausführbare Container<br><br>**2. Git Repository** (z.B. GitHub):<br>• Hier liegen deine **Helm Charts** (Kubernetes-Manifests + Konfiguration)<br>• Beispiel: `helm-charts/infrastructure/backend/values.yaml`<br>• Der Helm Chart sagt Kubernetes "Starte Container XYZ mit diesen Einstellungen"<br><br>**Der Zusammenhang:**<br>Im Helm Chart (`values.yaml`) steht WELCHES Container-Image verwendet werden soll:<br>```yaml<br>image:<br>  repository: ghcr.io/user/backend  # Registry-URL<br>  tag: v1.2.3                       # Welche Version?<br>```<br><br>**Das grundlegende Problem:**<br>Argo CD überwacht **NUR Git**, NICHT Container-Registries!<br><br>**Beispiel-Szenario:**<br>1. Du entwickelst deine App, baust ein neues Docker-Image: `backend:v1.2.4`<br>2. Du pushst das Image zur Registry: `docker push ghcr.io/user/backend:v1.2.4`<br>3. **Argo CD merkt nichts!** Warum? Der Helm Chart in Git hat immer noch `tag: v1.2.3`<br>4. Solange du den **Tag im Helm Chart** (Git) nicht änderst, deployed Argo CD die alte Version<br><br>**Warum ist das so?** GitOps-Prinzip: "Git ist die einzige Wahrheit".<br>Argo CD deployed nur was in Git committed ist, nicht was in einer Registry liegt.<br><br>**Die Lösungen - Automatisches Image-Tag Update:**<br><br>• **Argo CD Image Updater** (Extra-Tool):<br>  - Überwacht deine Registry automatisch<br>  - Sieht neues Image (`v1.2.4`) → öffnet `values.yaml` → ändert `tag: v1.2.3` zu `tag: v1.2.4`<br>  - Committed die Änderung zu Git → Argo CD sieht Commit → deployed neue Version<br><br>• **CI/CD Pipeline** (z.B. GitHub Actions, GitLab CI):<br>  - Nach jedem Docker Build: Script ändert automatisch `values.yaml`<br>  - Beispiel: `yq -i '.image.tag = "v1.2.4"' helm-charts/infrastructure/backend/values.yaml`<br>  - Git commit + push → Argo CD deployed<br><br>• **Webhooks** (advanced):<br>  - Registry sendet Notification bei neuem Image → dein API-Endpoint → Script updated Git → Argo CD deployed<br><br>**Wichtig zu verstehen:**<br>• Registry = Nur Container-Images (deine ausführbare App)<br>• Git = Helm Charts + Config (sagt Kubernetes WAS deployed wird)<br>• Helm Charts landen NIEMALS in der Registry, nur in Git!<br>• Alle Lösungen führen über Git, weil das der GitOps-Weg ist |
| **🚨 Was tun wenn Pods nicht starten?** | **Verstehe die Fehler-Arten:**<br>Kubernetes hat verschiedene Status-Meldungen die dir sagen WAS falsch ist:<br><br>**ImagePullBackOff** = Kubernetes kann das Container-Image nicht herunterladen (Image-Name falsch? Registry nicht erreichbar? Authentifizierung fehlt?)<br><br>**CrashLoopBackOff** = Dein Container startet, crasht sofort, Kubernetes versucht's wieder → Endlosschleife. Problem liegt IM Code oder Config (z.B. falsche Env-Variablen).<br><br>**Pending** = Kubernetes findet keine Ressourcen (z.B. "brauche 8GB RAM, aber Node hat nur 4GB frei").<br><br>**Debugging-Workflow:**<br>• `kubectl get pods` = Status anzeigen (welcher Fehler?)<br>• `kubectl describe pod` = Detaillierte Info (Events, Fehler-Messages)<br>• `kubectl logs` = Was sagt die App selbst? (Logs lesen!)<br>• `kubectl get events` = Cluster-Events (oft stehen da Hinweise)<br><br>**Wichtig:** Fehler von AUSSEN nach INNEN debuggen (Cluster → Pod → Container → App-Logs). |

---
## 📋 Geplante Sections

### **2. Was brauchst du installiert? (Prerequisites)**

| Tool | Zweck | Wo herunterladen | Wie installieren | Wie testen |
|------|-------|------------------|------------------|------------|
| **Docker** | Container Runtime (kind braucht Docker) | docker.com | `brew install docker` / apt / installer | `docker --version` |
| **kind** | Lokales Kubernetes (Cluster in Docker) | kind.sigs.k8s.io | `brew install kind` / binary | `kind version` |
| **kubectl** | Kubernetes CLI (Befehle ans Cluster) | kubernetes.io | `brew install kubectl` / binary | `kubectl version --client` |
| **Helm** | Package Manager (Charts installieren) | helm.sh | `brew install helm` / binary | `helm version` |
| **Argo CD CLI** | GitOps Tool (Apps managen) | argo-cd.readthedocs.io | `brew install argocd` / binary | `argocd version --client` |
| **Git** | Version Control (Code pushen/pullen) | git-scm.com | Meist vorinstalliert | `git --version` |
| **VS Code** *(optional)* | Editor mit Kubernetes Plugins | code.visualstudio.com | Installer | Extensions: Kubernetes, YAML |
| **k9s** *(optional)* | Terminal UI (schneller als kubectl) | k9scli.io | `brew install k9s` / binary | `k9s version` |

**Mindestanforderungen:**
- Docker muss laufen (`docker ps` funktioniert)
- Alle Tools im `$PATH` verfügbar

---

### **3. Wie startest du den Stack?**

| Was | Befehl | Was passiert | Dauer | Ergebnis |
|-----|--------|--------------|-------|----------|
| **Kompletter Stack** | `./setup-template/phase0-template-foundation/setup-phase0.sh` | kind cluster + Argo CD + PostgreSQL + Redis + Ingress + podinfo | ~5 min | Lokaler GitOps-Stack läuft |
| **Nur Cluster** | `kind create cluster --config kind-config.yaml` | Leeres Kubernetes | ~1 min | Cluster ohne Apps |
| **Stack nach Reboot** | Siehe `docs/quickstart/Boot-Routine.md` | Docker starten → kind Cluster startet automatisch | ~2 min | Stack läuft wieder |

**Nach dem Start:**
```bash
# Cluster Check
kubectl get nodes          # Status: Ready
kubectl get pods -A        # Alle Pods: Running

# Argo CD UI öffnen
# 1. /etc/hosts eintragen: 127.0.0.1 argocd.local
# 2. Browser: http://argocd.local
# 3. Login: admin / (siehe Befehl unten)
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

---

### **4. Repository-Struktur: Wo liegt was?**

| Ordner | Was liegt da | Wofür | Änderst du oft? |
|--------|--------------|-------|-----------------|
| `apps/base/` | Argo CD Application Manifests (root-app, ingress, postgres, redis, podinfo) | Argo CD weiß von hier, welche Apps es managen soll | ⚠️ Selten (nur bei neuen Apps) |
| `helm-charts/infrastructure/` | Vendored Helm Charts (ingress-nginx, postgresql, redis, podinfo) | Die eigentlichen Deployments, Services, ConfigMaps | 🔴 Oft (hier änderst du Replicas, Images, Config) |
| `clusters/base/` | Shared Configs (Policies, Namespaces) | Cluster-weite Einstellungen | ⚠️ Selten |
| `setup-template/` | Setup-Scripts (setup-phase0.sh) | Automatisiertes Setup | 🟢 Nie (nur ausführen) |
| `docs/` | Architektur, ADRs, Runbooks | Dokumentation | 🟢 Nie (nur lesen) |
| `kind-config.yaml` | kind Cluster Konfiguration (Ports 80/443) | Cluster-Definition | 🟢 Nie (nur bei Cluster-Neuanlage) |

**Wichtig:**
- Argo CD schaut auf `apps/base/` → dort stehen die "Pointer" zu den Helm Charts
- Die Helm Charts in `helm-charts/infrastructure/` sind die echten Configs

---

### **5. Auf was hört dein Argo CD?**

| Frage | Antwort | Wie prüfen | Wie ändern |
|-------|---------|------------|------------|
| **Welches Git Repo?** | `https://github.com/ADASK-B/agent-ready-k8s` | `kubectl get application podinfo -n argocd -o yaml \| grep repoURL` | Ändere `repoURL` in `apps/base/<app>-app.yaml` |
| **Welcher Branch?** | `main` | `kubectl get application podinfo -n argocd -o yaml \| grep targetRevision` | Ändere `targetRevision` in `apps/base/<app>-app.yaml` |
| **Welcher Ordner?** | `helm-charts/infrastructure/podinfo` (z.B.) | `kubectl get application podinfo -n argocd -o yaml \| grep path` | Ändere `path` in `apps/base/<app>-app.yaml` |
| **Wie oft polled Argo CD?** | Alle 3 Minuten (Standard) | `kubectl get application podinfo -n argocd -o yaml \| grep timeout` | ConfigMap `argocd-cm` ändern (nicht empfohlen) |
| **Auto-Sync an?** | Ja (prune + selfHeal) | `kubectl get application podinfo -n argocd -o yaml \| grep automated` | `syncPolicy.automated` in `apps/base/<app>-app.yaml` |

**Beispiel: podinfo hört auf...**
```yaml
# apps/base/podinfo-app.yaml
spec:
  source:
    repoURL: https://github.com/ADASK-B/agent-ready-k8s  # Dieses Repo
    targetRevision: main                                  # Dieser Branch
    path: helm-charts/infrastructure/podinfo              # Dieser Ordner
```

---

### **6. Wie bearbeitest du Services/Apps?**

#### **A. Lokal testen (OHNE Git Push) - Schnelles Experimentieren**

| Schritt | Befehl | Was passiert | Wann nutzen |
|---------|--------|--------------|-------------|
| **1. Ändern** | `vim helm-charts/infrastructure/podinfo/values.yaml` | Replicas z.B. auf 3 setzen | Immer zuerst |
| **2. Preview** | `helm template podinfo ./helm-charts/infrastructure/podinfo/` | Zeigt YAML Output | Syntax-Check |
| **3. Validieren** | `helm template podinfo ./helm-charts/infrastructure/podinfo/ \| kubeconform --strict` | Prüft K8s Spec | Vor jedem Deploy |
| **4. Test-Deploy** | `kubectl create ns test-podinfo && helm upgrade --install podinfo ./helm-charts/infrastructure/podinfo/ -n test-podinfo` | Deployed in Test-Namespace | Funktions-Check |
| **5. Testen** | `kubectl port-forward svc/podinfo -n test-podinfo 9898:9898` | App lokal erreichbar | Smoke Test |
| **6. Cleanup** | `kubectl delete ns test-podinfo` | Test-Namespace löschen | Nach jedem Test |

**Wichtig:** Test-Namespace wird NICHT von Argo CD gemanaged! → Sicheres Experimentieren

---

#### **B. GitOps Flow (MIT Git Push) - Echtes Deployment**

| Schritt | Befehl | Was passiert | Branch? |
|---------|--------|--------------|---------|
| **1. Feature Branch** | `git checkout -b feat/podinfo-replicas` | Neuer Branch (oder direkt main) | ⚠️ Empfohlen für größere Änderungen |
| **2. Ändern** | `vim helm-charts/infrastructure/podinfo/values.yaml` | Replicas auf 3 setzen | - |
| **3. Committen** | `git add helm-charts/ && git commit -m "feat: increase podinfo replicas"` | Änderung in Git | - |
| **4. Push** | `git push origin feat/podinfo-replicas` | Zu GitHub pushen | Branch oder main |
| **5. Argo CD Sync** | *Automatisch nach 3 min* ODER `argocd app sync podinfo` | Argo CD zieht Änderung, deployed | main Branch |
| **6. Prüfen** | `kubectl get pods -n tenant-demo` | 3 Pods laufen | - |

**Frage: Branch oder main?**
- **Direkt auf main:** Schnell, aber riskant (keine Review)
- **Feature Branch → PR → main:** Sicherer (GitHub Actions prüft, Review möglich)

**Argo CD hört NUR auf `main` Branch!**
→ Feature Branch wird NICHT automatisch deployed
→ Du musst mergen nach main, dann synced Argo CD

---

### **7. Wie änderst du Argo CD Config selbst?**

| Was ändern | Wo ändern | Beispiel | Wann nötig |
|------------|-----------|----------|------------|
| **Neue App hinzufügen** | `apps/base/` → neue `<app>-app.yaml` + in `root-app.yaml` eintragen | Backend API deployen | Neue Services |
| **Branch wechseln** | `apps/base/<app>-app.yaml` → `targetRevision: dev` | Auf dev-Branch zeigen | Multi-Environment |
| **Sync-Policy ändern** | `apps/base/<app>-app.yaml` → `syncPolicy.automated: null` | Auto-Sync ausschalten | Debug-Modus |
| **Repo wechseln** | `apps/base/<app>-app.yaml` → `repoURL: https://...` | Anderes Repo nutzen | Fork/Mirror |

**Beispiel: podinfo von main auf dev Branch umstellen**
```yaml
# apps/base/podinfo-app.yaml
spec:
  source:
    repoURL: https://github.com/ADASK-B/agent-ready-k8s
    targetRevision: dev  # ← HIER ändern (war: main)
    path: helm-charts/infrastructure/podinfo
```

Nach Änderung: **Committen + Pushen**, dann `argocd app sync root` (Root App synced → alle Child Apps updaten)

---

### **8. Häufige Befehle (Cheatsheet)**

| Task | Befehl | Output |
|------|--------|--------|
| **Alle Apps anzeigen** | `kubectl get applications -n argocd` | Liste mit Sync-Status |
| **App Status prüfen** | `argocd app get podinfo` | Detaillierter Status, letzte Sync-Zeit |
| **App manuell syncen** | `argocd app sync podinfo --prune` | Forciert Sync (nicht auf 3min warten) |
| **App diff anzeigen** | `argocd app diff podinfo` | Was würde sich ändern? |
| **Logs anschauen** | `kubectl logs -n tenant-demo deployment/podinfo -f` | Live Logs |
| **Port-Forward** | `kubectl port-forward svc/podinfo -n tenant-demo 9898:9898` | App lokal erreichbar |
| **Argo CD UI** | Browser: `http://argocd.local` | Web Interface |
| **Argo CD Login CLI** | `argocd login argocd.local --username admin --password $(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" \| base64 -d)` | CLI authentifizieren |

---

### **9. Troubleshooting: Was tun wenn...**

| Problem | Ursache | Lösung | Befehl |
|---------|---------|--------|--------|
| **Argo CD synced nicht** | Git Polling noch nicht durch | Manuell syncen | `argocd app sync podinfo --hard-refresh` |
| **Pod crasht** | Image falsch / Ressourcen fehlen | Logs + Events prüfen | `kubectl describe pod <name> -n <namespace>` |
| **Ingress 404** | /etc/hosts fehlt / Ingress Controller down | /etc/hosts + Ingress Pods prüfen | `kubectl get ingress -A` + `kubectl get pods -n ingress-nginx` |
| **PostgreSQL nicht erreichbar** | Service falsch / Pod down | Service + Pod prüfen | `kubectl get svc,pods -n demo-platform` |
| **Argo CD UI lädt nicht** | argocd-server Pod down | Pod restarten | `kubectl rollout restart deployment argocd-server -n argocd` |
| **Nach Reboot alles down** | Docker nicht gestartet | Boot Routine folgen | Siehe `docs/quickstart/Boot-Routine.md` |

---

### **10. Best Practices**

| ✅ DO | ❌ DON'T | Warum? |
|-------|----------|--------|
| Immer lokal testen (Test-Namespace) | Direkt auf main pushen ohne Test | Kaputte Configs vermeiden |
| `helm template \| kubeconform` vor Push | `kubectl apply` direkt auf Argo CD Namespace | Argo CD Drift vermeiden |
| Feature Branch für größere Änderungen | Secrets in Git committen | Security / Code Review |
| Vendored Helm Charts nutzen | Externe Helm Repos in Argo CD | Reproduzierbarkeit |
| Images mit Digest (`@sha256:...`) | `:latest` Tags | Immutability (enforce-image-digests.yml) |


#### **📋 Kompletter Setup-Walkthrough (für Erstes Mal)**

> Nur beim allerersten Setup folgen - danach nutze die FAQ oben!

#### **Phase 1: Tools installieren** (einmalig)

```bash
# 1. Docker installieren (Ubuntu/Debian Beispiel)
sudo apt update
sudo apt install docker.io -y
sudo systemctl start docker
sudo usermod -aG docker $USER  # Damit du ohne sudo arbeiten kannst
newgrp docker                   # Gruppe aktivieren (oder neu einloggen)

# Test
docker --version
docker ps  # Sollte laufen (keine Fehlermeldung)

# 2. kind installieren
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
kind version

# 3. kubectl installieren
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
kubectl version --client

# 4. Helm installieren
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# 5. Argo CD CLI installieren
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/argocd
argocd version --client

# 6. Optional: k9s installieren (Terminal UI, sehr empfohlen!)
curl -sS https://webinstall.dev/k9s | bash
export PATH="$HOME/.local/bin:$PATH"
k9s version
```

**✅ Checkpoint:** Alle Befehle (`docker`, `kind`, `kubectl`, `helm`, `argocd`) funktionieren ohne Fehler.

---

#### **Phase 2: Repository clonen**

```bash
# 1. Ins Arbeitsverzeichnis wechseln
cd ~/Dev  # Oder wo du deine Projekte hast

# 2. Repo clonen
git clone https://github.com/ADASK-B/agent-ready-k8s.git
cd agent-ready-k8s

# 3. Branch checken (sollte main sein)
git branch
git status
```

**✅ Checkpoint:** Du bist in `~/Dev/agent-ready-k8s` und siehst `README.md`, `apps/`, `helm-charts/`, etc.

---

#### **Phase 3: Stack starten**

```bash
# Setup-Script ausführen (DAS IST DER WICHTIGSTE BEFEHL!)
./setup-template/phase0-template-foundation/setup-phase0.sh

# Was passiert automatisch:
# - kind Cluster erstellen (mit Ports 80/443)
# - Ingress-Nginx installieren (Helm)
# - PostgreSQL installieren (Helm)
# - Redis installieren (Helm)
# - Argo CD installieren (Manifest)
# - podinfo Demo-App installieren (Helm)
# - 65 Tests laufen durch

# Du siehst am Ende:
# ✅ All 65 tests passed!
```

**✅ Checkpoint:** Script endet mit `All tests passed`, keine Fehler.

---

#### **Phase 4: Zugriff testen**

```bash
# 1. /etc/hosts editieren (damit argocd.local und demo.localhost funktionieren)
sudo bash -c 'cat >> /etc/hosts << EOF
127.0.0.1 argocd.local
127.0.0.1 demo.localhost
EOF'

# 2. Cluster checken
kubectl get nodes
# Erwartet: 1 Node, Status: Ready

kubectl get pods -A
# Erwartet: Alle Pods Running (argocd, ingress-nginx, demo-platform, tenant-demo)

# 3. Argo CD Passwort holen
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
# Kopier das Passwort!

# 4. Argo CD UI öffnen (Browser)
# URL: http://argocd.local
# User: admin
# Pass: (das Passwort von oben)

# 5. podinfo testen (Browser oder curl)
curl http://demo.localhost
# Erwartet: JSON mit {"hostname": "podinfo-xxx", "version": "6.9.2", ...}
```

**✅ Checkpoint:**
- Argo CD UI zeigt 5 Apps (root, ingress-nginx, postgresql, redis, podinfo), alle grün/Synced
- podinfo antwortet auf http://demo.localhost

---

#### **Phase 5: Erste Änderung machen (Testlauf)**

**Szenario:** podinfo von 2 auf 3 Replicas erhöhen

```bash
# 1. Helm Chart ändern
vim helm-charts/infrastructure/podinfo/values.yaml
# Ändere:
# replicaCount: 2  →  replicaCount: 3

# 2. Lokal testen (OHNE Git Push) - Test-Namespace
kubectl create namespace test-podinfo

helm upgrade --install podinfo ./helm-charts/infrastructure/podinfo/ \
  --namespace test-podinfo \
  --set replicaCount=3

# 3. Prüfen
kubectl get pods -n test-podinfo
# Erwartet: 3 Pods Running

# 4. Funktionstest
kubectl port-forward svc/podinfo -n test-podinfo 9898:9898 &
curl http://localhost:9898
# Erwartet: JSON Response

# 5. Cleanup Test-Namespace
kubectl delete namespace test-podinfo

# 6. Jetzt ECHT deployen via GitOps
git add helm-charts/infrastructure/podinfo/values.yaml
git commit -m "feat: increase podinfo replicas to 3"
git push origin main

# 7. Argo CD synced automatisch (3 Minuten warten ODER manuell triggern)
argocd app sync podinfo

# 8. Prüfen
kubectl get pods -n tenant-demo
# Erwartet: 3 podinfo Pods Running (statt 2)

# 9. In Argo CD UI checken
# Browser: http://argocd.local → App "podinfo" → sollte grün/Synced sein
```

**✅ Checkpoint:** podinfo läuft mit 3 Replicas, Argo CD zeigt "Synced", Git Commit ist sichtbar.

---

#### **📊 Zusammenfassung: Welche Befehle brauchst du?**

| Phase | Häufigkeit | Befehle |
|-------|------------|---------|
| **Tools installieren** | Einmalig | Docker, kind, kubectl, Helm, Argo CD CLI installieren |
| **Repo clonen** | Einmalig | `git clone https://github.com/ADASK-B/agent-ready-k8s.git` |
| **Stack starten** | Einmalig + nach Reboot | `./setup-template/phase0-template-foundation/setup-phase0.sh` |
| **/etc/hosts** | Einmalig | `sudo vim /etc/hosts` (argocd.local, demo.localhost) |
| **Änderung testen (lokal)** | Täglich | `helm template \| kubeconform`, `kubectl create ns test-*`, `helm upgrade --install` |
| **Änderung deployen (GitOps)** | Täglich | `git add`, `git commit`, `git push`, `argocd app sync` |
| **Status checken** | Sehr oft | `kubectl get pods -A`, `kubectl get applications -n argocd`, `k9s` |

---

**🔑 Der wichtigste Befehl für dich:**

```bash
# Kompletter Stack in einem Befehl:
./setup-template/phase0-template-foundation/setup-phase0.sh
```

**Danach hast du:**
- ✅ kind Cluster läuft
- ✅ Argo CD managed alles
- ✅ PostgreSQL + Redis laufen
- ✅ podinfo Demo-App läuft
- ✅ GitOps Flow funktioniert

**Und dann entwickelst du:** Code ändern → lokal testen → committen → pushen → Argo CD synced automatisch! 🚀

---

## 📝 Offene Fragen (für finale Version):

1. **VS Code Extensions:** Soll ich empfohlene Extensions auflisten? (Kubernetes, YAML, GitLens)
2. **Webhook statt Polling:** Soll ich zeigen wie man GitHub Webhooks einrichtet für instant sync?
3. **Multi-Environment:** Soll ich erklären wie man dev/staging/prod Branches aufsetzt?
4. **Secrets Management:** Kurz Sealed Secrets erwähnen oder zu lang?

---

**Status:** ⚠️ ENTWURF - Feedback erwünscht!
