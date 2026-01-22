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

$headers = @{
    "x-api-key" = $ApiKey
    "Content-Type" = "application/json"
}

# 1. Prompt for ProjectName if missing
if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    $ProjectName = Read-Host "`nEnter project name to DELETE"
}

if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    Write-Error "ProjectName is required."
    exit 1
}

# 2. Confirmation Safety Check
Write-Host "`nWARNING: You are about to DELETE project '$ProjectName'." -ForegroundColor Red
Write-Host "This will permanently delete the project and ALL associated files from Cloudinary and the Database." -ForegroundColor Red
$confirm = Read-Host "Are you sure? Type 'YES' to confirm"

if ($confirm -ne "YES") {
    Write-Host "Deletion cancelled." -ForegroundColor Yellow
    exit 0
}

# 3. Perform Delete
$encodedProject = [Uri]::EscapeDataString($ProjectName)
$url = "$BaseUrl/api/Context/projects/$encodedProject"
Write-Host "`nDeleting project '$ProjectName'..." -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Delete
    Write-Host "Project deleted successfully!" -ForegroundColor Green
    $response | ConvertTo-Json
} catch {
    if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
        Write-Error "Project '$ProjectName' not found."
    } else {
        Write-Error "Failed to delete project: $_"
    }
}
