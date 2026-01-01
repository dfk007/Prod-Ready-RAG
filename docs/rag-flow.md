# RAG Pipeline Flow

## Core Components

**FastAPI** - Backend API that receives requests from Streamlit and triggers workflows.

**Inngest** - Manages workflow steps. Handles retries if tasks fail and limits how many tasks run at once.

**Qdrant** - Stores document embeddings (768 numbers per chunk) for fast search.

**Ollama** - Runs AI models locally:
- `nomic-embed-text`: Converts text into 768-number vectors
- `gemma3:1b`: Answers questions using retrieved document chunks

**LlamaIndex** - Reads PDFs and splits them into chunks (1000 characters each, 200 overlap).

**Streamlit** - Web interface for uploading PDFs and asking questions.

## Component Interactions

### Component Input/Output Diagram

```mermaid
graph TB
    subgraph "User Interface"
        ST[Streamlit UI]
    end
    
    subgraph "API Layer"
        API[FastAPI]
    end
    
    subgraph "Orchestration"
        ING[Inngest]
    end
    
    subgraph "Data Processing"
        LI[LlamaIndex]
    end
    
    subgraph "AI Models"
        OLL[Ollama]
        NOMIC[nomic-embed-text]
        GEMMA[gemma3:1b]
    end
    
    subgraph "Storage"
        QD[Qdrant Vector DB]
    end
    
    ST -->|"PDF upload / Question"| API
    API -->|"Event: rag/ingest_pdf"| ING
    API -->|"Event: rag/query_pdf_ai"| ING
    
    ING -->|"PDF file path"| LI
    LI -->|"Text chunks"| OLL
    OLL -->|"Text chunks"| NOMIC
    NOMIC -->|"768-dim vectors"| QD
    
    ING -->|"Question text"| OLL
    OLL -->|"Question text"| NOMIC
    NOMIC -->|"768-dim query vector"| QD
    QD -->|"Top-K similar chunks"| ING
    ING -->|"Chunks + Question"| OLL
    OLL -->|"Chunks + Question"| GEMMA
    GEMMA -->|"Answer text"| ING
    ING -->|"Answer + Sources"| API
    API -->|"Response"| ST
```

### Component Details

```mermaid
graph LR
    subgraph Streamlit["Streamlit UI"]
        ST_IN["Input: User actions<br/>(PDF upload, Questions)"]
        ST_OUT["Output: Display results<br/>(Status, Answers)"]
    end
    
    subgraph FastAPI["FastAPI"]
        API_IN["Input: HTTP requests<br/>(PDF path, Question)"]
        API_PROC["Process: Create Inngest events"]
        API_OUT["Output: Event IDs<br/>(rag/ingest_pdf, rag/query_pdf_ai)"]
    end
    
    subgraph Inngest["Inngest"]
        ING_IN["Input: Events from FastAPI"]
        ING_PROC["Process: Orchestrate steps<br/>(Retry on failure, Rate limit)"]
        ING_OUT["Output: Workflow results"]
    end
    
    subgraph LlamaIndex["LlamaIndex"]
        LI_IN["Input: PDF file path"]
        LI_PROC["Process: PDFReader → Split text<br/>(1000 chars, 200 overlap)"]
        LI_OUT["Output: Text chunks array"]
    end
    
    subgraph OllamaEmbed["Ollama: nomic-embed-text"]
        EMB_IN["Input: Text chunks or question"]
        EMB_PROC["Process: Generate embeddings"]
        EMB_OUT["Output: 768-dimension vectors<br/>(Array of 768 numbers)"]
    end
    
    subgraph Qdrant["Qdrant Vector Database"]
        QD_IN["Input: Vectors + IDs + Payloads"]
        QD_PROC["Process: Store & Index vectors<br/>(Cosine similarity search)"]
        QD_OUT["Output: Top-K similar chunks<br/>(Text + Source IDs)"]
    end
    
    subgraph OllamaLLM["Ollama: gemma3:1b"]
        LLM_IN["Input: Question + Context chunks"]
        LLM_PROC["Process: Generate answer<br/>(Temperature: 0.2, Max: 1024 tokens)"]
        LLM_OUT["Output: Answer text"]
    end
    
    ST_IN --> API_IN
    API_PROC --> API_OUT
    API_OUT --> ING_IN
    ING_PROC --> LI_IN
    LI_OUT --> EMB_IN
    EMB_OUT --> QD_IN
    QD_OUT --> LLM_IN
    LLM_OUT --> ING_OUT
    ING_OUT --> ST_OUT
```

## Workflow Diagrams

### PDF Upload & Ingestion Flow

