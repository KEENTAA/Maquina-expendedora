import enum
import os
import uuid
from datetime import datetime

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy import DateTime, Float, String, create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./orchestrator.db")
SIMUPAY_INTEGRATION_URL = os.getenv("SIMUPAY_INTEGRATION_URL", "http://simupay-service:8020")
VENDING_SERVICE_URL = os.getenv("VENDING_SERVICE_URL", "http://vending-service:8040")
IOT_WEBHOOK_ENABLED = os.getenv("IOT_WEBHOOK_ENABLED", "false").lower() == "true"
IOT_WEBHOOK_URL_TEMPLATE = os.getenv("IOT_WEBHOOK_URL_TEMPLATE", "")
IOT_WEBHOOK_TIMEOUT = float(os.getenv("IOT_WEBHOOK_TIMEOUT", "3.0"))

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass


class TransactionState(str, enum.Enum):
    PENDING = "PENDING"
    QR_GENERATED = "QR_GENERATED"
    PAID = "PAID"
    PAID_PENDING_DISPENSE = "PAID_PENDING_DISPENSE"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"
    REFUNDED = "REFUNDED"


class Transaction(Base):
    __tablename__ = "transactions"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str | None] = mapped_column(String, index=True, nullable=True)
    machine_id: Mapped[str] = mapped_column(String, index=True)
    product_id: Mapped[str] = mapped_column(String)
    amount: Mapped[float] = mapped_column(Float)
    state: Mapped[str] = mapped_column(String, default=TransactionState.PENDING.value)
    qr_image: Mapped[str | None] = mapped_column(String, nullable=True)
    payment_reference: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


Base.metadata.create_all(bind=engine)


def _ensure_schema_compatibility() -> None:
    if engine.dialect.name != "postgresql":
        return

    inspector = inspect(engine)
    if "transactions" not in inspector.get_table_names():
        return

    tx_columns = {col["name"] for col in inspector.get_columns("transactions")}
    if "user_id" not in tx_columns:
        return

    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE transactions ALTER COLUMN user_id DROP NOT NULL"))


_ensure_schema_compatibility()

app = FastAPI(title="Grog Transaction Orchestrator")


class CreateTransactionRequest(BaseModel):
    user_id: str
    machine_id: str
    product_id: str
    amount: float


class InitTransactionRequest(BaseModel):
    machine_id: str
    product_id: str = "PROD-1"
    amount: float | None = None


class DispenseResultRequest(BaseModel):
    success: bool

class SimulateRequest(BaseModel):
    outcome: str  # success | fail | refund


class TransactionResponse(BaseModel):
    id: str
    user_id: str | None = None
    machine_id: str
    product_id: str
    amount: float
    state: str
    qr_image: str | None = None
    payment_reference: str | None = None


def to_response(tx: Transaction) -> TransactionResponse:
    return TransactionResponse(
        id=tx.id,
        user_id=tx.user_id,
        machine_id=tx.machine_id,
        product_id=tx.product_id,
        amount=tx.amount,
        state=tx.state,
        qr_image=tx.qr_image,
        payment_reference=tx.payment_reference,
    )


async def notify_iot_webhook(machine_id: str, tx_id: str) -> None:
    if not IOT_WEBHOOK_ENABLED or not IOT_WEBHOOK_URL_TEMPLATE.strip():
        return

    url = (
        IOT_WEBHOOK_URL_TEMPLATE
        .replace("{machine_id}", machine_id)
        .replace("{tx_id}", tx_id)
    )
    async with httpx.AsyncClient() as client:
        await client.post(url, json={"tx_id": tx_id, "machine_id": machine_id}, timeout=IOT_WEBHOOK_TIMEOUT)


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "transaction-orchestrator"}

# NUEVO ENDPOINT PARA ARDUINO / QR ESTATICO
@app.get("/init/{machine_id}", response_model=TransactionResponse)
async def init_transaction(machine_id: str, product_id: str = "PROD-1", amount: float | None = None) -> TransactionResponse:
    # Obtener el precio del servicio de vending
    resolved_amount = amount if amount is not None else 10.0  # Default
    if amount is None:
        try:
            async with httpx.AsyncClient() as client:
                vending_res = await client.get(f"{VENDING_SERVICE_URL}/api/v1/machines/{machine_id}/inventory")
                if vending_res.status_code == 200:
                    items = vending_res.json().get("items", [])
                    for item in items:
                        if item["product_sku"] == product_id or item["product_name"] == product_id:
                            resolved_amount = item["price"]
                            break
        except Exception:
            pass

    tx = Transaction(
        id=str(uuid.uuid4()),
        user_id=None, # Aun no sabemos quien la escanea
        machine_id=machine_id,
        product_id=product_id,
        amount=resolved_amount,
        state=TransactionState.PENDING.value,
    )
    with SessionLocal() as db:
        db.add(tx)
        db.commit()
        db.refresh(tx)
        return to_response(tx)


