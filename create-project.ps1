param (
    [string]$ProjectName,

    [string]$BaseUrl = "http://context-nexus.runasp.net",
    [string]$ApiKey = $env:CONTEXT_NEXUS_API_KEY
)

# Force UTF-8 Encoding for Console Output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Error "Error: API Key is missing!`nPlease set environment variable 'CONTEXT_NEXUS_API_KEY' or pass '-ApiKey' parameter."
    exit 1
}

$url = "$BaseUrl/api/Context/projects"
$headers = @{
    "x-api-key" = $ApiKey
    "Content-Type" = "application/json"
}

# 1. Fetch and show existing projects
Write-Host "`nExisting Projects:" -ForegroundColor Yellow
try {
    $existing = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    if ($existing.Count -gt 0) {
        $existing | ForEach-Object { Write-Host " - $($_.name)" -ForegroundColor Gray }
    } else {
        Write-Host " (None)" -ForegroundColor Gray
    }
} catch {
    Write-Warning "Could not fetch existing projects."
}

# 2. Prompt if ProjectName wasn't provided as argument
if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    $ProjectName = Read-Host "`nEnter name for new project"
}

if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    Write-Error "ProjectName is required."
    exit 1
}

$body = @{ name = $ProjectName } | ConvertTo-Json

Write-Host "`nCreating project: $ProjectName..." -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $body
    Write-Host "Project created successfully!" -ForegroundColor Green
    $response | ConvertTo-Json
} catch {
    Write-Error "Failed to create project: $_"
}
