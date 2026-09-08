import enum
import os
import uuid
from datetime import datetime, timedelta

import httpx
from fastapi import FastAPI, HTTPException, Header, Request
from pydantic import BaseModel
from sqlalchemy import DateTime, Float, Integer, String, create_engine, func, inspect, text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./orchestrator.db")
SIMUPAY_INTEGRATION_URL = os.getenv("SIMUPAY_INTEGRATION_URL", "http://simupay-service:8020")
VENDING_SERVICE_URL = os.getenv("VENDING_SERVICE_URL", "http://vending-service:8040")
NOTIFICATION_SERVICE_URL = os.getenv("NOTIFICATION_SERVICE_URL", "http://notification-service:8070")
IOT_WEBHOOK_ENABLED = os.getenv("IOT_WEBHOOK_ENABLED", "false").lower() == "true"
IOT_WEBHOOK_URL_TEMPLATE = os.getenv("IOT_WEBHOOK_URL_TEMPLATE", "")
IOT_WEBHOOK_TIMEOUT = float(os.getenv("IOT_WEBHOOK_TIMEOUT", "3.0"))
AUDIT_SERVICE_URL = os.getenv("AUDIT_SERVICE_URL", "http://audit-service:8080")
VISION_SERVICE_URL = os.getenv("VISION_SERVICE_URL", "http://vision-service:8060") # Nuevo


async def audit_log(category: str, action: str, actor_id: str = None, machine_id: str = None, details: dict = None):
    try:
        async with httpx.AsyncClient() as client:
            payload = {
                "category": category,
                "action": action,
                "actor_id": actor_id,
                "machine_id": machine_id,
                "details": details or {}
            }
            await client.post(f"{AUDIT_SERVICE_URL}/api/v1/audit/logs", json=payload, timeout=2.0)
    except:
        pass

async def send_notification_async(user_email: str, title: str, summary: str, description: str, n_type: str = "info"):
    if not user_email:
        return
    try:
        async with httpx.AsyncClient() as client:
            await client.post(
                f"{NOTIFICATION_SERVICE_URL}/api/v1/notifications/send",
                json={
                    "user_email": user_email,
                    "title": title,
                    "summary": summary,
                    "description": description,
                    "type": n_type
                },
                timeout=2.0
            )
    except Exception:
        pass

async def start_vision_monitoring_async(tx_id: str):
    try:
        async with httpx.AsyncClient() as client:
            vision_payload = {"tx_id": tx_id, "duration_seconds": 15}
            await client.post(f"{VISION_SERVICE_URL}/api/v1/vision/start-monitoring", json=vision_payload, timeout=1.0)
    except Exception:
        pass

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

class Base(DeclarativeBase):
    pass

class TransactionState(str, enum.Enum):
    PENDING = "PENDING"
    QR_PRINTED = "QR_PRINTED" # Nuevo: Registrado por el hardware
    QR_GENERATED = "QR_GENERATED" # Escaneado por la App
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
    initial_distance: Mapped[float | None] = mapped_column(Float, nullable=True)
    final_distance: Mapped[float | None] = mapped_column(Float, nullable=True)
    error_log: Mapped[str | None] = mapped_column(String, nullable=True)
    payment_method: Mapped[str | None] = mapped_column(String, default="QR")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class MachineTelemetry(Base):
    __tablename__ = "machine_telemetry"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    machine_id: Mapped[str] = mapped_column(String, index=True)
    temperature: Mapped[float] = mapped_column(Float)
    timestamp: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

Base.metadata.create_all(bind=engine)

def _ensure_schema_compatibility() -> None:
    if engine.dialect.name != "postgresql": return
    inspector = inspect(engine)
    if "transactions" not in inspector.get_table_names(): return
    tx_columns = {col["name"] for col in inspector.get_columns("transactions")}
    with engine.begin() as conn:
        if "user_id" not in tx_columns: conn.execute(text("ALTER TABLE transactions ALTER COLUMN user_id DROP NOT NULL"))
        if "initial_distance" not in tx_columns: conn.execute(text("ALTER TABLE transactions ADD COLUMN initial_distance DOUBLE PRECISION"))
        if "final_distance" not in tx_columns: conn.execute(text("ALTER TABLE transactions ADD COLUMN final_distance DOUBLE PRECISION"))
        if "error_log" not in tx_columns: conn.execute(text("ALTER TABLE transactions ADD COLUMN error_log TEXT"))
        if "payment_method" not in tx_columns: conn.execute(text("ALTER TABLE transactions ADD COLUMN payment_method VARCHAR DEFAULT 'QR'"))

