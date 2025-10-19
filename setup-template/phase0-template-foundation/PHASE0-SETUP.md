# Phase 0: Template Foundation

**🎯 Purpose:** Complete Kubernetes platform foundation with all dependencies for local development and Hot-Reload pattern implementation.

---

## 📂 What Phase 0 Creates

Phase 0 creates the following structure in your repository:

```
agent-ready-k8s/
│
├─ apps/                             # ✅ Created by Phase 0 (Block 2 + 3)
│  └─ podinfo/
│     ├─ base/                       # Base Kubernetes manifests (from upstream)
│     │  ├─ deployment.yaml
│     │  ├─ service.yaml
│     │  ├─ hpa.yaml
│     │  └─ kustomization.yaml
│     └─ tenants/                    # Tenant-specific overlays
│        └─ demo/
│           └─ kustomization.yaml
│
├─ clusters/                         # ✅ Created by Phase 0 (Block 2)
│  ├─ local/                         # Local (kind) cluster configs
│  │  └─ .gitkeep
│  └─ production/                    # Production cluster configs (empty, for Phase 2)
│     └─ .gitkeep
│
├─ infrastructure/                   # ✅ Created by Phase 0 (Block 2)
│  ├─ sources/                       # GitOps sources (repositories, Helm charts)
│  │  └─ .gitkeep
│  └─ controllers/                   # Infrastructure controllers (ESO, cert-manager)
│     └─ .gitkeep
│
├─ policies/                         # ✅ Created by Phase 0 (Block 2, empty for Phase 1+)
│  └─ .gitkeep
│
└─ kind-config.yaml                  # ✅ Created by Phase 0 (Block 4)
                                     # 3-node cluster config (ports 80/443 → localhost)
```

### **What Exists (After Phase 0):**

| Category | Component | Location | Status |
|----------|-----------|----------|--------|
| **Cluster** | kind cluster (1 control-plane + 2 workers) | Docker containers | ✅ Running |
| **Ingress** | NGINX Ingress Controller | Namespace: `ingress-nginx` | ✅ Running |
| **Databases** | PostgreSQL (Bitnami) | Namespace: `demo-platform` | ✅ Running |
| | Redis (Bitnami) | Namespace: `demo-platform` | ✅ Running |
| **GitOps** | Argo CD | Namespace: `argocd` | ✅ Running |
| **Demo App** | podinfo (connected to Redis) | Namespace: `tenant-demo` | ✅ Running |
| **Access** | http://demo.localhost | Ingress | ✅ Working |
| | http://argocd.local | Ingress | ✅ Working |


## �📋 What is Phase 0?

Phase 0 provides a **production-ready Kubernetes platform template** that includes:

- ✅ **Local Kubernetes** (kind cluster)
- ✅ **Ingress Controller** (NGINX)
- ✅ **Databases** (PostgreSQL + Redis)
- ✅ **GitOps** (Argo CD)
- ✅ **Reference App** (podinfo connected to Redis)

This is your **foundation layer** - everything you need **before** building your own applications.

---

## 🎯 Why Phase 0?

### **Before Phase 0:** Manual Setup Hell
```
❌ Install Docker manually
❌ Install kind manually
❌ Create cluster with custom config
❌ Deploy ingress (find correct manifests)
❌ Deploy PostgreSQL (find Helm chart, configure)
❌ Deploy Redis (find Helm chart, configure)
❌ Deploy Argo CD (find manifests, create ingress)
❌ Deploy demo app
❌ Connect everything together
❌ Debug when something breaks

Result: 2-3 hours, lots of trial & error
```

### **With Phase 0:** One Command
```
✅ ./setup-phase0.sh
✅ Wait 8-10 minutes
✅ Everything works

Result: Coffee break, return to ready platform
```

---

## 🚀 Quick Start

### **Prerequisites:**
- Linux/macOS/WSL2
- 8 GB RAM minimum
- 20 GB free disk space

