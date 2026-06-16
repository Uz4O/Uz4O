import base64
import hashlib
import hmac
import json
from datetime import datetime, timedelta, timezone
from typing import Annotated, Dict, List, Literal, Optional
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.auth.dependencies import get_app_settings, get_current_account
from app.auth.models import Account
from app.auth.repository import list_accounts_by_ids
from app.community.models import CommunityComment, CommunityPost
from app.core.config import Settings
from app.core.rate_limit import community_write_rate_limit
from app.community.repository import (
    create_comment,
    create_post,
    get_post,
    list_comments,
    list_feed_posts,
    set_reaction,
)
from app.db import get_session


BLOCKED_CONTENT_KEYWORDS = ("加微信", "返现", "广告推广", "博彩", "贷款")
ALLOWED_IMAGE_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
IMAGE_EXTENSIONS_BY_CONTENT_TYPE = {
    "image/jpeg": {".jpg", ".jpeg"},
    "image/png": {".png"},
    "image/webp": {".webp"},
}
CommunityTag = Annotated[str, Field(min_length=1, max_length=32)]
CommunityPart = Annotated[str, Field(min_length=1, max_length=160)]


class CommunityAuthorResponse(BaseModel):
    name: str
    subtitle: str
    avatar_initial: str


class CommunityStatsResponse(BaseModel):
    likes: int
    comments: int
    saves: int


class CommunityPostRequest(BaseModel):
    summary: str = Field(min_length=4, max_length=160)
    body: str = Field(min_length=4, max_length=5000)
    tags: List[CommunityTag] = Field(default_factory=list, max_length=12)
    parts: List[CommunityPart] = Field(default_factory=list, max_length=40)
    image_asset: Optional[str] = Field(default=None, max_length=500)


class CommunityPostResponse(BaseModel):
    id: str
    author: CommunityAuthorResponse
    summary: str
    body: str
    created_at: datetime
    tags: List[str]
    parts: List[str]
    stats: CommunityStatsResponse
    is_pinned: bool
    image_asset: Optional[str]
    status: str


class CommunityFeedResponse(BaseModel):
    posts: List[CommunityPostResponse]


class CommunityCommentRequest(BaseModel):
    body: str = Field(min_length=2, max_length=2000)


class CommunityCommentResponse(BaseModel):
    id: str
    author: CommunityAuthorResponse
    body: str
    status: str
    created_at: datetime


class CommunityPostDetailResponse(BaseModel):
    post: CommunityPostResponse
    comments: List[CommunityCommentResponse]


class CommunityReactionRequest(BaseModel):
    type: Literal["like", "save"]
    active: bool = True


class CommunityReactionResponse(BaseModel):
    post_id: str
    stats: CommunityStatsResponse


class CommunityUploadRequest(BaseModel):
    file_name: str = Field(min_length=1, max_length=160)
    content_type: str = Field(min_length=1, max_length=80)
    size_bytes: int = Field(gt=0)


class CommunityUploadResponse(BaseModel):
    upload_url: str
    asset_key: str
    headers: Dict[str, str]
    form_fields: Dict[str, str]


router = APIRouter(prefix="/v1/community", tags=["community"])


@router.get("/feed", response_model=CommunityFeedResponse)
def community_feed(
    topic: Optional[str] = None,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    session: Session = Depends(get_session),
) -> CommunityFeedResponse:
    posts = list_feed_posts(session, topic, limit=limit, offset=offset)
    authors = _accounts_by_id(session, [post.author_id for post in posts])
    return CommunityFeedResponse(
        posts=[_post_response(post, authors.get(post.author_id)) for post in posts]
    )


@router.get("/posts/{post_id}", response_model=CommunityPostDetailResponse)
def community_post_detail(
    post_id: str,
    comments_limit: int = Query(default=50, ge=1, le=100),
    comments_offset: int = Query(default=0, ge=0),
    session: Session = Depends(get_session),
) -> CommunityPostDetailResponse:
    post = _published_or_404(session, post_id)
    comments = list_comments(session, post.id, limit=comments_limit, offset=comments_offset)
    authors = _accounts_by_id(
        session,
        [post.author_id] + [comment.author_id for comment in comments],
    )
    return CommunityPostDetailResponse(
        post=_post_response(post, authors.get(post.author_id)),
        comments=[
            _comment_response(comment, authors.get(comment.author_id))
            for comment in comments
        ],
    )


