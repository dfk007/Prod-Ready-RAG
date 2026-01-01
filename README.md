![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/dfk007/Prod-Ready-RAG?utm_source=oss&utm_medium=github&utm_campaign=dfk007%2FProd-Ready-RAG&labelColor=171717&color=FF570A&link=https%3A%2F%2Fcoderabbit.ai&label=CodeRabbit+Reviews)
# Production-Grade RAG Python Application

A Retrieval-Augmented Generation (RAG) application built with Python that enables document ingestion, vector search, and AI-powered question answering using PDF documents.

## Overview

This application provides a complete RAG pipeline that:
- **Ingests PDF documents** by chunking and embedding them
- **Stores embeddings** in a Qdrant vector database
- **Answers questions** using AI with context retrieved from ingested documents

The application uses **Inngest** for workflow orchestration, providing features like rate limiting, throttling, and step-based execution for reliable document processing.

## Architecture

### Components

- **`main.py`**: FastAPI application with Inngest functions for PDF ingestion and querying
- **`streamlit_app.py`**: Streamlit web UI for uploading PDFs and asking questions
- **`data_loader.py`**: Handles PDF loading, text chunking, and embedding generation
- **`vector_db.py`**: Qdrant vector database wrapper for storage and search operations
- **`custom_types.py`**: Pydantic models for type-safe data structures

### Technology Stack

- **FastAPI**: Backend API framework
- **Inngest**: Workflow orchestration with rate limiting and throttling
- **Streamlit**: Interactive web interface
- **Qdrant**: Vector database for storing and searching embeddings
- **Ollama**: 
  - `nomic-embed-text` for embeddings (768 dimensions)
  - `gemma3:1b` for question answering
- **LlamaIndex**: PDF reading and text splitting utilities

## Features

### PDF Ingestion
- Automatic PDF parsing and text extraction
- Intelligent text chunking (1000 characters with 200 character overlap)
- Vector embedding generation using Ollama
- Persistent storage in Qdrant with source tracking
- Rate limiting: 1 ingestion per 4 hours per source
- Throttling: Maximum 2 ingestions per minute

### Query & Answer
- Semantic search across all ingested documents
- Configurable top-k retrieval (default: 5 chunks)
- AI-powered answers using retrieved context
- Source attribution for transparency
- Context-aware responses limited to provided information

## Prerequisites

- Python 3.13+
- Qdrant server running locally (default: `http://localhost:6333`)
- Ollama installed and running locally (default: `http://localhost:11434`)
- Ollama models: `nomic-embed-text` and `gemma3:1b` (will be pulled automatically on first use)
- Inngest dev server (for local development)

## Installation

1. **Clone the repository** (if applicable) or navigate to the project directory

2. **Install dependencies** using `uv`:
```bash
uv sync
```

3. **Install and start Ollama**:
```bash
# Install Ollama (if not already installed)
# Visit https://ollama.ai for installation instructions

# Pull required models (will be done automatically on first use, or manually):
ollama pull nomic-embed-text
ollama pull gemma3:1b
```

4. **Set up environment variables** (optional):
Create a `.env` file in the project root:
```env
OLLAMA_BASE_URL=http://localhost:11434  # Optional, defaults to local Ollama
INNGEST_API_BASE=http://127.0.0.1:8288/v1  # Optional, defaults to local dev server
```

5. **Start Qdrant server**:
```bash
# Using Docker
docker run -p 6333:6333 qdrant/qdrant

# Or install and run Qdrant locally
```

6. **Start the FastAPI server**:
```bash
uvicorn main:app --reload
```

7. **Start the Streamlit app** (in a separate terminal):
```bash
streamlit run streamlit_app.py
```

## Usage

### Via Streamlit UI

1. Open the Streamlit app (typically at `http://localhost:8501`)
2. **Upload a PDF**: Use the file uploader to select a PDF document
3. **Wait for ingestion**: The app will trigger the ingestion workflow
4. **Ask questions**: Enter your question in the query form and specify how many chunks to retrieve
5. **View results**: See the AI-generated answer along with source documents

