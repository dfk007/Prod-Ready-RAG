FROM python:3.13-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv for faster package management
RUN pip install --no-cache-dir uv

# Copy dependency files
COPY pyproject.toml uv.lock* ./

# Install Python dependencies
RUN uv sync --frozen

# Copy application code
COPY . .

# Create uploads directory
RUN mkdir -p uploads

# Make venv Python available in PATH
ENV PATH="/app/.venv/bin:$PATH"

# Expose ports
# 8000 for FastAPI
# 8501 for Streamlit
EXPOSE 8000 8501

# Make venv Python available in PATH
ENV PATH="/app/.venv/bin:$PATH"

# Default command (can be overridden in docker-compose)
# Use venv python explicitly
CMD ["/app/.venv/bin/python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

