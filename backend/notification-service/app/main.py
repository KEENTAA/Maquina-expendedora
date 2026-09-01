import json
import asyncio
from typing import List, Dict
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from pydantic import BaseModel
from datetime import datetime
import uuid
from sqlalchemy import create_engine, Column, String, Boolean, text
from sqlalchemy.orm import declarative_base, sessionmaker

app = FastAPI(title="Grog Notification Service")

# --- Database Setup ---
DATABASE_URL = "postgresql+psycopg://grog:grog@grog-postgres:5432/grog"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class DBNotification(Base):
    __tablename__ = "notifications"
    id = Column(String, primary_key=True, index=True)
    user_email = Column(String, index=True)
    title = Column(String)
    summary = Column(String)
    description = Column(String)
    type = Column(String)
    is_read = Column(Boolean, default=False)
    created_at = Column(String)

# Crea la tabla si no existe
Base.metadata.create_all(bind=engine)

# --- Models ---
class Notification(BaseModel):
    id: str
    user_email: str
    title: str
    summary: str
    description: str
    type: str
    is_read: bool
    created_at: str

class NotificationCreate(BaseModel):
    user_email: str
    title: str
    summary: str
    description: str
    type: str = "info"

# --- WebSocket Manager ---
class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, user_email: str):
        await websocket.accept()
        if user_email not in self.active_connections:
            self.active_connections[user_email] = []
        self.active_connections[user_email].append(websocket)
        print(f"WS CONNECTED: {user_email}")

    def disconnect(self, websocket: WebSocket, user_email: str):
        if user_email in self.active_connections:
            self.active_connections[user_email].remove(websocket)
            if not self.active_connections[user_email]:
                del self.active_connections[user_email]
        print(f"WS DISCONNECTED: {user_email}")

    async def send_personal_message(self, message: dict, user_email: str):
        if user_email in self.active_connections:
            for connection in self.active_connections[user_email]:
                try:
                    await connection.send_json(message)
                except:
                    pass

manager = ConnectionManager()

# --- Endpoints ---

@app.get("/api/v1/notifications/{user_email}")
async def get_notifications(user_email: str):
    with SessionLocal() as db:
        notifs = db.query(DBNotification).filter(DBNotification.user_email == user_email).all()
        # Sort by date parsing manually or string, string ISO format sorts correctly lexicographically
        notifs_sorted = sorted(notifs, key=lambda x: x.created_at, reverse=True)
        return [
            {
                "id": n.id,
                "user_email": n.user_email,
                "title": n.title,
                "summary": n.summary,
                "description": n.description,
                "type": n.type,
                "is_read": n.is_read,
                "created_at": n.created_at
            }
            for n in notifs_sorted
        ]

@app.post("/api/v1/notifications/broadcast")
async def broadcast_notification(notif: NotificationCreate):
    with SessionLocal() as db:
        # Obtener todos los correos de la tabla de usuarios
        users = db.execute(text("SELECT email FROM users")).fetchall()
        emails = [row[0] for row in users]
        
        now_str = datetime.now().isoformat()
        db_notifs = []
        result_payloads = []
        
        for email in emails:
            new_id = str(uuid.uuid4())
            db_n = DBNotification(
                id=new_id,
                user_email=email,
                title=notif.title,
                summary=notif.summary,
                description=notif.description,
                type=notif.type,
                is_read=False,
                created_at=now_str
            )
            db.add(db_n)
            db_notifs.append(db_n)
            
            # Prepare payload for WS
            payload = {
                "id": new_id,
                "user_email": email,
                "title": notif.title,
                "summary": notif.summary,
                "description": notif.description,
                "type": notif.type,
                "is_read": False,
                "created_at": now_str
            }
            result_payloads.append((email, payload))
            
        db.commit()
        
    # Enviar websockets en background
    for email, payload in result_payloads:
        await manager.send_personal_message(payload, email)
        
    return {"status": "broadcasted", "count": len(emails)}

@app.post("/api/v1/notifications/send")
async def create_notification(notif: NotificationCreate):
    now_str = datetime.now().isoformat()
    new_id = str(uuid.uuid4())
    with SessionLocal() as db:
        db_n = DBNotification(
            id=new_id,
            user_email=notif.user_email,
            title=notif.title,
            summary=notif.summary,
            description=notif.description,
            type=notif.type,
            is_read=False,
            created_at=now_str
        )
        db.add(db_n)
        db.commit()
    
    payload = {
        "id": new_id,
        "user_email": notif.user_email,
        "title": notif.title,
        "summary": notif.summary,
        "description": notif.description,
        "type": notif.type,
        "is_read": False,
        "created_at": now_str
    }
    await manager.send_personal_message(payload, notif.user_email)
    return payload

@app.patch("/api/v1/notifications/{notification_id}/read")
async def mark_as_read(notification_id: str):
    with SessionLocal() as db:
        n = db.query(DBNotification).filter(DBNotification.id == notification_id).first()
        if not n:
            raise HTTPException(status_code=404, detail="Notification not found")
        n.is_read = True
        db.commit()
        return {"id": n.id, "is_read": True}

@app.websocket("/ws/notifications/{user_email}")
async def websocket_endpoint(websocket: WebSocket, user_email: str):
    await manager.connect(websocket, user_email)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_email)

