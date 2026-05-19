import argparse
import json
from pathlib import Path

from fusion_service import fuse_predictions
from model_profile import ACTIVE_MODEL_PROFILE
from ocr_service import OCRAnalyzer
from vision_service import VisionClassifier


ROOT = Path(__file__).resolve().parent
DEFAULT_MODEL = ACTIVE_MODEL_PROFILE["checkpoint"]


def parse_args():
    parser = argparse.ArgumentParser(description="Run OCR + vision inference on one image.")
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path, default=DEFAULT_MODEL)
    parser.add_argument("--top-k", type=int, default=3)
    parser.add_argument("--disable-ocr", action="store_true")
    return parser.parse_args()


def main():
    args = parse_args()
    classifier = VisionClassifier(args.checkpoint, class_bias=ACTIVE_MODEL_PROFILE["policy"].get("class_bias"))
    vision_result = classifier.predict(args.image, top_k=args.top_k)

    if args.disable_ocr:
        ocr_result = {
            "raw_text": "",
            "clean_text": "",
            "predicted_class": None,
            "confidence": 0.0,
            "scores": {},
            "matched_keywords": {},
            "has_text_signal": False,
        }
    else:
        ocr_result = OCRAnalyzer().analyze(args.image)

    decision = fuse_predictions(vision_result, ocr_result, policy=ACTIVE_MODEL_PROFILE["policy"])

    output = {
        "image": str(args.image),
        "model_profile": ACTIVE_MODEL_PROFILE["name"],
        "vision": vision_result,
        "ocr": ocr_result,
        "decision": decision,
    }
    print(json.dumps(output, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
