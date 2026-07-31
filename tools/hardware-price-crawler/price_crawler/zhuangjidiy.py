"""Fetch and import the public zhuangjidiy.com local parts catalog."""

from __future__ import annotations

import json
import math
import re
import time
import unicodedata
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple
from urllib.parse import urlencode
from urllib.request import Request, urlopen


DEFAULT_LIST_URL = "https://www.zhuangjidiy.com/data/diy/parts/local/list"
SOURCE = "zhuangjidiy.com"
TYPE_TO_CATEGORY = {
    "cpu": "cpu",
    "gpu": "gpu",
    "motherboard": "motherboard",
    "memory": "ram",
    "storage": "storage",
    "cooling": "cooler",
    "case": "case",
}


# The site leaves brand empty. Keep aliases here so categories in the app still
# have useful vendor groups instead of one giant "unknown" bucket.
BRAND_ALIASES: Sequence[Tuple[str, str]] = tuple(
    sorted(
        {
            "英特尔（Intel）": "Intel",
            "Intel英特尔": "Intel",
            "英伟达Tesla": "NVIDIA",
            "英伟达": "NVIDIA",
            "华为昇腾": "华为",
            "昂达（ONDA）": "昂达",
            "技嘉（GIGABYTE）": "技嘉",
            "蓝戟（GUNNIR）": "蓝戟",
            "华硕（ASUS）": "华硕",
            "美商海盗船": "海盗船",
            "宏碁掠夺者": "宏碁",
            "Intel": "Intel",
            "英特尔": "Intel",
            "至强": "Intel",
            "AMD": "AMD",
            "七彩虹": "七彩虹",
            "华硕": "华硕",
            "微星": "微星",
            "技嘉": "技嘉",
            "ROG": "华硕",
            "华擎": "华擎",
            "精粤": "精粤",
            "圣旗": "圣旗",
            "铭瑄": "铭瑄",
            "耕升": "耕升",
            "映众": "映众",
            "盈通": "盈通",
            "蓝宝石": "蓝宝石",
            "讯景": "讯景",
            "瀚铠": "瀚铠",
            "云轩": "云轩",
            "梅捷": "梅捷",
            "丽台": "丽台",
            "蓝戟": "蓝戟",
            "摩尔线程": "摩尔线程",
            "影驰": "影驰",
            "昂达": "昂达",
            "金百达": "金百达",
            "阿斯加特": "阿斯加特",
            "芝奇": "芝奇",
            "佰维": "佰维",
            "金士顿": "金士顿",
            "联想": "联想",
            "威刚": "威刚",
            "ThinkPlus": "ThinkPlus",
            "玖合": "玖合",
            "朗科": "朗科",
            "光威": "光威",
            "奔跑者": "奔跑者",
            "金邦": "金邦",
            "海力士": "海力士",
            "三星": "三星",
            "西部数据": "西部数据",
            "铠侠": "铠侠",
            "金胜维": "金胜维",
            "致态": "致态",
            "爱国者": "爱国者",
            "梵想": "梵想",
            "PNY": "PNY",
            "探路人": "探路人",
            "闪迪": "闪迪",
            "雷克沙": "雷克沙",
            "铨兴": "铨兴",
            "利民": "利民",
            "乔思伯": "乔思伯",
            "瓦尔基里": "瓦尔基里",
            "九州风神": "九州风神",
            "钛钽": "钛钽",
            "超频三": "超频三",
            "超频3": "超频三",
            "TCOMAS": "TCOMAS",
            "酷冷至尊": "酷冷至尊",
            "大水牛": "大水牛",
            "AOC": "AOC",
            "追风者": "追风者",
            "先马": "先马",
            "创氪星系": "创氪星系",
            "动力火车": "动力火车",
            "首席玩家": "首席玩家",
            "TRYX": "TRYX",
            "Bykski": "Bykski",
            "玩嘉": "玩嘉",
            "酷里奥": "酷里奥",
            "思民": "思民",
            "NVV": "NVV",
            "酷凛": "酷凛",
            "联力": "联力",
            "半岛铁盒": "半岛铁盒",
            "银昕": "银昕",
            "子意": "子意",
            "Tt": "Tt",
            "航嘉": "航嘉",
            "骨伽": "骨伽",
            "金河田": "金河田",
            "游戏帝国": "游戏帝国",
            "迎广": "迎广",
            "abee": "abee",
            "硕一": "硕一",
            "NESO": "NESO",
            "雷神": "雷神",
            "鑫谷": "鑫谷",
            "安钛克": "安钛克",
            "安耐美": "安耐美",
            "方糖机械大师": "方糖机械大师",
            "台电": "台电",
            "珑京": "珑京",
            "撼讯": "撼讯",
            "磐镭": "磐镭",
            "砺算科技": "砺算",
            "砺算": "砺算",
            "电竞叛客": "电竞叛客",
            "浩海宏图": "浩海宏图",
            "智锐通": "智锐通",
            "芯联能": "芯联能",
            "思腾合力": "思腾合力",
            "索泰": "索泰",
            "同德": "同德",
            "万丽": "万丽",
            "外星人": "外星人",
            "COLORFIRE": "COLORFIRE",
            "楚霏": "楚霏",
            "必恩威": "PNY",
            "尔英": "尔英",
            "宝莱特": "宝莱特",
            "研华": "研华",
            "国产飞腾": "飞腾",
            "来酷": "来酷",
            "储奇": "储奇",
            "新乐士": "新乐士",
            "忆捷": "忆捷",
            "OC LAB": "OC LAB",
            "酷芯客": "酷芯客",
            "挚科": "挚科",
            "汉存": "汉存",
            "英睿达": "英睿达",
            "惠普": "惠普",
            "戴尔": "戴尔",
            "毕伟": "毕伟",
            "超越申泰": "超越申泰",
            "镁光": "镁光",
            "京东京造": "京东京造",
            "TANLR": "TANLR",
            "微闪": "微闪",
            "希捷": "希捷",
            "腾隐": "腾隐",
            "登高者": "登高者",
            "储尊": "储尊",
            "赛可驰": "赛可驰",
            "Nextorage": "Nextorage",
            "海康威视": "海康威视",
            "凌态": "凌态",
            "铼德": "铼德",
            "尤达大师": "尤达大师",
            "奥睿科": "奥睿科",
            "久内": "久内",
            "长江存储": "长江存储",
            "芯展速": "芯展速",
            "忆恒创源": "忆恒创源",
            "OWC": "OWC",
            "SOLIDIGM": "SOLIDIGM",
            "思得": "思得",
            "科保盾": "科保盾",
            "博思锐": "博思锐",
            "酷霄": "酷霄",
            "华为": "华为",
            "摩冷": "摩冷",
            "Thermaltake": "Thermaltake",
            "COOLLEO": "COOLLEO",
            "ARCTIC": "ARCTIC",
            "ZALMAN": "ZALMAN",
            "SUMOND": "SUMOND",
            "Apexgaming": "Apexgaming",
            "台达": "台达",
            "熙德热传": "熙德热传",
            "久银工控": "久银工控",
            "天极风": "天极风",
            "博可斯": "博可斯",
            "振华": "振华",
            "雅浚": "雅浚",
            "红戟": "红戟",
            "零度世家": "零度世家",
            "丛林豹": "丛林豹",
            "海韵": "海韵",
            "绿巨能": "绿巨能",
            "AD90": "AD90",
            "京品鹿": "京品鹿",
            "Apexgaming": "Apexgaming",
            "NZXT": "NZXT",
            "机械大师": "机械大师",
            "SAHARA": "SAHARA",
            "撒哈拉": "撒哈拉",
            "HAVN": "HAVN",
            "APNX": "APNX",
            "ART ULTRA": "ART ULTRA",
            "趣创": "趣创",
            "虞诚": "虞诚",
            "德商德静界": "德商德静界",
            "FPMAX": "FPMAX",
            "EVESKY": "EVESKY",
            "鱼巢": "鱼巢",
            "巧美": "巧美",
            "山头林村": "山头林村",
            "研锦工控": "研锦工控",
            "平行世界": "平行世界",
            "雷匠": "雷匠",
        }.items(),
        key=lambda item: len(item[0]),
        reverse=True,
    )
)


