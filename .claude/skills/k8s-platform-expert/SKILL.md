---
name: k8s-platform-expert
description: Complete Kubernetes platform expertise - deployment, security hardening, and systematic troubleshooting. Use for workload deployment, Helm charts, RBAC, NetworkPolicies, incident response, and diagnostics. Keywords: Kubernetes, K8s, kubectl, Helm, RBAC, troubleshooting, incident response, GitOps.
---

# Kubernetes Platform Expert

A comprehensive Kubernetes skill combining deployment expertise with systematic troubleshooting capabilities. Covers the full lifecycle from design and deployment through incident response and remediation.

## When to Use This Skill

**Deployment & Configuration:**
- Deploying workloads (Deployments, StatefulSets, DaemonSets, Jobs)
- Configuring networking (Services, Ingress, NetworkPolicies)
- Managing configuration (ConfigMaps, Secrets)
- Setting up persistent storage (PV, PVC, StorageClasses)
- Creating and managing Helm charts
- Implementing security best practices (RBAC, PSS)

**Troubleshooting & Incident Response:**
- Investigating pod failures (CrashLoopBackOff, ImagePullBackOff, Pending)
- Responding to production incidents or outages
- Diagnosing cluster health issues
- Troubleshooting networking or storage problems
- Debugging ArgoCD sync failures
- Troubleshooting Helm release problems
- Diagnosing kind cluster issues (local development)

---

## Part 1: Deployment & Security

### Core Deployment Workflow

1. **Analyze requirements** - workload characteristics, scaling needs, security requirements
2. **Design architecture** - workload types, networking patterns, storage solutions
3. **Implement manifests** - declarative YAML with proper resource limits, health checks
4. **Secure** - apply RBAC, NetworkPolicies, Pod Security Standards
5. **Test & validate** - verify deployments, test failure scenarios

### Deployment Constraints (MUST DO)

- Use declarative YAML manifests (avoid imperative kubectl commands)
- Set resource requests AND limits on all containers
- Include liveness and readiness probes
- Use Secrets for sensitive data (never hardcode)
- Apply least privilege RBAC permissions
- Implement NetworkPolicies for network segmentation
- Use namespaces for logical isolation
- Label resources consistently
- Pin image versions (never use `latest` in production)

### Deployment Constraints (MUST NOT DO)

- Deploy without resource limits
- Store secrets in ConfigMaps or plain env vars
- Use default ServiceAccount for application pods
- Allow unrestricted network access (default allow-all)
- Run containers as root without justification
- Skip health checks
- Expose unnecessary ports or services

### Output Templates

When implementing Kubernetes resources, provide:
- Complete YAML manifests with proper structure
- RBAC configuration (ServiceAccount, Role, RoleBinding)
- NetworkPolicy for network isolation
- Brief explanation of design decisions

---

## Part 2: Troubleshooting & Incident Response

### Core Troubleshooting Workflow

1. **Gather Context**
   - What is the observed symptom?
   - When did it start?
   - What changed recently?
   - What is the scope (pod, service, node, cluster)?
   - What is the business impact?

2. **Initial Triage**
   Run cluster health check:
   ```bash
   python3 .claude/skills/k8s-platform-expert/scripts/cluster_health.py
   ```

3. **Deep Dive Investigation**

   **Namespace-Level:**
   ```bash
   python3 .claude/skills/k8s-platform-expert/scripts/check_namespace.py <namespace>
   ```

   **Pod-Level:**
   ```bash
   python3 .claude/skills/k8s-platform-expert/scripts/diagnose_pod.py <namespace> <pod-name>
   ```

   **ArgoCD Issues:**
   ```bash
   python3 .claude/skills/k8s-platform-expert/scripts/diagnose_argocd.py <app-name>
   ```

   **Helm Issues:**
   ```bash
   python3 .claude/skills/k8s-platform-expert/scripts/diagnose_helm.py <release> <namespace>
   ```

4. **Identify Root Cause** - consult [references/common-issues.md](references/common-issues.md)

5. **Apply Remediation** - test in non-prod first, document actions, have rollback ready

6. **Verify & Monitor** - confirm fix, monitor 15-30 min minimum

### Incident Severity Levels

| Level | Description | Examples |
|-------|-------------|----------|
| SEV-1 | Critical | Complete outage, data loss, security breach |
| SEV-2 | High | Major degradation, significant user impact |
| SEV-3 | Medium | Minor impairment, workaround available |
| SEV-4 | Low | Cosmetic, minimal impact |

### Quick Reference Commands

**Cluster Overview:**
```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
```

**Pod Diagnostics:**
```bash
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace>
kubectl logs <pod> -n <namespace> --previous
kubectl exec -it <pod> -n <namespace> -- /bin/sh
```

**Node Diagnostics:**
```bash
kubectl describe node <node>
kubectl top nodes
kubectl top pods --all-namespaces
```

**Service & Network:**
```bash
kubectl describe svc <service> -n <namespace>
kubectl get endpoints <service> -n <namespace>
kubectl get networkpolicies -n <namespace>
```

**Storage:**
```bash
kubectl get pvc,pv -n <namespace>
kubectl describe pvc <pvc> -n <namespace>
kubectl get storageclass
```

---

## Best Practices

### Always:
- Start with high-level health check before deep diving
- Document symptoms and findings
- Check recent changes (deployments, config, infrastructure)
- Preserve logs before making destructive changes
- Test fixes in non-production when possible
- Monitor after applying fixes

### Never:
- Make production changes without understanding impact
- Delete resources without confirming safety
- Restart pods repeatedly without investigating root cause
- Apply fixes without documentation
- Skip post-incident review

---

## Related References

- [references/common-issues.md](references/common-issues.md) - Detailed troubleshooting guides
- [references/deployment-patterns.md](references/deployment-patterns.md) - Workload patterns
- [references/security-hardening.md](references/security-hardening.md) - Security best practices

---

## Sources

Combined from:
- [Jeffallan/claude-skills](https://github.com/Jeffallan/claude-skills) - kubernetes-specialist
- [ahmedasmar/devops-claude-skills](https://github.com/ahmedasmar/devops-claude-skills) - k8s-troubleshooter
