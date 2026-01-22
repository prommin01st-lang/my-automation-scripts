param (
    [string]$ProjectName,
    [string]$FilePath,
    [string]$OutFile = "",
    
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

# 2. Prompt for ProjectName
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
    $encodedProject = [Uri]::EscapeDataString($ProjectName)
    $filesUrl = "$BaseUrl/api/Context/$encodedProject/files"
    $existingFiles = Invoke-RestMethod -Uri $filesUrl -Headers $headers -Method Get
    if ($existingFiles.Count -gt 0) {
        $existingFiles | ForEach-Object { Write-Host " - $($_.filePath)" -ForegroundColor Gray }
    } else {
        Write-Host " (None)" -ForegroundColor Gray
    }
} catch {
    Write-Warning "Could not fetch existing files for project '$ProjectName'."
}

# 4. Prompt for FilePath
if ([string]::IsNullOrWhiteSpace($FilePath)) {
    $FilePath = Read-Host "`nEnter remote file path to download"
}

if ([string]::IsNullOrWhiteSpace($FilePath)) {
    Write-Error "FilePath is required."
    exit 1
}

$encodedProject = [Uri]::EscapeDataString($ProjectName)
$encodedPath = [Uri]::EscapeDataString($FilePath)
$url = "$BaseUrl/api/Context/$encodedProject/$encodedPath"
Write-Host "Fetching info from: $url..." -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    
    # Check if Cloudinary URL
    if ($response.url) {
        $downloadUrl = $response.url
        Write-Host "File URL found: $downloadUrl" -ForegroundColor Cyan
        
        if ([string]::IsNullOrWhiteSpace($OutFile)) {
             $saveChoice = Read-Host "Do you want to save this to a file? (Y/N)"
             if ($saveChoice -eq 'Y' -or $saveChoice -eq 'y') {
                $suggestedName = Split-Path $FilePath -Leaf
                $filename = Read-Host "Enter filename (default: $suggestedName)"
                if ([string]::IsNullOrWhiteSpace($filename)) { $filename = $suggestedName }
                
                Invoke-WebRequest -Uri $downloadUrl -OutFile $filename
                Write-Host "Successfully downloaded to $filename" -ForegroundColor Green
             } else {
                 # Try to display content if text
                 try {
                     $resp = Invoke-WebRequest -Uri $downloadUrl -UseBasicParsing
                     $content = [System.Text.Encoding]::UTF8.GetString($resp.Content)
                     Write-Host "`n--- Content ---" -ForegroundColor Yellow
                     $content
                     Write-Host "---------------`n" -ForegroundColor Yellow
                 } catch {
                     Write-Warning "Could not read content as text (might be binary)."
                 }
             }
        } else {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $OutFile
            Write-Host "Successfully downloaded to $OutFile" -ForegroundColor Green
        }

    } else {
        # Fallback (Direct Content)
        Write-Host "`n--- Content ---" -ForegroundColor Yellow
        $response
        Write-Host "---------------`n" -ForegroundColor Yellow
        
        if ([string]::IsNullOrWhiteSpace($OutFile)) {
             $saveChoice = Read-Host "Do you want to save this to a file? (Y/N)"
             if ($saveChoice -eq 'Y' -or $saveChoice -eq 'y') {
                $suggestedName = Split-Path $FilePath -Leaf
                $filename = Read-Host "Enter filename (default: $suggestedName)"
                if ([string]::IsNullOrWhiteSpace($filename)) { $filename = $suggestedName }
                $response | Out-File -FilePath $filename -Encoding utf8
                Write-Host "Successfully saved to $filename" -ForegroundColor Green
             }
        }
    }
} catch {
    Write-Error "Failed to download content: $_"
}
