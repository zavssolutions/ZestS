param(
  [Parameter(Mandatory = $true)] [string]$RenderApiKey,
  [Parameter(Mandatory = $true)] [string]$OwnerId,
  [Parameter(Mandatory = $true)] [string]$RepoUrl,
  [string]$Branch = "main",
  [string]$BackendName = "zests-backend",
  [string]$WorkerName = "zests-celery-worker",
  [string]$FirebaseServiceAccountJsonPath = "",
  [string]$GcpStorageCredentialsJsonPath = "",
  [string]$FirebaseServiceAccountJson = "",
  [string]$GcpStorageCredentialsJson = "",
  [string]$GcpStorageBucket = ""
)

$headers = @{
  Authorization = "Bearer $RenderApiKey"
  "Content-Type" = "application/json"
}

function Invoke-RenderPost([string]$url, [hashtable]$body) {
  return Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body ($body | ConvertTo-Json -Depth 20 -Compress)
}

function Invoke-RenderPut([string]$url, [array]$body) {
  return Invoke-RestMethod -Method Put -Uri $url -Headers $headers -Body ($body | ConvertTo-Json -Depth 20 -Compress)
}

if ($FirebaseServiceAccountJsonPath -and (Test-Path $FirebaseServiceAccountJsonPath)) {
  $FirebaseServiceAccountJson = Get-Content -Raw $FirebaseServiceAccountJsonPath
}

if ($GcpStorageCredentialsJsonPath -and (Test-Path $GcpStorageCredentialsJsonPath)) {
  $GcpStorageCredentialsJson = Get-Content -Raw $GcpStorageCredentialsJsonPath
}

# 1) Provision Postgres + Key Value
$postgres = Invoke-RenderPost 'https://api.render.com/v1/postgres' @{
  name = 'zests-postgres'
  ownerId = $OwnerId
  plan = 'free'
  version = '16'
  databaseName = 'zests'
  databaseUser = 'zests_admin'
}

$keyValue = Invoke-RenderPost 'https://api.render.com/v1/key-value' @{
  name = 'zests-cache'
  ownerId = $OwnerId
  plan = 'free'
}

# Wait briefly for connection info availability
Start-Sleep -Seconds 8

$dbConn = Invoke-RestMethod -Method Get -Uri "https://api.render.com/v1/postgres/$($postgres.id)/connection-info" -Headers $headers
$kvConn = Invoke-RestMethod -Method Get -Uri "https://api.render.com/v1/key-value/$($keyValue.id)/connection-info" -Headers $headers

# 2) Create backend service
$backend = Invoke-RenderPost 'https://api.render.com/v1/services' @{
  type = 'web_service'
  name = $BackendName
  ownerId = $OwnerId
  repo = $RepoUrl
  branch = $Branch
  rootDir = 'backend'
  autoDeploy = 'yes'
  serviceDetails = @{
    runtime = 'python'
    envSpecificDetails = @{
      buildCommand = 'pip install -r requirements.txt'
      startCommand = 'uvicorn app.main:app --host 0.0.0.0 --port $PORT'
    }
    healthCheckPath = '/healthz'
    plan = 'free'
  }
}

# 3) Create worker service
$worker = Invoke-RenderPost 'https://api.render.com/v1/services' @{
  type = 'background_worker'
  name = $WorkerName
  ownerId = $OwnerId
  repo = $RepoUrl
  branch = $Branch
  rootDir = 'backend'
  autoDeploy = 'yes'
  serviceDetails = @{
    runtime = 'python'
    envSpecificDetails = @{
      buildCommand = 'pip install -r requirements.txt'
      startCommand = 'celery -A app.workers.celery_app.celery_app worker --loglevel=INFO'
    }
    plan = 'starter'
  }
}

# 4) Set env vars
$commonEnv = @(
  @{ key = 'DATABASE_URL'; value = $dbConn.internalConnectionString },
  @{ key = 'REDIS_URL'; value = $kvConn.internalConnectionString },
  @{ key = 'FIREBASE_SERVICE_ACCOUNT_JSON'; value = $FirebaseServiceAccountJson },
  @{ key = 'GCP_STORAGE_CREDENTIALS_JSON'; value = $GcpStorageCredentialsJson },
  @{ key = 'GCP_STORAGE_BUCKET'; value = $GcpStorageBucket },
  @{ key = 'AUTH_ENABLED'; value = 'true' },
  @{ key = 'PAYMENTS_ENABLED'; value = 'false' },
  @{ key = 'PHONE_AUTH_ENABLED'; value = 'true' },
  @{ key = 'GOOGLE_AUTH_ENABLED'; value = 'true' }
)

Invoke-RenderPut "https://api.render.com/v1/services/$($backend.id)/env-vars" $commonEnv | Out-Null
Invoke-RenderPut "https://api.render.com/v1/services/$($worker.id)/env-vars" $commonEnv | Out-Null

Write-Host "Provisioned resources:"
Write-Host "Postgres ID: $($postgres.id)"
Write-Host "Key Value ID: $($keyValue.id)"
Write-Host "Backend Service ID: $($backend.id)"
Write-Host "Worker Service ID: $($worker.id)"