### **Run Setup:**
```bash
cd /home/arthur/Dev/agent-ready-k8s
chmod +x setup-template/phase0-template-foundation/setup-phase0.sh
./setup-template/phase0-template-foundation/setup-phase0.sh
```

### **Add to /etc/hosts:**
```bash
sudo bash -c 'echo "127.0.0.1 demo.localhost argocd.local" >> /etc/hosts'
```

### **Access:**
- **Demo App:** http://demo.localhost
- **Argo CD:** http://argocd.local (admin / see password in output)

---

## 📦 What Gets Installed (8 Blocks)

### **Block 1: Install Tools**
```
Docker, kind, kubectl, Helm, Argo CD CLI, Task
Runtime: ~1 minute (if already installed: ~5 seconds)
```

### **Block 2: Create Structure**
```
Creates: apps/, clusters/, infrastructure/, policies/
Runtime: ~5 seconds
```

### **Block 3: Clone Templates**
```
Clones podinfo Kubernetes manifests as reference
Runtime: ~15 seconds
```

### **Block 4: Create Cluster**
```
kind cluster with 1 control-plane + 2 worker nodes
Port forwarding: 80, 443 → localhost
Runtime: ~60 seconds
```

### **Block 5: Deploy Ingress**
```
NGINX Ingress Controller via Helm
Enables: http://demo.localhost, http://argocd.local
Runtime: ~2 minutes
```

### **Block 6: Deploy Databases** ⭐ **NEW**
```
PostgreSQL: Config storage (Hot-Reload source of truth)
Redis: Pub/Sub notifications (Hot-Reload events)
Runtime: ~2-3 minutes
```

### **Block 7: Deploy Argo CD** ⭐ **NEW**
```
Argo CD: GitOps continuous delivery
Web UI: http://argocd.local
Runtime: ~3-4 minutes
```

### **Block 8: Deploy podinfo**
```
podinfo: Reference application (connected to Redis)
URL: http://demo.localhost
Runtime: ~30 seconds
```

---

## 🗂️ Block Structure

Each block follows this pattern:

```
XX-block-name/
  ├─ deploy.sh (or create.sh/install.sh/clone.sh)
  ├─ test.sh
  └─ README.md (optional)
```

**Scripts are:**
- ✅ Idempotent (safe to run multiple times)
- ✅ Tested (test.sh validates each block)
- ✅ Documented (clear headers with purpose, runtime, actions)
- ✅ Fail-safe (stops on error, shows what failed)

---

## 🎯 After Phase 0 - What Next?

### **You Have:**
```
✅ kind cluster (Kubernetes local)
✅ Ingress (http://demo.localhost, http://argocd.local)
✅ PostgreSQL (for config storage)
✅ Redis (for Hot-Reload notifications)
✅ Argo CD (for GitOps)
✅ podinfo (reference app)
```

### **Phase 1 - Build Your App:**
```
1. Use podinfo as reference
2. Connect your app to PostgreSQL (config storage)
3. Connect your app to Redis (subscribe to config changes)
4. Implement Hot-Reload:
   - Backend: UPDATE PostgreSQL → PUBLISH Redis event
   - App: SUBSCRIBE Redis → SELECT new config → Apply without restart
5. Deploy via Argo CD (GitOps)
```

### **Phase 2 - Production (Cloud):**
```
1. Adapt overlays for AKS/EKS/GKE
2. Replace kind with managed cluster
3. Replace PostgreSQL with managed service (optional)
4. Enable TLS (cert-manager + Let's Encrypt)
5. Enable monitoring (Prometheus, Grafana, Loki)
6. Enable backups (Velero)
```

---

## 🧪 Testing Individual Blocks

```bash
# Test specific block
./setup-template/phase0-template-foundation/06-deploy-databases/test.sh

# Re-run specific block
./setup-template/phase0-template-foundation/06-deploy-databases/deploy.sh
```

---

## 🗑️ Cleanup

