# Common Kubernetes Issues Reference

## Pod Issues

### ImagePullBackOff / ErrImagePull

**Symptoms:**
- Pod stuck in `ImagePullBackOff` or `ErrImagePull` state
- Events show "Failed to pull image"

**Common Causes:**
- Image name typo
- Image doesn't exist in registry
- Registry authentication failure
- Network issues reaching registry

**Diagnostic Commands:**
```bash
kubectl describe pod <pod> -n <namespace>
kubectl get events -n <namespace> --field-selector involvedObject.name=<pod>
```

**Remediation:**
1. Verify image name and tag exist
2. Check imagePullSecrets configuration
3. Test registry access from node
4. Verify network connectivity

---

### CrashLoopBackOff

**Symptoms:**
- Pod repeatedly restarts
- Container exits immediately after start

**Common Causes:**
- Application error/crash
- Missing configuration or secrets
- Resource exhaustion (OOM)
- Failed health checks
- Missing dependencies

**Diagnostic Commands:**
```bash
kubectl logs <pod> -n <namespace>
kubectl logs <pod> -n <namespace> --previous
kubectl describe pod <pod> -n <namespace>
```

**Remediation:**
1. Check application logs for errors
2. Verify all ConfigMaps/Secrets exist
3. Check resource limits (OOMKilled?)
4. Verify liveness probe configuration
5. Test application locally

---

### Pending Pods

**Symptoms:**
- Pod stays in `Pending` state
- Not scheduled to any node

**Common Causes:**
- Insufficient cluster resources
- Node selector/affinity mismatch
- Taints preventing scheduling
- PVC not bound
- Resource quota exceeded

**Diagnostic Commands:**
```bash
kubectl describe pod <pod> -n <namespace>
kubectl get nodes -o wide
kubectl describe nodes
kubectl get pvc -n <namespace>
```

**Remediation:**
1. Check node resources: `kubectl top nodes`
2. Review nodeSelector/affinity rules
3. Check for taints: `kubectl describe node <node>`
4. Verify PVC is bound
5. Check resource quotas

---

### OOMKilled

**Symptoms:**
- Container terminated with OOMKilled
- Exit code 137

**Common Causes:**
- Memory limit too low
- Memory leak in application
- Unexpected memory usage spike

**Diagnostic Commands:**
```bash
kubectl describe pod <pod> -n <namespace>
kubectl top pod <pod> -n <namespace>
```

**Remediation:**
1. Increase memory limits
2. Profile application memory usage
3. Fix memory leaks
4. Add memory request to ensure scheduling

---

## Node Issues

### NotReady

**Symptoms:**
- Node shows `NotReady` status
- Pods being evicted

**Common Causes:**
- Kubelet not running
- Network issues
- Disk pressure
- Memory pressure
- Container runtime issues

**Diagnostic Commands:**
```bash
kubectl describe node <node>
kubectl get events --field-selector involvedObject.name=<node>
# On the node:
systemctl status kubelet
journalctl -u kubelet -n 100
```

**Remediation:**
1. SSH to node and check kubelet
2. Restart kubelet if needed
3. Check disk space
4. Check memory usage
5. Verify container runtime

---

### DiskPressure

**Symptoms:**
- Node condition `DiskPressure=True`
- Pods being evicted

**Common Causes:**
- Container images filling disk
- Log files growing
- Unused containers/images

**Diagnostic Commands:**
```bash
kubectl describe node <node>
# On the node:
df -h
docker system df  # or crictl
```

**Remediation:**
1. Clean unused images: `docker system prune`
2. Clean old logs
3. Expand disk if possible
4. Configure log rotation

---

## Networking Issues

### Pod-to-Pod Communication Failure

**Symptoms:**
- Pods cannot reach each other
- Connection timeouts

**Common Causes:**
- NetworkPolicy blocking traffic
- CNI plugin issues
- DNS resolution failure

**Diagnostic Commands:**
```bash
kubectl get networkpolicies -n <namespace>
kubectl exec <pod> -- nslookup <service>
kubectl exec <pod> -- ping <other-pod-ip>
```

**Remediation:**
1. Check NetworkPolicies
2. Verify CNI is running
3. Test DNS resolution
4. Check service endpoints

---

### Service Not Accessible

**Symptoms:**
- Service returns no response
- Connection refused

**Common Causes:**
- No endpoints (selector mismatch)
- Target port incorrect
- Pod not ready

**Diagnostic Commands:**
```bash
kubectl get endpoints <service> -n <namespace>
kubectl describe svc <service> -n <namespace>
kubectl get pods -n <namespace> --show-labels
```

**Remediation:**
1. Verify endpoints exist
2. Check selector matches pod labels
3. Verify targetPort matches container port
4. Check pod readiness

---

