# ADR-0005: Canned Chat Actions (No Free Text)

> **Status:** Accepted
> **Date:** 20 October 2025
> **Deciders:** Platform Team, Product Team, Backend Team
> **Related:** [goals-and-scope.md](../architecture/goals-and-scope.md)

## Context

Chat is a core feature for project collaboration. Most SaaS platforms implement free-text chat (Slack, Teams, Discord) with:
- Message persistence (chat_messages table)
- Full-text search
- File attachments
- Rich formatting (Markdown, emoji)
- Threading
- AI moderation (toxicity detection)

This creates:
- **Storage Cost** - Messages stored forever
- **Moderation Cost** - Toxic content, spam
- **Complexity** - Search indexing, threading, notifications

### Requirements (MVP)

1. **Simple Status Updates** - "Ready", "Blocked", "Deployed"
2. **No Toxic Content** - Predefined actions only
3. **Ephemeral** - No long-term storage
4. **Low Cost** - No AI moderation, no search indexing

---

## Decision

**We will use "Canned Chat Actions" (predefined buttons) instead of free-text chat.**

Users click predefined actions:
- 👍 / 👎
- "Ready" / "Blocked" / "In Review"
- "Deployed" / "Tests Green"

No free-text input allowed in MVP.

---

## Rationale

### Why Canned Actions?

✅ **Zero Toxic Content** - No free text = no abuse
✅ **Zero Moderation Cost** - No AI needed
✅ **Simple** - No search, no threading
✅ **Ephemeral** - No storage (WebSocket fan-out only)
✅ **Fast** - One click, instant delivery

### Why NOT Free-Text Chat?

❌ **Toxic Content** - Spam, harassment, hate speech
❌ **Moderation Cost** - AI moderation ($0.002/message) or human review
❌ **Storage Cost** - Messages stored forever (10GB/month for 1000 users)
❌ **Search Complexity** - Full-text indexing (Elasticsearch/Meilisearch)
❌ **Legal Liability** - GDPR (right to delete messages), content moderation laws

---

## Consequences

### Positive

- ✅ **Zero Moderation** - No toxic content possible
- ✅ **Zero Storage Cost** - No message persistence
- ✅ **Simple** - No search, threading, formatting
- ✅ **Fast Development** - 1 week vs. 4 weeks (free-text chat)

### Negative

- ⚠️ **Limited Expression** - Users can't write custom messages
- ⚠️ **No Context** - Actions lack detailed explanation

### Trade-Offs

- **Pro:** MVP ships in 1 week (vs. 4 weeks for full chat)
- **Con:** Power users may request free-text (Phase 2)

---

## Implementation

### Allowed Actions (Predefined)

```typescript
enum ChatAction {
  // Reactions
  THUMBS_UP = "👍",
  THUMBS_DOWN = "👎",
  
  // Status Updates
  READY = "Ready",
  BLOCKED = "Blocked",
  IN_REVIEW = "In Review",
  
  // Deployment Events
  DEPLOYED = "Deployed",
  TESTS_GREEN = "Tests Green",
  ROLLBACK = "Rollback"
}
```

### Frontend UI (Buttons)

```tsx
// Chat.tsx
<div className="chat-actions">
  <button onClick={() => sendAction("👍")}>👍</button>
  <button onClick={() => sendAction("👎")}>👎</button>
  <button onClick={() => sendAction("Ready")}>Ready</button>
  <button onClick={() => sendAction("Blocked")}>Blocked</button>
  <button onClick={() => sendAction("Deployed")}>Deployed</button>
</div>
```

### Backend WebSocket (Ephemeral Fan-Out)

