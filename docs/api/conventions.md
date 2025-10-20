# API Conventions

> **Purpose:** REST API design guidelines for consistent, predictable APIs.
>
> **Audience:** Backend developers, API consumers
>
> **Related:** [openapi.yaml](openapi.yaml), [error-catalog.md](error-catalog.md)

---

## 1. General Principles

### RESTful Design

✅ **Resource-Based URLs**
```
/api/organizations/{org_id}
/api/organizations/{org_id}/projects
/api/projects/{project_id}
```

❌ **Action-Based URLs (Avoid)**
```
/api/getOrganization?id=123
/api/createProject
```

### HTTP Methods

| Method   | Purpose             | Idempotent | Safe |
| -------- | ------------------- | ---------- | ---- |
| `GET`    | Retrieve resource   | ✅          | ✅    |
| `POST`   | Create resource     | ❌          | ❌    |
| `PUT`    | Replace resource    | ✅          | ❌    |
| `PATCH`  | Update resource     | ✅          | ❌    |
| `DELETE` | Delete resource     | ✅          | ❌    |

**Idempotent:** Multiple identical requests have same effect as one request.
**Safe:** Read-only, no side effects.

---

## 2. URL Structure

### Base URL

```
Production:  https://api.platform.example.com
Staging:     https://api-staging.platform.example.com
Local Dev:   http://localhost:8000
```

### API Versioning

**Strategy:** URL-based versioning (v1, v2)

```
/api/v1/organizations
/api/v2/organizations  # Breaking changes
```

**Current:** No version prefix (implicit v1). Add `/v2` when breaking changes needed.

### Path Parameters

✅ **Use for resource IDs**
```
/api/organizations/{org_id}
/api/projects/{project_id}
```

❌ **Don't use for filters**
```
/api/organizations/active  # ❌ Use query param instead
```

### Query Parameters

✅ **Use for filters, pagination, sorting**
```
GET /api/projects?limit=20&offset=40&status=active&sort=created_at:desc
```

**Reserved query params:**
- `limit` - Max results (default: 20, max: 100)
- `offset` - Pagination offset (default: 0)
- `sort` - Sort field + direction (`field:asc`, `field:desc`)
- `q` - Full-text search query

---

## 3. Request Format

### Content-Type

```http
POST /api/organizations
Content-Type: application/json
```

**Supported:**
- `application/json` (primary)
- `application/x-www-form-urlencoded` (form submissions only)

**Not supported:**
- `application/xml`
- `text/plain`

### Request Body (JSON)

```json
{
  "name": "Acme Corp",
  "description": "Main organization"
}
```

**Conventions:**
- `snake_case` field names
- ISO 8601 timestamps (`2025-10-20T12:00:00Z`)
- UUIDs for IDs (not integers)

### Authentication Header

```http
GET /api/organizations
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Format:** `Authorization: Bearer <jwt>`

**When not required:**
- `/api/auth/signin` (guest sign-in)
- `/health`, `/health/ready` (health checks)

### Idempotency Keys (Optional)

For `POST` requests (create operations), clients can send idempotency key to prevent duplicates:

```http
POST /api/organizations
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
Content-Type: application/json

{
  "name": "Acme Corp"
}
```

**Backend behavior:**
- First request with key → 201 Created
- Duplicate request with same key → 200 OK (returns cached response)
- Key expires after 24 hours

**Use cases:**
- Network retries (prevent duplicate orgs/projects)
- User double-clicks submit button

---

## 4. Response Format

### Success Responses

#### Single Resource

```http
GET /api/organizations/550e8400-e29b-41d4-a716-446655440000
200 OK
Content-Type: application/json

{
  "org_id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Acme Corp",
  "description": "Main organization",
  "created_at": "2025-10-20T12:00:00Z",
  "updated_at": "2025-10-20T12:00:00Z"
}
```

#### Collection (List)

```http
GET /api/organizations?limit=20&offset=0
200 OK
Content-Type: application/json

{
  "data": [
    {
      "org_id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Acme Corp",
      "created_at": "2025-10-20T12:00:00Z",
      "updated_at": "2025-10-20T12:00:00Z"
    }
  ],
  "pagination": {
    "limit": 20,
    "offset": 0,
    "total": 100
  }
}
```

**Pagination:**
- `limit` - Requested page size
- `offset` - Current offset
- `total` - Total count (expensive, may be omitted if >10K results)

#### Create Resource (201 Created)

```http
POST /api/organizations
201 Created
Location: /api/organizations/550e8400-e29b-41d4-a716-446655440000
Content-Type: application/json

