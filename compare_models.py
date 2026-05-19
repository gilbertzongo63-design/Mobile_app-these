import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def parse_args():
    parser = argparse.ArgumentParser(description="Compare trained classification models on key classes.")
    parser.add_argument("--model-a-dir", type=Path, required=True)
    parser.add_argument("--model-b-dir", type=Path, required=True)
    parser.add_argument(
        "--key-classes",
        nargs="+",
        default=["Plastic", "PaperCardboard", "Glass", "Metal", "Other"],
    )
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def load_metrics(run_dir: Path):
    with open(run_dir / "test_metrics.json", "r", encoding="utf-8") as file:
        metrics = json.load(file)
    with open(run_dir / "run_config.json", "r", encoding="utf-8") as file:
        config = json.load(file)
    return metrics, config


def round_or_none(value):
    if value is None:
        return None
    return round(float(value), 4)


def build_comparison(name, metrics, config, key_classes):
    per_class = metrics.get("per_class_accuracy", {})
    return {
        "run_name": name,
        "accuracy": round_or_none(metrics.get("accuracy")),
        "loss": round_or_none(metrics.get("loss")),
        "class_names": config.get("class_names", []),
        "per_class_accuracy": {class_name: round_or_none(per_class.get(class_name)) for class_name in key_classes},
    }


def winner_for_class(a_score, b_score):
    if a_score is None and b_score is None:
        return "tie"
    if a_score is None:
        return "model_b"
    if b_score is None:
        return "model_a"
    if a_score > b_score:
        return "model_a"
    if b_score > a_score:
        return "model_b"
    return "tie"


def main():
    args = parse_args()
    metrics_a, config_a = load_metrics(args.model_a_dir)
    metrics_b, config_b = load_metrics(args.model_b_dir)

    name_a = args.model_a_dir.name
    name_b = args.model_b_dir.name

    model_a = build_comparison(name_a, metrics_a, config_a, args.key_classes)
    model_b = build_comparison(name_b, metrics_b, config_b, args.key_classes)

    class_winners = {}
    for class_name in args.key_classes:
        a_score = model_a["per_class_accuracy"].get(class_name)
        b_score = model_b["per_class_accuracy"].get(class_name)
        winner = winner_for_class(a_score, b_score)
        class_winners[class_name] = {
            "winner": winner,
            name_a: a_score,
            name_b: b_score,
            "delta": None if a_score is None or b_score is None else round(a_score - b_score, 4),
        }

    overall_winner = winner_for_class(model_a["accuracy"], model_b["accuracy"])

    payload = {
        "model_a": model_a,
        "model_b": model_b,
        "overall_winner": overall_winner,
        "class_winners": class_winners,
    }

    output_path = args.output or ROOT / "training_runs" / f"comparison_{name_a}_vs_{name_b}.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as file:
        json.dump(payload, file, indent=2, ensure_ascii=False)

    print(json.dumps(payload, indent=2, ensure_ascii=False))
    print(f"\nComparison written to {output_path}")


if __name__ == "__main__":
    main()
