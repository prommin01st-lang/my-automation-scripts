param (
    [string]$BaseUrl = "http://context-nexus.runasp.net",
    [string]$ApiKey = $env:CONTEXT_NEXUS_API_KEY
)

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Error "Error: API Key is missing!`nPlease set environment variable 'CONTEXT_NEXUS_API_KEY' or pass '-ApiKey' parameter."
    exit 1
}

$headers = @{
    "x-api-key" = $ApiKey
    "Content-Type" = "application/json"
}

$url = "$BaseUrl/api/Context/overview"
Write-Host "`nFetching System Overview..." -ForegroundColor Cyan

try {
    $overview = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    
    Write-Host "`n=== System Overview ===" -ForegroundColor Green
    Write-Host "Total Projects : $($overview.totalProjects)"
    Write-Host "Total Files    : $($overview.totalFiles)"
    
    if ($overview.projects.Count -gt 0) {
        Write-Host "`n[Project Details]" -ForegroundColor Yellow
        $overview.projects | Format-Table -Property Name, FileCount -AutoSize
    } else {
        Write-Host "`nNo projects found." -ForegroundColor Gray
    }

} catch {
    Write-Error "Failed to fetch overview: $_"
}
