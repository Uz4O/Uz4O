from starlette.types import ASGIApp, Message, Receive, Scope, Send


SECURITY_HEADERS = {
    b"x-content-type-options": b"nosniff",
    b"x-frame-options": b"DENY",
    b"referrer-policy": b"no-referrer",
}
SENSITIVE_PATH_PREFIXES = (
    "/v1/auth",
    "/v1/profile",
    "/v1/builds",
    "/v1/ops",
)
SENSITIVE_CACHE_HEADERS = {
    b"cache-control": b"no-store",
    b"pragma": b"no-cache",
}


class SecurityHeadersMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        is_sensitive_path = any(
            scope.get("path", "").startswith(prefix)
            for prefix in SENSITIVE_PATH_PREFIXES
        )

        async def send_with_security_headers(message: Message) -> None:
            if message["type"] == "http.response.start":
                headers = list(message.get("headers", []))
                existing = {name.lower() for name, _ in headers}
                for name, value in SECURITY_HEADERS.items():
                    if name not in existing:
                        headers.append((name, value))
                if is_sensitive_path:
                    for name, value in SENSITIVE_CACHE_HEADERS.items():
                        if name not in existing:
                            headers.append((name, value))
                message["headers"] = headers
            await send(message)

        await self.app(scope, receive, send_with_security_headers)
