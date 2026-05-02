# ZestS GCR Master Deployment Script (Zero-Docker Version + IAM + Registry Fix)
# Usage: .\scripts\deploy_zests_gcr.ps1 -DatabaseUrl "postgresql+psycopg://postgres:..."

param (
    [Parameter(Mandatory=$true)]
    [string]$DatabaseUrl,

    [string]$Region = "asia-south1",
    # Final Project ID
    [string]$ProjectId = "project-891d72fd-d662-4503-a25"
)

$RepoName = "zests-repo"
$Registry = "$Region-docker.pkg.dev/$ProjectId/$RepoName"

Write-Host "--- Starting ZestS Zero-Docker Deployment to Google Cloud Run ---" -ForegroundColor Cyan

# 1. Ensure Artifact Registry exists
Write-Host "[1/7] Checking Artifact Registry..." -ForegroundColor Yellow
gcloud artifacts repositories create $RepoName --repository-format=docker --location=$Region --quiet 2>$null

# 2. Setup Secrets
Write-Host "[2/7] Setting up Secrets..." -ForegroundColor Yellow
$secretExists = gcloud secrets list --filter="name:zests-database-url" --format="value(name)"
if (-not $secretExists) {
    gcloud secrets create zests-database-url --replication-policy="automatic" --quiet
}
# Add version (piping to gcloud)
Write-Output $DatabaseUrl | gcloud secrets versions add zests-database-url --data-file=- --quiet

# 2.5 Grant IAM Permissions to Service Account
Write-Host "[2.5/7] Configuring IAM Permissions..." -ForegroundColor Yellow
$projectNumber = gcloud projects describe $ProjectId --format="value(projectNumber)"
$serviceAccount = "$projectNumber-compute@developer.gserviceaccount.com"

# Grant Secret Accessor
gcloud projects add-iam-policy-binding $ProjectId `
    --member="serviceAccount:$serviceAccount" `
    --role="roles/secretmanager.secretAccessor" --quiet --no-user-output-enabled

# Grant Logs Writer
gcloud projects add-iam-policy-binding $ProjectId `
    --member="serviceAccount:$serviceAccount" `
    --role="roles/logging.logWriter" --quiet --no-user-output-enabled

# Grant Artifact Registry Reader (Crucial for Cloud Run to pull images)
gcloud projects add-iam-policy-binding $ProjectId `
    --member="serviceAccount:$serviceAccount" `
    --role="roles/artifactregistry.reader" --quiet --no-user-output-enabled

# 3. Build Backend Remotely via Cloud Build
Write-Host "[3/7] Building Backend Image in the Cloud..." -ForegroundColor Yellow
gcloud builds submit --tag "$Registry/backend:latest" ./backend

# Wait for registry propagation
Write-Host "Waiting 10 seconds for registry to index backend image..." -ForegroundColor Gray
Start-Sleep -Seconds 10

# 4. Deploy Backend
Write-Host "[4/7] Deploying Backend Service to Cloud Run..." -ForegroundColor Yellow
gcloud run services replace infra/gcr_api_deploy.yaml --region=$Region --quiet

# 5. Get Backend URL
$BackendUrl = gcloud run services describe zests-backend --region=$Region --format="value(status.url)"
if (-not $BackendUrl) {
    Write-Host "Error: Failed to retrieve Backend URL." -ForegroundColor Red
    exit
}
Write-Host "Backend is live at: $BackendUrl" -ForegroundColor Green

# 6. Build Admin Dashboard Remotely via Cloud Build (pass backend URL as build arg)
Write-Host "[6/7] Building Admin Dashboard Image in the Cloud..." -ForegroundColor Yellow
gcloud builds submit --tag "$Registry/admin:latest" --build-arg "NEXT_PUBLIC_API_BASE_URL=$BackendUrl/api/v1" ./admin

# Wait for registry propagation
Write-Host "Waiting 10 seconds for registry to index admin image..." -ForegroundColor Gray
Start-Sleep -Seconds 10

# 7. Update Admin Manifest with actual Backend URL & Deploy
Write-Host "[7/7] Deploying Admin Dashboard..." -ForegroundColor Yellow
$AdminManifest = Get-Content infra/gcr_admin_deploy.yaml -Raw
$UpdatedManifest = $AdminManifest -replace "https://zests-backend-placeholder.a.run.app/api/v1", "$BackendUrl/api/v1"
$UpdatedManifest | Out-File infra/gcr_admin_deploy_tmp.yaml -Encoding utf8
gcloud run services replace infra/gcr_admin_deploy_tmp.yaml --region=$Region --quiet
Remove-Item infra/gcr_admin_deploy_tmp.yaml

$AdminUrl = gcloud run services describe zests-admin --region=$Region --format="value(status.url)"

Write-Host "DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "-------------------------------------------"
Write-Host "API Endpoint:   $BackendUrl/api/v1" -ForegroundColor Cyan
Write-Host "Admin Panel:    $AdminUrl" -ForegroundColor Cyan
Write-Host "-------------------------------------------"
Write-Host "Next Step: Update your mobile app base URL to the API Endpoint above."
