from functools import lru_cache
from tempfile import NamedTemporaryFile
from typing import Any, Iterable, List


class OCRUnavailableError(RuntimeError):
    pass


class OCRTextNotFoundError(ValueError):
    pass


def extract_text_from_image_bytes(image_bytes: bytes) -> str:
    if not image_bytes:
        raise OCRTextNotFoundError("未读取到图片内容")

    with NamedTemporaryFile(suffix=".png") as image_file:
        image_file.write(image_bytes)
        image_file.flush()
        result = _run_paddleocr(image_file.name)

    text = "\n".join(_texts_from_ocr_result(result)).strip()
    if len(text) < 12:
        raise OCRTextNotFoundError("没有从图片里识别到足够的配置文字")
    return text


def _run_paddleocr(image_path: str) -> Any:
    engine = _paddleocr_engine()
    if hasattr(engine, "ocr"):
        try:
            return engine.ocr(image_path, cls=True)
        except TypeError:
            return engine.ocr(image_path)
    if hasattr(engine, "predict"):
        return engine.predict(image_path)
    raise OCRUnavailableError("当前 PaddleOCR 版本没有可用的 OCR 调用接口")


@lru_cache(maxsize=1)
def _paddleocr_engine() -> Any:
    try:
        from paddleocr import PaddleOCR
    except Exception as exc:  # pragma: no cover - depends on optional runtime install
        raise OCRUnavailableError("PaddleOCR 尚未安装，请安装 paddleocr 后再使用图片排雷") from exc

    try:
        return PaddleOCR(lang="ch", use_angle_cls=True)
    except TypeError:
        return PaddleOCR(lang="ch")


def _texts_from_ocr_result(value: Any) -> List[str]:
    return [text for text in _walk_texts(value) if text.strip()]


def _walk_texts(value: Any) -> Iterable[str]:
    if value is None:
        return
    if isinstance(value, dict):
        for key in ("rec_texts", "texts"):
            texts = value.get(key)
            if isinstance(texts, list):
                for text in texts:
                    if isinstance(text, str):
                        yield text
        for child in value.values():
            yield from _walk_texts(child)
        return
    if hasattr(value, "json"):
        yield from _walk_texts(value.json)
        return
    if hasattr(value, "to_dict"):
        yield from _walk_texts(value.to_dict())
        return
    if isinstance(value, (list, tuple)):
        if len(value) >= 2 and isinstance(value[1], (list, tuple)) and value[1] and isinstance(value[1][0], str):
            yield value[1][0]
            return
        for child in value:
            yield from _walk_texts(child)

