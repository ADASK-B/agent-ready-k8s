# Testing Strategy

> **Status:** Draft - needs content
> **Owner:** Engineering Team
> **Last Updated:** 20 October 2025

## Overview

This document defines the testing approach, test pyramid, tools, coverage goals, and quality gates for the platform and applications.

## Table of Contents

- [Testing Principles](#testing-principles)
- [Test Pyramid](#test-pyramid)
- [Unit Tests](#unit-tests)
- [Integration Tests](#integration-tests)
- [End-to-End Tests](#end-to-end-tests)
- [Performance Tests](#performance-tests)
- [Security Tests](#security-tests)
- [Quality Gates](#quality-gates)

---

## Testing Principles

### Core Principles

1. **Shift Left** - Test early and often
2. **Fast Feedback** - Fast tests run frequently
3. **Isolate Failures** - Tests should not depend on each other
4. **Realistic Data** - Use production-like data
5. **Test in Production** - Synthetic monitoring

### Coverage Goals

- **Unit Tests:** ≥ 80% code coverage
- **Integration Tests:** All critical paths
- **E2E Tests:** All user journeys
- **Performance Tests:** All APIs under load

---

## Test Pyramid

```
        /\
       /  \  E2E Tests (10%)
      /----\
     /      \  Integration Tests (30%)
    /--------\
   /          \  Unit Tests (60%)
  /--------------\
```

### Distribution

- **60% Unit Tests** - Fast, focused, low cost
- **30% Integration Tests** - Component interactions
- **10% E2E Tests** - Full user flows

---

## Unit Tests

### Scope

- Individual functions/methods
- Business logic
- Data transformations
- Utility functions

### Tools

- **Backend:** pytest (Python), Jest (Node.js)
- **Frontend:** Vitest, React Testing Library

### Best Practices

```python
# Example: Backend unit test
def test_create_organization():
    org = create_organization(name="ACME Corp")
    assert org.name == "ACME Corp"
    assert org.status == "active"
```

### Coverage Target

- **≥ 80%** overall
- **100%** for critical business logic

---

## Integration Tests

### Scope

- API endpoints
- Database interactions
- Redis Pub/Sub
- External service integrations

### Tools

- **Testcontainers** - Real PostgreSQL, Redis in Docker
- **pytest-asyncio** - Async API tests
- **Supertest** - HTTP API testing (Node.js)

### Best Practices

```python
# Example: Integration test with Testcontainers
@pytest.fixture
def postgres_container():
    with PostgresContainer("postgres:16") as postgres:
        yield postgres

def test_create_organization_db(postgres_container):
    db = connect(postgres_container.get_connection_url())
    org = create_organization_db(db, name="ACME Corp")
    assert db.query("SELECT * FROM organizations WHERE id = ?", org.id)
```

### Test Data

- [ ] Fixtures for common scenarios
- [ ] Factory pattern for test data generation
- [ ] Database migrations run before tests

---

## End-to-End Tests

### Scope

- Full user journeys
- Browser-based workflows
- API orchestration

### Tools

- **Playwright** - Browser automation (preferred)
- **Cypress** - Alternative
- **k6** - API E2E tests

### User Journeys

| Journey | Steps | Priority |
|---------|-------|----------|
| **Sign In** | 1. Open app → 2. Guest sign-in → 3. Dashboard | P0 |
| **Create Org** | 1. Click "New Org" → 2. Fill form → 3. Submit → 4. Verify | P0 |
| **Create Project** | 1. Select Org → 2. New Project → 3. Fill → 4. Submit | P0 |
| **Chat Action** | 1. Open Project → 2. Chat → 3. 👍 action → 4. Verify WS | P1 |
| **Config Hot-Reload** | 1. Update config → 2. Verify < 100ms reload | P1 |

### Example

```javascript
// Playwright E2E test
test('Create organization flow', async ({ page }) => {
  await page.goto('https://app.example.com');
  await page.click('text=New Organization');
  await page.fill('input[name="name"]', 'ACME Corp');
  await page.click('button[type="submit"]');
  await expect(page.locator('text=ACME Corp')).toBeVisible();
});
```

---

## Performance Tests

### Scope

- API load testing
- Database query performance
- Hot-reload latency
- Concurrent user simulation

### Tools

- **k6** - Load testing (preferred)
- **Locust** - Python-based load tests
- **Apache Bench (ab)** - Quick API benchmarks

### Test Scenarios

| Scenario | Load | Duration | Success Criteria |
|----------|------|----------|------------------|
| **Baseline** | 10 req/s | 5 min | P95 < 500ms, 0% errors |
| **Stress** | 100 req/s | 10 min | P95 < 1s, < 1% errors |
| **Spike** | 10 → 500 req/s | 2 min | No crashes, < 5% errors |
| **Soak** | 50 req/s | 1 hour | No memory leaks |

### Example

```javascript
// k6 load test
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  vus: 50,
  duration: '5m',
};

export default function() {
  let res = http.get('https://api.example.com/organizations');
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
}
```

---

## Security Tests

### Scope

- Vulnerability scanning
- Dependency audits
- Secret leakage detection
- API security (OWASP Top 10)

### Tools

- **Trivy** - Container image scanning
- **Snyk** - Dependency vulnerabilities
- **GitLeaks** - Secret detection in Git
- **OWASP ZAP** - Dynamic security testing

### Checks

- [ ] No Critical CVEs in images
- [ ] No secrets in Git history
- [ ] Authentication required on all APIs
- [ ] RBAC enforced
- [ ] Input validation (SQL injection, XSS)

---

## Quality Gates

### CI/CD Pipeline

```
PR → Unit Tests → Integration Tests → Build → Security Scan → E2E Tests → Deploy
```

### Merge Criteria

- [ ] All tests pass (unit + integration)
- [ ] Code coverage ≥ 80%
- [ ] No Critical CVEs
- [ ] Linting passes
- [ ] PR approved by 1+ reviewers

### Deployment Gates

- [ ] All tests pass in Stage environment
- [ ] Performance tests pass (P95 < 500ms)
- [ ] Security scans pass
- [ ] Manual approval (production only)

---

## Test Environments

### Environments

| Environment | Purpose | Data | Tests Run |
|-------------|---------|------|-----------|
| **Local** | Developer testing | Synthetic | Unit, Integration |
| **CI** | Pull Request validation | Synthetic | Unit, Integration, E2E |
| **Stage** | Pre-production validation | Production-like | Full suite + perf |
| **Prod** | Synthetic monitoring | Real | Smoke tests only |

### Test Data Strategy

- **Synthetic:** Generated test data (factories)
- **Anonymized:** Production data with PII removed
- **Real:** Production (read-only, monitoring only)

---

## Monitoring & Observability

### Test Metrics

- [ ] Test execution time
- [ ] Test flakiness rate
- [ ] Code coverage trends
- [ ] Failed test breakdown

### Alerts

- [ ] Tests failing on main branch
- [ ] Coverage drops below 80%
- [ ] E2E tests fail (production smoke)

---

## Best Practices

### Do's

- ✅ Write tests before fixing bugs
- ✅ Use Testcontainers for real dependencies
- ✅ Isolate tests (no shared state)
- ✅ Use realistic test data
- ✅ Run tests in CI on every PR

### Don'ts

- ❌ Skip tests to "save time"
- ❌ Test implementation details
- ❌ Use sleep/wait (use proper waits)
- ❌ Depend on external services (mock them)
- ❌ Commit failing tests

---

## References

- [Test Pyramid - Martin Fowler](https://martinfowler.com/articles/practical-test-pyramid.html)
- [Testcontainers Documentation](https://testcontainers.com/)
- [Playwright Documentation](https://playwright.dev/)
- [k6 Documentation](https://k6.io/docs/)
