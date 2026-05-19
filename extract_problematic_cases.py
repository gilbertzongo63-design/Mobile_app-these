import argparse
import csv
import json
import shutil
from pathlib import Path

from PIL import Image
import torch
from torchvision import models, transforms


ROOT = Path(__file__).resolve().parent
DEFAULT_CHECKPOINT = ROOT / "training_runs" / "stage2_combined_resnet18_all_key_classes_cleaned" / "best_model.pt"
DEFAULT_DATASET = ROOT / "prepared_datasets" / "combined_6class" / "test"
DEFAULT_OUTPUT = ROOT / "analysis" / "problematic_cases"


def parse_args():
    parser = argparse.ArgumentParser(description="Extract problematic classification cases from the test split.")
    parser.add_argument("--checkpoint", type=Path, default=DEFAULT_CHECKPOINT)
    parser.add_argument("--dataset-dir", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--focus-classes", nargs="+", default=["Plastic", "Glass", "Other"])
    parser.add_argument("--low-confidence-threshold", type=float, default=0.55)
    return parser.parse_args()


def build_model(model_name: str, num_classes: int):
    if model_name == "resnet18":
        model = models.resnet18(weights=None)
        model.fc = torch.nn.Linear(model.fc.in_features, num_classes)
        return model
    if model_name == "mobilenet_v3_small":
        model = models.mobilenet_v3_small(weights=None)
        in_features = model.classifier[-1].in_features
        model.classifier[-1] = torch.nn.Linear(in_features, num_classes)
        return model
    raise ValueError(f"Unsupported model: {model_name}")


def build_transform(image_size: int):
    return transforms.Compose(
        [
            transforms.Resize((image_size, image_size)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ]
    )


def ensure_clean_dir(path: Path):
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def copy_case(image_path: Path, output_dir: Path, predicted_class: str):
    output_dir.mkdir(parents=True, exist_ok=True)
    destination = output_dir / f"{image_path.stem}__pred-{predicted_class}{image_path.suffix}"
    shutil.copy2(image_path, destination)


def main():
    args = parse_args()
    ensure_clean_dir(args.output_dir)

    checkpoint = torch.load(args.checkpoint, map_location="cpu")
    class_names = checkpoint["class_names"]
    model_name = checkpoint.get("model_name", "resnet18")
    image_size = checkpoint.get("image_size", 224)

    model = build_model(model_name, len(class_names))
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()
    transform = build_transform(image_size)

    rows = []
    summary = {
        "focus_classes": args.focus_classes,
        "low_confidence_threshold": args.low_confidence_threshold,
        "total_cases": 0,
        "misclassified_cases": 0,
        "low_confidence_cases": 0,
        "focus_class_cases": 0,
    }

    for class_dir in sorted([p for p in args.dataset_dir.iterdir() if p.is_dir()]):
        true_class = class_dir.name
        for image_path in sorted([p for p in class_dir.iterdir() if p.is_file()]):
            with Image.open(image_path) as image:
                image = image.convert("RGB")
                tensor = transform(image).unsqueeze(0)
            with torch.no_grad():
                probs = torch.softmax(model(tensor), dim=1).squeeze(0)
            scores, indices = torch.topk(probs, k=min(3, len(class_names)))
            top_predictions = [(class_names[idx], float(score)) for score, idx in zip(scores.tolist(), indices.tolist())]

            predicted_class, predicted_prob = top_predictions[0]
            low_confidence = predicted_prob < args.low_confidence_threshold
            misclassified = predicted_class != true_class
            in_focus = true_class in args.focus_classes or predicted_class in args.focus_classes

            if not (misclassified or low_confidence or in_focus):
                continue

            summary["total_cases"] += 1
            if misclassified:
                summary["misclassified_cases"] += 1
            if low_confidence:
                summary["low_confidence_cases"] += 1
            if in_focus:
                summary["focus_class_cases"] += 1

            row = {
                "image_path": str(image_path),
                "true_class": true_class,
                "predicted_class": predicted_class,
                "predicted_probability": round(predicted_prob, 4),
                "top2_class": top_predictions[1][0] if len(top_predictions) > 1 else "",
                "top2_probability": round(top_predictions[1][1], 4) if len(top_predictions) > 1 else "",
                "top3_class": top_predictions[2][0] if len(top_predictions) > 2 else "",
                "top3_probability": round(top_predictions[2][1], 4) if len(top_predictions) > 2 else "",
                "misclassified": misclassified,
                "low_confidence": low_confidence,
                "focus_case": in_focus,
            }
            rows.append(row)

            if misclassified:
                copy_case(image_path, args.output_dir / "misclassified" / true_class, predicted_class)
            if low_confidence:
                copy_case(image_path, args.output_dir / "low_confidence" / true_class, predicted_class)
            if in_focus:
                copy_case(image_path, args.output_dir / "focus_classes" / true_class, predicted_class)

    with open(args.output_dir / "problematic_cases.csv", "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(
            file,
            fieldnames=[
                "image_path",
                "true_class",
                "predicted_class",
                "predicted_probability",
                "top2_class",
                "top2_probability",
                "top3_class",
                "top3_probability",
                "misclassified",
                "low_confidence",
                "focus_case",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    with open(args.output_dir / "summary.json", "w", encoding="utf-8") as file:
        json.dump(summary, file, indent=2, ensure_ascii=False)

    print(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"\nDetailed report written to {args.output_dir}")


if __name__ == "__main__":
    main()