@dataclass(frozen=True)
class ZhuangjidiyPart:
    component_id: str
    category: str
    name: str
    brand: str
    detail_raw: str
    specs: Dict[str, Any]
    price: int
    source_part_id: str


def fetch_zhuangjidiy_parts(
    types: Iterable[str] = TYPE_TO_CATEGORY.keys(),
    *,
    page_size: int = 100,
    delay_seconds: float = 0.15,
    timeout_seconds: float = 30,
    list_url: str = DEFAULT_LIST_URL,
) -> List[ZhuangjidiyPart]:
    parts: List[ZhuangjidiyPart] = []
    for part_type in types:
        if part_type not in TYPE_TO_CATEGORY:
            raise ValueError(f"unsupported zhuangjidiy type: {part_type}")
        page = 1
        total = None
        while total is None or len([p for p in parts if p.specs.get("source_type") == part_type]) < total:
            query = urlencode({"type": part_type, "page": page, "size": page_size})
            request = Request(
                f"{list_url}?{query}",
                headers={"User-Agent": "UzBox-Hardware-Price-Collector/1.0"},
            )
            with urlopen(request, timeout=timeout_seconds) as response:
                payload = json.loads(response.read().decode("utf-8"))
            data = payload.get("data") if isinstance(payload, Mapping) else None
            records = data.get("records") if isinstance(data, Mapping) else None
            if not isinstance(records, list):
                raise ValueError(f"invalid zhuangjidiy response for type={part_type}")
            total = int(data.get("total") or 0)
            parts.extend(
                parsed
                for record in records
                for parsed in [_parse_part(record, part_type)]
                if parsed is not None
            )
            if not records:
                break
            page += 1
            if delay_seconds:
                time.sleep(delay_seconds)
    return parts


