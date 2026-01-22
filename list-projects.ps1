param (
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
}

Write-Host "Fetching project list..." -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    $response | Select-Object -Property Id, Name | Format-Table -AutoSize
} catch {
    Write-Error "Failed to fetch projects: $_"
}
