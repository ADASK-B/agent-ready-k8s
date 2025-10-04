# Third-Party Licenses & Attributions

This project uses code and patterns from the following open-source projects:

## FluxCD flux2-kustomize-helm-example
- **Source:** https://github.com/fluxcd/flux2-kustomize-helm-example
- **License:** Apache-2.0
- **Copyright:** Cloud Native Computing Foundation (CNCF)
- **Usage:** Repository structure, GitOps patterns, Kustomize layouts
- **Changes:** Adapted for local development with kind, simplified structure

## podinfo (Demo Application)
- **Source:** https://github.com/stefanprodan/podinfo
- **License:** Apache-2.0
- **Copyright:** Stefan Prodan
- **Usage:** Demo workload for testing Kubernetes deployments, Helm charts
- **Changes:** Custom Ingress configuration, tenant overlays

## AKS Baseline Automation (Phase 2 - Future)
- **Source:** https://github.com/Azure/aks-baseline-automation
- **License:** MIT
- **Copyright:** Microsoft Corporation
- **Usage:** Azure Kubernetes Service best practices (Phase 2 only)
- **Changes:** Will be integrated in Phase 2 for AKS deployment

## helm/kind-action (Phase 2 - Future)
- **Source:** https://github.com/helm/kind-action
- **License:** Apache-2.0
- **Copyright:** The Helm Authors
- **Usage:** CI/CD testing with ephemeral kind clusters (Phase 2 only)
- **Changes:** Will be used in GitHub Actions workflows

---

## License Compliance

All third-party components retain their original licenses as listed above.

**This project (agent-ready-k8s-stack) is licensed under MIT.**

See [LICENSE](LICENSE) for the main project license.

---

## Attributions in Source Files

Where applicable, source files contain header comments with attribution:
```yaml
# Based on: https://github.com/fluxcd/flux2-kustomize-helm-example
# License: Apache-2.0
# Modifications: [Description of changes]
```

---

**Last Updated:** 2025-10-04