def deduplicate_parts(
    parts: Iterable[ZhuangjidiyPart],
    existing_components: Iterable[Mapping[str, Any]],
) -> Tuple[List[ZhuangjidiyPart], Dict[str, int]]:
    parts = list(parts)
    existing_keys = set()
    existing_ids = set()
    for component in existing_components:
        category = str(component.get("category") or "")
        brand = str(component.get("brand") or "")
        name = str(component.get("name") or "")
        existing_keys.add(identity_key(category, brand, name))
        existing_keys.add(identity_key(category, "", name))
        existing_ids.add(str(component.get("id") or ""))

    selected: Dict[str, ZhuangjidiyPart] = {}
    skipped_existing = 0
    skipped_duplicate = 0
    skipped_invalid = 0
    for part in parts:
        if not part.component_id or part.price <= 0:
            skipped_invalid += 1
            continue
        if part.component_id in existing_ids or identity_key(part.category, part.brand, part.name) in existing_keys:
            skipped_existing += 1
            continue
        key = identity_key(part.category, part.brand, part.name)
        previous = selected.get(key)
        if previous is not None:
            skipped_duplicate += 1
            if part.price < previous.price:
                selected[key] = part
            continue
        selected[key] = part
    return list(selected.values()), {
        "fetched": len(parts),
        "existing": skipped_existing,
        "duplicates": skipped_duplicate,
        "invalid": skipped_invalid,
        "new": len(selected),
    }


def identity_key(category: str, brand: str, name: str) -> str:
    value = unicodedata.normalize("NFKC", f"{category}|{brand}|{name}").upper()
    return re.sub(r"[^0-9A-Z\u3400-\u9FFF]+", "", value)


