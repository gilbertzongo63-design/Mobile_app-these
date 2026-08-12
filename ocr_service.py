import re
import unicodedata
from concurrent.futures import ThreadPoolExecutor, as_completed
from difflib import SequenceMatcher
from pathlib import Path

import cv2
import pytesseract
from pytesseract import Output


OCR_CLASS_KEYWORDS = {
    "Plastic": [
        "plastic",
        "plastique",
        "pet",
        "pete",
        "hdpe",
        "ldpe",
        "pvc",
        "pp",
        "ps",
        "pla",
        "polyethylene",
        "polypropylene",
        "bottle",
        "bouteille",
        "flacon",
        "emballage plastique",
        "recyclable",
        "recycle",
        "recycling",
        "eau",
        "water",
        "soda",
        "boisson",
    ],
    "Glass": [
        "glass",
        "verre",
        "bocal",
        "jar",
        "bouteille en verre",
    ],
    "PaperCardboard": [
        "paper",
        "papier",
        "cardboard",
        "carton",
        "card",
        "box",
        "boite",
        "pack",
        "tetra",
        "tetrapak",
        "brick",
        "brique",
        "lait",
        "milk",
        "juice",
        "jus",
    ],
    "Metal": [
        "metal",
        "metallique",
        "alu",
        "aluminium",
        "aluminum",
        "steel",
        "acier",
        "can",
        "canette",
        "conserve",
        "tin",
        "cannette",
        "canette alu",
        "aluminium can",
    ],
    "Other": [
        "styrofoam",
        "foam",
        "mousse",
        "snack",
        "chips",
        "wrapper",
        "sachet",
        "film",
        "pouch",
        "barquette",
        "polystyrene",
    ],
}

LABEL_INDICATOR_KEYWORDS = [
    "coca",
    "cola",
    "cocacola",
    "pepsi",
    "fanta",
    "sprite",
    "nestle",
    "evian",
    "vittel",
    "cristaline",
    "volvic",
    "danone",
    "lait",
    "milk",
    "eau",
    "water",
    "jus",
    "juice",
    "soda",
    "pet",
    "hdpe",
    "pp",
    "alu",
    "aluminium",
    "carton",
    "papier",
    "verre",
    "glass",
    "metal",
    "recyclable",
    "tri",
]

TESSERACT_CONFIGS = [
    "--oem 3 --psm 6 -c preserve_interword_spaces=1",
    "--oem 3 --psm 7 -c preserve_interword_spaces=1",
    "--oem 3 --psm 11 -c preserve_interword_spaces=1",
]

FUZZY_MIN_LENGTH = 5
FUZZY_THRESHOLD = 0.82
MIN_OCR_WORD_CONFIDENCE = 35
MIN_RELIABLE_CLASS_SCORE = 1.0

WEAK_SINGLE_TOKEN_KEYWORDS = {
    "alu",
    "box",
    "can",
    "card",
    "film",
    "jar",
    "pack",
    "pet",
    "pla",
    "pp",
    "ps",
    "pvc",
    "tin",
}

OCR_TOKEN_CORRECTIONS = {
    "plast1c": "plastic",
    "piastic": "plastic",
    "plastlc": "plastic",
    "p1astic": "plastic",
    "bott1e": "bottle",
    "bouteilie": "bouteille",
    "metai": "metal",
    "metalllque": "metallique",
    "a1u": "alu",
    "aluminlum": "aluminium",
    "cart0n": "carton",
    "bo1te": "boite",
    "g1ass": "glass",
    "verrc": "verre",
    "papcr": "paper",
    "papler": "papier",
    "tetra pak": "tetrapak",
    "tetra pack": "tetrapak",
    "coca cola": "cocacola",
    "coca-cola": "cocacola",
    "c0ca": "coca",
    "coia": "cola",
    "pepsl": "pepsi",
    "fanta.": "fanta",
    "sprlte": "sprite",
    "evlan": "evian",
    "cristaiine": "cristaline",
    "recyciable": "recyclable",
}


