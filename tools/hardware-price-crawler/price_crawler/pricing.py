from dataclasses import dataclass
from statistics import median
from typing import Optional, Sequence, Tuple


@dataclass(frozen=True)
class HardwareTarget:
    category: str
    id: str
    name: str
    brand: str
    detail: str


@dataclass(frozen=True)
class RawProduct:
    target_id: str
    category: str
    query: str
    sku: str
    title: str
    price: float
    shop: str
    url: str
    captured_at: str


@dataclass(frozen=True)
class ProductAssessment:
    product: RawProduct
    accepted: bool
    reason: str


@dataclass(frozen=True)
class ReferencePrice:
    target: HardwareTarget
    reference_price: Optional[float]
    normal_price_min: Optional[float]
    normal_price_max: Optional[float]
    accepted_count: int
    rejected_count: int
    review_reasons: Tuple[str, ...]


PRICE_GUARDRAILS = {
    "cpu": (200, 15000),
    "gpu": (500, 30000),
    "motherboard": (300, 15000),
}

GLOBAL_EXCLUSIONS = (
    "二手",
    "闲置",
    "回收",
    "租赁",
    "瑕疵",
    "拆机",
    "维修",
)

CATEGORY_EXCLUSIONS = {
    "cpu": ("整机", "主机", "板u套装", "主板套装", "散热器", "风扇", "笔记本"),
    "gpu": ("整机", "主机", "显卡支架", "延长线", "水冷头", "风扇", "笔记本"),
    "motherboard": ("整机", "主机", "板u套装", "主板套装", "挡板", "bios"),
}

VARIANT_SUFFIXES = (
    "ti",
    "super",
    "xt",
    "gre",
    "x3d",
    "kf",
    "ks",
    "k",
    "f",
    "g",
    "d",
    "x",
    "v2",
    "wifi",
)


def normalize_text(value: str) -> str:
    return "".join(character.lower() for character in value if character.isalnum())


def model_matches(target_name: str, product_title: str) -> bool:
    target = normalize_text(target_name)
    title = normalize_text(product_title)
    position = title.find(target)
    if position < 0:
        return False

    remainder = title[position + len(target) :]
    return not any(remainder.startswith(suffix) for suffix in VARIANT_SUFFIXES)


def assess_product(target: HardwareTarget, product: RawProduct) -> ProductAssessment:
    minimum, maximum = PRICE_GUARDRAILS[target.category]
    if product.price < minimum or product.price > maximum:
        return ProductAssessment(product, False, "price_out_of_range")

    compact_title = normalize_text(product.title)
    for keyword in GLOBAL_EXCLUSIONS + CATEGORY_EXCLUSIONS[target.category]:
        if normalize_text(keyword) in compact_title:
            return ProductAssessment(product, False, "excluded_keyword:{}".format(keyword))

    if not model_matches(target.name, product.title):
        return ProductAssessment(product, False, "model_mismatch")

    return ProductAssessment(product, True, "accepted")


def build_reference_price(
    target: HardwareTarget,
    assessments: Sequence[ProductAssessment],
    previous_price: Optional[float] = None,
) -> ReferencePrice:
    accepted_prices = sorted(item.product.price for item in assessments if item.accepted)
    rejected_count = sum(1 for item in assessments if not item.accepted)
    if not accepted_prices:
        return ReferencePrice(target, None, None, None, 0, rejected_count, ("no_accepted_products",))

    review_reasons = []
    provisional_median = float(median(accepted_prices))
    filtered_prices = [
        price for price in accepted_prices if provisional_median * 0.55 <= price <= provisional_median * 1.80
    ]
    if filtered_prices and len(filtered_prices) != len(accepted_prices):
        rejected_count += len(accepted_prices) - len(filtered_prices)
        accepted_prices = filtered_prices
        review_reasons.append("price_outliers_removed")

    reference_price = float(median(accepted_prices))
    if len(accepted_prices) < 2:
        review_reasons.append("insufficient_accepted_products")
    elif accepted_prices[-1] / accepted_prices[0] > 1.60:
        review_reasons.append("accepted_price_spread_over_60_percent")
    if previous_price and abs(reference_price - previous_price) / previous_price > 0.20:
        review_reasons.append("price_changed_over_20_percent")

    return ReferencePrice(
        target=target,
        reference_price=_clean_number(reference_price),
        normal_price_min=_clean_number(accepted_prices[0]),
        normal_price_max=_clean_number(accepted_prices[-1]),
        accepted_count=len(accepted_prices),
        rejected_count=rejected_count,
        review_reasons=tuple(review_reasons),
    )


def _clean_number(value: float) -> float:
    return int(value) if float(value).is_integer() else round(value, 2)
