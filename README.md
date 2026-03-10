# ZestS - Production-Grade Sports Event Management Platform

ZestS is a comprehensive platform built to simplify the management of sports events, starting with skating. It features a cross-platform mobile app, a robust backend, and an admin dashboard.

## System Architecture

The project is structured as a monorepo with three core components:

1. **Mobile Application (`/mobile`)**: A Flutter app (iOS & Android) using Riverpod for state management, Firebase Auth (Google/Phone OOB), and a beautiful UI with skeleton loaders and micro-animations.
2. **Backend API (`/backend`)**: A highly scalable Python FastAPI application backed by PostgreSQL, using SQLModel, Redis for caching, Celery for task queues, and Firebase Admin for auth validation and FCM push notifications.
3. **Web Admin Dashboard (`/admin`)**: A Next.js web interface for organizers and administrators to manage events, users, banners, sponsors, and application configuration.

## Features Built

- **Authentication Flow**: Native splash -> PageView Onboarding -> Google/Phone login -> FastAPI secure token exchange.
- **Role-Based Access**: Specialized profiles and views for Parents (with Kid sub-profiles), Skaters, Trainers, Organizers, and Admins.
- **Event Management**: Complete CRUD, categorization (age groups, distances, skate types), event publish/cancel notifications via Firebase Cloud Messaging.
- **Registrations & Results**: Frictionless registration flow for parents and direct participants, including post-event leaderboard results and points caching.
- **Growth & Marketing**: Referral tracking for app installs and event views with point attribution.
- **Content Management**: Global dynamic banners, sponsor listings, and static app pages.
- **Security & Reliability**: Comprehensive role validation middleware, environment-variable configuration, and global API exception handling.

## Local Setup & Development

### Prerequisites
- Docker & Docker Compose
- Python 3.12+
- Flutter SDK 3.11+
- Node.js 20+

### 1. Start Infrastructure Services

```bash
docker compose up -d postgres redis meilisearch
```

### 2. Run the Backend

```bash
cd backend
python -m venv .venv

# On Windows:
.venv\Scripts\activate
# On macOS/Linux:
# source .venv/bin/activate

pip install -r requirements.txt
alembic upgrade head
```

To populate the database with comprehensive dummy data (parents, kids, trainers, events, banners):
```bash
python scripts/seed_dummy_data.py
```

Start the FastAPI server:
```bash
uvicorn app.main:app --reload
```
API Documentation will be available at: http://localhost:8000/api/v1/docs

### 3. Run Mobile App

```bash
cd mobile
flutter pub get
flutter run
```

### 4. Run Admin Panel

```bash
cd admin
npm install
npm run dev
```

## Testing & CI/CD

Continuous Integration pipelines are defined in `.github/workflows/` utilizing GitHub Actions for all three components.

To run tests locally:
```bash
# Backend unit & integration tests
cd backend
pip install pytest httpx
pytest tests/ -v

# E2E API Smoke test (runs against a live server)
python scripts/smoke_test.py http://localhost:8000

# Mobile widget tests and static analysis
cd mobile
flutter analyze
flutter test
```

## Production Deployment

### Building Mobile Artifacts
```bash
cd mobile
flutter build appbundle --release  # For Google Play Console
flutter build ipa --release        # For Apple App Store
```

### Render Infrastructure Updates
Changes merged to the `main` branch are automatically deployed via Render triggers connected to the GitHub repository:
- **Web Service** (`zests-backend`, region: Singapore) automatically spins up Python using `uvicorn main:app`
- **PostgreSQL Database** (`zests-db`, region: Singapore)
- **Redis Instance** (`zests-redis`, region: Singapore)
- **Web Service** (`zests-admin`, region: Singapore) running Next.js

See `infra/render.yaml` for complete Infrastructure as Code configuration.
