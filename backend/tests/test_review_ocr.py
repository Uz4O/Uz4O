import sys
from types import SimpleNamespace

import pytest

from app.review import ocr


def test_paddleocr_engine_wraps_runtime_initialization_errors(monkeypatch) -> None:
    class BrokenPaddleOCR:
        def __init__(self, *args, **kwargs) -> None:
            raise RuntimeError("dependency 'paddlepaddle' is not installed")

    ocr._paddleocr_engine.cache_clear()
    monkeypatch.setitem(sys.modules, "paddleocr", SimpleNamespace(PaddleOCR=BrokenPaddleOCR))

    with pytest.raises(ocr.OCRUnavailableError) as exc_info:
        ocr._paddleocr_engine()

    assert "PaddleOCR 初始化失败" in str(exc_info.value)

    ocr._paddleocr_engine.cache_clear()
