import json
import re
import shutil
from os import getenv
from pathlib import Path
from uuid import uuid4

from fastapi import Depends, FastAPI, File, Header, HTTPException, Query, UploadFile
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from auth_utils import create_access_token, decode_access_token, hash_password, verify_password
from database import engine, get_database_url, get_db
from db_models import Base, Category, Feedback, Prediction, UploadedImage, User
from fusion_service import fuse_predictions
from model_profile import ACTIVE_MODEL_PROFILE
from ocr_service import OCRAnalyzer
from vision_service import VisionClassifier


ROOT = Path(__file__).resolve().parent
BACKEND_DATA_DIR = ROOT / "backend_data"
UPLOADS_DIR = BACKEND_DATA_DIR / "uploads"
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

UPLOADS_DIR.mkdir(parents=True, exist_ok=True)

CATEGORY_SEED = [
    {
        "name": "Plastic",
        "description": "Dechets et emballages principalement en plastique.",
        "sort_guidance": "A deposer dans la filiere plastique ou le bac de tri adapte selon la commune.",
    },
    {
        "name": "Glass",
        "description": "Objets et emballages en verre.",
        "sort_guidance": "A deposer dans le conteneur a verre si propre et conforme.",
    },
    {
        "name": "PaperCardboard",
        "description": "Papier, carton et emballages derives.",
        "sort_guidance": "A mettre dans le bac papier/carton si le dechet reste majoritairement fibreux.",
    },
    {
        "name": "Metal",
        "description": "Canettes, boites et autres objets majoritairement metalliques.",
        "sort_guidance": "A orienter vers la filiere metal ou le bac recyclable adapte.",
    },
    {
        "name": "Other",
        "description": "Dechets ambigus, residuels ou non clairement recyclables.",
        "sort_guidance": "A verifier localement; souvent a orienter vers les ordures residuelles.",
    },
]

EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class RegisterRequest(BaseModel):
    email: str
    full_name: str = Field(min_length=2, max_length=255)
    password: str = Field(min_length=6, max_length=128)

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str):
        normalized = value.strip().lower()
        if not EMAIL_PATTERN.match(normalized):
            raise ValueError("Invalid email address")
        return normalized


class LoginRequest(BaseModel):
    email: str
    password: str = Field(min_length=6, max_length=128)

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str):
        normalized = value.strip().lower()
        if not EMAIL_PATTERN.match(normalized):
            raise ValueError("Invalid email address")
        return normalized


class FeedbackRequest(BaseModel):
    prediction_id: int
    rating: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=2000)


app = FastAPI(
    title="Waste Sorting Recommendation API",
    version="2.0.0",
    description="Backend API for image-based waste sorting using vision, OCR, fusion rules, auth, and SQL database storage.",
)

vision_classifier = VisionClassifier(
    ACTIVE_MODEL_PROFILE["checkpoint"],
    class_bias=ACTIVE_MODEL_PROFILE["policy"].get("class_bias"),
)
ocr_analyzer = OCRAnalyzer()


def initialize_database():
    Base.metadata.create_all(engine)
    with Session(engine) as db:
        existing = {item.name for item in db.scalars(select(Category)).all()}
        missing = [Category(**item) for item in CATEGORY_SEED if item["name"] not in existing]
        if missing:
            db.add_all(missing)
            db.commit()


initialize_database()


def _validate_extension(filename: str):
    suffix = Path(filename).suffix.lower()
    if suffix not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported image format. Allowed formats: {', '.join(sorted(ALLOWED_EXTENSIONS))}",
        )
    return suffix


def _store_upload(upload: UploadFile):
    suffix = _validate_extension(upload.filename or "uploaded_image.jpg")
    stored_name = f"{uuid4().hex}{suffix}"
    stored_path = UPLOADS_DIR / stored_name
    with stored_path.open("wb") as destination:
        shutil.copyfileobj(upload.file, destination)
    return stored_path


def _serialize_prediction(prediction: Prediction):
    return {
        "id": prediction.id,
        "created_at": prediction.created_at.isoformat(),
        "image_filename": prediction.image_filename,
        "stored_image_path": prediction.stored_image_path,
        "model_profile": prediction.model_profile,
        "predicted_class": prediction.predicted_class,
        "final_confidence": prediction.final_confidence,
        "vision": json.loads(prediction.vision_json),
        "ocr": json.loads(prediction.ocr_json),
        "decision": json.loads(prediction.decision_json),
    }


def _serialize_user(user: User):
    return {
        "id": user.id,
        "email": user.email,
        "full_name": user.full_name,
        "created_at": user.created_at.isoformat(),
    }


