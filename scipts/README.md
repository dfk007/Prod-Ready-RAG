# Inngest Testing Scripts

Collection of scripts to test Inngest endpoints with clean, readable output.

## Scripts

### 1. `test-inngest-host.sh`
**Run from host machine** - Full endpoint testing with jq parsing

```bash
./scipts/test-inngest-host.sh
```

Features:
- Color-coded output (green=success, red=error, yellow=warning)
- JSON parsing with jq
- Detects HTML vs JSON responses
- Tests all common endpoints

### 2. `test-inngest-docker.sh`
**Run from inside Docker container** - Testing from container perspective

```bash
# Option 1: Copy script into container and run
docker compose exec streamlit bash
./scipts/test-inngest-docker.sh

# Option 2: Run directly
docker compose exec streamlit bash -c './scipts/test-inngest-docker.sh'
```

Features:
- Tests using internal Docker network (`inngest:8288`)
- Clean output without HTML noise
- Works without jq (falls back to text preview)

### 3. `quick-test.sh`
**Quick diagnostic** - One-line status for each endpoint

```bash
# From host
./scipts/quick-test.sh host

# From Docker
./scipts/quick-test.sh docker
```

Output format:
```
Endpoint                    | Status | Content-Type
----------------------------|--------|-------------------
/api/events                 | 200    | text/html; charset=utf-8
/api/v1/events              | 200    | text/html; charset=utf-8
/v1/events                  | 405    | 
```

### 4. `test-single-endpoint.sh`
**Test one endpoint** - Detailed output for specific endpoint

```bash
# Test from host
./scipts/test-single-endpoint.sh /api/events host

# Test from Docker
./scipts/test-single-endpoint.sh /api/events docker
```

## Quick Reference Commands

### Host Machine (with jq)

```bash
# Quick status check
curl -s -o /dev/null -w "%{http_code} (%{content_type})\n" \
  -X POST http://localhost:8288/api/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test" \
  -d '[{"name": "test", "data": {}}]'

# Full test with JSON parsing
curl -s -X POST http://localhost:8288/api/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test" \
  -d '[{"name": "rag/ingest_pdf", "data": {"pdf_path": "/app/uploads/test.pdf", "source_id": "test.pdf"}}]' \
  | jq '.' 2>/dev/null || echo "Not JSON - likely HTML dashboard"
```

### Inside Docker Container

```bash
# Enter container
docker compose exec streamlit bash

# Quick status
curl -s -o /dev/null -w "HTTP: %{http_code} | Type: %{content_type}\n" \
  -X POST http://inngest:8288/api/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test" \
  -d '[{"name": "test", "data": {}}]'

# Check if JSON or HTML
curl -s -X POST http://inngest:8288/api/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test" \
  -d '[{"name": "test", "data": {}}]' \
  | head -c 100
```

## Understanding Output

- **✓ SUCCESS (200 + application/json)**: Endpoint is working correctly
- **✗ HTML Response (200 + text/html)**: Endpoint serves dashboard UI, not processing events
- **✗ 405 Method Not Allowed**: Endpoint exists but doesn't accept POST
- **✗ 404 Not Found**: Endpoint doesn't exist
- **✗ Other HTTP codes**: Various errors (check response body)

## Making Scripts Executable

```bash
chmod +x scipts/*.sh
```