def normalize_text(text: str):
    lowered = unicodedata.normalize("NFKD", text.lower())
    lowered = "".join(char for char in lowered if not unicodedata.combining(char))
    lowered = lowered.replace("\n", " ")
    lowered = re.sub(r"[^a-z0-9\s]+", " ", lowered)
    lowered = re.sub(r"\s+", " ", lowered).strip()
    for source, replacement in OCR_TOKEN_CORRECTIONS.items():
        lowered = re.sub(rf"\b{re.escape(source)}\b", replacement, lowered)
    return lowered


def _load_image(image_path: Path):
    image = cv2.imread(str(image_path))
    if image is None:
        raise FileNotFoundError(f"Unable to read image for OCR: {image_path}")
    return image


def _resize_for_ocr(image):
    height, width = image.shape[:2]
    longest_side = max(width, height)
    if longest_side <= 0:
        return image

    target_longest_side = 1600
    max_longest_side = 2200
    if longest_side < target_longest_side:
        scale = target_longest_side / longest_side
    elif longest_side > max_longest_side:
        scale = max_longest_side / longest_side
    else:
        scale = 1.0

    if scale == 1.0:
        return image
    interpolation = cv2.INTER_CUBIC if scale > 1 else cv2.INTER_AREA
    return cv2.resize(image, None, fx=scale, fy=scale, interpolation=interpolation)


def _candidate_regions(image):
    height, width = image.shape[:2]
    regions = [("full", image)]
    if height > 0 and width > 0:
        regions.extend(
            [
                ("full_rot90_cw", cv2.rotate(image, cv2.ROTATE_90_CLOCKWISE)),
                ("full_rot90_ccw", cv2.rotate(image, cv2.ROTATE_90_COUNTERCLOCKWISE)),
                ("full_rot180", cv2.rotate(image, cv2.ROTATE_180)),
            ]
        )
    crop_specs = [
        ("center_object", 0.14, 0.12, 0.86, 0.88),
        ("middle_label", 0.08, 0.24, 0.92, 0.76),
        ("lower_label", 0.10, 0.45, 0.90, 0.95),
        ("upper_label", 0.10, 0.05, 0.90, 0.55),
        ("left_label", 0.00, 0.15, 0.58, 0.90),
        ("right_label", 0.42, 0.15, 1.00, 0.90),
    ]

    for name, left, top, right, bottom in crop_specs:
        x1 = int(width * left)
        y1 = int(height * top)
        x2 = int(width * right)
        y2 = int(height * bottom)
        crop = image[y1:y2, x1:x2]
        if crop.size:
            regions.append((name, crop))
    return regions


def _enhance_gray(image):
    gray = cv2.cvtColor(_resize_for_ocr(image), cv2.COLOR_BGR2GRAY)
    clahe = cv2.createCLAHE(clipLimit=2.8, tileGridSize=(8, 8)).apply(gray)
    denoised = cv2.fastNlMeansDenoising(clahe, None, 9, 7, 21)
    sharpened = cv2.addWeighted(denoised, 1.75, cv2.GaussianBlur(denoised, (0, 0), 2), -0.75, 0)
    return gray, clahe, denoised, sharpened


def _enhance_gray_full(image):
    gray = cv2.cvtColor(_resize_for_ocr(image), cv2.COLOR_BGR2GRAY)
    return gray


def _denoise_full(gray):
    return cv2.fastNlMeansDenoising(gray, None, 9, 7, 21)


def _enhance_gray_region(denoised_full, region_bbox):
    x1, y1, x2, y2 = region_bbox
    crop = denoised_full[y1:y2, x1:x2]
    clahe = cv2.createCLAHE(clipLimit=2.8, tileGridSize=(8, 8)).apply(crop)
    sharpened = cv2.addWeighted(clahe, 1.75, cv2.GaussianBlur(clahe, (0, 0), 2), -0.75, 0)
    return sharpened


