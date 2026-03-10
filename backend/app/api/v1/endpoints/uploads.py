from uuid import UUID

from fastapi import APIRouter, File, UploadFile

from app.api.deps import CurrentUser
from app.services.storage import upload_bytes

router = APIRouter(prefix="/uploads", tags=["uploads"])


@router.post("/image", response_model=dict)
async def upload_image(
    file: UploadFile = File(...),
    current_user: CurrentUser,
) -> dict:
    data = await file.read()
    object_name = f"uploads/{current_user.id}/{file.filename}"
    url = upload_bytes(object_name, data, file.content_type or "application/octet-stream")
    return {"url": url}