```python
# WebSocket endpoint
@router.websocket("/ws/projects/{project_id}/chat")
async def chat_websocket(websocket: WebSocket, project_id: str):
    await websocket.accept()
    
    # Subscribe to Redis Pub/Sub channel
    pubsub = redis.pubsub()
    await pubsub.subscribe(f"chat:{project_id}")
    
    async for message in pubsub.listen():
        if message["type"] == "message":
            # Fan-out to WebSocket client
            await websocket.send_json({
                "user_id": message["user_id"],
                "action": message["action"],  # "👍", "Ready", etc.
                "timestamp": message["timestamp"]
            })

# Send action
@router.post("/api/projects/{project_id}/chat/actions")
async def send_chat_action(project_id: str, action: ChatAction, user_id: str):
    # Validate action (must be in enum)
    if action not in ChatAction.__members__.values():
        raise HTTPException(400, "Invalid action")
    
    # Publish to Redis (ephemeral)
    await redis.publish(f"chat:{project_id}", json.dumps({
        "user_id": user_id,
        "action": action.value,
        "timestamp": datetime.utcnow().isoformat()
    }))
    
    return {"status": "sent"}
```

---

## No Message Persistence (Ephemeral)

**Rule:** Chat actions are **NOT stored** in database.

### Why Ephemeral?

1. **No Storage Cost** - Zero DB writes
2. **No GDPR Burden** - No messages = no "right to delete" requests
3. **Stateless** - No search, no history, no threading
4. **Simple** - Redis Pub/Sub only

### Trade-Offs

- **Pro:** Zero storage cost, zero GDPR complexity
- **Con:** No chat history (if user reloads page, history is gone)

### Future Enhancement (Optional)

If users demand history:
- Store **last 10 actions** in Redis (TTL = 1 hour)
- On WebSocket connect, replay last 10 actions

```python
# Store last 10 actions in Redis List
await redis.lpush(f"chat:{project_id}:recent", json.dumps(action))
await redis.ltrim(f"chat:{project_id}:recent", 0, 9)  # Keep last 10
await redis.expire(f"chat:{project_id}:recent", 3600)  # 1 hour TTL
```

---

## User Limits (Prevent Spam)

### Max 3 Active Chats Per User Per Project

**Rule:** User can have max 3 **active** chat WebSocket connections per project.

**Why?**
- Prevent abuse (user opening 1000 tabs)
- Limit Redis Pub/Sub fan-out load

**Enforcement:**
```python
# Track active connections in Redis
connection_count = await redis.scard(f"chat:{project_id}:user:{user_id}:connections")
if connection_count >= 3:
    raise HTTPException(429, "Max 3 active chats per project")

# Add connection
await redis.sadd(f"chat:{project_id}:user:{user_id}:connections", websocket_id)

# Remove on disconnect
await redis.srem(f"chat:{project_id}:user:{user_id}:connections", websocket_id)
```

---

## Security

### 1. Action Validation (Server-Side)

**Rule:** Backend MUST validate action is in allowed enum.

```python
# ❌ BAD: Accept any string
@router.post("/api/chat/actions")
async def send_action(action: str):  # Dangerous!
    await redis.publish("chat", action)  # User could inject <script>

# ✅ GOOD: Validate against enum
@router.post("/api/chat/actions")
async def send_action(action: ChatAction):  # Type-safe
    if action not in ChatAction.__members__.values():
        raise HTTPException(400, "Invalid action")
    await redis.publish("chat", action.value)
```

### 2. Rate Limiting

Prevent spam (user clicking 👍 1000 times):

```yaml
# Nginx Ingress rate limit
nginx.ingress.kubernetes.io/limit-rps: "5"  # Max 5 actions/sec per user
```

### 3. JWT Auth (WebSocket)

WebSocket must validate JWT:

```python
@router.websocket("/ws/projects/{project_id}/chat")
async def chat_websocket(websocket: WebSocket, token: str):
    # Validate JWT
    try:
        payload = jwt.decode(token, secret_key, algorithms=["HS256"])
        user_id = payload["sub"]
    except jwt.ExpiredSignatureError:
        await websocket.close(code=1008, reason="Token expired")
        return
    
    # Check if token revoked
    jti = payload["jti"]
    if await redis.exists(f"denylist:{jti}"):
        await websocket.close(code=1008, reason="Token revoked")
        return
    
    # Accept connection
    await websocket.accept()
```

---

## Monitoring

### Metrics

```yaml
# Chat metrics
chat_actions_total{action, project_id}  # Counter per action type
chat_connections_active{project_id}  # Gauge
chat_latency_seconds  # Histogram (send to receive)
chat_rate_limit_exceeded_total  # Counter
```

