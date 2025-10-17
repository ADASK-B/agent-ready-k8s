# Setup Phase 0 - agent-ready-k8s

**Goal:** Deploy complete local Kubernetes foundation from scratch.
**Policy:** Idempotent; 3× retry on failure (5s backoff), else STOP with error log.

---

## Prerequisites

### System Requirements
- **OS:** Linux (Ubuntu/Debian recommended)
- **RAM:** ≥ 8 GB
- **Disk:** ≥ 20 GB free space
- **Network:** Internet connection for downloads

### Required Access
- Docker installed & running
- User in docker group: `groups | grep docker`
- /etc/hosts writable (needs sudo once)

---

## Quick Start

```bash
cd /home/arthur/Dev/agent-ready-k8s
./setup-template/phase0-template-foundation/setup-phase0.sh
```

**Runtime:** ~3-4 minutes

---

## What Gets Installed

### Tools
- **Docker Engine CE** - Container runtime
- **kind** - Kubernetes IN Docker (v0.20.0+)
- **kubectl** - Kubernetes CLI (v1.27.3+)
- **Helm** - Kubernetes package manager (v3.12+)
- **Argo CD CLI** - GitOps CLI (v2.12.3)

### Infrastructure Components
| Component | Version | Purpose |
|-----------|---------|---------|
| **kind Cluster** | K8s v1.27.3 | Local Kubernetes cluster |
| **Ingress-Nginx** | Latest | HTTP routing (port 80/443) |
| **PostgreSQL** | 18.0.0 | Config storage, multi-tenant data |
| **Redis** | 8.2.2 | Hot-Reload Pub/Sub, caching |
| **Argo CD** | v2.12.3 | GitOps UI & CD pipeline |
| **podinfo** | v6.9.2 | Demo application |

### Generated Resources
```
agent-ready-k8s/
├── apps/                    ← Kustomize app manifests
├── clusters/                ← Cluster-specific configs
├── infrastructure/          ← Infrastructure sources
├── policies/                ← Policy templates
└── kind-config.yaml         ← kind cluster configuration
```

---

## Deployment Steps

### 1) Tool Installation
```bash
# Docker, kind, kubectl, Helm, Argo CD CLI
# All tools verified with version checks
```

### 2) Create kind Cluster
```bash
kind create cluster --name agent-k8s-local --config kind-config.yaml
# Ports: 80:80, 443:443 (HTTP/HTTPS)
```

### 3) Deploy Ingress-Nginx
```bash
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx
# Wait for controller Ready
```

### 4) Deploy Databases
```bash
# PostgreSQL: demo-platform namespace
# Redis: demo-platform namespace
# Credentials in Access Credentials section
```

### 5) Deploy Argo CD
```bash
# Namespace: argocd
# Ingress: http://argocd.local
# Server: HTTP mode (port 80)
```

### 6) Deploy Demo App (podinfo)
```bash
# Namespace: tenant-demo
# Ingress: http://demo.localhost
# Replicas: 2
# Connected to: Redis
```

### 7) Configure /etc/hosts
```bash
# Adds:
127.0.0.1 argocd.local
127.0.0.1 demo.localhost
```

---

## Expected Result

### Cluster Status
```bash
kubectl get nodes
# NAME                              STATUS   ROLE           AGE   VERSION
# agent-k8s-local-control-plane     Ready    control-plane  3m    v1.27.3
```

### Pod Status (21 total)
```bash
kubectl get pods -A
# NAMESPACE          PODS
# argocd             7 pods (Argo CD components)
# demo-platform      2 pods (PostgreSQL, Redis)
# ingress-nginx      1 pod  (Ingress controller)
# kube-system        9 pods (K8s system)
# tenant-demo        2 pods (podinfo replicas)
```

### Endpoints
```bash
curl http://argocd.local          # HTTP 200
curl http://demo.localhost        # HTTP 200
```

---

## Access Credentials

### Argo CD (GitOps UI)
```bash
# URL
http://argocd.local

# Username
admin

# Password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### Demo App (podinfo)
```bash
# URL
http://demo.localhost

# Health Check
curl http://demo.localhost/healthz
# Expected: {"status":"ok"}
```

### PostgreSQL (Config Storage)
```bash
Host: postgresql.demo-platform:5432
User: demouser
Pass: demopass
DB:   demodb

# Test Connection
kubectl run -n demo-platform postgresql-client --rm --tty -i --restart='Never' \
  --image docker.io/bitnami/postgresql:17 --env PGPASSWORD=demopass \
  --command -- psql --host postgresql.demo-platform -U demouser -d demodb -c 'SELECT version();'
```

### Redis (Pub/Sub for Hot-Reload)
```bash
Host: redis-master.demo-platform:6379
Pass: redispass

# Test Connection
kubectl run -n demo-platform redis-client --rm --tty -i --restart='Never' \
  --image docker.io/bitnami/redis:7.4 \
  --command -- redis-cli -h redis-master.demo-platform -a redispass ping
# Expected: PONG
```

---

## Troubleshooting

### Setup Fails
```bash
# Check Docker status
sudo systemctl status docker

# Check disk space
df -h /var/lib/docker

# Re-run setup (idempotent)
./setup-template/phase0-template-foundation/setup-phase0.sh
```

### Pods Not Running
```bash
# Describe failing pod
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace>

# Common issues:
# - ImagePullBackOff: Network/registry issue
# - CrashLoopBackOff: Check logs for app error
# - Pending: Resource constraints (check: kubectl describe node)
```

### Ingress Not Working (502 Bad Gateway)
```bash
# Wait for ingress controller
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx \
  -n ingress-nginx --timeout=120s

# Verify ingress backend
kubectl get ingress -n argocd -o yaml | grep -A5 backend
# Should show: port: 80 (not 443)

# Check /etc/hosts
cat /etc/hosts | grep -E 'argocd|demo'
```

---

## Cleanup

### Delete Cluster
```bash
kind delete cluster --name agent-k8s-local
```

### Delete Generated Files
```bash
cd /home/arthur/Dev/agent-ready-k8s
rm -rf apps/ clusters/ infrastructure/ policies/ kind-config.yaml
```

### Verify Cleanup
```bash
kind get clusters          # Expected: No kind clusters found.
docker ps | grep agent-k8s # Expected: (no output)
```

---

## What's Next?

**After successful setup:**
1. ✅ Login to Argo CD: `http://argocd.local`
2. ✅ Test Demo App: `http://demo.localhost`
3. ✅ Verify Databases: PostgreSQL & Redis connections
5. 📋 Check [Phase 0 Roadmap](../roadmap/Phase-0.md) for completed tasks

**After reboot:**
- See [Boot Routine](Boot-Routine.md) for verification checklist
