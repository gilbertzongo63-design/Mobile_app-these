import csv
import json
import sys
from difflib import SequenceMatcher
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from ocr_service import OCRAnalyzer, normalize_text


OUTPUT_DIR = ROOT / "analysis" / "ocr_object_reading_benchmark"
IMAGE_DIR = OUTPUT_DIR / "images"

TEST_CASES = [
    {
        "class_name": "Plastic",
        "shape": "bottle",
        "lines": ["PLASTIC PET BOTTLE", "RECYCLABLE PACKAGING", "BOUTEILLE PLASTIQUE"],
        "fill": (196, 232, 244),
        "outline": (84, 130, 146),
    },
    {
        "class_name": "Glass",
        "shape": "jar",
        "lines": ["GLASS JAR", "BOCAL EN VERRE", "RECYCLABLE"],
        "fill": (210, 238, 230),
        "outline": (78, 132, 118),
    },
    {
        "class_name": "PaperCardboard",
        "shape": "box",
        "lines": ["CARDBOARD BOX", "CARTON PAPIER", "PAPER PACK"],
        "fill": (224, 193, 139),
        "outline": (135, 93, 46),
    },
    {
        "class_name": "Metal",
        "shape": "can",
        "lines": ["METAL CAN", "ALUMINIUM", "CANETTE RECYCLABLE"],
        "fill": (198, 202, 201),
        "outline": (88, 92, 91),
    },
    {
        "class_name": "Other",
        "shape": "wrapper",
        "lines": ["SNACK WRAPPER", "SACHET CHIPS", "FILM MOUSSE"],
        "fill": (239, 190, 150),
        "outline": (151, 83, 47),
    },
]


def _font(size: int):
    for name in ("arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _centered_text(draw: ImageDraw.ImageDraw, text: str, y: int, font, fill, center_x: int = 550):
    box = draw.textbbox((0, 0), text, font=font)
    x = center_x - ((box[2] - box[0]) // 2)
    draw.text((x, y), text, fill=fill, font=font)


def _draw_object(draw: ImageDraw.ImageDraw, case: dict):
    fill = case["fill"]
    outline = case["outline"]
    shape = case["shape"]

    if shape == "bottle":
        draw.rounded_rectangle((385, 90, 715, 780), radius=130, fill=fill, outline=outline, width=8)
        draw.rounded_rectangle((450, 25, 650, 130), radius=35, fill=fill, outline=outline, width=6)
        label_box = (345, 330, 755, 555)
    elif shape == "jar":
        draw.rounded_rectangle((350, 120, 750, 745), radius=90, fill=fill, outline=outline, width=8)
        draw.rounded_rectangle((400, 60, 700, 150), radius=24, fill=(183, 215, 207), outline=outline, width=6)
        label_box = (320, 335, 780, 555)
    elif shape == "box":
        draw.rectangle((285, 165, 815, 700), fill=fill, outline=outline, width=8)
        draw.line((285, 165, 420, 70, 950, 70, 815, 165), fill=outline, width=7)
        draw.polygon([(285, 165), (420, 70), (950, 70), (815, 165)], fill=(236, 207, 156), outline=outline)
        label_box = (315, 330, 785, 540)
    elif shape == "can":
        draw.rounded_rectangle((365, 85, 735, 725), radius=90, fill=fill, outline=outline, width=8)
        draw.ellipse((365, 55, 735, 150), fill=(216, 220, 218), outline=outline, width=5)
        draw.ellipse((365, 660, 735, 750), fill=(180, 184, 182), outline=outline, width=5)
        label_box = (330, 315, 770, 520)
    else:
        draw.rounded_rectangle((270, 210, 830, 650), radius=42, fill=fill, outline=outline, width=8)
        draw.polygon([(270, 210), (220, 255), (270, 300)], fill=(222, 161, 120), outline=outline)
        draw.polygon([(830, 560), (880, 605), (830, 650)], fill=(222, 161, 120), outline=outline)
        label_box = (300, 335, 800, 535)

    draw.rounded_rectangle(label_box, radius=28, fill=(250, 250, 241), outline=outline, width=6)
    return label_box


def create_object_image(case: dict, output_path: Path):
    image = Image.new("RGB", (1100, 850), (237, 241, 232))
    draw = ImageDraw.Draw(image)
    label_box = _draw_object(draw, case)

    y = label_box[1] + 24
    for index, line in enumerate(case["lines"]):
        font = _font(46 if index == 0 else 36)
        _centered_text(draw, line, y, font, fill=(25, 45, 36))
        y += 58

    image = image.rotate(-3, resample=Image.Resampling.BICUBIC, expand=True, fillcolor=(237, 241, 232))
    image = image.filter(ImageFilter.GaussianBlur(radius=0.35))
    image.save(output_path, quality=95)


def run_benchmark():
    IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    analyzer = OCRAnalyzer()
    rows = []

    for case in TEST_CASES:
        image_path = IMAGE_DIR / f"{case['class_name'].lower()}_written_object.png"
        create_object_image(case, image_path)

        expected_text = " ".join(case["lines"])
        expected_clean = normalize_text(expected_text)
        result = analyzer.analyze(image_path)
        read_clean = result["clean_text"]
        similarity = SequenceMatcher(None, expected_clean, read_clean).ratio()

        rows.append(
            {
                "class_name": case["class_name"],
                "image_path": str(image_path.relative_to(ROOT)),
                "expected_text": expected_clean,
                "ocr_text": read_clean,
                "similarity_percent": round(similarity * 100, 2),
                "ocr_predicted_class": result["predicted_class"],
                "ocr_confidence": result["confidence"],
                "average_word_confidence": result["average_word_confidence"],
                "preprocess_variant": result["preprocess_variant"],
                "matched_keywords": result["matched_keywords"],
            }
        )

    json_path = OUTPUT_DIR / "results.json"
    csv_path = OUTPUT_DIR / "results.csv"
    json_path.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")

    with csv_path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(json.dumps(rows, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    run_benchmark()
