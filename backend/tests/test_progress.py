from pathlib import Path

from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app
from app.progress import load_progress


def test_progress_file_tracks_the_backend_roadmap() -> None:
    progress = load_progress(Path("progress.json"))

    assert progress.project == "AI 装机助手后端"
    assert progress.estimated_completion == "仅后端可开发剩余项：约 0-0.5 天（待最终联调）"
    assert len(progress.phases) == 5
    assert progress.total_items == 85
    assert progress.completed_items == 78
    assert progress.completion_percentage == 92
    assert [item.title for item in progress.user_action_items] == [
        "硬件尺寸字段人工补充",
        "生产短信服务与登录密钥配置",
        "Sign in with Apple 登录配置",
        "生产推荐池与价格/模板数据发布",
        "DeepSeek API Key 与配置模板",
        "社区图片上传配置",
        "服务器 SSH 暴力破解防护",
    ]


def test_fastapi_scaffold_is_the_initial_completed_item() -> None:
    progress = load_progress(Path("progress.json"))

    scaffold = progress.phases[0].items[0]
    assert scaffold.title == "FastAPI 后端脚手架"
    assert scaffold.status == "completed"


def test_postgres_foundation_is_completed_before_seed_import_starts() -> None:
    progress = load_progress(Path("progress.json"))

    postgres = progress.phases[0].items[1]
    seed_import = progress.phases[0].items[2]

    assert postgres.title == "PostgreSQL 数据库地基"
    assert postgres.status == "completed"
    assert postgres.completed_at == "2026-06-13"
    assert seed_import.title == "硬件库种子导入"
    assert seed_import.status == "completed"
    assert seed_import.completed_at == "2026-06-13"


def test_progress_dashboard_renders_summary_and_phases() -> None:
    client = TestClient(
        create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))
    )

    response = client.get("/progress")

    assert response.status_code == 200
    assert "AI 装机助手后端" in response.text
    assert "92%" in response.text
    assert "预计完成时间" in response.text
    assert "仅后端可开发剩余项：约 0-0.5 天（待最终联调）" in response.text
    assert "需要你完成" in response.text
    assert "下面这些不是后端代码缺口" in response.text
    assert "硬件规格字段补全" in response.text
    assert "硬件尺寸字段人工补充" in response.text
    assert "短信验证码基础限流" in response.text
    assert "短信验证码旧码失效收口" in response.text
    assert "调试短信验证码稳定性修复" in response.text
    assert "短信登录格式校验收口" in response.text
    assert "生产短信未配置安全拒绝" in response.text
    assert "短信重复验证码线上 500 修复" in response.text
    assert "生产短信服务与登录密钥配置" in response.text
    assert "Sign in with Apple 登录配置" in response.text
    assert "Sign in with Apple 登录入口占位" in response.text
    assert "Sign in with Apple identity token 校验流程" in response.text
    assert "Bug 检查" in response.text
    assert "安全检查" in response.text
    assert "PostgreSQL 数据库地基" in response.text
    assert "FastAPI 后端脚手架" in response.text
    assert "AI 一键装机规则兜底" in response.text
    assert "AI 一键装机前端请求契约兼容" in response.text
    assert "生产推荐池与价格/模板数据发布" in response.text
    assert "推荐硬件池导入工具" in response.text
    assert "生产数据就绪检查工具" in response.text
    assert "生产数据就绪 API" in response.text
    assert "配置模板导入质量校验" in response.text
    assert "配置模板结构质量校验" in response.text
    assert "配置模板兼容性复校" in response.text
    assert "DeepSeek API Key 与配置模板" in response.text
    assert "配置排雷" in response.text
    assert "配置中心 CRUD" in response.text
    assert "升级建议" in response.text
    assert "游戏性能测试" in response.text
    assert "兼容性检查接口收口" in response.text
    assert "社区服务" in response.text
    assert "社区图片占位安全拦截" in response.text
    assert "社区图片上传签名入口占位" in response.text
    assert "社区敏感内容变体拦截" in response.text
    assert "社区标签与配件字段长度收口" in response.text
    assert "社区图片上传文件类型一致性校验" in response.text
    assert "社区图片 OSS 直传签名" in response.text
    assert "社区图片上传配置" in response.text
    assert "装机指南内容服务" in response.text
    assert "AI 接口基础限流" in response.text
    assert "社区写入基础限流" in response.text
    assert "Redis 分布式限流存储通道" in response.text
    assert "Redis 限流故障本机降级" in response.text
    assert "非法 Redis URL 限流降级" in response.text
    assert "数据库 Session Factory 复用" in response.text
    assert "安全配置体检" in response.text
    assert "生产关键配置体检扩展" in response.text
    assert "生产上线阻断项体检" in response.text
    assert "生产数据就绪健康阻断" in response.text
    assert "关键依赖 URL 格式体检" in response.text
    assert "登录密钥强度体检" in response.text
    assert "畸形登录 Token 安全拒绝" in response.text
    assert "超长 Bearer Token 提前拒绝" in response.text
    assert "CORS 跨域白名单配置" in response.text
    assert "危险 CORS 配置阻断" in response.text
    assert "生产 API 文档默认关闭" in response.text
    assert "基础安全响应头" in response.text
    assert "敏感接口禁止缓存" in response.text
    assert "高成本接口输入缓存" in response.text
    assert "配置排雷流式响应" in response.text
    assert "性能与升级流式响应" in response.text
    assert "社区作者展示修复" in response.text
    assert "社区作者查询优化" in response.text
    assert "配置中心保存体积限制" in response.text
    assert "Profile 同步输入边界收口" in response.text
    assert "全局请求体积限制" in response.text
    assert "高成本接口用量统计" in response.text
    assert "高成本接口估算成本统计" in response.text
    assert "真实 AI 成本与失败统计通道" in response.text
    assert "AI/规则接口输入边界收口" in response.text
    assert "配置生成偏好输入收口" in response.text
    assert "AI Provider 安全降级说明" in response.text
    assert "DeepSeek 受控 Provider 失败降级" in response.text
    assert "AI Provider URL 安全阻断" in response.text
    assert "硬件目录列表分页边界" in response.text
    assert "社区 Feed 与评论分页边界" in response.text
    assert "配置中心列表分页边界" in response.text
    assert "流式响应、降级与成本优化" in response.text
    assert "服务器 SSH 暴力破解防护" in response.text
    assert "完成于 2026-06-16" in response.text
    assert "Phase 4 · 打磨" in response.text


def test_root_redirects_to_progress_dashboard() -> None:
    client = TestClient(
        create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))
    )

    response = client.get("/", follow_redirects=False)

    assert response.status_code == 307
    assert response.headers["location"] == "/progress"
