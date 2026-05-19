def _find_preferred_other_fallback(
    top_predictions,
    vision_conf,
    preferred_rules,
    default_min_prob,
    default_max_gap,
    ocr_class=None,
    allow_below_top2_without_ocr=False,
):
    best_non_other_probability = 0.0
    for candidate in top_predictions[1:]:
        if candidate["class_name"] == "Other":
            continue
        best_non_other_probability = max(best_non_other_probability, candidate["probability"])

    candidates = []
    for rank, candidate in enumerate(top_predictions[1:], start=2):
        class_name = candidate["class_name"]
        rule = preferred_rules.get(class_name)
        if not rule:
            continue

        min_probability = rule.get("min_top2_probability", default_min_prob)
        max_gap = rule.get("max_gap_to_top1", default_max_gap)
        max_gap_to_best_non_other = rule.get("max_gap_to_best_non_other")
        gap = vision_conf - candidate["probability"]
        if candidate["probability"] < min_probability or gap > max_gap:
            continue
        if (
            max_gap_to_best_non_other is not None
            and best_non_other_probability > 0
            and (best_non_other_probability - candidate["probability"]) > max_gap_to_best_non_other
        ):
            continue
        if rank > 2 and not allow_below_top2_without_ocr and ocr_class != class_name:
            continue

        candidates.append(
            {
                "rank": rank,
                "class_name": class_name,
                "probability": candidate["probability"],
                "gap_to_top1": gap,
                "priority": rule.get("priority", 100),
            }
        )

    if not candidates:
        return None

    candidates.sort(key=lambda item: (-item["probability"], item["priority"], item["rank"]))
    return candidates[0]


def fuse_predictions(vision_result, ocr_result, policy=None):
    policy = policy or {}
    high_conf_threshold = policy.get("high_confidence_threshold", 0.80)
    medium_conf_threshold = policy.get("medium_confidence_threshold", 0.55)
    ocr_support_threshold = policy.get("ocr_support_threshold", 0.45)
    other_fallback_min_top2 = policy.get("other_fallback_min_top2", 0.18)
    other_fallback_max_gap = policy.get("other_fallback_max_gap", 0.18)
    prefer_top2_for_other = policy.get("prefer_top2_for_other", True)
    prefer_recyclable_over_other = policy.get("prefer_recyclable_over_other", True)
    other_bias_max_top1_probability = policy.get("other_bias_max_top1_probability")
    other_bias_max_gap_to_top1 = policy.get("other_bias_max_gap_to_top1")
    other_risk_classes = set(policy.get("other_risk_classes", []))
    preferred_other_fallback_classes = policy.get("preferred_other_fallback_classes", {})
    allow_below_top2_without_ocr = policy.get("allow_preferred_fallback_below_top2_without_ocr", False)
    strong_keep_classes = policy.get("strong_keep_classes", {})

    top_predictions = vision_result["top_predictions"]
    top1 = top_predictions[0]
    top2 = top_predictions[1] if len(top_predictions) > 1 else None
    vision_class = top1["class_name"]
    vision_conf = top1["probability"]
    ocr_class = ocr_result["predicted_class"]
    ocr_conf = ocr_result["confidence"]

    decision = {
        "status": "accepted",
        "recommended_class": vision_class,
        "model_top1_class": vision_class,
        "reason": "vision_top1",
        "final_confidence": vision_conf,
    }

    strong_keep_threshold = strong_keep_classes.get(vision_class)
    if strong_keep_threshold is not None and vision_conf >= strong_keep_threshold:
        decision["reason"] = "strong_class_specific_vision_top1"
        return decision

    if vision_conf >= high_conf_threshold:
        if ocr_class and ocr_class == vision_class:
            decision["reason"] = "vision_strong_confirmed_by_ocr"
            decision["final_confidence"] = round(min(0.99, vision_conf + 0.05), 4)
        return decision

    if ocr_class and ocr_class == vision_class:
        decision["reason"] = "vision_confirmed_by_ocr"
        decision["final_confidence"] = round(min(0.95, max(vision_conf, ocr_conf) + 0.08), 4)
        return decision

    if vision_class == "Other" and ocr_class and ocr_conf >= ocr_support_threshold:
        decision["status"] = "adjusted"
        decision["recommended_class"] = ocr_class
        decision["reason"] = "vision_other_replaced_by_ocr"
        decision["alternative_class"] = vision_class
        decision["alternative_probability"] = vision_conf
        decision["final_confidence"] = round(max(ocr_conf, vision_conf), 4)
        return decision

    if vision_conf < medium_conf_threshold:
        decision["status"] = "review"
        decision["reason"] = "low_confidence_vision"
        if ocr_class and ocr_conf >= ocr_support_threshold:
            decision["status"] = "adjusted"
            decision["recommended_class"] = ocr_class
            decision["reason"] = "low_confidence_vision_supported_by_ocr"
            decision["final_confidence"] = round(max(vision_conf, ocr_conf), 4)
            return decision
        if (
            top2
            and vision_class == "Other"
            and top2["class_name"] != "Other"
            and top2["probability"] >= other_fallback_min_top2
            and (vision_conf - top2["probability"]) <= other_fallback_max_gap
            and prefer_top2_for_other
        ):
            decision["recommended_class"] = top2["class_name"]
            decision["reason"] = "low_confidence_other_fallback"
            decision["final_confidence"] = top2["probability"]

    if vision_class == "Other":
        preferred_candidate = _find_preferred_other_fallback(
            top_predictions,
            vision_conf,
            preferred_other_fallback_classes,
            other_fallback_min_top2,
            other_fallback_max_gap,
            ocr_class=ocr_class,
            allow_below_top2_without_ocr=allow_below_top2_without_ocr,
        )
        if preferred_candidate:
            decision["status"] = "review"
            decision["recommended_class"] = preferred_candidate["class_name"]
            decision["reason"] = "preferred_class_other_fallback"
            decision["final_confidence"] = preferred_candidate["probability"]
            decision["preferred_candidate_rank"] = preferred_candidate["rank"]
            decision["preferred_candidate_gap_to_top1"] = round(preferred_candidate["gap_to_top1"], 4)

    if (
        prefer_recyclable_over_other
        and top2
        and vision_class == "Other"
        and decision["reason"] != "preferred_class_other_fallback"
        and top2["class_name"] in other_risk_classes
        and top2["probability"] >= other_fallback_min_top2
        and (other_bias_max_top1_probability is None or vision_conf <= other_bias_max_top1_probability)
        and (
            other_bias_max_gap_to_top1 is None
            or (vision_conf - top2["probability"]) <= other_bias_max_gap_to_top1
        )
    ):
        decision["status"] = "review"
        decision["recommended_class"] = top2["class_name"]
        decision["reason"] = "other_bias_recycled_fallback"
        decision["final_confidence"] = top2["probability"]

    if top2 is not None:
        decision["second_candidate"] = top2["class_name"]
        decision["second_candidate_probability"] = top2["probability"]

    return decision
