import json
import os
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import DateTime, Integer, String, Text, create_engine, select
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker


ROOT = Path(__file__).resolve().parent
DEFAULT_SQLITE_URL = f"sqlite:///{(ROOT / 'backend_data' / 'analysis_history.db').as_posix()}"


class Base(DeclarativeBase):
    pass


class AnalysisHistory(Base):
    __tablename__ = "analysis_history"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    stored_image_path: Mapped[str] = mapped_column(Text, nullable=False)
    model_profile: Mapped[str] = mapped_column(String(255), nullable=False)
    vision_json: Mapped[str] = mapped_column(Text, nullable=False)
    ocr_json: Mapped[str] = mapped_column(Text, nullable=False)
    decision_json: Mapped[str] = mapped_column(Text, nullable=False)


def get_database_url():
    database_url = os.getenv("DATABASE_URL")
    if database_url:
        return database_url
    return DEFAULT_SQLITE_URL


class AnalysisHistoryStore:
    def __init__(self, database_url: str | None = None):
        self.database_url = database_url or get_database_url()
        self._ensure_sqlite_parent_dir()
        self.engine = create_engine(self.database_url, future=True)
        self.session_factory = sessionmaker(bind=self.engine, future=True)
        self._initialize()

    @property
    def backend_name(self):
        return self.engine.url.get_backend_name()

    def _ensure_sqlite_parent_dir(self):
        if self.database_url.startswith("sqlite:///"):
            db_path = Path(self.database_url.replace("sqlite:///", "", 1))
            db_path.parent.mkdir(parents=True, exist_ok=True)

    def _initialize(self):
        Base.metadata.create_all(self.engine)

    def save_analysis(
        self,
        *,
        original_filename: str,
        stored_image_path: str,
        model_profile: str,
        vision_result: dict,
        ocr_result: dict,
        decision: dict,
    ):
        created_at = datetime.now(timezone.utc)
        with self.session_factory() as session:
            record = AnalysisHistory(
                created_at=created_at,
                original_filename=original_filename,
                stored_image_path=stored_image_path,
                model_profile=model_profile,
                vision_json=json.dumps(vision_result, ensure_ascii=False),
                ocr_json=json.dumps(ocr_result, ensure_ascii=False),
                decision_json=json.dumps(decision, ensure_ascii=False),
            )
            session.add(record)
            session.commit()
            session.refresh(record)
            return record.id

    def list_analyses(self, limit: int = 50):
        safe_limit = max(1, min(limit, 200))
        with self.session_factory() as session:
            statement = (
                select(AnalysisHistory)
                .order_by(AnalysisHistory.id.desc())
                .limit(safe_limit)
            )
            rows = session.scalars(statement).all()
        return [self._row_to_record(row) for row in rows]

    def get_analysis(self, analysis_id: int):
        with self.session_factory() as session:
            row = session.get(AnalysisHistory, analysis_id)
        if row is None:
            return None
        return self._row_to_record(row)

    def _row_to_record(self, row: AnalysisHistory):
        return {
            "id": row.id,
            "created_at": row.created_at.isoformat(),
            "original_filename": row.original_filename,
            "stored_image_path": row.stored_image_path,
            "model_profile": row.model_profile,
            "vision": json.loads(row.vision_json),
            "ocr": json.loads(row.ocr_json),
            "decision": json.loads(row.decision_json),
        }
