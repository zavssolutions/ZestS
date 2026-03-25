from typing import Iterable
import uuid

from firebase_admin import messaging
from sqlmodel import Session, select

from app.models.event import Event
from app.models.notification import DeviceToken, Notification
from app.services.firebase_auth import _init_firebase


def _send_fcm(tokens: Iterable[str], title: str, body: str, data: dict) -> None:
    tokens_list = [token for token in tokens if token]
    if not tokens_list:
        return
    _init_firebase()
    message = messaging.MulticastMessage(
        tokens=tokens_list,
        notification=messaging.Notification(title=title, body=body),
        data={k: str(v) for k, v in data.items()},
    )
    messaging.send_multicast(message)


def send_event_status(session: Session, event_id: str | uuid.UUID, status: str) -> None:
    from uuid import UUID
    if isinstance(event_id, str):
        event_id = UUID(event_id)
    event = session.get(Event, event_id)
    if event is None:
        return

    title = f"Event {status.capitalize()}"
    body = f"{event.title} has been {status}."
    data = {"event_id": str(event.id), "status": status}

    tokens = session.exec(select(DeviceToken)).all()
    token_values = [token.token for token in tokens]
    _send_fcm(token_values, title, body, data)

    for token in tokens:
        session.add(
            Notification(
                user_id=token.user_id,
                title=title,
                body=body,
                data_json=str(data),
            )
        )
    session.commit()