## Storage Issues

### PVC Pending

**Symptoms:**
- PVC stuck in `Pending` state
- Pod waiting for volume

**Common Causes:**
- No matching StorageClass
- Insufficient storage capacity
- StorageClass not provisioning

**Diagnostic Commands:**
```bash
kubectl describe pvc <pvc> -n <namespace>
kubectl get storageclass
kubectl get pv
```

**Remediation:**
1. Verify StorageClass exists
2. Check storage provisioner logs
3. Verify storage capacity
4. Check access modes compatibility

---

### Volume Mount Failure

**Symptoms:**
- Pod stuck in `ContainerCreating`
- Events show mount errors

**Common Causes:**
- PVC not bound
- Volume already mounted (RWO)
- Node cannot access storage

**Diagnostic Commands:**
```bash
kubectl describe pod <pod> -n <namespace>
kubectl get pvc <pvc> -n <namespace>
kubectl get pv <pv>
```

**Remediation:**
1. Ensure PVC is bound
2. Check access mode (RWO vs RWX)
3. Verify node has access to storage
4. Check storage driver on node

---

## Resource Issues

### ResourceQuota Exceeded

**Symptoms:**
- Cannot create new pods
- Events show quota exceeded

**Common Causes:**
- Namespace quota limit reached
- Too many pods/services

**Diagnostic Commands:**
```bash
kubectl describe resourcequota -n <namespace>
kubectl get pods -n <namespace> | wc -l
```

**Remediation:**
1. Delete unused resources
2. Increase quota if appropriate
3. Optimize resource requests

---

## RBAC Issues

### Permission Denied

**Symptoms:**
- API calls fail with 403 Forbidden
- ServiceAccount cannot access resources

**Common Causes:**
- Missing Role/ClusterRole
- Missing RoleBinding/ClusterRoleBinding
- Wrong ServiceAccount

**Diagnostic Commands:**
```bash
kubectl auth can-i <verb> <resource> --as system:serviceaccount:<ns>:<sa>
kubectl get rolebindings,clusterrolebindings -n <namespace>
```

**Remediation:**
1. Create appropriate Role
2. Create RoleBinding to ServiceAccount
3. Verify ServiceAccount in pod spec

---

## ArgoCD Issues

### Application OutOfSync

**Symptoms:**
- Application shows `OutOfSync` status
- Changes not being applied to cluster

**Common Causes:**
- Manual changes made directly to cluster (drift)
- Git repository not accessible
- Invalid manifests in repository
- Resource hooks failing
- Ignored differences not configured

**Diagnostic Commands:**
```bash
argocd app get <app-name>
argocd app diff <app-name>
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd
```

**Remediation:**
1. Check diff to understand changes: `argocd app diff <app-name>`
2. If drift, sync to restore: `argocd app sync <app-name>`
3. Check git credentials if repo access fails
4. Validate manifests locally before pushing
5. Configure ignoreDifferences for expected drift

---

### Application Sync Failed

**Symptoms:**
- Sync operation fails
- Application stuck in `Progressing` or `Degraded`

**Common Causes:**
- Invalid Kubernetes manifests
- Resource already exists (not managed by ArgoCD)
- Webhook validation failures
- Insufficient RBAC permissions
- Helm chart rendering errors

**Diagnostic Commands:**
```bash
argocd app sync <app-name> --dry-run
argocd app logs <app-name>
kubectl get events -n argocd --sort-by='.lastTimestamp'
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

**Remediation:**
1. Run dry-run to see errors: `argocd app sync <app-name> --dry-run`
2. Check application controller logs for details
3. Verify RBAC permissions for ArgoCD service account
4. For existing resources, add annotation: `argocd.argoproj.io/sync-options: Replace=true`
5. Force sync if needed: `argocd app sync <app-name> --force`

---

### ArgoCD UI Not Accessible

**Symptoms:**
- Cannot reach ArgoCD web interface
- 502/503 errors

**Common Causes:**
- argocd-server pod not running
- Ingress misconfiguration
- TLS certificate issues
- Service not exposed correctly

**Diagnostic Commands:**
```bash
kubectl get pods -n argocd
kubectl get svc -n argocd
kubectl get ingress -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

**Remediation:**
1. Verify argocd-server pod is running
2. Check service endpoints exist
3. For port-forward access: `kubectl port-forward svc/argocd-server -n argocd 8080:443`
4. Verify ingress configuration and TLS secrets

---

## Helm Issues

### Helm Release Failed

**Symptoms:**
- `helm install/upgrade` fails
- Release stuck in `pending-install` or `pending-upgrade`

**Common Causes:**
- Invalid values
- Template rendering errors
- Resource conflicts
- Timeout during deployment
- Previous failed release blocking

