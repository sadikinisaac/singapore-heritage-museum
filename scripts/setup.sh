#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Singapore Heritage Museum — Local Dev Setup Script
# Usage: bash scripts/setup.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "🦁 Singapore Heritage Museum — DevSecOps Setup"
echo "================================================"
echo ""

# ── Check prerequisites ────────────────────────────────────────────────────
check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${RED}✗ $1 not found. Please install it first.${NC}"
    exit 1
  else
    echo -e "${GREEN}✓ $1 found${NC}"
  fi
}

echo "Checking prerequisites..."
check_cmd docker
check_cmd python3
check_cmd git
echo ""

# ── .env setup ────────────────────────────────────────────────────────────
if [ ! -f ".env" ]; then
  echo -e "${YELLOW}Creating .env from .env.example...${NC}"
  cp .env.example .env

  # Generate a random secret key
  SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/change-me-to-a-long-random-string/$SECRET/" .env
  else
    sed -i "s/change-me-to-a-long-random-string/$SECRET/" .env
  fi
  echo -e "${GREEN}✓ .env created with generated SECRET_KEY${NC}"
else
  echo -e "${GREEN}✓ .env already exists${NC}"
fi
echo ""

# ── Python virtual environment ────────────────────────────────────────────
echo "Setting up Python virtual environment..."
if [ ! -d "venv" ]; then
  python3 -m venv venv
  echo -e "${GREEN}✓ venv created${NC}"
fi

source venv/bin/activate
pip install --quiet -r app/requirements.txt
pip install --quiet pytest pytest-cov flake8 bandit pip-audit
echo -e "${GREEN}✓ Python dependencies installed${NC}"
echo ""

# ── Run local security checks ─────────────────────────────────────────────
echo "Running security checks..."
echo ""

echo "▶ flake8 lint..."
flake8 app/ tests/ --max-line-length=100 --exclude=__pycache__ && \
  echo -e "${GREEN}  ✓ No lint issues${NC}"

echo ""
echo "▶ pip-audit dependency scan..."
pip-audit -r app/requirements.txt --progress-spinner=off && \
  echo -e "${GREEN}  ✓ No known CVEs${NC}"

echo ""
echo "▶ bandit SAST scan..."
bandit -r app/ -q && echo -e "${GREEN}  ✓ No high-severity issues${NC}"

echo ""
echo "▶ Running unit tests..."
SECRET_KEY="local-test-key" FLASK_ENV=testing \
  pytest tests/ -v --tb=short && \
  echo -e "${GREEN}  ✓ All tests passed${NC}"

echo ""
echo "════════════════════════════════════════════"
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "To start the application:"
echo "  docker compose up --build"
echo ""
echo "Then open: http://localhost"
echo ""
