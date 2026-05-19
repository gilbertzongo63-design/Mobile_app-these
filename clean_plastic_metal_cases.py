import argparse
import csv
import json
import shutil
from collections import Counter
from pathlib import Path

from vision_service import VisionClassifier


ROOT = Path(__file__).resolve().parent
DEFAULT_CHECKPOINT = ROOT / "training_runs" / "stage2_combined_resnet18_plastic_refined" / "best_model.pt"
DEFAULT_DATASET_ROOT = ROOT / "prepared_datasets" / "combined_6class"
DEFAULT_OUTPUT_ROOT = ROOT / "prepared_datasets" / "combined_6class_plasticmetal_cleaned"
DEFAULT_OUTPUT_MANIFEST_DIR = ROOT / "prepared_datasets" / "combined_6class_plasticmetal_cleaned_manifest"
DEFAULT_REPORT_DIR = ROOT / "analysis" / "plastic_metal_cleaning"


def parse_args():
    parser = argparse.ArgumentParser(description="Remove Plastic->Metal confusion cases from train/val splits.")
    parser.add_argument("--checkpoint", type=Path, default=DEFAULT_CHECKPOINT)
    parser.add_argument("--dataset-root", type=Path, default=DEFAULT_DATASET_ROOT)
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT)
    parser.add_argument("--output-manifest-dir", type=Path, default=DEFAULT_OUTPUT_MANIFEST_DIR)
    parser.add_argument("--report-dir", type=Path, default=DEFAULT_REPORT_DIR)
    parser.add_argument("--top-k", type=int, default=3)
    parser.add_argument("--remove-predicted-class", default="Metal")
    parser.add_argument("--target-class", default="Plastic")
    parser.add_argument("--splits", nargs="+", default=["train", "val"])
    return parser.parse_args()


def ensure_clean_dir(path: Path):
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def copy_dataset_tree(source_root: Path, target_root: Path):
    if target_root.exists():
        shutil.rmtree(target_root)
    shutil.copytree(source_root, target_root)


def main():
    args = parse_args()
    ensure_clean_dir(args.report_dir)
    args.output_manifest_dir.mkdir(parents=True, exist_ok=True)

    classifier = VisionClassifier(args.checkpoint)
    target_splits = set(args.splits)
    remove_set = set()
    removed_records = []
    counts_by_split = Counter()

    for split in sorted(target_splits):
        class_dir = args.dataset_root / split / args.target_class
        if not class_dir.exists():
            continue

        for image_path in sorted([path for path in class_dir.iterdir() if path.is_file()]):
            prediction = classifier.predict(image_path, top_k=args.top_k)
            top1 = prediction["top_predictions"][0]
            if top1["class_name"] != args.remove_predicted_class:
                continue

            relative_image_path = image_path.relative_to(args.dataset_root)
            remove_set.add(relative_image_path.as_posix())
            counts_by_split[split] += 1
            removed_records.append(
                {
                    "sample_id": f"{split}_{args.target_class}_{image_path.name}",
                    "split": split,
                    "image_path": str(relative_image_path).replace("\\", "/"),
                    "predicted_class": top1["class_name"],
                    "predicted_probability": top1["probability"],
                    "top2_class": prediction["top_predictions"][1]["class_name"] if len(prediction["top_predictions"]) > 1 else "",
                    "top2_probability": prediction["top_predictions"][1]["probability"] if len(prediction["top_predictions"]) > 1 else "",
                }
            )

    copy_dataset_tree(args.dataset_root, args.output_root)

    for relative_path in remove_set:
        target_path = args.output_root / Path(relative_path)
        if target_path.exists():
            target_path.unlink()

    manifest_path = args.output_manifest_dir / "annotations_unified.csv"
    manifest_rows = []
    fieldnames = [
        "sample_id",
        "source_dataset",
        "annotation_type",
        "split",
        "final_class",
        "source_label",
        "image_path",
        "crop_path",
        "source_image_path",
        "image_width",
        "image_height",
        "bbox_x",
        "bbox_y",
        "bbox_width",
        "bbox_height",
        "image_id",
        "annotation_id",
    ]
    split_counts = {}
    for split_dir in sorted([path for path in args.output_root.iterdir() if path.is_dir()]):
        split = split_dir.name
        split_counts.setdefault(split, Counter())
        for class_dir in sorted([path for path in split_dir.iterdir() if path.is_dir()]):
            class_name = class_dir.name
            for image_path in sorted([path for path in class_dir.iterdir() if path.is_file()]):
                relative_path = image_path.relative_to(ROOT).as_posix()
                manifest_rows.append(
                    {
                        "sample_id": f"cleaned_{split}_{class_name}_{image_path.name}",
                        "source_dataset": "CombinedCleaned",
                        "annotation_type": "image_classification",
                        "split": split,
                        "final_class": class_name,
                        "source_label": class_name,
                        "image_path": relative_path,
                        "crop_path": "",
                        "source_image_path": relative_path,
                        "image_width": "",
                        "image_height": "",
                        "bbox_x": "",
                        "bbox_y": "",
                        "bbox_width": "",
                        "bbox_height": "",
                        "image_id": "",
                        "annotation_id": "",
                    }
                )
                split_counts[split][class_name] += 1

    with open(manifest_path, "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(manifest_rows)

    summary = {
        "checkpoint": str(args.checkpoint),
        "target_class": args.target_class,
        "removed_predicted_class": args.remove_predicted_class,
        "splits_cleaned": sorted(target_splits),
        "removed_count": len(removed_records),
        "removed_count_by_split": dict(counts_by_split),
        "output_dataset_root": str(args.output_root),
        "output_manifest": str(manifest_path),
        "manifest_row_count": len(manifest_rows),
        "remaining_split_counts": {split: dict(counter) for split, counter in split_counts.items()},
    }

    with open(args.report_dir / "removed_plastic_metal_cases.csv", "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(
            file,
            fieldnames=[
                "sample_id",
                "split",
                "image_path",
                "predicted_class",
                "predicted_probability",
                "top2_class",
                "top2_probability",
            ],
        )
        writer.writeheader()
        writer.writerows(removed_records)

    with open(args.report_dir / "summary.json", "w", encoding="utf-8") as file:
        json.dump(summary, file, indent=2, ensure_ascii=False)

    with open(args.output_manifest_dir / "summary.json", "w", encoding="utf-8") as file:
        json.dump(summary, file, indent=2, ensure_ascii=False)

    print(json.dumps(summary, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
