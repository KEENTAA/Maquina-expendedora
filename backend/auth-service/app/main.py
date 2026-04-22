import os
from datetime import datetime, timedelta
from uuid import uuid4

import httpx
from fastapi import FastAPI, HTTPException
from jose import jwt
from passlib.context import CryptContext
from pydantic import BaseModel
from sqlalchemy import DateTime, ForeignKey, String, create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./auth.db")
JWT_SECRET = os.getenv("JWT_SECRET", "grog-auth-secret")
SIMUPAY_SERVICE_URL = os.getenv("SIMUPAY_INTEGRATION_URL", "http://simupay-service:8020")
JWT_ALG = "HS256"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class Base(DeclarativeBase):
    pass


class Role(Base):
    __tablename__ = "roles"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, unique=True)


class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    email: Mapped[str] = mapped_column(String, unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String)
    full_name: Mapped[str] = mapped_column(String)
    simupay_email: Mapped[str | None] = mapped_column(String, nullable=True)
    role_id: Mapped[str] = mapped_column(ForeignKey("roles.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    role: Mapped[Role] = relationship(Role)


Base.metadata.create_all(bind=engine)


def _ensure_schema_compatibility() -> None:
    inspector = inspect(engine)
    if "users" not in inspector.get_table_names():
        return

    user_columns = {col["name"] for col in inspector.get_columns("users")}
    with engine.begin() as conn:
        if "simupay_email" not in user_columns:
            conn.execute(text("ALTER TABLE users ADD COLUMN simupay_email VARCHAR"))
        if "created_at" not in user_columns:
            conn.execute(text("ALTER TABLE users ADD COLUMN created_at TIMESTAMP"))


_ensure_schema_compatibility()

app = FastAPI(title="Grog Auth Service")


class LoginRequest(BaseModel):
    email: str
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str
    role: str
    email: str
    simupay_email: str | None = None


class RegisterRequest(BaseModel):
    email: str
    password: str
    full_name: str


class LinkSimupayRequest(BaseModel):
    email: str
    simupay_email: str


def _seed_if_needed() -> None:
    with SessionLocal() as db:
        if db.query(Role).count() == 0:
            client_role = Role(id="role-client", name="CLIENT")
            admin_role = Role(id="role-admin", name="ADMIN")
            devops_role = Role(id="role-devops", name="DEVOPS")
            db.add_all([client_role, admin_role, devops_role])
            db.commit()

            # Seed default users if empty
            if db.query(User).count() == 0:
                db.add(
                    User(
                        id=f"user-{uuid4()}",
                        email="client@grog.com",
                        password_hash=pwd_context.hash("123456"),
                        full_name="Grog Client",
                        role_id=client_role.id,
                        simupay_email="client@grog.com",
                    )
                )
                db.add(
                    User(
                        id=f"user-{uuid4()}",
                        email="admin@grog.com",
                        password_hash=pwd_context.hash("123456"),
                        full_name="Grog Admin",
                        role_id=admin_role.id,
                        simupay_email="admin@grog.com",
                    )
                )
                db.commit()


_seed_if_needed()


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "auth-service"}


@app.post("/api/v1/auth/login", response_model=LoginResponse)
def login(req: LoginRequest) -> LoginResponse:
    with SessionLocal() as db:
        user = db.query(User).filter(User.email == req.email).first()
        if not user or not pwd_context.verify(req.password, user.password_hash):
            raise HTTPException(status_code=401, detail="Invalid credentials")
        role = user.role.name
        token = jwt.encode(
            {
                "sub": user.email,
                "role": role,
                "exp": datetime.utcnow() + timedelta(hours=8),
            },
            JWT_SECRET,
            algorithm=JWT_ALG,
        )
        return LoginResponse(
            access_token=token,
            token_type="bearer",
            role=role,
            email=user.email,
            simupay_email=user.simupay_email
        )


@app.post("/api/v1/auth/register", response_model=LoginResponse)
async def register(req: RegisterRequest) -> LoginResponse:
    if len(req.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    with SessionLocal() as db:
        if db.query(User).filter(User.email == req.email).first():
            raise HTTPException(status_code=409, detail="Email already exists")

        role = db.query(Role).filter(Role.name == "CLIENT").first()
        if not role:
            raise HTTPException(status_code=500, detail="CLIENT role not configured")

        user = User(
            id=f"user-{uuid4()}",
            email=req.email.strip().lower(),
            password_hash=pwd_context.hash(req.password),
            full_name=req.full_name.strip(),
            role_id=role.id,
        )
        db.add(user)
        db.commit()

        # NO LLAMAR A SIMUPAY AQUÍ. La vinculación es manual después.
        
        token = jwt.encode(
            {
                "sub": user.email,
                "role": role.name,
                "exp": datetime.utcnow() + timedelta(hours=8),
            },
            JWT_SECRET,
            algorithm=JWT_ALG,
        )
        return LoginResponse(access_token=token, token_type="bearer", role=role.name, email=user.email)


@app.post("/api/v1/auth/link-simupay")
def link_simupay(req: LinkSimupayRequest) -> dict:
    with SessionLocal() as db:
        user = db.query(User).filter(User.email == req.email).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        user.simupay_email = req.simupay_email
        db.commit()
        return {"status": "ok", "simupay_email": user.simupay_email}


@app.get("/api/v1/users")
def list_users() -> dict:
    with SessionLocal() as db:
        users = db.query(User).all()
        return {"users": [{"email": u.email, "role": u.role.name, "name": u.full_name, "simupay_email": u.simupay_email} for u in users]}
