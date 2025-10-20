# Local Development Setup

> **Purpose:** Run the full stack locally (kind cluster + PostgreSQL + Redis + Backend + Frontend).
>
> **Audience:** Developers
>
> **Related:** [PHASE0-SETUP.md](PHASE0-SETUP.md), [Boot-Routine.md](Boot-Routine.md)

---

## Prerequisites

Before starting, complete [PHASE0-SETUP.md](../../setup-template/phase0-template-foundation/PHASE0-SETUP.md):
- ✅ Docker (24.0+)
- ✅ kind (0.20+)
- ✅ kubectl (1.28+)
- ✅ Helm (3.12+)
- ✅ Argo CD CLI (2.8+)
- ✅ kind cluster running (`kind get clusters` → `kind`)

---

## Quick Start (10 Minutes)

### 1. Clone Repository

```bash
git clone https://github.com/example/agent-ready-k8s.git
cd agent-ready-k8s
```

---

### 2. Run Phase 0 Setup (If Not Done)

```bash
cd setup-template/phase0-template-foundation
./dev-kind-up.sh

# Wait for all services (3-4 minutes)
# ✅ kind cluster created
# ✅ PostgreSQL running
# ✅ Redis running
# ✅ Argo CD running
# ✅ NGINX Ingress running
```

**Verify:**
```bash
kubectl get pods -n default
# Should show: postgresql-0, redis-0, podinfo-*

kubectl get pods -n argocd
# Should show: argocd-server-*, argocd-repo-server-*
```

---

### 3. Add `/etc/hosts` Entries

```bash
# Add local domains
echo "127.0.0.1 argocd.local" | sudo tee -a /etc/hosts
echo "127.0.0.1 podinfo.local" | sudo tee -a /etc/hosts
echo "127.0.0.1 api.platform.local" | sudo tee -a /etc/hosts
echo "127.0.0.1 app.platform.local" | sudo tee -a /etc/hosts
```

**Verify:**
```bash
curl http://podinfo.local
# Should return: {"hostname":"podinfo-..."}
```

---

### 4. Run Backend (Python)

```bash
cd app/backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/demo-platform"
export REDIS_URL="redis://localhost:6379/0"
export JWT_SECRET="dev-secret-key-change-in-production"

# Port-forward PostgreSQL & Redis
kubectl port-forward -n default postgresql-0 5432:5432 &
kubectl port-forward -n default redis-0 6379:6379 &

# Run migrations
alembic upgrade head

# Start backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**Verify:**
```bash
curl http://localhost:8000/health
# {"status":"ok"}

curl http://localhost:8000/health/ready
# {"status":"ready","checks":{"database":"ok","redis":"ok"}}
```

---

### 5. Run Frontend (React/Next.js)

```bash
cd app/frontend

# Install dependencies
npm install

# Set environment variables
export NEXT_PUBLIC_API_URL="http://localhost:8000"

# Start dev server
npm run dev
```

**Verify:**
Open http://localhost:3000 in browser.

---

## Development Workflow

### A. Database Migrations

#### Create New Migration

```bash
cd app/backend
source venv/bin/activate

# Auto-generate migration from model changes
alembic revision --autogenerate -m "Add user_roles table"

# Review generated migration
cat alembic/versions/abc123_add_user_roles_table.py
```

#### Apply Migration

```bash
alembic upgrade head
```

#### Rollback Migration

```bash
alembic downgrade -1  # Rollback 1 step
```

---

### B. Seed Demo Data

```bash
cd tools/scripts
./seed-demo-data.sh

# Creates:
# - 2 Organizations (Acme Corp, Beta LLC)
# - 5 Projects per org
# - 10 Users
# - 100 Config entries
```

**Verify:**
```bash
kubectl exec -it postgresql-0 -n default -- psql -U postgres -d demo-platform -c \
  "SELECT count(*) FROM organizations;"
# Should return: 2
```

---

### C. Testing

#### Unit Tests (Backend)

```bash
cd app/backend
source venv/bin/activate

# Run all tests
pytest

# Run specific test
pytest tests/test_organizations.py

# Run with coverage
pytest --cov=. --cov-report=html
open htmlcov/index.html
```

#### Integration Tests (Backend)

```bash
# Start Testcontainers (PostgreSQL + Redis)
pytest tests/integration/

# Testcontainers auto-starts/stops containers
```

#### E2E Tests (Playwright)

```bash
cd tests/e2e

# Install Playwright
npm install
npx playwright install

# Run E2E tests
npx playwright test

# Run in headed mode (see browser)
npx playwright test --headed

# Run specific test
npx playwright test tests/auth.spec.ts
```

---

### D. Hot-Reload Testing

#### Test Config Hot-Reload

```bash
# Terminal 1: Subscribe to Redis Pub/Sub
kubectl exec -it redis-0 -n default -- redis-cli SUBSCRIBE "config:*"

# Terminal 2: Update config via API
curl -X PUT http://localhost:8000/api/configs/ai.threshold \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"value": "0.99"}'

# Terminal 1: Should show:
# 1) "message"
# 2) "config:ai:threshold"
# 3) "version=5"
```

---

### E. Debugging

#### Backend (Python)

```python
# Add breakpoint in code
import pdb; pdb.set_trace()

