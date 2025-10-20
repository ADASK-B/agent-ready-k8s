# ADR-0004: Guest Sign-In (No Registration, No PII)

> **Status:** Accepted
> **Date:** 20 October 2025
> **Deciders:** Platform Team, Security Team, Product Team
> **Related:** [goals-and-scope.md](../architecture/goals-and-scope.md)

## Context

Multi-tenant SaaS platforms typically require user registration (email, password, PII). This creates:
- GDPR compliance burden
- Data breach liability
- Account management complexity
- Password reset flows
- Email verification

### Requirements

1. **No PII** - No email, name, phone, address
2. **Fast Onboarding** - One-click sign-in
3. **Secure** - Prevent abuse, replay attacks
4. **Multi-Session** - Multiple browsers/devices
5. **Revocable** - Logout = token revoked

---

## Decision

**We will use "Guest Sign-In" with short-lived JWT + JTI denylist (no registration, no PII).**

Users click "Sign In as Guest" → Backend generates JWT → User accesses platform.

---

## Rationale

### Why Guest Sign-In?

✅ **Zero PII** - No GDPR, no breach liability
✅ **Instant Onboarding** - One click, no forms
✅ **Simple** - No password reset, no email verification
✅ **Secure** - JWT with short TTL (15 min)
✅ **Revocable** - JTI denylist for logout

### Why NOT Traditional Registration?

❌ **PII Collection** - GDPR, CCPA, data breach risk
❌ **Slow Onboarding** - Fill form, verify email (3-5 min)
❌ **Password Management** - Reset flows, complexity rules
❌ **Account Recovery** - Email verification, security questions

### Why NOT OIDC (OAuth2)?

❌ **PII Exposure** - OIDC providers (Google, GitHub) require email
❌ **External Dependency** - Outage = login broken
❌ **Complex Setup** - Client ID, secret, callback URL

---

## Consequences

### Positive

- ✅ **No GDPR Compliance** - Zero PII = no data subject requests
- ✅ **No Breach Liability** - No passwords = no password breaches
- ✅ **Fast Onboarding** - One click (3 seconds)
- ✅ **Simple Architecture** - No user DB, no email service

### Negative

- ⚠️ **No Account Recovery** - If JWT lost, user must sign in again (creates new account)
- ⚠️ **No Identity Continuity** - Clearing browser cookies = new account

### Trade-Offs

- **Pro:** Zero PII = zero breach liability
- **Con:** No "remember me" across devices (unless user manually shares JWT)

---

## Implementation

### Flow

```
1. User clicks "Sign In as Guest"
2. Backend generates JWT with:
   - sub: user_id (UUID)
   - jti: token_id (UUID, for revocation)
   - exp: 15 minutes
   - iat: issued_at
3. Backend returns JWT to frontend
4. Frontend stores JWT in:
   - Memory (for SPA session)
   - LocalStorage (for "remember me" - optional, user choice)
5. Frontend sends JWT in Authorization header:
   Authorization: Bearer <jwt>
6. Backend validates JWT on every request
```

### JWT Payload (Example)

```json
{
  "sub": "user-550e8400-e29b-41d4-a716-446655440000",
  "jti": "token-7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "exp": 1729512000,
  "iat": 1729511100,
  "aud": "agent-ready-k8s",
  "iss": "https://platform.example.com"
}
```

**Minimal Claims:**
- `sub` (subject) - User ID (UUID)
- `jti` (JWT ID) - Token ID (UUID, for revocation)
- `exp` (expiration) - 15 minutes
- `iat` (issued at)

**No PII:**
- ❌ No email
- ❌ No name
- ❌ No IP address

---

## Security Hardening

### 1. Short TTL (15 Minutes)

JWT expires after 15 minutes. User must refresh token via silent refresh.

```python
# JWT expiration
exp = datetime.utcnow() + timedelta(minutes=15)
```

### 2. JTI Denylist (Logout = Revoke)

When user logs out, add JWT ID (`jti`) to Redis denylist:

```python
# Logout: Revoke token
await redis.setex(
    f"denylist:{jti}",
    ttl=900,  # 15 minutes (TTL of JWT)
    value="revoked"
)
```

**Validation:**
```python
# Check if token revoked
if await redis.exists(f"denylist:{jti}"):
    raise HTTPException(401, "Token revoked")
```

### 3. Silent Refresh (Refresh Token)

Frontend auto-refreshes JWT before expiration:

```javascript
// Silent refresh every 10 minutes (before 15-min expiration)
setInterval(async () => {
  const newJwt = await fetch("/api/auth/refresh", {
    method: "POST",
    headers: { Authorization: `Bearer ${currentJwt}` }
  }).then(r => r.json());
  
  currentJwt = newJwt.access_token;
}, 10 * 60 * 1000);  // 10 minutes
```

