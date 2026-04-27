# 🦁 Singapore Heritage Museum — DevSecOps Capstone Project

![CI Dev](https://img.shields.io/badge/CI-Dev%20Branch-blue)
![Security](https://img.shields.io/badge/Security-Bandit%20%7C%20Trivy%20%7C%20pip--audit-green)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED)
![Python](https://img.shields.io/badge/Python-3.12-3776AB)
![Flask](https://img.shields.io/badge/Flask-3.0-000000)

> **Use Case 3 — Security Focused (DevSecOps)**
> A production-grade DevSecOps pipeline for the Singapore Heritage Museum web application, with security gates at every stage of the CI/CD pipeline.

---

## 📋 Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture Diagram](#2-architecture-diagram)
3. [Repository Structure](#3-repository-structure)
4. [Application Overview](#4-application-overview)
5. [Branching Strategy](#5-branching-strategy)
6. [Security Measures](#6-security-measures)
7. [CI/CD Pipeline](#7-cicd-pipeline)
8. [Secrets Management](#8-secrets-management)
9. [Getting Started (Local)](#9-getting-started-local)
10. [Running Tests](#10-running-tests)
11. [Docker Compose Usage](#11-docker-compose-usage)
12. [GitHub Repository Setup](#12-github-repository-setup)
13. [Branch Protection Rules](#13-branch-protection-rules)
14. [Environment Credentials Separation](#14-environment-credentials-separation)
15. [Troubleshooting](#15-troubleshooting)
16. [Team](#16-team)

---

## 1. Project Overview

**Organisation:** Singapore Heritage Museum (fictional capstone organisation)
**Project Name:** Museum Web Portal — DevSecOps Pipeline
**Stack:** Python 3.12 · Flask 3 · Docker · Nginx · GitHub Actions

### Completion Criteria Checklist

| Criterion | Status | Details |
|-----------|--------|---------|
| Typical CI/CD Pipeline | ✅ | 3 workflow files: `ci-dev.yml`, `cd-staging.yml`, `cd-production.yml` |
| Dependency Screening in CI | ✅ | `pip-audit` + `bandit` in every CI run |
| Auth/Authorisation per environment | ✅ | Separate secrets: `STAGING_*` vs `PROD_*` |
| Proper Secrets Handling | ✅ | GitHub Secrets only, `.env` gitignored, no hardcoded values |
| Dev branch accessible to all devs | ✅ | Branch protection allows push; staging/main are PR-only |
| Master branch secured | ✅ | Protected: requires PR + approval + passing CI + no direct push |
| Container image scanning | ✅ | Trivy scans every image before push |
| SAST | ✅ | Bandit static analysis on every dev push |

---

## 2. Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                        DEVELOPER WORKSTATION                         │
│  feature/xyz ──► git push ──► Pull Request ──► dev branch           │
└───────────────────────────────┬──────────────────────────────────────┘
                                │
                    ┌───────────▼───────────┐
                    │   GitHub Actions CI   │
                    │  (ci-dev.yml)         │
                    │  1. flake8 lint       │
                    │  2. pip-audit (CVEs)  │
                    │  3. bandit SAST       │
                    │  4. pytest + coverage │
                    └───────────┬───────────┘
                                │ merge to staging
                    ┌───────────▼───────────┐
                    │  GitHub Actions CD    │
                    │  (cd-staging.yml)     │
                    │  1. Build image       │
                    │  2. Trivy scan        │
                    │  3. Push GHCR         │
                    │  4. Deploy staging    │  ← uses STAGING_* secrets
                    │  5. Smoke test        │
                    └───────────┬───────────┘
                                │ PR + manual approval
                    ┌───────────▼───────────┐
                    │  GitHub Actions CD    │
                    │  (cd-production.yml)  │
                    │  1. Security gate     │
                    │  2. Build image       │
                    │  3. Trivy (stricter)  │
                    │  4. Manual approval   │  ← GitHub Environment rule
                    │  5. Deploy production │  ← uses PROD_* secrets
                    │  6. Tag release       │
                    └───────────┬───────────┘
                                │
               ┌────────────────▼────────────────┐
               │         Docker Compose          │
               │  ┌──────────┐  ┌─────────────┐ │
               │  │  Nginx   │  │  Flask App  │ │
               │  │ :80      │──│  :5000      │ │
               │  │ (proxy)  │  │ (gunicorn)  │ │
               │  └──────────┘  └─────────────┘ │
               │         museum-net bridge        │
               └─────────────────────────────────┘
```

---

## 3. Repository Structure

```
singapore-museum-devsecops/
│
├── .github/
│   └── workflows/
│       ├── ci-dev.yml          # CI: lint + dep scan + SAST + tests
│       ├── cd-staging.yml      # CD: build + Trivy scan + staging deploy
│       └── cd-production.yml   # CD: security gate + prod deploy (manual approval)
│
├── app/
│   ├── app.py                  # Flask application (entry point)
│   ├── requirements.txt        # Python dependencies
│   ├── templates/
│   │   └── index.html          # Museum frontend
│   └── static/
│       ├── css/style.css
│       └── js/main.js
│
├── nginx/
│   ├── nginx.conf              # Nginx main config
│   └── default.conf            # Virtual host + security headers + rate limiting
│
├── tests/
│   ├── __init__.py
│   └── test_app.py             # Pytest unit tests
│
├── scripts/
│   └── setup.sh                # Local dev setup helper
│
├── .bandit                     # Bandit SAST configuration
├── .env.example                # Env var template (never commit .env)
├── .gitignore
├── Dockerfile                  # Multi-stage build (builder + runtime)
├── docker-compose.yml          # Local / dev compose
├── docker-compose.prod.yml     # Production overrides
└── README.md
```

---

## 4. Application Overview

The **Singapore Heritage Museum** web portal is a Python/Flask REST API with a fully rendered frontend.

### API Endpoints

| Method | Path | Description | Rate Limited |
|--------|------|-------------|--------------|
| `GET` | `/` | Museum homepage (HTML) | No |
| `GET` | `/health` | Health check (JSON) | No |
| `GET` | `/api/exhibits` | List all exhibits | 60/hr |
| `GET` | `/api/exhibits/<id>` | Get single exhibit | 60/hr |
| `GET` | `/api/events` | List upcoming events | 60/hr |
| `POST` | `/api/tickets` | Book event tickets | 10/min |

### Sample Health Response

```json
{
  "status": "healthy",
  "service": "singapore-heritage-museum",
  "timestamp": "2025-04-25T08:00:00.000000",
  "version": "1.0.0",
  "environment": "production"
}
```

### Sample Ticket Booking Request

```bash
curl -X POST http://localhost:5000/api/tickets \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Tan Wei Lin",
    "email": "wei@example.com",
    "event_id": 1,
    "quantity": 2
  }'
```

---

## 5. Branching Strategy

This project uses a **GitFlow-inspired** branching model:

```
main (production)
  └── staging
        └── dev
              └── feature/add-exhibits
              └── feature/ticket-booking
              └── hotfix/fix-rate-limit
```

| Branch | Purpose | Who Can Push | Protected |
|--------|---------|--------------|-----------|
| `main` | Production-ready code | Nobody directly | ✅ Yes |
| `staging` | Pre-production integration | Nobody directly | ✅ Yes |
| `dev` | Active development | All developers | ⚠️ PR only |
| `feature/*` | Individual features/fixes | Feature owner | No |

### Workflow

```
1. Developer creates feature branch from dev:
   git checkout dev && git checkout -b feature/new-gallery

2. Developer pushes and opens PR → dev:
   git push origin feature/new-gallery
   (opens PR on GitHub)

3. CI runs automatically on the PR (ci-dev.yml)

4. After review + CI passes → merge to dev

5. When dev is stable → PR from dev → staging
   (cd-staging.yml runs: build + Trivy scan + deploy staging)

6. After staging validation → PR from staging → main
   (cd-production.yml runs: manual approval required → deploy prod)
```

---

## 6. Security Measures

### 6.1 Dependency Screening (`pip-audit`)
Every push to `dev` triggers a full CVE scan of `requirements.txt`:
```yaml
- name: Audit dependencies for known CVEs
  run: pip-audit -r app/requirements.txt --output-format=json
```
Results are uploaded as artifacts for review.

### 6.2 Static Application Security Testing — SAST (`bandit`)
Bandit scans all Python source files for common security issues:
- SQL injection patterns
- Hardcoded passwords / tokens
- Insecure use of `subprocess`, `pickle`, `eval`
- Weak cryptography
- The pipeline **fails** if any `HIGH` severity finding is detected.

### 6.3 Container Image Scanning (`trivy`)
Before any image is pushed to the registry:
- **Staging:** fails on `CRITICAL` and `HIGH` CVEs
- **Production:** fails on `CRITICAL`, `HIGH`, and `MEDIUM` CVEs (stricter)

Results are uploaded to **GitHub Security → Code Scanning** as SARIF.

### 6.4 Application-Level Security
| Measure | Implementation |
|---------|---------------|
| Security headers (CSP, HSTS, etc.) | `flask-talisman` |
| Rate limiting | `flask-limiter` (app) + Nginx `limit_req` |
| Non-root Docker user | `USER museum` in Dockerfile |
| Multi-stage Docker build | Minimises attack surface (no build tools in runtime) |
| Input validation | All POST endpoints validate types + required fields |
| Error handling | Never exposes stack traces to clients |

### 6.5 Nginx Security Headers
```
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin
Permissions-Policy: geolocation=()
Strict-Transport-Security: max-age=31536000
```

---

## 7. CI/CD Pipeline

### `ci-dev.yml` — Development CI

```
Push/PR to dev
      │
      ├─► [lint]            flake8 — code style
      ├─► [dependency-scan] pip-audit — CVE check
      ├─► [sast]            bandit — static security analysis
      └─► [unit-tests]      pytest + coverage (needs lint to pass)
```

### `cd-staging.yml` — Staging CD

```
Push to staging
      │
      ├─► [build-and-scan]
      │     ├─ Login to GHCR (STAGING_REGISTRY_TOKEN)
      │     ├─ Build Docker image
      │     ├─ Trivy scan (CRITICAL/HIGH)
      │     └─ Push image if scan passes
      │
      └─► [deploy-staging]  (GitHub Environment: staging)
            ├─ Write .env using STAGING_* secrets
            ├─ docker compose up
            └─ Smoke test /health
```

### `cd-production.yml` — Production CD

```
Push to main
      │
      ├─► [security-gate]
      │     ├─ pip-audit full audit
      │     ├─ bandit (medium + high)
      │     └─ Check no .env committed
      │
      ├─► [build-prod]
      │     ├─ Login to GHCR (PROD_REGISTRY_TOKEN)
      │     ├─ Build with git SHA tag
      │     ├─ Trivy scan (CRITICAL/HIGH/MEDIUM — strictest)
      │     └─ Push :sha + :latest tags
      │
      └─► [deploy-production]  (GitHub Environment: production — MANUAL APPROVAL)
            ├─ docker compose -f docker-compose.yml -f docker-compose.prod.yml up
            ├─ Health check /health (retry 5x)
            └─ Tag release in GitHub
```

---

## 8. Secrets Management

### GitHub Secrets Required

Navigate to: **Repository → Settings → Secrets and variables → Actions**

| Secret Name | Environment | Description |
|------------|-------------|-------------|
| `STAGING_REGISTRY_TOKEN` | Staging | GitHub PAT to push images (staging namespace only) |
| `STAGING_SECRET_KEY` | Staging | Flask SECRET_KEY for staging |
| `PROD_REGISTRY_TOKEN` | Production | GitHub PAT to push images (production namespace) |
| `PROD_SECRET_KEY` | Production | Flask SECRET_KEY for production |

> ⚠️ **Staging and production NEVER share the same secrets.** This is enforced by using separate GitHub Environment secrets.

### Generating a Secure SECRET_KEY

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

### Why No `.env` in Git?

`.env` is listed in `.gitignore`. The pipeline uses GitHub Secrets exclusively. The `.env.example` file provides a safe template with no real values.

---

## 9. Getting Started (Local)

### Prerequisites

- Docker Desktop (or Docker Engine + Compose plugin)
- Python 3.12+ (for running tests locally)
- Git

### Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/your-org/singapore-museum-devsecops.git
cd singapore-museum-devsecops

# 2. Create your local .env file
cp .env.example .env

# 3. Edit .env and set a SECRET_KEY
#    Generate one: python -c "import secrets; print(secrets.token_hex(32))"
nano .env

# 4. Start the application
docker compose up --build

# 5. Open in browser
#    http://localhost        (via Nginx)
#    http://localhost:5000   (Flask direct)
```

### Local Python Development (without Docker)

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate      # Windows: venv\Scripts\activate

# Install dependencies
pip install -r app/requirements.txt
pip install pytest pytest-cov flake8 bandit pip-audit

# Run the app
export SECRET_KEY=$(python -c "import secrets; print(secrets.token_hex(32))")
export FLASK_ENV=development
cd app && python app.py
```

---

## 10. Running Tests

```bash
# Activate virtual environment first
source venv/bin/activate

# Run all tests
pytest tests/ -v

# Run with coverage report
pytest tests/ -v --cov=app --cov-report=term-missing

# Run linter
flake8 app/ tests/ --max-line-length=100

# Run dependency audit
pip-audit -r app/requirements.txt

# Run SAST scan
bandit -r app/ -f screen
```

### Expected Test Output

```
tests/test_app.py::TestHealth::test_health_returns_200         PASSED
tests/test_app.py::TestHealth::test_health_json_structure      PASSED
tests/test_app.py::TestHealth::test_health_service_name        PASSED
tests/test_app.py::TestExhibits::test_exhibits_list            PASSED
tests/test_app.py::TestExhibits::test_exhibits_has_items       PASSED
tests/test_app.py::TestExhibits::test_exhibit_fields           PASSED
tests/test_app.py::TestExhibits::test_single_exhibit           PASSED
tests/test_app.py::TestExhibits::test_exhibit_not_found        PASSED
tests/test_app.py::TestEvents::test_events_list                PASSED
tests/test_app.py::TestEvents::test_events_has_items           PASSED
tests/test_app.py::TestTickets::test_booking_success           PASSED
tests/test_app.py::TestTickets::test_booking_missing_fields    PASSED
tests/test_app.py::TestTickets::test_booking_invalid_quantity  PASSED
tests/test_app.py::TestTickets::test_booking_no_json_body      PASSED
tests/test_app.py::TestTickets::test_booking_zero_quantity     PASSED
tests/test_app.py::TestSecurityHeaders::test_csp_header_present PASSED
tests/test_app.py::TestSecurityHeaders::test_404_returns_json  PASSED

========== 17 passed in 0.84s ==========
```

---

## 11. Docker Compose Usage

### Development

```bash
# Start all services
docker compose up --build

# Start in background
docker compose up -d --build

# View logs
docker compose logs -f

# Stop services
docker compose down
```

### Production

```bash
# Uses docker-compose.prod.yml overrides (production FLASK_ENV, resource limits)
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Check health
curl http://localhost/health
```

### Service Ports

| Service | Port | Description |
|---------|------|-------------|
| Nginx | `80` | Main entry point (use this) |
| Flask | `5000` | Direct Flask access (dev only) |

---

## 12. GitHub Repository Setup

### Step 1 — Create Repository

1. Go to [github.com](https://github.com) → **New Repository**
2. Name: `singapore-museum-devsecops`
3. Set to **Public**
4. Do **not** initialise with README (we have one)

### Step 2 — Push Code

```bash
git init
git add .
git commit -m "feat: initial DevSecOps project setup"
git branch -M main
git remote add origin https://github.com/YOUR_ORG/singapore-museum-devsecops.git
git push -u origin main

# Create and push dev and staging branches
git checkout -b staging && git push origin staging
git checkout -b dev && git push origin dev
```

### Step 3 — Add Collaborators

Go to **Settings → Collaborators** → Add each team member.

### Step 4 — Create GitHub Environments

Go to **Settings → Environments**:

1. Create environment: `staging`
   - Add secret: `STAGING_SECRET_KEY`
   - Add secret: `STAGING_REGISTRY_TOKEN`

2. Create environment: `production`
   - ✅ Enable **Required reviewers** (add tech lead)
   - ✅ Enable **Wait timer** (5 minutes recommended)
   - Add secret: `PROD_SECRET_KEY`
   - Add secret: `PROD_REGISTRY_TOKEN`

---

## 13. Branch Protection Rules

Configure at: **Settings → Branches → Add branch protection rule**

### `main` (Production)

```
Branch name pattern: main

✅ Require a pull request before merging
  ✅ Require approvals: 2
  ✅ Dismiss stale pull request approvals
✅ Require status checks to pass before merging
  Required checks:
  - CI — Dev Branch / lint
  - CI — Dev Branch / dependency-scan
  - CI — Dev Branch / sast
  - CI — Dev Branch / unit-tests
✅ Require branches to be up to date before merging
✅ Restrict who can push to matching branches
  → Add only: Tech Lead role
✅ Do not allow bypassing the above settings
```

### `staging`

```
Branch name pattern: staging

✅ Require a pull request before merging
  ✅ Require approvals: 1
✅ Require status checks to pass before merging
  Required checks: (same as main)
✅ Restrict who can push: Tech Lead + Senior Devs
```

### `dev`

```
Branch name pattern: dev

✅ Require a pull request before merging
  ✅ Require approvals: 1
✅ Require status checks to pass before merging
  Required checks:
  - CI — Dev Branch / lint
  - CI — Dev Branch / unit-tests
```

> **Note:** Per the project assumptions, `dev` is accessible to all developers but `staging` and `production` are not.

---

## 14. Environment Credentials Separation

This is a key DevSecOps requirement. The table below shows how each environment uses entirely different credentials:

| Credential | Development | Staging | Production |
|------------|-------------|---------|------------|
| `SECRET_KEY` | Local `.env` only | `STAGING_SECRET_KEY` | `PROD_SECRET_KEY` |
| Registry Token | Not used | `STAGING_REGISTRY_TOKEN` | `PROD_REGISTRY_TOKEN` |
| Image Tag | `dev-<sha>` | `staging-<sha>` | `<sha>` + `latest` |
| Trivy Severity | Not run | CRITICAL, HIGH | CRITICAL, HIGH, MEDIUM |
| Manual Approval | No | No | **Yes** |

---

## 15. Troubleshooting

### App container won't start

```bash
# Check logs
docker compose logs museum-app

# Most common cause: missing SECRET_KEY in .env
# Fix: ensure .env exists with SECRET_KEY set
cat .env
```

### Port 80 already in use

```bash
# Find what's using port 80
sudo lsof -i :80

# Change nginx port in docker-compose.yml:
ports:
  - "8080:80"    # use 8080 instead
```

### Trivy scan fails in CI

The image has a known CVE — check the SARIF report uploaded to GitHub Security tab. Options:
1. Update the base image in `Dockerfile` to a patched version
2. Update the offending dependency in `requirements.txt`

### bandit reports a false positive

Add a `# nosec B<id>` comment with justification:
```python
subprocess.run(cmd, shell=False)  # nosec B603 – shell=False, input is sanitised
```

### pip-audit finds a vulnerability

```bash
# See what's vulnerable
pip-audit -r app/requirements.txt

# Update the package
pip install --upgrade <package>
pip freeze | grep <package> >> app/requirements.txt
```

---

## 16. Team

| Role | Responsibility |
|------|----------------|
| DevSecOps Lead | Pipeline architecture, secrets management, branch protection |
| Developer 1 | Flask application, API endpoints, unit tests |
| Developer 2 | Docker, Nginx, docker-compose configuration |
| Developer 3 | GitHub Actions workflows, security scanning integration |

---

## References

- [Flask Documentation](https://flask.palletsprojects.com/)
- [pip-audit](https://pypi.org/project/pip-audit/)
- [Bandit SAST](https://bandit.readthedocs.io/)
- [Trivy Container Scanner](https://aquasecurity.github.io/trivy/)
- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Flask-Talisman Security Headers](https://github.com/GoogleCloudPlatform/flask-talisman)

---

*Singapore Heritage Museum DevSecOps Capstone — Built with 🦁 in Singapore*