# Or use VS Code debugger
# .vscode/launch.json:
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Backend (Uvicorn)",
      "type": "python",
      "request": "launch",
      "module": "uvicorn",
      "args": ["main:app", "--reload"],
      "env": {
        "DATABASE_URL": "postgresql://postgres:postgres@localhost:5432/demo-platform",
        "REDIS_URL": "redis://localhost:6379/0"
      }
    }
  ]
}
```

#### Frontend (React)

```javascript
// Add debugger statement
debugger;

// Or use Chrome DevTools
// F12 → Sources → Set breakpoint
```

---

## Common Commands

### PostgreSQL

```bash
# Connect to PostgreSQL
kubectl exec -it postgresql-0 -n default -- psql -U postgres -d demo-platform

# List tables
\dt

# Describe table
\d organizations

# Run query
SELECT * FROM organizations LIMIT 10;

# Exit
\q
```

---

### Redis

```bash
# Connect to Redis
kubectl exec -it redis-0 -n default -- redis-cli

# Get all keys
KEYS *

# Get value
GET config:ai:threshold

# Subscribe to channel
SUBSCRIBE config:*

# Publish event
PUBLISH config:ai:threshold "version=5"

# Exit
exit
```

---

### Argo CD

```bash
# Login (password from Phase 0 output)
argocd login argocd.local --insecure

# List apps
argocd app list

# Sync app
argocd app sync podinfo

# View app details
argocd app get podinfo
```

---

### Logs

```bash
# Backend logs
kubectl logs -n default -l app=backend --tail=100 -f

# PostgreSQL logs
kubectl logs -n default postgresql-0 --tail=100 -f

# Redis logs
kubectl logs -n default redis-0 --tail=100 -f

# Argo CD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100 -f
```

---

## Troubleshooting

### "Port already in use"

**Symptom:** `uvicorn` fails with "Address already in use"
**Fix:**
```bash
# Find process using port 8000
lsof -i :8000

# Kill process
kill -9 <PID>
```

---

### "Database connection refused"

**Symptom:** Backend logs show "connection refused"
**Fix:**
```bash
# Check PostgreSQL pod
kubectl get pods -n default -l app=postgresql

# Port-forward PostgreSQL
kubectl port-forward -n default postgresql-0 5432:5432

# Test connection
psql -h localhost -U postgres -d demo-platform -c "SELECT 1;"
```

---

### "Redis connection timeout"

**Symptom:** Backend logs show "redis.exceptions.TimeoutError"
**Fix:**
```bash
# Check Redis pod
kubectl get pods -n default -l app=redis

# Port-forward Redis
kubectl port-forward -n default redis-0 6379:6379

# Test connection
redis-cli -h localhost PING
```

---

### "Frontend can't connect to backend"

**Symptom:** Browser console shows "CORS error" or "Network error"
**Fix:**
```bash
# Verify backend CORS config (backend/main.py)
# Should include: origins=["http://localhost:3000"]

# Verify backend running
curl http://localhost:8000/health

# Check NEXT_PUBLIC_API_URL
echo $NEXT_PUBLIC_API_URL
# Should be: http://localhost:8000
```

---

## IDE Setup

### VS Code (Recommended)

#### Extensions

Install:
- Python (ms-python.python)
- Pylance (ms-python.vscode-pylance)
- ESLint (dbaeumer.vscode-eslint)
- Prettier (esbenp.prettier-vscode)
- Docker (ms-azuretools.vscode-docker)
- Kubernetes (ms-kubernetes-tools.vscode-kubernetes-tools)

#### Workspace Settings

```json
// .vscode/settings.json
{
  "python.defaultInterpreterPath": "${workspaceFolder}/app/backend/venv/bin/python",
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": true,
  "python.formatting.provider": "black",
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.organizeImports": true
  }
}
```

---

### PyCharm

#### Project Setup

1. File → Open → Select `agent-ready-k8s/`
2. Configure Python interpreter: `app/backend/venv/bin/python`
3. Mark `app/backend` as "Sources Root"
4. Enable `pytest` as test runner

---

## Performance Tips

### A. Skip Tests for Fast Iteration

```bash
# Run backend without tests
uvicorn main:app --reload
```

### B. Use Docker Compose (Alternative to kind)

```yaml
# docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: demo-platform
    ports:
      - "5432:5432"
  
  redis:
    image: redis:7
    ports:
      - "6379:6379"
```

```bash
docker-compose up -d
```

---

### C. Use `entr` for Auto-Reload (Backend)

```bash
# Install entr (macOS)
brew install entr

# Auto-reload on file change
find app/backend -name "*.py" | entr -r uvicorn main:app --reload
```

---

## Next Steps

After local dev setup:
- [ ] Read [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) for design decisions
- [ ] Review [ADRs](../adr/) for context on key choices
- [ ] Check [API docs](../api/openapi.yaml) for endpoint specs
- [ ] Run [testing-strategy.md](../architecture/testing-strategy.md) test suite
- [ ] Deploy to staging (see `infra/terraform/`)

---

## References

- [Phase 0 Setup](../../setup-template/phase0-template-foundation/PHASE0-SETUP.md)
- [Boot Routine](Boot-Routine.md)
- [Architecture Docs](../architecture/)
- [API Docs](../api/)
- [Runbooks](../runbooks/)
