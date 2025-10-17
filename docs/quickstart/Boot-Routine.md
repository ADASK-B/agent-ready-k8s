# Boot Routine - agent-ready-k8s

**Goal:** Verify system operational after reboot.
**Policy:** Idempotent checks; 3× retry on failure (5s backoff), else STOP with error log.

---

## Preconditions
- Network & DNS reachable
- Docker active: `docker ps || sudo systemctl start docker`
- Repo exists: `git -C /home/arthur/Dev/agent-ready-k8s rev-parse`

---

## 1) Check Container
```bash
docker ps | grep agent-k8s-local
```
**If not running:**
```bash
docker start agent-k8s-local-control-plane
```

---

## 2) Verify Cluster
```bash
kubectl get nodes
# Expected: NAME=agent-k8s-local-control-plane, STATUS=Ready
```

---

## 3) Verify Pods
```bash
kubectl get pods -A --field-selector=status.phase!=Running
# Expected: No resources found (all Running)
```

---

## 4) Test Endpoints
```bash
curl -o /dev/null -w "%{http_code}\n" http://argocd.local
curl -o /dev/null -w "%{http_code}\n" http://demo.localhost
# Expected: Both return 200
```

---

## Troubleshooting

**Container not found:**
```bash
# Check if cluster exists
kind get clusters
# Expected: agent-k8s-local

# If missing, run full setup
cd /home/arthur/Dev/agent-ready-k8s
./setup-template/phase0-template-foundation/setup-phase0.sh
```

**Pods not Running:**
```bash
# Wait 30s for pod initialization
sleep 30
kubectl get pods -A

# Check specific pod logs
kubectl logs -n <namespace> <pod>
```

**Endpoints return 502/Connection Refused:**
```bash
# Wait for ingress controller
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=60s

# Check ingress status
kubectl get ingress -A
```

---

## Policy Notes
- All commands **idempotent** (safe to re-run)
- Container auto-starts with Docker
- Pods auto-restart after reboot
- On persistent failure → See [Setup Phase 0](Setup-Phase0.md)
