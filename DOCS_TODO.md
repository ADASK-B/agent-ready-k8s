# Documentation Fix Plan

| Path | When | Required Change | Reason |
| --- | --- | --- | --- |
| `README.md:32` | Phase 1 | Mark the `CODEOWNERS` entry in the structure tree as "planned" (or reintroduce the file) so the overview reflects the current repo. | The tree still lists `CODEOWNERS`, but the file has been removed; newcomers may waste time looking for it. |
| `docs/quickstart/local-dev.md:54` | Phase 1 | Replace the reference to `argocd/root-app.yaml` with a manifest that exists (or add the file under `argocd/`). | The GitOps workflow now tells readers to apply a file that is missing, causing setup failures. |
| `apps/podinfo/` | Phase 2 Block 1 | Delete apps/podinfo/ directory (unused Kustomize structure from Phase 1 Block 6) - podinfo runs via Helm through apps/base/podinfo-app.yaml | Cleanup artifact: Kustomize base/tenants structure was created to fix patchesStrategicMerge bug but never used - will be replaced by Backend/Frontend in Phase 2 |
| `docs/runbooks/sql-backup-restore.md:74-115` | Phase 2 | Update CronJob paths, namespaces, and storage destinations once the backup tooling is implemented. | The runbook still points to future manifests (`infra/k8s/cronjobs/...`) and MinIO buckets that are not available yet. |
| `docs/runbooks/secrets-rotation.md:30-135` | Phase 2 | Rewrite the rotation steps when the backend service and helper scripts exist (or add explicit TODO notes). | Current instructions reference a `backend` deployment and `tools/scripts/rotate-postgresql-password.sh`, which have not been created. |
| `docs/runbooks/incident-triage.md:74-170` | Phase 2 | Fill in the troubleshooting flow after observability dashboards and backend workloads land. | The incident guide assumes Phase 2+ components (backend services, Grafana dashboards) that are still on the roadmap. |

---

## Verification Notes (26 Oct 2025)

- Draft architecture strategies (`deployment-model`, `observability-strategy`, `testing-strategy`) now follow the Phase 2 template and no longer need additional TODOs.
- Security baseline checklist includes a Phase 2 note; no further action required until those controls ship.
- Config hot-reload runbook uses `<namespace>` placeholders, so namespace updates are deferred until tenant layout is finalized.
