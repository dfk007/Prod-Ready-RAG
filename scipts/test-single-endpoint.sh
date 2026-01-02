#!/bin/bash
# Test a single endpoint with detailed output
# Usage: ./scipts/test-single-endpoint.sh <endpoint> [host|docker]
# Example: ./scipts/test-single-endpoint.sh /api/events host

if [ -z "$1" ]; then
    echo "Usage: $0 <endpoint> [host|docker]"
    echo "Example: $0 /api/events host"
    exit 1
fi

ENDPOINT=$1
MODE=${2:-host}
EVENT_KEY="test"
EVENT_DATA='[{"name": "rag/ingest_pdf", "data": {"pdf_path": "/app/uploads/test.pdf", "source_id": "test.pdf"}}]'

if [[ "$MODE" == "docker" ]]; then
    INNGEST_URL="http://inngest:8288"
    echo "Testing from inside Docker: ${INNGEST_URL}${ENDPOINT}"
    docker compose exec streamlit bash -c "
        curl -s -X POST \"${INNGEST_URL}${ENDPOINT}\" \\
            -H \"Content-Type: application/json\" \\
            -H \"Authorization: Bearer ${EVENT_KEY}\" \\
            -d '${EVENT_DATA}' \\
            -w \"\n\nHTTP: %{http_code}\nContent-Type: %{content_type}\n\" \\
            | head -c 500
    "
else
    INNGEST_URL="http://localhost:8288"
    echo "Testing from host: ${INNGEST_URL}${ENDPOINT}"
    echo ""
    
    response=$(curl -s -w "\n%{http_code}\n%{content_type}" -X POST "${INNGEST_URL}${ENDPOINT}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${EVENT_KEY}" \
        -d "$EVENT_DATA" 2>&1)
    
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
    
    echo "HTTP Status: $http_code"
    echo "Content-Type: $content_type"
    echo ""
    echo "Response Body:"
    
    if [[ "$content_type" == *"json"* ]]; then
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    else
        echo "$body" | head -c 500
    fi
fi

