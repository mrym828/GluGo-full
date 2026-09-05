from cryptography.fernet import Fernet, InvalidToken
from django.conf import settings

# Utility helpers used to avoid storing Libre passwords as plain text in the DB.


def _fernet() -> Fernet:
    key = settings.LIBRE_FIELD_ENCRYPTION_KEY
    if not key:
        raise RuntimeError(
            "LIBRE_FIELD_ENCRYPTION_KEY is not set. Generate one with: "
            "python -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\""
        )
    return Fernet(key)


def encrypt_password(value: str) -> str:
    """Return `value` encrypted with LIBRE_FIELD_ENCRYPTION_KEY, as a str."""
    if value is None:
        return None
    return _fernet().encrypt(value.encode()).decode()


def decrypt_password(token: str) -> str:
    """Return the original plaintext value, or None if decryption fails."""
    if not token:
        return None
    try:
        return _fernet().decrypt(token.encode()).decode()
    except (InvalidToken, ValueError):
        return None
