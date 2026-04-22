from fastapi import FastAPI, HTTPException, BackgroundTasks, Depends, status, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
import uuid
import httpx
import qrcode
import io
import base64
import os
from typing import Optional, List
from datetime import datetime
from urllib.parse import urlparse, parse_qs, quote_plus, unquote_plus
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from jose import JWTError, jwt
from fastapi.responses import StreamingResponse

# Importar modelos, esquemas y utils
from models.models import Base, User, Wallet, Transaction
from schemas import schemas
from auth_utils import verify_password, get_password_hash, create_access_token, SECRET_KEY, ALGORITHM, verify_google_token

# --- CONFIGURACIÓN DE BASE DE DATOS ---
SQLALCHEMY_DATABASE_URL = "sqlite:///./gateway.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Crear tablas
Base.metadata.create_all(bind=engine)

app = FastAPI(title="VERIFICACION-API-FINAL")
INTERNAL_API_KEY = os.getenv("INTERNAL_API_KEY", "grog-simupay-secret")
DEFAULT_MERCHANT_EMAIL = os.getenv("MERCHANT_EMAIL", "admin@experimentalcollege.edu.bo")

@app.get("/")
def read_root():
    print("API ROOT ACCESSED")
    return {"status": "online", "service": "SimuPay Gateway", "version": "1.0.1"}

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:5174",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:5174",
    ],
    allow_origin_regex=r"http://.*:(3000|5173|5174)$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# --- DEPENDENCIAS ---
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
        token_data = schemas.TokenData(email=email)
    except JWTError:
        raise credentials_exception
    user = db.query(User).filter(User.email == token_data.email).first()
    if user is None:
        raise credentials_exception
    return user

# --- NOTIFICACIÓN WEBHOOK ---
async def notify_main_app(transaction_id: str, db: Session):
    tx = db.query(Transaction).filter(Transaction.id == transaction_id).first()
    if not tx or not tx.webhook_url: return

    webhook_data = {
        "enrollment_id": tx.enrollment_id,
        "transaction_id": f"SIM-{tx.id}",
        "status": "completed",
        "amount": tx.amount,
        "timestamp": datetime.utcnow().isoformat()
    }

    async with httpx.AsyncClient() as client:
        try:
            print(f"Sending webhook to: {tx.webhook_url}")
            response = await client.post(tx.webhook_url, json=webhook_data, timeout=10.0)
            print(f"Webhook sent: {response.status_code}")
        except Exception as e:
            print(f"Webhook error: {e}")

@app.get("/test")
def test_endpoint():
    return {"status": "ok", "message": "SimuPay API is alive"}

# --- AUTH ENDPOINTS ---
@app.post("/token", response_model=schemas.Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=400, detail="Incorrect email or password")
    
    access_token = create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer", "email": user.email}

@app.post("/signup", response_model=schemas.User)
def signup(user: schemas.UserCreate, db: Session = Depends(get_db)):
    try:
        print(f"DEBUG SIGNUP: Iniciando registro para {user.email}")
        db_user = db.query(User).filter(User.email == user.email).first()
        if db_user:
            print(f"DEBUG SIGNUP: Email ya registrado: {user.email}")
            raise HTTPException(status_code=400, detail="Email already registered")
        
        print(f"DEBUG SIGNUP: Creando usuario...")
        new_user = User(
            email=user.email,
            hashed_password=get_password_hash(user.password),
            full_name=user.full_name
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        
        print(f"DEBUG SIGNUP: Creando billetera para user_id {new_user.id}...")
        new_wallet = Wallet(user_id=new_user.id, balance=0.0)
        db.add(new_wallet)
        db.commit()
        
        print(f"DEBUG SIGNUP: Registro exitoso para {user.email}")
        return new_user
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"DEBUG SIGNUP CRITICAL ERROR: {str(e)}")
        import traceback
        traceback.print_exc()
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")

