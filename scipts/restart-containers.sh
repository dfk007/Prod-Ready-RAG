#!/bin/bash
# Script to rebuild and restart Docker containers after code changes
# Usage: ./scipts/restart-containers.sh [service_name]
#   - If service_name is provided, only rebuild/restart that service
#   - If no service_name, rebuild/restart all services

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SERVICE=${1:-""}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Docker Container Rebuild & Restart Script                      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"

if [ -n "$SERVICE" ]; then
    echo -e "\n${YELLOW}Rebuilding and restarting service: ${SERVICE}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "\n${YELLOW}Step 1: Building ${SERVICE} (no cache)...${NC}"
    docker compose build --no-cache "$SERVICE"
    
    echo -e "\n${YELLOW}Step 2: Restarting ${SERVICE}...${NC}"
    docker compose up -d "$SERVICE"
    
    echo -e "\n${YELLOW}Step 3: Checking ${SERVICE} status...${NC}"
    docker compose ps "$SERVICE"
    
    echo -e "\n${GREEN}✓ ${SERVICE} rebuilt and restarted successfully!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
else
    echo -e "\n${YELLOW}Rebuilding and restarting ALL services...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "\n${YELLOW}Step 1: Building all services (no cache)...${NC}"
    docker compose build --no-cache
    
    echo -e "\n${YELLOW}Step 2: Restarting all services...${NC}"
    docker compose up -d
    
    echo -e "\n${YELLOW}Step 3: Checking all services status...${NC}"
    docker compose ps
    
    echo -e "\n${GREEN}✓ All services rebuilt and restarted successfully!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
fi

echo -e "\n${BLUE}Available services:${NC}"
echo "  - streamlit  (Streamlit web app)"
echo "  - fastapi    (FastAPI backend with Inngest functions)"
echo "  - inngest    (Inngest dev server)"
echo "  - qdrant     (Vector database)"
echo "  - ollama     (LLM and embeddings)"
echo "  - redis      (Event queue backend)"

echo -e "\n${YELLOW}To view logs:${NC}"
if [ -n "$SERVICE" ]; then
    echo "  docker compose logs -f $SERVICE"
else
    echo "  docker compose logs -f"
fi

echo -e "\n${YELLOW}To view service status:${NC}"
echo "  docker compose ps"

