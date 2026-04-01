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

def test_and_dump():
    id_token = get_id_token()
    if not id_token: return

    headers = {
        "Authorization": f"Bearer {id_token}",
        "Content-Type": "application/json"
    }
    
    # 2. Create Massive Event (10 categories)
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
        })
        
    payload = {
        "title": "Debug Dump Test Event",
        "description": "Created to verify 10 categories in DB dump",
        "organizer_email": ADMIN_EMAIL,
        "price": 0.0,
        "location_name": "Dump Stadium",
        "venue_city": "Dump City",
        "start_at_utc": start_at.isoformat(),
        "end_at_utc": end_at.isoformat(),
        "latitude": 0.0,
        "longitude": 0.0,
        "categories": categories
    }
    
    print(f"\n--- [Step 1] Creating Massive Event on Render ---")
    response = requests.post(f"{API_BASE_URL}/events", json=payload, headers=headers)
    
    if response.status_code != 200:
        print(f"FAILED TO CREATE EVENT: {response.text}")
        return

    event_id = response.json()["id"]
    print(f"✅ Success! Created Event ID: {event_id}")

    # 3. Fetch DB Dump
    print(f"\n--- [Step 2] Fetching Admin DB Dump ---")
    dump_res = requests.get(f"{API_BASE_URL}/admin/debug/db-dump", headers=headers)
    
    if dump_res.status_code != 200:
        print(f"FAILED TO FETCH DB DUMP: {dump_res.status_code}")
        print(dump_res.text)
        return

    dump = dump_res.json()
    
    # 4. Display Filtered Results
    print(f"\n--- [Step 3] Results from DB Dump (Filtered for latest event) ---")
    
    # Events table
    events = dump.get("events", {}).get("rows", [])
    latest_event = next((e for e in events if e["id"] == event_id), None)
    if latest_event:
        print("\nTABLE: events (Latest Row)")
        print(json.dumps(latest_event, indent=2))
    else:
        print("\n❌ Latest event not found in the first 50 rows of 'events' table.")

    # Categories table
    categories_rows = dump.get("event_categories", {}).get("rows", [])
    relevant_categories = [c for c in categories_rows if c["event_id"] == event_id]
    
    print(f"\nTABLE: event_categories (Found {len(relevant_categories)} rows matching Event ID)")
    for c in relevant_categories:
        print(f"  - {c['name']}: ₹{c['price']}")

    if len(relevant_categories) == 10:
        print("\n✅ VERIFICATION COMPLETE: 10 categories successfully created and verified via DB dump!")
    else:
        print(f"\n⚠️ VERIFICATION INCOMPLETE: Found {len(relevant_categories)} matching categories in the dump (first 50 limit).")

if __name__ == "__main__":
    test_and_dump()
