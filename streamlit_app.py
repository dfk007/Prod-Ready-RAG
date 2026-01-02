from pathlib import Path
import time

import streamlit as st
import inngest
from dotenv import load_dotenv
import os
import requests

load_dotenv()

st.set_page_config(page_title="RAG Ingest PDF", page_icon="📄", layout="centered")


@st.cache_resource
def get_inngest_client() -> inngest.Inngest:
    # The Inngest SDK automatically reads from environment variables:
    # - INNGEST_API_BASE (defaults to http://127.0.0.1:8288/v1)
    # - INNGEST_EVENT_KEY (optional, for authentication)
    # - INNGEST_SIGNING_KEY (optional, for webhook signing)
    # 
    # For Docker: These are set in docker-compose.yml
    # For local: Set in .env file or use defaults
    # 
    # NOTE: The SDK reads these from env vars automatically - don't pass them as kwargs!
    return inngest.Inngest(
        app_id="rag_app",
        is_production=False,
    )


def save_uploaded_pdf(file) -> Path:
    uploads_dir = Path("uploads")
    uploads_dir.mkdir(parents=True, exist_ok=True)
    file_path = uploads_dir / file.name
    file_bytes = file.getbuffer()
    file_path.write_bytes(file_bytes)
    return file_path


def send_rag_ingest_event(pdf_path: Path) -> None:
    """Send RAG ingest event using Inngest SDK client."""
    # Use the Inngest SDK client - it knows the correct endpoint
    client = get_inngest_client()
    
    try:
        # Use synchronous API to avoid conflicts with Streamlit's async runtime
        result = client.send_sync(
            inngest.Event(
                name="rag/ingest_pdf",
                data={
                    "pdf_path": str(pdf_path.resolve()),
                    "source_id": pdf_path.name,
                }
            )
        )
        # SDK returns list[str] of event IDs on success
        if not isinstance(result, list) or len(result) == 0:
            raise ValueError("Inngest SDK returned no event IDs - event may not have been sent")
    except (ValueError, ConnectionError) as e:
        # Preserve original error types
        raise
    except Exception as e:
        raise ConnectionError(
            f"Failed to send event to Inngest: {str(e)}. "
            f"Please ensure the Inngest service is running and accessible."
        )


st.title("Upload a PDF to Ingest")
uploaded = st.file_uploader("Choose a PDF", type=["pdf"], accept_multiple_files=False)

if uploaded is not None:
    with st.spinner("Uploading and triggering ingestion..."):
        path = save_uploaded_pdf(uploaded)
        # Kick off the event and block until the send completes
        try:
            send_rag_ingest_event(path)
            # Small pause for user feedback continuity
            time.sleep(0.3)
            st.success(f"Triggered ingestion for: {path.name}")
            st.caption("You can upload another PDF if you like.")
        except Exception as e:
            st.error(f"Failed to trigger ingestion: {str(e)}")
            st.caption("Please ensure the Inngest service is running and accessible.")

st.divider()
st.title("Ask a question about your PDFs")


def send_rag_query_event(question: str, top_k: int) -> str:
    """Send RAG query event using Inngest SDK client and return event ID."""
    # Use the Inngest SDK client - it knows the correct endpoint
    client = get_inngest_client()
    
    try:
        # Use synchronous API to avoid conflicts with Streamlit's async runtime
        result = client.send_sync(
            inngest.Event(
                name="rag/query_pdf_ai",
                data={
                    "question": question,
                    "top_k": top_k,
                }
            )
        )
        
        # SDK returns list[str] of event IDs: ["event-id-1", "event-id-2", ...]
        if isinstance(result, list) and len(result) > 0:
            return result[0]  # Return first event ID
        else:
            raise ValueError(f"Inngest SDK returned empty or invalid result: {result}")
            
    except (ValueError, ConnectionError) as e:
        # Preserve original error types
        raise
    except Exception as e:
        raise ConnectionError(
            f"Failed to send event to Inngest: {str(e)}. "
            f"Please ensure the Inngest service is running and accessible."
        )


def _inngest_api_base() -> str:
    # Local dev server default; configurable via env
    # For Docker, use 'inngest' hostname; for local, use 127.0.0.1
    return os.getenv("INNGEST_API_BASE", "http://127.0.0.1:8288/v1")


def fetch_runs(event_id: str) -> list[dict]:
    url = f"{_inngest_api_base()}/events/{event_id}/runs"
    resp = requests.get(url)
    resp.raise_for_status()
    data = resp.json()
    return data.get("data", [])


def wait_for_run_output(event_id: str, timeout_s: float = 120.0, poll_interval_s: float = 0.5) -> dict:
    start = time.time()
    last_status = None
    while True:
        runs = fetch_runs(event_id)
        if runs:
            run = runs[0]
            status = run.get("status")
            last_status = status or last_status
            if status in ("Completed", "Succeeded", "Success", "Finished"):
                return run.get("output") or {}
            if status in ("Failed", "Cancelled"):
                raise RuntimeError(f"Function run {status}")
        if time.time() - start > timeout_s:
            raise TimeoutError(f"Timed out waiting for run output (last status: {last_status})")
        time.sleep(poll_interval_s)


with st.form("rag_query_form"):
    question = st.text_input("Your question")
    top_k = st.number_input("How many chunks to retrieve", min_value=1, max_value=20, value=5, step=1)
    submitted = st.form_submit_button("Ask")

    if submitted and question.strip():
        with st.spinner("Sending event and generating answer..."):
            try:
                # Fire-and-forget event to Inngest for observability/workflow
                event_id = send_rag_query_event(question.strip(), int(top_k))
                # Poll the local Inngest API for the run's output
                output = wait_for_run_output(event_id)
                answer = output.get("answer", "")
                sources = output.get("sources", [])
            except Exception as e:
                st.error(f"Failed to query: {str(e)}")
                st.caption("Please ensure the Inngest service is running and accessible.")
                answer = ""
                sources = []

        st.subheader("Answer")
        st.write(answer or "(No answer)")
        if sources:
            st.caption("Sources")
            for s in sources:
                st.write(f"- {s}")

