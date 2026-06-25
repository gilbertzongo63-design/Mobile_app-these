import sys
sys.path.insert(0, '.')
import sqlite3
from auth_utils import hash_password

# Generate proper hash
pwd_hash = hash_password('Admin123#')
print(f"Generated hash: {pwd_hash}")

# Connect to DB
conn = sqlite3.connect('backend_data/app.db')
cur = conn.cursor()

# Delete old user
cur.execute('DELETE FROM users WHERE email = ?', ('admin@ecosort.local',))

# Insert new user with PBKDF2 hash
cur.execute('''
    INSERT INTO users (email, full_name, password_hash, role, email_verified, status, created_at)
    VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
''', ('admin@ecosort.local', 'Admin EcoSort', pwd_hash, 'admin', 1, 'active'))

conn.commit()

# Verify
cur.execute('SELECT id, email, role, password_hash FROM users WHERE email = ?', ('admin@ecosort.local',))
result = cur.fetchone()
conn.close()

print(f"Admin user created: ID={result[0]}, Email={result[1]}, Role={result[2]}")
print(f"Password hash stored: {result[3][:30]}...")