```mermaid
sequenceDiagram
    participant User
    participant Streamlit
    participant FastAPI
    participant Inngest
    participant LlamaIndex
    participant Ollama
    participant Qdrant
    
    User->>Streamlit: Upload PDF file
    Streamlit->>FastAPI: POST /event (rag/ingest_pdf)
    Note over Streamlit,FastAPI: Event data: {pdf_path, source_id}
    
    FastAPI->>Inngest: Send event: rag/ingest_pdf
    Inngest->>Inngest: Step 1: Load & Chunk
    
    Inngest->>LlamaIndex: load_and_chunk_pdf(pdf_path)
    LlamaIndex->>LlamaIndex: Read PDF with PDFReader
    LlamaIndex->>LlamaIndex: Split text (1000 chars, 200 overlap)
    LlamaIndex-->>Inngest: Return: [chunk1, chunk2, ...]
    
    Inngest->>Inngest: Step 2: Embed & Upsert
    
    loop For each chunk
        Inngest->>Ollama: embed_texts([chunk])
        Note over Ollama: nomic-embed-text model
        Ollama->>Ollama: Generate 768-dim vector
        Ollama-->>Inngest: Return: [0.123, -0.456, ...]
    end
    
    Inngest->>Qdrant: upsert(ids, vectors, payloads)
    Note over Qdrant: Store vectors with:<br/>- ID (UUID v5)<br/>- Vector (768 numbers)<br/>- Payload (text + source)
    Qdrant-->>Inngest: Confirmation
    
    Inngest-->>FastAPI: Return: {ingested: N}
    FastAPI-->>Streamlit: Success message
    Streamlit-->>User: "Ingestion complete"
```

### Question Answering Flow

```mermaid
sequenceDiagram
    participant User
    participant Streamlit
    participant FastAPI
    participant Inngest
    participant Ollama
    participant Qdrant
    participant Gemma
    
    User->>Streamlit: Ask question
    Streamlit->>FastAPI: POST /event (rag/query_pdf_ai)
    Note over Streamlit,FastAPI: Event data: {question, top_k}
    
    FastAPI->>Inngest: Send event: rag/query_pdf_ai
    Inngest->>Inngest: Step 1: Embed & Search
    
    Inngest->>Ollama: embed_texts([question])
    Note over Ollama: nomic-embed-text model
    Ollama->>Ollama: Generate 768-dim query vector
    Ollama-->>Inngest: Return: [0.789, -0.234, ...]
    
    Inngest->>Qdrant: search(query_vector, top_k=5)
    Note over Qdrant: Find similar vectors<br/>using cosine similarity
    Qdrant->>Qdrant: Search collection
    Qdrant-->>Inngest: Return: {contexts: [...], sources: [...]}
    
    Inngest->>Inngest: Step 2: Generate Answer
    
    Inngest->>Gemma: generate(prompt)
    Note over Gemma: gemma3:1b model<br/>Input: System prompt +<br/>Context chunks + Question
    Gemma->>Gemma: Process context & question
    Gemma->>Gemma: Generate answer (max 1024 tokens)
    Gemma-->>Inngest: Return: "Answer text..."
    
    Inngest-->>FastAPI: Return: {answer, sources, num_contexts}
    FastAPI-->>Streamlit: Response data
    Streamlit-->>User: Display answer + sources
```

## Data Flow Visualization

### What Each Component Does

```mermaid
graph TD
    subgraph "Streamlit"
        ST1["Receives: User PDF file<br/>Sends: PDF path to FastAPI<br/>Receives: Success/Error status<br/>Displays: Upload confirmation"]
    end
    
    subgraph "FastAPI"
        API1["Receives: PDF path from Streamlit<br/>Creates: Inngest event<br/>Sends: Event to Inngest<br/>Returns: Event ID to Streamlit"]
    end
    
    subgraph "Inngest"
        ING1["Receives: Event from FastAPI<br/>Orchestrates: Workflow steps<br/>Manages: Retries & rate limits<br/>Returns: Final result to FastAPI"]
    end
    
    subgraph "LlamaIndex"
        LI1["Receives: PDF file path<br/>Reads: PDF content<br/>Splits: Into text chunks<br/>Returns: Array of text chunks"]
    end
    
    subgraph "Ollama: nomic-embed-text"
        EMB1["Receives: Text chunks or question<br/>Processes: Text through model<br/>Generates: 768-dimension vectors<br/>Returns: Array of 768 numbers"]
    end
    
    subgraph "Qdrant"
        QD1["Receives: Vectors + IDs + Payloads<br/>Stores: Vectors in collection<br/>Indexes: For similarity search<br/>Returns: Top-K similar chunks on query"]
    end
    
    subgraph "Ollama: gemma3:1b"
        LLM1["Receives: Question + Context chunks<br/>Processes: Through language model<br/>Generates: Answer text<br/>Returns: Final answer string"]
    end
    
    ST1 --> API1
    API1 --> ING1
    ING1 --> LI1
    LI1 --> EMB1
    EMB1 --> QD1
    QD1 --> LLM1
    LLM1 --> ING1
    ING1 --> API1
    API1 --> ST1
```

## Workflow Summary

### Document Ingestion
1. User uploads PDF via Streamlit
2. FastAPI sends event to Inngest
3. Inngest workflow:
   - Reads PDF and splits into chunks
   - Converts chunks to embeddings using nomic-embed-text
   - Saves embeddings to Qdrant

### Question Answering
1. User asks a question via Streamlit
2. FastAPI sends event to Inngest
3. Inngest workflow:
   - Converts question to embedding
   - Searches Qdrant for similar chunks
   - Sends chunks + question to gemma3:1b
   - Returns answer with source documents

## Performance

**gemma3:1b Speed**: ~2,585 tokens/second on modern hardware

**Memory**: ~1.5GB VRAM (BF16) or ~1.1GB (SFP8)

**Embedding Dimensions**: 768 per chunk

**Chunk Size**: 1000 characters with 200 character overlap
