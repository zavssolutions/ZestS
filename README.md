# ZestS Monorepo

Production-oriented starter for ZestS mobile, backend, and admin.

## Repository Structure

- `mobile/` Flutter app (Riverpod, splash, onboarding, Firebase auth, caching)
- `backend/` FastAPI + SQLModel + PostgreSQL + Redis + Celery
- `admin/` Next.js admin (`/admin` base path)
- `infra/` deployment templates (`render.yaml`)
- `docs/` architecture, API, testing, deployment docs
- `scripts/` smoke test and dummy seed scripts

## Startup Flow Implemented (Mobile)

1. Native splash (`flutter_native_splash`)
2. Auth check (`FirebaseAuth.instance.currentUser`)
3. First-open onboarding PageView (3 slides)
4. Login screen with Google/Phone and Terms checkbox
5. Home with skeleton loaders, events, drawer, and animated nav icons

## Local Run

```bash
docker compose up -d postgres redis meilisearch
```

Backend:

```bash
cd backend
python -m venv .venv
. .venv/Scripts/Activate.ps1
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload
```

Mobile:

```bash
cd mobile
flutter pub get
flutter run
```

Admin:

```bash
cd admin
npm install
npm run dev
```

## Build Artifacts

Android AAB:

```bash
cd mobile
flutter build appbundle --release
```

iOS IPA:

```bash
cd mobile
flutter build ipa --release
```

## Security Notes

- Never commit `.jks`, `.p12`, Firebase service account JSON, or production DB URLs.
- Keep secrets in environment variables only.
- Backend write routes are role-restricted.
