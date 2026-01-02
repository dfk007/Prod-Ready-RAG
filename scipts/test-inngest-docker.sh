#!/bin/bash
# Clean Inngest endpoint testing from inside Docker containers
# Run this from inside the streamlit container: docker compose exec streamlit bash -c './scipts/test-inngest-docker.sh'

INNGEST_URL="http://inngest:8288"
EVENT_KEY="test"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📡 $description${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Endpoint: ${method} ${endpoint}"
    
    # Get HTTP status, content type, and body in one call
    response=$(curl -s -w "\n%{http_code}\n%{content_type}" -X "$method" "$endpoint" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $EVENT_KEY" \
        -d "$data" 2>&1)
    
    # Extract HTTP code and content type (last 2 lines)
    # Handle cases where response might be empty or malformed
    total_lines=$(echo "$response" | wc -l | tr -d ' ')
    
    if [ "$total_lines" -ge 2 ]; then
        http_code=$(echo "$response" | tail -2 | head -1 | tr -d '[:space:]')
        content_type=$(echo "$response" | tail -1 | tr -d '[:space:]')
        # Extract body (all lines except last 2) - cross-platform method
        body_lines=$((total_lines - 2))
        if [ "$body_lines" -gt 0 ]; then
            body=$(echo "$response" | head -n "$body_lines")
        else
            body=""
        fi
    else
        # Malformed response - try to extract what we can
        http_code=$(echo "$response" | grep -oE '[0-9]{3}' | head -1 || echo "000")
        content_type="unknown"
        body="$response"
    fi
    
    echo -e "\n${BLUE}Response Details:${NC}"
    echo "  HTTP Status: ${http_code}"
    echo "  Content-Type: ${content_type}"
    
    if [[ "$http_code" == "200" ]]; then
        if [[ "$content_type" == *"application/json"* ]] || [[ "$content_type" == *"text/json"* ]]; then
            echo -e "\n${GREEN}✓ SUCCESS: JSON Response${NC}"
            # Try to parse as JSON if jq is available, otherwise show first 300 chars
            if command -v jq &> /dev/null; then
                echo "$body" | jq '.' 2>/dev/null || echo "$body" | head -c 300
            else
                echo "$body" | head -c 300
            fi
        elif [[ "$content_type" == *"text/html"* ]]; then
            echo -e "\n${RED}✗ ISSUE: HTML Response (Dashboard UI - not API endpoint)${NC}"
            echo -e "${YELLOW}This endpoint is serving the Inngest dashboard, not processing events.${NC}"
            echo -e "${YELLOW}Preview:${NC} $(echo "$body" | grep -o '<title>[^<]*</title>' | head -1 || echo "$body" | head -c 100)..."
        else
            echo -e "\n${YELLOW}? UNKNOWN: Content type: ${content_type}${NC}"
            echo "Preview: $(echo "$body" | head -c 200)..."
        fi
    elif [[ "$http_code" == "405" ]]; then
        echo -e "\n${RED}✗ METHOD NOT ALLOWED${NC}"
    elif [[ "$http_code" == "404" ]]; then
        echo -e "\n${RED}✗ NOT FOUND${NC}"
    else
        echo -e "\n${RED}✗ ERROR: HTTP ${http_code}${NC}"
        echo "Preview: $(echo "$body" | head -c 200)..."
    fi
}

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 Inngest Endpoint Testing (Inside Docker)                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

# Test health endpoint
test_endpoint "GET" "${INNGEST_URL}/api/health" "" "Health Check"

# Test event endpoints
EVENT_DATA='[{"name": "rag/ingest_pdf", "data": {"pdf_path": "/app/uploads/test.pdf", "source_id": "test.pdf"}}]'

test_endpoint "POST" "${INNGEST_URL}/api/events" "$EVENT_DATA" "POST /api/events (Current Code)"
test_endpoint "POST" "${INNGEST_URL}/api/v1/events" "$EVENT_DATA" "POST /api/v1/events"
test_endpoint "POST" "${INNGEST_URL}/v1/events" "$EVENT_DATA" "POST /v1/events (Old Endpoint)"

# Test query event
QUERY_DATA='[{"name": "rag/query_pdf_ai", "data": {"question": "What is this document about?", "top_k": 5}}]'
test_endpoint "POST" "${INNGEST_URL}/api/events" "$QUERY_DATA" "Query Event (rag/query_pdf_ai)"

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Testing Complete${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