### Via API (Inngest Events)

#### Ingest a PDF
```python
import inngest

client = inngest.Inngest(app_id="rag_app", is_production=False)

await client.send(
    inngest.Event(
        name="rag/ingest_pdf",
        data={
            "pdf_path": "/path/to/document.pdf",
            "source_id": "document_name"  # Optional, defaults to pdf_path
        }
    )
)
```

#### Query Documents
```python
await client.send(
    inngest.Event(
        name="rag/query_pdf_ai",
        data={
            "question": "What is the main topic of the document?",
            "top_k": 5  # Number of chunks to retrieve
        }
    )
)
```

## Configuration

### Embedding Model
- Model: `nomic-embed-text`
- Dimensions: 768
- Configured in `data_loader.py`
- Note: Ollama will automatically pull this model on first use

### Chunking Parameters
- Chunk size: 1000 characters
- Overlap: 200 characters
- Configured in `data_loader.py`

### LLM Model
- Model: `gemma3:1b`
- Temperature: 0.2
- Max tokens: 1024
- Configured in `main.py`
- Note: Ollama will automatically pull this model on first use

### Vector Database
- Default collection: `docs`
- Distance metric: Cosine similarity
- Vector dimensions: 768 (matching nomic-embed-text)
- Configured in `vector_db.py`

### Rate Limits
- **Ingestion**: 1 per 4 hours per source
- **Throttling**: 2 per minute globally
- Configured in `main.py`

## Project Structure

```
.
├── main.py                 # FastAPI app with Inngest functions
├── streamlit_app.py        # Streamlit web interface
├── data_loader.py          # PDF loading and embedding utilities
├── vector_db.py            # Qdrant storage wrapper
├── custom_types.py         # Pydantic models
├── pyproject.toml          # Project dependencies
├── qdrant_storage/         # Local Qdrant data directory
└── uploads/                # Uploaded PDF files (created at runtime)
```

## Development

### Running in Development Mode

1. Start Qdrant: `docker run -p 6333:6333 qdrant/qdrant`
2. Start FastAPI: `uvicorn main:app --reload`
3. Start Streamlit: `streamlit run streamlit_app.py`
4. Start Inngest Dev Server: `npx inngest-cli@latest dev`

### Dependencies

All dependencies are managed via `pyproject.toml` and can be installed with `uv sync`.

Key dependencies:
- `fastapi>=0.116.1`
- `inngest>=0.5.6`
- `llama-index-core>=0.14.0`
- `llama-index-readers-file>=0.5.4`
- `ollama>=0.3.0`
- `qdrant-client>=1.15.1`
- `streamlit>=1.49.1`

## Workflow Details

### Ingestion Workflow (`rag/ingest_pdf`)
1. **Load and Chunk**: Extracts text from PDF and splits into chunks
2. **Embed and Upsert**: Generates embeddings and stores in Qdrant
3. Returns count of ingested chunks

### Query Workflow (`rag/query_pdf_ai`)
1. **Embed and Search**: Embeds the question using Ollama and searches for relevant chunks
2. **LLM Answer**: Uses gemma3:1b to generate an answer from retrieved context
3. Returns answer, sources, and number of contexts used

## Notes

- The application uses UUID v5 for generating deterministic document chunk IDs
- Uploaded PDFs are stored in the `uploads/` directory
- Qdrant data is persisted in the `qdrant_storage/` directory
- The application is configured for local development (`is_production=False`)
- **Ollama models**: The required models (`nomic-embed-text` and `gemma3:1b`) will be automatically downloaded by Ollama on first use. Ensure Ollama is running before using the application.
- **Embedding dimensions**: Changed from 3072 (OpenAI) to 768 (Ollama). If you have existing Qdrant collections, you may need to recreate them or migrate the data.

## License

[Add your license information here]

