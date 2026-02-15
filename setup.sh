#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; }

# ── Detect docker compose command ────────────────────────────────────
if docker compose version &>/dev/null; then
  DOCKER_COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then
  DOCKER_COMPOSE="docker-compose"
else
  error "Neither 'docker compose' nor 'docker-compose' found."
  exit 1
fi

# ── Check prerequisites ──────────────────────────────────────────────
info "Checking prerequisites..."

missing=()
for cmd in docker python3 node npm; do
  if ! command -v "$cmd" &>/dev/null; then
    missing+=("$cmd")
  fi
done

if [ ${#missing[@]} -ne 0 ]; then
  error "Missing required tools: ${missing[*]}"
  exit 1
fi

info "All prerequisites found."

# ── Linux: suggest host networking override ──────────────────────────
if [[ "$(uname)" == "Linux" ]] && [ ! -f "docker-compose.override.yml" ]; then
  warn "Linux detected. Docker bridge networking may not work on newer kernels."
  warn "Creating docker-compose.override.yml from docker-compose.linux.yml..."
  cp docker-compose.linux.yml docker-compose.override.yml
fi

# ── Start Docker containers ──────────────────────────────────────────
info "Starting Docker containers..."
$DOCKER_COMPOSE up -d

# ── Wait for Postgres ────────────────────────────────────────────────
info "Waiting for Postgres to be healthy..."
retries=30
until docker inspect --format='{{.State.Health.Status}}' aitb_postgres 2>/dev/null | grep -q "healthy"; do
  retries=$((retries - 1))
  if [ "$retries" -le 0 ]; then
    error "Postgres did not become healthy in time."
    exit 1
  fi
  sleep 2
done
info "Postgres is healthy."

# ── Backend setup ────────────────────────────────────────────────────
info "Setting up backend..."

if [ ! -d "backend/.venv" ]; then
  info "Creating backend virtual environment..."
  python3 -m venv backend/.venv
fi

source backend/.venv/bin/activate

info "Installing backend dependencies..."
pip install -e "backend/.[dev]" --quiet

# Verify critical auth packages are importable
info "Verifying auth dependencies..."
missing_pkgs=()
python3 -c "from jose import jwt" 2>/dev/null       || missing_pkgs+=("python-jose[cryptography]")
python3 -c "from passlib.context import CryptContext" 2>/dev/null || missing_pkgs+=("passlib[bcrypt]")
python3 -c "import multipart" 2>/dev/null            || missing_pkgs+=("python-multipart")

if [ ${#missing_pkgs[@]} -ne 0 ]; then
  warn "Some auth packages failed to install. Retrying: ${missing_pkgs[*]}"
  pip install "${missing_pkgs[@]}" --quiet
fi

# ── Environment file ─────────────────────────────────────────────────
if [ ! -f "backend/.env" ]; then
  cp backend/.env.example backend/.env
  warn "Created backend/.env from .env.example — please edit it with your secrets."
fi

# ── Run migrations ───────────────────────────────────────────────────
info "Running database migrations..."
(cd backend && alembic upgrade head)

deactivate

# ── Frontend setup ───────────────────────────────────────────────────
info "Installing frontend dependencies..."
(cd frontend && npm install)

# ── Done ─────────────────────────────────────────────────────────────
echo ""
info "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Edit backend/.env with your API keys"
echo "  2. Run ./start.sh to start the dev servers"
