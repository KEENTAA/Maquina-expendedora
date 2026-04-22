import os
from datetime import datetime, timedelta
from uuid import uuid4

from fastapi import FastAPI
from pydantic import BaseModel
from sqlalchemy import DateTime, Float, String, Text, create_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./iot.db")
MQTT_BROKER_URL = os.getenv("MQTT_BROKER_URL", "mqtt://127.0.0.1:1883")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass


class TelemetryLog(Base):
    __tablename__ = "telemetry_logs"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    machine_id: Mapped[str] = mapped_column(String, index=True)
    temperature: Mapped[float] = mapped_column(Float)
    humidity: Mapped[float] = mapped_column(Float)
    motor_status: Mapped[str] = mapped_column(String)
    status: Mapped[str] = mapped_column(String)
    raw_payload: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


Base.metadata.create_all(bind=engine)
app = FastAPI(title="Grog IoT Bridge Service")


class TelemetryIn(BaseModel):
    machine_id: str
    temperature: float
    humidity: float
    motor_status: str
    status: str


def _seed() -> None:
    with SessionLocal() as db:
        if db.query(TelemetryLog).count() == 0:
            db.add_all(
                [
                    TelemetryLog(
                        id=str(uuid4()),
                        machine_id="MACHINE-001",
                        temperature=24.2,
                        humidity=39.0,
                        motor_status="OK",
                        status="online",
                        raw_payload='{"heartbeat":true}',
                        created_at=datetime.utcnow(),
                    ),
                    TelemetryLog(
                        id=str(uuid4()),
                        machine_id="MACHINE-002",
                        temperature=31.6,
                        humidity=58.0,
                        motor_status="WARN",
                        status="offline",
                        raw_payload='{"heartbeat":false}',
                        created_at=datetime.utcnow() - timedelta(minutes=15),
                    ),
                ]
            )
            db.commit()


_seed()


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "iot-bridge-service", "mqtt_broker": MQTT_BROKER_URL}


@app.get("/api/v1/iot/topics")
def topics() -> dict:
    return {
        "publish": [
            "grog/v1/machines/{machine_id}/commands/dispense",
            "grog/v1/machines/{machine_id}/commands/homing",
            "grog/v1/machines/{machine_id}/commands/restart",
        ],
        "subscribe": [
            "grog/v1/machines/{machine_id}/heartbeat",
            "grog/v1/machines/{machine_id}/telemetry",
            "grog/v1/machines/{machine_id}/events/dispense-result",
            "grog/v1/machines/{machine_id}/errors",
        ],
    }


@app.post("/api/v1/iot/telemetry")
def ingest_telemetry(req: TelemetryIn) -> dict:
    with SessionLocal() as db:
        db.add(
            TelemetryLog(
                id=str(uuid4()),
                machine_id=req.machine_id,
                temperature=req.temperature,
                humidity=req.humidity,
                motor_status=req.motor_status,
                status=req.status,
                raw_payload=req.model_dump_json(),
            )
        )
        db.commit()
    return {"status": "stored"}


@app.get("/api/v1/iot/machines")
def machine_statuses() -> dict:
    with SessionLocal() as db:
        rows = db.query(TelemetryLog).order_by(TelemetryLog.created_at.desc()).all()
        latest = {}
        for row in rows:
            if row.machine_id not in latest:
                latest[row.machine_id] = row
        return {
            "machines": [
                {
                    "machine_id": r.machine_id,
                    "status": r.status,
                    "last_seen": r.created_at.isoformat(),
                    "temperature": r.temperature,
                    "humidity": r.humidity,
                    "motor_status": r.motor_status,
                }
                for r in latest.values()
            ]
        }


@app.get("/api/v1/iot/telemetry/{machine_id}")
def telemetry(machine_id: str) -> dict:
    with SessionLocal() as db:
        rows = (
            db.query(TelemetryLog)
            .filter(TelemetryLog.machine_id == machine_id)
            .order_by(TelemetryLog.created_at.desc())
            .limit(100)
            .all()
        )
        return {
            "items": [
                {
                    "timestamp": r.created_at.isoformat(),
                    "temperature": r.temperature,
                    "humidity": r.humidity,
                    "status": r.status,
                    "motor_status": r.motor_status,
                }
                for r in rows
            ]
        }


@app.post("/api/v1/iot/commands/{machine_id}/{command}")
def command(machine_id: str, command: str) -> dict:
    return {"status": "queued", "machine_id": machine_id, "command": command, "mqtt_broker": MQTT_BROKER_URL}
