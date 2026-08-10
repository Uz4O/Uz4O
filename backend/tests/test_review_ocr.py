import sys
from types import SimpleNamespace

import pytest

from app.review import ocr


def test_paddleocr_engine_uses_cpu_safe_paddleocr_3_options(monkeypatch) -> None:
    received_kwargs = {}

    class FakePaddleOCR:
        def __init__(self, **kwargs) -> None:
            received_kwargs.update(kwargs)

    ocr._paddleocr_engine.cache_clear()
    monkeypatch.setitem(sys.modules, "paddleocr", SimpleNamespace(PaddleOCR=FakePaddleOCR))

    ocr._paddleocr_engine()

    assert received_kwargs == {
        "lang": "ch",
        "use_doc_orientation_classify": False,
        "use_doc_unwarping": False,
        "use_textline_orientation": False,
        "enable_mkldnn": False,
    }

    ocr._paddleocr_engine.cache_clear()


def test_run_paddleocr_retries_without_legacy_cls_argument(monkeypatch) -> None:
    calls = []

    class PaddleOCR3Engine:
        def ocr(self, image_path, **kwargs):
            calls.append((image_path, kwargs))
            if "cls" in kwargs:
                raise TypeError("unexpected keyword argument 'cls'")
            return [{"rec_texts": ["CPU Ryzen 7 9700X"]}]

    monkeypatch.setattr(ocr, "_paddleocr_engine", lambda: PaddleOCR3Engine())

    result = ocr._run_paddleocr("fixture.png")

    assert result == [{"rec_texts": ["CPU Ryzen 7 9700X"]}]
    assert calls == [("fixture.png", {"cls": True}), ("fixture.png", {})]


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
