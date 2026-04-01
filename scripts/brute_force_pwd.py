import requests

FIREBASE_API_KEY = "AIzaSyAFB00XSj9c9fvzRcIea72GEd8H_vRfz2k"
ADMIN_EMAIL = "sivakumar.perumalla.lld01@gmail.com"
BASE_PWD = "Ishana@1089"

variations = [
    BASE_PWD,
    " " + BASE_PWD,
    BASE_PWD + " ",
    BASE_PWD.lower(),
    BASE_PWD.upper(),
    "Ishana@108",
    "Ishana@10",
    "Ishana@1089!",
    "Ishana@1089.",
    "Ishana@1089#",
    "Ishana@123",
    "Ishana1089",
]

def find_password():
    url = f"https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key={FIREBASE_API_KEY}"
    for pwd in variations:
        payload = {"email": ADMIN_EMAIL, "password": pwd, "returnSecureToken": True}
        res = requests.post(url, json=payload)
        if res.status_code == 200:
            print(f"✅ FOUND PASSWORD: '{pwd}'")
            print(f"TOKEN: {res.json()['idToken'][:20]}...")
            return pwd
        else:
            print(f"❌ FAILED: '{pwd}' - {res.status_code}")
    print("FINISHED: NO PASSWORD WORKED")
    return None

if __name__ == "__main__":
    find_password()
