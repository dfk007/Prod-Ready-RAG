# Docker Setup Guide for RAG Application

This guide explains how to run the entire RAG application using Docker Compose, making it completely self-contained without requiring any installations on your host machine.

## Prerequisites

- **Docker** (version 20.10 or later)
- **Docker Compose** (version 2.0 or later)

No other software needs to be installed on your host machine!

## Quick Start

1. **Start all services:**
```bash
docker compose up -d
```

**What this does:**
- Starts all services in detached mode (`-d` flag)
- Builds Docker images if needed
- Creates Docker networks and volumes
- Automatically pulls Ollama models (`nomic-embed-text` and `gemma3:1b`)

2. **Check service status:**
```bash
docker compose ps
```

3. **View logs:**
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f ollama
docker compose logs -f fastapi
docker compose logs -f streamlit
```

4. **Stop all services:**
```bash
docker compose down
```

5. **Stop and remove volumes (clean slate):**
```bash
docker compose down -v
```

## Service URLs

Once all services are running, access them at:

| Service | URL | Description |
|---------|-----|-------------|
| **Streamlit UI** | http://localhost:8501 | Web interface for uploading PDFs and asking questions |
| **FastAPI Docs** | http://localhost:8000/docs | API documentation (Swagger UI) |
| **FastAPI ReDoc** | http://localhost:8000/redoc | Alternative API documentation |
| **Qdrant Dashboard** | http://localhost:6333/dashboard | Vector database dashboard |
| **Qdrant API** | http://localhost:6333 | Qdrant REST API |
| **Ollama API** | http://localhost:11435 | Ollama API (custom port) |
| **Inngest Dev Server** | http://localhost:8288 | Inngest workflow orchestration |

## Architecture Components

The Docker Compose setup includes the following services:

### 1. **Qdrant** (Vector Database)
- **Image:** `qdrant/qdrant:latest`
- **Ports:** 6333 (HTTP), 6334 (gRPC)
- **Purpose:** Stores vector embeddings for semantic search
- **Volume:** `qdrant_storage` (persists data)

### 2. **Ollama** (AI Service)
- **Custom Image:** Built from `Dockerfile.ollama`
- **Port:** 11435 (custom port)
- **Models:** Automatically pulls `nomic-embed-text` and `gemma3:1b` on startup
- **Purpose:** 
  - `nomic-embed-text`: Generates embeddings (768 dimensions)
  - `gemma3:1b`: Generates answers to questions
- **Volume:** `ollama_data` (persists models)

### 3. **FastAPI** (Backend API)
- **Custom Image:** Built from `Dockerfile`
- **Port:** 8000
- **Purpose:** Handles PDF ingestion and query workflows via Inngest
- **Dependencies:** Qdrant, Ollama, Inngest

### 4. **Streamlit** (Web UI)
- **Custom Image:** Built from `Dockerfile`
- **Port:** 8501
- **Purpose:** User interface for uploading PDFs and asking questions
- **Dependencies:** FastAPI, Qdrant, Ollama, Inngest

### 5. **Inngest** (Workflow Orchestration)
- **Image:** `inngest/inngest:latest`
- **Port:** 8288
- **Purpose:** Manages workflow execution, rate limiting, and step tracking
- **Dependencies:** FastAPI

## Verifying Each Component

### 1. Verify Qdrant (Vector Database)

**Check health:**
```bash
curl http://localhost:6333/health
```

**Expected response:**
```json
{"status":"ok"}
```

**List collections:**
```bash
curl http://localhost:6333/collections
```

**Access dashboard:**
Open http://localhost:6333/dashboard in your browser

---

### 2. Verify Ollama (AI Service)

**Check if Ollama is running:**
```bash
curl http://localhost:11435/api/tags
```

**Expected response:** List of available models including `nomic-embed-text` and `gemma3:1b`

**Test embedding generation:**
```bash
curl http://localhost:11435/api/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "prompt": "Hello world"
  }'
```

**Expected response:** JSON with embedding vector (768 dimensions)

**Test text generation:**
```bash
curl http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma3:1b",
    "prompt": "What is artificial intelligence?",
    "stream": false
  }'