def _serialize_uploaded_image(uploaded_image: UploadedImage):
    return {
        "id": uploaded_image.id,
        "original_filename": uploaded_image.original_filename,
        "stored_image_path": uploaded_image.stored_image_path,
        "created_at": uploaded_image.created_at.isoformat(),
    }


def get_current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")
    token = authorization.split(" ", 1)[1].strip()
    payload = decode_access_token(token)
    if not payload or "sub" not in payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    user = db.scalar(select(User).where(User.id == payload["sub"]))
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    return user


def get_optional_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    if not authorization or not authorization.startswith("Bearer "):
        return None
    token = authorization.split(" ", 1)[1].strip()
    payload = decode_access_token(token)
    if not payload or "sub" not in payload:
        return None
    return db.scalar(select(User).where(User.id == payload["sub"]))


@app.get("/")
def root():
    return {
        "message": "Waste Sorting Recommendation API",
        "docs": "/docs",
        "health": "/health",
    }


@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    return {
        "status": "ok",
        "model_profile": ACTIVE_MODEL_PROFILE["name"],
        "checkpoint": str(ACTIVE_MODEL_PROFILE["checkpoint"]),
        "database_backend": engine.url.get_backend_name(),
        "database_url": get_database_url(),
        "database_url_configured": bool(getenv("DATABASE_URL")),
    }