@app.post("/auth/google", response_model=schemas.Token)
def google_auth(req: dict, db: Session = Depends(get_db)):
    try:
        token = req.get("token")
        print(f"DEBUG API: Recibida petición google_auth. Token presente: {bool(token)}")
        if not token:
            raise HTTPException(status_code=400, detail="Token is required")
        
        google_user = verify_google_token(token)
        if not google_user:
            print("DEBUG API ERROR: No se pudo validar el token con Google")
            raise HTTPException(status_code=400, detail="Invalid Google token or Client ID mismatch")
        
        print(f"DEBUG API: Usuario validado por Google: {google_user['email']}")
        
        # Buscar usuario por email
        user = db.query(User).filter(User.email == google_user["email"]).first()
        
        if not user:
            print(f"DEBUG API: Creando nuevo usuario social: {google_user['email']}")
            # Crear usuario si no existe (Social Signup)
            user = User(
                email=google_user["email"],
                full_name=google_user["full_name"],
                hashed_password="social-auth-no-password" 
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            
            # Crear billetera
            new_wallet = Wallet(user_id=user.id, balance=0.0)
            db.add(new_wallet)
            db.commit()
        
        print(f"DEBUG API: Generando token SimuPay para: {user.email}")
        access_token = create_access_token(data={"sub": user.email})
        return {"access_token": access_token, "token_type": "bearer", "email": user.email}
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"DEBUG API CRITICAL ERROR: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")