```

**Expected response:** JSON with generated text

---

### 3. Verify FastAPI (Backend API)

**Check API health:**
```bash
curl http://localhost:8000/docs
```

**Expected:** HTML page loads (Swagger UI)

**Check Inngest endpoint:**
```bash
curl http://localhost:8000/api/inngest
```

**Expected:** Inngest configuration response

**Access API documentation:**
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

---

### 4. Verify Streamlit (Web UI)

**Check if Streamlit is running:**
```bash
curl http://localhost:8501/_stcore/health
```

**Expected response:**
```json
{"status":"ok"}
```

**Access web interface:**
Open http://localhost:8501 in your browser

You should see:
- PDF upload interface
- Question/answer interface

---

### 5. Verify Inngest (Workflow Orchestration)

**Check Inngest health:**
```bash
curl http://localhost:8288/api/health
```

**Expected response:** Health status

**List functions:**
```bash
curl http://localhost:8288/api/v1/functions
```

**Expected response:** List of registered Inngest functions (RAG: Ingest PDF, RAG: Query PDF)

---

## Testing the Complete RAG Pipeline

### Step 1: Upload a PDF (via Streamlit UI)

1. Open http://localhost:8501 in your browser
2. Click "Choose a PDF" and select a PDF file
3. Wait for the ingestion to complete (check logs: `docker compose logs -f fastapi`)

### Step 2: Query the Document (via Streamlit UI)

1. In the Streamlit interface, enter a question about your PDF
2. Set the number of chunks to retrieve (default: 5)
3. Click "Ask"
4. View the AI-generated answer with source attribution

### Step 3: Test via API (Alternative Method)

**Trigger PDF ingestion via Inngest event:**
```bash
# First, you need to upload a PDF to the container
# Then trigger ingestion:
curl -X POST http://localhost:8288/api/v1/events \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rag/ingest_pdf",
    "data": {
      "pdf_path": "/app/uploads/your-document.pdf",
      "source_id": "test-document"
    }
  }'
```

**Query documents:**
```bash
curl -X POST http://localhost:8288/api/v1/events \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rag/query_pdf_ai",
    "data": {
      "question": "What is the main topic?",
      "top_k": 5
    }
  }'
```

## Troubleshooting

### Services won't start

**Check logs:**
```bash
docker compose logs
```

**Common issues:**
- Port conflicts: Ensure ports 6333, 6334, 8000, 8501, 8288, 11435 are not in use
- Insufficient memory: Ollama models require significant RAM
- Network issues: Check Docker network connectivity

### Ollama models not pulling

**Check Ollama logs:**
```bash
docker compose logs ollama
```

**Manually pull models:**
```bash
docker compose exec ollama ollama pull nomic-embed-text
docker compose exec ollama ollama pull gemma3:1b
```

### Qdrant collection issues

**If you need to recreate the collection:**
```bash
# Delete the collection
curl -X DELETE http://localhost:6333/collections/docs

# It will be automatically recreated on next use
```

### FastAPI/Streamlit can't connect to services

**Check environment variables:**
```bash
docker compose exec fastapi env | grep -E "OLLAMA|QDRANT|INNGEST"
```

**Verify service names:** Services should use Docker Compose service names:
- `http://ollama:11435` (not localhost)
- `http://qdrant:6333` (not localhost)
- `http://inngest:8288` (not localhost)

## Data Persistence

Data is persisted in Docker volumes:

- **Qdrant data:** `qdrant_storage` volume**
- **Ollama models:** `ollama_data` volume
- **Uploaded PDFs:** `./uploads` directory (mounted from host)

To remove all data:
```bash
docker compose down -v
```

## Resource Requirements

**Minimum recommended:**
- CPU: 2 cores
- RAM: 4 GB (8 GB recommended for Ollama models)
- Disk: 10 GB free space (for models and data)

**Ollama model sizes:**
- `nomic-embed-text`: ~274 MB
- `gemma3:1b`: ~1.3 GB

## Environment Variables

You can customize the setup by creating a `.env` file:

```env
# Ollama configuration
OLLAMA_BASE_URL=http://ollama:11435

# Qdrant configuration
QDRANT_URL=http://qdrant:6333

# Inngest configuration
INNGEST_API_BASE=http://inngest:8288/v1
```

These are automatically used by the Docker Compose services.

## Stopping and Cleaning Up

**Stop services (keep data):**
```bash
docker compose stop
```

**Stop and remove containers (keep volumes):**
```bash
docker compose down
```

**Stop and remove everything including volumes:**
```bash
docker compose down -v
```

**Remove images:**
```bash
docker compose down --rmi all
```

## Next Steps

1. **Upload a PDF** via the Streamlit interface
2. **Ask questions** about your documents
3. **Explore the API** via Swagger UI at http://localhost:8000/docs
4. **Monitor workflows** via Inngest dashboard
5. **Check vector data** via Qdrant dashboard at http://localhost:6333/dashboard

## Support

If you encounter issues:
1. Check service logs: `docker compose logs [service-name]`
2. Verify all services are healthy: `docker compose ps`
3. Check service connectivity: Use the curl commands above
4. Review the main README.md for additional information

