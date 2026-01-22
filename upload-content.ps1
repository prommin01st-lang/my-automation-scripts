param (
    [string]$ProjectName,
    [string]$FilePath,
    [string]$Content,

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

    # 2. Loop until a valid ProjectName is provided
    $validProject = $false
    while (-not $validProject) {
        # If ProjectName is passed as a parameter, try to use it first
        if ([string]::IsNullOrWhiteSpace($ProjectName)) {
            $ProjectName = Read-Host "`nEnter project name"
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
    # 3. Fetch and show existing files for the selected project
    Write-Host "`nExisting files in project '$ProjectName':" -ForegroundColor Yellow
    try {
        $encodedProjectList = [Uri]::EscapeDataString($ProjectName)
        $filesUrl = "$BaseUrl/api/Context/$encodedProjectList/files"
        $existingFiles = Invoke-RestMethod -Uri $filesUrl -Headers $headers -Method Get
        if ($existingFiles.Count -gt 0) {
            $existingFiles | ForEach-Object { Write-Host " - $($_.filePath)" -ForegroundColor Gray }
        } else {
            Write-Host " (None)" -ForegroundColor Gray
        }
    } catch {
        # Re-throw the exception to be caught by the main handler, which will terminate the script.
        throw $_
    }

    # 4. Loop until FilePath and Content are provided
    while ([string]::IsNullOrWhiteSpace($FilePath)) {
        $FilePath = Read-Host "`nEnter remote file path (e.g., 'docs/readme.md')"
        if ([string]::IsNullOrWhiteSpace($FilePath)) {
            Write-Host "FilePath cannot be empty." -ForegroundColor Red
        }
    }
    while ([string]::IsNullOrWhiteSpace($Content)) {
        $Content = Read-Host "`nEnter content (or pipe content to this script)"
        if ([string]::IsNullOrWhiteSpace($Content)) {
            Write-Host "Content cannot be empty." -ForegroundColor Red
        }
    }
    # 5. Safety Check: Rename restricted extensions to .txt
    $RestrictedExtensions = @(".config", ".exe", ".dll", ".bin", ".msi", ".php", ".jsp", ".asp", ".aspx", ".sh", ".bat")
    $currentExtension = [System.IO.Path]::GetExtension($FilePath)

    if ($RestrictedExtensions -contains $currentExtension.ToLower()) {
        $FilePath = "$FilePath.txt"
        Write-Host "Safety Note: Renamed restricted file path to '$FilePath' for secure storage." -ForegroundColor Yellow
    }
    
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

    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $utf8Body -ErrorAction Stop
    Write-Host "✅ Content uploaded successfully!" -ForegroundColor Green
    $response | ConvertTo-Json
} catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
