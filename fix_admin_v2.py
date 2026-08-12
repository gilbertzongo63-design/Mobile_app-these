import sys
sys.path.insert(0, '.')
from auth_utils import hash_password
from database import engine
from sqlalchemy import text, func
from datetime import datetime

pwd_hash = hash_password('Admin123#')
print(f"Generated hash: {pwd_hash}")

with engine.connect() as conn:
    conn.execute(text("DELETE FROM users WHERE email = 'admin@ecosort.local'"))
    conn.execute(
        text("""
            INSERT INTO users (email, full_name, password_hash, role, email_verified, status, created_at)
            VALUES (:email, :name, :hash, :role, 1, 'active', :now)
        """),
        {"email": "admin@ecosort.local", "name": "Admin EcoSort", "hash": pwd_hash, "role": "admin", "now": datetime.utcnow()}
    )
    conn.commit()

    result = conn.execute(
        text("SELECT id, email, role FROM users WHERE email = 'admin@ecosort.local'")
    ).fetchone()

print(f"Admin user created: ID={result[0]}, Email={result[1]}, Role={result[2]}")
print(f"Password hash stored: {pwd_hash[:30]}...")
