import json
from functools import lru_cache

from google.cloud import storage

from app.core.config import get_settings


@lru_cache
def get_storage_client() -> storage.Client:
    settings = get_settings()
    creds_raw = settings.gcp_storage_credentials_json.strip()

    if creds_raw:
        if creds_raw.startswith("{"):
            info = json.loads(creds_raw)
            return storage.Client.from_service_account_info(info)
        return storage.Client.from_service_account_json(creds_raw)

    return storage.Client()


def upload_bytes(object_name: str, data: bytes, content_type: str) -> str:
    settings = get_settings()
    bucket = get_storage_client().bucket(settings.gcp_storage_bucket)
    blob = bucket.blob(object_name)
    blob.upload_from_string(data, content_type=content_type)
    return blob.public_url
