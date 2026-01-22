param (
    [string]$ProjectName,

    [string]$BaseUrl = "http://context-nexus.runasp.net",
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
    $ProjectName = Read-Host "`nEnter project name to list files"
}

if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    Write-Error "ProjectName is required."
    exit 1
}

$url = "$BaseUrl/api/Context/$ProjectName/files"

Write-Host "`nFetching files for project '$ProjectName'..." -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    if ($response.Count -gt 0) {
        $response | Select-Object -Property FilePath, PublicUrl | Format-Table -AutoSize
    } else {
        Write-Host "Project '$ProjectName' has no files." -ForegroundColor Yellow
    }
} catch {
    Write-Error "Failed to fetch files: $_"
}
