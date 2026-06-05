from datetime import datetime, timezone

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


def utcnow():
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    profile_image_path: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)

    predictions = relationship("Prediction", back_populates="user")
    uploaded_images = relationship("UploadedImage", back_populates="user")
    feedback_items = relationship("Feedback", back_populates="user")


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    sort_guidance: Mapped[str] = mapped_column(Text, nullable=False)


class UploadedImage(Base):
    __tablename__ = "uploaded_images"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    stored_image_path: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)

    user = relationship("User", back_populates="uploaded_images")
    predictions = relationship("Prediction", back_populates="uploaded_image")


class Prediction(Base):
    __tablename__ = "predictions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    uploaded_image_id: Mapped[int | None] = mapped_column(ForeignKey("uploaded_images.id"), nullable=True)
    image_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    stored_image_path: Mapped[str] = mapped_column(Text, nullable=False)
    model_profile: Mapped[str] = mapped_column(String(255), nullable=False)
    predicted_class: Mapped[str] = mapped_column(String(100), nullable=False)
    final_confidence: Mapped[float] = mapped_column(Float, nullable=False)
    vision_json: Mapped[str] = mapped_column(Text, nullable=False)
    ocr_json: Mapped[str] = mapped_column(Text, nullable=False)
    decision_json: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)

    user = relationship("User", back_populates="predictions")
    uploaded_image = relationship("UploadedImage", back_populates="predictions")
    feedback_items = relationship("Feedback", back_populates="prediction")


class Feedback(Base):
    __tablename__ = "feedback"
    __table_args__ = (UniqueConstraint("prediction_id", "user_id", name="uq_feedback_prediction_user"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    prediction_id: Mapped[int] = mapped_column(ForeignKey("predictions.id"), nullable=False)
    rating: Mapped[int] = mapped_column(Integer, nullable=False)
    comment: Mapped[str] = mapped_column(Text, default="", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)

    user = relationship("User", back_populates="feedback_items")
    prediction = relationship("Prediction", back_populates="feedback_items")