```bash
# Delete cluster (keeps images cached)
kind delete cluster --name agent-k8s-local

# Full reset (including Docker images)
kind delete cluster --name agent-k8s-local
docker system prune -a -f
```

---

## 📝 Database Credentials

### **PostgreSQL:**
```
Host:     postgresql.demo-platform:5432
User:     demouser
Password: demopass
Database: demodb

# Test connection
kubectl run -n demo-platform postgresql-client --rm -ti --restart='Never' \
  --image docker.io/bitnami/postgresql:17 --env PGPASSWORD=demopass \
  --command -- psql --host postgresql.demo-platform -U demouser -d demodb
```

### **Redis:**
```
Host:     redis-master.demo-platform:6379
Password: redispass

# Test connection
kubectl run -n demo-platform redis-client --rm -ti --restart='Never' \
  --image docker.io/bitnami/redis:7.4 \
  --command -- redis-cli -h redis-master.demo-platform -a redispass
```

---

## 🔍 Troubleshooting

### **Problem: Pods not starting**
```bash
# Check pod status
kubectl get pods -A

# Check specific namespace
kubectl get pods -n demo-platform
kubectl get pods -n tenant-demo

# Check logs
kubectl logs -n demo-platform -l app.kubernetes.io/name=postgresql
kubectl logs -n demo-platform -l app.kubernetes.io/name=redis
```

### **Problem: http://demo.localhost not working**
```bash
# 1. Check /etc/hosts
cat /etc/hosts | grep demo.localhost

# 2. Check ingress
kubectl get ingress -A

# 3. Check ingress controller
kubectl get pods -n ingress-nginx

# 4. Test ingress directly
curl http://localhost
```

### **Problem: Argo CD password not working**
```bash
# Get password again
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

---

## 📊 Resource Usage

**Typical:**
- CPU: 2-3 cores
- RAM: 4-6 GB
- Disk: ~10 GB

**Pods Running (~20-25):**
- kind system: ~5 pods
- ingress-nginx: ~3 pods
- argocd: ~7 pods
- PostgreSQL: 1 pod
- Redis: 1 pod
- podinfo: 2 pods

---

## 🎯 Success Criteria

After Phase 0 completes, all these should work:

```bash
# 1. Cluster accessible
kubectl get nodes

# 2. All pods running
kubectl get pods -A | grep -v "Running\|Completed"
# (should return nothing)

# 3. Demo app accessible
curl http://demo.localhost
# (should return podinfo HTML)

# 4. Argo CD accessible
curl http://argocd.local
# (should return HTTP 200/301/302)

# 5. PostgreSQL accessible
kubectl run postgresql-test -n demo-platform --rm -ti --restart='Never' \
  --image docker.io/bitnami/postgresql:17 --env PGPASSWORD=demopass \
  --command -- psql --host postgresql.demo-platform -U demouser -d demodb -c 'SELECT 1;'
# (should return "1 row")

# 6. Redis accessible
kubectl run redis-test -n demo-platform --rm -ti --restart='Never' \
  --image docker.io/bitnami/redis:7.4 \
  --command -- redis-cli -h redis-master.demo-platform -a redispass ping
# (should return "PONG")
```

---

## 📚 References

- **podinfo:** https://github.com/stefanprodan/podinfo
- **Argo CD:** https://argo-cd.readthedocs.io/
- **kind:** https://kind.sigs.k8s.io/
- **PostgreSQL Helm Chart:** https://github.com/bitnami/charts/tree/main/bitnami/postgresql
- **Redis Helm Chart:** https://github.com/bitnami/charts/tree/main/bitnami/redis

---

## 🎉 You're Ready!

Phase 0 gives you a **complete, production-ready Kubernetes platform template** that you can:

✅ Use for local development
✅ Extend with your own applications
✅ Deploy to cloud with minimal changes
✅ Use as reference for best practices

**Now build something awesome!** 🚀
