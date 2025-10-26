# Documentation Fix Plan

| Path | When | Required Change | Reason |
| --- | --- | --- | --- |
| `README.md:441-488` | Phase 1 (now) | Replace the Quick Start commands with the actual Phase 0 workflow (`setup-phase0.sh`, `kubectl` applies) or note that the `tools/scripts/*.sh` helpers are future work. | Current instructions reference scripts (`dev-kind-up.sh`, `seed-demo-data.sh`) and services (Grafana) that do not exist, causing onboarding failures. |
| `README.md:490` | Phase 1 (now) | Remove or replace the link to `infra/terraform/envs/onprem/README.md` until that document exists. | The link points to a non-existent file, producing a 404 for readers following the production guide. |
| `CODEOWNERS:1-44` | Phase 1 (now) | Align ownership patterns with existing directories (drop `/tools/`, `/infra/argocd/`, `/Makefile`, etc., or create the referenced paths). | CODEOWNERS currently requests reviews for files and directories that are absent, creating noise in review workflows. |
| `SECURITY.md:32-47` | Phase 2 (later) | Clarify which baseline controls are implemented versus planned (e.g., mark unchecked items as “planned” or document current status). | The checklist states every control is unchecked despite documentation claiming features like PSA restricted profiles are in place, leading to contradictory guidance. |
| `docs/architecture/deployment-model.md` | Phase 2 (later) | Flesh out the draft sections (GitOps principles, sync policies, environment strategy) with the actual decisions and artifacts in this repo. | Document is flagged “Draft – needs content” and contains empty checklists, leaving contributors without deployment guidance. |
| `docs/architecture/observability-strategy.md` | Phase 2 (later) | Populate metrics, logging, tracing, dashboards, and alerting sections with concrete stack details or explicitly mark them as backlog tasks. | Critical observability guidance is missing, which blocks Phase 2 planning and conflicts with roadmap claims. |
| `docs/architecture/testing-strategy.md` | Phase 2 (later) | Replace placeholders with repository-specific tooling (pytest, k6, etc.) and add ownership of quality gates. | Testing policy is incomplete, so contributors lack clear expectations for coverage and tooling. |
| `docs/architecture/diagrams/README.md:55-76` | Phase 1 (now) | Either provide the referenced `tools/scripts/render-diagrams.sh` and CI workflow or update the instructions to match the current toolchain. | The doc instructs contributors to run scripts and rely on CI checks that are not present, leading to broken processes. |
| `docs/quickstart/local-dev.md:7` | Phase 1 (now) | Point the “Related: PHASE0-SETUP.md” link at `../../setup-template/phase0-template-foundation/PHASE0-SETUP.md`. | The existing relative link resolves to a non-existent file, breaking navigation. |
| `docs/quickstart/local-dev.md:36-178` | Phase 1 (now) | Rewrite the Quick Start to reference `setup-template/phase0-template-foundation/setup-phase0.sh`, remove nonexistent assets (`dev-kind-up.sh`, `app/frontend`, `tools/scripts`), and align namespace examples with Phase 0 (`demo-platform`, not `default`). | The current instructions reference scripts and directories that do not exist and mismatched namespaces, making the guide unusable. |
| `docs/runbooks/config-hot-reload.md:29-94` | Phase 1 (now) | Update commands to use the `demo-platform` namespace and correct resource names produced by the Phase 0 deployment. | The runbook instructs operators to exec into pods in `default`, which fails because PostgreSQL/Redis now run in `demo-platform`. |
| `docs/runbooks/sql-backup-restore.md:74-115` | Phase 2 (later) | Adjust CronJob paths, namespaces, and S3 instructions to match the current repository layout (or mark them as future enhancements). | References to `infra/k8s/cronjobs/postgresql-backup.yaml`, `default` namespace, and MinIO buckets don't exist, making the restore guide inaccurate. |
| `docs/runbooks/secrets-rotation.md:30-135` | Phase 2 (later) | Replace references to `tools/scripts/rotate-postgresql-password.sh`, `backend` deployment, and `default` namespace with the actual resources or mark the steps as pending implementation. | The rotation procedure points to scripts and workloads that aren’t present, so operators cannot follow it. |
| `docs/runbooks/incident-triage.md:74-170` | Phase 2 (later) | Revise troubleshooting steps to reflect the current workload names/namespaces or clearly label them as future-state examples. | The guide assumes `backend` deployments and specific dashboards that are not yet shipped, so on-call engineers cannot follow the workflow. |
| `docs/roadmap/Phase-0.md:73-112` | Phase 1 (now) | Update the “What Was Committed” table to reflect that `apps/`, `clusters/`, `infrastructure/`, `policies/`, and `kind-config.yaml` are now tracked in Git. | The roadmap still marks these paths as “not committed,” contradicting the repository’s current state. |



