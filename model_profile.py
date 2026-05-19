from pathlib import Path


ROOT = Path(__file__).resolve().parent

ACTIVE_MODEL_PROFILE = {
    "name": "stage2_combined_resnet18_plastic_refined",
    "checkpoint": ROOT / "training_runs" / "stage2_combined_resnet18_plastic_refined" / "best_model.pt",
    "policy": {
        "high_confidence_threshold": 0.80,
        "medium_confidence_threshold": 0.55,
        "ocr_support_threshold": 0.45,
        "other_fallback_min_top2": 0.18,
        "other_fallback_max_gap": 0.18,
        "prefer_top2_for_other": True,
        "prefer_recyclable_over_other": True,
        "allow_preferred_fallback_below_top2_without_ocr": False,
        "other_bias_max_top1_probability": 0.42,
        "other_bias_max_gap_to_top1": 0.16,
        "other_risk_classes": ["Plastic", "Glass", "PaperCardboard", "Metal"],
        "preferred_other_fallback_classes": {
            "Plastic": {
                "min_top2_probability": 0.22,
                "max_gap_to_top1": 0.17,
                "max_gap_to_best_non_other": 0.03,
                "priority": 2,
            },
            "Glass": {
                "min_top2_probability": 0.18,
                "max_gap_to_top1": 0.32,
                "max_gap_to_best_non_other": 0.02,
                "priority": 3,
            },
        },
        "strong_keep_classes": {
            "PaperCardboard": 0.82,
            "Metal": 0.80,
            "Glass": 0.84,
            "Plastic": 0.86,
        },
        "class_bias": {
            "Plastic": 1.10,
            "Glass": 1.08,
            "PaperCardboard": 1.06,
            "Metal": 1.01,
            "Other": 0.95,
        },
    },
}
