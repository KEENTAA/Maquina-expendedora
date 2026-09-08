import os
import json
import httpx
import random
import time
from datetime import datetime
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy import DateTime, Float, Integer, String, Text, create_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./vending.db")
NOTIFICATION_SERVICE_URL = os.getenv("NOTIFICATION_SERVICE_URL", "http://notification-service:8070")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass


class Machine(Base):
    __tablename__ = "machines"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    owner_email: Mapped[str] = mapped_column(String, index=True)
    name: Mapped[str] = mapped_column(String)
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    status: Mapped[str] = mapped_column(String, default="online")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class Product(Base):
    __tablename__ = "products"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    sku: Mapped[str] = mapped_column(String, unique=True)
    name: Mapped[str] = mapped_column(String)
    price: Mapped[float] = mapped_column(Float)


class Inventory(Base):
    __tablename__ = "inventory"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    machine_id: Mapped[str] = mapped_column(String, index=True)
    product_id: Mapped[str] = mapped_column(String, index=True)
    slot: Mapped[str] = mapped_column(String)
    stock: Mapped[int] = mapped_column(Integer)
    capacity: Mapped[int] = mapped_column(Integer)
    price: Mapped[float] = mapped_column(Float, nullable=True)
    is_enabled: Mapped[bool] = mapped_column(Integer, default=1) # 1=True, 0=False para SQLite
    slot_type: Mapped[str] = mapped_column(String, default="soda") # "soda" o "snack"
    image_base64: Mapped[str | None] = mapped_column(Text, nullable=True)
    display_order: Mapped[int] = mapped_column(Integer, default=0)

class GlobalSetting(Base):
    __tablename__ = "global_settings"
    key: Mapped[str] = mapped_column(String, primary_key=True)
    value: Mapped[str] = mapped_column(Text) # Cambiado a Text para base64

Base.metadata.create_all(bind=engine)
app = FastAPI(title="Grog Vending Service")



from sqlalchemy import inspect, text

def _ensure_schema_compatibility() -> None:
    inspector = inspect(engine)
    if "inventory" not in inspector.get_table_names():
        return
    cols = {col["name"] for col in inspector.get_columns("inventory")}
    with engine.begin() as conn:
        if "image_base64" not in cols:
            conn.execute(text("ALTER TABLE inventory ADD COLUMN image_base64 TEXT"))
        if "display_order" not in cols:
            conn.execute(text("ALTER TABLE inventory ADD COLUMN display_order INTEGER DEFAULT 0"))

_ensure_schema_compatibility()

def _seed() -> None:
    with SessionLocal() as db:
        if db.query(Machine).count() == 0:
            db.add_all(
                [
                    Machine(id="MACHINE-001", owner_email="admin@grog.com", name="Campus Norte", latitude=-17.8, longitude=-63.2, status="online"),
                    Machine(id="MACHINE-002", owner_email="admin@grog.com", name="Campus Sur", latitude=-17.81, longitude=-63.22, status="offline"),
                ]
            )
        if db.query(Product).count() == 0:
            db.add_all([
                Product(id="PROD-1", sku="SODA-001", name="Soda", price=8.5), 
                Product(id="PROD-2", sku="CHIPS-002", name="Chips", price=6.0),
                Product(id="PROD-NONE", sku="NONE", name="Vacío", price=0.0)
            ])
        
        if db.query(Inventory).count() == 0:
            # Asegurar 16 slots para MACHINE-001
            slots = []
            for row in ['A', 'B', 'C', 'D']:
                for col in range(1, 5):
                    slot_name = f"{row}{col}"
                    prod_id = "PROD-1" if row in ['A', 'B'] else "PROD-2"
                    stype = "soda" if row in ['A', 'B'] else "snack"
                    slots.append(Inventory(
                        id=str(uuid4()), 
                        machine_id="MACHINE-001", 
                        product_id=prod_id, 
                        slot=slot_name, 
                        stock=10, 
                        capacity=20, 
                        price=8.5 if stype=="soda" else 6.0,
                        is_enabled=True,
                        slot_type=stype
                    ))
            db.add_all(slots)
            
        if db.query(GlobalSetting).filter(GlobalSetting.key == "banner_url").count() == 0:
            db.add(GlobalSetting(key="banner_url", value="https://via.placeholder.com/400x100?text=Publicidad+Grog"))
            
        db.commit()


