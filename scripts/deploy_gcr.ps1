param (
    [Parameter(Mandatory=$true)] [string]$ProjectID,
    [Parameter(Mandatory=$true)] [string]$SupabaseURL,
    [string]$FirebaseID = "test-49b1d",
    [string]$AdminEmails = "sivakumar.perumalla.lld01@gmail.com,admin@zestsports.in",
    [string]$StorageBucket = "project-891d72fd-d662-4503-a25.firebasestorage.app",
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
gcloud.cmd services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com storage.googleapis.com identitytoolkit.googleapis.com

# 3. FIX: Grant Comprehensive Permissions
Write-Host "Verifying Service Account permissions..."
$ProjNumber = gcloud.cmd projects describe $ProjectID --format='value(projectNumber)'

# Compute SA (needed for GCR, Firebase, and Storage)
$ComputeSA = "$ProjNumber-compute@developer.gserviceaccount.com"
gcloud.cmd projects add-iam-policy-binding $ProjectID --member="serviceAccount:$ComputeSA" --role="roles/storage.admin"
gcloud.cmd projects add-iam-policy-binding $ProjectID --member="serviceAccount:$ComputeSA" --role="roles/artifactregistry.reader"
gcloud.cmd projects add-iam-policy-binding $ProjectID --member="serviceAccount:$ComputeSA" --role="roles/firebaseauth.admin"

# Cloud Build SA (needed to PUSH to Artifact Registry)
$BuildSA = "$ProjNumber@cloudbuild.gserviceaccount.com"
gcloud.cmd projects add-iam-policy-binding $ProjectID --member="serviceAccount:$BuildSA" --role="roles/artifactregistry.admin"

# 4. Create Artifact Registry
gcloud.cmd artifacts repositories create $RepoName --repository-format=docker --location=$Region --description="ZestS Docker Repository" 2>$null

# 5. Build and Push Image
Write-Host "Building and Pushing Docker Image..."
cd backend
gcloud.cmd builds submit --config cloudbuild.yaml .
cd ..

# 6. Prepare YAML files
Write-Host "Preparing configuration..."
$CommonReplacements = @{
    "REPLACEME_IMAGE"           = $ImageName
    "REPLACEME_SUPABASE"        = $SupabaseURL
    "REPLACEME_REDIS"           = $RedisURL
    "REPLACEME_FIREBASE_ID"     = $FirebaseID
    "REPLACEME_ADMIN_EMAILS"    = $AdminEmails
    "REPLACEME_STORAGE_BUCKET"  = $StorageBucket
}

function Invoke-Placement {
    param($Path)
    $Content = Get-Content -Path $Path
    foreach ($key in $CommonReplacements.Keys) {
        $Content = $Content -replace $key, $CommonReplacements[$key]
    }
    return $Content
}

Invoke-Placement -Path "infra/gcr_api.yaml" | Set-Content -Path "infra/gcr_api_deploy.yaml"
Invoke-Placement -Path "infra/gcr_worker.yaml" | Set-Content -Path "infra/gcr_worker_deploy.yaml"

# 7. Deploy Services
Write-Host "Deploying API and Worker..."
gcloud.cmd run services replace "infra/gcr_api_deploy.yaml" --region $Region
gcloud.cmd run services replace "infra/gcr_worker_deploy.yaml" --region $Region

# 8. Ensure API is public
gcloud.cmd run services add-iam-policy-binding zests-backend --region $Region --member="allUsers" --role="roles/run.invoker"

Write-Host "--- 🎉 Deployment Complete! ---" -ForegroundColor Green
$ServiceUrl = gcloud.cmd run services describe zests-backend --region $Region --format='value(status.url)'
Write-Host "API URL: $ServiceUrl"
