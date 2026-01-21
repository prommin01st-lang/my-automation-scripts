param (
    [string]$ProjectName,
    [string]$FilePath,

    [string]$BaseUrl = "https://context-nexus-production.up.railway.app",
    [string]$ApiKey = $env:CONTEXT_NEXUS_API_KEY
)

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Error "Error: API Key is missing!`nPlease set environment variable 'CONTEXT_NEXUS_API_KEY' or pass '-ApiKey' parameter."
    exit 1
}

$headers = @{
    "x-api-key" = $ApiKey
}

# 1. Fetch and show existing projects (to help user verify ProjectName)
Write-Host "`nExisting Projects:" -ForegroundColor Yellow
try {
    $projectsUrl = "$BaseUrl/api/Context/projects"
    $existingProjects = Invoke-RestMethod -Uri $projectsUrl -Headers $headers -Method Get
    if ($existingProjects.Count -gt 0) {
        $existingProjects | ForEach-Object { Write-Host " - $_" -ForegroundColor Gray }
    } else {
        Write-Host " (None)" -ForegroundColor Gray
    }
} catch {
    Write-Warning "Could not fetch existing projects."
}

# 2. Prompt for ProjectName if missing
if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    $ProjectName = Read-Host "`nEnter project name"
}

if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    Write-Error "ProjectName is required."
    exit 1
}

# 3. Fetch and show existing files for the selected project
Write-Host "`nExisting files in project '$ProjectName':" -ForegroundColor Yellow
try {
    $filesUrl = "$BaseUrl/api/Context/$ProjectName/files"
    $existingFiles = Invoke-RestMethod -Uri $filesUrl -Headers $headers -Method Get
    if ($existingFiles.Count -gt 0) {
        $existingFiles | ForEach-Object { Write-Host " - $($_.filePath)" -ForegroundColor Gray }
    } else {
        Write-Host " (None)" -ForegroundColor Gray
    }
} catch {
    Write-Warning "Could not fetch existing files for project '$ProjectName'."
}

# 4. Prompt for FilePath if missing
if ([string]::IsNullOrWhiteSpace($FilePath)) {
    $FilePath = Read-Host "`nEnter GitHub file path to delete"
}

if ([string]::IsNullOrWhiteSpace($FilePath)) {
    Write-Error "FilePath is required."
    exit 1
}

$url = "$BaseUrl/api/Context/$ProjectName/$FilePath"

Write-Host "`nYou are about to delete:" -ForegroundColor Yellow
Write-Host "  Project: $ProjectName" -ForegroundColor Cyan
Write-Host "  File: $FilePath" -ForegroundColor Cyan

$confirmation = Read-Host "`nAre you sure you want to delete this file? (Y/N)"

if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Deletion cancelled." -ForegroundColor Gray
    exit
}

Write-Host "`nDeleting file '$FilePath' from project '$ProjectName'..." -ForegroundColor Red

try {
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Delete
    Write-Host "File deleted successfully!" -ForegroundColor Green
    $response | ConvertTo-Json
} catch {
    Write-Error "Failed to delete file: $_"
}