_ensure_schema_compatibility()
app = FastAPI(title="Grog Transaction Orchestrator")

class InitTransactionRequest(BaseModel):
    machine_id: str
    product_id: str
    amount: float | None = None
    payment_method: str | None = "QR"

class TelemetryRequest(BaseModel):
    temperature: float
    ip: str | None = None

class DispenseResultRequest(BaseModel):
    success: bool
    initial_distance: float | None = None
    final_distance: float | None = None
    error_log: str | None = None

class TransactionResponse(BaseModel):
    id: str
    tx_id: str  # Duplicamos para compatibilidad con Arduino
    machine_id: str
    product_id: str
    amount: float
    state: str
    qr_image: str | None = None
    payment_reference: str | None = None
    error_log: str | None = None
    payment_method: str | None = "QR"

def to_response(tx: Transaction) -> TransactionResponse:
    return TransactionResponse(
        id=tx.id,
        tx_id=tx.id, # Arduino busca "tx_id"
        machine_id=tx.machine_id,
        product_id=tx.product_id,
        amount=tx.amount,
        state=tx.state,
        qr_image=tx.qr_image,
        payment_reference=tx.payment_reference,
        error_log=tx.error_log,
        payment_method=tx.payment_method or "QR"
    )

@app.get("/init/{machine_id}", response_model=TransactionResponse)
async def init_transaction(machine_id: str, product_id: str = "PROD-1", amount: float | None = None, payment_method: str = "QR") -> TransactionResponse:
    with SessionLocal() as db:
        # IMPORTANTE: Si ya existe una transacción QR_PRINTED para esta máquina y producto, la reutilizamos para no llenar la DB de basura
        existing = db.query(Transaction).filter(
            Transaction.machine_id == machine_id,
            Transaction.product_id == product_id,
            Transaction.state == TransactionState.QR_PRINTED.value
        ).first()
        
        if existing:
            existing.amount = amount if amount else existing.amount
            existing.payment_method = payment_method or existing.payment_method or "QR"
            existing.updated_at = datetime.utcnow()
            db.commit(); db.refresh(existing)
            return to_response(existing)

    resolved_amount = amount if amount else 10.0
    tx = Transaction(
        id=str(uuid.uuid4()),
        machine_id=machine_id,
        product_id=product_id,
        amount=resolved_amount,
        state=TransactionState.QR_PRINTED.value,
        payment_method=payment_method or "QR"
    )
    with SessionLocal() as db:
        db.add(tx); db.commit(); db.refresh(tx)
        return to_response(tx)

@app.post("/api/v1/transactions/init", response_model=TransactionResponse)
async def init_transaction_api(req: InitTransactionRequest) -> TransactionResponse:
    return await init_transaction(req.machine_id, req.product_id, req.amount, payment_method=req.payment_method or "QR")

@app.get("/api/v1/transactions/{tx_id}", response_model=TransactionResponse)
async def get_transaction(tx_id: str) -> TransactionResponse:
    with SessionLocal() as db:
        tx = db.get(Transaction, tx_id)
        if not tx: raise HTTPException(status_code=404, detail="Transaction not found")
        return to_response(tx)

@app.post("/api/v1/transactions/{tx_id}/generate-qr", response_model=TransactionResponse)
async def generate_qr(tx_id: str) -> TransactionResponse:
    with SessionLocal() as db:
        tx = db.get(Transaction, tx_id)
        if not tx: raise HTTPException(status_code=404, detail="Not found")
        
        # 1. Autorizar en SimuPay
        async with httpx.AsyncClient() as client:
            try:
                auth_res = await client.post(
                    f"{SIMUPAY_INTEGRATION_URL}/api/v1/payments/authorize",
                    json={"transaction_id": tx.id, "amount": tx.amount},
                    timeout=10.0
                )
                if auth_res.status_code >= 400:
                    raise HTTPException(status_code=502, detail=f"SimuPay Authorize failed: {auth_res.text}")
                auth_data = auth_res.json()
                provider_tx_id = auth_data["provider_transaction_id"]
                
                # 2. Generar QR en SimuPay
                qr_res = await client.post(
                    f"{SIMUPAY_INTEGRATION_URL}/api/v1/payments/{provider_tx_id}/qr",
                    timeout=10.0
                )
                if qr_res.status_code >= 400:
                    raise HTTPException(status_code=502, detail=f"SimuPay QR failed: {qr_res.text}")
                qr_data = qr_res.json()
                
                tx.payment_reference = provider_tx_id
                tx.qr_image = qr_data.get("qr_image")
                tx.state = TransactionState.QR_GENERATED.value
                tx.updated_at = datetime.utcnow()
                db.commit(); db.refresh(tx)
                return to_response(tx)
            except Exception as e:
                if isinstance(e, HTTPException): raise e
                raise HTTPException(status_code=502, detail=f"SimuPay connection error: {str(e)}")