# --- WALLET ENDPOINTS ---
@app.get("/wallet", response_model=schemas.Wallet)
def get_wallet(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return current_user.wallet

@app.post("/wallet/recharge")
def recharge_wallet(req: schemas.WalletRechargeRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Simular recarga con tarjeta
    current_user.wallet.balance += req.amount
    
    # Registrar transacción de recarga
    recharge_tx = Transaction(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        amount=req.amount,
        status="completed",
        method="card",
        type="recharge"
    )
    db.add(recharge_tx)
    db.commit()
    return {"balance": current_user.wallet.balance}

def parse_qr_payment_data(qr_data: str) -> Optional[dict]:
    if not qr_data:
        return None
    normalized = qr_data.strip()
    prefix = "simupay://user/"
    if normalized.startswith(prefix):
        recipient_id = normalized[len(prefix):].strip()
        if not recipient_id:
            return None
        return {
            "recipient_id": recipient_id,
            "amount": None,
            "recipient_name": None,
            "note": None,
            "invalid_amount": False,
        }
    if normalized.startswith("simupay://pay"):
        parsed = urlparse(normalized)
        query = parse_qs(parsed.query)
        recipient_id = (query.get("to", [None])[0] or "").strip()
        if not recipient_id:
            return None

        amount_raw = (query.get("amount", [None])[0] or "").strip()
        parsed_amount: Optional[float] = None
        invalid_amount = False
        if amount_raw:
            try:
                parsed_amount = float(amount_raw)
            except ValueError:
                invalid_amount = True

        recipient_name = (query.get("name", [None])[0] or "").strip()
        note = (query.get("note", [None])[0] or "").strip()

        return {
            "recipient_id": recipient_id,
            "amount": parsed_amount,
            "recipient_name": unquote_plus(recipient_name) if recipient_name else None,
            "note": unquote_plus(note) if note else None,
            "invalid_amount": invalid_amount,
        }
    return None


def _pay_with_qr_for_user(*, payer: User, qr_data: str, db: Session, amount_override: Optional[float] = None) -> dict:
    qr_payload = parse_qr_payment_data(qr_data)
    if not qr_payload:
        raise HTTPException(status_code=400, detail="QR inválido para pago SimuPay")
    if qr_payload.get("invalid_amount"):
        raise HTTPException(status_code=400, detail="El monto codificado en el QR no es válido")

    amount_to_pay = amount_override if amount_override is not None else qr_payload.get("amount")
    if amount_to_pay is None or amount_to_pay <= 0:
        raise HTTPException(status_code=400, detail="El monto debe ser mayor a 0")

    recipient_id = qr_payload["recipient_id"]
    if recipient_id == payer.id:
        raise HTTPException(status_code=400, detail="No puedes pagarte a ti mismo")

    recipient = db.query(User).filter(User.id == recipient_id).first()
    if not recipient:
        raise HTTPException(status_code=404, detail="Cuenta destino no encontrada")

    if not payer.wallet or payer.wallet.balance < amount_to_pay:
        raise HTTPException(status_code=400, detail="Saldo insuficiente en billetera")

    if not recipient.wallet:
        recipient_wallet = Wallet(user_id=recipient.id, balance=0.0)
        db.add(recipient_wallet)
        db.commit()
        db.refresh(recipient)

    payer.wallet.balance -= amount_to_pay
    recipient.wallet.balance += amount_to_pay

    payer_tx = Transaction(
        id=str(uuid.uuid4()),
        user_id=payer.id,
        amount=amount_to_pay,
        status="completed",
        method="qr-account",
        type="payment",
        external_id=recipient.id
    )
    receiver_tx = Transaction(
        id=str(uuid.uuid4()),
        user_id=recipient.id,
        amount=amount_to_pay,
        status="completed",
        method="qr-account",
        type="income",
        external_id=payer.id
    )
    db.add(payer_tx)
    db.add(receiver_tx)
    db.commit()

    return {
        "status": "completed",
        "balance": payer.wallet.balance,
        "recipient_name": recipient.full_name,
        "amount": amount_to_pay,
        "note": qr_payload.get("note"),
    }


@app.get("/wallet/qr", response_model=dict)
def get_wallet_qr(current_user: User = Depends(get_current_user)):
    qr_content = f"simupay://user/{current_user.id}"
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(qr_content)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")

    buffered = io.BytesIO()
    img.save(buffered, format="PNG")
    qr_base64 = base64.b64encode(buffered.getvalue()).decode()

    return {
        "qr_data": qr_content,
        "qr_image": f"data:image/png;base64,{qr_base64}",
    }

@app.post("/wallet/qr-request", response_model=dict)
def create_wallet_payment_qr(req: schemas.QRPaymentRequestCreate, current_user: User = Depends(get_current_user)):
    if req.amount <= 0:
        raise HTTPException(status_code=400, detail="El monto debe ser mayor a 0")

    recipient_name = (current_user.full_name or current_user.email or "SimuPay").strip()
    qr_content = f"simupay://pay?to={current_user.id}&amount={req.amount:.2f}&name={quote_plus(recipient_name)}"
    if req.note and req.note.strip():
        qr_content += f"&note={quote_plus(req.note.strip())}"

    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(qr_content)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")

    buffered = io.BytesIO()
    img.save(buffered, format="PNG")
    qr_base64 = base64.b64encode(buffered.getvalue()).decode()

    return {
        "qr_data": qr_content,
        "qr_image": f"data:image/png;base64,{qr_base64}",
        "amount": round(req.amount, 2),
        "recipient_name": recipient_name,
        "note": req.note.strip() if req.note else None,
    }

@app.post("/wallet/pay-qr", response_model=dict)
def pay_with_account_qr(req: schemas.QRWalletPaymentRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return _pay_with_qr_for_user(
        payer=current_user,
        qr_data=req.qr_data,
        amount_override=req.amount,
        db=db,
    )

@app.get("/transactions", response_model=List[schemas.Transaction])
def get_user_transactions(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    Obtiene el historial de transacciones (pagos y recargas) del usuario autenticado.
    """
    transactions = db.query(Transaction).filter(
        Transaction.user_id == current_user.id
    ).order_by(Transaction.created_at.desc()).all()
    return transactions

# --- PAYMENT SESSION ENDPOINTS ---
@app.post("/sessions", response_model=dict)
async def create_session(data: dict, db: Session = Depends(get_db)):
    """
    Endpoint robusto que acepta dict para evitar errores 422 estrictos 
    y realiza la validación/conversión manualmente.
    """
    print(f"DEBUG: Recibida solicitud de sesión: {data}")
    
    try:
        amount = float(data.get("amount", 0))
        enrollment_id = str(data.get("enrollment_id", "1"))
        callback_url = str(data.get("callback_url", ""))
        webhook_url = str(data.get("webhook_url", ""))
        
        if amount <= 0:
            print("WARNING: Amount es 0 o menor")
            
        session_id = str(uuid.uuid4())
        new_tx = Transaction(
            id=session_id,
            amount=amount,
            enrollment_id=enrollment_id,
            callback_url=callback_url,
            webhook_url=webhook_url,
            status="pending",
            type="payment"
        )
        db.add(new_tx)
        db.commit()
        print(f"✅ Sesión {session_id} creada exitosamente para Enrollment {enrollment_id}")
        return {"session_id": session_id, "amount": amount}
    except Exception as e:
        print(f"❌ Error procesando sesión: {str(e)}")
        raise HTTPException(status_code=422, detail=f"Error en formato de datos: {str(e)}")

@app.get("/sessions/{session_id}")
def get_session(session_id: str, db: Session = Depends(get_db)):
    tx = db.query(Transaction).filter(Transaction.id == session_id).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Session not found")
    return tx

# --- CONFIGURACIÓN DE COMERCIO ---
async def credit_merchant_wallet(amount: float, db: Session, merchant_email: Optional[str] = None):
    """
    Busca la cuenta de la academia y le suma los fondos del pago recibido.
    """
    target_email = (merchant_email or DEFAULT_MERCHANT_EMAIL).strip().lower()
    merchant = db.query(User).filter(User.email == target_email).first()
    if not merchant:
        # Si no existe el usuario academia, lo creamos preventivamente
        print(f"DEBUG API: Creando cuenta de comercio para {target_email}")
        merchant = User(
            email=target_email,
            full_name=f"Merchant {target_email}",
            hashed_password=get_password_hash("admin123")
        )
        db.add(merchant)
        db.commit()
        db.refresh(merchant)
        
        merchant_wallet = Wallet(user_id=merchant.id, balance=0.0)
        db.add(merchant_wallet)
        db.commit()
    
    # Acreditar fondos
    merchant.wallet.balance += amount
    print(f"MERCHANT: Credited Bs. {amount} to academy wallet. New balance: {merchant.wallet.balance}")
    db.commit()

# --- PAYMENT PROCESS ENHANCED ---
@app.post("/sessions/{session_id}/process")
async def process_payment(session_id: str, req: schemas.PaymentProcessRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    tx = db.query(Transaction).filter(Transaction.id == session_id).first()
    if not tx: raise HTTPException(status_code=404, detail="Error de sesión")
    
    tx.method = req.method
    
    # Vincular usuario si se proporciona (para historial)
    if req.user_id:
        tx.user_id = req.user_id
    
    if req.method == 'card':
        # Simulación de aprobación de tarjeta
        if req.card_number and req.card_number.startswith('5'):
            tx.status = "failed"
            db.commit()
            return {"status": "failed", "message": "Tarjeta rechazada"}
        
        tx.status = "completed"
        # Al ser tarjeta, el dinero "entra" al sistema y se le da a la academia
        await credit_merchant_wallet(tx.amount, db)
    
    elif req.method == 'wallet':
        if not req.user_id: raise HTTPException(status_code=400, detail="User ID required for wallet payment")
        user = db.query(User).filter(User.id == req.user_id).first()
        if not user or user.wallet.balance < tx.amount:
            return {"status": "failed", "message": "Saldo insuficiente en billetera"}
        
        # Restar al alumno
        user.wallet.balance -= tx.amount
        tx.user_id = user.id
        tx.status = "completed"
        
        # Sumar a la academia
        await credit_merchant_wallet(tx.amount, db)
    
    elif req.method == 'qr':
        # El pago QR empieza como pendiente
        tx.status = "pending"
        tx.external_id = f"QR-{uuid.uuid4().hex[:8]}"
        
        # Generar QR data
        qr_content = f"simupay://pay?id={tx.id}&amount={tx.amount}&enrollment={tx.enrollment_id}"
        
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(qr_content)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        
        buffered = io.BytesIO()
        img.save(buffered, format="PNG")
        qr_base64 = base64.b64encode(buffered.getvalue()).decode()
        
        db.commit()
        return {
            "status": "pending", 
            "qr_data": qr_content, 
            "qr_image": f"data:image/png;base64,{qr_base64}",
            "external_id": tx.external_id
        }

    db.commit()
    
    if tx.status == "completed":
        background_tasks.add_task(notify_main_app, session_id, db)
    
    return {"status": tx.status, "redirect_url": tx.callback_url}

# --- ACTUALIZAR SIMULACIÓN QR PARA ACREDITAR TAMBIÉN ---
@app.post("/simulate-qr-payment")
async def simulate_qr_payment(req: schemas.QRConfirmation, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    tx = db.query(Transaction).filter(Transaction.id == req.transaction_id).first()
    if not tx: raise HTTPException(status_code=404, detail="Transaction not found")
    
    print(f"DEBUG: Simulando confirmación de QR para transacción {tx.id}. Estado actual: {tx.status}")
    
    if tx.status != "completed" and req.status == "completed":
        tx.status = req.status
        # Acreditar a la academia cuando se confirma el QR
        await credit_merchant_wallet(tx.amount, db)
        db.commit()
        print(f"FUNDS MOVED: Bs. {tx.amount} credited to academy wallet in SimuPay.")
        background_tasks.add_task(notify_main_app, tx.id, db)
    
    return {"status": "success", "message": f"Transaction {tx.id} updated to {req.status} and merchant credited"}

# --- INTERNAL INTEGRATION ENDPOINTS ---
@app.get("/api/v1/internal/wallets/{email}")
def get_internal_wallet(email: str, x_api_key: str = Header(default=None), db: Session = Depends(get_db)):
    if x_api_key != INTERNAL_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
    
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found in SimuPay")
    
    if not user.wallet:
        new_wallet = Wallet(user_id=user.id, balance=0.0)
        db.add(new_wallet)
        db.commit()
        db.refresh(user)
        
    return {"email": user.email, "balance": user.wallet.balance, "user_id": user.id}

@app.post("/api/v1/internal/wallets")
def create_internal_wallet(req: schemas.UserCreate, x_api_key: str = Header(default=None), db: Session = Depends(get_db)):
    if x_api_key != INTERNAL_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
    
    user = db.query(User).filter(User.email == req.email).first()
    if not user:
        # Si no existe, lo creamos (Social Signup implicito o registro desde Grog)
        user = User(
            email=req.email,
            full_name=req.full_name,
            hashed_password=get_password_hash(req.password)
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    
    if not user.wallet:
        new_wallet = Wallet(user_id=user.id, balance=0.0)
        db.add(new_wallet)
        db.commit()
        db.refresh(user)
        
    return {"email": user.email, "balance": user.wallet.balance, "user_id": user.id}


@app.get("/api/v1/internal/wallets/{email}/transactions")
def get_internal_wallet_transactions(email: str, x_api_key: str = Header(default=None), db: Session = Depends(get_db)):
    if x_api_key != INTERNAL_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")

    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found in SimuPay")

    transactions = db.query(Transaction).filter(
        Transaction.user_id == user.id
    ).order_by(Transaction.created_at.desc()).all()

    related_user_ids = {tx.external_id for tx in transactions if tx.external_id}
    related_users = {}
    if related_user_ids:
        users = db.query(User).filter(User.id.in_(related_user_ids)).all()
        related_users = {u.id: u.email for u in users}

    items = []
    for tx in transactions:
        from_email = user.email if tx.type in ["payment", "recharge"] else related_users.get(tx.external_id)
        to_email = related_users.get(tx.external_id) if tx.type == "payment" else user.email if tx.type == "income" else None
        items.append(
            {
                "id": tx.id,
                "from_email": from_email,
                "to_email": to_email,
                "amount": tx.amount,
                "type": tx.type,
                "created_at": tx.created_at.isoformat(),
            }
        )

    return {"items": items}


@app.post("/api/v1/internal/wallets/transfer")
def internal_transfer(req: schemas.TransferRequest, x_api_key: str = Header(default=None), db: Session = Depends(get_db)):
    if x_api_key != INTERNAL_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
    
    sender = db.query(User).filter(User.email == req.from_email).first()
    receiver = db.query(User).filter(User.email == req.to_email).first()
    
    if not sender or not receiver:
        raise HTTPException(status_code=404, detail="One or both wallets not found")
        
    if sender.wallet.balance < req.amount:
        raise HTTPException(status_code=400, detail="Insufficient balance")
        
    sender.wallet.balance -= req.amount
    receiver.wallet.balance += req.amount
    
    # Registrar transacciones en el historial de SimuPay
    db.add(Transaction(
        id=str(uuid.uuid4()), user_id=sender.id, amount=req.amount,
        status="completed", method="internal-transfer", type="payment",
        external_id=receiver.id
    ))
    db.add(Transaction(
        id=str(uuid.uuid4()), user_id=receiver.id, amount=req.amount,
        status="completed", method="internal-transfer", type="income",
        external_id=sender.id
    ))
    
    db.commit()
    return {"status": "ok", "from_balance": sender.wallet.balance}


@app.post("/api/v1/internal/payments/{session_id}/capture")
async def internal_capture_payment(session_id: str, data: dict, x_api_key: str = Header(default=None), db: Session = Depends(get_db)):
    if x_api_key != INTERNAL_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")

    tx = db.query(Transaction).filter(Transaction.id == session_id).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Session not found")

    merchant_email = data.get("merchant_email")
    if tx.status != "completed":
        tx.status = "completed"
        await credit_merchant_wallet(tx.amount, db, merchant_email=merchant_email)
    else:
        # Asegura que exista respuesta idempotente y evita doble crédito.
        db.commit()

    return {"status": "completed", "session_id": tx.id, "amount": tx.amount}


@app.post("/api/v1/internal/payments/{session_id}/wallet-pay")
def internal_wallet_pay(session_id: str, data: dict, x_api_key: str = Header(default=None), db: Session = Depends(get_db)):
    if x_api_key != INTERNAL_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")

    from_email = (data.get("from_email") or "").strip().lower()
    if not from_email:
        raise HTTPException(status_code=400, detail="from_email is required")

    tx = db.query(Transaction).filter(Transaction.id == session_id).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Session not found")

    # Idempotencia: si ya se pagó con wallet o ya se completó, no volver a debitar.
    if tx.status in {"paid_pending_capture", "completed"}:
        return {"status": tx.status, "session_id": tx.id, "amount": tx.amount}

    payer = db.query(User).filter(User.email == from_email).first()
    if not payer:
        raise HTTPException(status_code=404, detail="Payer not found in SimuPay")
    if not payer.wallet or payer.wallet.balance < tx.amount:
        raise HTTPException(status_code=400, detail="Insufficient balance")

    payer.wallet.balance -= tx.amount
    tx.user_id = payer.id
    tx.status = "paid_pending_capture"

    db.add(Transaction(
        id=str(uuid.uuid4()),
        user_id=payer.id,
        amount=tx.amount,
        status="completed",
        method="qr-session",
        type="payment",
        external_id=tx.id
    ))
    db.commit()

    return {"status": tx.status, "session_id": tx.id, "amount": tx.amount, "from_balance": payer.wallet.balance}


@app.post("/api/v1/internal/payments/{session_id}/refund")
def internal_refund_payment(session_id: str, x_api_key: str = Header(default=None), db: Session = Depends(get_db)):
    if x_api_key != INTERNAL_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")

    tx = db.query(Transaction).filter(Transaction.id == session_id).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Session not found")

    tx.status = "failed"
    db.commit()
    return {"status": "refunded", "session_id": tx.id}


@app.post("/api/v1/internal/wallets/pay-qr")
def internal_pay_qr(data: dict, x_api_key: str = Header(default=None), db: Session = Depends(get_db)):
    if x_api_key != INTERNAL_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")

    from_email = (data.get("from_email") or "").strip().lower()
    qr_data = (data.get("qr_data") or "").strip()
    amount = data.get("amount")

    if not from_email or not qr_data:
        raise HTTPException(status_code=400, detail="from_email and qr_data are required")

    payer = db.query(User).filter(User.email == from_email).first()
    if not payer:
        raise HTTPException(status_code=404, detail="Payer not found in SimuPay")

    amount_override = None
    if amount is not None:
        try:
            amount_override = float(amount)
        except (TypeError, ValueError):
            raise HTTPException(status_code=400, detail="amount must be a valid number")

    return _pay_with_qr_for_user(
        payer=payer,
        qr_data=qr_data,
        amount_override=amount_override,
        db=db,
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