---

## Verification Results & Recommendations (26 Oct 2025)

| # | Path | Status | Agent Recommendation | Priority |
|---|------|--------|---------------------|----------|
| 1 | `SECURITY.md:32-47` | ✅ **FIXED** - Added Phase 2 note above checklist | ✅ **Done** - Checkboxes now have context (will be filled in Phase 2+) | **Done** |
| 2 | `docs/architecture/deployment-model.md` | ✅ **FIXED** - Now "Draft - Phase 2 work" with clear structure | ✅ **Keep as-is** - Document correctly marked as Phase 2 | Done |
| 3 | `docs/architecture/observability-strategy.md` | ✅ **FIXED** - Now "Draft - Phase 2 work" with clear structure | ✅ **Keep as-is** - Document correctly marked as Phase 2 | Done |
| 4 | `docs/architecture/testing-strategy.md` | ✅ **FIXED** - Now "Draft - Phase 2 work" with clear structure | ✅ **Keep as-is** - Document correctly marked as Phase 2 | Done |
| 5 | `docs/architecture/deployment-model.md:36-56` | ✅ **FIXED** - Duplicate References removed | ✅ **Done** - Only one References section remains | **Done** |
| 6 | `docs/architecture/observability-strategy.md:36-56` | ✅ **FIXED** - Duplicate References removed | ✅ **Done** - Only one References section remains | **Done** |
| 7 | `docs/architecture/diagrams/README.md:40-56` | ✅ **FIXED** - Replaced missing script with manual loop command | ✅ **Done** - Now uses: `for file in *.mmd; do mmdc -i "$file" -o "${file%.mmd}.png"; done` | **Done** |
| 8 | `README.md:28-36` | ✅ **VERIFIED** - Line 32 lists `CODEOWNERS` but file missing | 🔧 **Fix Phase 1** - Change to: `├─ CODEOWNERS (planned)` | Phase 1 |
| 9 | `docs/quickstart/local-dev.md:7` | ✅ **FIXED** - File rewritten as general GitOps dev guide | ✅ **Done** - New file covers prerequisites, tech stack, workflow, no phase-specific content | **Done** |
| 10 | `docs/quickstart/local-dev.md:36-178` | ✅ **FIXED** - File rewritten with correct structure | ✅ **Done** - GitOps-focused, uses Argo CD, general best practices | **Done** |
| 11 | `docs/runbooks/config-hot-reload.md:29-94` | ✅ **FIXED** - Made generic with `<namespace>` placeholders | ✅ **Done** - Added warning banner + TODO note for final namespace decision | **Done** |
| 12 | `docs/runbooks/sql-backup-restore.md:74-115` | ✅ **VERIFIED** - Line 73: `namespace: default`, Line 86: `postgresql.default.svc`, Line 114: `s3://` (MinIO missing) | ⏳ **Keep Phase 2** - Production runbook, not yet relevant | Phase 2 |
| 13 | `docs/runbooks/secrets-rotation.md:30-135` | ✅ **VERIFIED** - Line 51: `-n default`, Line 64: `backend_v2` (backend missing) | ⏳ **Keep Phase 2** - Production runbook, backend not implemented | Phase 2 |
| 14 | `docs/runbooks/incident-triage.md:74-170` | ✅ **VERIFIED** - Lines 82,94,99,104: `default` namespace, Line 108: `backend` deployment (missing) | ⏳ **Keep Phase 2** - Production runbook, backend not implemented | Phase 2 |