@app.post("/api/v1/transactions/{tx_id}/payment-confirmed", response_model=TransactionResponse)
async def payment_confirmed(tx_id: str) -> TransactionResponse:
    with SessionLocal() as db:
        tx = db.get(Transaction, tx_id)
        if not tx: raise HTTPException(status_code=404, detail="Not found")
        tx.state = TransactionState.PAID_PENDING_DISPENSE.value
        tx.updated_at = datetime.utcnow()
        machine_id = tx.machine_id

        db.commit(); db.refresh(tx)
        res = to_response(tx)
        
        # AUDIT LOG (Asíncrono en segundo plano)
        import asyncio
        asyncio.create_task(audit_log("APPLICATION", "PAYMENT_CONFIRMED", actor_id=tx.user_id, machine_id=tx.machine_id, details={"tx_id": tx.id, "amount": tx.amount}))

    # Vision Service en segundo plano (no bloquea la compra si no está corriendo)
    asyncio.create_task(start_vision_monitoring_async(tx_id))

    # Notificar al cliente sobre el pago confirmado en segundo plano
    if tx.user_id:
        asyncio.create_task(
            send_notification_async(
                user_email=tx.user_id,
                title="¡Pago Confirmado!",
                summary=f"Tu pago de Bs. {tx.amount} ha sido recibido.",
                description=f"Estamos preparando tu producto {tx.product_id} en la máquina {tx.machine_id}.",
                n_type="success"
            )
        )

    if IOT_WEBHOOK_ENABLED:
        try:
            url = IOT_WEBHOOK_URL_TEMPLATE.rstrip("/") + "/payment-confirmed"
            async with httpx.AsyncClient() as client: 
                await client.post(url, data={"tx_id": tx_id}, timeout=2.0)
        except: pass
    return res

@app.post("/api/v1/transactions/{tx_id}/refund", response_model=TransactionResponse)
async def refund_api(tx_id: str, req: DispenseResultRequest | None = None) -> TransactionResponse:
    return await dispense_result(tx_id, req if req else DispenseResultRequest(success=False))

