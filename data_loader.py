import ollama
from llama_index.readers.file import PDFReader
from llama_index.core.node_parser import SentenceSplitter
from dotenv import load_dotenv
import os

load_dotenv()

# Using nomic-embed-text for embeddings (Ollama embedding model)
# gemma3:1b is used for LLM, but we need a dedicated embedding model
EMBED_MODEL = "nomic-embed-text"
EMBED_DIM = 768  # nomic-embed-text produces 768-dimensional embeddings

# Initialize Ollama client (supports custom base URL via environment variable)
ollama_base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
ollama_client = ollama.Client(host=ollama_base_url)

splitter = SentenceSplitter(chunk_size=1000, chunk_overlap=200)

def load_and_chunk_pdf(path: str):
    docs = PDFReader().load_data(file=path)
    texts = [d.text for d in docs if getattr(d, "text", None)]
    chunks = []
    for t in texts:
        chunks.extend(splitter.split_text(t))
    return chunks


def embed_texts(texts: list[str]) -> list[list[float]]:
    """Generate embeddings using Ollama."""
    embeddings = []
    for text in texts:
        response = ollama_client.embeddings(model=EMBED_MODEL, prompt=text)
        embeddings.append(response["embedding"])
    return embeddings