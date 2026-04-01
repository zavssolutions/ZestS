import requests

FIREBASE_API_KEY = "AIzaSyAFB00XSj9c9fvzRcIea72GEd8H_vRfz2k"
ADMIN_EMAIL = "sivakumar.perumalla.lld01@gmail.com"
ADMIN_PASSWORD = "Ishana@1089"

def check_signup():
    url = f"https://www.googleapis.com/identitytoolkit/v3/relyingparty/signupNewUser?key={FIREBASE_API_KEY}"
    payload = {"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD, "returnSecureToken": True}
    res = requests.post(url, json=payload)
    print(f"Signup Status: {res.status_code}")
    print(f"Signup Response: {res.text}")

def check_signin():
    url = f"https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key={FIREBASE_API_KEY}"
    payload = {"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD, "returnSecureToken": True}
    res = requests.post(url, json=payload)
    print(f"Signin Status: {res.status_code}")
    print(f"Signin Response: {res.text}")

if __name__ == "__main__":
    check_signup()
    check_signin()
