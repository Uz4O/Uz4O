EXCLUDED_GPU_BRANDS_OVER_5000 = ("耕升",)


def gpu_brand_allowed_for_budget(name: str, budget: int) -> bool:
    if budget <= 5_000:
        return True
    return not any(brand in name for brand in EXCLUDED_GPU_BRANDS_OVER_5000)
