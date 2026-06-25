import sqlite3
import bcrypt
from datetime import datetime

# Generate hash
pwd_hash = bcrypt.hashpw(b'Admin123#', bcrypt.gensalt()).decode()

# Connect to DB
conn = sqlite3.connect('backend_data/app.db')
cur = conn.cursor()

# Delete old user
cur.execute('DELETE FROM users WHERE email = ?', ('admin@ecosort.local',))

# Insert new user with valid hash
cur.execute('''
    INSERT INTO users (email, full_name, password_hash, role, email_verified, status, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
''', ('admin@ecosort.local', 'Admin EcoSort', pwd_hash, 'admin', 1, 'active', datetime.now()))

conn.commit()

# Verify
cur.execute('SELECT id, email, role FROM users WHERE email = ?', ('admin@ecosort.local',))
result = cur.fetchone()
conn.close()

print(f"Admin user created: ID={result[0]}, Email={result[1]}, Role={result[2]}")
print(f"Password hash: {pwd_hash[:20]}...")
