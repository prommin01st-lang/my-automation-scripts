param (
    [string]$ProjectName,

    [string]$BaseUrl = "http://context-nexus.runasp.net",
    [string]$ApiKey = $env:CONTEXT_NEXUS_API_KEY
)

# Force UTF-8 Encoding for Console Output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        throw "API Key is missing! Please set environment variable 'CONTEXT_NEXUS_API_KEY' or pass '-ApiKey' parameter."
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
            $existingProjects | ForEach-Object { Write-Host " - $($_.name)" -ForegroundColor Gray }
        } else {
            Write-Host " (None)" -ForegroundColor Gray
        }
    } catch {
        Write-Warning "Could not fetch existing projects."
    }

    # 2. Loop until a valid ProjectName is provided
    $validProject = $false
    while (-not $validProject) {
        # If ProjectName is passed as a parameter, try to use it first
        if ([string]::IsNullOrWhiteSpace($ProjectName)) {
            $ProjectName = Read-Host "`nEnter project name to list files"
        }
    
        if ([string]::IsNullOrWhiteSpace($ProjectName)) {
            Write-Host "Project Name cannot be empty." -ForegroundColor Red
            continue # Go to start of the loop
        }
    
        # Validate against the list fetched in step 1
        if ($existingProjects -and ($existingProjects.name -notcontains $ProjectName)) {
            Write-Host "❌ Error: Project '$ProjectName' not found! Please check for typos." -ForegroundColor Red
            $ProjectName = $null # Reset to allow re-prompting
        } else {
            # If validation passes (or was skipped because fetching failed), exit the loop
            $validProject = $true
        }
    }
    $encodedProject = [Uri]::EscapeDataString($ProjectName)
    $url = "$BaseUrl/api/Context/$encodedProject/files"

    Write-Host "`nFetching files for project '$ProjectName'..." -ForegroundColor Cyan

    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
    if ($response.Count -gt 0) {
        $response | Select-Object -Property FilePath, PublicUrl | Format-Table -AutoSize
    } else {
        Write-Host "✅ Project '$ProjectName' found, but it has no files." -ForegroundColor Green
    }
} catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
