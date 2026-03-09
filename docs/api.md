# API Contract Notes

- OpenAPI docs URL: `/api/v1/docs`
- Health endpoint: `/healthz`
- Auth exchange: `POST /api/v1/auth/token`
- Current profile: `GET /api/v1/users/me`
- Add kid profile: `POST /api/v1/users/me/kids`
- Upcoming events: `GET /api/v1/events/upcoming`
- Anonymous event preview: `GET /api/v1/events/upcoming/anonymous`
- Event publish/cancel: `POST /api/v1/events/{event_id}/status`
- Terms page: `GET /api/v1/pages/terms-and-conditions`
