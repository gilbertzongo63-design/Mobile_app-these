#!/usr/bin/env python3
"""
Test script for Google OAuth endpoint
"""
import json
import requests
import sys

BASE_URL = "http://127.0.0.1:8000"

def test_google_login_no_token():
    """Test /auth/google-login without a token"""
    print("\n=== Test 1: POST /auth/google-login without token ===")
    endpoint = f"{BASE_URL}/auth/google-login"
    payload = {
        "id_token": "",
        "display_name": "Test User"
    }
    
    try:
        response = requests.post(endpoint, json=payload)
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
    except Exception as e:
        print(f"Error: {e}")

def test_google_login_invalid_token():
    """Test /auth/google-login with an invalid token"""
    print("\n=== Test 2: POST /auth/google-login with invalid token ===")
    endpoint = f"{BASE_URL}/auth/google-login"
    payload = {
        "id_token": "invalid.token.here",
        "display_name": "Test User"
    }
    
    try:
        response = requests.post(endpoint, json=payload)
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
    except Exception as e:
        print(f"Error: {e}")

def test_api_health():
    """Test if API is running"""
    print("\n=== Test 0: API Health Check ===")
    try:
        response = requests.get(f"{BASE_URL}/docs")
        print(f"API is running! Status: {response.status_code}")
        return True
    except Exception as e:
        print(f"API is NOT running: {e}")
        return False

if __name__ == "__main__":
    print("Testing Google OAuth endpoint...")
    
    if not test_api_health():
        print("\n❌ Backend API is not running. Start it with:")
        print("   cd C:\\Users\\HP\\Desktop\\Soutenance-dev")
        print("   pip install -r requirements-backend.txt")
        print("   python -m uvicorn backend_api:app --host 127.0.0.1 --port 8000")
        sys.exit(1)
    
    test_google_login_no_token()
    test_google_login_invalid_token()
    
    print("\n" + "="*70)
    print("Testing complete!")
    print("\n⚠️  To test with a VALID Google token:")
    print("   1. Go to https://console.cloud.google.com/apis/credentials")
    print("   2. Create an OAuth 2.0 Client ID")
    print("   3. Add the Client ID to .env file: GOOGLE_OAUTH_CLIENT_ID=your-client-id")
    print("   4. Get a valid ID token from Google Sign-In")
    print("   5. Use that token in the test")