### Alerts

```yaml
alert: HighChatLatency
expr: histogram_quantile(0.95, chat_latency_seconds) > 1.0
for: 5m
severity: warning

alert: TooManyActiveConnections
expr: chat_connections_active > 1000
for: 5m
severity: warning
```

---

## User Experience

### Chat Flow (User Perspective)

```
1. User opens Project page
2. Chat panel shows online users
3. User clicks "👍" button
4. Action appears instantly in chat for all online users
5. User closes tab → connection closed, action history gone
```

### Example Chat UI

```
Project: "Backend Refactor"

Online Users (3):
- Alice
- Bob
- Charlie

Recent Actions (last 5):
12:34 - Alice: 👍
12:33 - Bob: "Ready"
12:32 - Charlie: "Deployed"
12:30 - Alice: "Tests Green"
12:28 - Bob: 👎

[👍] [👎] [Ready] [Blocked] [Deployed]
```

---

## Alternatives Rejected

### Option 1: Free-Text Chat (Slack-like)

**Rejected because:**
- Moderation cost ($0.002/message AI or human review)
- Storage cost (10GB/month for 1000 users)
- Toxic content risk (spam, harassment)
- Search complexity (Elasticsearch/Meilisearch)
- MVP delay (4 weeks vs. 1 week)

**When to use:**
- Phase 2 (if users demand it)
- Add free-text as **opt-in** (default = canned actions)
- Require AI moderation (Perspective API, OpenAI Moderation)

### Option 2: Threaded Chat (Discord-like)

**Rejected because:**
- Complexity (threads, replies, notifications)
- Storage cost (persist all threads)
- MVP delay (6 weeks vs. 1 week)

**When to use:**
- Phase 3 (after free-text chat is stable)

### Option 3: Chat with File Attachments

**Rejected because:**
- Storage cost (MinIO/S3)
- Security risk (malware, XSS via SVG)
- Complexity (virus scanning, thumbnail generation)

**When to use:**
- Phase 2 (after MinIO is enabled)
- Limit to images only (PNG, JPG)
- Max 5MB per file

---

## Future Enhancements

### Phase 2: Optional Free-Text (Opt-In)

Projects can **enable** free-text chat:

```yaml
project:
  chat_mode: "canned"  # Default
  # OR
  chat_mode: "free_text"  # Opt-in (requires AI moderation)
```

**Requirements for Free-Text:**
- AI moderation (OpenAI Moderation API)
- Rate limit: 10 messages/min per user
- Max message length: 500 chars
- Storage: Keep last 100 messages (7 days TTL)

### Phase 3: Chat History (Last 100 Messages)

Store last 100 actions in PostgreSQL (not Redis):

```sql
CREATE TABLE chat_messages (
    message_id UUID PRIMARY KEY,
    project_id UUID NOT NULL REFERENCES projects(project_id),
    user_id UUID NOT NULL,
    action VARCHAR(50) NOT NULL,  -- "👍", "Ready", etc.
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Retention policy: Delete messages older than 7 days
CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at);
```

**Trade-Offs:**
- **Pro:** Users can see history after reload
- **Con:** Storage cost, GDPR "right to delete"

---

## Decision Tree

```
Need real-time updates?
├─ Status updates only? → Canned actions (ADR-0005) ✅
├─ Detailed discussions? → Free-text chat (Phase 2) ⏳
└─ File sharing? → Attachments (Phase 2) ⏳

Need message history?
├─ No history (ephemeral)? → Redis Pub/Sub only ✅
├─ Last 10 messages? → Redis List (TTL = 1 hour) ⏳
└─ Last 100 messages? → PostgreSQL (TTL = 7 days) ⏳

Need moderation?
├─ Canned actions? → No moderation needed ✅
└─ Free text? → AI moderation required (Phase 2) ⏳
```

---

## References

- [WebSocket Best Practices](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)
- [Redis Pub/Sub](https://redis.io/docs/manual/pubsub/)
- [OpenAI Moderation API](https://platform.openai.com/docs/guides/moderation) (for Phase 2)
- [goals-and-scope.md](../architecture/goals-and-scope.md) - MVP Scope
