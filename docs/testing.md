# Test Plan

## Backend

- Auth token exchange (`/auth/token`) with valid/invalid Firebase token.
- Users CRUD for profile and kid sub-profiles.
- Event CRUD and publish/cancel notifications.
- Referral install/view points increment.
- Support issue submission.

## Mobile

- Splash -> onboarding -> login flow.
- Existing Firebase session skips login and loads cached profile.
- Google and phone login paths.
- Terms and Conditions link launch.
- Event map link open.
- Event share link copy.

## Admin

- Dashboard navigation.
- Events and user management pages load.
- Static content forms for Terms/About.

## CI

- GitHub Actions for backend/mobile/admin.
- Jenkins pipeline for future on-demand regression checks.
