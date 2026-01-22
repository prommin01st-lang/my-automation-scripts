param (
    [string]$ProjectName,
    [string]$FilePath,
    [string]$Content,

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

# 1. Fetch and show existing projects
Write-Host "`nExisting Projects:" -ForegroundColor Yellow
try {
    $projectsUrl = "$BaseUrl/api/Context/projects"
    $existingProjects = Invoke-RestMethod -Uri $projectsUrl -Headers $headers -Method Get
    if ($existingProjects.Count -gt 0) {
        $existingProjects | ForEach-Object { Write-Host " - $($_.name)" -ForegroundColor Gray }
    } else {
        Write-Host " (None)" -ForegroundColor Gray
    }
} catch {
    Write-Warning "Could not fetch existing projects."
}

# 2. Prompt if ProjectName wasn't provided as argument
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

# 4. Prompt for remaining parameters
if ([string]::IsNullOrWhiteSpace($FilePath)) {
    $FilePath = Read-Host "`nEnter remote file path (e.g., 'docs/readme.md')"
}
if ([string]::IsNullOrWhiteSpace($Content)) {
    $Content = Read-Host "`nEnter content (or pipe content to this script)"
}

if ([string]::IsNullOrWhiteSpace($FilePath) -or [string]::IsNullOrWhiteSpace($Content)) {
    Write-Error "FilePath and Content are required."
    exit 1
}

# 5. Safety Check: Rename restricted extensions to .txt
$RestrictedExtensions = @(".config", ".exe", ".dll", ".bin", ".msi", ".php", ".jsp", ".asp", ".aspx", ".sh", ".bat")
$currentExtension = [System.IO.Path]::GetExtension($FilePath)

if ($RestrictedExtensions -contains $currentExtension.ToLower()) {
    $FilePath = "$FilePath.txt"
    Write-Host "Safety Note: Renamed restricted file path to '$FilePath' for secure storage." -ForegroundColor Yellow
}

$encodedProject = [Uri]::EscapeDataString($ProjectName)
$url = "$BaseUrl/api/Context/content"

$payload = @{ 
    projectName = $ProjectName
    filePath    = $FilePath
    content     = $Content
}
$body = $payload | ConvertTo-Json
# Ensure the body is sent as UTF-8 bytes for Invoke-RestMethod
$utf8Body = [System.Text.Encoding]::UTF8.GetBytes($body)

Write-Host "`nUploading content to: $ProjectName/$FilePath..." -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $utf8Body
    Write-Host "Content uploaded successfully!" -ForegroundColor Green
    $response | ConvertTo-Json
} catch {
    Write-Error "Failed to upload content: $_"
}