_seed()



class ImageRequest(BaseModel):
    image_base64: str

@app.patch("/api/v1/machines/{machine_id}/inventory/{slot_or_id}/image")
def update_inventory_image(machine_id: str, slot_or_id: str, req: ImageRequest) -> dict:
    with SessionLocal() as db:
        item = db.query(Inventory).filter(
            (Inventory.machine_id == machine_id) & 
            ((Inventory.id == slot_or_id) | (Inventory.slot == slot_or_id))
        ).first()
        if not item:
            raise HTTPException(status_code=404, detail="Inventory item not found")
        item.image_base64 = req.image_base64
        db.commit()
        return {"status": "updated", "slot": item.slot}

class InventoryUpdateRequest(BaseModel):
    stock: int
    capacity: int

class SlotStatusRequest(BaseModel):
    is_enabled: bool
    slot_type: str | None = None
    product_name: str | None = None
    new_slot: str | None = None

class CreateSlotRequest(BaseModel):
    slot: str
    product_name: str
    price: float = 5.0
    stock: int = 10
    capacity: int = 20
    slot_type: str = "soda"

class ReorderSlotsRequest(BaseModel):
    ordered_slots: list[str]

class BannerRequest(BaseModel):
    title: str = ""
    concept: str = ""
    image_base64: str = ""
    url: str | None = None


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "vending-service"}

@app.get("/api/v1/settings/banner")
def get_banner() -> dict:
    with SessionLocal() as db:
        setting = db.query(GlobalSetting).filter(GlobalSetting.key == "banner_url").first()
        if not setting or not setting.value:
            return {"url": "", "title": "", "concept": "", "image_base64": ""}
        
        # Intentar parsear como JSON si es un anuncio enriquecido
        try:
            data = json.loads(setting.value)
            if isinstance(data, dict):
                return {
                    "url": data.get("url", ""),
                    "title": data.get("title", ""),
                    "concept": data.get("concept", ""),
                    "image_base64": data.get("image_base64", ""),
                }
        except Exception:
            pass

        # Si es un string simple / URL legacy
        return {
            "url": setting.value,
            "title": "",
            "concept": "",
            "image_base64": setting.value if setting.value.startswith("data:image") or len(setting.value) > 200 else ""
        }

@app.post("/api/v1/admin/settings/banner")
def update_banner(req: BannerRequest) -> dict:
    with SessionLocal() as db:
        payload = {
            "title": req.title or "",
            "concept": req.concept or "",
            "image_base64": req.image_base64 or "",
            "url": req.url or "",
        }
        serialized = json.dumps(payload)

        setting = db.query(GlobalSetting).filter(GlobalSetting.key == "banner_url").first()
        if not setting:
            setting = GlobalSetting(key="banner_url", value=serialized)
            db.add(setting)
        else:
            setting.value = serialized
        db.commit()
        return {
            "status": "updated",
            "title": req.title,
            "concept": req.concept,
            "image_base64": req.image_base64,
            "url": req.url
        }

@app.get("/api/v1/machines")
def list_machines(owner_email: str | None = None) -> dict:
    with SessionLocal() as db:
        query = db.query(Machine)
        if owner_email:
            query = query.filter(Machine.owner_email == owner_email)
        machines = query.all()
        return {"machines": [{"id": m.id, "owner_email": m.owner_email, "name": m.name, "status": m.status, "lat": m.latitude, "lng": m.longitude} for m in machines]}


@app.get("/api/v1/machines/{machine_id}/inventory")
def machine_inventory(machine_id: str, include_images: bool = True, only_enabled: bool = False) -> dict:
    with SessionLocal() as db:
        query = (
            db.query(Inventory, Product)
            .join(Product, Inventory.product_id == Product.id)
            .filter(Inventory.machine_id == machine_id)
        )
        if only_enabled:
            query = query.filter(Inventory.is_enabled == 1)
        rows = query.order_by(Inventory.display_order.asc(), Inventory.slot.asc()).all()
        return {
            "items": [
                {
                    "inventory_id": inv.id,
                    "slot": inv.slot,
                    "stock": inv.stock,
                    "capacity": inv.capacity,
                    "product_sku": prod.sku,
                    "product_name": prod.name,
                    "price": inv.price if inv.price is not None else prod.price,
                    "is_enabled": bool(inv.is_enabled),
                    "slot_type": inv.slot_type,
                    "display_order": inv.display_order if hasattr(inv, 'display_order') and inv.display_order is not None else 0,
                    "image_base64": inv.image_base64 if include_images else None
                }
                for inv, prod in rows
            ]
        }


