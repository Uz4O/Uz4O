from secrets import compare_digest

from fastapi import APIRouter, Header, HTTPException, Request


router = APIRouter(prefix="/v1/ops", tags=["ops"])


@router.get("/usage")
def usage_metrics(
    request: Request,
    x_ops_token: str = Header(default=""),
) -> dict:
    configured_token = request.app.state.settings.ops_token
    if not configured_token:
        raise HTTPException(status_code=404, detail="Not found")
    if not x_ops_token or not compare_digest(x_ops_token, configured_token):
        raise HTTPException(status_code=401, detail="Invalid ops token")

    return {
        "high_cost": request.app.state.high_cost_usage_metrics.snapshot(),
    }
