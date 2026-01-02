import asyncio
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
    return inngest.Inngest(
        app_id="rag_app",
        is_production=False
    )


def save_uploaded_pdf(file) -> Path:
    uploads_dir = Path("uploads")
    uploads_dir.mkdir(parents=True, exist_ok=True)
    file_path = uploads_dir / file.name
    file_bytes = file.getbuffer()
    file_path.write_bytes(file_bytes)
    return file_path


def send_rag_ingest_event(pdf_path: Path) -> None:
    # Verify Inngest is reachable before sending
    api_base = os.getenv("INNGEST_API_BASE", "http://127.0.0.1:8288/v1")
    try:
        # Quick health check
        health_url = api_base.replace("/v1", "/api/health")
        response = requests.get(health_url, timeout=2)
        response.raise_for_status()
    except Exception as e:
        raise ConnectionError(
            f"Cannot reach Inngest service at {api_base}. "
            f"Please ensure the Inngest service is running and accessible. Error: {str(e)}"
        )
    
    # Send event via direct HTTP API call to avoid SDK configuration issues
    event_key = os.getenv("INNGEST_EVENT_KEY")
    headers = {"Content-Type": "application/json"}
    if event_key:
        headers["Authorization"] = f"Bearer {event_key}"
    
    # Inngest API expects events as an array
    event_data = [{
        "name": "rag/ingest_pdf",
        "data": {
            "pdf_path": str(pdf_path.resolve()),
            "source_id": pdf_path.name,
        }
    }]
    
    # Inngest dev server uses /api/events endpoint (without /v1 prefix)
    # Extract base URL and construct correct endpoint
    base_url = api_base.replace("/v1", "").rstrip("/")
    events_url = f"{base_url}/api/events"
    
    response = requests.post(
        events_url,
        json=event_data,
        headers=headers,
        timeout=10
    )
    response.raise_for_status()


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
    # Verify Inngest is reachable before sending
    api_base = os.getenv("INNGEST_API_BASE", "http://127.0.0.1:8288/v1")
    try:
        # Quick health check
        health_url = api_base.replace("/v1", "/api/health")
        response = requests.get(health_url, timeout=2)
        response.raise_for_status()
    except Exception as e:
        raise ConnectionError(
            f"Cannot reach Inngest service at {api_base}. "
            f"Please ensure the Inngest service is running and accessible. Error: {str(e)}"
        )
    
    # Send event via direct HTTP API call to avoid SDK configuration issues
    event_key = os.getenv("INNGEST_EVENT_KEY")
    headers = {"Content-Type": "application/json"}
    if event_key:
        headers["Authorization"] = f"Bearer {event_key}"
    
    # Inngest API expects events as an array
    event_data = [{
        "name": "rag/query_pdf_ai",
        "data": {
            "question": question,
            "top_k": top_k,
        }
    }]
    
    # Inngest dev server uses /api/events endpoint (without /v1 prefix)
    # Extract base URL and construct correct endpoint
    base_url = api_base.replace("/v1", "").rstrip("/")
    events_url = f"{base_url}/api/events"
    
    response = requests.post(
        events_url,
        json=event_data,
        headers=headers,
        timeout=10
    )
    response.raise_for_status()
    result = response.json()
    
    # Return the event ID from the response
    # Inngest returns: {"ids": ["event-id-1", "event-id-2", ...]}
    if isinstance(result, dict) and "ids" in result:
        ids = result["ids"]
        if ids and len(ids) > 0:
            return ids[0]
    elif isinstance(result, list) and len(result) > 0:
        # Handle array response format
        first_item = result[0]
        if isinstance(first_item, dict):
            return first_item.get("ids", [None])[0] if "ids" in first_item else first_item.get("id")
    
    raise ValueError(f"Unexpected response format from Inngest: {result}")


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