{
  "org_id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Acme Corp",
  "created_at": "2025-10-20T12:00:00Z",
  "updated_at": "2025-10-20T12:00:00Z"
}
```

**Location header:** URL of created resource.

#### Delete Resource (204 No Content)

```http
DELETE /api/organizations/550e8400-e29b-41d4-a716-446655440000
204 No Content
```

**No response body** for 204.

---

## 5. Error Responses

See [error-catalog.md](error-catalog.md) for complete list.

### Error Format

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
- `error_code` - Machine-readable code (uppercase, underscores)
- `message` - Human-readable message (English)
- `details` - Optional context (field name, constraint)

### Common HTTP Status Codes

| Status | Meaning            | When to Use                                                       |
| ------ | ------------------ | ----------------------------------------------------------------- |
| 200    | OK                 | Success (GET, PATCH, PUT)                                         |
| 201    | Created            | Resource created (POST)                                           |
| 204    | No Content         | Success, no body (DELETE)                                         |
| 400    | Bad Request        | Validation error, malformed JSON                                  |
| 401    | Unauthorized       | Missing/invalid JWT                                               |
| 403    | Forbidden          | Valid JWT, insufficient permissions                               |
| 404    | Not Found          | Resource not found                                                |
| 409    | Conflict           | Duplicate resource (unique constraint violation)                  |
| 422    | Unprocessable      | Valid JSON, but business logic error (e.g., "org already has 10 projects") |
| 429    | Too Many Requests  | Rate limit exceeded                                               |
| 500    | Internal Error     | Unexpected server error (bug)                                     |
| 503    | Service Unavailable| DB/Redis down (temporary)                                         |

---

## 6. Rate Limiting

### Limits

| Endpoint                 | Limit            |
| ------------------------ | ---------------- |
| `/api/auth/signin`       | 10 req/min/IP    |
| `/api/*/chat/actions`    | 5 req/sec/user   |
| All other endpoints      | 100 req/min/user |

### Rate Limit Headers

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 42
X-RateLimit-Reset: 1729512000
```

### Rate Limit Exceeded (429)

```http
429 Too Many Requests
Retry-After: 60
Content-Type: application/json

{
  "error_code": "RATE_LIMIT_EXCEEDED",
  "message": "Too many requests. Try again in 60 seconds."
}
```

**Retry-After header:** Seconds until rate limit resets.

---

## 7. Pagination

### Offset-Based Pagination (Default)

```http
GET /api/projects?limit=20&offset=40
```

**Query params:**
- `limit` - Page size (default: 20, max: 100)
- `offset` - Skip N results (default: 0)

**Response:**
```json
{
  "data": [...],
  "pagination": {
    "limit": 20,
    "offset": 40,
    "total": 100
  }
}
```

**Pros:**
- Simple
- Jump to any page

**Cons:**
- Inconsistent results if data changes (e.g., new project inserted)

### Cursor-Based Pagination (Future)

For real-time feeds (chat, events):

```http
GET /api/events?limit=20&after=cursor123
```

**Pros:**
- Consistent results (no missed/duplicate items)

**Cons:**
- Can't jump to page N

---

## 8. Sorting

### Query Param

```http
GET /api/projects?sort=created_at:desc
```

**Format:** `field:direction`
- `direction` = `asc` or `desc`
- Multiple sorts: `?sort=status:asc,created_at:desc`

### Default Sort

Each endpoint has default sort:
- Organizations: `created_at:desc`
- Projects: `created_at:desc`

---

## 9. Filtering

### Query Params

```http
GET /api/projects?org_id=550e8400-e29b-41d4-a716-446655440000&status=active
```

**Operators (simple):**
- Equals: `?status=active`
- Multiple values (OR): `?status=active,archived`

**Operators (advanced, future):**
- Greater than: `?created_at[gt]=2025-10-01`
- Less than: `?created_at[lt]=2025-11-01`

---

## 10. Timestamps

### Format

**ISO 8601 with UTC timezone:**
```json
{
  "created_at": "2025-10-20T12:00:00Z",
  "updated_at": "2025-10-20T12:30:00Z"
}
```

**Rules:**
- Always UTC (`Z` suffix)
- Precision: seconds (no milliseconds)
- Format: `YYYY-MM-DDTHH:MM:SSZ`

### Standard Fields

All resources have:
- `created_at` - Creation timestamp (never changes)
- `updated_at` - Last update timestamp (changes on PATCH/PUT)
- `deleted_at` - Soft-delete timestamp (nullable)

---

## 11. Resource IDs

### UUIDs (v4)

All resource IDs are UUIDs (not integers):

```json
{
  "org_id": "550e8400-e29b-41d4-a716-446655440000",
  "project_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7"
}
```

**Why UUIDs?**
- ✅ No ID enumeration attacks
- ✅ Globally unique (no collisions)
- ✅ Client-generated (offline-first apps)

**Why NOT integers?**
- ❌ Enumeration attacks (`/api/orgs/1`, `/api/orgs/2`, ...)
- ❌ Leaks info (org ID 1000 → 1000 orgs exist)

---

## 12. Soft Deletes

### DELETE Behavior

`DELETE /api/organizations/{org_id}` → Sets `deleted_at` (soft-delete).

**Database:**
```sql
UPDATE organizations SET deleted_at = now() WHERE org_id = ?;
```

**Response:**
```http
204 No Content
```

**Listing:**
```sql
SELECT * FROM organizations WHERE deleted_at IS NULL;
```

### Hard Deletes (Admin Only)

Manual cleanup via SQL (not exposed in API):
```sql
DELETE FROM organizations WHERE deleted_at < now() - INTERVAL '90 days';
```

---

## 13. Validation Rules

### General

- **Required fields:** 400 Bad Request if missing
- **Max lengths:** 400 Bad Request if exceeded
- **UUIDs:** 400 Bad Request if invalid format

### Example Validation Errors

```json
{
  "error_code": "VALIDATION_ERROR",
  "message": "Invalid request body",
  "details": {
    "name": "must be at least 3 characters",
    "org_id": "must be a valid UUID"
  }
}
```

---

## 14. CORS (Cross-Origin)

### Allowed Origins

```http
Access-Control-Allow-Origin: https://app.platform.example.com
Access-Control-Allow-Methods: GET, POST, PATCH, DELETE, OPTIONS
Access-Control-Allow-Headers: Authorization, Content-Type, Idempotency-Key
Access-Control-Max-Age: 3600
```

**Local dev:**
```http
Access-Control-Allow-Origin: http://localhost:3000
```

---

## 15. Deprecation

### Deprecation Header

```http
GET /api/v1/organizations
200 OK
Deprecation: true
Sunset: Sat, 01 Jan 2026 00:00:00 GMT
Link: </api/v2/organizations>; rel="successor-version"
```

**Deprecation process:**
1. Add `Deprecation` header (6 months notice)
2. Add `Sunset` header (end-of-life date)
3. Log warnings in client SDK
4. Remove endpoint after sunset date

---

## 16. OpenAPI Spec

All endpoints documented in [openapi.yaml](openapi.yaml).

**Generate client SDKs:**
```bash
# TypeScript
openapi-generator-cli generate -i docs/api/openapi.yaml -g typescript-axios -o sdk/typescript

# Python
openapi-generator-cli generate -i docs/api/openapi.yaml -g python -o sdk/python
```

---

## 17. Examples

### Create Organization

```bash
curl -X POST https://api.platform.example.com/api/organizations \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Acme Corp",
    "description": "Main organization"
  }'
```

**Response:**
```json
{
  "org_id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Acme Corp",
  "description": "Main organization",
  "created_at": "2025-10-20T12:00:00Z",
  "updated_at": "2025-10-20T12:00:00Z"
}
```

### List Projects

```bash
curl -X GET "https://api.platform.example.com/api/organizations/550e8400-e29b-41d4-a716-446655440000/projects?limit=20" \
  -H "Authorization: Bearer $JWT"
```

### Update Config (Hot-Reload)

```bash
curl -X PUT https://api.platform.example.com/api/configs/ai.threshold \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"value": "0.85"}'
```

---

## 18. Checklist for New Endpoints

- [ ] RESTful URL (`/api/resources/{id}`)
- [ ] Correct HTTP method (GET/POST/PATCH/DELETE)
- [ ] JWT auth required (except health/signin)
- [ ] Request validation (400 for invalid input)
- [ ] Error responses (400/401/404/500)
- [ ] Documented in `openapi.yaml`
- [ ] Rate limiting configured
- [ ] Integration test written
- [ ] Idempotency key support (if POST)
- [ ] Soft-delete (not hard-delete)

---

## References

- [OpenAPI 3.1 Spec](https://spec.openapis.org/oas/v3.1.0)
- [REST API Best Practices](https://restfulapi.net/)
- [HTTP Status Codes](https://httpstatuses.com/)
- [ISO 8601 Timestamps](https://en.wikipedia.org/wiki/ISO_8601)
