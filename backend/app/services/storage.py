import json
import logging
from functools import lru_cache
from pathlib import Path

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


def _save_local(object_name: str, data: bytes) -> str:
    # Create a local 'uploads' directory
    upload_dir = Path("static/uploads")
    upload_dir.mkdir(parents=True, exist_ok=True)
    
    # Save file locally
    file_path = upload_dir / object_name.split("/")[-1]
    with open(file_path, "wb") as f:
        f.write(data)
    
    # Return a relative URL (assuming static files are served)
    return f"/static/uploads/{file_path.name}"


def upload_bytes(object_name: str, data: bytes, content_type: str) -> str:
    settings = get_settings()
    
    # Fallback for local development if GCP is not configured
    if not settings.gcp_storage_bucket or not settings.gcp_storage_credentials_json:
        return _save_local(object_name, data)

    try:
        bucket = get_storage_client().bucket(settings.gcp_storage_bucket)
        blob = bucket.blob(object_name)
        blob.upload_from_string(data, content_type=content_type)
        return blob.public_url
    except Exception as e:
        # If GCP fails, fallback to local as well to avoid blocking
        logging.warning("GCP Upload failed, falling back to local: %s", e)
        return _save_local(object_name, data)
