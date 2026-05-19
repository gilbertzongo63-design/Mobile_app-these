import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DEFAULT_WEIGHTS = {
    "Plastic": 0.30,
    "PaperCardboard": 0.25,
    "Glass": 0.15,
    "Metal": 0.15,
    "Other": 0.15,
}


def parse_args():
    parser = argparse.ArgumentParser(description="Choose the best model using business-priority weights.")
    parser.add_argument("--model-dirs", nargs="+", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--weights-json",
        type=Path,
        help="Optional JSON file with class weights, e.g. {\"Plastic\": 0.4, ...}",
    )
    return parser.parse_args()


def load_weights(weights_json: Path | None):
    if not weights_json:
        return DEFAULT_WEIGHTS
    with open(weights_json, "r", encoding="utf-8") as file:
        return json.load(file)


def load_run(run_dir: Path):
    with open(run_dir / "test_metrics.json", "r", encoding="utf-8") as file:
        metrics = json.load(file)
    with open(run_dir / "run_config.json", "r", encoding="utf-8") as file:
        config = json.load(file)
    return metrics, config


def score_run(run_dir: Path, weights):
    metrics, config = load_run(run_dir)
    per_class = metrics.get("per_class_accuracy", {})
    weighted_score = 0.0
    used_weights = 0.0
    class_breakdown = {}

    for class_name, weight in weights.items():
        score = per_class.get(class_name)
        contribution = 0.0 if score is None else score * weight
        if score is not None:
            used_weights += weight
        weighted_score += contribution
        class_breakdown[class_name] = {
            "weight": weight,
            "accuracy": score,
            "contribution": round(contribution, 4),
        }

    normalized_score = weighted_score / used_weights if used_weights else 0.0

    return {
        "run_name": run_dir.name,
        "run_dir": str(run_dir),
        "overall_accuracy": round(metrics.get("accuracy", 0.0), 4),
        "loss": round(metrics.get("loss", 0.0), 4),
        "weighted_business_score": round(normalized_score, 4),
        "raw_weighted_sum": round(weighted_score, 4),
        "class_breakdown": class_breakdown,
        "class_names": config.get("class_names", []),
    }


def main():
    args = parse_args()
    weights = load_weights(args.weights_json)

    ranked = [score_run(run_dir, weights) for run_dir in args.model_dirs]
    ranked.sort(
        key=lambda item: (item["weighted_business_score"], item["overall_accuracy"], -item["loss"]),
        reverse=True,
    )

    payload = {
        "weights": weights,
        "recommended_model": ranked[0] if ranked else None,
        "ranking": ranked,
        "selection_rule": "Highest weighted business score, then overall accuracy, then lower loss.",
    }

    output_path = args.output or ROOT / "training_runs" / "business_priority_model_selection.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as file:
        json.dump(payload, file, indent=2, ensure_ascii=False)

    print(json.dumps(payload, indent=2, ensure_ascii=False))
    print(f"\nSelection written to {output_path}")


if __name__ == "__main__":
    main()