@app.get("/api/v1/machines/{machine_id}/qr-payload")
def machine_qr_payload(machine_id: str, product_id: str = "PROD-1", amount: float | None = None) -> dict:
    qr_payload = f"/init/{machine_id}?product_id={product_id}"
    if amount is not None:
        qr_payload = f"{qr_payload}&amount={amount}"
    return {"machine_id": machine_id, "product_id": product_id, "amount": amount, "qr_payload": qr_payload}


@app.get("/api/v1/machines/{machine_id}/slots/{slot_id}")
async def get_slot_info_orchestrator(machine_id: str, slot_id: str) -> dict:
    async with httpx.AsyncClient() as client:
        try:
            vending_res = await client.get(f"{VENDING_SERVICE_URL}/api/v1/machines/{machine_id}/slots/{slot_id}")
            if vending_res.status_code != 200:
                raise HTTPException(status_code=vending_res.status_code, detail="Slot info not found")
            
            data = vending_res.json()
            # Generar la URL para el QR dinámico basado en este producto
            qr_payload = f"/init/{machine_id}?product_id={data['product_id']}&amount={data['price']}"
            
            return {
                "product_name": data["product_name"],
                "price": data["price"],
                "qr_payload": qr_payload,
                "stock": data["stock"]
            }
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/transactions/init", response_model=TransactionResponse)
async def init_transaction_api(req: InitTransactionRequest) -> TransactionResponse:
    return await init_transaction(req.machine_id, req.product_id, req.amount)


@app.post("/api/v1/transactions", response_model=TransactionResponse)
def create_transaction(req: CreateTransactionRequest) -> TransactionResponse:
    tx = Transaction(
        id=str(uuid.uuid4()),
        user_id=req.user_id,
        machine_id=req.machine_id,
        product_id=req.product_id,
        amount=req.amount,
        state=TransactionState.PENDING.value,
    )
    with SessionLocal() as db:
        db.add(tx)
        db.commit()
        db.refresh(tx)
        return to_response(tx)

# NUEVO ENDPOINT PARA QUE LA APP SE ASIGNE LA TRANSACCION
@app.patch("/api/v1/transactions/{tx_id}/assign", response_model=TransactionResponse)
def assign_transaction(tx_id: str, user_id: str) -> TransactionResponse:
    with SessionLocal() as db:
        tx = db.get(Transaction, tx_id)
        if not tx:
            raise HTTPException(status_code=404, detail="Transaction not found")
        tx.user_id = user_id
        tx.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(tx)
        return to_response(tx)

@app.get("/api/v1/transactions")
def list_transactions(user_id: str | None = None) -> dict:
    with SessionLocal() as db:
        query = db.query(Transaction).order_by(Transaction.created_at.desc())
        if user_id:
            query = query.filter(Transaction.user_id == user_id)
        rows = query.limit(200).all()
        return {"items": [to_response(r).model_dump() for r in rows]}


@app.post("/api/v1/transactions/{tx_id}/generate-qr", response_model=TransactionResponse)
async def generate_qr(tx_id: str) -> TransactionResponse:
    with SessionLocal() as db:
        tx = db.get(Transaction, tx_id)
        if not tx:
            raise HTTPException(status_code=404, detail="Transaction not found")
        if tx.state not in [TransactionState.PENDING.value, TransactionState.QR_GENERATED.value]:
            raise HTTPException(status_code=409, detail=f"Invalid state for QR: {tx.state}")

    async with httpx.AsyncClient() as client:
        simupay_res = await client.post(
            f"{SIMUPAY_INTEGRATION_URL}/api/v1/payments/authorize",
            json={"transaction_id": tx_id, "amount": tx.amount},
            timeout=15.0,
        )
        if simupay_res.status_code >= 400:
            raise HTTPException(status_code=502, detail=f"Authorize failed: {simupay_res.text}")
        authorize_data = simupay_res.json()

        qr_res = await client.post(
            f"{SIMUPAY_INTEGRATION_URL}/api/v1/payments/{authorize_data['provider_transaction_id']}/qr",
            timeout=15.0,
        )
        if qr_res.status_code >= 400:
            raise HTTPException(status_code=502, detail=f"QR generation failed: {qr_res.text}")
        qr_data = qr_res.json()

    with SessionLocal() as db:
        tx = db.get(Transaction, tx_id)
        tx.state = TransactionState.QR_GENERATED.value
        tx.payment_reference = authorize_data["provider_transaction_id"]
        tx.qr_image = qr_data.get("qr_image")
        tx.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(tx)
        return to_response(tx)


