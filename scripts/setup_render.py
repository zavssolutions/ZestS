import requests
import json
import time
import os

# Configuration
OLD_RENDER_API_KEY = os.environ.get("OLD_RENDER_API_KEY", "").strip()
NEW_RENDER_API_KEY = os.environ.get("RENDER_API_KEY", "").strip()
REPO_URL = "https://github.com/zavssolutions/ZestS"
PROJECT_NAME_PREFIX = "zestsmvp"

# Old Service ID (for env var sync)
OLD_BACKEND_SERVICE_ID = "srv-d6nmmpngi27c73a7b700"

def get_headers(api_key):
    if not api_key:
        raise RuntimeError("Missing Render API key in environment variables.")
    return {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }

def get_owner_id(api_key):
    url = "https://api.render.com/v1/owners"
    response = requests.get(url, headers=get_headers(api_key))
    response.raise_for_status()
    # Picking the first owner (usually the personal account or team)
    return response.json()[0]['owner']['id']

def create_postgres(api_key, owner_id):
    print("Creating Postgres Database...")
    url = "https://api.render.com/v1/postgres"
    payload = {
        "name": f"{PROJECT_NAME_PREFIX}-db",
        "ownerId": owner_id,
        "plan": "free",
        "version": "16",
        "databaseName": "zests",
        "databaseUser": "zests_admin"
    }
    response = requests.post(url, headers=get_headers(api_key), json=payload)
    response.raise_for_status()
    db_id = response.json()['id']
    
    # Wait for connection info to be available
    print("Waiting for database connection info...")
    while True:
        conn_url = f"https://api.render.com/v1/postgres/{db_id}/connection-info"
        conn_resp = requests.get(conn_url, headers=get_headers(api_key))
        if conn_resp.status_code == 200:
            return db_id, conn_resp.json()['internalConnectionString']
        time.sleep(5)

def create_redis(api_key, owner_id):
    print("Creating Redis Cache...")
    url = "https://api.render.com/v1/key-value"
    payload = {
        "name": f"{PROJECT_NAME_PREFIX}-cache",
        "ownerId": owner_id,
        "plan": "free"
    }
    response = requests.post(url, headers=get_headers(api_key), json=payload)
    response.raise_for_status()
    redis_id = response.json()['id']
    
    print("Waiting for redis connection info...")
    while True:
        conn_url = f"https://api.render.com/v1/key-value/{redis_id}/connection-info"
        conn_resp = requests.get(conn_url, headers=get_headers(api_key))
        if conn_resp.status_code == 200:
            return redis_id, conn_resp.json()['internalConnectionString']
        time.sleep(5)

def get_old_env_vars(api_key, service_id):
    print("Fetching environment variables from old project...")
    url = f"https://api.render.com/v1/services/{service_id}/env-vars"
    response = requests.get(url, headers=get_headers(api_key))
    response.raise_for_status()
    # Extract only key-value pairs, ignoring 'cursor' and metadata
    return [{"key": item['envVar']['key'], "value": item['envVar']['value']} for item in response.json()]

def create_web_service(api_key, owner_id, name, root_dir, build_cmd, start_cmd, runtime, env_vars):
    print(f"Creating Web Service: {name}...")
    url = "https://api.render.com/v1/services"
    payload = {
        "type": "web_service",
        "name": name,
        "ownerId": owner_id,
        "repo": REPO_URL,
        "branch": "main",
        "rootDir": root_dir,
        "autoDeploy": "yes",
        "serviceDetails": {
            "runtime": runtime,
            "envSpecificDetails": {
                "buildCommand": build_cmd,
                "startCommand": start_cmd
            },
            "plan": "free"
        }
    }
    response = requests.post(url, headers=get_headers(api_key), json=payload)
    response.raise_for_status()
    service_id = response.json()['id']
    
    # Set environment variables
    print(f"Setting environment variables for {name}...")
    requests.put(f"{url}/{service_id}/env-vars", headers=get_headers(api_key), json=env_vars)
    return service_id

def main():
    try:
        new_owner_id = get_owner_id(NEW_RENDER_API_KEY)
        
        # 1. Databases
        db_id, db_url = create_postgres(NEW_RENDER_API_KEY, new_owner_id)
        redis_id, redis_url = create_redis(NEW_RENDER_API_KEY, new_owner_id)
        
        # 2. Get old env vars for sync
        old_vars = get_old_env_vars(OLD_RENDER_API_KEY, OLD_BACKEND_SERVICE_ID)
        
        # 3. Filter and update backend env vars
        backend_vars = []
        skip_keys = ["DATABASE_URL", "REDIS_URL", "RENDER_EXTERNAL_URL"]
        for var in old_vars:
            if var['key'] not in skip_keys:
                backend_vars.append(var)
        
        # Add new DB and Redis URLs
        # Note: SQLAlchemy requires 'postgresql+psycopg://'
        backend_db_url = db_url.replace("postgres://", "postgresql+psycopg://")
        backend_vars.append({"key": "DATABASE_URL", "value": backend_db_url})
        backend_vars.append({"key": "REDIS_URL", "value": redis_url})
        backend_vars.append({"key": "FIREBASE_PROJECT_ID", "value": "test-49b1d"})
        
        # 4. Create Backend
        backend_id = create_web_service(
            NEW_RENDER_API_KEY, new_owner_id, 
            f"{PROJECT_NAME_PREFIX}-backend", "backend",
            "pip install -r requirements.txt", 
            "uvicorn app.main:app --host 0.0.0.0 --port $PORT",
            "python", backend_vars
        )
        
        # 5. Create Admin
        admin_vars = [
            {"key": "NEXT_PUBLIC_API_BASE_URL", "value": f"https://{PROJECT_NAME_PREFIX}-backend.onrender.com/api/v1"}
        ]
        admin_id = create_web_service(
            NEW_RENDER_API_KEY, new_owner_id, 
            f"{PROJECT_NAME_PREFIX}-admin", "admin",
            "npm install && npm run build", 
            "npm run start",
            "node", admin_vars
        )
        
        print("\n" + "="*40)
        print("SETUP COMPLETE!")
        print(f"Backend ID: {backend_id}")
        print(f"Admin ID: {admin_id}")
        print(f"Database Internal URL: {db_url}")
        print(f"Redis Internal URL: {redis_url}")
        print("="*40)
        print("\nIMPORTANT: Don't forget to manually add 'FIREBASE_SERVICE_ACCOUNT_JSON' in Render dashboard for the backend service.")

    except Exception as e:
        print(f"Error during setup: {e}")

if __name__ == "__main__":
    main()
