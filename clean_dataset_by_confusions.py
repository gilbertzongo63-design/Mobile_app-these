import argparse
import csv
import json
import shutil
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image
import torch
from torchvision import models, transforms


ROOT = Path(__file__).resolve().parent
DEFAULT_CHECKPOINT = ROOT / "training_runs" / "stage2_combined_resnet18_all_key_classes_cleaned" / "best_model.pt"
DEFAULT_DATASET = ROOT / "prepared_datasets" / "combined_6class"
DEFAULT_OUTPUT_DATASET = ROOT / "prepared_datasets" / "combined_6class_confusion_cleaned"
DEFAULT_REPORT_DIR = ROOT / "analysis" / "confusion_cleaning"

TARGET_TRANSITIONS = {
    "PaperCardboard -> Other",
    "Plastic -> Other",
    "Metal -> Other",
    "Plastic -> Glass",
    "Metal -> Glass",
    "Glass -> Other",
}


def parse_args():
    parser = argparse.ArgumentParser(description="Create a cleaned dataset by excluding dominant confusion patterns.")
    parser.add_argument("--checkpoint", type=Path, default=DEFAULT_CHECKPOINT)
    parser.add_argument("--dataset-dir", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--output-dataset-dir", type=Path, default=DEFAULT_OUTPUT_DATASET)
    parser.add_argument("--report-dir", type=Path, default=DEFAULT_REPORT_DIR)
    parser.add_argument("--min-probability", type=float, default=0.45)
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


def score_image(model, transform, class_names, image_path: Path):
    with Image.open(image_path) as image:
        image = image.convert("RGB")
        tensor = transform(image).unsqueeze(0)
    with torch.no_grad():
        probs = torch.softmax(model(tensor), dim=1).squeeze(0)
    scores, indices = torch.topk(probs, k=min(3, len(class_names)))
    top = [(class_names[idx], float(score)) for score, idx in zip(scores.tolist(), indices.tolist())]
    return top


def main():
    args = parse_args()
    ensure_clean_dir(args.output_dataset_dir)
    ensure_clean_dir(args.report_dir)

    checkpoint = torch.load(args.checkpoint, map_location="cpu")
    class_names = checkpoint["class_names"]
    model_name = checkpoint.get("model_name", "resnet18")
    image_size = checkpoint.get("image_size", 224)
    model = build_model(model_name, len(class_names))
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()
    transform = build_transform(image_size)

    removed_rows = []
    summary = {
        "target_transitions": sorted(TARGET_TRANSITIONS),
        "min_probability": args.min_probability,
        "removed_counts_by_split": Counter(),
        "removed_counts_by_transition": Counter(),
        "kept_counts_by_split": Counter(),
    }

    for split_dir in sorted([p for p in args.dataset_dir.iterdir() if p.is_dir()]):
        split = split_dir.name
        for class_dir in sorted([p for p in split_dir.iterdir() if p.is_dir()]):
            true_class = class_dir.name
            dest_class_dir = args.output_dataset_dir / split / true_class
            dest_class_dir.mkdir(parents=True, exist_ok=True)

            for image_path in sorted([p for p in class_dir.iterdir() if p.is_file()]):
                if split == "test" or true_class not in class_names:
                    shutil.copy2(image_path, dest_class_dir / image_path.name)
                    summary["kept_counts_by_split"][split] += 1
                    continue

                top = score_image(model, transform, class_names, image_path)
                predicted_class, predicted_probability = top[0]
                transition = f"{true_class} -> {predicted_class}"
                should_remove = (
                    transition in TARGET_TRANSITIONS and predicted_probability >= args.min_probability
                )

                if should_remove:
                    removed_rows.append(
                        {
                            "split": split,
                            "image_path": str(image_path),
                            "true_class": true_class,
                            "predicted_class": predicted_class,
                            "predicted_probability": round(predicted_probability, 4),
                            "top2_class": top[1][0] if len(top) > 1 else "",
                            "top2_probability": round(top[1][1], 4) if len(top) > 1 else "",
                            "transition": transition,
                        }
                    )
                    summary["removed_counts_by_split"][split] += 1
                    summary["removed_counts_by_transition"][transition] += 1
                    continue

                shutil.copy2(image_path, dest_class_dir / image_path.name)
                summary["kept_counts_by_split"][split] += 1

    with open(args.report_dir / "removed_samples.csv", "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(
            file,
            fieldnames=[
                "split",
                "image_path",
                "true_class",
                "predicted_class",
                "predicted_probability",
                "top2_class",
                "top2_probability",
                "transition",
            ],
        )
        writer.writeheader()
        writer.writerows(removed_rows)

    summary_payload = {
        "target_transitions": summary["target_transitions"],
        "min_probability": summary["min_probability"],
        "removed_total": len(removed_rows),
        "removed_counts_by_split": dict(summary["removed_counts_by_split"]),
        "removed_counts_by_transition": dict(summary["removed_counts_by_transition"]),
        "kept_counts_by_split": dict(summary["kept_counts_by_split"]),
        "output_dataset_dir": str(args.output_dataset_dir),
    }
    with open(args.report_dir / "summary.json", "w", encoding="utf-8") as file:
        json.dump(summary_payload, file, indent=2, ensure_ascii=False)

    print(json.dumps(summary_payload, indent=2, ensure_ascii=False))
    print(f"\nCleaned dataset written to {args.output_dataset_dir}")
    print(f"Cleaning report written to {args.report_dir}")


if __name__ == "__main__":
    main()
