param(
  [string]$BaseUrl = "http://localhost:8000/api/v1",
  [string]$Token = ""
)

$headers = @{}
if ($Token -ne "") {
  $headers["Authorization"] = "Bearer $Token"
}

Write-Host "Health check"
Invoke-RestMethod -Method Get -Uri "http://localhost:8000/healthz"

Write-Host "Terms page"
Invoke-RestMethod -Method Get -Uri "$BaseUrl/pages/terms-and-conditions"

Write-Host "Upcoming events"
Invoke-RestMethod -Method Get -Uri "$BaseUrl/events/upcoming/anonymous"

Write-Host "Done"