### 4. HMAC-SHA256 Signing

JWT signed with HMAC-SHA256 (HS256):

```python
import jwt

secret_key = os.environ["JWT_SECRET"]  # From K8s Secret

token = jwt.encode(
    payload={"sub": user_id, "jti": jti, "exp": exp, "iat": iat},
    key=secret_key,
    algorithm="HS256"
)
```

**Secret Rotation:**
- Store `JWT_SECRET` in K8s Secret (backed by KMS)
- Rotate every 90 days (runbook: `secrets-rotation.md`)

### 5. Rate Limiting

Prevent brute-force token generation:

```yaml
# Nginx Ingress rate limit
nginx.ingress.kubernetes.io/limit-rps: "10"  # Max 10 sign-ins/sec per IP
```

---

## User Experience

### Sign-In Flow (3 Seconds)

```
User lands on homepage
→ Clicks "Sign In as Guest"
→ Backend generates JWT
→ User redirected to dashboard
```

### Logout Flow

```
User clicks "Logout"
→ Frontend calls /api/auth/logout
→ Backend adds jti to Redis denylist
→ Frontend deletes JWT from memory/localStorage
→ User redirected to homepage
```

### Multi-Device Flow

**Option 1: Separate Sessions (Default)**
- User signs in on Desktop → JWT-1 (device A)
- User signs in on Mobile → JWT-2 (device B)
- Each device has independent JWT

**Option 2: Shared Session (Advanced)**
- User can export JWT from Desktop (QR code)
- User scans QR code on Mobile
- Both devices share same JWT

---

## Database Schema

### Option 1: No User Table (Stateless)

JWT is self-contained. No user table needed.

**Pros:**
- ✅ Zero DB queries for auth
- ✅ Stateless (scales horizontally)

**Cons:**
- ⚠️ No user metadata (last login, IP)

### Option 2: Minimal User Table (Optional)

```sql
CREATE TABLE users (
    user_id         UUID PRIMARY KEY,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_login_at   TIMESTAMPTZ,
    session_count   INT DEFAULT 0
);
```

**When to use:**
- Analytics (user count, retention)
- Rate limiting per user (not per IP)

---

## Monitoring

### Metrics

```yaml
# Auth metrics
auth_signins_total{method="guest"}  # Counter
auth_logout_total  # Counter
auth_token_expired_total  # Counter
auth_token_invalid_total  # Counter (validation failed)
```

### Alerts

```yaml
alert: HighInvalidTokenRate
expr: rate(auth_token_invalid_total[5m]) > 10
for: 5m
severity: warning
```

---

## Alternatives Rejected

### Option 1: Email + Password Registration

**Rejected because:**
- PII collection (GDPR, breach liability)
- Slow onboarding (3-5 min: form, email verification)
- Password reset complexity
- Email delivery issues (spam folders)

**When to use:**
- B2B SaaS (enterprise customers want SSO, audit logs)
- Compliance requires identity verification

### Option 2: OIDC (OAuth2 with Google/GitHub)

**Rejected because:**
- PII exposure (email required)
- External dependency (Google outage = login broken)
- Complex setup (redirect URI, client secret)

**When to use:**
- B2B SaaS (enterprises use Google Workspace)
- Identity continuity required across devices

### Option 3: Magic Link (Email-Based Login)

**Rejected because:**
- Requires email (PII)
- Slow (user checks email, clicks link)
- Email delivery issues

**When to use:**
- Passwordless but identity continuity needed

---

## Future Enhancements

### Phase 2: Optional Email (Opt-In)

Users can **optionally** provide email for:
- Account recovery
- Multi-device sync

**Privacy:**
- Email is hashed (SHA-256 + salt)
- User can delete email anytime
- No marketing emails (ever)

### Phase 3: OIDC Integration (Optional)

For enterprise customers, allow OIDC sign-in **alongside** guest sign-in:

```
Sign In Options:
1. Continue as Guest (no PII)
2. Sign In with Google (optional)
```

---

## Compliance

### GDPR (EU)

✅ **No PII = No GDPR obligations**
- No data subject requests (no data to delete)
- No breach notification (no personal data)
- No consent banners (no tracking)

### CCPA (California)

✅ **No PII = No CCPA obligations**
- No "Do Not Sell My Data" (no data collected)

### SOC 2 (Security)

✅ **JWT + JTI Denylist = Compliant**
- Access control (JWT validation)
- Encryption (TLS + JWT signing)
- Audit trail (optional user table with last_login_at)

---

## References

- [JWT Best Practices](https://datatracker.ietf.org/doc/html/rfc8725)
- [OWASP JWT Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html)
- [GDPR Compliance](https://gdpr.eu/)
- [goals-and-scope.md](../architecture/goals-and-scope.md) - MVP Scope
