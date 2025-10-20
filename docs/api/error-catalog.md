# API Error Catalog

> **Purpose:** Standard error codes, HTTP status mappings, and troubleshooting.
>
> **Audience:** Backend developers, API consumers, support engineers
>
> **Related:** [conventions.md](conventions.md), [openapi.yaml](openapi.yaml)

---

## Error Format

All errors follow this JSON structure:

```json
{
  "error_code": "VALIDATION_ERROR",
  "message": "Invalid request body",
  "details": {
    "field": "name",
    "issue": "must be at least 3 characters"
  }
}
```

**Fields:**
- `error_code` - Machine-readable code (UPPERCASE_UNDERSCORE)
- `message` - Human-readable message (English)
- `details` - Optional context (field names, constraints)

---

## Error Codes

### Authentication Errors (401)

#### `UNAUTHORIZED`

**HTTP Status:** 401
**Message:** "JWT invalid or expired"
**Cause:** Missing `Authorization` header, or JWT signature invalid
**Fix:** Sign in again via `/api/auth/signin`

**Example:**
```json
{
  "error_code": "UNAUTHORIZED",
  "message": "JWT invalid or expired"
}
```

**Request:**
```http
GET /api/organizations
Authorization: Bearer invalid_jwt
```

---

#### `TOKEN_EXPIRED`

**HTTP Status:** 401
**Message:** "JWT expired"
**Cause:** JWT `exp` claim is in the past
**Fix:** Refresh token via `/api/auth/refresh`

**Example:**
```json
{
  "error_code": "TOKEN_EXPIRED",
  "message": "JWT expired"
}
```

**Details:**
- JWT TTL: 15 minutes
- Silent refresh: Frontend should refresh every 10 minutes

---

#### `TOKEN_REVOKED`

**HTTP Status:** 401
**Message:** "JWT revoked (logged out)"
**Cause:** JWT ID (`jti`) in Redis denylist
**Fix:** Sign in again

**Example:**
```json
{
  "error_code": "TOKEN_REVOKED",
  "message": "JWT revoked (logged out)"
}
```

**Flow:**
1. User clicks "Logout"
2. Backend adds `jti` to Redis denylist
3. Subsequent requests with same JWT → 401 `TOKEN_REVOKED`

---

### Validation Errors (400)

#### `VALIDATION_ERROR`

**HTTP Status:** 400
**Message:** "Invalid request body"
**Cause:** Request body validation failed (missing fields, wrong types, constraint violations)
**Fix:** Check `details` field for specific issue

**Example 1: Missing required field**
```json
{
  "error_code": "VALIDATION_ERROR",
  "message": "Invalid request body",
  "details": {
    "name": "field is required"
  }
}
```

**Request:**
```http
POST /api/organizations
Content-Type: application/json

{
  "description": "Missing name field"
}
```

**Example 2: Field too short**
```json
{
  "error_code": "VALIDATION_ERROR",
  "message": "Invalid request body",
  "details": {
    "name": "must be at least 3 characters"
  }
}
```

**Request:**
```http
POST /api/organizations
Content-Type: application/json

{
  "name": "AB"
}
```

**Example 3: Invalid UUID**
```json
{
  "error_code": "VALIDATION_ERROR",
  "message": "Invalid request body",
  "details": {
    "org_id": "must be a valid UUID"
  }
}
```

---

#### `MALFORMED_JSON`

**HTTP Status:** 400
**Message:** "Request body is not valid JSON"
**Cause:** JSON syntax error (missing comma, unquoted keys, etc.)
**Fix:** Validate JSON with linter

**Example:**
```json
{
  "error_code": "MALFORMED_JSON",
  "message": "Request body is not valid JSON",
  "details": {
    "position": 42,
    "issue": "Unexpected token }"
  }
}
```

**Request:**
```http
POST /api/organizations
Content-Type: application/json

{
  "name": "Acme Corp",  # ❌ JSON doesn't allow comments
}
```

---

#### `INVALID_ACTION`

**HTTP Status:** 400
**Message:** "Action must be one of: 👍, 👎, Ready, Blocked, ..."
**Cause:** Chat action not in allowed enum (ADR-0005)
**Fix:** Use predefined action

**Example:**
```json
{
  "error_code": "INVALID_ACTION",
  "message": "Action must be one of: 👍, 👎, Ready, Blocked, In Review, Deployed, Tests Green, Rollback"
}
```

**Request:**
```http
POST /api/projects/7c9e6679-7425-40de-944b-e07fc1f90ae7/chat/actions
Content-Type: application/json

{
  "action": "Custom Message"
}
```

---

### Authorization Errors (403)

#### `FORBIDDEN`

**HTTP Status:** 403
**Message:** "Insufficient permissions"
**Cause:** Valid JWT, but user lacks permission (e.g., not org member)
**Fix:** Request access from org admin

**Example:**
```json
{
  "error_code": "FORBIDDEN",
  "message": "Insufficient permissions",
  "details": {
    "required_role": "org_admin",
    "user_role": "member"
  }
}
```

