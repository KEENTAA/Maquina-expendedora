from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from google.oauth2 import id_token
from google.auth.transport import requests

# Configuración JWT de SimuPay
SECRET_KEY = "SECRET_GATEWAY_KEY"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

# ID de Cliente Real del Usuario
GOOGLE_CLIENT_ID = "668360177016-njs18vbi6u7ilju4dvj9o4mu00rigqv6.apps.googleusercontent.com"

# Usamos pbkdf2_sha256 en lugar de bcrypt para evitar bugs de compatibilidad en Windows
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_google_token(token: str):
    """
    Verifica un id_token de Google REAL. 
    """
    try:
        print(f"DEBUG AUTH: Iniciando verificación de token: {token[:15]}...")
        # La librería google-auth verifica el token contra los servidores de Google
        idinfo = id_token.verify_oauth2_token(token, requests.Request(), GOOGLE_CLIENT_ID)
        print(f"DEBUG AUTH: Verificación exitosa para email: {idinfo.get('email')}")
        
        return {
            "email": idinfo['email'],
            "full_name": idinfo.get('name', 'Usuario de Google')
        }
    except Exception as e:
        print(f"DEBUG AUTH ERROR: Google Token Verification Failed: {str(e)}")
        import traceback
        traceback.print_exc()
        return None