@app.post("/api/v1/transactions/{tx_id}/payment-confirmed", response_model=TransactionResponse)
async def payment_confirmed(tx_id: str) -> TransactionResponse:
    with SessionLocal() as db:
        tx = db.get(Transaction, tx_id)
        if not tx:
            raise HTTPException(status_code=404, detail="Transaction not found")
        if tx.state != TransactionState.QR_GENERATED.value:
            raise HTTPException(status_code=409, detail=f"Invalid transition from {tx.state}")
        tx.state = TransactionState.PAID_PENDING_DISPENSE.value
        tx.updated_at = datetime.utcnow()
        machine_id = tx.machine_id
        db.commit()
        db.refresh(tx)
        response = to_response(tx)

    try:
        await notify_iot_webhook(machine_id=machine_id, tx_id=tx_id)
    except Exception as exc:
        print(f"IoT webhook notify failed for tx={tx_id}: {exc}")

    return response


@app.post("/api/v1/transactions/{tx_id}/dispense-result", response_model=TransactionResponse)
async def dispense_result(tx_id: str, req: DispenseResultRequest) -> TransactionResponse:
    with SessionLocal() as db:
        tx = db.get(Transaction, tx_id)
        if not tx:
            raise HTTPException(status_code=404, detail="Transaction not found")
        if tx.state != TransactionState.PAID_PENDING_DISPENSE.value:
            raise HTTPException(status_code=409, detail=f"Invalid transition from {tx.state}")
        payment_ref = tx.payment_reference

    if not payment_ref:
        raise HTTPException(status_code=500, detail="Missing payment reference")

    async with httpx.AsyncClient() as client:
        if req.success:
            capture = await client.post(f"{SIMUPAY_INTEGRATION_URL}/api/v1/payments/{payment_ref}/capture", timeout=15.0)
            if capture.status_code >= 400:
                raise HTTPException(status_code=502, detail=f"Capture failed: {capture.text}")
            new_state = TransactionState.COMPLETED.value
        else:
            refund = await client.post(f"{SIMUPAY_INTEGRATION_URL}/api/v1/payments/{payment_ref}/refund", timeout=15.0)
            if refund.status_code >= 400:
                raise HTTPException(status_code=502, detail=f"Refund failed: {refund.text}")
            new_state = TransactionState.REFUNDED.value

    with SessionLocal() as db:
        tx = db.get(Transaction, tx_id)
        tx.state = new_state
        tx.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(tx)
        return to_response(tx)


@app.get("/api/v1/machines/{machine_id}/next-paid")
def next_paid_for_machine(machine_id: str) -> dict:
    with SessionLocal() as db:
        tx = (
            db.query(Transaction)
            .filter(
                Transaction.machine_id == machine_id,
                Transaction.state == TransactionState.PAID_PENDING_DISPENSE.value,
            )
            .order_by(Transaction.updated_at.asc())
            .first()
        )
        if not tx:
            return {"item": None}
        return {
            "item": {
                "tx_id": tx.id,
                "machine_id": tx.machine_id,
                "product_id": tx.product_id,
                "amount": tx.amount,
                "state": tx.state,
            }
        }


@app.post("/api/v1/transactions/{tx_id}/simulate", response_model=TransactionResponse)
async def simulate_result(tx_id: str, req: SimulateRequest) -> TransactionResponse:
    if req.outcome == "success":
        return await dispense_result(tx_id, DispenseResultRequest(success=True))
    if req.outcome in ["fail", "refund"]:
        return await dispense_result(tx_id, DispenseResultRequest(success=False))
    raise HTTPException(status_code=400, detail="Invalid outcome")


@app.get("/api/v1/transactions/{tx_id}", response_model=TransactionResponse)
def get_transaction(tx_id: str) -> TransactionResponse:
    with SessionLocal() as db:
        tx = db.get(Transaction, tx_id)
        if not tx:
            raise HTTPException(status_code=404, detail="Transaction not found")
        return to_response(tx)