**Request:**
```http
DELETE /api/organizations/550e8400-e29b-41d4-a716-446655440000
Authorization: Bearer <jwt_of_non_admin_user>
```

---

### Not Found Errors (404)

#### `NOT_FOUND`

**HTTP Status:** 404
**Message:** "Resource not found"
**Cause:** Resource ID doesn't exist or user lacks access
**Fix:** Verify resource ID

**Example:**
```json
{
  "error_code": "NOT_FOUND",
  "message": "Organization not found",
  "details": {
    "resource_type": "Organization",
    "resource_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

**Request:**
```http
GET /api/organizations/550e8400-e29b-41d4-a716-446655440000
```

---

### Conflict Errors (409)

#### `CONFLICT`

**HTTP Status:** 409
**Message:** "Resource already exists"
**Cause:** Unique constraint violation (duplicate name, etc.)
**Fix:** Use different name or retrieve existing resource

**Example:**
```json
{
  "error_code": "CONFLICT",
  "message": "Organization with name 'Acme Corp' already exists",
  "details": {
    "field": "name",
    "value": "Acme Corp",
    "existing_resource_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

**Request:**
```http
POST /api/organizations
Content-Type: application/json

{
  "name": "Acme Corp"
}
```

**Resolution:**
1. Check if duplicate was intended (idempotency)
2. Retrieve existing resource: `GET /api/organizations/550e8400-...`
3. Or use different name

---

### Business Logic Errors (422)

#### `UNPROCESSABLE_ENTITY`

**HTTP Status:** 422
**Message:** "Request is valid but cannot be processed due to business rules"
**Cause:** Valid JSON/types, but violates business constraint
**Fix:** See `details` for specific constraint

**Example 1: Max projects limit**
```json
{
  "error_code": "UNPROCESSABLE_ENTITY",
  "message": "Organization has reached maximum project limit",
  "details": {
    "max_projects": 10,
    "current_projects": 10
  }
}
```

**Example 2: Chat limit**
```json
{
  "error_code": "UNPROCESSABLE_ENTITY",
  "message": "User has reached maximum active chat connections",
  "details": {
    "max_connections": 3,
    "current_connections": 3
  }
}
```

---

### Rate Limiting Errors (429)

#### `RATE_LIMIT_EXCEEDED`

**HTTP Status:** 429
**Message:** "Too many requests. Try again in N seconds."
**Cause:** Rate limit exceeded (see [conventions.md](conventions.md))
**Fix:** Wait for `Retry-After` seconds

**Example:**
```json
{
  "error_code": "RATE_LIMIT_EXCEEDED",
  "message": "Too many requests. Try again in 60 seconds.",
  "details": {
    "limit": 10,
    "window": "1 minute",
    "retry_after": 60
  }
}
```

**Response Headers:**
```http
HTTP/1.1 429 Too Many Requests
Retry-After: 60
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1729512000
```

**Rate Limits:**
- `/api/auth/signin`: 10 req/min/IP
- `/api/*/chat/actions`: 5 req/sec/user
- All other: 100 req/min/user

---

### Server Errors (500)

#### `INTERNAL_SERVER_ERROR`

**HTTP Status:** 500
**Message:** "Internal server error"
**Cause:** Unhandled exception (bug)
**Fix:** Retry; if persists, contact support

**Example:**
```json
{
  "error_code": "INTERNAL_SERVER_ERROR",
  "message": "Internal server error",
  "details": {
    "request_id": "req-7c9e6679-7425-40de-944b-e07fc1f90ae7"
  }
}
```

**Mitigation:**
- Backend logs full stack trace with `request_id`
- Alert sent to PagerDuty
- User sees generic error (no stack trace leaked)

---

### Service Unavailable Errors (503)

#### `SERVICE_UNAVAILABLE`

**HTTP Status:** 503
**Message:** "Service temporarily unavailable"
**Cause:** DB, Redis, or dependency down
**Fix:** Retry with exponential backoff

**Example:**
```json
{
  "error_code": "SERVICE_UNAVAILABLE",
  "message": "Database connection failed",
  "details": {
    "component": "postgresql",
    "retry_after": 30
  }
}
```

**Response Headers:**
```http
HTTP/1.1 503 Service Unavailable
Retry-After: 30
```

**Troubleshooting:**
1. Check `/health/ready` endpoint
2. Verify PostgreSQL/Redis status
3. Check K8s pod logs

---

## Error Code Summary Table

| Code                         | HTTP | Retry? | Cause                              |
| ---------------------------- | ---- | ------ | ---------------------------------- |
| `UNAUTHORIZED`               | 401  | ❌      | Missing/invalid JWT                |
| `TOKEN_EXPIRED`              | 401  | ✅*     | JWT expired (refresh token)        |
| `TOKEN_REVOKED`              | 401  | ❌      | JWT revoked (logged out)           |
| `VALIDATION_ERROR`           | 400  | ❌      | Invalid request body               |
| `MALFORMED_JSON`             | 400  | ❌      | JSON syntax error                  |
| `INVALID_ACTION`             | 400  | ❌      | Chat action not allowed            |
| `FORBIDDEN`                  | 403  | ❌      | Insufficient permissions           |
| `NOT_FOUND`                  | 404  | ❌      | Resource doesn't exist             |
| `CONFLICT`                   | 409  | ❌      | Duplicate resource                 |
| `UNPROCESSABLE_ENTITY`       | 422  | ❌      | Business rule violation            |
| `RATE_LIMIT_EXCEEDED`        | 429  | ✅      | Too many requests                  |
| `INTERNAL_SERVER_ERROR`      | 500  | ✅      | Unhandled exception                |
| `SERVICE_UNAVAILABLE`        | 503  | ✅      | DB/Redis down                      |

**Retry Strategy:**
- ✅* `TOKEN_EXPIRED`: Call `/api/auth/refresh` first, then retry
- ✅ `RATE_LIMIT_EXCEEDED`: Wait `Retry-After` seconds, then retry
- ✅ `INTERNAL_SERVER_ERROR`: Exponential backoff (1s, 2s, 4s, 8s)
- ✅ `SERVICE_UNAVAILABLE`: Exponential backoff (5s, 10s, 20s)
- ❌ All 4xx (except 429): Don't retry, fix request

---

## Client-Side Handling

### TypeScript Example

```typescript
async function fetchOrganizations() {
  try {
    const response = await fetch("/api/organizations", {
      headers: { Authorization: `Bearer ${jwt}` }
    });

    if (!response.ok) {
      const error = await response.json();
      
      switch (error.error_code) {
        case "TOKEN_EXPIRED":
          // Refresh token and retry
          await refreshToken();
          return fetchOrganizations();
        
        case "RATE_LIMIT_EXCEEDED":
          // Wait and retry
          const retryAfter = response.headers.get("Retry-After");
          await sleep(parseInt(retryAfter) * 1000);
          return fetchOrganizations();
        
        case "UNAUTHORIZED":
        case "TOKEN_REVOKED":
          // Redirect to sign-in
          window.location.href = "/signin";
          break;
        
        case "NOT_FOUND":
          // Show "Organization not found" message
          throw new Error(error.message);
        
        default:
          // Generic error
          throw new Error(error.message);
      }
    }

    return await response.json();
  } catch (err) {
    console.error("API request failed", err);
    throw err;
  }
}
```

---

## Troubleshooting Guide

### "JWT invalid or expired"

**Symptoms:** 401 `UNAUTHORIZED` on all requests
**Causes:**
1. JWT signature invalid (wrong secret key)
2. JWT expired (`exp` claim in past)
3. JWT revoked (logged out)

**Debug:**
```bash
# Decode JWT (client-side)
echo $JWT | cut -d. -f2 | base64 -d | jq

# Check claims:
# - exp: 1729512000 (Unix timestamp)
# - jti: token ID
```

**Fix:**
1. If expired: Call `/api/auth/refresh`
2. If revoked: Sign in again `/api/auth/signin`
3. If invalid: Check `JWT_SECRET` env var on backend

---

### "Rate limit exceeded"

**Symptoms:** 429 `RATE_LIMIT_EXCEEDED`
**Causes:**
1. Too many requests from same user/IP
2. Infinite loop in client code

**Debug:**
```bash
# Check rate limit headers
curl -I https://api.platform.example.com/api/organizations \
  -H "Authorization: Bearer $JWT"

# Response:
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1729512000
```

**Fix:**
1. Wait for `Retry-After` seconds
2. Implement exponential backoff
3. Check for infinite loops in client

---

### "Service temporarily unavailable"

**Symptoms:** 503 `SERVICE_UNAVAILABLE`
**Causes:**
1. PostgreSQL down
2. Redis down
3. K8s rolling update in progress

**Debug:**
```bash
# Check health endpoint
curl https://api.platform.example.com/health/ready

# Check K8s pods
kubectl get pods -n default
kubectl logs -n default backend-7c9e6679-abc12
```

**Fix:**
1. Retry with exponential backoff
2. Check K8s pod status
3. Check PostgreSQL/Redis connectivity

---

## Monitoring

### Metrics

```yaml
# Error rate by code
api_errors_total{error_code, endpoint, method}

# 5xx error rate
rate(api_errors_total{status=~"5.."}[5m]) > 0.01

# 4xx error rate
rate(api_errors_total{status=~"4.."}[5m]) > 0.1
```

### Alerts

```yaml
alert: HighErrorRate
expr: rate(api_errors_total{status=~"5.."}[5m]) > 0.01
for: 5m
severity: critical

alert: High4xxRate
expr: rate(api_errors_total{status=~"4.."}[5m]) > 0.2
for: 10m
severity: warning
```

---

## References

- [HTTP Status Codes](https://httpstatuses.com/)
- [RFC 7807 Problem Details](https://datatracker.ietf.org/doc/html/rfc7807)
- [API Conventions](conventions.md)
- [OpenAPI Spec](openapi.yaml)
