import os
from datetime import datetime
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy import DateTime, Float, Integer, String, create_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./vending.db")

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


Base.metadata.create_all(bind=engine)
app = FastAPI(title="Grog Vending Service")


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
            db.add_all([Product(id="PROD-1", sku="SODA-001", name="Soda", price=8.5), Product(id="PROD-2", sku="CHIPS-002", name="Chips", price=6.0)])
        if db.query(Inventory).count() == 0:
            db.add_all(
                [
                    Inventory(id=str(uuid4()), machine_id="MACHINE-001", product_id="PROD-1", slot="A1", stock=12, capacity=20, price=8.5),
                    Inventory(id=str(uuid4()), machine_id="MACHINE-001", product_id="PROD-2", slot="A2", stock=9, capacity=20, price=6.0),
                    Inventory(id=str(uuid4()), machine_id="MACHINE-002", product_id="PROD-1", slot="A1", stock=3, capacity=20, price=10.0),
                ]
            )
        db.commit()


_seed()


class InventoryUpdateRequest(BaseModel):
    stock: int
    capacity: int


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "vending-service"}


@app.get("/api/v1/machines")
def list_machines(owner_email: str | None = None) -> dict:
    with SessionLocal() as db:
        query = db.query(Machine)
        if owner_email:
            query = query.filter(Machine.owner_email == owner_email)
        machines = query.all()
        return {"machines": [{"id": m.id, "owner_email": m.owner_email, "name": m.name, "status": m.status, "lat": m.latitude, "lng": m.longitude} for m in machines]}


@app.get("/api/v1/machines/{machine_id}/inventory")
def machine_inventory(machine_id: str) -> dict:
    with SessionLocal() as db:
        rows = db.query(Inventory, Product).join(Product, Inventory.product_id == Product.id).filter(Inventory.machine_id == machine_id).all()
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
                }
                for inv, prod in rows
            ]
        }


@app.get("/api/v1/machines/{machine_id}/slots/{slot_id}")
def get_slot_info(machine_id: str, slot_id: str) -> dict:
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
            "stock": inv.stock
        }


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
        db.commit()
        return {"status": "updated", "inventory_id": inventory_id}


@app.get("/api/v1/admin/sales")
def admin_sales() -> dict:
    return {
        "daily_total": 120.5,
        "weekly_total": 870.0,
        "monthly_total": 3410.3,
    }
