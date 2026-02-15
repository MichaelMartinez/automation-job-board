# AITB Automation Job Board

A community-focused job board where sponsors post automation help requests and AITB apprentices apply to fulfill them. Think "Upwork for AI automation" but focused on the AITB community.

## Tech Stack

- **Backend:** FastAPI (Python 3.11+)
- **Database:** PostgreSQL 15
- **Frontend:** React 18 + TypeScript, Vite, Tailwind CSS, shadcn/ui
- **Auth:** JWT (python-jose + passlib/bcrypt)
- **LLM:** OpenRouter API (Claude 3 Haiku)

## Prerequisites

Make sure you have the following installed before starting:

| Tool | Version | Check with |
|------|---------|------------|
| **Git** | any | `git --version` |
| **Docker** & **Docker Compose** | Docker 20+, Compose v2+ | `docker --version` && `docker compose version` |
| **Python** | 3.11+ | `python3 --version` |
| **Node.js** | 18+ | `node --version` |
| **npm** | 9+ | `npm --version` |

> **Note:** The database runs via Docker so you do **not** need PostgreSQL installed locally.

## Quick Start

### 1. Clone and Set Up

```bash
git clone <repo-url>
cd automation-job-board
./setup.sh
```

`setup.sh` handles everything automatically:
- Checks prerequisites (Docker, Python, Node, npm)
- Starts Docker containers (PostgreSQL + pgAdmin)
- Creates a Python virtual environment and installs backend deps
- Verifies auth packages (`python-jose`, `passlib`, `python-multipart`)
- Copies `.env.example` → `.env` if needed
- Runs database migrations
- Installs frontend deps

> **Linux users:** `setup.sh` auto-detects Linux and creates a `docker-compose.override.yml` that uses host networking. This avoids Docker bridge/nftables issues on newer kernels (6.x+). The override is gitignored so it won't affect teammates.

After setup, edit `backend/.env` with your keys:

```ini
# Required — get a key at https://openrouter.ai/keys
OPENROUTER_API_KEY=your-openrouter-api-key-here

# Change this to a random string for production
JWT_SECRET_KEY=change-this-to-a-secure-random-string
```

### 2. Start Development Servers

```bash
./start.sh
```

This starts Docker, runs pending migrations, and launches:
- **Backend (uvicorn):** http://localhost:8000 (Swagger docs at `/docs`)
- **Frontend (Vite):** http://localhost:5173
- **pgAdmin:** http://localhost:5050 (login: `admin@local.dev` / `admin`)

Press **Ctrl+C** to stop both servers cleanly.

### 3. Stop Everything

```bash
./stop.sh
```

Kills backend/frontend processes and stops Docker containers.

### Manual Setup (without scripts)

<details>
<summary>Click to expand manual steps</summary>

```bash
# Start the database
docker compose up -d

# Set up backend
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env   # then edit with your keys
alembic upgrade head
uvicorn app.main:app --reload

# In a new terminal — set up frontend
cd frontend
npm install
npm run dev
```

</details>

## Environment Variables

