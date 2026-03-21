# ZestS — Render Deployment & Backup Guide

## Architecture

| Service              | Type   | Root Dir   | Runtime |
|----------------------|--------|------------|---------|
| `zests-backend`      | Web    | `backend/` | Python 3.12 |
| `zests-admin`        | Web    | `admin/`   | Node.js |
| `zests-celery-worker`| Worker | `backend/` | Python 3.12 |
| PostgreSQL Database  | DB     | —          | Render Managed |

---

## Environment Variables (Backend)

Set these in Render Dashboard → **zests-backend** → **Environment**:

| Variable | Required | Example |
|----------|----------|---------|
| `DATABASE_URL` | ✅ | `postgresql+psycopg://user:pass@host:5432/zests` |
| `REDIS_URL` | ✅ | `redis://red-xxx:6379` |
| `FIREBASE_PROJECT_ID` | ✅ | `zests-xxxxx` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | ✅ | `{"type":"service_account",...}` |
| `GCP_STORAGE_BUCKET` | ✅ | `zests-uploads` |
| `GCP_STORAGE_CREDENTIALS_JSON` | ✅ | `{"type":"service_account",...}` |
| `APP_ENV` | | `production` |
| `AUTH_ENABLED` | | `true` |
| `ADMIN_EMAILS` | | `admin@example.com` |
| `MAX_KIDS_PER_PARENT` | | `3` |

> **IMPORTANT:** `DATABASE_URL`, `REDIS_URL`, and the JSON credentials are sensitive.
> Never commit them to Git. Render stores them encrypted.

---

## Build & Start Commands

### Backend (`zests-backend`)
- **Build:** `pip install -r requirements.txt`
- **Start:** `uvicorn app.main:app --host 0.0.0.0 --port $PORT`

### Admin Panel (`zests-admin`)
- **Build:** `npm ci && npm run build`
- **Start:** `npm run start`

### Celery Worker (`zests-celery-worker`)
- **Build:** `pip install -r requirements.txt`
- **Start:** `celery -A app.workers.celery_app.celery_app worker --loglevel=INFO`

---

## Backup Procedures

### 1. Export Database (Tables + Schema)

```powershell
# Set the Render DATABASE_URL (from Render Dashboard → Environment)
$env:DATABASE_URL = "postgresql+psycopg://user:pass@host:5432/zests"

# Run the backup
python scripts/backup_render_db.py
```

This creates `infra/backup/` with:
- `tables/*.json` — every row from every table
- `schema.sql` — full CREATE TABLE DDL
- `metadata.json` — timestamp and row counts

### 2. Export Environment Variables

Go to **Render Dashboard → zests-backend → Environment** and screenshot or copy
all key/value pairs into a secure location (e.g., a password manager).

---

## Restore / Redeploy Procedures

### Fresh Render Deployment

1. **Create Services on Render:**
   - Go to https://dashboard.render.com
   - Click **New** → **Blueprint** → connect your GitHub repo
   - Point it to `infra/render.yaml` (or manually create each service)

2. **Add Environment Variables:**
   - For `zests-backend`, add all variables from the table above
   - Connect a new Render PostgreSQL database and copy its Internal URL to `DATABASE_URL`

3. **Deploy:**
   - Push to `main` branch or click **Manual Deploy** → **Deploy latest commit**
   - The backend will auto-create all tables on first boot via `create_db_and_tables()`

4. **Restore Data (Optional):**
   ```powershell
   $env:DATABASE_URL = "postgresql+psycopg://user:pass@new-host:5432/zests"
   python scripts/restore_render_db.py
   ```
   Use `--drop-first` to clear existing data before restoring:
   ```powershell
   python scripts/restore_render_db.py --drop-first
   ```

### Redeploy Existing Service

1. Push code to `main` branch → Render auto-deploys
2. Or go to **Render Dashboard → zests-backend → Manual Deploy**
3. Monitor logs for startup messages and schema patches

---

## Database Tables Reference

| Table | Description |
|-------|-------------|
| `users` | All user accounts (parents, kids, trainers, organizers, admins, skaters) |
| `parent_profiles` | Extra fields for parent users |
| `trainer_profiles` | Extra fields for trainer users |
| `organizer_profiles` | Extra fields for organizer users |
| `skater_profiles` | Extra fields for skater users |
| `events` | Skating events |
| `event_categories` | Categories within events |
| `event_registrations` | User registrations for events |
| `event_results` | Competition results |
| `payments` | Payment records for event registrations |
| `referrals` | Referral tracking between users |
| `banners` | Home screen promotional banners |
| `sponsors` | Event sponsors |
| `static_pages` | CMS pages (about, terms, privacy, etc.) |
| `support_issues` | User support tickets |
| `device_tokens` | FCM push notification tokens |
| `notifications` | In-app notification records |
| `tip_of_day` | Daily tips shown on home screen |
| `audit_logs` | Admin action audit trail |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `column X does not exist` | The startup patcher in `db/base.py` handles known missing columns. For new ones, add a patch there. |
| `invalid input value for enum` | Enum columns were converted to VARCHAR. Ensure role values are lowercase strings. |
| Build fails on Render | Check `requirements.txt` for version conflicts. Ensure `rootDir: backend` is set. |
| Deploy doesn't pick up new commits | Go to Render Dashboard → **Manual Deploy** → **Clear build cache & deploy** |
| 500 on DELETE user | The cascade handler in `admin.py` covers all FK tables. Check Render logs for the specific constraint. |
