param (
    [string]$ProjectName,
    [string]$LocalFile,
    
    [string]$RemotePath = "",
    [string]$BaseUrl = "http://context-nexus.runasp.net",
    [string]$ApiKey = $env:CONTEXT_NEXUS_API_KEY
)

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Error "Error: API Key is missing!`nPlease set environment variable 'CONTEXT_NEXUS_API_KEY' or pass '-ApiKey' parameter."
    exit 1
}

# Ensure System.Net.Http is loaded for Windows PowerShell 5.1
Add-Type -AssemblyName System.Net.Http

$headers = @{
    "x-api-key" = $ApiKey
    "Content-Type" = "application/json; charset=utf-8"
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

# 3. Check/Prompt for LocalFile
if ([string]::IsNullOrWhiteSpace($LocalFile)) {
    $LocalFile = Read-Host "`nEnter local file path to upload"
}

# Check if file exists
if (-not (Test-Path $LocalFile)) {
    Write-Error "File not found: $LocalFile"
    exit 1
}

# 4. Determine Remote Path
if ([string]::IsNullOrWhiteSpace($RemotePath)) {
    $filename = Split-Path $LocalFile -Leaf
    Write-Host "`nDefault remote path: $filename" -ForegroundColor Yellow
    $userInput = Read-Host "Enter remote path (press Enter to use default)"
    
    if ([string]::IsNullOrWhiteSpace($userInput)) {
        $RemotePath = $filename
    } else {
        $RemotePath = $userInput
    }
}

$url = "$BaseUrl/api/Context/upload"
Write-Host "Uploading to: $ProjectName/$RemotePath..." -ForegroundColor Cyan

try {
    $client = New-Object System.Net.Http.HttpClient
    $client.DefaultRequestHeaders.Add("x-api-key", $ApiKey)

    $content = New-Object System.Net.Http.MultipartFormDataContent
    
    $fileStream = [System.IO.File]::OpenRead((Resolve-Path $LocalFile))
    $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
    $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/octet-stream")
    
    $content.Add([System.Net.Http.StringContent]::new($ProjectName), "projectName")
    $content.Add([System.Net.Http.StringContent]::new($RemotePath), "filePath")
    $content.Add($fileContent, "file", (Split-Path $LocalFile -Leaf))

    $response = $client.PostAsync($url, $content).Result
    
    if ($response.IsSuccessStatusCode) {
        $responseBody = $response.Content.ReadAsStringAsync().Result
        Write-Host "File uploaded successfully!" -ForegroundColor Green
        $responseBody | ConvertFrom-Json | ConvertTo-Json
    } else {
        $errorBody = $response.Content.ReadAsStringAsync().Result
        Write-Error "Failed to upload file. StatusCode: $($response.StatusCode). Details: $errorBody"
    }
    
    $fileStream.Dispose()
    $client.Dispose()

} catch {
    Write-Error "Failed to upload file: $_"
}
