from typing import Awaitable, Callable, MutableMapping, Optional

from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Message, Receive, Scope, Send


class RequestBodyTooLarge(Exception):
    pass


class RequestBodySizeLimitMiddleware:
    def __init__(self, app: ASGIApp, max_body_bytes: int) -> None:
        self.app = app
        self.max_body_bytes = max_body_bytes

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or self.max_body_bytes <= 0:
            await self.app(scope, receive, send)
            return

        content_length = _content_length(scope)
        if content_length is not None and content_length > self.max_body_bytes:
            await _request_too_large_response(scope, receive, send)
            return

        received_body_bytes = 0

        async def limited_receive() -> Message:
            nonlocal received_body_bytes

            message = await receive()
            if message["type"] != "http.request":
                return message

            received_body_bytes += len(message.get("body", b""))
            if received_body_bytes > self.max_body_bytes:
                raise RequestBodyTooLarge
            return message

        try:
            await self.app(scope, limited_receive, send)
        except RequestBodyTooLarge:
            await _request_too_large_response(scope, receive, send)


def _content_length(scope: Scope) -> Optional[int]:
    headers: MutableMapping[bytes, bytes] = dict(scope.get("headers", []))
    raw_content_length = headers.get(b"content-length")
    if raw_content_length is None:
        return None

    try:
        return int(raw_content_length)
    except ValueError:
        return None


async def _request_too_large_response(
    scope: Scope,
    receive: Callable[[], Awaitable[Message]],
    send: Send,
) -> None:
    response = JSONResponse(
        status_code=413,
        content={"detail": "Request body too large"},
    )
    await response(scope, receive, send)
