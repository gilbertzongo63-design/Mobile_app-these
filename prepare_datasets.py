import csv
import json
import random
import shutil
import zipfile
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parent
TRASHNET_DATA = ROOT / "trashnet-master" / "trashnet-master" / "data"
TACO_DATA = ROOT / "TACO-master" / "TACO-master" / "data"

FINAL_CLASSES = [
    "Plastic",
    "Glass",
    "PaperCardboard",
    "Metal",
    "Organic",
    "Other",
]

TRASHNET_MAPPING = {
    "plastic": "Plastic",
    "glass": "Glass",
    "paper": "PaperCardboard",
    "cardboard": "PaperCardboard",
    "metal": "Metal",
    "trash": "Other",
}

TACO_MAPPING = {
    "Aluminium foil": "Metal",
    "Battery": "Other",
    "Aluminium blister pack": "Metal",
    "Carded blister pack": "Other",
    "Other plastic bottle": "Plastic",
    "Clear plastic bottle": "Plastic",
    "Glass bottle": "Glass",
    "Plastic bottle cap": "Plastic",
    "Metal bottle cap": "Metal",
    "Broken glass": "Glass",
    "Food Can": "Metal",
    "Aerosol": "Metal",
    "Drink can": "Metal",
    "Toilet tube": "PaperCardboard",
    "Other carton": "PaperCardboard",
    "Egg carton": "PaperCardboard",
    "Drink carton": "PaperCardboard",
    "Corrugated carton": "PaperCardboard",
    "Meal carton": "PaperCardboard",
    "Pizza box": "PaperCardboard",
    "Paper cup": "PaperCardboard",
    "Disposable plastic cup": "Plastic",
    "Foam cup": "Other",
    "Glass cup": "Glass",
    "Other plastic cup": "Plastic",
    "Food waste": "Organic",
    "Glass jar": "Glass",
    "Plastic lid": "Plastic",
    "Metal lid": "Metal",
    "Other plastic": "Plastic",
    "Magazine paper": "PaperCardboard",
    "Tissues": "PaperCardboard",
    "Wrapping paper": "PaperCardboard",
    "Normal paper": "PaperCardboard",
    "Paper bag": "PaperCardboard",
    "Plastified paper bag": "PaperCardboard",
    "Plastic film": "Plastic",
    "Six pack rings": "Plastic",
    "Garbage bag": "Other",
    "Other plastic wrapper": "Plastic",
    "Single-use carrier bag": "Plastic",
    "Polypropylene bag": "Plastic",
    "Crisp packet": "Other",
    "Spread tub": "Plastic",
    "Tupperware": "Plastic",
    "Disposable food container": "Other",
    "Foam food container": "Other",
    "Other plastic container": "Plastic",
    "Plastic glooves": "Plastic",
    "Plastic utensils": "Plastic",
    "Pop tab": "Metal",
    "Rope & strings": "Other",
    "Scrap metal": "Metal",
    "Shoe": "Other",
    "Squeezable tube": "Plastic",
    "Plastic straw": "Plastic",
    "Paper straw": "PaperCardboard",
    "Styrofoam piece": "Other",
    "Unlabeled litter": "Other",
    "Cigarette": "Other",
}

# These TACO categories add strong visual noise to the Plastic class for a
# simple image classifier. We keep the final classes simple by excluding
# tiny/flat/ambiguous plastic items that do not align well with TrashNet's
# plastic examples.
TACO_EXCLUDED_CATEGORIES = {
    "Plastic bottle cap",
    "Plastic lid",
    "Plastic film",
    "Other plastic wrapper",
    "Single-use carrier bag",
    "Polypropylene bag",
    "Plastic straw",
    "Plastic glooves",
    "Plastic utensils",
    "Six pack rings",
    "Other plastic",
    "Paper cup",
    "Tissues",
    "Wrapping paper",
    "Paper straw",
    "Toilet tube",
    "Drink carton",
    "Meal carton",
    "Broken glass",
    "Glass cup",
    "Glass jar",
    "Metal bottle cap",
    "Metal lid",
    "Pop tab",
    "Aluminium blister pack",
    "Scrap metal",
    "Aluminium foil",
    "Battery",
    "Carded blister pack",
    "Rope & strings",
    "Cigarette",
    "Shoe",
    "Unlabeled litter",
    "Foam cup",
    "Foam food container",
    "Disposable food container",
}

