---
name: security-compliance-guard
description: Implement zero-trust security, secrets management, and compliance. Use for Vault, ESO, Kyverno, OPA, Pod Security, RBAC, and supply chain security. Keywords: security, secrets, Vault, ESO, Kyverno, OPA, RBAC, compliance, SBOM, Cosign.
---

# Security & Compliance Guard

Expert in implementing zero-trust security posture, secrets management, and compliance controls for Kubernetes environments.

## When to Use This Skill

- Setting up secrets management (Vault, ESO)
- Implementing policy enforcement (Kyverno, OPA)
- Configuring Pod Security Standards
- Designing RBAC strategies
- Implementing supply chain security (Cosign, SBOM)
- Conducting security audits
- Implementing NetworkPolicies
- Setting up runtime security (Falco)

---

## Security Layers

```
┌─────────────────────────────────────────────────────────┐
│                   Supply Chain                          │
│   (Image signing, SBOM, vulnerability scanning)         │
├─────────────────────────────────────────────────────────┤
│                   Admission Control                     │
│   (Kyverno/OPA, Pod Security, image policies)          │
├─────────────────────────────────────────────────────────┤
│                   Secrets Management                    │
│   (External Secrets, Vault, encrypted at rest)         │
├─────────────────────────────────────────────────────────┤
│                   Identity & Access                     │
│   (RBAC, ServiceAccounts, Workload Identity)           │
├─────────────────────────────────────────────────────────┤
│                   Network Security                      │
│   (NetworkPolicies, mTLS, service mesh)                │
├─────────────────────────────────────────────────────────┤
│                   Runtime Security                      │
│   (Falco, syscall monitoring, container isolation)     │
└─────────────────────────────────────────────────────────┘
```

---

## Secrets Management with External Secrets Operator

### SecretStore Configuration

```yaml
# Azure Key Vault
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-keyvault
  namespace: demo-platform
spec:
  provider:
    azurekv:
      tenantId: ${AZURE_TENANT_ID}
      vaultUrl: https://my-vault.vault.azure.net
      authType: WorkloadIdentity
      serviceAccountRef:
        name: eso-service-account
---
# AWS Secrets Manager
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: eso-service-account
---
# HashiCorp Vault
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault
spec:
  provider:
    vault:
      server: https://vault.example.com
      path: secret
      auth:
        kubernetes:
          mountPath: kubernetes
          role: demo-app
          serviceAccountRef:
            name: vault-auth
```

### ExternalSecret Usage

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: demo-platform
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault
    kind: SecretStore
  target:
    name: db-credentials
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: database/creds/demo
        property: username
    - secretKey: password
      remoteRef:
        key: database/creds/demo
        property: password
```

---

## Pod Security Standards

### Restricted Profile (Production)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Compliant Pod Example

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault

  containers:
    - name: app
      image: ghcr.io/org/app:v1.0.0@sha256:...
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
      resources:
        requests:
          memory: "128Mi"
          cpu: "100m"
        limits:
          memory: "256Mi"
          cpu: "200m"
```

---

## Kyverno Policies

### Require Non-Root

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-run-as-non-root
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-containers
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Containers must run as non-root"
        pattern:
          spec:
            containers:
              - securityContext:
                  runAsNonRoot: true
```

### Require Image Signatures

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: verify-signature
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "ghcr.io/my-org/*"
          attestors:
            - entries:
                - keys:
                    publicKeys: |-
                      -----BEGIN PUBLIC KEY-----
                      ...
                      -----END PUBLIC KEY-----
```

### Require Resource Limits

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Enforce
  rules:
    - name: validate-resources
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "CPU and memory limits are required"
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
```

### Block Latest Tag

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: Enforce
  rules:
    - name: validate-image-tag
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Using 'latest' tag is not allowed"
        pattern:
          spec:
            containers:
              - image: "!*:latest"
```

---

## RBAC Best Practices