@router.post("/posts", response_model=CommunityPostResponse)
def write_community_post(
    http_request: Request,
    request: CommunityPostRequest,
    account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> CommunityPostResponse:
    community_write_rate_limit(http_request, account)
    if request.image_asset:
        _validate_image_asset(request.image_asset, account, http_request.app.state.settings)
    status = _moderation_status(" ".join([request.summary, request.body, " ".join(request.tags)]))
    post = create_post(
        session,
        author_id=account.id,
        summary=request.summary,
        body=request.body,
        tags=request.tags,
        parts=request.parts,
        image_asset=request.image_asset,
        status=status,
    )
    return _post_response(post, account)


@router.post("/posts/{post_id}/comments", response_model=CommunityCommentResponse)
def write_community_comment(
    http_request: Request,
    post_id: str,
    request: CommunityCommentRequest,
    account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> CommunityCommentResponse:
    community_write_rate_limit(http_request, account)
    post = _published_or_404(session, post_id)
    status = _moderation_status(request.body)
    comment = create_comment(session, post=post, author_id=account.id, body=request.body, status=status)
    return _comment_response(comment, account)


@router.post("/posts/{post_id}/reactions", response_model=CommunityReactionResponse)
def write_community_reaction(
    http_request: Request,
    post_id: str,
    request: CommunityReactionRequest,
    account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> CommunityReactionResponse:
    community_write_rate_limit(http_request, account)
    post = _published_or_404(session, post_id)
    post = set_reaction(session, post, account_id=account.id, reaction_type=request.type, active=request.active)
    return CommunityReactionResponse(post_id=post.id, stats=_stats_response(post))


@router.post("/upload", response_model=CommunityUploadResponse)
def create_community_upload(
    request: CommunityUploadRequest,
    account: Account = Depends(get_current_account),
    settings: Settings = Depends(get_app_settings),
) -> CommunityUploadResponse:
    if request.content_type not in ALLOWED_IMAGE_CONTENT_TYPES:
        raise HTTPException(status_code=422, detail="Unsupported community image type")
    if not _image_extension_matches_content_type(request.file_name, request.content_type):
        raise HTTPException(status_code=422, detail="Community image extension does not match content type")
    if request.size_bytes > settings.community_image_max_bytes:
        raise HTTPException(status_code=413, detail="Community image is too large")
    if not settings.community_image_upload_configured:
        raise HTTPException(status_code=503, detail="Community image upload is not configured")

    return _oss_upload_signature(request, account, settings)


def _published_or_404(session: Session, post_id: str) -> CommunityPost:
    post = get_post(session, post_id)
    if post is None or post.status != "published":
        raise HTTPException(status_code=404, detail="Community post not found")
    return post


def _post_response(post: CommunityPost, account: Optional[Account] = None) -> CommunityPostResponse:
    return CommunityPostResponse(
        id=post.id,
        author=_author_response(account),
        summary=post.summary,
        body=post.body,
        created_at=post.created_at,
        tags=list(post.tags or []),
        parts=list(post.parts or []),
        stats=_stats_response(post),
        is_pinned=post.is_pinned,
        image_asset=post.image_asset,
        status=post.status,
    )


def _comment_response(comment: CommunityComment, account: Optional[Account] = None) -> CommunityCommentResponse:
    return CommunityCommentResponse(
        id=comment.id,
        author=_author_response(account),
        body=comment.body,
        status=comment.status,
        created_at=comment.created_at,
    )


def _author_response(account: Optional[Account]) -> CommunityAuthorResponse:
    name = _display_name(account)
    return CommunityAuthorResponse(name=name, subtitle="", avatar_initial=name[:1] or "用")


def _display_name(account: Optional[Account]) -> str:
    if account is None:
        return "用户"
    if account.nickname:
        return account.nickname
    if account.phone:
        return f"用户{account.phone[-4:]}"
    return "用户"


def _accounts_by_id(session: Session, account_ids: List[str]) -> Dict[str, Account]:
    return {account.id: account for account in list_accounts_by_ids(session, account_ids)}


def _stats_response(post: CommunityPost) -> CommunityStatsResponse:
    return CommunityStatsResponse(
        likes=post.like_count,
        comments=post.comment_count,
        saves=post.save_count,
    )


def _moderation_status(text: str) -> str:
    normalized_text = _normalize_for_moderation(text)
    blocked = any(
        keyword in text or _normalize_for_moderation(keyword) in normalized_text
        for keyword in BLOCKED_CONTENT_KEYWORDS
    )
    return "pending_review" if blocked else "published"


def _normalize_for_moderation(text: str) -> str:
    return "".join(character.lower() for character in text if character.isalnum())


def _image_extension_matches_content_type(file_name: str, content_type: str) -> bool:
    allowed_extensions = IMAGE_EXTENSIONS_BY_CONTENT_TYPE[content_type]
    normalized_name = file_name.lower()
    return any(normalized_name.endswith(extension) for extension in allowed_extensions)


def _validate_image_asset(image_asset: str, account: Account, settings: Settings) -> None:
    if not settings.community_image_upload_configured:
        raise HTTPException(status_code=400, detail="Community image upload is not configured")
    if not image_asset.startswith(f"community/{account.id}/"):
        raise HTTPException(status_code=400, detail="Invalid community image asset")
    if "://" in image_asset or ".." in image_asset:
        raise HTTPException(status_code=400, detail="Invalid community image asset")
    if not any(image_asset.lower().endswith(extension) for extensions in IMAGE_EXTENSIONS_BY_CONTENT_TYPE.values() for extension in extensions):
        raise HTTPException(status_code=400, detail="Invalid community image asset")


def _oss_upload_signature(
    request: CommunityUploadRequest,
    account: Account,
    settings: Settings,
) -> CommunityUploadResponse:
    now = datetime.now(timezone.utc)
    short_date = now.strftime("%Y%m%d")
    oss_date = now.strftime("%Y%m%dT%H%M%S.000Z")
    expiration = (now + timedelta(minutes=10)).strftime("%Y-%m-%dT%H:%M:%S.000Z")
    extension = _extension_for_file_name(request.file_name, request.content_type)
    asset_key = f"community/{account.id}/{uuid4().hex}{extension}"
    credential = (
        f"{settings.community_image_oss_access_key_id}/{short_date}/"
        f"{settings.community_image_oss_region}/oss/aliyun_v4_request"
    )
    policy_document = {
        "expiration": expiration,
        "conditions": [
            {"bucket": settings.community_image_oss_bucket},
            {"key": asset_key},
            {"x-oss-credential": credential},
            {"x-oss-date": oss_date},
            {"x-oss-signature-version": "OSS4-HMAC-SHA256"},
            ["eq", "$Content-Type", request.content_type],
            ["content-length-range", 1, settings.community_image_max_bytes],
        ],
    }
    policy = base64.b64encode(
        json.dumps(policy_document, separators=(",", ":")).encode("utf-8")
    ).decode("ascii")
    form_fields = {
        "key": asset_key,
        "policy": policy,
        "x-oss-credential": credential,
        "x-oss-date": oss_date,
        "x-oss-signature-version": "OSS4-HMAC-SHA256",
        "x-oss-signature": _oss_v4_signature(
            policy,
            settings.community_image_oss_access_key_secret or "",
            short_date,
            settings.community_image_oss_region or "",
        ),
        "success_action_status": "200",
    }
    if settings.community_image_oss_security_token:
        form_fields["x-oss-security-token"] = settings.community_image_oss_security_token
    return CommunityUploadResponse(
        upload_url=settings.community_image_oss_host or "",
        asset_key=asset_key,
        headers={"Content-Type": request.content_type},
        form_fields=form_fields,
    )


def _extension_for_file_name(file_name: str, content_type: str) -> str:
    normalized_name = file_name.lower()
    for extension in IMAGE_EXTENSIONS_BY_CONTENT_TYPE[content_type]:
        if normalized_name.endswith(extension):
            return extension
    return next(iter(IMAGE_EXTENSIONS_BY_CONTENT_TYPE[content_type]))


def _oss_v4_signature(policy: str, secret: str, short_date: str, region: str) -> str:
    date_key = _hmac_sha256(("aliyun_v4" + secret).encode("utf-8"), short_date)
    region_key = _hmac_sha256(date_key, region)
    product_key = _hmac_sha256(region_key, "oss")
    signing_key = _hmac_sha256(product_key, "aliyun_v4_request")
    return hmac.new(signing_key, policy.encode("utf-8"), hashlib.sha256).hexdigest()


def _hmac_sha256(key: bytes, value: str) -> bytes:
    return hmac.new(key, value.encode("utf-8"), hashlib.sha256).digest()