@app.post("/api/v1/transactions/{tx_id}/dispense-result", response_model=TransactionResponse)
async def dispense_result(tx_id: str, req: DispenseResultRequest) -> TransactionResponse:
    with SessionLocal() as db:
        tx = db.get(Transaction, tx_id); 
        if not tx: raise HTTPException(status_code=404, detail="Not found")
        tx.initial_distance = req.initial_distance
        tx.final_distance = req.final_distance
        tx.error_log = req.error_log
        
        # Si ya está finalizada, no hacemos nada
        if tx.state in [TransactionState.COMPLETED.value, TransactionState.REFUNDED.value, TransactionState.FAILED.value]:
            db.commit(); return to_response(tx)

        # Si el sensor dice que falló, intentamos reembolsar SIEMPRE (por si acaso ya se pagó pero el webhook no llegó)
        # O si está en estado PAID_PENDING_DISPENSE
        should_refund = not req.success
        should_capture = req.success and tx.state == TransactionState.PAID_PENDING_DISPENSE.value
        
        # Realizar captura o reembolso real en SimuPay
        async with httpx.AsyncClient() as client:
            try:
                if should_capture:
                    # Capturar el pago si el despacho fue exitoso
                    await client.post(f"{SIMUPAY_INTEGRATION_URL}/api/v1/payments/{tx.payment_reference}/capture", timeout=10.0)
                    tx.state = TransactionState.COMPLETED.value
                    

                    # Reducir el stock del slot
                    try:
                        slot_to_decrement = tx.product_id
                        await client.patch(f"{VENDING_SERVICE_URL}/api/v1/machines/{tx.machine_id}/inventory/{slot_to_decrement}/decrement", timeout=5.0)
                        print(f"Decremented stock for {tx.machine_id} slot {slot_to_decrement}")
                    except Exception as e:
                        print(f"Failed to decrement stock: {e}")
                        
                    # AUDIT LOG
                    import asyncio
                    asyncio.create_task(audit_log("APPLICATION", "DISPENSE_SUCCESS", actor_id=tx.user_id, machine_id=tx.machine_id, details={"tx_id": tx.id, "slot": tx.product_id}))


                        
                    # Notificar al cliente sobre el exito en segundo plano
                    if tx.user_id:
                        asyncio.create_task(
                            send_notification_async(
                                user_email=tx.user_id,
                                title="¡Producto Entregado!",
                                summary="Tu compra se completó con éxito.",
                                description=f"Disfruta tu {tx.product_id}. Gracias por usar Grog.",
                                n_type="success"
                            )
                        )
                elif should_refund:

                    # Reembolsar si el despacho falló
                    print(f"DISPENSE FAILURE: Requesting refund for tx {tx.id}")
                    await client.post(f"{SIMUPAY_INTEGRATION_URL}/api/v1/payments/{tx.payment_reference}/refund", timeout=10.0)
                    tx.state = TransactionState.REFUNDED.value
                    
                    # AUDIT LOG
                    import asyncio
                    asyncio.create_task(audit_log("APPLICATION", "DISPENSE_FAILED", actor_id=tx.user_id, machine_id=tx.machine_id, details={"tx_id": tx.id, "error": tx.error_log}))

                    # Notificar al cliente sobre el reembolso en segundo plano
                    if tx.user_id:
                        asyncio.create_task(
                            send_notification_async(
                                user_email=tx.user_id,
                                title="Producto no entregado",
                                summary="Hubo un problema y se ha procesado tu reembolso.",
                                description=f"No pudimos entregar tu producto {tx.product_id}. El monto de Bs. {tx.amount} ha sido devuelto a tu billetera.",
                                n_type="warning"
                            )
                        )
                else:
                    # Si success=true pero no estaba PAID, quizás es un despacho gratuito o error de flujo
                    # Solo guardamos los logs de distancia
                    pass
            except Exception as e:
                # Si falla la llamada externa, marcamos como FAILED para revisión manual
                print(f"GATEWAY ERROR during dispense_result: {e}")
                tx.error_log = f"Gateway Error: {str(e)}"
                tx.state = TransactionState.FAILED.value

        db.commit(); db.refresh(tx)
        return to_response(tx)

@app.get("/api/v1/machines/{machine_id}/slots/{slot_id}")
async def get_slot_info(machine_id: str, slot_id: str):
    async with httpx.AsyncClient() as client:
        try:
            res = await client.get(f"{VENDING_SERVICE_URL}/api/v1/machines/{machine_id}/slots/{slot_id}", timeout=5.0)
            if res.status_code != 200:
                raise HTTPException(status_code=res.status_code, detail=res.text)
            data = res.json()
            # Añadimos el qr_payload para que el Arduino sepa qué URL poner en el QR
            data["qr_payload"] = f"/init/{machine_id}?product_id={data['product_id']}&amount={data['price']}"
            return data
        except Exception as e:
            if isinstance(e, HTTPException): raise e
            raise HTTPException(status_code=502, detail=f"Vending service error: {str(e)}")

@app.get("/api/v1/machines/{machine_id}/next-paid")
def next_paid(machine_id: str) -> dict:
    with SessionLocal() as db:
        tx = db.query(Transaction).filter(Transaction.machine_id == machine_id, Transaction.state == TransactionState.PAID_PENDING_DISPENSE.value).first()
        return {"item": {"tx_id": tx.id, "product_id": tx.product_id} if tx else None}

@app.get("/api/v1/transactions")
def list_tx() -> dict:
    with SessionLocal() as db:
        rows = db.query(Transaction).order_by(Transaction.created_at.desc()).limit(50).all()
        return {"items": [to_response(r).model_dump() for r in rows]}

@app.get("/api/v1/admin/stats/top-sellers")
async def get_top_sellers(machine_id: str | None = None):
    with SessionLocal() as db:
        query = db.query(
            Transaction.product_id, 
            func.count(Transaction.id).label("count"),
            func.coalesce(func.sum(Transaction.amount), 0.0).label("total_amount")
        ).filter(Transaction.state == TransactionState.COMPLETED.value)
        
        if machine_id and machine_id != "all":
            query = query.filter(Transaction.machine_id == machine_id)
            
        rows = query.group_by(Transaction.product_id).order_by(text("count DESC")).all()
        
        return {
            "machine_id": machine_id or "all",
            "items": [{"slot": r[0], "count": r[1], "total_amount": float(r[2])} for r in rows]
        }

