from fastapi import APIRouter

from app.guide.service import GuideContentResponse, get_guide_content


router = APIRouter(prefix="/v1/guide", tags=["guide"])


@router.get("", response_model=GuideContentResponse, response_model_exclude_none=True)
def read_guide() -> GuideContentResponse:
    return get_guide_content()
