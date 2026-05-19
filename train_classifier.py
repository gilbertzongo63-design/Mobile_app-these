import argparse
import csv
import json
import time
from collections import Counter
from pathlib import Path

from PIL import Image
import torch
from torch import nn
from torch.optim import AdamW
from torch.optim.lr_scheduler import ReduceLROnPlateau
from torch.utils.data import DataLoader, Dataset, WeightedRandomSampler
from torchvision import models, transforms


ROOT = Path(__file__).resolve().parent
DATASET_DIR = ROOT / "prepared_datasets"
MANIFEST_PATH = DATASET_DIR / "annotations_unified.csv"
SUMMARY_PATH = DATASET_DIR / "summary.json"
OUTPUT_ROOT = ROOT / "training_runs"


def parse_args():
    parser = argparse.ArgumentParser(description="Train a waste classification model from the unified manifest.")
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH)
    parser.add_argument("--summary", type=Path, default=SUMMARY_PATH)
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_ROOT / "baseline_mobilenet_v3_small")
    parser.add_argument("--epochs", type=int, default=5)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--num-workers", type=int, default=0)
    parser.add_argument("--image-size", type=int, default=224)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--weight-decay", type=float, default=1e-4)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--model", choices=["mobilenet_v3_small", "resnet18"], default="mobilenet_v3_small")
    parser.add_argument("--use-balanced-sampler", action="store_true", default=True)
    parser.add_argument("--no-balanced-sampler", dest="use_balanced_sampler", action="store_false")
    parser.add_argument("--merge-organic-into-other", action="store_true")
    parser.add_argument("--sources", nargs="+", choices=["TrashNet", "TACO"], default=["TrashNet", "TACO"])
    parser.add_argument("--pretrained", action="store_true")
    parser.add_argument("--freeze-backbone-epochs", type=int, default=0)
    parser.add_argument("--label-smoothing", type=float, default=0.0)
    parser.add_argument("--resume-checkpoint", type=Path)
    parser.add_argument("--loss-class-multipliers", nargs="*", default=[])
    parser.add_argument("--sampler-class-multipliers", nargs="*", default=[])
    return parser.parse_args()


def set_seed(seed: int):
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


