# Repository Guidelines

## Project Structure & Module Organization
- `apps/` carries Kustomize bases (`apps/<service>/base`) and tenant overlays (`apps/<service>/tenants/<org>`); keep bases generic and overlays minimal.
- `clusters/` captures environment or provider wiring; put shared defaults in `clusters/base` and overlays under `clusters/<target>/`.
- `helm-charts/infrastructure/` stores curated charts (ingress-nginx, podinfo, postgresql, redis); update values here before referencing them from Argo CD.
- `infra/` hosts automation code such as Terraform modules or Argo bootstrap logic; keep helper scripts inside this tree rather than at repo root.
- `policies/` tracks admission controls and security guardrails, while `docs/` contains architecture decisions and runbooks that must accompany structural changes.

## Build, Test, and Development Commands
- Provision the local kind stack with `./setup-template/phase0-template-foundation/setup-phase0.sh`.
- Apply a tenant overlay via `kubectl apply -k apps/podinfo/tenants/demo` and switch `demo` to your tenant path when testing changes.
- Run `kustomize build <path> | kubeconform --strict` on every manifest path touched by your change.
- Check Argo CD sync with `kubectl get applications.argoproj.io -n argocd`.
- After adjusting a chart, execute `helm dependency update helm-charts/infrastructure/<chart>` so `Chart.lock` stays authoritative.

## Coding Style & Naming Conventions
- YAML uses two-space indentation and the key order `apiVersion`, `kind`, `metadata`, `spec`, `status`.
- Directories stay `kebab-case`, Kubernetes resource names use `PascalCase`, and namespaces follow `tenant-<name>`.
- Helm values should be lowercase, concise, and documented with short comments only when intent is unclear.

## Testing Guidelines
- Manifest changes require a `kubeconform` run and a smoke test: `kubectl apply -k <tenant>` then `kubectl rollout status deployment/<component> -n tenant-<name>`.
- Store SQL migrations in `app/backend/db/migrations` and run them with short-lived Kubernetes Jobs.
- Document manual verification in `docs/runbooks/`.

## Commit & Pull Request Guidelines
- Follow the repository pattern `type(scope): short description`, e.g. `fix(phase1): harden Redis network policy`; emojis are optional.
- Squash intermediary commits, link to relevant docs or ADRs, and enumerate the commands you executed (kubeconform, kubectl, Helm) in the PR body.
- Share diffs and CLI snippets as fenced code blocks so reviewers can copy-paste during validation.

## Security & Configuration Tips
- Never commit secrets; rely on External Secrets or sealed manifests under `policies/` or the relevant tenant overlay.
- Align ingress hosts, `kind-config.yaml`, and `/etc/hosts` entries whenever routes change.

## Agent Workflow Notes
- Replies must be in English, regardless of input language.
- Follow `.github/copilot-instructions.md`: read `docs/architecture/ARCHITECTURE.md` before infra decisions and load only the minimal supporting doc.
