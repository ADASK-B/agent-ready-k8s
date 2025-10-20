.
├─ README.md
├─ LICENSE
├─ SECURITY.md                                # + Secrets-Flow, Rotation, Break-glass, SBOM/Signing
├─ CODEOWNERS
├─ .gitignore                                 # + docs/architecture/diagrams/*.png (render outputs)
├─ .pre-commit-config.yaml
├─ Makefile
├─ .github/
│  └─ workflows/
│     ├─ ci.yml                               # Build, Test (unit/integration), SBOM, sign, push
│     ├─ cd-validate.yml                      # Helm lint, kubeval, policy checks
│     └─ diagram-check.yml                    # Mermaid lint/validate (mmdc/markdownlint)
│
├─ docs/
│  ├─ architecture/
│  │  ├─ goals-and-scope.md
│  │  ├─ ARCHITECTURE.md
│  │  ├─ deployment-model.md                  # Argo/Helm, envs, sync waves, health checks
│  │  ├─ observability-strategy.md            # + Metriken/Logs/Traces Katalog & Dashboards
│  │  ├─ testing-strategy.md                  # Testpyramide, Tools, Coverage-Ziele, perf smoke
│  │  └─ diagrams/                            # Mermaid-Diagramme (git-diffbar, CI-validiert)
│  │     ├─ README.md                         # Wie Diagramme gepflegt/gerendert werden
│  │     ├─ system-context.mmd                # C4 L1 – Systemkontext
│  │     ├─ container-diagram.mmd             # C4 L2 – Container/Komponenten
│  │     ├─ deployment-view.mmd               # CI→CD→K8s Deploy Flow
│  │     ├─ data-flow.mmd                     # E2E Org→Project→Chat
│  │     ├─ config-hot-reload.mmd             # SQL+Redis Hot-Reload Sequenz
│  │     └─ observability-stack.mmd           # Prom/Loki/Tempo/Grafana (+ Mimir-Pfad)
│  ├─ adr/
│  │  ├─ ADR-0001-config-sot-sql.md
│  │  ├─ ADR-0002-hot-reload-redis.md
│  │  ├─ ADR-0003-etcd-scope.md
│  │  ├─ ADR-0004-guest-auth.md
│  │  └─ ADR-0005-canned-chat.md
│  ├─ api/
│  │  ├─ openapi.yaml
│  │  ├─ conventions.md                       # Versioning, Auth, Idempotency, Pagination, Errors
│  │  └─ error-catalog.md
│  ├─ runbooks/
│  │  ├─ sql-backup-restore.md
│  │  ├─ config-hot-reload.md                 # Redis notify + reconcile troubleshooting
│  │  ├─ secrets-rotation.md                  # Rotationspfade (DB, Redis, JWT keys)
│  │  └─ incident-triage.md
│  └─ quickstart/
│     ├─ PHASE0-SETUP.md
│     └─ local-dev.md
│
├─ infra/
│  ├─ terraform/
│  │  ├─ modules/{cluster,network,dns}
│  │  ├─ environments/{dev,prod}/(main.tf, variables.tf, terraform.tfvars)
│  │  └─ README.md
│  ├─ argocd/
│  │  ├─ app-of-apps.yaml
│  │  └─ apps/
│  │     ├─ 01-infrastructure.yaml            # Postgres, Redis, MinIO, Ingress (Sync Wave 1)
│  │     ├─ 02-observability.yaml             # Prom/Loki/Tempo/Grafana (Wave 1–2)
│  │     ├─ 03-backend.yaml                   # Backend (Wave 2)
│  │     └─ 04-frontend.yaml                  # Frontend (Wave 3)
│  ├─ helm-charts/
│  │  ├─ infrastructure/                      # gespiegelt/gekapselt (optional)
│  │  │  ├─ postgresql/  ├─ redis/  ├─ minio/  └─ ingress-nginx/
│  │  └─ application/
│  │     ├─ backend/                          # unser Chart (values-dev/prod.yaml)
│  │     └─ frontend/
│  ├─ grafana/
│  │  ├─ dashboards/
│  │  │  ├─ golden-signals.json               # RED/USE, API Latenz, Fehlerquote, Sättigung
│  │  │  ├─ business-metrics.json             # Orgs/Projects/Chats Active, Actions/min
│  │  │  └─ infrastructure.json               # Postgres/Redis/MinIO Health
│  │  └─ alerts/
│  │     ├─ slos.yaml                         # Latenz/Fehler SLOs → Alertmanager
│  │     └─ infrastructure.yaml               # DB down, Queue stuck, Disk high
│  └─ policies/
│     ├─ kyverno/
│     └─ gatekeeper/
│
├─ app/
│  ├─ backend/
│  │  ├─ src/
│  │  ├─ db/
│  │  │  └─ migrations/
│  │  │     ├─ V001__initial_schema.sql       # Orgs, Projects, Users, RLS
│  │  │     ├─ V002__chat_channels.sql        # 1:1 per user, ≤3 active constraint
│  │  │     ├─ V003__service_configs.sql
│  │  │     └─ V004__audit_tables.sql
│  │  ├─ tests/
│  │  │  ├─ unit/
│  │  │  ├─ integration/                      # Testcontainers: Postgres, Redis
│  │  │  └─ e2e/                              # API Journeys (org→project→chat)
│  │  ├─ test-fixtures/                       # Seeds, sample payloads, fake JWTs
│  │  ├─ Dockerfile
│  │  └─ README.md
│  └─ frontend/
│     ├─ src/
│     ├─ tests/                               # UI smoke/E2E (Playwright/Cypress)
│     ├─ Dockerfile
│     └─ README.md
│
├─ tools/
│  ├─ scripts/
│  │  ├─ dev-kind-up.sh
│  │  ├─ seed-demo-data.sh
│  │  ├─ lint-all.sh
│  │  ├─ gen-sbom.sh
│  │  └─ render-diagrams.sh                   # mmd → png (mermaid-cli), optional lokal
│  ├─ codegen/
│  │  └─ openapi-codegen.config.json
│  └─ ct/
│     └─ config.yaml                          # chart-testing
│
└─ setup-template/
   └─ phase0-template-foundation/PHASE0-SETUP.md
