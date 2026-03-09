# Deployment

## Render

1. Create PostgreSQL and Redis services.
2. Create backend web service from `backend/`.
3. Create Celery worker service from `backend/`.
4. Create admin web service from `admin/`.
5. Set secrets through Render dashboard env vars.

### Current workspace provisioning status (2026-03-10)

- Postgres instance created: `zests-postgres` (`dpg-d6nknqk50q8c738j8l2g-a`)
- Key Value instance created: `zests-cache` (`red-d6nknqchg0os73c5tq80`)
- Remaining blocker: backend/worker web services require a Git repository URL connected to Render.

## Mobile release

### Android

```bash
cd mobile
flutter build appbundle --release
```

Output: `mobile/build/app/outputs/bundle/release/app-release.aab`

### iOS

```bash
cd mobile
flutter build ipa --release
```

Output: `mobile/build/ios/ipa/*.ipa`
