# Quickstart - agent-ready-k8s

**Goal:** Make system operational after reboot or initial setup.
**Policy:** Idempotent; 3× retry on failure (5s backoff), else STOP with error log.

---

## Table of Contents

1. [After Reboot](#after-reboot)
2. [First Installation](#first-installation)
3. [Access Credentials](#access-credentials)
4. [Cleanup](#cleanup)

---

## After Reboot

**Goal:** Verify cluster operational, restart if needed.

### 1) Preconditions
- Network & DNS reachable
- Docker active: `docker ps || sudo systemctl start docker`
- Repo exists: `git -C /home/arthur/Dev/agent-ready-k8s rev-parse`

### 2) Check Container
```bash
docker ps | grep agent-k8s-local
```
**If not running:**
```bash
docker start agent-k8s-local-control-plane
```

### 3) Verify Cluster
```bash
kubectl get nodes
# Expected: NAME=agent-k8s-local-control-plane, STATUS=Ready
```

### 4) Verify Pods
```bash
kubectl get pods -A --field-selector=status.phase!=Running
# Expected: No resources found (all Running)
```

### 5) Test Endpoints
```bash
curl -o /dev/null -w "%{http_code}\n" http://argocd.local
curl -o /dev/null -w "%{http_code}\n" http://demo.localhost
# Expected: Both return 200
```

**On failure:** See [First Installation](#first-installation)

---

## First Installation

**Goal:** Deploy complete Kubernetes environment from scratch.

### 1) Prerequisites
- Docker installed & running
- User in docker group: `groups | grep docker`
- /etc/hosts writable (needs sudo once)

### 2) Run Setup
```bash
cd /home/arthur/Dev/agent-ready-k8s
./setup-template/phase0-template-foundation/setup-phase0.sh
```

### 3) What Happens
- Install tools: Docker, kind, kubectl, Helm, Argo CD CLI
- Create kind cluster: `agent-k8s-local`
- Deploy: Ingress-Nginx, PostgreSQL, Redis, Argo CD, podinfo
- Configure /etc/hosts: `127.0.0.1 argocd.local demo.localhost`

### 4) Expected Result
- ✅ `kubectl get nodes` → Ready
- ✅ `kubectl get pods -A` → 21 pods Running
- ✅ `http://argocd.local` → HTTP 200
- ✅ `http://demo.localhost` → HTTP 200

**On failure:** Check logs in setup output, verify Docker is running.

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

# Health
curl http://demo.localhost/healthz
```

### PostgreSQL (Config Storage)
```bash
Host: postgresql.demo-platform:5432
User: demouser
Pass: demopass
DB:   demodb

# Test
kubectl run -n demo-platform postgresql-client --rm --tty -i --restart='Never' \
  --image docker.io/bitnami/postgresql:17 --env PGPASSWORD=demopass \
  --command -- psql --host postgresql.demo-platform -U demouser -d demodb -c 'SELECT version();'
```

### Redis (Pub/Sub for Hot-Reload)
```bash
Host: redis-master.demo-platform:6379
Pass: redispass

# Test
kubectl run -n demo-platform redis-client --rm --tty -i --restart='Never' \
  --image docker.io/bitnami/redis:7.4 \
  --command -- redis-cli -h redis-master.demo-platform -a redispass ping
```

---

## Cleanup

**Goal:** Remove all resources and generated files.

### Delete Cluster
```bash
kind delete cluster --name agent-k8s-local
```

### Delete Generated Files
```bash
cd /home/arthur/Dev/agent-ready-k8s
rm -rf apps/ clusters/ infrastructure/ policies/ kind-config.yaml
```

### Verify
```bash
kind get clusters  # Expected: No kind clusters found.
docker ps | grep agent-k8s  # Expected: (no output)
```

---

**Policy Notes:**
- All commands idempotent (safe to re-run)
- After reboot: Container auto-starts with Docker, pods restart automatically
- On 502/Connection Refused: Wait 30s for pod initialization
- Logs: `kubectl logs -n <namespace> <pod>` or `docker logs agent-k8s-local-control-plane`