SPLITS = {"train": 0.70, "val": 0.15, "test": 0.15}
RANDOM_SEED = 42
MIN_TACO_BBOX_WIDTH = 40
MIN_TACO_BBOX_HEIGHT = 40
MIN_TACO_AREA_RATIO = 0.003
UNIFIED_FIELDNAMES = [
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


def ensure_clean_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def stratified_split(records, class_key):
    rng = random.Random(RANDOM_SEED)
    grouped = defaultdict(list)
    for record in records:
        grouped[record[class_key]].append(record)

    split_records = {split: [] for split in SPLITS}
    for class_name, items in grouped.items():
        rng.shuffle(items)
        total = len(items)
        train_end = int(total * SPLITS["train"])
        val_end = train_end + int(total * SPLITS["val"])

        split_records["train"].extend(items[:train_end])
        split_records["val"].extend(items[train_end:val_end])
        split_records["test"].extend(items[val_end:])

        if total and not split_records["train"]:
            raise RuntimeError(f"Unexpected empty train split for {class_name}")
    return split_records


def extract_trashnet_zip():
    zip_path = TRASHNET_DATA / "dataset-resized.zip"
    extract_root = TRASHNET_DATA / "dataset-resized"
    if extract_root.exists():
        return extract_root

    with zipfile.ZipFile(zip_path) as archive:
        for member in archive.infolist():
            name = member.filename
            if name.startswith("__MACOSX") or name.endswith(".DS_Store"):
                continue
            archive.extract(member, TRASHNET_DATA)
    return extract_root


def prepare_trashnet():
    source_root = extract_trashnet_zip()
    output_root = TRASHNET_DATA / "filtered_6class"
    ensure_clean_dir(output_root)

    records = []
    excluded = []
    for source_class, final_class in TRASHNET_MAPPING.items():
        class_dir = source_root / source_class
        if not class_dir.exists():
            excluded.append({"reason": "missing_source_dir", "source_class": source_class})
            continue
        for image_path in sorted(class_dir.glob("*.jpg")):
            records.append(
                {
                    "source": "TrashNet",
                    "source_class": source_class,
                    "final_class": final_class,
                    "image_path": image_path,
                    "file_name": image_path.name,
                }
            )

    split_records = stratified_split(records, "final_class")
    unified_rows = []
    for split, items in split_records.items():
        for item in items:
            destination_dir = output_root / split / item["final_class"]
            destination_dir.mkdir(parents=True, exist_ok=True)
            destination_path = destination_dir / item["file_name"]
            shutil.copy2(item["image_path"], destination_path)
            row = empty_unified_row()
            row.update(
                {
                    "sample_id": f"trashnet_{split}_{item['file_name']}",
                    "source_dataset": "TrashNet",
                    "annotation_type": "image_classification",
                    "split": split,
                    "final_class": item["final_class"],
                    "source_label": item["source_class"],
                    "image_path": to_relative(destination_path),
                    "source_image_path": to_relative(item["image_path"]),
                }
            )
            unified_rows.append(row)

    write_csv(output_root / "annotations_unified.csv", unified_rows, UNIFIED_FIELDNAMES)
    write_json(output_root / "annotations_unified.json", unified_rows)

    write_json(
        output_root / "summary.json",
        {
            "dataset": "TrashNet",
            "final_classes": FINAL_CLASSES,
            "source_counts": dict(Counter(r["source_class"] for r in records)),
            "final_counts": dict(Counter(r["final_class"] for r in records)),
            "split_counts": {
                split: dict(Counter(r["final_class"] for r in items))
                for split, items in split_records.items()
            },
            "excluded": excluded,
        },
    )


def load_taco_annotations():
    with open(TACO_DATA / "annotations.json", "r", encoding="utf-8") as file:
        return json.load(file)


def should_keep_taco_annotation(annotation, image_info, category_name):
    bbox = annotation.get("bbox", [])
    if category_name in TACO_EXCLUDED_CATEGORIES:
        return False, "excluded_noisy_category"
    if annotation.get("iscrowd", 0):
        return False, "iscrowd"
    if len(bbox) != 4:
        return False, "missing_bbox"

    _, _, width, height = bbox
    if width < MIN_TACO_BBOX_WIDTH or height < MIN_TACO_BBOX_HEIGHT:
        return False, "bbox_too_small"

    image_area = max(1, image_info["width"] * image_info["height"])
    area_ratio = float(annotation.get("area", width * height)) / image_area
    if area_ratio < MIN_TACO_AREA_RATIO:
        return False, "area_ratio_too_small"

    if category_name not in TACO_MAPPING:
        return False, "unmapped_category"

    return True, "kept"


def write_json(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as file:
        json.dump(payload, file, indent=2, ensure_ascii=False)


def write_csv(path: Path, rows, fieldnames):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def to_relative(path: Path) -> str:
    return path.resolve().relative_to(ROOT.resolve()).as_posix()


def empty_unified_row():
    return {field: "" for field in UNIFIED_FIELDNAMES}


def prepare_taco():
    taco = load_taco_annotations()
    output_root = TACO_DATA / "filtered_classification"
    ensure_clean_dir(output_root)

    categories = {c["id"]: c["name"] for c in taco["categories"]}
    images = {img["id"]: img for img in taco["images"]}

    kept_annotations = []
    rejected_annotations = []
    candidate_rows = []

    for annotation in taco["annotations"]:
        category_name = categories[annotation["category_id"]]
        image_info = images[annotation["image_id"]]
        keep, reason = should_keep_taco_annotation(annotation, image_info, category_name)
        if not keep:
            rejected_annotations.append(
                {
                    "annotation_id": annotation["id"],
                    "image_id": annotation["image_id"],
                    "file_name": image_info["file_name"],
                    "category_name": category_name,
                    "reason": reason,
                }
            )
            continue

        mapped_class = TACO_MAPPING[category_name]
        record = {
            "annotation_id": annotation["id"],
            "image_id": annotation["image_id"],
            "file_name": image_info["file_name"],
            "category_name": category_name,
            "final_class": mapped_class,
            "bbox": annotation["bbox"],
            "area": annotation.get("area"),
            "image_width": image_info["width"],
            "image_height": image_info["height"],
        }
        kept_annotations.append(annotation)
        candidate_rows.append(record)

    split_records = stratified_split(candidate_rows, "final_class")
    split_by_annotation_id = {
        row["annotation_id"]: split
        for split, rows in split_records.items()
        for row in rows
    }
    for row in candidate_rows:
        row["split"] = split_by_annotation_id[row["annotation_id"]]

    kept_image_ids = sorted({a["image_id"] for a in kept_annotations})
    kept_images = [images[image_id] for image_id in kept_image_ids]

    filtered_payload = {
        "info": taco.get("info", {}),
        "licenses": taco.get("licenses", []),
        "images": kept_images,
        "annotations": kept_annotations,
        "categories": taco["categories"],
        "final_class_mapping": TACO_MAPPING,
        "recommended_final_classes": FINAL_CLASSES,
    }
    write_json(output_root / "annotations_filtered.json", filtered_payload)
    write_json(output_root / "class_mapping.json", TACO_MAPPING)
    write_json(
        output_root / "rejected_annotations.json",
        {
            "thresholds": {
                "min_bbox_width": MIN_TACO_BBOX_WIDTH,
                "min_bbox_height": MIN_TACO_BBOX_HEIGHT,
                "min_area_ratio": MIN_TACO_AREA_RATIO,
            },
            "rejected_annotations": rejected_annotations,
        },
    )
    write_csv(
        output_root / "candidate_crops.csv",
        candidate_rows,
        [
            "annotation_id",
            "image_id",
            "file_name",
            "category_name",
            "final_class",
            "bbox",
            "area",
            "image_width",
            "image_height",
            "split",
        ],
    )

    image_root_exists = any((TACO_DATA / image["file_name"]).exists() for image in kept_images[:25])
    cropped_count = 0
    crop_failures = []
    unified_rows = []
    if image_root_exists:
        try:
            from PIL import Image
        except ImportError:
            crop_failures.append("Pillow_not_installed")
        else:
            for row in candidate_rows:
                source_path = TACO_DATA / row["file_name"]
                if not source_path.exists():
                    crop_failures.append(f"missing_image:{row['file_name']}")
                    continue
                x, y, width, height = row["bbox"]
                dest_dir = output_root / "crops" / row["split"] / row["final_class"]
                dest_dir.mkdir(parents=True, exist_ok=True)
                dest_name = f"{Path(row['file_name']).stem}_ann{row['annotation_id']}.jpg"
                dest_path = dest_dir / dest_name
                with Image.open(source_path) as image:
                    crop = image.crop((int(x), int(y), int(x + width), int(y + height)))
                    crop.save(dest_path, quality=95)
                    cropped_count += 1
                unified_row = empty_unified_row()
                unified_row.update(
                    {
                        "sample_id": f"taco_{row['annotation_id']}",
                        "source_dataset": "TACO",
                        "annotation_type": "cropped_object_classification",
                        "split": row["split"],
                        "final_class": row["final_class"],
                        "source_label": row["category_name"],
                        "image_path": to_relative(dest_path),
                        "crop_path": to_relative(dest_path),
                        "source_image_path": to_relative(source_path),
                        "image_width": row["image_width"],
                        "image_height": row["image_height"],
                        "bbox_x": row["bbox"][0],
                        "bbox_y": row["bbox"][1],
                        "bbox_width": row["bbox"][2],
                        "bbox_height": row["bbox"][3],
                        "image_id": row["image_id"],
                        "annotation_id": row["annotation_id"],
                    }
                )
                unified_rows.append(unified_row)
    else:
        crop_failures.append("taco_images_not_downloaded")

    write_csv(output_root / "annotations_unified.csv", unified_rows, UNIFIED_FIELDNAMES)
    write_json(output_root / "annotations_unified.json", unified_rows)

    write_json(
        output_root / "summary.json",
        {
            "dataset": "TACO",
            "final_classes": FINAL_CLASSES,
            "thresholds": {
                "min_bbox_width": MIN_TACO_BBOX_WIDTH,
                "min_bbox_height": MIN_TACO_BBOX_HEIGHT,
                "min_area_ratio": MIN_TACO_AREA_RATIO,
            },
            "kept_annotation_count": len(candidate_rows),
            "kept_image_count": len(kept_images),
            "rejected_annotation_count": len(rejected_annotations),
            "kept_original_category_counts": dict(Counter(r["category_name"] for r in candidate_rows)),
            "kept_final_class_counts": dict(Counter(r["final_class"] for r in candidate_rows)),
            "split_counts": {
                split: dict(Counter(r["final_class"] for r in rows))
                for split, rows in split_records.items()
            },
            "crop_status": {
                "cropped_count": cropped_count,
                "notes": sorted(set(crop_failures)),
            },
        },
    )


def build_combined_manifest():
    manifest_root = ROOT / "prepared_datasets"
    manifest_root.mkdir(parents=True, exist_ok=True)
    combined_root = manifest_root / "combined_6class"
    ensure_clean_dir(combined_root)

    manifest_paths = [
        TRASHNET_DATA / "filtered_6class" / "annotations_unified.csv",
        TACO_DATA / "filtered_classification" / "annotations_unified.csv",
    ]

    combined_rows = []
    for manifest_path in manifest_paths:
        if not manifest_path.exists():
            continue
        with open(manifest_path, "r", encoding="utf-8", newline="") as file:
            reader = csv.DictReader(file)
            combined_rows.extend(reader)

    write_csv(manifest_root / "annotations_unified.csv", combined_rows, UNIFIED_FIELDNAMES)
    write_json(manifest_root / "annotations_unified.json", combined_rows)

    split_counts = defaultdict(Counter)
    source_counts = defaultdict(Counter)
    for row in combined_rows:
        split_counts[row["split"]][row["final_class"]] += 1
        source_counts[row["source_dataset"]][row["final_class"]] += 1
        source_path = ROOT / row["image_path"]
        if not source_path.exists():
            continue
        destination_dir = combined_root / row["split"] / row["final_class"]
        destination_dir.mkdir(parents=True, exist_ok=True)
        destination_path = destination_dir / Path(row["image_path"]).name
        if destination_path.exists():
            stem = destination_path.stem
            suffix = destination_path.suffix
            destination_path = destination_dir / f"{stem}_{row['sample_id']}{suffix}"
        shutil.copy2(source_path, destination_path)

    write_json(
        manifest_root / "summary.json",
        {
            "final_classes": FINAL_CLASSES,
            "fieldnames": UNIFIED_FIELDNAMES,
            "total_samples": len(combined_rows),
            "combined_dataset_root": to_relative(combined_root),
            "split_counts": {split: dict(counter) for split, counter in split_counts.items()},
            "source_counts": {source: dict(counter) for source, counter in source_counts.items()},
        },
    )


def main():
    prepare_trashnet()
    prepare_taco()
    build_combined_manifest()
    print("Datasets prepared successfully.")


if __name__ == "__main__":
    main()