def build_transforms(image_size: int):
    train_transform = transforms.Compose(
        [
            transforms.Resize((image_size + 32, image_size + 32)),
            transforms.RandomResizedCrop(image_size, scale=(0.8, 1.0)),
            transforms.RandomHorizontalFlip(),
            transforms.RandomRotation(12),
            transforms.ColorJitter(brightness=0.15, contrast=0.15, saturation=0.1),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ]
    )
    eval_transform = transforms.Compose(
        [
            transforms.Resize((image_size, image_size)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ]
    )
    return train_transform, eval_transform


def load_class_names(summary_path: Path):
    with open(summary_path, "r", encoding="utf-8") as file:
        payload = json.load(file)
    return payload["final_classes"]


def load_manifest_rows(manifest_path: Path):
    with open(manifest_path, "r", encoding="utf-8", newline="") as file:
        return list(csv.DictReader(file))


class ManifestClassificationDataset(Dataset):
    def __init__(self, rows, class_to_idx, transform=None):
        self.rows = rows
        self.class_to_idx = class_to_idx
        self.transform = transform
        self.samples = [(row["image_path"], class_to_idx[row["final_class"]]) for row in rows]

    def __len__(self):
        return len(self.rows)

    def __getitem__(self, index):
        row = self.rows[index]
        image_path = ROOT / row["image_path"]
        label = self.class_to_idx[row["final_class"]]
        with Image.open(image_path) as image:
            image = image.convert("RGB")
            if self.transform is not None:
                image = self.transform(image)
        return image, label


def remap_rows_for_training(rows, merge_organic_into_other):
    if not merge_organic_into_other:
        return rows

    remapped = []
    for row in rows:
        updated = dict(row)
        if updated["final_class"] == "Organic":
            updated["final_class"] = "Other"
        remapped.append(updated)
    return remapped


def filter_rows_by_sources(rows, sources):
    allowed = set(sources)
    return [row for row in rows if row["source_dataset"] in allowed]


def build_datasets(
    manifest_path: Path,
    summary_path: Path,
    image_size: int,
    merge_organic_into_other: bool,
    sources,
):
    class_names = load_class_names(summary_path)
    if merge_organic_into_other:
        class_names = [name for name in class_names if name != "Organic"]
    class_to_idx = {name: idx for idx, name in enumerate(class_names)}
    rows = load_manifest_rows(manifest_path)
    rows = filter_rows_by_sources(rows, sources)
    rows = remap_rows_for_training(rows, merge_organic_into_other)
    split_rows = {"train": [], "val": [], "test": []}
    for row in rows:
        split_rows[row["split"]].append(row)

    train_transform, eval_transform = build_transforms(image_size)
    train_dataset = ManifestClassificationDataset(split_rows["train"], class_to_idx, train_transform)
    val_dataset = ManifestClassificationDataset(split_rows["val"], class_to_idx, eval_transform)
    test_dataset = ManifestClassificationDataset(split_rows["test"], class_to_idx, eval_transform)
    return train_dataset, val_dataset, test_dataset, class_names


def build_sampler(dataset):
    class_counts = Counter(label for _, label in dataset.samples)
    sample_weights = [1.0 / class_counts[label] for _, label in dataset.samples]
    return WeightedRandomSampler(sample_weights, num_samples=len(sample_weights), replacement=True)


def parse_class_multiplier_args(entries):
    multipliers = {}
    for entry in entries:
        if "=" not in entry:
            raise ValueError(f"Invalid class multiplier entry: {entry}. Expected format ClassName=Value")
        class_name, raw_value = entry.split("=", 1)
        multipliers[class_name] = float(raw_value)
    return multipliers


def build_sampler_with_class_multipliers(dataset, class_names, class_multipliers):
    class_counts = Counter(label for _, label in dataset.samples)
    sample_weights = []
    for _, label in dataset.samples:
        class_name = class_names[label]
        multiplier = class_multipliers.get(class_name, 1.0)
        sample_weights.append((1.0 / class_counts[label]) * multiplier)
    return WeightedRandomSampler(sample_weights, num_samples=len(sample_weights), replacement=True)


def build_loaders(
    train_dataset,
    val_dataset,
    test_dataset,
    batch_size,
    num_workers,
    use_balanced_sampler,
    class_names,
    sampler_class_multipliers,
):
    train_kwargs = {
        "dataset": train_dataset,
        "batch_size": batch_size,
        "num_workers": num_workers,
    }
    if use_balanced_sampler:
        if sampler_class_multipliers:
            train_kwargs["sampler"] = build_sampler_with_class_multipliers(
                train_dataset, class_names, sampler_class_multipliers
            )
        else:
            train_kwargs["sampler"] = build_sampler(train_dataset)
    else:
        train_kwargs["shuffle"] = True

    train_loader = DataLoader(**train_kwargs)
    val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=False, num_workers=num_workers)
    test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False, num_workers=num_workers)
    return train_loader, val_loader, test_loader


def build_model(model_name: str, num_classes: int, pretrained: bool):
    if model_name == "mobilenet_v3_small":
        weights = models.MobileNet_V3_Small_Weights.DEFAULT if pretrained else None
        model = models.mobilenet_v3_small(weights=weights)
        in_features = model.classifier[-1].in_features
        model.classifier[-1] = nn.Linear(in_features, num_classes)
        return model
    if model_name == "resnet18":
        weights = models.ResNet18_Weights.DEFAULT if pretrained else None
        model = models.resnet18(weights=weights)
        model.fc = nn.Linear(model.fc.in_features, num_classes)
        return model
    raise ValueError(f"Unsupported model: {model_name}")


def get_backbone_parameters(model_name: str, model):
    if model_name == "mobilenet_v3_small":
        return model.features.parameters()
    if model_name == "resnet18":
        backbone = [
            model.conv1,
            model.bn1,
            model.layer1,
            model.layer2,
            model.layer3,
            model.layer4,
        ]
        for module in backbone:
            for parameter in module.parameters():
                yield parameter
        return
    raise ValueError(f"Unsupported model: {model_name}")


def set_backbone_trainable(model_name: str, model, trainable: bool):
    for parameter in get_backbone_parameters(model_name, model):
        parameter.requires_grad = trainable