### Least Privilege ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: demo-platform
  annotations:
    # Azure Workload Identity
    azure.workload.identity/client-id: ${CLIENT_ID}
    # AWS IRSA
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/my-app
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: my-app
  namespace: demo-platform
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["my-app-config"]  # Specific secret only
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: my-app
  namespace: demo-platform
subjects:
  - kind: ServiceAccount
    name: my-app
roleRef:
  kind: Role
  name: my-app
  apiGroup: rbac.authorization.k8s.io
```

---

## NetworkPolicies

### Default Deny All

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: demo-platform
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### Allow Specific Traffic

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-traffic
  namespace: demo-platform
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
    # Allow DNS
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
```

---

## Supply Chain Security

### Image Signing with Cosign

```bash
# Generate key pair
cosign generate-key-pair

# Sign image
cosign sign --key cosign.key ghcr.io/org/app:v1.0.0

# Verify signature
cosign verify --key cosign.pub ghcr.io/org/app:v1.0.0
```

### GitHub Actions for Signing

```yaml
- name: Sign image
  env:
    COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}
  run: |
    cosign sign --key env://COSIGN_PRIVATE_KEY \
      ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}
```

### SBOM Generation

```yaml
- name: Generate SBOM
  uses: anchore/sbom-action@v0
  with:
    image: ghcr.io/${{ github.repository }}:${{ github.sha }}
    format: spdx-json
    output-file: sbom.spdx.json

- name: Attach SBOM to image
  run: |
    cosign attach sbom --sbom sbom.spdx.json \
      ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}
```

---

## Security Scanning

### Trivy Integration

```yaml
# .github/workflows/security.yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ghcr.io/${{ github.repository }}:${{ github.sha }}
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'

- name: Upload Trivy scan results
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: 'trivy-results.sarif'
```

### Falco for Runtime Security

```yaml
# falco-values.yaml
falco:
  rules_file:
    - /etc/falco/falco_rules.yaml
    - /etc/falco/k8s_audit_rules.yaml

  json_output: true

  http_output:
    enabled: true
    url: http://falcosidekick:2801

falcosidekick:
  config:
    slack:
      webhookurl: ${SLACK_WEBHOOK}
      channel: "#security-alerts"
```

---

## Security Checklist

### Pod Security
- [ ] runAsNonRoot: true
- [ ] readOnlyRootFilesystem: true
- [ ] allowPrivilegeEscalation: false
- [ ] capabilities.drop: ALL
- [ ] seccompProfile: RuntimeDefault
- [ ] Resource limits set

### Secrets
- [ ] No secrets in Git
- [ ] External Secrets Operator configured
- [ ] Secrets encrypted at rest
- [ ] Secrets rotated regularly
- [ ] Audit logging enabled

### Network
- [ ] Default deny NetworkPolicy
- [ ] Specific allow rules only
- [ ] mTLS for service-to-service
- [ ] Ingress TLS configured

### Supply Chain
- [ ] Images signed with Cosign
- [ ] SBOM attached to images
- [ ] Vulnerability scanning in CI
- [ ] Latest tag blocked
- [ ] Image pull from approved registries only

### RBAC
- [ ] Least privilege roles
- [ ] No cluster-admin for apps
- [ ] ServiceAccounts per app
- [ ] Regular RBAC audit

---

## Best Practices

### DO:
- Use External Secrets Operator for all secrets
- Implement Pod Security Standards (restricted)
- Sign all container images
- Use NetworkPolicies for microsegmentation
- Run vulnerability scans in CI
- Audit RBAC regularly
- Enable audit logging

### DON'T:
- Store secrets in Git or ConfigMaps
- Run containers as root
- Use `latest` tag
- Grant cluster-admin to applications
- Allow all network traffic
- Skip security scanning
- Ignore CVE alerts

---

## Related References

- [references/secrets-management.md](references/secrets-management.md) - ESO and Vault patterns
- [references/policy-enforcement.md](references/policy-enforcement.md) - Kyverno/OPA policies
- [references/supply-chain.md](references/supply-chain.md) - Image signing and SBOM