@app.post("/auth/register")
def register_user(payload: RegisterRequest, db: Session = Depends(get_db)):
    existing = db.scalar(select(User).where(User.email == payload.email))
    if existing is not None:
        raise HTTPException(status_code=409, detail="Email already registered")

    user = User(
        email=payload.email,
        full_name=payload.full_name,
        password_hash=hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    token = create_access_token({"sub": user.id, "email": user.email})

    return {
        "message": "User registered successfully",
        "access_token": token,
        "token_type": "bearer",
        "user": _serialize_user(user),
    }


@app.post("/auth/login")
def login_user(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    token = create_access_token({"sub": user.id, "email": user.email})
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": _serialize_user(user),
    }


@app.get("/users/me")
def get_me(current_user: User = Depends(get_current_user)):
    return _serialize_user(current_user)


@app.post("/images")
def upload_image(
    image: UploadFile = File(...),
    current_user: User | None = Depends(get_optional_user),
    db: Session = Depends(get_db),
):
    stored_path = _store_upload(image)
    uploaded_image = UploadedImage(
        user_id=current_user.id if current_user else None,
        original_filename=image.filename or stored_path.name,
        stored_image_path=str(stored_path),
    )
    db.add(uploaded_image)
    db.commit()
    db.refresh(uploaded_image)
    return _serialize_uploaded_image(uploaded_image)


def _run_prediction(
    *,
    image_filename: str,
    stored_path: Path,
    disable_ocr: bool,
    top_k: int,
    user: User | None,
    db: Session,
    uploaded_image: UploadedImage | None = None,
):
    vision_result = vision_classifier.predict(stored_path, top_k=top_k)
    if disable_ocr:
        ocr_result = {
            "raw_text": "",
            "clean_text": "",
            "predicted_class": None,
            "confidence": 0.0,
            "scores": {},
            "matched_keywords": {},
            "has_text_signal": False,
        }
    else:
        ocr_result = ocr_analyzer.analyze(stored_path)

    decision = fuse_predictions(vision_result, ocr_result, policy=ACTIVE_MODEL_PROFILE["policy"])

    prediction = Prediction(
        user_id=user.id if user else None,
        uploaded_image_id=uploaded_image.id if uploaded_image else None,
        image_filename=image_filename,
        stored_image_path=str(stored_path),
        model_profile=ACTIVE_MODEL_PROFILE["name"],
        predicted_class=decision["recommended_class"],
        final_confidence=float(decision["final_confidence"]),
        vision_json=json.dumps(vision_result, ensure_ascii=False),
        ocr_json=json.dumps(ocr_result, ensure_ascii=False),
        decision_json=json.dumps(decision, ensure_ascii=False),
    )
    db.add(prediction)
    db.commit()
    db.refresh(prediction)

    return prediction, vision_result, ocr_result, decision


@app.post("/predict")
def predict_image(
    image: UploadFile = File(...),
    disable_ocr: bool = Query(False),
    top_k: int = Query(3, ge=1, le=5),
    current_user: User | None = Depends(get_optional_user),
    db: Session = Depends(get_db),
):
    stored_path = _store_upload(image)
    uploaded_image = UploadedImage(
        user_id=current_user.id if current_user else None,
        original_filename=image.filename or stored_path.name,
        stored_image_path=str(stored_path),
    )
    db.add(uploaded_image)
    db.commit()
    db.refresh(uploaded_image)

    try:
        prediction, vision_result, ocr_result, decision = _run_prediction(
            image_filename=image.filename or stored_path.name,
            stored_path=stored_path,
            disable_ocr=disable_ocr,
            top_k=top_k,
            user=current_user,
            db=db,
            uploaded_image=uploaded_image,
        )
    except Exception as exc:
        if stored_path.exists():
            stored_path.unlink()
        raise HTTPException(status_code=500, detail=f"Prediction failed: {exc}") from exc

    return JSONResponse(
        {
            "prediction_id": prediction.id,
            "analysis_id": prediction.id,
            "image_filename": image.filename or stored_path.name,
            "stored_image_path": str(stored_path),
            "model_profile": ACTIVE_MODEL_PROFILE["name"],
            "vision": vision_result,
            "ocr": ocr_result,
            "decision": decision,
        }
    )


@app.post("/analyze")
def analyze_alias(
    image: UploadFile = File(...),
    disable_ocr: bool = Query(False),
    top_k: int = Query(3, ge=1, le=5),
    current_user: User | None = Depends(get_optional_user),
    db: Session = Depends(get_db),
):
    return predict_image(image=image, disable_ocr=disable_ocr, top_k=top_k, current_user=current_user, db=db)


@app.get("/predictions")
def list_predictions(
    limit: int = Query(20, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    statement = (
        select(Prediction)
        .where(Prediction.user_id == current_user.id)
        .order_by(Prediction.id.desc())
        .limit(limit)
    )
    items = db.scalars(statement).all()
    return {"count": len(items), "items": [_serialize_prediction(item) for item in items]}


@app.get("/predictions/{prediction_id}")
def get_prediction(
    prediction_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    prediction = db.scalar(
        select(Prediction).where(Prediction.id == prediction_id, Prediction.user_id == current_user.id)
    )
    if prediction is None:
        raise HTTPException(status_code=404, detail="Prediction not found")
    return _serialize_prediction(prediction)


@app.get("/history")
def history_alias(
    limit: int = Query(20, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return list_predictions(limit=limit, current_user=current_user, db=db)


@app.get("/history/{prediction_id}")
def history_detail_alias(
    prediction_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return get_prediction(prediction_id=prediction_id, current_user=current_user, db=db)


@app.get("/stats")
def get_stats(db: Session = Depends(get_db)):
    prediction_count = db.scalar(select(func.count(Prediction.id))) or 0
    user_count = db.scalar(select(func.count(User.id))) or 0
    feedback_count = db.scalar(select(func.count(Feedback.id))) or 0
    category_count = db.scalar(select(func.count(Category.id))) or 0
    top_classes = db.execute(
        select(Prediction.predicted_class, func.count(Prediction.id))
        .group_by(Prediction.predicted_class)
        .order_by(func.count(Prediction.id).desc())
    ).all()
    return {
        "prediction_count": prediction_count,
        "user_count": user_count,
        "feedback_count": feedback_count,
        "category_count": category_count,
        "predictions_by_class": {class_name: count for class_name, count in top_classes},
    }


@app.get("/categories")
def list_categories(db: Session = Depends(get_db)):
    categories = db.scalars(select(Category).order_by(Category.name.asc())).all()
    return {
        "count": len(categories),
        "items": [
            {
                "id": category.id,
                "name": category.name,
                "description": category.description,
                "sort_guidance": category.sort_guidance,
            }
            for category in categories
        ],
    }


@app.post("/feedback")
def create_feedback(
    payload: FeedbackRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    prediction = db.scalar(
        select(Prediction).where(Prediction.id == payload.prediction_id, Prediction.user_id == current_user.id)
    )
    if prediction is None:
        raise HTTPException(status_code=404, detail="Prediction not found")

    existing = db.scalar(
        select(Feedback).where(
            Feedback.prediction_id == payload.prediction_id,
            Feedback.user_id == current_user.id,
        )
    )
    if existing is not None:
        raise HTTPException(status_code=409, detail="Feedback already submitted for this prediction")

    feedback = Feedback(
        user_id=current_user.id,
        prediction_id=payload.prediction_id,
        rating=payload.rating,
        comment=payload.comment,
    )
    db.add(feedback)
    db.commit()
    db.refresh(feedback)
    return {
        "id": feedback.id,
        "prediction_id": feedback.prediction_id,
        "rating": feedback.rating,
        "comment": feedback.comment,
        "created_at": feedback.created_at.isoformat(),
    }