def compute_class_weights(train_dataset, num_classes: int):
    counts = Counter(label for _, label in train_dataset.samples)
    total = sum(counts.values())
    weights = []
    for class_idx in range(num_classes):
        count = counts.get(class_idx, 1)
        weights.append(total / (num_classes * count))
    return torch.tensor(weights, dtype=torch.float32)


def apply_class_weight_multipliers(class_weights, class_names, class_multipliers):
    adjusted = class_weights.clone()
    for class_name, multiplier in class_multipliers.items():
        if class_name not in class_names:
            raise ValueError(f"Unknown class name in loss multiplier: {class_name}")
        class_idx = class_names.index(class_name)
        adjusted[class_idx] = adjusted[class_idx] * multiplier
    return adjusted


def distribution_by_name(dataset, class_names):
    counts = Counter(label for _, label in dataset.samples)
    return {class_names[idx]: counts.get(idx, 0) for idx in range(len(class_names))}


def train_one_epoch(model, loader, criterion, optimizer, device):
    model.train()
    running_loss = 0.0
    correct = 0
    total = 0

    for images, labels in loader:
        images = images.to(device)
        labels = labels.to(device)

        optimizer.zero_grad()
        logits = model(images)
        loss = criterion(logits, labels)
        loss.backward()
        optimizer.step()

        running_loss += loss.item() * images.size(0)
        predictions = logits.argmax(dim=1)
        correct += (predictions == labels).sum().item()
        total += labels.size(0)

    return running_loss / max(total, 1), correct / max(total, 1)


@torch.no_grad()
def evaluate(model, loader, criterion, device, num_classes, class_names):
    model.eval()
    running_loss = 0.0
    correct = 0
    total = 0
    confusion = torch.zeros(num_classes, num_classes, dtype=torch.int64)

    for images, labels in loader:
        images = images.to(device)
        labels = labels.to(device)

        logits = model(images)
        loss = criterion(logits, labels)

        running_loss += loss.item() * images.size(0)
        predictions = logits.argmax(dim=1)
        correct += (predictions == labels).sum().item()
        total += labels.size(0)

        for true_label, pred_label in zip(labels.cpu(), predictions.cpu()):
            confusion[true_label, pred_label] += 1

    per_class_accuracy = {}
    for class_idx, class_name in enumerate(class_names):
        class_total = confusion[class_idx].sum().item()
        per_class_accuracy[class_name] = (
            confusion[class_idx, class_idx].item() / class_total if class_total else None
        )

    return {
        "loss": running_loss / max(total, 1),
        "accuracy": correct / max(total, 1),
        "confusion_matrix": confusion.tolist(),
        "per_class_accuracy": per_class_accuracy,
    }


