from pathlib import Path

from PIL import Image
import torch
from torchvision import models, transforms


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


def confidence_note(confidence: float):
    if confidence >= 0.80:
        return "high"
    if confidence >= 0.55:
        return "medium"
    return "low"


class VisionClassifier:
    def __init__(self, checkpoint_path: Path, class_bias: dict | None = None):
        checkpoint = torch.load(checkpoint_path, map_location="cpu")
        self.class_names = checkpoint["class_names"]
        self.model_name = checkpoint.get("model_name", "resnet18")
        self.image_size = checkpoint.get("image_size", 224)
        self.model = build_model(self.model_name, len(self.class_names))
        self.model.load_state_dict(checkpoint["model_state_dict"])
        self.model.eval()
        self.transform = build_transform(self.image_size)
        self.checkpoint_path = checkpoint_path
        self.class_bias = class_bias or {}

    def predict(self, image_path: Path, top_k: int = 3):
        with Image.open(image_path) as image:
            image = image.convert("RGB")
            tensor = self.transform(image).unsqueeze(0)

        with torch.no_grad():
            logits = self.model(tensor)
            probabilities = torch.softmax(logits, dim=1).squeeze(0)
            if self.class_bias:
                bias_tensor = torch.tensor(
                    [self.class_bias.get(class_name, 1.0) for class_name in self.class_names],
                    dtype=probabilities.dtype,
                )
                probabilities = probabilities * bias_tensor
                probabilities = probabilities / probabilities.sum()

        top_k = min(top_k, len(self.class_names))
        scores, indices = torch.topk(probabilities, k=top_k)

        predictions = []
        for score, idx in zip(scores.tolist(), indices.tolist()):
            predictions.append(
                {
                    "class_name": self.class_names[idx],
                    "probability": round(score, 4),
                    "confidence_level": confidence_note(score),
                }
            )

        return {
            "checkpoint": str(self.checkpoint_path),
            "predicted_class": predictions[0]["class_name"],
            "predicted_probability": predictions[0]["probability"],
            "confidence_level": predictions[0]["confidence_level"],
            "top_predictions": predictions,
        }
