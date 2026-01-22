param (
    [string]$ProjectName,
    [string]$FilePath,

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

    # 4. Loop until a valid FilePath is provided
    $availableFiles = if ($existingFiles) { $existingFiles.filePath } else { @() }
    # If there are no files, we can't proceed with deletion.
    if ($availableFiles.Count -eq 0) {
        throw "No files found in project '$ProjectName' to delete."
    }
    
    $validFile = $false
    while (-not $validFile) {
        # Prompt for FilePath if missing or invalid
        if ([string]::IsNullOrWhiteSpace($FilePath)) {
            $FilePath = Read-Host "`nEnter GitHub file path to delete"
        }
    
        if ([string]::IsNullOrWhiteSpace($FilePath)) {
            Write-Host "File Path cannot be empty." -ForegroundColor Red
            continue
        }
    
        # Validate against list
        if ($availableFiles -notcontains $FilePath) {
            Write-Host "❌ Error: File '$FilePath' not found in project '$ProjectName'!" -ForegroundColor Red
            $FilePath = $null # Reset for re-prompt
        } else {
            $validFile = $true
        }
    }
    $encodedProject = [Uri]::EscapeDataString($ProjectName)
    $encodedPath = [Uri]::EscapeDataString($FilePath)
    $url = "$BaseUrl/api/Context/$encodedProject/$encodedPath"

    Write-Host "`nYou are about to delete:" -ForegroundColor Yellow
    Write-Host "  Project: $ProjectName" -ForegroundColor Cyan
    Write-Host "  File: $FilePath" -ForegroundColor Cyan

    $confirmation = Read-Host "`nAre you sure you want to delete this file? (Y/N)"

    if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
        Write-Host "Deletion cancelled." -ForegroundColor Gray
        return
    }

    Write-Host "`nDeleting file '$FilePath' from project '$ProjectName'..." -ForegroundColor Red

    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Delete -ErrorAction Stop
    Write-Host "✅ File deleted successfully!" -ForegroundColor Green
    $response | ConvertTo-Json

} catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
