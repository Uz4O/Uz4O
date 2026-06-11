from datetime import datetime, timezone
from pathlib import Path
import re
import time
from typing import Callable, Iterable, List, Optional
from urllib.parse import quote

from .pricing import HardwareTarget, RawProduct


CATEGORY_QUERY_SUFFIX = {
    "cpu": "处理器",
    "gpu": "显卡",
    "motherboard": "主板",
}


def parse_price(value: str) -> Optional[float]:
    match = re.search(r"(\d[\d,]*(?:\.\d+)?)", value or "")
    if not match:
        return None
    return float(match.group(1).replace(",", ""))


def scrape_jd_targets(
    targets: Iterable[HardwareTarget],
    profile_path: Path,
    delay_seconds: float = 5,
    channel: str = "msedge",
    pause_for_login: bool = True,
    after_target: Optional[Callable[[List[RawProduct]], None]] = None,
) -> List[RawProduct]:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError as error:
        raise RuntimeError(
            "Playwright is not installed. Run: python3 -m pip install -r requirements.txt"
        ) from error

    targets = list(targets)
    collected = []
    profile_path = Path(profile_path)
    profile_path.mkdir(parents=True, exist_ok=True)

    with sync_playwright() as playwright:
        context = playwright.chromium.launch_persistent_context(
            str(profile_path),
            channel=channel,
            headless=False,
            viewport={"width": 1380, "height": 900},
        )
        page = context.pages[0] if context.pages else context.new_page()
        if pause_for_login:
            page.goto("https://www.jd.com/", wait_until="domcontentloaded")
            _prompt("请在打开的浏览器中登录京东，完成后回到终端按回车继续。")

        try:
            for index, target in enumerate(targets, start=1):
                query = "{} {}".format(target.name, CATEGORY_QUERY_SUFFIX[target.category])
                print("[{}/{}] 正在采集 {}".format(index, len(targets), query))
                try:
                    products = _search_one(page, target, query)
                    collected.extend(products)
                except Exception as error:
                    print("  采集失败，将在复核报告中表现为无可信商品：{}".format(error))
                if after_target:
                    after_target(collected)
                if delay_seconds > 0:
                    time.sleep(delay_seconds)
        finally:
            context.close()
    return collected


def _search_one(page, target: HardwareTarget, query: str) -> List[RawProduct]:
    url = "https://search.jd.com/Search?keyword={}".format(quote(query))
    page.goto(url, wait_until="domcontentloaded", timeout=60000)
    page.wait_for_timeout(2500)
    page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
    page.wait_for_timeout(1800)

    cards = page.locator("#J_goodsList li.gl-item")
    if cards.count() == 0:
        _prompt("没有读取到商品。若页面要求登录或验证，请手动完成，然后按回车重试一次。")
        page.reload(wait_until="domcontentloaded", timeout=60000)
        page.wait_for_timeout(2500)
        page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
        page.wait_for_timeout(1800)

    rows = page.locator("#J_goodsList li.gl-item").evaluate_all(
        """cards => cards.map(card => {
            const link = card.querySelector('.p-name a');
            const title = card.querySelector('.p-name em')?.innerText || card.querySelector('.p-name')?.innerText || '';
            const price = card.querySelector('.p-price i')?.innerText || card.querySelector('.p-price')?.innerText || '';
            const shop = card.querySelector('.p-shop a')?.innerText || card.querySelector('.p-shop')?.innerText || '';
            return {
                sku: card.getAttribute('data-sku') || '',
                title,
                price,
                shop,
                url: link?.href || ''
            };
        })"""
    )
    captured_at = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
    products = []
    for row in rows:
        price = parse_price(row.get("price", ""))
        if not row.get("title") or price is None:
            continue
        products.append(
            RawProduct(
                target_id=target.id,
                category=target.category,
                query=query,
                sku=row.get("sku", ""),
                title=" ".join(row["title"].split()),
                price=price,
                shop=" ".join(row.get("shop", "").split()),
                url=row.get("url", ""),
                captured_at=captured_at,
            )
        )
    print("  读取到 {} 条原始商品".format(len(products)))
    return products


def _prompt(message: str) -> None:
    try:
        input("{}\n> ".format(message))
    except EOFError:
        print("当前终端无法等待输入，继续执行。")