@app.get("/api/v1/machines/{machine_id}/slots/{slot_id}")
def get_slot_info(machine_id: str, slot_id: str, include_images: bool = False) -> dict:
    with SessionLocal() as db:
        row = (
            db.query(Inventory, Product)
            .join(Product, Inventory.product_id == Product.id)
            .filter(Inventory.machine_id == machine_id, Inventory.slot == slot_id)
            .first()
        )
        if not row:
            raise HTTPException(status_code=404, detail="Slot not found")
        
        inv, prod = row
        return {
            "slot": inv.slot,
            "product_id": prod.id,
            "product_name": prod.name,
            "price": inv.price if inv.price is not None else prod.price,
            "stock": inv.stock,
            "is_enabled": bool(inv.is_enabled),
            "slot_type": inv.slot_type,
            "image_base64": inv.image_base64 if include_images else None
        }


@app.patch("/api/v1/machines/{machine_id}/inventory/{slot_or_id}/status")
def update_slot_status(machine_id: str, slot_or_id: str, req: SlotStatusRequest) -> dict:
    with SessionLocal() as db:
        item = db.query(Inventory).filter(
            (Inventory.machine_id == machine_id) & 
            ((Inventory.id == slot_or_id) | (Inventory.slot == slot_or_id))
        ).first()
        
        if not item:
            raise HTTPException(status_code=404, detail="Inventory item not found")
            
        item.is_enabled = req.is_enabled
        if req.slot_type:
            item.slot_type = req.slot_type

        # Check if slot code changed (e.g. A1 -> A5)
        if req.new_slot is not None and req.new_slot.strip():
            target_slot = req.new_slot.strip().upper()
            if target_slot != item.slot:
                existing = db.query(Inventory).filter(
                    Inventory.machine_id == machine_id,
                    Inventory.slot == target_slot,
                    Inventory.id != item.id
                ).first()
                if existing:
                    raise HTTPException(status_code=400, detail=f"El slot {target_slot} ya existe en esta máquina")
                item.slot = target_slot

        if req.product_name is not None and req.product_name.strip():
            new_name = req.product_name.strip()
            prod_id = f"PROD-{item.machine_id}-{item.slot}"
            dedicated_prod = db.query(Product).filter(Product.id == prod_id).first()
            if not dedicated_prod:
                dedicated_prod = Product(
                    id=prod_id,
                    sku=f"SKU-{item.machine_id}-{item.slot}",
                    name=new_name,
                    price=item.price or 0.0,
                )
                db.add(dedicated_prod)
            else:
                dedicated_prod.name = new_name
            item.product_id = dedicated_prod.id

        db.commit()
        return {"status": "updated", "slot": item.slot, "is_enabled": bool(item.is_enabled), "slot_type": item.slot_type}


@app.post("/api/v1/machines/{machine_id}/slots")
def create_slot(machine_id: str, req: CreateSlotRequest) -> dict:
    with SessionLocal() as db:
        slot_name = req.slot.strip().upper()
        existing = db.query(Inventory).filter(
            Inventory.machine_id == machine_id,
            Inventory.slot == slot_name
        ).first()
        if existing:
            raise HTTPException(status_code=400, detail=f"El slot {slot_name} ya existe en esta máquina")

        # Determine next display_order
        max_order = db.query(Inventory).filter(Inventory.machine_id == machine_id).count()

        prod_id = f"PROD-{machine_id}-{slot_name}"
        prod = db.query(Product).filter(Product.id == prod_id).first()
        if not prod:
            prod = Product(
                id=prod_id,
                sku=f"SKU-{machine_id}-{slot_name}",
                name=req.product_name.strip() or "Nuevo Producto",
                price=req.price,
            )
            db.add(prod)
        else:
            prod.name = req.product_name.strip()
            prod.price = req.price

        new_item = Inventory(
            id=str(uuid4()),
            machine_id=machine_id,
            product_id=prod.id,
            slot=slot_name,
            stock=req.stock,
            capacity=req.capacity,
            price=req.price,
            is_enabled=True,
            slot_type=req.slot_type,
            display_order=max_order,
        )
        db.add(new_item)
        db.commit()
        return {"status": "created", "slot": slot_name, "inventory_id": new_item.id}


