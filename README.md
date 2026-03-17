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
- **Unified Banner & Logo Strategy**: The ZestS Official Logo is now treated as a standard entry in the `banners` table. This simplifies the mobile frontend logic, as the ZestS logo is fetched, displayed, and shared using the same unified banner system as any other promotional content.
- **Deep Link Sharing**: Native mobile integration utilizing `app_links` to handle external URLs. Banners and Events can be shared externally; the links will smartly redirect active users natively routing into the app or redirect to the App Store for users who don't have the app installed.
- **Enhanced Banner Interaction**: Clicking a banner on the Home Screen opens a full-screen view. Tapping the full-screen banner triggers native sharing options, allowing users to share the banner image and its associated deep link.
- **Security & Reliability**: Comprehensive role validation middleware, environment-variable configuration, and global API exception handling.

## Infrastructure & Services

### Backend Deployment (Render)
The backend is a FastAPI application designed for high-performance and scalability. It is deployed on **Render** (using `infra/render.yaml`) within the `singapore` cluster to ensure low-latency access for users in Asia/India. The deployment includes:
- **FastAPI**: The core web service handling API requests.
- **PostgreSQL**: The primary relational database for persistent storage.
- **Redis**: Powering session management, caching, and as a Celery broker.
- **Celery Workers**: Handling asynchronous background tasks such as notification dispatching and search index synchronization.
- **Meilisearch**: Providing ultra-fast, typo-tolerant event search capabilities.

### Mobile Notifications (FCM)
The application utilizes **Firebase Cloud Messaging (FCM)** for cross-platform push notifications.
- **Service Side**: The FastAPI backend uses the `firebase-admin` SDK to securely send data and display notifications to specific device tokens.
- **Client Side**: The Flutter app uses `firebase_messaging` to receive notifications, register device tokens, and handle background/foreground messaging logic.
- **Features**: Automated notifications for event publishing, registration updates, and marketing announcements.

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

To populate the database with comprehensive dummy data (including the ZestS logo as a banner):
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

## Database Design

The detailed database schema and design rationale can be found in [db_design.md](file:///c%3A/Users/Siva%20Kumar%20Perumalla/.gemini/antigravity/scratch/ZestS-repo/db_design.md). Key tables include:
- **users**: Core user data and roles.
- **events**: Sports event details.
- **event_categories**: Registration categories (e.g., age groups).
- **event_registrations**: User event sign-ups.
- **banners**: Promotional content and logos.
- **sponsors**: Event sponsor information.

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
