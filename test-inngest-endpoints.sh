#!/bin/bash
# Curl commands to test Inngest endpoints
# Run from your host machine

INNGEST_URL="http://localhost:8288"
EVENT_KEY="test"

echo "=== Testing Inngest Health Endpoint ==="
curl -v "${INNGEST_URL}/api/health"
echo -e "\n\n"

echo "=== Testing /api/events endpoint (current code uses this) ==="
curl -v -X POST "${INNGEST_URL}/api/events" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${EVENT_KEY}" \
  -d '[
    {
      "name": "rag/ingest_pdf",
      "data": {
        "pdf_path": "/app/uploads/test.pdf",
        "source_id": "test.pdf"
      }
    }
  ]'
echo -e "\n\n"

echo "=== Testing /api/v1/events endpoint ==="
curl -v -X POST "${INNGEST_URL}/api/v1/events" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${EVENT_KEY}" \
  -d '[
    {
      "name": "rag/ingest_pdf",
      "data": {
        "pdf_path": "/app/uploads/test.pdf",
        "source_id": "test.pdf"
      }
    }
  ]'
echo -e "\n\n"

echo "=== Testing /v1/events endpoint (old endpoint) ==="
curl -v -X POST "${INNGEST_URL}/v1/events" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${EVENT_KEY}" \
  -d '[
    {
      "name": "rag/ingest_pdf",
      "data": {
        "pdf_path": "/app/uploads/test.pdf",
        "source_id": "test.pdf"
      }
    }
  ]'
echo -e "\n\n"

echo "=== Testing /api/inngest/events endpoint ==="
curl -v -X POST "${INNGEST_URL}/api/inngest/events" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${EVENT_KEY}" \
  -d '[
    {
      "name": "rag/ingest_pdf",
      "data": {
        "pdf_path": "/app/uploads/test.pdf",
        "source_id": "test.pdf"
      }
    }
  ]'
echo -e "\n\n"

echo "=== Testing query event ==="
curl -v -X POST "${INNGEST_URL}/api/events" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${EVENT_KEY}" \
  -d '[
    {
      "name": "rag/query_pdf_ai",
      "data": {
        "question": "What is this document about?",
        "top_k": 5
      }
    }
  ]'
echo -e "\n\n"