@app.post("/api/v1/machines/{machine_id}/reorder-slots")
def reorder_slots(machine_id: str, req: ReorderSlotsRequest) -> dict:
    with SessionLocal() as db:
        for idx, slot_code in enumerate(req.ordered_slots):
            item = db.query(Inventory).filter(
                Inventory.machine_id == machine_id,
                (Inventory.slot == slot_code) | (Inventory.id == slot_code)
            ).first()
            if item:
                item.display_order = idx
        db.commit()
        return {"status": "reordered", "count": len(req.ordered_slots)}



@app.patch("/api/v1/machines/{machine_id}/inventory/{slot_or_id}/price")
def update_inventory_price(machine_id: str, slot_or_id: str, price: float) -> dict:
    with SessionLocal() as db:
        # Buscar por ID de inventario o por slot en esa máquina
        item = db.query(Inventory).filter(
            (Inventory.machine_id == machine_id) & 
            ((Inventory.id == slot_or_id) | (Inventory.slot == slot_or_id))
        ).first()
        
        if not item:
            raise HTTPException(status_code=404, detail="Inventory item not found")
            
        item.price = price
        db.commit()
        return {"status": "updated", "machine_id": machine_id, "slot": item.slot, "new_price": price}


@app.patch("/api/v1/products/{product_id}/price")
def update_product_price(product_id: str, price: float) -> dict:
    with SessionLocal() as db:
        # Intentar buscar por ID, si no existe, buscar por SKU
        product = db.query(Product).filter((Product.id == product_id) | (Product.sku == product_id)).first()
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        product.price = price
        db.commit()
        return {"status": "updated", "product_id": product.id, "sku": product.sku, "new_price": price}


@app.patch("/api/v1/inventory/{inventory_id}")
def update_inventory(inventory_id: str, req: InventoryUpdateRequest) -> dict:
    with SessionLocal() as db:
        row = db.get(Inventory, inventory_id)
        if not row:
            raise HTTPException(status_code=404, detail="Inventory not found")
        
        row.stock = req.stock
        row.capacity = req.capacity
        
        # Alerta de Stock Bajo
        if row.stock < 3:
            machine = db.get(Machine, row.machine_id)
            if machine:
                try:
                    with httpx.Client() as client:
                        client.post(
                            f"{NOTIFICATION_SERVICE_URL}/api/v1/notifications/send",
                            json={
                                "user_email": machine.owner_email,
                                "title": "⚠️ Alerta de Stock Bajo",
                                "summary": f"Slot {row.slot} casi vacío en {machine.name}",
                                "description": f"La máquina {machine.name} (ID: {machine.id}) tiene solo {row.stock} unidades en el slot {row.slot}. Por favor, reabastecer pronto.",
                                "type": "warning"
                            },
                            timeout=2.0
                        )
                except Exception as e:
                    print(f"ERROR sending stock notification: {e}")

        db.commit()
        return {"status": "updated", "inventory_id": inventory_id}


@app.get("/api/v1/admin/sales")
def admin_sales() -> dict:
    return {
        "daily_total": 120.5,
        "weekly_total": 870.0,
        "monthly_total": 3410.3,
    }


@app.patch("/api/v1/machines/{machine_id}/inventory/{slot}/decrement")
def decrement_stock(machine_id: str, slot: str) -> dict:
    with SessionLocal() as db:
        item = db.query(Inventory).filter(
            (Inventory.machine_id == machine_id) & 
            ((Inventory.id == slot) | (Inventory.slot == slot))
        ).first()
        if not item:
            raise HTTPException(status_code=404, detail="Inventory not found")
        
        if item.stock > 0:
            item.stock -= 1
            db.commit()
            return {"status": "decremented", "new_stock": item.stock}
        else:
            return {"status": "empty", "new_stock": 0}


class LocationRequest(BaseModel):
    latitude: float
    longitude: float

@app.patch("/api/v1/machines/{machine_id}/location")
def update_machine_location(machine_id: str, req: LocationRequest) -> dict:
    with SessionLocal() as db:
        machine = db.get(Machine, machine_id)
        if not machine:
            raise HTTPException(status_code=404, detail="Machine not found")
        machine.latitude = req.latitude
        machine.longitude = req.longitude
        db.commit()
        return {"status": "ok", "latitude": machine.latitude, "longitude": machine.longitude}


