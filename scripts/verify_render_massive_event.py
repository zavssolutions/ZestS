import requests
import json
from datetime import datetime, timedelta, timezone

# 1. Configuration
API_BASE_URL = "https://zestsmvp-backend.onrender.com/api/v1"
FIREBASE_API_KEY = "AIzaSyAFB00XSj9c9fvzRcIea72GEd8H_vRfz2k"
ADMIN_EMAIL = "sivakumar.perumalla.lld01@gmail.com"
ADMIN_PASSWORD = "Ishana@1089"

def get_id_token():
    url = f"https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key={FIREBASE_API_KEY}"
    payload = {"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD, "returnSecureToken": True}
    res = requests.post(url, json=payload)
    if res.status_code == 200:
        return res.json()["idToken"]
    else:
        print(f"FAILED TO GET ID TOKEN: {res.text}")
        return None

def verify_massive_event():
    id_token = get_id_token()
    if not id_token: return

    headers = {
        "Authorization": f"Bearer {id_token}",
        "Content-Type": "application/json"
    }
    # 2. Prepare Payload
    start_at = datetime.now(timezone.utc) + timedelta(days=30)
    end_at = start_at + timedelta(hours=5)
    
    categories = []
    for i in range(1, 11):
        categories.append({
            "name": f"Massive Category {i}",
            "price": 10.0 * i,
            "category_type": "Road",
            "skate_type": "Inline",
            "age_group": "Under 15",
            "distance": f"{i}km",
            "images_url": [f"https://example.com/massive_img{i}.png"]
        })
        
    payload = {
        "title": "Render Massive Test Event",
        "description": "Created via API verification script with 10 categories",
        "price": 0.0,
        "location_name": "Hosted Stadium",
        "venue_city": "Cloud City",
        "start_at_utc": start_at.isoformat(),
        "end_at_utc": end_at.isoformat(),
        "latitude": 0.0,
        "longitude": 0.0,
        "categories": categories
    }
    
    # 3. POST /events
    print(f"\n--- Creating Event on Render: {API_BASE_URL}/events ---")
    response = requests.post(f"{API_BASE_URL}/events", json=payload, headers=headers)
    
    print(f"Status: {response.status_code}")
    if response.status_code != 200:
        print(f"Error Body: {response.text}")
        return

    event_data = response.json()
    event_id = event_data["id"]
    print(f"✅ Success! Event ID on Render: {event_id}")

    # 4. Fetch Event Detail (to show "table contents")
    print(f"\n--- Fetching Event Details from Render ---")
    detail_res = requests.get(f"{API_BASE_URL}/admin/events/{event_id}", headers=headers)
    if detail_res.status_code == 200:
        print(json.dumps(detail_res.json(), indent=2))
    else:
        print(f" (Could not fetch admin detail: {detail_res.status_code})")
        # Fallback to public detail if admin fails
        public_res = requests.get(f"{API_BASE_URL}/events/{event_id}", headers=headers)
        print(json.dumps(public_res.json(), indent=2))

if __name__ == "__main__":
    verify_massive_event()
