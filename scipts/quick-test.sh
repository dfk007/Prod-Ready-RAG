#!/bin/bash
# Quick diagnostic - test all endpoints and show status in one line each
# Usage: ./scipts/quick-test.sh [host|docker]
#   host: test from host machine (default)
#   docker: test from inside streamlit container

MODE=${1:-host}

if [[ "$MODE" == "docker" ]]; then
    INNGEST_URL="http://inngest:8288"
    echo "Testing from inside Docker container..."
    docker compose exec streamlit bash -c "
        for ep in '/api/events' '/api/v1/events' '/v1/events'; do
            echo -n \"\${ep}: \"
            curl -s -o /dev/null -w \"%{http_code} (%{content_type})\" \\
                -X POST \"http://inngest:8288\${ep}\" \\
                -H \"Content-Type: application/json\" \\
                -H \"Authorization: Bearer test\" \\
                -d '[{\"name\": \"test\", \"data\": {}}]' 2>&1
            echo
        done
    "
else
    INNGEST_URL="http://localhost:8288"
    echo "Testing from host machine..."
    echo ""
    echo "Endpoint                    | Status | Content-Type"
    echo "----------------------------|--------|-------------------"
    
    for endpoint in "/api/events" "/api/v1/events" "/v1/events" "/api/inngest/events"; do
        result=$(curl -s -o /dev/null -w "%{http_code}|%{content_type}" \
            -X POST "${INNGEST_URL}${endpoint}" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer test" \
            -d '[{"name": "test", "data": {}}]' 2>&1)
        
        http_code=$(echo "$result" | cut -d'|' -f1)
        content_type=$(echo "$result" | cut -d'|' -f2)
        
        # Format output
        printf "%-27s | %-6s | %s\n" "$endpoint" "$http_code" "$content_type"
    done
    
    echo ""
    echo "Legend:"
    echo "  200 + application/json = ✓ Working"
    echo "  200 + text/html        = ✗ Dashboard UI (not API)"
    echo "  405                    = ✗ Method not allowed"
    echo "  404                    = ✗ Not found"
fi

