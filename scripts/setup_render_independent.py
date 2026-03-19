import requests
import json
import time
import os

# Configuration
RENDER_API_KEY = os.environ.get("RENDER_API_KEY", "").strip()
REPO_URL = "https://github.com/zavssolutions/ZestS"
PROJECT_NAME_PREFIX = "zestsmvp"
FIREBASE_PROJECT_ID = "test-49b1d"

def get_headers():
    if not RENDER_API_KEY:
        raise RuntimeError("Missing RENDER_API_KEY environment variable.")
    return {
        "Authorization": f"Bearer {RENDER_API_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }

def get_owner_id():
    url = "https://api.render.com/v1/owners"
    response = requests.get(url, headers=get_headers())
    response.raise_for_status()
    return response.json()[0]['owner']['id']

def create_postgres(owner_id):
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
    response = requests.post(url, headers=get_headers(), json=payload)
    response.raise_for_status()
    db_id = response.json()['id']
    
    print("Waiting for database connection info...")
    while True:
        conn_url = f"https://api.render.com/v1/postgres/{db_id}/connection-info"
        conn_resp = requests.get(conn_url, headers=get_headers())
        if conn_resp.status_code == 200:
            return db_id, conn_resp.json()['internalConnectionString']
        time.sleep(5)

def create_redis(owner_id):
    print("Creating Redis Cache...")
    url = "https://api.render.com/v1/key-value"
    payload = {
        "name": f"{PROJECT_NAME_PREFIX}-cache",
        "ownerId": owner_id,
        "plan": "free"
    }
    response = requests.post(url, headers=get_headers(), json=payload)
    response.raise_for_status()
    redis_id = response.json()['id']
    
    print("Waiting for redis connection info...")
    while True:
        conn_url = f"https://api.render.com/v1/key-value/{redis_id}/connection-info"
        conn_resp = requests.get(conn_url, headers=get_headers())
        if conn_resp.status_code == 200:
            return redis_id, conn_resp.json()['internalConnectionString']
        time.sleep(5)

def create_service(owner_id, type, name, root_dir, build_cmd, start_cmd, runtime, env_vars, health_check_path=None):
    print(f"Creating {type.replace('_', ' ').title()}: {name}...")
    url = "https://api.render.com/v1/services"
    
    service_details = {
        "runtime": runtime,
        "envSpecificDetails": {
            "buildCommand": build_cmd,
            "startCommand": start_cmd
        },
        "plan": "free" if type != "background_worker" else "starter"
    }
    
    if health_check_path:
        service_details["healthCheckPath"] = health_check_path

    payload = {
        "type": type,
        "name": name,
        "ownerId": owner_id,
        "repo": REPO_URL,
        "branch": "main",
        "rootDir": root_dir,
        "autoDeploy": "yes",
        "serviceDetails": service_details
    }
    
    response = requests.post(url, headers=get_headers(), json=payload)
    response.raise_for_status()
    service_id = response.json()['id']
    
    print(f"Setting environment variables for {name}...")
    # Render API expects a simple array of {key, value} for environment variables
    env_payload = [{"key": v["key"], "value": v["value"]} for v in env_vars]
    requests.put(f"{url}/{service_id}/env-vars", headers=get_headers(), json=env_payload)
    return service_id

def main():
    try:
        owner_id = get_owner_id()
        
        # 1. Provision Infrastructure
        db_id, db_url = create_postgres(owner_id)
        redis_id, redis_url = create_redis(owner_id)
        
        # Format database URL for SQLAlchemy
        backend_db_url = db_url.replace("postgres://", "postgresql+psycopg://")
        
        # 2. Define Backend Environment Variables
        backend_env = [
            {"key": "DATABASE_URL", "value": backend_db_url},
            {"key": "REDIS_URL", "value": redis_url},
            {"key": "APP_ENV", "value": "production"},
            {"key": "APP_NAME", "value": "ZestS MVP API"},
            {"key": "API_V1_PREFIX", "value": "/api/v1"},
            {"key": "ADMIN_EMAILS", "value": "zavssolutions@gmail.com,sivakumar.perumalla.lld01@gmail.com"},
            {"key": "MEILISEARCH_URL", "value": "http://localhost:7700"},
            {"key": "MEILISEARCH_MASTER_KEY", "value": "masterKey"},
            {"key": "FIREBASE_PROJECT_ID", "value": FIREBASE_PROJECT_ID},
            {"key": "GOOGLE_AUTH_ENABLED", "value": "true"},
            {"key": "PHONE_AUTH_ENABLED", "value": "true"},
            {"key": "AUTH_ENABLED", "value": "true"},
            {"key": "PYTHON_VERSION", "value": "3.12.4"}
        ]
        
        # 3. Create Backend Service (with auto-migrations)
        backend_id = create_service(
            owner_id, "web_service", f"{PROJECT_NAME_PREFIX}-backend", "backend",
            "pip install -r requirements.txt", 
            "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port $PORT",
            "python", backend_env, health_check_path="/healthz"
        )
        
        # 4. Create Admin Service
        admin_env = [
            {"key": "NEXT_PUBLIC_API_BASE_URL", "value": f"https://{PROJECT_NAME_PREFIX}-backend.onrender.com/api/v1"}
        ]
        create_service(
            owner_id, "web_service", f"{PROJECT_NAME_PREFIX}-admin", "admin",
            "npm install && npm run build", 
            "npm run start",
            "node", admin_env
        )
        
        # 5. Create Worker Service (Requires card on file)
        try:
            worker_env = [
                {"key": "DATABASE_URL", "value": backend_db_url},
                {"key": "REDIS_URL", "value": redis_url},
                {"key": "APP_ENV", "value": "production"},
                {"key": "FIREBASE_PROJECT_ID", "value": FIREBASE_PROJECT_ID}
            ]
            create_service(
                owner_id, "background_worker", f"{PROJECT_NAME_PREFIX}-worker", "backend",
                "pip install -r requirements.txt", 
                "celery -A app.workers.celery_app.celery_app worker --loglevel=INFO",
                "python", worker_env
            )
        except Exception as e:
            print(f"\nWorker creation skipped: {e} (Add billing to Render for non-web services)")

        print("\n" + "="*40)
        print("FULLY AUTOMATED SETUP COMPLETE!")
        print(f"Project Prefix: {PROJECT_NAME_PREFIX}")
        print(f"Firebase Project: {FIREBASE_PROJECT_ID}")
        print("="*40)
        print("\nFINAL MANUAL STEPS:")
        print("1. Go to Firebase Console -> Service Accounts -> Generate new private key.")
        print(f"2. In Render Dashboard, add 'FIREBASE_SERVICE_ACCOUNT_JSON' to the {PROJECT_NAME_PREFIX}-backend service.")
        print("3. Re-run 'flutter build apk' after adding the new 'google-services.json'.")

    except Exception as e:
        print(f"Error during setup: {e}")

if __name__ == "__main__":
    main()
