from pathlib import Path

from PIL import Image
import cv2
import numpy as np
import torch
from torchvision import models, transforms

SUPPORTED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def _load_and_validate_image(image_path: Path):
    if image_path.suffix.lower() not in SUPPORTED_IMAGE_EXTENSIONS:
        raise ValueError(f"Unsupported image format: {image_path.suffix}")

    image = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError(f"Unable to decode image: {image_path}")

    height, width = image.shape[:2]
    if height < 32 or width < 32:
        raise ValueError("Image resolution too low for classification; minimum 32x32 required.")

    return image


def _correct_color_balance(image: np.ndarray) -> np.ndarray:
    image = image.astype(np.float32)
    avg_bgr = np.mean(image, axis=(0, 1))
    gray = np.mean(avg_bgr)
    gain = gray / (avg_bgr + 1e-8)
    balanced = np.clip(image * gain, 0, 255).astype(np.uint8)
    return balanced


def _denoise_image(image: np.ndarray) -> np.ndarray:
    return cv2.fastNlMeansDenoisingColored(image, None, h=10, hColor=10, templateWindowSize=7, searchWindowSize=21)


def _enhance_image(image: np.ndarray) -> np.ndarray:
    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
    l_channel, a_channel, b_channel = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    l_channel = clahe.apply(l_channel)
    lab = cv2.merge((l_channel, a_channel, b_channel))
    enhanced = cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)

    blurred = cv2.GaussianBlur(enhanced, (0, 0), sigmaX=3)
    sharpened = cv2.addWeighted(enhanced, 1.4, blurred, -0.4, 0)

    gamma = 1.05
    lut = np.array([((i / 255.0) ** (1.0 / gamma)) * 255 for i in np.arange(256)], dtype=np.uint8)
    return cv2.LUT(sharpened, lut)


def _smart_resize(image: np.ndarray, target_size: int) -> np.ndarray:
    height, width = image.shape[:2]
    scale = target_size / max(height, width)
    new_width = round(width * scale)
    new_height = round(height * scale)
    interpolation = cv2.INTER_LINEAR if scale > 1 else cv2.INTER_AREA
    resized = cv2.resize(image, (new_width, new_height), interpolation=interpolation)

    delta_w = target_size - new_width
    delta_h = target_size - new_height
    top = delta_h // 2
    bottom = delta_h - top
    left = delta_w // 2
    right = delta_w - left
    return cv2.copyMakeBorder(resized, top, bottom, left, right, cv2.BORDER_CONSTANT, value=[0, 0, 0])


def _prepare_image_for_model(image_path: Path, image_size: int) -> tuple[Image.Image, dict]:
    image = _load_and_validate_image(image_path)
    original_height, original_width = image.shape[:2]

    image = _correct_color_balance(image)
    image = _denoise_image(image)
    image = _enhance_image(image)
    image = _smart_resize(image, image_size)

    final_height, final_width = image.shape[:2]
    rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    diagnostics = {
        "input_format": image_path.suffix.lower(),
        "original_size": {"width": original_width, "height": original_height},
        "processed_size": {"width": final_width, "height": final_height},
        "pipeline": [
            "load_and_validate",
            "color_balance",
            "denoise",
            "enhance",
            "smart_resize",
        ],
        "validation_status": "ok",
    }
    return Image.fromarray(rgb_image), diagnostics


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
        image, preprocessing_log = _prepare_image_for_model(image_path, self.image_size)
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
            "preprocessing": preprocessing_log,
        }
