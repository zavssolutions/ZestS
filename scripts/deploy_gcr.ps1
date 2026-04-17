# ZestS Google Cloud Run Deployment Script (Final IAM Consolidation)
param (
    [Parameter(Mandatory=$true)] [string]$ProjectID,
    [Parameter(Mandatory=$true)] [string]$SupabaseURL,
    [string]$RedisURL = "redis://placeholder"
)

$Region = "asia-south1"
$RepoName = "zests-repo"
$ImageName = "$Region-docker.pkg.dev/$ProjectID/$RepoName/backend:latest"

Write-Host "--- 🚀 Finishing ZestS Deployment to Google Cloud ---" -ForegroundColor Cyan

# 1. Set Project
gcloud.cmd config set project $ProjectID

# 2. Enable APIs
Write-Host "Enabling APIs..."
gcloud.cmd services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com storage.googleapis.com

# 3. FIX: Grant Comprehensive Permissions
Write-Host "Verifying Service Account permissions..."
$ProjNumber = gcloud.cmd projects describe $ProjectID --format='value(projectNumber)'

# Compute SA (needed for GCR and Storage)
$ComputeSA = "$ProjNumber-compute@developer.gserviceaccount.com"
gcloud.cmd projects add-iam-policy-binding $ProjectID --member="serviceAccount:$ComputeSA" --role="roles/storage.admin"
gcloud.cmd projects add-iam-policy-binding $ProjectID --member="serviceAccount:$ComputeSA" --role="roles/artifactregistry.reader"

# Cloud Build SA (needed to PUSH to Artifact Registry)
$BuildSA = "$ProjNumber@cloudbuild.gserviceaccount.com"
gcloud.cmd projects add-iam-policy-binding $ProjectID --member="serviceAccount:$BuildSA" --role="roles/artifactregistry.writer"

# 4. Create Artifact Registry
gcloud.cmd artifacts repositories create $RepoName --repository-format=docker --location=$Region --description="ZestS Docker Repository" 2>$null

# 5. Build and Push Image
Write-Host "Building and Pushing Docker Image..."
cd backend
gcloud.cmd builds submit --config cloudbuild.yaml .
cd ..

# 6. Prepare YAML files
Write-Host "Preparing configuration..."
(Get-Content -Path "infra/gcr_api.yaml") -replace "REPLACEME_IMAGE", $ImageName -replace "REPLACEME_SUPABASE", $SupabaseURL -replace "REPLACEME_REDIS", $RedisURL | Set-Content -Path "infra/gcr_api_deploy.yaml"
(Get-Content -Path "infra/gcr_worker.yaml") -replace "REPLACEME_IMAGE", $ImageName -replace "REPLACEME_SUPABASE", $SupabaseURL -replace "REPLACEME_REDIS", $RedisURL | Set-Content -Path "infra/gcr_worker_deploy.yaml"

# 7. Deploy Services
Write-Host "Deploying API and Worker..."
gcloud.cmd run services replace "infra/gcr_api_deploy.yaml" --region $Region

# For the worker, we use a custom command that runs a dummy HTTP server on port 8080 
# to satisfy Cloud Run's health checks while Celery runs.
$WorkerCommand = "sh,-c,python -m http.server 8080 & celery -A app.workers.celery_app.celery_app worker --loglevel=INFO"
gcloud.cmd run deploy zests-worker --image $ImageName --region $Region --command "sh" --args "-c","python -m http.server 8080 & celery -A app.workers.celery_app.celery_app worker --loglevel=INFO" --set-env-vars "DATABASE_URL=$SupabaseURL,REDIS_URL=$RedisURL,APP_ENV=production" --no-allow-unauthenticated

# 8. Ensure API is public
gcloud.cmd run services add-iam-policy-binding zests-backend --region $Region --member="allUsers" --role="roles/run.invoker"

Write-Host "--- 🎉 Deployment Complete! ---" -ForegroundColor Green
$ServiceUrl = gcloud.cmd run services describe zests-backend --region $Region --format='value(status.url)'
Write-Host "API URL: $ServiceUrl"