def _candidate_region_bboxes(image):
    height, width = image.shape[:2]
    bboxes = [("full", (0, 0, width, height))]
    if height > 0 and width > 0:
        bboxes.extend(
            [
                ("full_rot90_cw", None),
                ("full_rot90_ccw", None),
                ("full_rot180", None),
            ]
        )
    crop_specs = [
        ("center_object", 0.14, 0.12, 0.86, 0.88),
        ("middle_label", 0.08, 0.24, 0.92, 0.76),
        ("lower_label", 0.10, 0.45, 0.90, 0.95),
        ("upper_label", 0.10, 0.05, 0.90, 0.55),
        ("left_label", 0.00, 0.15, 0.58, 0.90),
        ("right_label", 0.42, 0.15, 1.00, 0.90),
    ]

    for name, left, top, right, bottom in crop_specs:
        x1 = int(width * left)
        y1 = int(height * top)
        x2 = int(width * right)
        y2 = int(height * bottom)
        bboxes.append((name, (x1, y1, x2, y2)))
    return bboxes


def preprocess_variants_for_ocr(image_path: Path):
    image = _load_image(image_path)
    gray_full = _enhance_gray_full(image)
    denoised_full = _denoise_full(gray_full)
    h_full, w_full = denoised_full.shape[:2]
    bboxes = _candidate_region_bboxes(image)

    rotated_cache = {}

    def _process_region(region_name, bbox):
        if bbox is not None:
            x1, y1, x2, y2 = bbox
            if x2 <= w_full and y2 <= h_full and (x1, y1, x2, y2) != (0, 0, w_full, h_full):
                sharpened = _enhance_gray_region(denoised_full, bbox)
            else:
                sharpened = _enhance_gray_region(denoised_full, (0, 0, w_full, h_full))
        else:
            if region_name == "full_rot90_cw":
                key = "rot90_cw"
            elif region_name == "full_rot90_ccw":
                key = "rot90_ccw"
            else:
                key = "rot180"
            if key not in rotated_cache:
                if key == "rot90_cw":
                    rot = cv2.rotate(image, cv2.ROTATE_90_CLOCKWISE)
                elif key == "rot90_ccw":
                    rot = cv2.rotate(image, cv2.ROTATE_90_COUNTERCLOCKWISE)
                else:
                    rot = cv2.rotate(image, cv2.ROTATE_180)
                gray_rot = _enhance_gray_full(rot)
                denoised_rot = _denoise_full(gray_rot)
                rotated_cache[key] = denoised_rot
            denoised_rot = rotated_cache[key]
            sharpened = _enhance_gray_region(denoised_rot, (0, 0, denoised_rot.shape[1], denoised_rot.shape[0]))

        blurred = cv2.GaussianBlur(sharpened, (3, 3), 0)
        _, otsu = cv2.threshold(sharpened, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        adaptive = cv2.adaptiveThreshold(
            blurred, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 35, 9,
        )
        return [
            (f"{region_name}:sharpened", sharpened),
            (f"{region_name}:otsu", otsu),
            (f"{region_name}:adaptive_gaussian", adaptive),
            (f"{region_name}:inverted_adaptive", cv2.bitwise_not(adaptive)),
        ]

    variants = []
    with ThreadPoolExecutor(max_workers=min(len(bboxes), 8)) as executor:
        futures = {
            executor.submit(_process_region, name, bbox): name
            for name, bbox in bboxes
        }
        for future in as_completed(futures):
            try:
                variants.extend(future.result())
            except Exception:
                pass

    return variants


def preprocess_for_ocr(image_path: Path):
    return preprocess_variants_for_ocr(image_path)[0][1]


def _token_similarity(left: str, right: str):
    return SequenceMatcher(None, left, right).ratio()


def _keyword_hit(keyword: str, clean_text: str, tokens):
    if " " in keyword and keyword in clean_text:
        return keyword
    if " " not in keyword and keyword in tokens:
        return keyword
    if len(keyword) < FUZZY_MIN_LENGTH or " " in keyword:
        return None

    best_token = None
    best_score = 0.0
    for token in tokens:
        if len(token) < FUZZY_MIN_LENGTH:
            continue
        score = _token_similarity(keyword, token)
        if score > best_score:
            best_score = score
            best_token = token

    if best_token and best_score >= FUZZY_THRESHOLD:
        return f"{keyword}~{best_token}"
    return None


def match_keywords(clean_text: str):
    scores = {}
    matched_keywords = {}
    tokens = clean_text.split()
    for class_name, keywords in OCR_CLASS_KEYWORDS.items():
        hits = []
        score = 0.0
        for keyword in keywords:
            hit = _keyword_hit(keyword, clean_text, tokens)
            if hit:
                hits.append(hit)
                score += _keyword_weight(hit)
        if score >= MIN_RELIABLE_CLASS_SCORE:
            scores[class_name] = round(score, 2)
            matched_keywords[class_name] = sorted(set(hits))
    return scores, matched_keywords


def match_label_indicators(clean_text: str):
    tokens = clean_text.split()
    hits = []
    for keyword in LABEL_INDICATOR_KEYWORDS:
        hit = _keyword_hit(keyword, clean_text, tokens)
        if hit:
            hits.append(hit)
    return sorted(set(hits))


def _keyword_weight(hit: str):
    keyword = hit.split("~", 1)[0]
    if keyword in WEAK_SINGLE_TOKEN_KEYWORDS:
        return 0.35
    if len(keyword) <= 3:
        return 0.45
    return 1.0


def _safe_tesseract_words(processed, config: str):
    try:
        data = pytesseract.image_to_data(processed, config=config, output_type=Output.DICT)
    except pytesseract.TesseractError:
        return "", [], 0.0

    raw_tokens = []
    words = []
    confidences = []
    for index, text in enumerate(data.get("text", [])):
        clean = text.strip()
        if not clean:
            continue
        raw_tokens.append(clean)
        try:
            confidence = float(data["conf"][index])
        except (KeyError, TypeError, ValueError):
            confidence = -1.0
        if confidence < MIN_OCR_WORD_CONFIDENCE:
            continue
        words.append(
            {
                "text": clean,
                "confidence": round(confidence / 100, 4),
                "box": {
                    "left": int(data["left"][index]),
                    "top": int(data["top"][index]),
                    "width": int(data["width"][index]),
                    "height": int(data["height"][index]),
                },
            }
        )
        confidences.append(confidence)

    average_confidence = (sum(confidences) / len(confidences) / 100) if confidences else 0.0
    return " ".join(raw_tokens), words, average_confidence


def _attempt_rank(clean_text: str, scores, average_word_confidence: float):
    max_score = max(scores.values()) if scores else 0
    word_count = len(clean_text.split())
    useful_length = min(len(clean_text), 160)
    return (
        max_score,
        round(average_word_confidence, 4),
        min(word_count, 18),
        useful_length,
    )


class OCRAnalyzer:
    def analyze(self, image_path: Path):
        variants = preprocess_variants_for_ocr(image_path)

        def _run_tesseract(args):
            variant_name, processed, config = args
            raw_text, words, average_word_confidence = _safe_tesseract_words(processed, config=config)
            clean_text = normalize_text(raw_text)
            scores, matched_keywords = match_keywords(clean_text)
            label_indicators = match_label_indicators(clean_text)
            rank = _attempt_rank(clean_text, scores, average_word_confidence)
            if label_indicators:
                rank = (
                    rank[0],
                    rank[1],
                    rank[2] + min(len(label_indicators), 4),
                    rank[3],
                )
            return {
                "raw_text": raw_text.strip(),
                "clean_text": clean_text,
                "scores": scores,
                "matched_keywords": matched_keywords,
                "label_indicators": label_indicators,
                "preprocess_variant": variant_name,
                "tesseract_config": config,
                "average_word_confidence": round(average_word_confidence, 4),
                "detected_words": words[:24],
                "_rank": rank,
            }

        PRIMARY_CONFIGS = [
            "--oem 3 --psm 6 -c preserve_interword_spaces=1",
            "--oem 3 --psm 11 -c preserve_interword_spaces=1",
        ]

        primary_variants = [
            (vn, p) for vn, p in variants
            if any(vn.startswith(pfx) for pfx in ("full:", "center_object:", "middle_label:"))
        ]

        phase1_tasks = [
            (vn, p, cfg)
            for vn, p in primary_variants
            for cfg in PRIMARY_CONFIGS
        ]

        attempts = []
        with ThreadPoolExecutor(max_workers=min(len(phase1_tasks) or 1, 8)) as pool:
            futures = {pool.submit(_run_tesseract, t): t for t in phase1_tasks}
            for f in as_completed(futures):
                try:
                    attempts.append(f.result())
                except Exception:
                    pass

        if attempts:
            best_phase1 = max(attempts, key=lambda a: a["_rank"])
            if best_phase1["_rank"][0] >= 2 and best_phase1["_rank"][1] >= 0.55:
                return self._build_result(attempts)

        phase1_has_any_signal = any(
            a["scores"] or a["label_indicators"] for a in attempts
        )

        if not phase1_has_any_signal:
            return self._build_result(attempts)

        phase2_tasks = [
            (vn, p, cfg)
            for vn, p in variants
            for cfg in TESSERACT_CONFIGS
            if not any(
                t[0] == vn and t[2] == cfg
                for t in phase1_tasks
            )
        ]

        if phase2_tasks:
            with ThreadPoolExecutor(max_workers=min(len(phase2_tasks), 8)) as pool:
                futures = {pool.submit(_run_tesseract, t): t for t in phase2_tasks}
                for f in as_completed(futures):
                    try:
                        attempts.append(f.result())
                    except Exception:
                        pass

        if not attempts:
            return self._empty_result()

        return self._build_result(attempts)

    def _build_result(self, attempts):
        best = max(attempts, key=lambda attempt: attempt["_rank"])
        scores = best["scores"]
        matched_keywords = best["matched_keywords"]
        label_indicators = best["label_indicators"]

        if scores:
            predicted_class = max(scores, key=scores.get)
            max_score = max(scores.values())
            confidence = min(
                0.97,
                0.35 + (0.14 * max_score) + (0.18 * best["average_word_confidence"]),
            )
        else:
            predicted_class = None
            confidence = round(min(0.35, best["average_word_confidence"] * 0.35), 4)

        top_attempts = sorted(attempts, key=lambda a: a["_rank"], reverse=True)[:5]

        return {
            "raw_text": best["raw_text"],
            "clean_text": best["clean_text"],
            "predicted_class": predicted_class,
            "confidence": round(confidence, 4),
            "scores": scores,
            "matched_keywords": matched_keywords,
            "label_indicators": label_indicators,
            "useful_text_signal": bool(scores or label_indicators),
            "has_text_signal": bool(scores),
            "preprocess_variant": best["preprocess_variant"],
            "tesseract_config": best["tesseract_config"],
            "average_word_confidence": best["average_word_confidence"],
            "detected_words": best["detected_words"],
            "top_ocr_attempts": [
                {
                    "preprocess_variant": a["preprocess_variant"],
                    "tesseract_config": a["tesseract_config"],
                    "clean_text": a["clean_text"],
                    "average_word_confidence": a["average_word_confidence"],
                    "scores": a["scores"],
                    "label_indicators": a["label_indicators"],
                }
                for a in top_attempts
            ],
        }

    def _empty_result(self):
        return {
            "raw_text": "",
            "clean_text": "",
            "predicted_class": None,
            "confidence": 0.0,
            "scores": {},
            "matched_keywords": {},
            "label_indicators": [],
            "useful_text_signal": False,
            "has_text_signal": False,
            "preprocess_variant": "",
            "tesseract_config": "",
            "average_word_confidence": 0.0,
            "detected_words": [],
            "top_ocr_attempts": [],
        }