@app.get("/api/v1/admin/stats/failed-slots")
async def get_failed_slots(machine_id: str | None = None):
    with SessionLocal() as db:
        query = db.query(
            Transaction.product_id, 
            func.count(Transaction.id).label("count")
        ).filter(Transaction.state.in_([TransactionState.FAILED.value, TransactionState.REFUNDED.value]))
        
        if machine_id and machine_id != "all":
            query = query.filter(Transaction.machine_id == machine_id)
            
        rows = query.group_by(Transaction.product_id).order_by(text("count DESC")).all()
        
        return {
            "machine_id": machine_id or "all",
            "items": [{"slot": r[0], "count": r[1]} for r in rows]
        }

def cleanup_old_transactions():
    with SessionLocal() as db:
        expiration_time = datetime.utcnow() - timedelta(hours=1)
        # Marcar como FAILED las transacciones antiguas en QR_PRINTED o QR_GENERATED
        db.query(Transaction).filter(
            Transaction.state.in_([TransactionState.QR_PRINTED.value, TransactionState.QR_GENERATED.value]),
            Transaction.created_at < expiration_time
        ).update({Transaction.state: TransactionState.FAILED.value, Transaction.error_log: "Expired cleanup"}, synchronize_session=False)
        db.commit()

# Almacenamiento en memoria para comandos de máquinas
command_queues = {}

@app.post("/api/v1/admin/commands/{machine_id}/toggle-lights")
async def toggle_lights(machine_id: str):
    if machine_id not in command_queues:
        command_queues[machine_id] = []
    command_queues[machine_id].append("toggle_lights")
    print(f"DEBUG: Enqueued toggle_lights for {machine_id}")
    return {"status": "queued", "command": "toggle_lights", "machine_id": machine_id}

@app.post("/api/v1/admin/commands/{machine_id}/lights-on")
async def lights_on(machine_id: str):
    if machine_id not in command_queues:
        command_queues[machine_id] = []
    command_queues[machine_id].append("lights_on")
    print(f"DEBUG: Enqueued lights_on for {machine_id}")
    return {"status": "queued", "command": "lights_on", "machine_id": machine_id}

@app.post("/api/v1/admin/commands/{machine_id}/lights-off")
async def lights_off(machine_id: str):
    if machine_id not in command_queues:
        command_queues[machine_id] = []
    command_queues[machine_id].append("lights_off")
    print(f"DEBUG: Enqueued lights_off for {machine_id}")
    return {"status": "queued", "command": "lights_off", "machine_id": machine_id}

@app.post("/api/v1/admin/commands/{machine_id}/refresh-config")
async def refresh_config(machine_id: str):
    if machine_id not in command_queues:
        command_queues[machine_id] = []
    # Usamos un string largo para que el ESP32 lo detecte como comando de actualización
    command_queues[machine_id].append("refresh_inventory_config")
    print(f"DEBUG: Enqueued refresh_config for {machine_id}")
    return {"status": "queued", "command": "refresh_config", "machine_id": machine_id}

@app.get("/api/v1/admin/commands/poll/{machine_id}")
async def poll_commands(machine_id: str):
    commands = command_queues.get(machine_id, [])
    command_queues[machine_id] = [] # Limpiar cola después de entregar
    return {"commands": commands}

@app.get("/api/v1/admin/stats/summary")
async def admin_stats_summary(machine_id: str | None = None):
    cleanup_old_transactions()
    with SessionLocal() as db:
        query_completed = db.query(
            func.coalesce(func.sum(Transaction.amount), 0.0),
            func.count(Transaction.id)
        ).filter(Transaction.state == TransactionState.COMPLETED.value)
        
        query_status = db.query(
            Transaction.state,
            func.count(Transaction.id)
        )
        
        query_method = db.query(
            Transaction.payment_method,
            Transaction.state,
            func.count(Transaction.id)
        )
        
        if machine_id and machine_id != "all":
            query_completed = query_completed.filter(Transaction.machine_id == machine_id)
            query_status = query_status.filter(Transaction.machine_id == machine_id)
            query_method = query_method.filter(Transaction.machine_id == machine_id)
            
        total_sales, total_units = query_completed.first() or (0.0, 0)
        
        counts = query_status.group_by(Transaction.state).all()
        status_breakdown = {state: count for state, count in counts}
        
        method_counts = query_method.group_by(Transaction.payment_method, Transaction.state).all()
        method_breakdown = {}
        for meth, st, cnt in method_counts:
            meth_key = meth if meth else "QR"
            if meth_key not in method_breakdown:
                method_breakdown[meth_key] = {}
            method_breakdown[meth_key][st] = cnt
        
        return {
            "total_sales": float(total_sales or 0.0),
            "total_units_sold": int(total_units or 0),
            "status_breakdown": status_breakdown,
            "method_breakdown": method_breakdown
        }


