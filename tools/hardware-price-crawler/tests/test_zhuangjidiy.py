from price_crawler.zhuangjidiy import _parse_part, deduplicate_parts


def test_parse_part_infers_brand_and_specs():
    part = _parse_part(
        {
            "partId": "123",
            "shortName": "华硕 PRIME B650M-A WIFI 主板 AM5",
            "salePrice": 799.4,
            "image": ["https://example.test/a.jpg"],
        },
        "motherboard",
    )
    assert part is not None
    assert part.brand == "华硕"
    assert part.name.startswith("PRIME B650M-A")
    assert part.price == 799
    assert part.specs["socket"] == "AM5"
    assert part.specs["chipset"] == "B650M-A"


def test_deduplicate_skips_existing_and_keeps_lowest_duplicate_price():
    first = _parse_part({"partId": "1", "shortName": "三星 990 PRO 1TB", "salePrice": 699}, "storage")
    second = _parse_part({"partId": "2", "shortName": "三星 990 PRO 1TB", "salePrice": 599}, "storage")
    existing = [{"id": "old", "category": "storage", "brand": "西数", "name": "SN770 1TB"}]
    selected, stats = deduplicate_parts([first, second], existing)
    assert [part.price for part in selected] == [599]
    assert stats == {"fetched": 2, "existing": 0, "duplicates": 1, "invalid": 0, "new": 1}
