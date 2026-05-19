import re
from pathlib import Path

import cv2
import pytesseract


OCR_CLASS_KEYWORDS = {
    "Plastic": [
        "plastic",
        "pet",
        "hdpe",
        "ldpe",
        "pp",
        "polyethylene",
        "polypropylene",
        "bottle",
    ],
    "Glass": [
        "glass",
        "verre",
    ],
    "PaperCardboard": [
        "paper",
        "papier",
        "cardboard",
        "carton",
        "card",
    ],
    "Metal": [
        "metal",
        "alu",
        "aluminium",
        "aluminum",
        "steel",
        "can",
        "tin",
    ],
    "Other": [
        "styrofoam",
        "foam",
        "snack",
        "chips",
        "wrapper",
    ],
}


def normalize_text(text: str):
    lowered = text.lower()
    lowered = lowered.replace("\n", " ")
    lowered = re.sub(r"[^a-z0-9\s]+", " ", lowered)
    lowered = re.sub(r"\s+", " ", lowered).strip()
    return lowered


def preprocess_for_ocr(image_path: Path):
    image = cv2.imread(str(image_path))
    if image is None:
        raise FileNotFoundError(f"Unable to read image for OCR: {image_path}")
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, None, fx=1.5, fy=1.5, interpolation=cv2.INTER_CUBIC)
    gray = cv2.GaussianBlur(gray, (3, 3), 0)
    _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    return thresh


def match_keywords(clean_text: str):
    scores = {}
    matched_keywords = {}
    for class_name, keywords in OCR_CLASS_KEYWORDS.items():
        hits = [keyword for keyword in keywords if keyword in clean_text]
        if hits:
            scores[class_name] = len(hits)
            matched_keywords[class_name] = sorted(set(hits))
    return scores, matched_keywords


class OCRAnalyzer:
    def analyze(self, image_path: Path):
        processed = preprocess_for_ocr(image_path)
        raw_text = pytesseract.image_to_string(processed, config="--oem 3 --psm 6")
        clean_text = normalize_text(raw_text)
        scores, matched_keywords = match_keywords(clean_text)

        if scores:
            predicted_class = max(scores, key=scores.get)
            max_score = max(scores.values())
            confidence = min(0.95, 0.35 + (0.15 * max_score))
        else:
            predicted_class = None
            confidence = 0.0

        return {
            "raw_text": raw_text.strip(),
            "clean_text": clean_text,
            "predicted_class": predicted_class,
            "confidence": round(confidence, 4),
            "scores": scores,
            "matched_keywords": matched_keywords,
            "has_text_signal": bool(scores),
        }