@app.get("/api/v1/admin/stats/temperature-history")
async def admin_temperature_history(machine_id: str = "MACHINE-001", interval_minutes: int = 10, hours: int = 1):
    with SessionLocal() as db:
        query = db.query(MachineTelemetry)
        if machine_id and machine_id != "all":
            query = query.filter(MachineTelemetry.machine_id == machine_id)
            
        if hours and hours > 0:
            since = datetime.utcnow() - timedelta(hours=hours)
            query = query.filter(MachineTelemetry.timestamp >= since)
            
        if engine.dialect.name == "postgresql":
            bucket = text(f"to_timestamp(floor(extract(epoch from timestamp) / ({interval_minutes} * 60)) * ({interval_minutes} * 60))")
        else:
            bucket = text(f"datetime((strftime('%s', timestamp) / ({interval_minutes} * 60)) * ({interval_minutes} * 60), 'unixepoch')")

        rows = query.with_entities(
            bucket,
            func.avg(MachineTelemetry.temperature).label("avg_temp")
        ).group_by(bucket).order_by(bucket).limit(300).all()
        
        items = [{"timestamp": str(r[0]), "temperature": round(float(r[1]), 2)} for r in rows if r[0] is not None and r[1] is not None]
        
        # Calcular pico máximo y mínimo
        min_temp = min([it["temperature"] for it in items]) if items else None
        max_temp = max([it["temperature"] for it in items]) if items else None
        
        return {
            "machine_id": machine_id,
            "interval": interval_minutes,
            "hours": hours,
            "min_temperature": min_temp,
            "max_temperature": max_temp,
            "items": items
        }

@app.get("/api/v1/admin/stats/distance-history")
async def admin_distance_history(machine_id: str = "MACHINE-001"):
    with SessionLocal() as db:
        # Obtenemos las últimas 50 transacciones que tienen datos de distancia
        rows = db.query(Transaction)\
            .filter(Transaction.machine_id == machine_id)\
            .filter(Transaction.initial_distance.isnot(None))\
            .order_by(Transaction.created_at.asc())\
            .limit(50).all()
        
        return {
            "machine_id": machine_id,
            "items": [
                {
                    "timestamp": r.created_at,
                    "m1": r.initial_distance,
                    "m2": r.final_distance,
                    "product": r.product_id
                } for r in rows
            ]
        }

# Almacenamiento en memoria para IPs de máquinas
machine_ips = {}

@app.post("/api/v1/machines/{machine_id}/telemetry")
async def record_telemetry(machine_id: str, req: TelemetryRequest):
    # Registrar IP enviada por el ESP32
    if req.ip:
        machine_ips[machine_id] = req.ip
    
    with SessionLocal() as db:
        new_entry = MachineTelemetry(machine_id=machine_id, temperature=req.temperature)
        db.add(new_entry)
        db.commit()
    return {"status": "ok", "machine_id": machine_id, "temperature": req.temperature, "ip_registered": machine_ips.get(machine_id)}

@app.get("/api/v1/machines/{machine_id}/telemetry")
async def get_telemetry(machine_id: str, limit: int = 20):
    with SessionLocal() as db:
        rows = db.query(MachineTelemetry).filter(MachineTelemetry.machine_id == machine_id).order_by(MachineTelemetry.timestamp.desc()).limit(limit).all()
        return {
            "machine_id": machine_id,
            "items": [{"temperature": r.temperature, "timestamp": r.timestamp} for r in rows]
        }

class HardwareLogRequest(BaseModel):
    level: str
    message: str
    source: str = "ESP32_MASTER"

@app.post("/api/v1/machines/{machine_id}/hardware-log")
async def receive_hardware_log(machine_id: str, req: HardwareLogRequest):
    import asyncio
    asyncio.create_task(audit_log("HARDWARE", req.level, actor_id=req.source, machine_id=machine_id, details={"message": req.message}))
    return {"status": "ok"}
