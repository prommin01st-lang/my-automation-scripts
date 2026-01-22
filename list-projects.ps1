param (
    [string]$BaseUrl = "http://context-nexus.runasp.net",
    [string]$ApiKey = $env:CONTEXT_NEXUS_API_KEY
)

# Force UTF-8 Encoding for Console Output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        throw "API Key is missing! Please set environment variable 'CONTEXT_NEXUS_API_KEY' or pass '-ApiKey' parameter."
    }

    $url = "$BaseUrl/api/Context/projects"
    $headers = @{ "x-api-key" = $ApiKey }

    Write-Host "Fetching project list..." -ForegroundColor Cyan

    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
    
    if ($response -and $response.Count -gt 0) {
        $response | Select-Object -Property Id, Name | Format-Table -AutoSize
    } else {
        Write-Host "✅ No projects found." -ForegroundColor Green
    }

} catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
