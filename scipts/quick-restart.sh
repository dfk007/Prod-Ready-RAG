#!/bin/bash
# Quick restart without rebuild (use when no code changes, just need to restart)
# Usage: ./scipts/quick-restart.sh [service_name]

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

echo -e "${BLUE}Quick Restart (no rebuild)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -n "$SERVICE" ]; then
    echo -e "\n${YELLOW}Restarting ${SERVICE}...${NC}"
    docker compose restart "$SERVICE"
    echo -e "${GREEN}✓ ${SERVICE} restarted!${NC}"
else
    echo -e "\n${YELLOW}Restarting all services...${NC}"
    docker compose restart
    echo -e "${GREEN}✓ All services restarted!${NC}"
fi

echo -e "\n${YELLOW}Service status:${NC}"
docker compose ps "$SERVICE" 2>/dev/null || docker compose ps

