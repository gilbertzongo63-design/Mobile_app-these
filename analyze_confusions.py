import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DEFAULT_CASES = ROOT / "analysis" / "problematic_cases" / "problematic_cases.csv"
DEFAULT_OUTPUT = ROOT / "analysis" / "problematic_cases" / "confusion_analysis.json"


def parse_args():
    parser = argparse.ArgumentParser(description="Analyze dominant confusion patterns from problematic cases.")
    parser.add_argument("--cases-csv", type=Path, default=DEFAULT_CASES)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--top-n", type=int, default=10)
    return parser.parse_args()


def load_rows(path: Path):
    with open(path, "r", encoding="utf-8", newline="") as file:
        return list(csv.DictReader(file))


def to_bool(value: str) -> bool:
    return str(value).strip().lower() == "true"


def main():
    args = parse_args()
    rows = load_rows(args.cases_csv)

    confusion_counter = Counter()
    low_conf_counter = Counter()
    true_class_counter = Counter()
    predicted_class_counter = Counter()
    focus_transition_counter = Counter()
    examples_by_confusion = defaultdict(list)

    for row in rows:
        true_class = row["true_class"]
        predicted_class = row["predicted_class"]
        true_class_counter[true_class] += 1
        predicted_class_counter[predicted_class] += 1

        if to_bool(row["misclassified"]):
            key = f"{true_class} -> {predicted_class}"
            confusion_counter[key] += 1
            if len(examples_by_confusion[key]) < 5:
                examples_by_confusion[key].append(
                    {
                        "image_path": row["image_path"],
                        "predicted_probability": float(row["predicted_probability"]),
                        "top2_class": row["top2_class"],
                        "top2_probability": row["top2_probability"],
                    }
                )

        if to_bool(row["low_confidence"]):
            low_conf_counter[true_class] += 1

        if true_class in {"Plastic", "Glass", "Other", "PaperCardboard", "Metal"} or predicted_class in {
            "Plastic",
            "Glass",
            "Other",
            "PaperCardboard",
            "Metal",
        }:
            focus_transition_counter[f"{true_class} -> {predicted_class}"] += 1

    top_confusions = []
    for key, count in confusion_counter.most_common(args.top_n):
        top_confusions.append(
            {
                "transition": key,
                "count": count,
                "examples": examples_by_confusion[key],
            }
        )

    payload = {
        "source_csv": str(args.cases_csv),
        "total_problematic_rows": len(rows),
        "top_confusions": top_confusions,
        "misclassification_counts_by_true_class": dict(true_class_counter.most_common()),
        "low_confidence_counts_by_true_class": dict(low_conf_counter.most_common()),
        "dominant_predicted_classes_in_problem_cases": dict(predicted_class_counter.most_common()),
        "focus_transitions": dict(focus_transition_counter.most_common(args.top_n)),
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as file:
        json.dump(payload, file, indent=2, ensure_ascii=False)

    print(json.dumps(payload, indent=2, ensure_ascii=False))
    print(f"\nConfusion analysis written to {args.output}")


if __name__ == "__main__":
    main()