# ─── CÓDIGO DINÁMICO DE EMPAREJAMIENTO Y CONTROL REMOTO DE MÁQUINA ────────────
_machine_session_codes: dict[str, dict] = {}
_machine_pending_actions: dict[str, dict] = {}
_machine_configs: dict[str, dict] = {}

class VerifyCodeRequest(BaseModel):
    code: str

class SelectSlotRequest(BaseModel):
    slot: str

class MachineConfigRequest(BaseModel):
    code_ttl: int | None = None
    wifi_ssid: str | None = None
    wifi_password: str | None = None
    server_ip: str | None = None

def _get_or_create_session_code(machine_id: str) -> dict:
    now = time.time()
    cfg = _machine_configs.get(machine_id, {"code_ttl": 45})
    ttl = cfg.get("code_ttl", 45)
    
    current = _machine_session_codes.get(machine_id)
    if not current or now >= current["expires_at"]:
        # Generar código de 5 dígitos (10000..99999)
        code = f"{random.randint(10000, 99999)}"
        _machine_session_codes[machine_id] = {
            "code": code,
            "expires_at": now + ttl,
            "ttl": ttl
        }
        current = _machine_session_codes[machine_id]
        
    seconds_left = max(0, int(current["expires_at"] - now))
    return {
        "code": current["code"],
        "ttl": ttl,
        "seconds_left": seconds_left,
        "machine_id": machine_id
    }

@app.get("/api/v1/machines/{machine_id}/session-code")
def get_session_code(machine_id: str) -> dict:
    return _get_or_create_session_code(machine_id)

@app.post("/api/v1/machines/{machine_id}/verify-code")
def verify_session_code(machine_id: str, req: VerifyCodeRequest) -> dict:
    now = time.time()
    current = _machine_session_codes.get(machine_id)
    if not current or now >= current["expires_at"] or current["code"] != req.code.strip():
        raise HTTPException(status_code=400, detail="Código inválido o expirado. Revisa la pantalla de la máquina.")
    
    return {
        "valid": True,
        "machine_id": machine_id,
        "message": "Máquina vinculada correctamente"
    }

@app.post("/api/v1/machines/{machine_id}/select-slot")
def select_slot(machine_id: str, req: SelectSlotRequest) -> dict:
    slot = req.slot.strip().upper()
    _machine_pending_actions[machine_id] = {
        "action": "generate_qr",
        "slot": slot,
        "timestamp": time.time()
    }
    return {"status": "ok", "action": "generate_qr", "slot": slot}

@app.get("/api/v1/machines/{machine_id}/pending-action")
def get_pending_action(machine_id: str) -> dict:
    action = _machine_pending_actions.pop(machine_id, None)
    if action:
        if time.time() - action.get("timestamp", 0) < 30:
            return action
    return {"action": "none"}

@app.get("/api/v1/machines/{machine_id}/config")
def get_machine_config(machine_id: str) -> dict:
    cfg = _machine_configs.get(machine_id, {
        "code_ttl": 45,
        "wifi_ssid": "ar-HP-Laptop-15-da2xxx",
        "server_ip": "10.42.0.1"
    })
    return {"machine_id": machine_id, "config": cfg}

@app.put("/api/v1/machines/{machine_id}/config")
def update_machine_config(machine_id: str, req: MachineConfigRequest) -> dict:
    if machine_id not in _machine_configs:
        _machine_configs[machine_id] = {
            "code_ttl": 45,
            "wifi_ssid": "ar-HP-Laptop-15-da2xxx",
            "server_ip": "10.42.0.1"
        }
    cfg = _machine_configs[machine_id]
    if req.code_ttl is not None and req.code_ttl >= 10:
        cfg["code_ttl"] = req.code_ttl
        if machine_id in _machine_session_codes:
            del _machine_session_codes[machine_id]
    if req.wifi_ssid is not None:
        cfg["wifi_ssid"] = req.wifi_ssid
    if req.wifi_password is not None:
        cfg["wifi_password"] = req.wifi_password
    if req.server_ip is not None:
        cfg["server_ip"] = req.server_ip
        
    return {"status": "updated", "machine_id": machine_id, "config": cfg}

