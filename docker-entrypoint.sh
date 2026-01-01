#!/bin/sh
set -e

# Start Ollama in the background
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to be ready
echo "Waiting for Ollama to start..."
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
    if curl -s http://localhost:11435/api/tags > /dev/null 2>&1; then
        echo "Ollama is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Ollama failed to start"
        kill $OLLAMA_PID 2>/dev/null || true
        exit 1
    fi
    sleep 2
done

# Pull required models
echo "Pulling nomic-embed-text model..."
ollama pull nomic-embed-text || echo "Warning: Failed to pull nomic-embed-text"

echo "Pulling gemma3:1b model..."
ollama pull gemma3:1b || echo "Warning: Failed to pull gemma3:1b"

echo "All models pulled successfully!"

# Keep Ollama running in foreground
wait $OLLAMA_PID

