from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime

class UserBase(BaseModel):
    email: EmailStr
    full_name: str

class UserCreate(UserBase):
    password: str

class User(UserBase):
    id: str
    is_active: bool

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str
    email: Optional[str] = None

class TokenData(BaseModel):
    email: Optional[str] = None

class WalletBase(BaseModel):
    balance: float

class Wallet(WalletBase):
    id: str
    user_id: str

    class Config:
        from_attributes = True

class TransactionBase(BaseModel):
    amount: float
    enrollment_id: Optional[str] = None
    status: str
    method: Optional[str] = None
    type: str
    created_at: datetime

class TransactionCreate(BaseModel):
    amount: float
    enrollment_id: str
    callback_url: str
    webhook_url: str

class Transaction(TransactionBase):
    id: str
    user_id: Optional[str] = None

    class Config:
        from_attributes = True

class PaymentProcessRequest(BaseModel):
    method: str # card, wallet, qr
    card_number: Optional[str] = None
    user_id: Optional[str] = None # For wallet payment

class WalletRechargeRequest(BaseModel):
    amount: float
    card_number: str

class QRWalletPaymentRequest(BaseModel):
    qr_data: str
    amount: Optional[float] = None

class QRPaymentRequestCreate(BaseModel):
    amount: float
    note: Optional[str] = None

class QRConfirmation(BaseModel):
    transaction_id: str
    status: str # completed, failed

class TransferRequest(BaseModel):
    from_email: str
    to_email: str
    amount: float