def save_metrics_csv(output_dir: Path, history):
    fieldnames = [
        "epoch",
        "train_loss",
        "train_accuracy",
        "val_loss",
        "val_accuracy",
        "lr",
        "epoch_seconds",
    ]
    with open(output_dir / "history.csv", "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(history)


def main():
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    set_seed(args.seed)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    loss_class_multipliers = parse_class_multiplier_args(args.loss_class_multipliers)
    sampler_class_multipliers = parse_class_multiplier_args(args.sampler_class_multipliers)
    train_dataset, val_dataset, test_dataset, class_names = build_datasets(
        args.manifest, args.summary, args.image_size, args.merge_organic_into_other, args.sources
    )
    num_classes = len(class_names)

    train_loader, val_loader, test_loader = build_loaders(
        train_dataset,
        val_dataset,
        test_dataset,
        args.batch_size,
        args.num_workers,
        args.use_balanced_sampler,
        class_names,
        sampler_class_multipliers,
    )

    model = build_model(args.model, num_classes, args.pretrained).to(device)
    if args.resume_checkpoint:
        checkpoint = torch.load(args.resume_checkpoint, map_location=device)
        model.load_state_dict(checkpoint["model_state_dict"])
    if args.freeze_backbone_epochs > 0:
        set_backbone_trainable(args.model, model, False)
    class_weights = compute_class_weights(train_dataset, num_classes).to(device)
    if loss_class_multipliers:
        class_weights = apply_class_weight_multipliers(class_weights, class_names, loss_class_multipliers).to(device)
    criterion = nn.CrossEntropyLoss(weight=class_weights, label_smoothing=args.label_smoothing)
    optimizer = AdamW(model.parameters(), lr=args.lr, weight_decay=args.weight_decay)
    scheduler = ReduceLROnPlateau(optimizer, mode="min", factor=0.5, patience=1)

    history = []
    best_val_loss = float("inf")
    best_checkpoint_path = args.output_dir / "best_model.pt"

    metadata = {
        "device": str(device),
        "model": args.model,
        "epochs": args.epochs,
        "batch_size": args.batch_size,
        "image_size": args.image_size,
        "learning_rate": args.lr,
        "weight_decay": args.weight_decay,
        "use_balanced_sampler": args.use_balanced_sampler,
        "merge_organic_into_other": args.merge_organic_into_other,
        "sources": args.sources,
        "pretrained": args.pretrained,
        "freeze_backbone_epochs": args.freeze_backbone_epochs,
        "label_smoothing": args.label_smoothing,
        "loss_class_multipliers": loss_class_multipliers,
        "sampler_class_multipliers": sampler_class_multipliers,
        "class_names": class_names,
        "train_size": len(train_dataset),
        "val_size": len(val_dataset),
        "test_size": len(test_dataset),
        "train_distribution": distribution_by_name(train_dataset, class_names),
        "val_distribution": distribution_by_name(val_dataset, class_names),
        "test_distribution": distribution_by_name(test_dataset, class_names),
    }
    with open(args.output_dir / "run_config.json", "w", encoding="utf-8") as file:
        json.dump(metadata, file, indent=2, ensure_ascii=False)

    print(f"Training on {device} with classes: {class_names}")
    for epoch in range(1, args.epochs + 1):
        if args.freeze_backbone_epochs and epoch == args.freeze_backbone_epochs + 1:
            set_backbone_trainable(args.model, model, True)
        epoch_start = time.time()
        train_loss, train_accuracy = train_one_epoch(model, train_loader, criterion, optimizer, device)
        val_metrics = evaluate(model, val_loader, criterion, device, num_classes, class_names)
        scheduler.step(val_metrics["loss"])
        epoch_seconds = time.time() - epoch_start
        current_lr = optimizer.param_groups[0]["lr"]

        history.append(
            {
                "epoch": epoch,
                "train_loss": train_loss,
                "train_accuracy": train_accuracy,
                "val_loss": val_metrics["loss"],
                "val_accuracy": val_metrics["accuracy"],
                "lr": current_lr,
                "epoch_seconds": epoch_seconds,
            }
        )

        print(
            f"Epoch {epoch}/{args.epochs} | "
            f"train_loss={train_loss:.4f} train_acc={train_accuracy:.4f} | "
            f"val_loss={val_metrics['loss']:.4f} val_acc={val_metrics['accuracy']:.4f} | "
            f"lr={current_lr:.6f} time={epoch_seconds:.1f}s"
        )

        if val_metrics["loss"] < best_val_loss:
            best_val_loss = val_metrics["loss"]
            checkpoint = {
                "model_state_dict": model.state_dict(),
                "class_names": class_names,
                "epoch": epoch,
                "val_metrics": val_metrics,
                "model_name": args.model,
                "image_size": args.image_size,
            }
            torch.save(checkpoint, best_checkpoint_path)

    save_metrics_csv(args.output_dir, history)
    with open(args.output_dir / "history.json", "w", encoding="utf-8") as file:
        json.dump(history, file, indent=2, ensure_ascii=False)

    checkpoint = torch.load(best_checkpoint_path, map_location=device)
    model.load_state_dict(checkpoint["model_state_dict"])
    test_metrics = evaluate(model, test_loader, criterion, device, num_classes, class_names)
    test_metrics["class_names"] = class_names

    with open(args.output_dir / "test_metrics.json", "w", encoding="utf-8") as file:
        json.dump(test_metrics, file, indent=2, ensure_ascii=False)

    print("Best model saved to:", best_checkpoint_path)
    print(f"Test metrics | loss={test_metrics['loss']:.4f} accuracy={test_metrics['accuracy']:.4f}")


if __name__ == "__main__":
    main()