def _parse_part(record: Any, part_type: str) -> Optional[ZhuangjidiyPart]:
    if not isinstance(record, Mapping):
        return None
    source_id = str(record.get("partId") or "").strip()
    raw_name = str(record.get("shortName") or record.get("name") or "").strip()
    raw_price = record.get("salePrice")
    try:
        price_float = float(raw_price)
    except (TypeError, ValueError):
        return None
    if not source_id or not raw_name or not math.isfinite(price_float) or price_float <= 0:
        return None
    brand = infer_brand(raw_name, part_type)
    name = strip_brand(raw_name, brand)
    category = TYPE_TO_CATEGORY[part_type]
    specs: Dict[str, Any] = {
        "source": SOURCE,
        "source_type": part_type,
        "source_part_id": source_id,
        "source_name": raw_name,
        "source_updated_at": record.get("updateTime") or record.get("createTime"),
        "source_url": "https://www.zhuangjidiy.com/build",
        "image": record.get("image") if isinstance(record.get("image"), list) else [],
    }
    if isinstance(record.get("spec"), Mapping):
        specs["source_spec"] = dict(record["spec"])
    specs.update(parse_name_specs(category, raw_name))
    return ZhuangjidiyPart(
        component_id=f"zhuangjidiy-{category}-{source_id}",
        category=category,
        name=name or raw_name,
        brand=brand,
        detail_raw=raw_name,
        specs=specs,
        price=int(round(price_float)),
        source_part_id=source_id,
    )


def infer_brand(name: str, part_type: str = "") -> str:
    normalized = unicodedata.normalize("NFKC", name).strip()
    for alias, brand in BRAND_ALIASES:
        if normalized.casefold().startswith(alias.casefold()):
            return brand
    if part_type == "cpu" and re.match(r"(?i)^(?:r[3579]|锐龙)", normalized):
        return "AMD"
    if part_type == "cpu" and re.match(r"(?i)^(?:i[3579]|core|至强|赛扬|奔腾)", normalized):
        return "Intel"
    chinese_prefix = re.match(r"^[\u3400-\u9fff]{2,8}", normalized)
    if chinese_prefix:
        return chinese_prefix.group(0)
    latin_prefix = re.match(r"^[A-Za-z][A-Za-z0-9-]{1,24}", normalized)
    if latin_prefix:
        return latin_prefix.group(0)
    return "未知品牌"


def strip_brand(name: str, brand: str) -> str:
    normalized = unicodedata.normalize("NFKC", name).strip()
    for alias, canonical in BRAND_ALIASES:
        if canonical == brand and normalized.casefold().startswith(alias.casefold()):
            return normalized[len(alias) :].lstrip(" \t：:—-_")
    if brand != "未知品牌" and normalized.casefold().startswith(brand.casefold()):
        return normalized[len(brand) :].lstrip(" \t：:—-_")
    return normalized


def parse_name_specs(category: str, name: str) -> Dict[str, Any]:
    specs: Dict[str, Any] = {}
    socket = re.search(r"\b(LGA\d+|AM\d+|sTRX\d+|sTR\d+)\b", name, re.I)
    if socket:
        specs["socket"] = socket.group(1).upper()
    if category == "motherboard":
        chipset = re.search(r"\b([ABHZX]\d{3,4}[A-Z0-9-]*)\b", name, re.I)
        if chipset:
            specs["chipset"] = chipset.group(1).upper()
    if category == "ram":
        for pattern, key in ((r"(DDR[345])", "type"), (r"(\d{1,2})GB", "capacity_gb"), (r"(\d{4,5})MHz", "speed_mhz"), (r"\bC(L)?(\d+)\b", "cas_latency")):
            match = re.search(pattern, name, re.I)
            if match:
                value = match.group(match.lastindex or 1)
                specs[key] = int(value) if key in {"capacity_gb", "speed_mhz", "cas_latency"} else value.upper()
    if category == "storage":
        capacity = re.search(r"(\d+(?:\.\d+)?)\s*(TB|GB)", name, re.I)
        if capacity:
            specs["capacity_gb"] = int(float(capacity.group(1)) * (1024 if capacity.group(2).upper() == "TB" else 1))
        if re.search(r"NVMe|M\.2|PCIe", name, re.I):
            specs["interface"] = "NVMe"
    watt = re.search(r"\b(\d{3,4})\s*[Ww]\b", name)
    if watt:
        specs["watt"] = int(watt.group(1))
    return specs


def snapshot_json(parts: Iterable[ZhuangjidiyPart]) -> str:
    return json.dumps([part.__dict__ for part in parts], ensure_ascii=False, indent=2) + "\n"
