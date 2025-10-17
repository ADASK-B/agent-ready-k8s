# agent-ready-k8s (link-only, single file)

> **Purpose:** Single control file for GitHub Copilot / LLM agents.
>
> **Token policy:** Do **not** expand documentation inline. Load only the minimal **linked** file(s) on demand.

---

## 🚨 Critical Rules

1. **Language:** All code, docs, commits **must be English**. Input may be any language → **Output always English**.
2. **Infra guardrail (MUST):** Before any infrastructure choice/change:

```
read_file("docs/architecture/ARCHITECTURE.md")
```

3. **Docs are NOT auto-loaded.** Read only when needed via:

```
read_file("<path>")
```

4. **Maintenance:** Keep paths/triggers current whenever files/folders/scripts/stack change or a phase completes.

---

## 🧭 Agent Dispatch Policy (token-aware)

**Goal:** Route to the **minimal** relevant doc(s).

**Flow**

1. Normalize user request (lowercase, strip punctuation).
2. If the request implies **infra decision** (db/storage/networking/security/cloud/mq) → **always**:

   ```
   read_file("docs/architecture/ARCHITECTURE.md")
   ```
3. Else match the **Routing Table** (specific > generic).
4. Load **one** file first. If incomplete, load **one more** (max 2 per turn).
5. Answer using only what was read. If still unclear, ask to load a specific path.

**Action template**

```
read_file("<best-match-path>")
# optional second read if essential
answer
```

**Tie-breakers**

* **Architecture first** if any infra term matches—even if others also match.
* **Specific > generic** (e.g., Boot Routine beats README for reboot issues).
* **Ambiguous?** Ask once or propose top 2 candidate paths.

---

## 📚 Routing Table (single source)

> Start with the **single best match**. Do **not** read multiple files “just in case”.

| Area                | Purpose                                          | When to read (intent)                                  | **Keywords** (any, EN/de)                                                                                                                                                                                                                                                                                                                                                                                                         | **Deny (do not route if these dominate)**          | Path                                |
| ------------------- | ------------------------------------------------ | ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- | ----------------------------------- |
| **Architecture**    | Design decisions; golden rules; provider mapping | Any infrastructure choice / policy / platform question | architecture, design decision, golden rule, database, postgres, mysql, redis, mongo, storage, pvc, storageclass, csi, ingress, service mesh, istio, linkerd, cni, calico, cilium, load balancer, security, tls, rbac, secret, policy, mq, kafka, rabbitmq, nats, provider, aks, eks, gke, on‑prem, vendor lock; **de:** architektur, entscheidung, datenbank, speicher, netzwerk, sicherheit, nachrichten, anbieter, lokal, cloud | readme, overview                                   | `docs/architecture/ARCHITECTURE.md` |
| **Boot Routine**    | After‑reboot checklist; system verification      | After reboot checks / down or unstable cluster         | reboot, boot, startup, cluster not responding, node not ready, crashloop, pending, health check, 502, connection refused, argocd down; **de:** neustart, cluster hängt, nicht erreichbar, abgestürzt, gesundheit                                                                                                                                                                                                                  | install, setup, phase 0, architecture              | `docs/quickstart/Boot-Routine.md`   |
| **Setup Phase 0**   | Local foundation; tools & components             | First install / local foundation / missing tools       | first install, initial setup, install, prerequisite, missing tools, kind, kubectl, helm, argocd cli, /etc/hosts, local dev, phase 0, bootstrap; **de:** erstinstallation, voraussetzungen, fehlende tools, lokal, einrichten                                                                                                                                                                                                      | reboot, crashloop, node not ready, architecture    | `docs/quickstart/Setup-Phase0.md`   |
| **Roadmap Phase 0** | Phase‑0 task list & status                       | Status / plan / progress                               | phase 0, task list, status, progress, roadmap, todo, backlog, milestone; **de:** aufgabenliste, fortschritt                                                                                                                                                                                                                                                                                                                       | reboot, install, setup, architecture               | `docs/roadmap/Phase-0.md`           |
| **Overview**        | Project overview & getting started               | Generic overview / getting started                     | overview, getting started, what is this, summary, repo structure; **de:** überblick, einstieg, was ist das, zusammenfassung                                                                                                                                                                                                                                                                                                       | aks, eks, gke, reboot, install, phase 0, crashloop | `README.md`                         |

---

## 🧪 Matching Examples

* “Which **database** for local vs **AKS**?” → `read_file("docs/architecture/ARCHITECTURE.md")`
* “Cluster shows **CrashLoopBackOff** after **reboot**” → `read_file("docs/quickstart/Boot-Routine.md")`
* “Fresh laptop: how to **install** the stack?” → `read_file("docs/quickstart/Setup-Phase0.md")`
* “What’s the **current status** of **Phase 0**?” → `read_file("docs/roadmap/Phase-0.md")`
* “What is this project?” → `read_file("README.md")`

---

## 🧱 Anti-patterns (to save tokens)

* Auto-reading multiple docs “just in case”.
* Loading README when a specific doc matches better.
* Skipping **ARCHITECTURE.md** before infra decisions.
* Reading >2 files per turn without explicit user need.
