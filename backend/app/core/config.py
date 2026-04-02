from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", case_sensitive=False, extra="ignore")

    app_env: str = Field(default="dev", alias="APP_ENV")
    app_name: str = Field(default="ZestS API", alias="APP_NAME")
    api_v1_prefix: str = Field(default="/api/v1", alias="API_V1_PREFIX")

    database_url: str = Field(
        default="postgresql+psycopg://postgres:postgres@localhost:5432/zests",
        alias="DATABASE_URL",
    )
    redis_url: str = Field(default="redis://localhost:6379/0", alias="REDIS_URL")

    meilisearch_url: str = Field(default="http://localhost:7700", alias="MEILISEARCH_URL")
    meilisearch_master_key: str = Field(default="masterKey", alias="MEILISEARCH_MASTER_KEY")

    firebase_project_id: str = Field(default="", alias="FIREBASE_PROJECT_ID")
    firebase_service_account_json: str = Field(default="", alias="FIREBASE_SERVICE_ACCOUNT_JSON")

    gcp_storage_bucket: str = Field(default="", alias="GCP_STORAGE_BUCKET")
    gcp_storage_credentials_json: str = Field(default="", alias="GCP_STORAGE_CREDENTIALS_JSON")

    auth_enabled: bool = Field(default=True, alias="AUTH_ENABLED")
    payments_enabled: bool = Field(default=False, alias="PAYMENTS_ENABLED")
    phone_auth_enabled: bool = Field(default=True, alias="PHONE_AUTH_ENABLED")
    google_auth_enabled: bool = Field(default=True, alias="GOOGLE_AUTH_ENABLED")
    max_kids_per_parent: int = Field(default=3, alias="MAX_KIDS_PER_PARENT")
    admin_emails: str = Field(default="", alias="ADMIN_EMAILS")
    celery_enabled: bool = Field(default=False, alias="CELERY_ENABLED")
    reset_database: bool = Field(default=False, alias="RESET_DATABASE")


@lru_cache
def get_settings() -> Settings:
    return Settings()
