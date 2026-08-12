import csv
import hashlib
import hmac
import json
import mimetypes
import re
import secrets
import urllib.request
import urllib.parse
from datetime import datetime, timedelta, timezone
from io import StringIO
from os import getenv
from pathlib import Path
from typing import Any
from uuid import uuid4

from dotenv import load_dotenv

from fastapi import Depends, FastAPI, File, Header, HTTPException, Query, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from fastapi.staticfiles import StaticFiles
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from PIL import Image, UnidentifiedImageError
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

load_dotenv()

from auth_utils import create_access_token, decode_access_token, hash_password, verify_password
from database import engine, get_database_url, get_db
from db_models import (
    AuditLog,
    Base,
    Category,
    DeviceToken,
    EmailVerificationToken,
    Feedback,
    MfaToken,
    Notification,
    PasswordResetToken,
    PendingRegistration,
    Prediction,
    RefreshToken,
    UploadedImage,
    User,
    ModelProfile,
)
from fusion_service import fuse_predictions
from model_profile import ACTIVE_MODEL_PROFILE
from ocr_service import OCRAnalyzer
from tasks import send_email_task, send_push_notification_task
from vision_service import VisionClassifier


ROOT = Path(__file__).resolve().parent
BACKEND_DATA_DIR = ROOT / "backend_data"
UPLOADS_DIR = BACKEND_DATA_DIR / "uploads"
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/bmp", "image/webp"}
GENERIC_UPLOAD_TYPES = {"", "application/octet-stream", "binary/octet-stream"}
MAX_UPLOAD_BYTES = int(getenv("MAX_UPLOAD_BYTES", str(8 * 1024 * 1024)))
PRIVILEGED_ROLES = {"admin", "manager"}
ADMIN_ROLES = {"admin"}
USER_ROLES = {"user", "manager", "admin"}
USER_STATUSES = {"active", "pending", "suspended"}
REVIEW_STATUSES = {"auto_accepted", "review", "validated", "rejected"}
LOCKOUT_THRESHOLD = int(getenv("LOCKOUT_THRESHOLD", "5"))
LOCKOUT_MINUTES = int(getenv("LOCKOUT_MINUTES", "15"))
REFRESH_TOKEN_TTL_HOURS = int(getenv("REFRESH_TOKEN_TTL_HOURS", "168"))
EMAIL_VERIFICATION_TOKEN_TTL_HOURS = int(getenv("EMAIL_VERIFICATION_TOKEN_TTL_HOURS", "24"))
PASSWORD_RESET_TOKEN_TTL_HOURS = int(getenv("PASSWORD_RESET_TOKEN_TTL_HOURS", "2"))
GOOGLE_OAUTH_CLIENT_ID = getenv("GOOGLE_OAUTH_CLIENT_ID", "")
GOOGLE_OAUTH_CLIENT_IDS = [
    client.strip()
    for client in getenv("GOOGLE_OAUTH_CLIENT_IDS", "").split(",")
    if client.strip()
]
if GOOGLE_OAUTH_CLIENT_ID and GOOGLE_OAUTH_CLIENT_ID not in GOOGLE_OAUTH_CLIENT_IDS:
    GOOGLE_OAUTH_CLIENT_IDS.append(GOOGLE_OAUTH_CLIENT_ID)
SMTP_SERVER = getenv("SMTP_SERVER", "")
SMTP_PORT = int(getenv("SMTP_PORT", "587"))
SMTP_USERNAME = getenv("SMTP_USERNAME", "")
SMTP_PASSWORD = getenv("SMTP_PASSWORD", "")
SMTP_USE_TLS = getenv("SMTP_USE_TLS", "true").lower() in ("true", "1", "yes")
EMAIL_FROM_ADDRESS = getenv("EMAIL_FROM_ADDRESS", "no-reply@example.com")
FCM_SERVER_KEY = getenv("FCM_SERVER_KEY", "")

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
    role: str = Field(default="user")

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str):
        normalized = value.strip().lower()
        if not EMAIL_PATTERN.match(normalized):
            raise ValueError("Invalid email address")
        return normalized

    @field_validator("role")
    @classmethod
    def validate_role(cls, value: str):
        normalized = value.strip().lower()
        valid_roles = {"user", "manager"}
        if normalized not in valid_roles:
            raise ValueError("Role invalide")
        return normalized


class LoginRequest(BaseModel):
    email: str
    password: str = Field(min_length=6, max_length=128)
    mfa_token: str | None = None
    mfa_code: str | None = None

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str):
        normalized = value.strip().lower()
        if not EMAIL_PATTERN.match(normalized):
            raise ValueError("Invalid email address")
        return normalized


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(min_length=32)


class DeviceTokenRequest(BaseModel):
    device_token: str = Field(min_length=10)
    platform: str | None = None


class GoogleLoginRequest(BaseModel):
    id_token: str = Field(min_length=20)
    display_name: str | None = None
    mfa_token: str | None = None
    mfa_code: str | None = None


class LogoutRequest(BaseModel):
    refresh_token: str = Field(min_length=32)


class RequestEmailVerificationRequest(BaseModel):
    email: str

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str):
        normalized = value.strip().lower()
        if not EMAIL_PATTERN.match(normalized):
            raise ValueError("Invalid email address")
        return normalized


class VerifyEmailRequest(BaseModel):
    email: str
    token: str = Field(min_length=6, max_length=6)

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str):
        normalized = value.strip().lower()
        if not EMAIL_PATTERN.match(normalized):
            raise ValueError("Invalid email address")
        return normalized


class RequestPasswordResetRequest(BaseModel):
    email: str

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str):
        normalized = value.strip().lower()
        if not EMAIL_PATTERN.match(normalized):
            raise ValueError("Invalid email address")
        return normalized


class VerifyResetOtpRequest(BaseModel):
    token: str = Field(min_length=6)


class ResetPasswordRequest(BaseModel):
    token: str = Field(min_length=6)
    password: str = Field(min_length=6, max_length=128)


class ModelProfileCreateRequest(BaseModel):
    name: str = Field(min_length=2, max_length=255)
    checkpoint: str
    policy: dict[str, Any] = Field(default_factory=dict)
    activate: bool = False


class FeedbackRequest(BaseModel):
    prediction_id: int
    rating: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=2000)


class ReplyRequest(BaseModel):
    reply: str = Field(..., min_length=1, max_length=2000)


class UpdateProfileRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=255)


class UpdatePredictionRequest(BaseModel):
    predicted_class: str

    @field_validator("predicted_class")
    @classmethod
    def validate_predicted_class(cls, value: str):
        normalized = value.strip()
        allowed = {item["name"] for item in CATEGORY_SEED}
        if normalized not in allowed:
            raise ValueError(f"Invalid class. Allowed values: {', '.join(sorted(allowed))}")
        return normalized


class AdminUpdateUserRequest(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=255)
    role: str | None = None
    status: str | None = None
    email_verified: bool | None = None

    @field_validator("role")
    @classmethod
    def validate_role(cls, value: str | None):
        if value is None:
            return value
        normalized = value.strip().lower()
        if normalized not in USER_ROLES:
            raise ValueError(f"Invalid role. Allowed values: {', '.join(sorted(USER_ROLES))}")
        return normalized

    @field_validator("status")
    @classmethod
    def validate_status(cls, value: str | None):
        if value is None:
            return value
        normalized = value.strip().lower()
        if normalized not in USER_STATUSES:
            raise ValueError(f"Invalid status. Allowed values: {', '.join(sorted(USER_STATUSES))}")
        return normalized


class AdminCreateUserRequest(BaseModel):
    email: str
    full_name: str = Field(min_length=2, max_length=255)
    password: str = Field(min_length=6, max_length=128)
    role: str = Field(default="user")
    status: str = Field(default="active")
    email_verified: bool = False

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str):
        normalized = value.strip().lower()
        if not EMAIL_PATTERN.match(normalized):
            raise ValueError("Invalid email address")
        return normalized

    @field_validator("role")
    @classmethod
    def validate_role(cls, value: str):
        normalized = value.strip().lower()
        if normalized not in USER_ROLES:
            raise ValueError(f"Invalid role. Allowed values: {', '.join(sorted(USER_ROLES))}")
        return normalized

    @field_validator("status")
    @classmethod
    def validate_status(cls, value: str):
        normalized = value.strip().lower()
        if normalized not in USER_STATUSES:
            raise ValueError(f"Invalid status. Allowed values: {', '.join(sorted(USER_STATUSES))}")
        return normalized


class AdminResetAdminRequest(BaseModel):
    email: str
    full_name: str = Field(min_length=2, max_length=255)
    password: str = Field(min_length=6, max_length=128)
    activate: bool = True
    verify_email: bool = True

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str):
        normalized = value.strip().lower()
        if not EMAIL_PATTERN.match(normalized):
            raise ValueError("Invalid email address")
        return normalized


class CategoryRequest(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    description: str = Field(min_length=2, max_length=2000)
    sort_guidance: str = Field(min_length=2, max_length=2000)

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str):
        return value.strip()