**Diagnostic Commands:**
```bash
helm list -a -n <namespace>
helm history <release> -n <namespace>
helm get manifest <release> -n <namespace>
helm template <chart> -f values.yaml  # Test rendering locally
```

**Remediation:**
1. Check release history: `helm history <release> -n <namespace>`
2. For stuck release: `helm rollback <release> <revision> -n <namespace>`
3. For failed install, uninstall first: `helm uninstall <release> -n <namespace>`
4. Test template locally before deploying
5. Increase timeout: `helm upgrade --timeout 10m`

---

### Helm Values Not Applied

**Symptoms:**
- Configuration changes not reflected in deployment
- Values file changes ignored

**Common Causes:**
- Wrong values file path
- Values override order incorrect
- Cached templates
- Subchart values not prefixed correctly

**Diagnostic Commands:**
```bash
helm get values <release> -n <namespace>
helm get values <release> -n <namespace> --all
helm template <chart> -f values.yaml --debug
```

**Remediation:**
1. Verify values are applied: `helm get values <release> -n <namespace>`
2. Check values file path is correct
3. For subcharts, prefix values with chart name
4. Use `--set` for debugging: `helm upgrade --set key=value --dry-run`

---

### Helm Hook Failures

**Symptoms:**
- Release fails during pre/post install/upgrade
- Hook jobs not completing

**Common Causes:**
- Hook job fails or times out
- Hook weight ordering issues
- Resource cleanup not happening

**Diagnostic Commands:**
```bash
kubectl get jobs -n <namespace>
kubectl logs job/<hook-job> -n <namespace>
helm get hooks <release> -n <namespace>
```

**Remediation:**
1. Check hook job logs
2. Verify hook deletion policy
3. Manually delete stuck hooks if needed
4. Adjust hook weights for correct ordering

---

## Kind-Specific Issues

### Kind Cluster Not Starting

**Symptoms:**
- `kind create cluster` fails
- Nodes stuck in NotReady

**Common Causes:**
- Docker not running
- Insufficient system resources
- Port conflicts
- Docker network issues

**Diagnostic Commands:**
```bash
docker ps
docker logs <kind-control-plane-container>
kind get clusters
kind export logs
```

**Remediation:**
1. Ensure Docker is running: `docker info`
2. Check Docker resource limits (memory/CPU)
3. Delete stuck cluster: `kind delete cluster --name <name>`
4. Reset Docker network: `docker network prune`
5. Export logs for debugging: `kind export logs ./kind-logs`

---

### Kind LoadBalancer Services Pending

**Symptoms:**
- Services of type LoadBalancer stuck in `Pending`
- No external IP assigned

**Common Causes:**
- Kind doesn't support LoadBalancer by default
- MetalLB not installed
- MetalLB address pool exhausted

**Diagnostic Commands:**
```bash
kubectl get svc -A | grep LoadBalancer
kubectl get pods -n metallb-system
kubectl describe ipaddresspool -n metallb-system
```

**Remediation:**
1. Install MetalLB for LoadBalancer support
2. Configure IP address pool matching Docker network:
   ```bash
   docker network inspect kind | grep Subnet
   ```
3. Use NodePort or Ingress as alternative
4. Port-forward for local access: `kubectl port-forward svc/<name> <port>:<port>`

---

### Kind Ingress Not Working

**Symptoms:**
- Ingress resources created but not accessible
- 404 or connection refused on localhost

**Common Causes:**
- Ingress controller not installed
- Kind cluster created without extraPortMappings
- Host network configuration missing

**Diagnostic Commands:**
```bash
kubectl get pods -n ingress-nginx
kubectl get ingress -A
docker port kind-control-plane
```

**Remediation:**
1. Create cluster with port mappings:
   ```yaml
   kind: Cluster
   nodes:
   - role: control-plane
     extraPortMappings:
     - containerPort: 80
       hostPort: 80
     - containerPort: 443
       hostPort: 443
   ```
2. Install ingress controller with kind-specific config
3. Use `kubectl port-forward` as workaround

---

### Kind Volume Mount Issues

**Symptoms:**
- PersistentVolumes not mounting correctly
- Permission denied on mounted paths

**Common Causes:**
- Host path not mounted into kind container
- File permissions mismatch
- SELinux/AppArmor blocking access

**Diagnostic Commands:**
```bash
docker exec kind-control-plane ls -la /path
kubectl describe pv <pv-name>
kubectl describe pod <pod> | grep -A5 Volumes
```

**Remediation:**
1. Mount host paths in kind config:
   ```yaml
   nodes:
   - role: control-plane
     extraMounts:
     - hostPath: /path/on/host
       containerPath: /path/in/node
   ```
2. Check file permissions (uid/gid)
3. Use local-path-provisioner for dynamic provisioning
