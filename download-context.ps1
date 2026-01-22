param (
    [string]$ProjectName,
    [string]$FilePath,
    [string]$OutFile = "",
    
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

# 1. Prompt for inputs
if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    $ProjectName = Read-Host "`nEnter project name"
}
if ([string]::IsNullOrWhiteSpace($FilePath)) {
    $FilePath = Read-Host "`nEnter remote file path to download"
}

if ([string]::IsNullOrWhiteSpace($ProjectName) -or [string]::IsNullOrWhiteSpace($FilePath)) {
    Write-Error "ProjectName and FilePath are required."
    exit 1
}

$url = "$BaseUrl/api/Context/$ProjectName/$FilePath"
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
                     $content = Invoke-RestMethod -Uri $downloadUrl
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