class AdminValidatePredictionRequest(BaseModel):
    predicted_class: str
    review_status: str = "validated"
    note: str = Field(default="", max_length=2000)

    @field_validator("predicted_class")
    @classmethod
    def validate_predicted_class(cls, value: str):
        normalized = value.strip()
        allowed = {item["name"] for item in CATEGORY_SEED}
        if normalized not in allowed:
            raise ValueError(f"Invalid class. Allowed values: {', '.join(sorted(allowed))}")
        return normalized

    @field_validator("review_status")
    @classmethod
    def validate_review_status(cls, value: str):
        normalized = value.strip().lower()
        if normalized not in {"validated", "rejected", "review"}:
            raise ValueError("review_status must be validated, rejected, or review")
        return normalized


app = FastAPI(
    title="Waste Sorting Recommendation API",
    version="2.0.0",
    description="Backend API for image-based waste sorting using vision, OCR, fusion rules, auth, and SQL database storage.",
)

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://192.168.11.118:8000",
        "http://192.168.11.118:5173",
    ],
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1|192\.168\.\d{1,3}\.\d{1,3})(:\d+)?$",
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["*"],
)


@app.middleware("http")
async def add_security_headers(request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'self'; connect-src 'self' http://localhost:8000 http://127.0.0.1:8000 http://localhost:3000 http://127.0.0.1:3000; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https: http://127.0.0.1:8000 http://localhost:8000; font-src 'self' data:"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"
    return response


app.mount("/uploads", StaticFiles(directory=str(UPLOADS_DIR)), name="uploads")

vision_classifier = None
_current_model_profile_name = None
ocr_analyzer = OCRAnalyzer()


def _get_active_model_profile(db: Session):
    profile = db.scalar(select(ModelProfile).where(ModelProfile.is_active == 1))
    if profile is not None:
        return {
            "name": profile.name,
            "checkpoint": Path(profile.checkpoint),
            "policy": json.loads(profile.policy_json or "{}"),
        }
    return ACTIVE_MODEL_PROFILE


def _set_active_model_profile(db: Session, name: str):
    profile = db.scalar(select(ModelProfile).where(ModelProfile.name == name))
    if profile is None:
        raise HTTPException(status_code=404, detail=f"Model profile '{name}' not found")

    db.execute(
        text("UPDATE model_profiles SET is_active = CASE WHEN name = :name THEN 1 ELSE 0 END"),
        {"name": name},
    )
    db.commit()
    return _get_active_model_profile(db)


def _get_vision_classifier(db: Session):
    global vision_classifier, _current_model_profile_name
    active_profile = _get_active_model_profile(db)
    if vision_classifier is None or _current_model_profile_name != active_profile["name"]:
        vision_classifier = VisionClassifier(
            active_profile["checkpoint"],
            class_bias=active_profile["policy"].get("class_bias"),
        )
        _current_model_profile_name = active_profile["name"]
    return vision_classifier, active_profile


def _serialize_model_profile(profile: ModelProfile) -> dict[str, Any]:
    return {
        "name": profile.name,
        "checkpoint": profile.checkpoint,
        "policy": json.loads(profile.policy_json or "{}"),
        "is_active": bool(profile.is_active),
        "created_at": profile.created_at.isoformat(),
    }


def initialize_database():
    Base.metadata.create_all(engine)
    with Session(engine) as db:
        _run_lightweight_migrations(db)
        existing = {item.name for item in db.scalars(select(Category)).all()}
        missing = [Category(**item) for item in CATEGORY_SEED if item["name"] not in existing]
        if missing:
            db.add_all(missing)
            db.commit()
        _ensure_bootstrap_admin(db)


def _run_lightweight_migrations(db: Session):
    user_columns = {
        "profile_image_path": "TEXT",
        "role": "VARCHAR(50) NOT NULL DEFAULT 'user'",
        "status": "VARCHAR(50) NOT NULL DEFAULT 'active'",
        "email_verified": "INTEGER NOT NULL DEFAULT 0",
        "google_id": "VARCHAR(255)",
        "email_notifications_enabled": "INTEGER NOT NULL DEFAULT 1",
        "push_notifications_enabled": "INTEGER NOT NULL DEFAULT 1",
        "failed_login_count": "INTEGER NOT NULL DEFAULT 0",
        "locked_until": "TIMESTAMP",
    }
    prediction_columns = {
        "review_status": "VARCHAR(50) NOT NULL DEFAULT 'auto_accepted'",
    }
    feedback_columns = {
        "admin_reply": "TEXT",
        "admin_replied_at": "TIMESTAMP",
        "replied_by_user_id": "INTEGER",
    }
    _ensure_columns(db, "users", user_columns)
    _ensure_columns(db, "predictions", prediction_columns)
    _ensure_columns(db, "feedback", feedback_columns)


def _ensure_columns(db: Session, table_name: str, columns: dict[str, str]):
    backend_name = engine.url.get_backend_name()
    if backend_name.startswith("postgres"):
        rows = db.execute(
            text("SELECT column_name FROM information_schema.columns WHERE table_name=:table_name"),
            {"table_name": table_name},
        ).all()
        existing = {row[0] for row in rows}
    elif backend_name.startswith("sqlite"):
        rows = db.execute(text(f"PRAGMA table_info({table_name})")).all()
        existing = {row[1] for row in rows}
    else:
        return

    for column_name, definition in columns.items():
        if column_name not in existing:
            db.execute(text(f"ALTER TABLE {table_name} ADD COLUMN {column_name} {definition}"))
    db.commit()


def _ensure_bootstrap_admin(db: Session):
    admin_count = db.scalar(select(func.count(User.id)).where(User.role == "admin")) or 0
    if admin_count > 0:
        return
    first_user = db.scalar(select(User).order_by(User.id.asc()).limit(1))
    if first_user is None:
        return
    first_user.role = "admin"
    first_user.status = "active"
    first_user.email_verified = 1
    db.add(first_user)
    db.add(
        AuditLog(
            actor_user_id=first_user.id,
            action="system.bootstrap_admin",
            resource_type="user",
            resource_id=str(first_user.id),
            details=json.dumps({"reason": "no existing admin account"}, ensure_ascii=False),
        )
    )
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
    declared_type = (upload.content_type or "").lower()
    guessed_type = mimetypes.guess_type(upload.filename or "")[0] or ""
    if (
        declared_type not in ALLOWED_IMAGE_TYPES
        and declared_type not in GENERIC_UPLOAD_TYPES
        and guessed_type not in ALLOWED_IMAGE_TYPES
    ):
        raise HTTPException(status_code=400, detail="Unsupported image MIME type")

    stored_name = f"{uuid4().hex}{suffix}"
    stored_path = UPLOADS_DIR / stored_name

    total = 0
    with stored_path.open("wb") as destination:
        while True:
            chunk = upload.file.read(1024 * 1024)
            if not chunk:
                break
            total += len(chunk)
            if total > MAX_UPLOAD_BYTES:
                destination.close()
                stored_path.unlink(missing_ok=True)
                raise HTTPException(status_code=413, detail="Image file is too large")
            destination.write(chunk)

    try:
        with Image.open(stored_path) as image:
            image.verify()
    except (UnidentifiedImageError, OSError) as exc:
        stored_path.unlink(missing_ok=True)
        raise HTTPException(status_code=400, detail="Invalid or corrupted image file") from exc

    return stored_path


def _serialize_prediction(prediction: Prediction):
    image_url = None
    if prediction.stored_image_path:
        stored_name = Path(prediction.stored_image_path).name
        image_url = f"/uploads/{stored_name}"

    return {
        "id": prediction.id,
        "created_at": prediction.created_at.isoformat(),
        "image_filename": prediction.image_filename,
        "stored_image_path": prediction.stored_image_path,
        "image_url": image_url,
        "model_profile": prediction.model_profile,
        "predicted_class": prediction.predicted_class,
        "final_confidence": prediction.final_confidence,
        "review_status": prediction.review_status,
        "vision": json.loads(prediction.vision_json),
        "ocr": json.loads(prediction.ocr_json),
        "decision": json.loads(prediction.decision_json),
    }


def _serialize_user(user: User):
    profile_image_url = None
    if user.profile_image_path:
        profile_image_url = f"/uploads/{Path(user.profile_image_path).name}"

    return {
        "id": user.id,
        "email": user.email,
        "full_name": user.full_name,
        "role": user.role,
        "status": user.status,
        "email_verified": bool(user.email_verified),
        "mfa_enabled": bool(getattr(user, "mfa_enabled", 0)),
        "profile_image_url": profile_image_url,
        "created_at": user.created_at.isoformat(),
    }


def _serialize_admin_prediction(prediction: Prediction):
    payload = _serialize_prediction(prediction)
    payload["user"] = _serialize_user(prediction.user) if prediction.user else None
    payload["feedback_count"] = len(prediction.feedback_items)
    return payload


def _serialize_feedback(feedback: Feedback):
    return {
        "id": feedback.id,
        "prediction_id": feedback.prediction_id,
        "user": _serialize_user(feedback.user) if feedback.user else None,
        "rating": feedback.rating,
        "comment": feedback.comment,
        "created_at": feedback.created_at.isoformat(),
        "admin_reply": feedback.admin_reply,
        "admin_replied_at": feedback.admin_replied_at.isoformat() if feedback.admin_replied_at else None,
        "replied_by": _serialize_user(feedback.replied_by) if feedback.replied_by else None,
    }


def _serialize_audit_log(log: AuditLog):
    return {
        "id": log.id,
        "actor_user_id": log.actor_user_id,
        "action": log.action,
        "resource_type": log.resource_type,
        "resource_id": log.resource_id,
        "details": log.details,
        "source": log.source,
        "created_at": log.created_at.isoformat(),
    }


def _serialize_notification(notification: Notification):
    return {
        "id": notification.id,
        "recipient_user_id": notification.recipient_user_id,
        "recipient_role": notification.recipient_role,
        "title": notification.title,
        "message": notification.message,
        "related_type": notification.related_type,
        "related_id": notification.related_id,
        "is_read": bool(notification.is_read),
        "created_at": notification.created_at.isoformat(),
    }


def _send_email_message(to_address: str, subject: str, body: str) -> bool:
    if not SMTP_SERVER or not EMAIL_FROM_ADDRESS:
        return False
    try:
        import ssl as _ssl
        import smtplib as _smtplib
        from email.message import EmailMessage as _EmailMessage
        smtp_port = int(getenv("SMTP_PORT", "587"))
        smtp_username = getenv("SMTP_USERNAME", "")
        smtp_password = getenv("SMTP_PASSWORD", "")
        smtp_use_tls = getenv("SMTP_USE_TLS", "true").lower() in ("true", "1", "yes")
        msg = _EmailMessage()
        msg["From"] = EMAIL_FROM_ADDRESS
        msg["To"] = to_address
        msg["Subject"] = subject
        msg.set_content(body)
        if smtp_use_tls:
            context = _ssl.create_default_context()
            with _smtplib.SMTP(SMTP_SERVER, smtp_port, timeout=15) as server:
                server.starttls(context=context)
                if smtp_username:
                    server.login(smtp_username, smtp_password)
                server.send_message(msg)
        else:
            with _smtplib.SMTP(SMTP_SERVER, smtp_port, timeout=15) as server:
                if smtp_username:
                    server.login(smtp_username, smtp_password)
                server.send_message(msg)
        return True
    except Exception:
        return False


def _send_push_notification(tokens: list[str], title: str, message: str, data: dict | None = None) -> bool:
    if not FCM_SERVER_KEY or not tokens:
        return False
    send_push_notification_task.delay(tokens, title, message, data)
    return True


def _notify_user_channels(
    db: Session,
    user: User,
    title: str,
    message: str,
    related_type: str | None,
    related_id: str | None,
):
    if user.email_notifications_enabled and user.email_verified:
        _send_email_message(
            user.email,
            title,
            f"{message}\n\nConsultez votre espace de notifications dans l'application.",
        )

    if user.push_notifications_enabled:
        tokens = db.scalars(select(DeviceToken.token).where(DeviceToken.user_id == user.id)).all()
        if tokens:
            _send_push_notification(
                tokens,
                title,
                message,
                {
                    "related_type": related_type or "notification",
                    "related_id": related_id or "",
                },
            )


def _create_notification(
    db: Session,
    *,
    title: str,
    message: str,
    recipient_user_id: int | None = None,
    recipient_role: str | None = None,
    related_type: str | None = None,
    related_id: str | None = None,
):
    db.add(
        Notification(
            recipient_user_id=recipient_user_id,
            recipient_role=recipient_role,
            title=title,
            message=message,
            related_type=related_type,
            related_id=related_id,
            is_read=0,
        )
    )

    try:
        if recipient_user_id is not None:
            recipient = db.scalar(select(User).where(User.id == recipient_user_id, User.status == "active"))
            if recipient is not None:
                _notify_user_channels(db, recipient, title, message, related_type, related_id)
        elif recipient_role is not None:
            recipients = db.scalars(
                select(User).where(User.role == recipient_role, User.status == "active")
            ).all()
            for recipient in recipients:
                _notify_user_channels(db, recipient, title, message, related_type, related_id)
    except Exception:
        pass


def _write_audit(
    db: Session,
    *,
    actor: User | None,
    action: str,
    resource_type: str,
    resource_id: str | int | None = None,
    details: dict | str | None = None,
):
    if isinstance(details, dict):
        details_text = json.dumps(details, ensure_ascii=False)
    else:
        details_text = details or ""
    db.add(
        AuditLog(
            actor_user_id=actor.id if actor else None,
            action=action,
            resource_type=resource_type,
            resource_id=str(resource_id) if resource_id is not None else None,
            details=details_text,
        )
    )


def _serialize_uploaded_image(uploaded_image: UploadedImage):
    return {
        "id": uploaded_image.id,
        "original_filename": uploaded_image.original_filename,
        "stored_image_path": uploaded_image.stored_image_path,
        "created_at": uploaded_image.created_at.isoformat(),
    }


def _hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _verify_google_id_token(id_token: str) -> dict:
    if not GOOGLE_OAUTH_CLIENT_IDS:
        raise HTTPException(status_code=500, detail="Google OAuth client ID is not configured")
    try:
        encoded = urllib.parse.quote(id_token, safe="")
        url = f"https://oauth2.googleapis.com/tokeninfo?id_token={encoded}"
        with urllib.request.urlopen(url, timeout=10) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid Google ID token") from exc

    aud = payload.get("aud")
    if aud not in GOOGLE_OAUTH_CLIENT_IDS:
        raise HTTPException(status_code=401, detail="Google ID token audience mismatch")
    if payload.get("email_verified") not in ("true", True, 1, "1"):
        raise HTTPException(status_code=401, detail="Google account email is not verified")
    return payload


def _create_refresh_token(
    db: Session,
    user: User,
    user_agent: str | None = None,
    ip_address: str | None = None,
) -> str:
    raw_token = secrets.token_urlsafe(32)
    refresh_token = RefreshToken(
        user_id=user.id,
        token_hash=_hash_refresh_token(raw_token),
        expires_at=datetime.now(timezone.utc) + timedelta(hours=REFRESH_TOKEN_TTL_HOURS),
        user_agent=user_agent,
        ip_address=ip_address,
    )
    db.add(refresh_token)
    db.commit()
    db.refresh(refresh_token)
    return raw_token


def _get_refresh_token_record(db: Session, token: str):
    token_hash = _hash_refresh_token(token)
    return db.scalar(select(RefreshToken).where(RefreshToken.token_hash == token_hash))


def _create_mfa_token(
    db: Session,
    user: User,
    code: str,
    expires_hours: float = 0.16,
    user_agent: str | None = None,
    ip_address: str | None = None,
) -> str:
    raw_token = secrets.token_urlsafe(32)
    token_record = MfaToken(
        user_id=user.id,
        token_hash=_hash_refresh_token(raw_token),
        code_hash=_hash_refresh_token(code),
        expires_at=datetime.now(timezone.utc) + timedelta(hours=expires_hours),
        user_agent=user_agent,
        ip_address=ip_address,
    )
    db.add(token_record)
    db.commit()
    db.refresh(token_record)
    return raw_token


def _get_mfa_token_record(db: Session, token: str):
    token_hash = _hash_refresh_token(token)
    return db.scalar(select(MfaToken).where(MfaToken.token_hash == token_hash))


def _verify_mfa_code(token_record: MfaToken, code: str) -> bool:
    return token_record is not None and token_record.used == 0 and hmac.compare_digest(
        token_record.code_hash, _hash_refresh_token(code)
    )


def _mark_mfa_token_used(db: Session, token_record: MfaToken):
    token_record.used = 1
    db.add(token_record)
    db.commit()


def _create_otp_code() -> str:
    return str(secrets.randbelow(900000) + 100000)


def _create_user_action_token(
    db: Session,
    user: User,
    model_class,
    expires_hours: int,
    user_agent: str | None = None,
    ip_address: str | None = None,
    raw_token: str | None = None,
) -> str:
    if raw_token is None:
        raw_token = secrets.token_urlsafe(32)
    token_record = model_class(
        user_id=user.id,
        token_hash=_hash_refresh_token(raw_token),
        expires_at=datetime.now(timezone.utc) + timedelta(hours=expires_hours),
        user_agent=user_agent,
        ip_address=ip_address,
    )
    db.add(token_record)
    db.commit()
    db.refresh(token_record)
    return raw_token


def _get_user_action_token_record(db: Session, token: str, model_class):
    token_hash = _hash_refresh_token(token)
    return db.scalar(
        select(model_class).where(model_class.token_hash == token_hash, model_class.used == 0)
    )


def _is_expired(dt):
    if dt is None:
        return True
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt < datetime.now(timezone.utc)


def _mark_user_action_token_used(db: Session, token_record):
    token_record.used = 1
    db.add(token_record)
    db.commit()


def _cleanup_pending_registration(db: Session, pending: PendingRegistration):
    db.delete(pending)
    db.commit()


def _revoke_refresh_token(db: Session, token_record: RefreshToken):
    token_record.revoked = 1
    db.add(token_record)
    db.commit()


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
    if user.status != "active":
        raise HTTPException(status_code=403, detail="User account is not active")
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
    user = db.scalar(select(User).where(User.id == payload["sub"]))
    if user is None or user.status != "active":
        return None
    return user


def require_roles(*allowed_roles: str):
    def dependency(current_user: User = Depends(get_current_user)):
        if current_user.role not in allowed_roles:
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return current_user

    return dependency


get_current_admin = require_roles(*ADMIN_ROLES)
get_admin_user = get_current_admin
get_current_privileged_user = require_roles(*PRIVILEGED_ROLES)


@app.get("/model-profiles")
def list_model_profiles(
    current_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    profiles = db.scalars(select(ModelProfile).order_by(ModelProfile.created_at.desc())).all()
    return [_serialize_model_profile(profile) for profile in profiles]


@app.post("/model-profiles")
def create_model_profile(
    payload: ModelProfileCreateRequest,
    current_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    existing = db.scalar(select(ModelProfile).where(ModelProfile.name == payload.name))
    if existing is not None:
        raise HTTPException(status_code=400, detail=f"Model profile '{payload.name}' already exists")

    if payload.activate:
        db.execute(text("UPDATE model_profiles SET is_active = 0 WHERE is_active = 1"))

    profile = ModelProfile(
        name=payload.name,
        checkpoint=payload.checkpoint,
        policy_json=json.dumps(payload.policy or {}),
        is_active=1 if payload.activate else 0,
    )
    db.add(profile)
    db.commit()
    db.refresh(profile)

    if payload.activate:
        _get_vision_classifier(db)

    return _serialize_model_profile(profile)


@app.post("/model-profiles/{name}/activate")
def activate_model_profile(
    name: str,
    current_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    active_profile = _set_active_model_profile(db, name)
    _get_vision_classifier(db)
    return active_profile


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
    active_profile = _get_active_model_profile(db)
    return {
        "status": "ok",
        "model_profile": active_profile["name"],
        "checkpoint": str(active_profile["checkpoint"]),
        "database_backend": engine.url.get_backend_name(),
        "database_url": get_database_url(),
        "database_url_configured": bool(getenv("DATABASE_URL")),
    }


@limiter.limit("10/day")
@app.post("/auth/register")
def register_user(request: Request, payload: RegisterRequest, db: Session = Depends(get_db)):
    existing_user = db.scalar(select(User).where(User.email == payload.email))
    if existing_user is not None:
        raise HTTPException(status_code=409, detail="Email already registered")

    existing_pending = db.scalar(select(PendingRegistration).where(PendingRegistration.email == payload.email))
    if existing_pending is not None:
        _cleanup_pending_registration(db, existing_pending)

    is_first_user = (db.scalar(select(func.count(User.id))) or 0) == 0
    role = "admin" if is_first_user else payload.role

    otp_code = _create_otp_code()
    pending = PendingRegistration(
        email=payload.email,
        full_name=payload.full_name,
        password_hash=hash_password(payload.password),
        role=role,
        otp_code_hash=_hash_refresh_token(otp_code),
        expires_at=datetime.now(timezone.utc) + timedelta(hours=EMAIL_VERIFICATION_TOKEN_TTL_HOURS),
    )
    db.add(pending)
    db.commit()

    _send_email_message(
        to_address=payload.email,
        subject="Votre code de vérification EcoSort",
        body=f"Bonjour {payload.full_name},\n\n"
             f"Votre code de vérification est : {otp_code}\n\n"
             f"Ce code expire dans {EMAIL_VERIFICATION_TOKEN_TTL_HOURS} heure(s).\n\n"
             f"Merci,\nL'équipe EcoSort",
    )

    return {
        "message": "Inscription réussie. Un code de vérification a été envoyé par email.",
        "email": payload.email,
    }


@app.post("/auth/request-email-verification")
def request_email_verification(
    payload: RequestEmailVerificationRequest,
    db: Session = Depends(get_db),
    user_agent: str | None = Header(default=None, alias="User-Agent"),
):
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is not None:
        if user.email_verified:
            return {"message": "Email is already verified."}
        otp_code = _create_otp_code()
        _create_user_action_token(
            db,
            user,
            EmailVerificationToken,
            EMAIL_VERIFICATION_TOKEN_TTL_HOURS,
            user_agent=user_agent,
            raw_token=otp_code,
        )
        _send_email_message(
            to_address=user.email,
            subject="Votre code de vérification EcoSort",
            body=f"Bonjour,\n\n"
                 f"Votre code de vérification est : {otp_code}\n\n"
                 f"Ce code expire dans {EMAIL_VERIFICATION_TOKEN_TTL_HOURS} heure(s).\n\n"
                 f"Merci,\nL'équipe EcoSort",
        )
        _write_audit(db, actor=user, action="auth.request_email_verification", resource_type="user", resource_id=user.id)
        return {"message": "Un code de vérification a été envoyé par email."}

    pending = db.scalar(select(PendingRegistration).where(PendingRegistration.email == payload.email))
    if pending is not None:
        if _is_expired(pending.expires_at):
            _cleanup_pending_registration(db, pending)
            return {"message": "If your email is registered, a verification code has been sent."}

        otp_code = _create_otp_code()
        pending.otp_code_hash = _hash_refresh_token(otp_code)
        pending.expires_at = datetime.now(timezone.utc) + timedelta(hours=EMAIL_VERIFICATION_TOKEN_TTL_HOURS)
        db.add(pending)
        db.commit()

        _send_email_message(
            to_address=pending.email,
            subject="Votre code de vérification EcoSort",
            body=f"Bonjour,\n\n"
                 f"Votre code de vérification est : {otp_code}\n\n"
                 f"Ce code expire dans {EMAIL_VERIFICATION_TOKEN_TTL_HOURS} heure(s).\n\n"
                 f"Merci,\nL'équipe EcoSort",
        )
        return {"message": "Un code de vérification a été envoyé par email."}

    return {"message": "If your email is registered, a verification code has been sent."}


@app.post("/auth/verify-email")
def verify_email(
    payload: VerifyEmailRequest,
    db: Session = Depends(get_db),
):
    pending = db.scalar(
        select(PendingRegistration).where(PendingRegistration.email == payload.email)
    )
    if pending is not None:
        if _is_expired(pending.expires_at):
            _cleanup_pending_registration(db, pending)
            raise HTTPException(status_code=400, detail="Le code de vérification a expiré. Veuillez vous réinscrire.")

        otp_hash = _hash_refresh_token(payload.token)
        if pending.otp_code_hash != otp_hash:
            raise HTTPException(status_code=400, detail="Code de vérification invalide.")

        user = User(
            email=pending.email,
            full_name=pending.full_name,
            password_hash=pending.password_hash,
            role=pending.role,
            status="pending",
            email_verified=1,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        _cleanup_pending_registration(db, pending)

        _write_audit(
            db,
            actor=user,
            action="auth.register",
            resource_type="user",
            resource_id=user.id,
            details={"role": user.role},
        )
        _write_audit(db, actor=user, action="auth.verify_email", resource_type="user", resource_id=user.id)

        for role in ("admin", "manager"):
            _create_notification(
                db,
                title="Nouvel inscrit",
                message=f"Un nouvel utilisateur s'est inscrit : {user.email}.",
                recipient_role=role,
                related_type="user",
                related_id=str(user.id),
            )

        db.commit()
    else:
        user = db.scalar(select(User).where(User.email == payload.email))
        if user is None:
            raise HTTPException(status_code=400, detail="Email non trouvé.")
        if user.email_verified:
            token = create_access_token({"sub": user.id, "email": user.email})
            refresh_token = _create_refresh_token(db, user)
            return {
                "message": "Email already verified.",
                "access_token": token,
                "refresh_token": refresh_token,
                "token_type": "bearer",
                "user": _serialize_user(user),
            }
        token_record = _get_user_action_token_record(db, payload.token, EmailVerificationToken)
        if token_record is None or token_record.user_id != user.id:
            raise HTTPException(status_code=400, detail="Code de vérification invalide.")
        if _is_expired(token_record.expires_at):
            raise HTTPException(status_code=400, detail="Le code de vérification a expiré.")
        user.email_verified = 1
        db.add(user)
        _mark_user_action_token_used(db, token_record)
        _write_audit(db, actor=user, action="auth.verify_email", resource_type="user", resource_id=user.id)
        db.commit()

    token = create_access_token({"sub": user.id, "email": user.email})
    refresh_token = _create_refresh_token(db, user)
    return {
        "message": "Email verified successfully.",
        "access_token": token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": _serialize_user(user),
    }


@app.post("/auth/request-password-reset")
def request_password_reset(
    payload: RequestPasswordResetRequest,
    db: Session = Depends(get_db),
    user_agent: str | None = Header(default=None, alias="User-Agent"),
):
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is None:
        return {"message": "If your email is registered, a password reset code has been sent."}

    otp_code = _create_otp_code()
    _create_user_action_token(
        db,
        user,
        PasswordResetToken,
        PASSWORD_RESET_TOKEN_TTL_HOURS,
        user_agent=user_agent,
        raw_token=otp_code,
    )
    _send_email_message(
        to_address=user.email,
        subject="Votre code de réinitialisation EcoSort",
        body=f"Bonjour,\n\n"
             f"Votre code de réinitialisation de mot de passe est : {otp_code}\n\n"
             f"Ce code expire dans {PASSWORD_RESET_TOKEN_TTL_HOURS} heure(s).\n\n"
             f"Si vous n'avez pas demandé cette réinitialisation, ignorez cet email.\n\n"
             f"Merci,\nL'équipe EcoSort",
    )
    _write_audit(db, actor=user, action="auth.request_password_reset", resource_type="user", resource_id=user.id)
    return {"message": "Un code de réinitialisation a été envoyé par email."}


@app.post("/auth/verify-reset-otp")
def verify_reset_otp(
    payload: VerifyResetOtpRequest,
    db: Session = Depends(get_db),
):
    token_record = _get_user_action_token_record(db, payload.token, PasswordResetToken)
    if token_record is None or _is_expired(token_record.expires_at):
        raise HTTPException(status_code=400, detail="Invalid or expired token")
    return {"message": "OTP verified successfully."}


@app.post("/auth/reset-password")
def reset_password(
    payload: ResetPasswordRequest,
    db: Session = Depends(get_db),
):
    token_record = _get_user_action_token_record(db, payload.token, PasswordResetToken)
    if token_record is None or _is_expired(token_record.expires_at):
        raise HTTPException(status_code=400, detail="Invalid or expired token")

    user = db.scalar(select(User).where(User.id == token_record.user_id))
    if user is None:
        raise HTTPException(status_code=400, detail="Invalid token")

    user.password_hash = hash_password(payload.password)
    db.add(user)
    _mark_user_action_token_used(db, token_record)
    _write_audit(db, actor=user, action="auth.reset_password", resource_type="user", resource_id=user.id)
    db.commit()
    return {"message": "Password has been reset successfully."}


@limiter.limit("5/minute")
@app.post("/auth/login")
def login_user(
    request: Request,
    payload: LoginRequest,
    db: Session = Depends(get_db),
    user_agent: str | None = Header(default=None, alias="User-Agent"),
):
    user = db.scalar(select(User).where(User.email == payload.email))
    now = datetime.now(timezone.utc)
    if user is not None and user.locked_until is not None:
        locked_until = user.locked_until
        if locked_until.tzinfo is None:
            locked_until = locked_until.replace(tzinfo=timezone.utc)
        if locked_until > now:
            raise HTTPException(status_code=423, detail="Account temporarily locked")

    if user is None or not user.password_hash or not verify_password(payload.password, user.password_hash):
        if user is not None:
            user.failed_login_count += 1
            if user.failed_login_count >= LOCKOUT_THRESHOLD:
                user.locked_until = now + timedelta(minutes=LOCKOUT_MINUTES)
                user.failed_login_count = 0
            db.add(user)
            _write_audit(
                db,
                actor=user,
                action="auth.login_failed",
                resource_type="user",
                resource_id=user.id,
            )
            db.commit()
        raise HTTPException(status_code=401, detail="Invalid email or password")
    if user.status != "active":
        raise HTTPException(status_code=403, detail="User account is not active")
    if not user.email_verified:
        raise HTTPException(status_code=403, detail="Email address is not verified")

    if user.mfa_enabled:
        if payload.mfa_token is not None and payload.mfa_code is not None:
            mfa_record = _get_mfa_token_record(db, payload.mfa_token)
            if (
                mfa_record is None
                or mfa_record.user_id != user.id
                or _is_expired(mfa_record.expires_at)
                or not _verify_mfa_code(mfa_record, payload.mfa_code)
            ):
                raise HTTPException(status_code=401, detail="Invalid or expired MFA code")
            _mark_mfa_token_used(db, mfa_record)
        else:
            code = f"{secrets.randbelow(900000) + 100000}"
            mfa_token = _create_mfa_token(
                db,
                user,
                code,
                user_agent=user_agent,
            )
            _write_audit(db, actor=user, action="auth.mfa.challenge", resource_type="user", resource_id=user.id)
            return {
                "mfa_required": True,
                "mfa_token": mfa_token,
                "mfa_method": user.mfa_method or "email",
                "mfa_code": code,
            }

    user.failed_login_count = 0
    user.locked_until = None
    db.add(user)
    _write_audit(db, actor=user, action="auth.login", resource_type="user", resource_id=user.id)

    for role in ("admin", "manager"):
        _create_notification(
            db,
            title="Connexion utilisateur",
            message=f"L'utilisateur {user.email} s'est connecté.",
            recipient_role=role,
            related_type="user",
            related_id=str(user.id),
        )

    db.commit()
    token = create_access_token({"sub": user.id, "email": user.email})
    refresh_token = _create_refresh_token(db, user, user_agent=user_agent)
    return {
        "access_token": token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": _serialize_user(user),
    }


@limiter.limit("5/minute")
@app.post("/auth/google-login")
def google_login(
    request: Request,
    payload: GoogleLoginRequest,
    db: Session = Depends(get_db),
    user_agent: str | None = Header(default=None, alias="User-Agent"),
):
    google_payload = _verify_google_id_token(payload.id_token)
    if google_payload is None:
        raise HTTPException(status_code=401, detail="Invalid Google identity token")

    user = db.scalar(select(User).where(User.google_id == google_payload["sub"]))
    if user is None:
        user = db.scalar(select(User).where(User.email == google_payload["email"]))
        if user is None:
            user = User(
                email=google_payload["email"],
                full_name=payload.display_name or google_payload.get("name", ""),
                password_hash="",
                google_id=google_payload["sub"],
                role="user",
                status="active",
                email_verified=1,
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            _write_audit(
                db,
                actor=user,
                action="auth.google_register",
                resource_type="user",
                resource_id=user.id,
                details={"email": user.email},
            )

            for role in ("admin", "manager"):
                _create_notification(
                    db,
                    title="Nouvel inscrit (Google)",
                    message=f"Un nouvel utilisateur s'est inscrit via Google : {user.email}.",
                    recipient_role=role,
                    related_type="user",
                    related_id=str(user.id),
                )

            db.commit()
        else:
            user.google_id = google_payload["sub"]
            user.email_verified = 1
            db.add(user)
            db.commit()
            db.refresh(user)

            for role in ("admin", "manager"):
                _create_notification(
                    db,
                    title="Connexion Google",
                    message=f"L'utilisateur {user.email} s'est connecté via Google.",
                    recipient_role=role,
                    related_type="user",
                    related_id=str(user.id),
                )
            db.commit()

    if user.status != "active":
        raise HTTPException(status_code=403, detail="User account is not active")

    if user.mfa_enabled:
        if payload.mfa_token is not None and payload.mfa_code is not None:
            mfa_record = _get_mfa_token_record(db, payload.mfa_token)
            if (
                mfa_record is None
                or mfa_record.user_id != user.id
                or _is_expired(mfa_record.expires_at)
                or not _verify_mfa_code(mfa_record, payload.mfa_code)
            ):
                raise HTTPException(status_code=401, detail="Invalid or expired MFA code")
            _mark_mfa_token_used(db, mfa_record)
        else:
            code = f"{secrets.randbelow(900000) + 100000}"
            mfa_token = _create_mfa_token(db, user, code, user_agent=user_agent)
            _write_audit(db, actor=user, action="auth.mfa.challenge", resource_type="user", resource_id=user.id)
            return {
                "mfa_required": True,
                "mfa_token": mfa_token,
                "mfa_method": user.mfa_method or "email",
                "mfa_code": code,
            }

    _write_audit(db, actor=user, action="auth.google_login", resource_type="user", resource_id=user.id)
    token = create_access_token({"sub": user.id, "email": user.email})
    refresh_token = _create_refresh_token(db, user, user_agent=user_agent)
    return {
        "access_token": token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": _serialize_user(user),
    }


@app.post("/auth/refresh")
def refresh_access_token(
    payload: RefreshTokenRequest,
    db: Session = Depends(get_db),
    user_agent: str | None = Header(default=None, alias="User-Agent"),
):
    token_record = _get_refresh_token_record(db, payload.refresh_token)
    if token_record is None or token_record.revoked:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")
    if _is_expired(token_record.expires_at):
        _revoke_refresh_token(db, token_record)
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    user = db.scalar(select(User).where(User.id == token_record.user_id))
    if user is None or user.status != "active":
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    _revoke_refresh_token(db, token_record)
    _write_audit(db, actor=user, action="auth.refresh", resource_type="user", resource_id=user.id)
    access_token = create_access_token({"sub": user.id, "email": user.email})
    refresh_token = _create_refresh_token(db, user, user_agent=user_agent)
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": _serialize_user(user),
    }


@app.post("/auth/logout")
def logout_user(
    payload: LogoutRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    token_record = _get_refresh_token_record(db, payload.refresh_token)
    if token_record is None or token_record.user_id != current_user.id:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    _revoke_refresh_token(db, token_record)
    _write_audit(db, actor=current_user, action="auth.logout", resource_type="user", resource_id=current_user.id)
    return {"message": "Logged out successfully"}


@app.post("/auth/logout_all")
def logout_all_sessions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    tokens = db.scalars(
        select(RefreshToken).where(RefreshToken.user_id == current_user.id, RefreshToken.revoked == 0)
    ).all()
    for token in tokens:
        token.revoked = 1
        db.add(token)
    db.commit()
    _write_audit(db, actor=current_user, action="auth.logout_all", resource_type="user", resource_id=current_user.id)
    return {"message": "All sessions revoked"}


@app.get("/users/me")
def get_me(current_user: User = Depends(get_current_user)):
    return _serialize_user(current_user)


@app.patch("/users/me")
def update_me(
    payload: UpdateProfileRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    current_user.full_name = payload.full_name.strip()
    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return _serialize_user(current_user)


@app.post("/users/me/photo")
def update_profile_photo(
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    stored_path = _store_upload(image)
    current_user.profile_image_path = str(stored_path)
    db.add(current_user)
    db.commit()
    db.refresh(current_user)
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
    debug: bool = False,
    uploaded_image: UploadedImage | None = None,
):
    classifier, active_profile = _get_vision_classifier(db)

    from concurrent.futures import ThreadPoolExecutor

    def _run_vision():
        return classifier.predict(stored_path, top_k=top_k)

    def _run_ocr():
        if disable_ocr:
            return {
                "raw_text": "",
                "clean_text": "",
                "predicted_class": None,
                "confidence": 0.0,
                "scores": {},
                "matched_keywords": {},
                "has_text_signal": False,
            }
        return ocr_analyzer.analyze(stored_path)

    with ThreadPoolExecutor(max_workers=2) as pool:
        vision_future = pool.submit(_run_vision)
        ocr_future = pool.submit(_run_ocr)
        raw_vision_result = vision_future.result()
        ocr_result = ocr_future.result()

    vision_result = raw_vision_result if debug else {
        key: value for key, value in raw_vision_result.items() if key != "preprocessing"
    }

    decision = fuse_predictions(vision_result, ocr_result, policy=active_profile["policy"])

    prediction = Prediction(
        user_id=user.id if user else None,
        uploaded_image_id=uploaded_image.id if uploaded_image else None,
        image_filename=image_filename,
        stored_image_path=str(stored_path),
        model_profile=active_profile["name"],
        predicted_class=decision["recommended_class"],
        final_confidence=float(decision["final_confidence"]),
        review_status="review" if decision.get("status") == "review" else "auto_accepted",
        vision_json=json.dumps(vision_result, ensure_ascii=False),
        ocr_json=json.dumps(ocr_result, ensure_ascii=False),
        decision_json=json.dumps(decision, ensure_ascii=False),
    )
    db.add(prediction)
    db.commit()
    db.refresh(prediction)
    if decision.get("status") == "review":
        _create_notification(
            db,
            title="Nouvelle analyse a verifier",
            message=(
                "Une nouvelle analyse generee par un utilisateur doit etre reveue par un administrateur."
            ),
            recipient_role="admin",
            related_type="prediction",
            related_id=str(prediction.id),
        )
    if user is not None:
        _write_audit(
            db,
            actor=user,
            action="prediction.created",
            resource_type="prediction",
            resource_id=prediction.id,
            details={"recommended_class": decision["recommended_class"], "status": decision.get("status")},
        )
        db.commit()

    return prediction, vision_result, ocr_result, decision, active_profile


@limiter.limit("10/hour")
@app.post("/predict")
def predict_image(
    request: Request,
    image: UploadFile = File(...),
    disable_ocr: bool = Query(False),
    top_k: int = Query(3, ge=1, le=5),
    debug: bool = Query(False, description="Return preprocessing diagnostics in the prediction response"),
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
        prediction, vision_result, ocr_result, decision, active_profile = _run_prediction(
            image_filename=image.filename or stored_path.name,
            stored_path=stored_path,
            disable_ocr=disable_ocr,
            top_k=top_k,
            debug=debug,
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
            "image_url": f"/uploads/{stored_path.name}",
            "model_profile": active_profile["name"],
            "review_status": prediction.review_status,
            "created_at": prediction.created_at.isoformat(),
            "vision": vision_result,
            "ocr": ocr_result,
            "decision": decision,
        }
    )


@limiter.limit("10/hour")
@app.post("/analyze")
def analyze_alias(
    request: Request,
    image: UploadFile = File(...),
    disable_ocr: bool = Query(False),
    top_k: int = Query(3, ge=1, le=5),
    debug: bool = Query(False, description="Return preprocessing diagnostics in the prediction response"),
    current_user: User | None = Depends(get_optional_user),
    db: Session = Depends(get_db),
):
    return predict_image(
        request=request,
        image=image,
        disable_ocr=disable_ocr,
        top_k=top_k,
        debug=debug,
        current_user=current_user,
        db=db,
    )


@app.get("/predictions")
def list_predictions(
    limit: int = Query(50, ge=1, le=200),
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


def _serialize_predictions_csv(predictions: list[Prediction]) -> str:
    buffer = StringIO()
    writer = csv.writer(buffer)
    writer.writerow(
        [
            "id",
            "user_id",
            "created_at",
            "image_filename",
            "model_profile",
            "predicted_class",
            "final_confidence",
            "review_status",
            "decision_status",
            "decision_reason",
            "decision_alternative_class",
            "decision_alternative_probability",
            "decision_second_candidate",
            "decision_second_candidate_probability",
        ]
    )
    for prediction in predictions:
        decision = {}
        try:
            decision = json.loads(prediction.decision_json or "{}")
        except (TypeError, ValueError):
            decision = {}

        writer.writerow(
            [
                prediction.id,
                prediction.user_id,
                prediction.created_at.isoformat() if prediction.created_at else "",
                prediction.image_filename,
                prediction.model_profile,
                prediction.predicted_class,
                float(prediction.final_confidence) if prediction.final_confidence is not None else "",
                prediction.review_status,
                decision.get("status", ""),
                decision.get("reason", ""),
                decision.get("alternative_class", ""),
                decision.get("alternative_probability", ""),
                decision.get("second_candidate", ""),
                decision.get("second_candidate_probability", ""),
            ]
        )
    return buffer.getvalue()


def _normalize_export_dates(start_date: str | None, end_date: str | None) -> tuple[datetime, datetime]:
    now = datetime.utcnow()
    if start_date is None and end_date is None:
        end = now
        start = now - timedelta(days=30)
    else:
        if start_date is not None:
            try:
                start = datetime.fromisoformat(start_date)
            except ValueError:
                raise HTTPException(status_code=400, detail="start_date must be ISO format YYYY-MM-DD or YYYY-MM-DDThh:mm:ss")
        else:
            start = now - timedelta(days=30)
        if end_date is not None:
            try:
                end = datetime.fromisoformat(end_date)
            except ValueError:
                raise HTTPException(status_code=400, detail="end_date must be ISO format YYYY-MM-DD or YYYY-MM-DDThh:mm:ss")
        else:
            end = now
        if start.tzinfo is not None:
            start = start.astimezone(timezone.utc).replace(tzinfo=None)
        if end.tzinfo is not None:
            end = end.astimezone(timezone.utc).replace(tzinfo=None)
        if start >= end:
            raise HTTPException(status_code=400, detail="start_date must be before end_date")
    return start, end


@app.get("/history/export")
def history_export(
    format: str = Query("csv", regex="^(csv)$"),
    start_date: str | None = Query(None),
    end_date: str | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    start, end = _normalize_export_dates(start_date, end_date)
    predictions = db.scalars(
        select(Prediction)
        .where(
            Prediction.user_id == current_user.id,
            Prediction.created_at >= start,
            Prediction.created_at < end,
        )
        .order_by(Prediction.id.desc())
    ).all()
    if format == "csv":
        csv_content = _serialize_predictions_csv(predictions)
        filename = f"user_history_{current_user.id}_{start.date()}_{end.date()}.csv"
        return Response(
            content=csv_content,
            media_type="text/csv",
            headers={
                "Content-Disposition": f"attachment; filename=\"{filename}\"",
            },
        )
    raise HTTPException(status_code=400, detail="Unsupported export format")


@app.get("/admin/reports/summary")
def admin_reports_summary(
    period: str = Query("daily", regex="^(daily|weekly|monthly)$"),
    current_user: User = Depends(get_current_privileged_user),
    db: Session = Depends(get_db),
):
    now = datetime.utcnow()
    if period == "daily":
        since = now - timedelta(days=1)
    elif period == "weekly":
        since = now - timedelta(days=7)
    else:
        since = now - timedelta(days=30)

    total_predictions = db.scalar(select(func.count(Prediction.id)).where(Prediction.created_at >= since)) or 0
    predictions_by_class = db.execute(
        select(Prediction.predicted_class, func.count(Prediction.id))
        .where(Prediction.created_at >= since)
        .group_by(Prediction.predicted_class)
        .order_by(func.count(Prediction.id).desc())
    ).all()
    review_stats = db.execute(
        select(Prediction.review_status, func.count(Prediction.id))
        .where(Prediction.created_at >= since)
        .group_by(Prediction.review_status)
    ).all()
    new_user_count = db.scalar(select(func.count(User.id)).where(User.created_at >= since)) or 0
    active_user_count = db.scalar(select(func.count(User.id)).where(User.status == "active")) or 0

    return {
        "period": period,
        "generated_at": now.isoformat(),
        "total_predictions": total_predictions,
        "predictions_by_class": {class_name: count for class_name, count in predictions_by_class},
        "review_status_breakdown": {status: count for status, count in review_stats},
        "new_user_count": new_user_count,
        "active_user_count": active_user_count,
    }


@app.get("/admin/reports/export")
def admin_reports_export(
    format: str = Query("csv", regex="^(csv)$"),
    start_date: str | None = Query(None),
    end_date: str | None = Query(None),
    current_user: User = Depends(get_current_privileged_user),
    db: Session = Depends(get_db),
):
    start, end = _normalize_export_dates(start_date, end_date)
    predictions = db.scalars(
        select(Prediction)
        .where(Prediction.created_at >= start, Prediction.created_at < end)
        .order_by(Prediction.id.desc())
    ).all()
    if format == "csv":
        csv_content = _serialize_predictions_csv(predictions)
        filename = f"admin_report_{start.date()}_{end.date()}.csv"
        return Response(
            content=csv_content,
            media_type="text/csv",
            headers={
                "Content-Disposition": f"attachment; filename=\"{filename}\"",
            },
        )
    raise HTTPException(status_code=400, detail="Unsupported export format")


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


@app.patch("/predictions/{prediction_id}")
def update_prediction(
    prediction_id: int,
    payload: UpdatePredictionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    prediction = db.scalar(
        select(Prediction).where(Prediction.id == prediction_id, Prediction.user_id == current_user.id)
    )
    if prediction is None:
        raise HTTPException(status_code=404, detail="Prediction not found")

    decision = json.loads(prediction.decision_json)
    decision["recommended_class"] = payload.predicted_class
    decision["status"] = "accepted"
    decision["reason"] = "user_correction"
    decision["final_confidence"] = 1.0

    prediction.predicted_class = payload.predicted_class
    prediction.final_confidence = 1.0
    prediction.review_status = "validated"
    prediction.decision_json = json.dumps(decision, ensure_ascii=False)
    db.add(prediction)
    _write_audit(
        db,
        actor=current_user,
        action="prediction.user_corrected",
        resource_type="prediction",
        resource_id=prediction.id,
        details={"predicted_class": payload.predicted_class},
    )
    db.commit()
    db.refresh(prediction)
    return _serialize_prediction(prediction)


@app.delete("/predictions/{prediction_id}")
def delete_prediction(
    prediction_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    prediction = db.scalar(
        select(Prediction).where(Prediction.id == prediction_id, Prediction.user_id == current_user.id)
    )
    if prediction is None:
        raise HTTPException(status_code=404, detail="Prediction not found")

    db.delete(prediction)
    db.commit()
    return {"message": "Prediction deleted successfully", "prediction_id": prediction_id}


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


@app.get("/admin/stats")
def get_admin_stats(
    current_user: User = Depends(get_current_privileged_user),
    db: Session = Depends(get_db),
):
    base_stats = get_stats(db=db)
    review_count = db.scalar(select(func.count(Prediction.id)).where(Prediction.review_status == "review")) or 0
    validated_count = db.scalar(select(func.count(Prediction.id)).where(Prediction.review_status == "validated")) or 0
    active_user_count = db.scalar(select(func.count(User.id)).where(User.status == "active")) or 0
    suspended_user_count = db.scalar(select(func.count(User.id)).where(User.status == "suspended")) or 0
    average_confidence = db.scalar(select(func.avg(Prediction.final_confidence))) or 0
    base_stats.update(
        {
            "review_count": review_count,
            "validated_count": validated_count,
            "active_user_count": active_user_count,
            "suspended_user_count": suspended_user_count,
            "average_confidence": round(float(average_confidence), 4),
        }
    )
    return base_stats


@app.get("/admin/users")
def admin_list_users(
    limit: int = Query(50, ge=1, le=200),
    current_user: User = Depends(get_current_privileged_user),
    db: Session = Depends(get_db),
):
    users = db.scalars(select(User).order_by(User.id.desc()).limit(limit)).all()
    return {"count": len(users), "items": [_serialize_user(user) for user in users]}


@app.post("/admin/users")
def admin_create_user(
    payload: AdminCreateUserRequest,
    current_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    existing = db.scalar(select(User).where(User.email == payload.email))
    if existing is not None:
        raise HTTPException(status_code=409, detail="A user already exists with this email")

    user = User(
        email=payload.email,
        full_name=payload.full_name.strip(),
        password_hash=hash_password(payload.password),
        role=payload.role,
        status=payload.status,
        email_verified=1 if payload.email_verified else 0,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    _write_audit(
        db,
        actor=current_user,
        action="admin.user_created",
        resource_type="user",
        resource_id=user.id,
        details={
            "email": user.email,
            "role": user.role,
            "status": user.status,
            "email_verified": bool(user.email_verified),
        },
    )
    return _serialize_user(user)


@app.post("/admin/users/reset-admin")
def admin_reset_admin(
    payload: AdminResetAdminRequest,
    current_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is None:
        user = User(
            email=payload.email,
            full_name=payload.full_name.strip(),
            password_hash=hash_password(payload.password),
            role="admin",
            status="active" if payload.activate else "pending",
            email_verified=1 if payload.verify_email else 0,
        )
        db.add(user)
        action = "admin.user_created"
        details = {
            "email": user.email,
            "role": user.role,
            "status": user.status,
            "email_verified": bool(user.email_verified),
            "reset_action": "created_admin",
        }
    else:
        user.full_name = payload.full_name.strip()
        user.password_hash = hash_password(payload.password)
        user.role = "admin"
        if payload.activate:
            user.status = "active"
        if payload.verify_email:
            user.email_verified = 1
        db.add(user)
        action = "admin.user_updated"
        details = {
            "email": user.email,
            "role": user.role,
            "status": user.status,
            "email_verified": bool(user.email_verified),
            "reset_action": "promoted_to_admin",
        }

    db.commit()
    db.refresh(user)
    _write_audit(
        db,
        actor=current_user,
        action=action,
        resource_type="user",
        resource_id=user.id,
        details=details,
    )
    return _serialize_user(user)


@app.delete("/admin/users/{user_id}")
def admin_delete_user(
    user_id: int,
    current_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    user = db.scalar(select(User).where(User.id == user_id))
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id == current_user.id:
        raise HTTPException(status_code=400, detail="Administrators cannot delete their own account")
    if user.role == "admin":
        admin_count = db.scalar(select(func.count(User.id)).where(User.role == "admin")) or 0
        if admin_count <= 1:
            raise HTTPException(status_code=400, detail="Cannot delete the last administrator account")

    for prediction in db.scalars(select(Prediction).where(Prediction.user_id == user_id)).all():
        prediction.user_id = None
        db.add(prediction)
    for upload in db.scalars(select(UploadedImage).where(UploadedImage.user_id == user_id)).all():
        upload.user_id = None
        db.add(upload)
    for feedback in db.scalars(select(Feedback).where(Feedback.user_id == user_id)).all():
        feedback.user_id = None
        db.add(feedback)

    for token in db.scalars(select(RefreshToken).where(RefreshToken.user_id == user_id)).all():
        db.delete(token)
    for notification in db.scalars(select(Notification).where(Notification.recipient_user_id == user_id)).all():
        db.delete(notification)
    for reset_token in db.scalars(select(PasswordResetToken).where(PasswordResetToken.user_id == user_id)).all():
        db.delete(reset_token)
    for verification in db.scalars(select(EmailVerificationToken).where(EmailVerificationToken.user_id == user_id)).all():
        db.delete(verification)
    for device_token in db.scalars(select(DeviceToken).where(DeviceToken.user_id == user_id)).all():
        db.delete(device_token)
    for mfa_token in db.scalars(select(MfaToken).where(MfaToken.user_id == user_id)).all():
        db.delete(mfa_token)
    for audit_log in db.scalars(select(AuditLog).where(AuditLog.actor_user_id == user_id)).all():
        audit_log.actor_user_id = None
        db.add(audit_log)

    _write_audit(
        db,
        actor=current_user,
        action="admin.user_deleted",
        resource_type="user",
        resource_id=user.id,
        details={"email": user.email, "role": user.role, "status": user.status},
    )

    db.delete(user)
    db.commit()
    return {"message": "User deleted successfully"}


@app.patch("/admin/users/{user_id}")
def admin_update_user(
    user_id: int,
    payload: AdminUpdateUserRequest,
    current_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    user = db.scalar(select(User).where(User.id == user_id))
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id == current_user.id and payload.status == "suspended":
        raise HTTPException(status_code=400, detail="An administrator cannot suspend their own account")

    changes = {}
    if payload.full_name is not None:
        user.full_name = payload.full_name.strip()
        changes["full_name"] = user.full_name
    if payload.role is not None:
        user.role = payload.role
        changes["role"] = user.role
    if payload.status is not None:
        user.status = payload.status
        changes["status"] = user.status
    if payload.email_verified is not None:
        user.email_verified = 1 if payload.email_verified else 0
        changes["email_verified"] = bool(user.email_verified)

    db.add(user)
    _write_audit(
        db,
        actor=current_user,
        action="admin.user_updated",
        resource_type="user",
        resource_id=user.id,
        details=changes,
    )
    _create_notification(
        db,
        title="Votre compte a ete modifie",
        message=(
            "Un administrateur a mis a jour les parametres de votre compte. "
            f"Modifications: {json.dumps(changes, ensure_ascii=False)}"
        ),
        recipient_user_id=user.id,
        related_type="user",
        related_id=str(user.id),
    )
    db.commit()
    db.refresh(user)
    return _serialize_user(user)


@app.get("/admin/predictions")
def admin_list_predictions(
    review_status: str | None = Query(default=None),
    limit: int = Query(100, ge=1, le=500),
    current_user: User = Depends(get_current_privileged_user),
    db: Session = Depends(get_db),
):
    statement = select(Prediction).order_by(Prediction.id.desc()).limit(limit)
    if review_status is not None:
        normalized = review_status.strip().lower()
        if normalized not in REVIEW_STATUSES:
            raise HTTPException(status_code=400, detail="Invalid review_status")
        statement = select(Prediction).where(Prediction.review_status == normalized).order_by(Prediction.id.desc()).limit(limit)
    items = db.scalars(statement).all()
    return {"count": len(items), "items": [_serialize_admin_prediction(item) for item in items]}


@app.patch("/admin/predictions/{prediction_id}/validate")
def admin_validate_prediction(
    prediction_id: int,
    payload: AdminValidatePredictionRequest,
    current_user: User = Depends(get_current_privileged_user),
    db: Session = Depends(get_db),
):
    prediction = db.scalar(select(Prediction).where(Prediction.id == prediction_id))
    if prediction is None:
        raise HTTPException(status_code=404, detail="Prediction not found")

    decision = json.loads(prediction.decision_json)
    decision["recommended_class"] = payload.predicted_class
    decision["status"] = "accepted" if payload.review_status == "validated" else payload.review_status
    decision["reason"] = "manual_validation"
    decision["validation_note"] = payload.note
    decision["validated_by"] = current_user.id
    decision["final_confidence"] = 1.0 if payload.review_status == "validated" else prediction.final_confidence

    prediction.predicted_class = payload.predicted_class
    prediction.final_confidence = float(decision["final_confidence"])
    prediction.review_status = payload.review_status
    prediction.decision_json = json.dumps(decision, ensure_ascii=False)
    db.add(prediction)
    _write_audit(
        db,
        actor=current_user,
        action="admin.prediction_validated",
        resource_type="prediction",
        resource_id=prediction.id,
        details={
            "predicted_class": payload.predicted_class,
            "review_status": payload.review_status,
            "note": payload.note,
        },
    )
    if prediction.user_id is not None:
        user = db.scalar(select(User).where(User.id == prediction.user_id))
        if user is not None:
            _create_notification(
                db,
                title="Votre analyse a ete mise a jour",
                message=(
                    "Votre analyse a ete examinee par un administrateur. "
                    f"Resultat: {payload.review_status}, classe: {payload.predicted_class}."
                ),
                recipient_user_id=user.id,
                related_type="prediction",
                related_id=str(prediction.id),
            )
    db.commit()
    db.refresh(prediction)
    return _serialize_admin_prediction(prediction)


@app.delete("/admin/predictions/{prediction_id}")
def admin_delete_prediction(
    prediction_id: int,
    current_user: User = Depends(get_current_privileged_user),
    db: Session = Depends(get_db),
):
    prediction = db.scalar(select(Prediction).where(Prediction.id == prediction_id))
    if prediction is None:
        raise HTTPException(status_code=404, detail="Prediction not found")

    if prediction.user_id is not None:
        user = db.scalar(select(User).where(User.id == prediction.user_id))
        if user is not None:
            _create_notification(
                db,
                title="Votre analyse a ete supprimee",
                message="Votre analyse a ete supprimee par un administrateur.",
                recipient_user_id=user.id,
                related_type="prediction",
                related_id=str(prediction.id),
            )

    _write_audit(
        db,
        actor=current_user,
        action="admin.prediction_deleted",
        resource_type="prediction",
        resource_id=prediction.id,
        details={
            "predicted_class": prediction.predicted_class,
            "review_status": prediction.review_status,
        },
    )

    image = db.scalar(select(UploadedImage).where(UploadedImage.id == prediction.image_id))
    db.delete(prediction)
    if image is not None:
        db.delete(image)
    db.commit()
    return {"message": "Prediction deleted successfully", "prediction_id": prediction_id}


@app.get("/admin/feedback")
def admin_list_feedback(
    limit: int = Query(50, ge=1, le=200),
    current_user: User = Depends(get_current_privileged_user),
    db: Session = Depends(get_db),
):
    items = db.scalars(select(Feedback).order_by(Feedback.id.desc()).limit(limit)).all()
    return {"count": len(items), "items": [_serialize_feedback(item) for item in items]}


@app.post("/admin/feedback/{feedback_id}/reply")
def admin_reply_feedback(
    feedback_id: int,
    payload: ReplyRequest,
    current_user: User = Depends(get_current_privileged_user),
    db: Session = Depends(get_db),
):
    feedback = db.scalar(select(Feedback).where(Feedback.id == feedback_id))
    if feedback is None:
        raise HTTPException(status_code=404, detail="Feedback not found")

    feedback.admin_reply = payload.reply
    feedback.admin_replied_at = datetime.now(timezone.utc)
    feedback.replied_by_user_id = current_user.id
    db.add(feedback)

    if feedback.user_id:
        _create_notification(
            db,
            title="Réponse à votre feedback",
            message=f"Un administrateur a répondu à votre feedback sur l'analyse #{feedback.prediction_id}.",
            recipient_user_id=feedback.user_id,
            related_type="feedback",
            related_id=str(feedback.id),
        )
    db.commit()
    db.refresh(feedback)
    return _serialize_feedback(feedback)


@app.get("/admin/audit-logs")
def admin_list_audit_logs(
    limit: int = Query(50, ge=1, le=200),
    current_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    items = db.scalars(select(AuditLog).order_by(AuditLog.id.desc()).limit(limit)).all()
    return {"count": len(items), "items": [_serialize_audit_log(item) for item in items]}


@app.get("/notifications")
def list_notifications(
    limit: int = Query(20, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = select(Notification).where(
        (Notification.recipient_user_id == current_user.id)
        | (Notification.recipient_role == current_user.role)
        | (Notification.recipient_role == 'admin')
    ).order_by(Notification.created_at.desc()).limit(limit)
    items = db.scalars(query).all()
    return {"count": len(items), "items": [_serialize_notification(item) for item in items]}


@app.patch("/notifications/{notification_id}/read")
def mark_notification_read(
    notification_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    notification = db.scalar(select(Notification).where(Notification.id == notification_id))
    if notification is None:
        raise HTTPException(status_code=404, detail="Notification introuvable")
    if notification.recipient_user_id is not None and notification.recipient_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acces refuse")
    if notification.recipient_role is not None and notification.recipient_role != current_user.role:
        raise HTTPException(status_code=403, detail="Acces refuse")

    notification.is_read = 1
    db.add(notification)
    db.commit()
    return {"message": "Notification marquee comme lue"}


@app.post("/notifications/device-tokens")
def register_device_token(
    payload: DeviceTokenRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    token_record = db.scalar(select(DeviceToken).where(DeviceToken.token == payload.device_token))
    if token_record is None:
        token_record = DeviceToken(
            user_id=current_user.id,
            token=payload.device_token,
            platform=payload.platform,
        )
    else:
        token_record.user_id = current_user.id
        token_record.platform = payload.platform
        token_record.last_seen = datetime.now(timezone.utc)

    db.add(token_record)
    db.commit()
    db.refresh(token_record)
    return {"message": "Device token enregistré."}


@app.delete("/notifications/device-tokens")
def unregister_device_token(
    payload: DeviceTokenRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    token_record = db.scalar(select(DeviceToken).where(DeviceToken.token == payload.device_token))
    if token_record is None or token_record.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Device token not found")
    db.delete(token_record)
    db.commit()
    return {"message": "Device token supprimé."}


@app.post("/notifications/device-tokens/unregister")
def unregister_device_token_via_post(
    payload: DeviceTokenRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return unregister_device_token(payload, current_user, db)


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


@app.post("/admin/categories")
def admin_create_category(
    payload: CategoryRequest,
    current_user: User = Depends(get_current_privileged_user),
    db: Session = Depends(get_db),
):
    existing = db.scalar(select(Category).where(Category.name == payload.name))
    if existing is not None:
        raise HTTPException(status_code=409, detail="Category already exists")
    category = Category(
        name=payload.name,
        description=payload.description.strip(),
        sort_guidance=payload.sort_guidance.strip(),
    )
    db.add(category)
    _write_audit(
        db,
        actor=current_user,
        action="admin.category_created",
        resource_type="category",
        details={"name": payload.name},
    )
    db.commit()
    db.refresh(category)
    return {
        "id": category.id,
        "name": category.name,
        "description": category.description,
        "sort_guidance": category.sort_guidance,
    }


@app.patch("/admin/categories/{category_id}")
def admin_update_category(
    category_id: int,
    payload: CategoryRequest,
    current_user: User = Depends(get_current_privileged_user),
    db: Session = Depends(get_db),
):
    category = db.scalar(select(Category).where(Category.id == category_id))
    if category is None:
        raise HTTPException(status_code=404, detail="Category not found")
    duplicate = db.scalar(select(Category).where(Category.name == payload.name, Category.id != category_id))
    if duplicate is not None:
        raise HTTPException(status_code=409, detail="Category name already exists")

    category.name = payload.name
    category.description = payload.description.strip()
    category.sort_guidance = payload.sort_guidance.strip()
    db.add(category)
    _write_audit(
        db,
        actor=current_user,
        action="admin.category_updated",
        resource_type="category",
        resource_id=category.id,
        details={"name": category.name},
    )
    db.commit()
    db.refresh(category)
    return {
        "id": category.id,
        "name": category.name,
        "description": category.description,
        "sort_guidance": category.sort_guidance,
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
    for role in ("admin", "manager"):
        _create_notification(
            db,
            title="Nouveau feedback utilisateur",
            message=(
                "Un utilisateur a soumis un feedback pour une analyse. "
                f"Prediction #{feedback.prediction_id}, note: {feedback.rating}."
            ),
            recipient_role=role,
            related_type="feedback",
            related_id=str(feedback.id),
        )
    db.commit()
    db.refresh(feedback)
    return {
        "id": feedback.id,
        "prediction_id": feedback.prediction_id,
        "rating": feedback.rating,
        "comment": feedback.comment,
        "created_at": feedback.created_at.isoformat(),
    }