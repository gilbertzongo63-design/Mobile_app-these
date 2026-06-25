import urllib.request
import json
import time

base = 'http://172.25.32.1:8000'
email = f"test+{int(time.time())}@example.com"
pwd = 'Testpass123'

payload = {'email': email, 'full_name': 'Test User', 'password': pwd}
req = urllib.request.Request(f"{base}/auth/register", data=json.dumps(payload).encode('utf-8'), headers={'Content-Type': 'application/json'})
reg = json.loads(urllib.request.urlopen(req).read().decode())
print('REGISTER:', json.dumps(reg))

token = reg.get('verification_token')
if token:
    req2 = urllib.request.Request(f"{base}/auth/verify-email", data=json.dumps({'token': token}).encode('utf-8'), headers={'Content-Type': 'application/json'})
    verify = json.loads(urllib.request.urlopen(req2).read().decode())
    print('VERIFY:', json.dumps(verify))

req3 = urllib.request.Request(f"{base}/auth/login", data=json.dumps({'email': email, 'password': pwd}).encode('utf-8'), headers={'Content-Type': 'application/json'})
login = json.loads(urllib.request.urlopen(req3).read().decode())
print('LOGIN:', json.dumps(login))
