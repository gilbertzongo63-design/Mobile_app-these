import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path

from vision_service import VisionClassifier


ROOT = Path(__file__).resolve().parent
DEFAULT_CHECKPOINT = ROOT / "training_runs" / "stage2_combined_resnet18_all_key_classes_cleaned" / "best_model.pt"
DEFAULT_DATASET = ROOT / "prepared_datasets" / "combined_6class" / "test" / "Plastic"
DEFAULT_OUTPUT = ROOT / "analysis" / "plastic_errors"


def parse_args():
    parser = argparse.ArgumentParser(description="Analyze Plastic-class errors for the active model.")
    parser.add_argument("--checkpoint", type=Path, default=DEFAULT_CHECKPOINT)
    parser.add_argument("--dataset-dir", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--top-k", type=int, default=3)
    parser.add_argument("--low-confidence-threshold", type=float, default=0.55)
    return parser.parse_args()


def confidence_band(probability: float):
    if probability >= 0.80:
        return "high"
    if probability >= 0.55:
        return "medium"
    return "low"


def main():
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    classifier = VisionClassifier(args.checkpoint)
    rows = []
    predicted_counts = Counter()
    confidence_counts = Counter()
    transition_counts = Counter()
    second_candidate_counts = Counter()
    examples_by_prediction = defaultdict(list)

    image_paths = sorted([path for path in args.dataset_dir.iterdir() if path.is_file()])
    for image_path in image_paths:
        prediction = classifier.predict(image_path, top_k=args.top_k)
        top_predictions = prediction["top_predictions"]
        top1 = top_predictions[0]
        top2 = top_predictions[1] if len(top_predictions) > 1 else {"class_name": "", "probability": 0.0}
        top3 = top_predictions[2] if len(top_predictions) > 2 else {"class_name": "", "probability": 0.0}

        predicted_class = top1["class_name"]
        predicted_probability = top1["probability"]
        is_error = predicted_class != "Plastic"
        is_low_confidence = predicted_probability < args.low_confidence_threshold

        row = {
            "image_path": str(image_path),
            "predicted_class": predicted_class,
            "predicted_probability": predicted_probability,
            "predicted_confidence_band": confidence_band(predicted_probability),
            "top2_class": top2["class_name"],
            "top2_probability": top2["probability"],
            "top3_class": top3["class_name"],
            "top3_probability": top3["probability"],
            "is_error": is_error,
            "is_low_confidence": is_low_confidence,
        }
        rows.append(row)

        predicted_counts[predicted_class] += 1
        confidence_counts[row["predicted_confidence_band"]] += 1
        transition_counts[f"Plastic -> {predicted_class}"] += 1
        if top2["class_name"]:
            second_candidate_counts[top2["class_name"]] += 1

        if len(examples_by_prediction[predicted_class]) < 10:
            examples_by_prediction[predicted_class].append(
                {
                    "image_path": str(image_path),
                    "predicted_probability": predicted_probability,
                    "top2_class": top2["class_name"],
                    "top2_probability": top2["probability"],
                    "top3_class": top3["class_name"],
                    "top3_probability": top3["probability"],
                }
            )

    with open(args.output_dir / "plastic_predictions.csv", "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(
            file,
            fieldnames=[
                "image_path",
                "predicted_class",
                "predicted_probability",
                "predicted_confidence_band",
                "top2_class",
                "top2_probability",
                "top3_class",
                "top3_probability",
                "is_error",
                "is_low_confidence",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    error_rows = [row for row in rows if row["is_error"]]
    low_conf_rows = [row for row in rows if row["is_low_confidence"]]

    summary = {
        "checkpoint": str(args.checkpoint),
        "dataset_dir": str(args.dataset_dir),
        "total_plastic_images": len(rows),
        "correct_plastic_predictions": predicted_counts.get("Plastic", 0),
        "plastic_error_count": len(error_rows),
        "plastic_low_confidence_count": len(low_conf_rows),
        "predicted_class_distribution": dict(predicted_counts),
        "confidence_distribution": dict(confidence_counts),
        "plastic_transition_counts": dict(transition_counts),
        "dominant_second_candidates": dict(second_candidate_counts.most_common()),
        "top_error_targets": [
            {
                "transition": transition,
                "count": count,
                "examples": examples_by_prediction[transition.split(" -> ", 1)[1]],
            }
            for transition, count in transition_counts.most_common()
            if transition != "Plastic -> Plastic"
        ],
    }

    with open(args.output_dir / "plastic_error_summary.json", "w", encoding="utf-8") as file:
        json.dump(summary, file, indent=2, ensure_ascii=False)

    print(json.dumps(summary, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
