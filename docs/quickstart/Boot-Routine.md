# After Reboot Checklist

> **When to use:** After system restart, Docker restart, or cluster recreation.

---

## Quick Verification (2 minutes)

### 1. Check Cluster

```bash
# Cluster running?
kubectl cluster-info

# Nodes ready?
kubectl get nodes
```

**Expected:** Cluster responds, nodes `Ready`.

---

### 2. Check Core Services

```bash
# All pods running?
kubectl get pods -A
```

**Expected:** All pods `Running` or `Completed`.

**If stuck in `Pending` or `CrashLoopBackOff`:**

```bash
# Check what's wrong
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

---

### 3. Check Argo CD

```bash
# Argo CD healthy?
kubectl get pods -n argocd

# Applications synced?
kubectl get applications -n argocd
```

**Expected:**
- Argo CD pods `Running`
- Applications `Synced` + `Healthy`

**If degraded:**

```bash
# Force sync
argocd app sync <app-name> --prune
```

---

## Common Issues

### Issue: Cluster not responding

```bash
# Check Docker
docker ps

# Restart kind cluster
kind delete cluster
kind create cluster --config kind-config.yaml
```

---

### Issue: Pods stuck `Pending`

**Cause:** PersistentVolumes not bound after reboot.

```bash
# Check PVCs
kubectl get pvc -A

# If "Pending", delete and let Argo CD recreate
kubectl delete pvc <pvc-name> -n <namespace>
argocd app sync <app-name>
```

---

### Issue: Ingress not working

```bash
# Check ingress-nginx
kubectl get pods -n ingress-nginx

# Restart if needed
kubectl rollout restart deployment/ingress-nginx-controller -n ingress-nginx
```

---

## Full Recovery (if everything fails)

```bash
# 1. Delete cluster
kind delete cluster

# 2. Recreate (see phase-specific setup)
./setup-template/phase0-template-foundation/setup-phase0.sh

# 3. Wait for Argo CD to sync everything
watch kubectl get applications -n argocd
```

---

## Success Criteria

✅ All pods `Running`
✅ All Argo CD apps `Synced` + `Healthy`
✅ Services accessible via port-forward

**Time to recovery:** ~2-5 minutes (normal reboot) | ~10 minutes (full cluster recreate)