All backend configuration is managed through `backend/.env` (loaded by Pydantic Settings):

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `postgresql+psycopg://aitb:aitb_dev_password@localhost:5432/aitb_jobboard` | PostgreSQL connection string |
| `JWT_SECRET_KEY` | *(must set)* | Secret key for signing JWT tokens |
| `JWT_ALGORITHM` | `HS256` | JWT signing algorithm |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `1440` (24 hours) | Token expiry time |
| `OPENROUTER_API_KEY` | *(must set for AI features)* | API key from [OpenRouter](https://openrouter.ai) |
| `DEBUG` | `true` | Enable debug mode |

Frontend:

| Variable | Default | Description |
|----------|---------|-------------|
| `VITE_API_URL` | `/api` | Backend API base URL |

## Project Structure

```
automation-job-board/
├── setup.sh                 # First-time setup script
├── start.sh                 # Start dev servers (Ctrl+C to stop)
├── stop.sh                  # Stop everything
├── docker-compose.yml       # Postgres + pgAdmin (bridge networking, works on macOS)
├── docker-compose.linux.yml # Linux override template (host networking)
├── .env.example             # Root env template (reference)
│
├── backend/
│   ├── pyproject.toml       # Python dependencies & tooling config
│   ├── .env.example         # Backend env template (copy to .env)
│   ├── alembic.ini          # DB migrations config
│   ├── alembic/             # Migration scripts
│   │   └── versions/        # Individual migration files
│   └── app/
│       ├── main.py          # FastAPI entry point
│       ├── config.py        # Pydantic Settings (reads .env)
│       ├── database.py      # DB connection / session
│       ├── models/          # SQLAlchemy ORM models
│       ├── schemas/         # Pydantic request/response schemas
│       ├── api/             # Route handlers
│       └── services/        # Business logic + AI integration
│
└── frontend/
    ├── package.json         # Node dependencies & scripts
    ├── vite.config.ts       # Vite build config
    ├── tailwind.config.ts   # Midnight Blue + Electric Teal theme
    ├── tsconfig.json        # TypeScript config
    └── src/
        ├── App.tsx          # Root component + routing
        ├── lib/
        │   ├── api.ts       # Axios client + API functions
        │   ├── auth.tsx     # Auth context provider
        │   └── utils.ts     # Utility helpers
        ├── components/      # Reusable UI components
        ├── pages/           # Route pages
        ├── hooks/           # React hooks (useJobs, useApplications)
        └── types/           # TypeScript type definitions
```

## Development Workflow

### Running Tests (Backend)

```bash
cd backend
source .venv/bin/activate
pytest
```

### Linting (Backend)

```bash
ruff check app/
ruff format app/
```

### Linting (Frontend)

```bash
cd frontend
npm run lint
```

### Building for Production (Frontend)

```bash
cd frontend
npm run build    # Outputs to dist/
npm run preview  # Preview the production build locally
```

### Database Migrations

When you change SQLAlchemy models, create a new migration:

```bash
cd backend
source .venv/bin/activate
alembic revision --autogenerate -m "describe your change"
alembic upgrade head
```

## Troubleshooting

### Port 5432 already in use
Something else is using the PostgreSQL port. Stop any local PostgreSQL service:
```bash
sudo systemctl stop postgresql  # Linux
brew services stop postgresql   # macOS
```

### Database connection hangs (Linux)
Docker's bridge networking can fail on Linux kernels 6.x+ with nftables. The fix is host networking:
```bash
cp docker-compose.linux.yml docker-compose.override.yml
docker compose down && docker compose up -d
```
`setup.sh` does this automatically on Linux.

### `alembic upgrade head` fails with connection error
Make sure the Docker database is running and healthy:
```bash
docker compose ps
docker compose logs db
```

### Frontend can't reach the backend
Make sure the backend is running on port 8000 and set `VITE_API_URL=http://localhost:8000/api` in `frontend/.env`. You'll need to restart the Vite dev server after changing env vars.

### Python version issues
The project requires Python 3.11+. If your system default is older, use `python3.11` or `python3.12` explicitly, or use [pyenv](https://github.com/pyenv/pyenv) to manage versions.

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/auth/register` | POST | Register new user |
| `/api/auth/login` | POST | Login and get JWT token |
| `/api/auth/me` | GET | Get current user |
| `/api/jobs` | GET | List open jobs |
| `/api/jobs` | POST | Create job (sponsors) |
| `/api/jobs/{id}` | GET | Job details |
| `/api/jobs/my` | GET | List current user's jobs |
| `/api/applications` | POST | Submit application |
| `/api/applications` | GET | My applications (apprentices) |
| `/api/applications/job/{id}` | GET | Applications for a specific job |
| `/api/applications/{id}/status` | PATCH | Update application status |
| `/api/ai/generate-description` | POST | Generate job description via AI |
| `/api/ai/generate-cover-letter` | POST | Generate cover letter via AI |
| `/api/ai/match-jobs` | POST | AI-powered job matching |

## Features

### Core Flow
- User registration (sponsor or apprentice roles)
- Sponsors post automation jobs
- Apprentices browse and apply to jobs
- Sponsors review and accept/reject applications

### AI Features (powered by OpenRouter)
- **Generate Job Descriptions:** Sponsors describe their need briefly and get a full job posting
- **Generate Cover Letters:** Apprentices get AI-assisted cover letter suggestions
- **Job Matching:** AI-powered job recommendations

## Theme

The app uses a **Midnight Blue (#1e3a5f)** and **Electric Teal (#00d9c0)** color scheme. See `frontend/tailwind.config.ts` for the full palette.

## License

MIT
