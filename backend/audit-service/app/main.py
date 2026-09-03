import os
import enum
from datetime import datetime
from uuid import uuid4
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from sqlalchemy import create_engine, Column, String, DateTime, JSON, Enum as SQLEnum
from sqlalchemy.orm import DeclarativeBase, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+psycopg://grog:grog@grog-postgres:5432/grog")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

class Base(DeclarativeBase):
    pass

class LogCategory(str, enum.Enum):
    SECURITY = "SECURITY"
    APPLICATION = "APPLICATION"
    HARDWARE = "HARDWARE"

class AuditLog(Base):
    __tablename__ = "audit_logs"
    id = Column(String, primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.utcnow)
    category = Column(SQLEnum(LogCategory), nullable=False)
    action = Column(String, index=True)
    actor_id = Column(String, nullable=True) # email or hardware ID
    machine_id = Column(String, nullable=True)
    details = Column(JSON, nullable=True)

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Audit Service")

class LogCreateRequest(BaseModel):
    category: LogCategory
    action: str
    actor_id: Optional[str] = None
    machine_id: Optional[str] = None
    details: Optional[Dict[str, Any]] = None

class LogResponse(BaseModel):
    id: str
    timestamp: datetime
    category: LogCategory
    action: str
    actor_id: Optional[str]
    machine_id: Optional[str]
    details: Optional[Dict[str, Any]]

@app.post("/api/v1/audit/logs", response_model=LogResponse)
def ingest_log(req: LogCreateRequest):
    with SessionLocal() as db:
        new_log = AuditLog(
            id=str(uuid4()),
            timestamp=datetime.utcnow(),
            category=req.category,
            action=req.action,
            actor_id=req.actor_id,
            machine_id=req.machine_id,
            details=req.details
        )
        db.add(new_log)
        db.commit()
        db.refresh(new_log)
        return new_log

@app.get("/api/v1/audit/logs", response_model=List[LogResponse])
def get_logs(
    category: Optional[LogCategory] = None,
    machine_id: Optional[str] = None,
    limit: int = Query(50, le=500),
    offset: int = 0
):
    with SessionLocal() as db:
        query = db.query(AuditLog)
        if category:
            query = query.filter(AuditLog.category == category)
        if machine_id:
            query = query.filter(AuditLog.machine_id == machine_id)
        
        query = query.order_by(AuditLog.timestamp.desc())
        logs = query.offset(offset).limit(limit).all()
        return logs

@app.get("/health")
def health():
    return {"status": "ok"}
