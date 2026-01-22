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
        "Content-Type" = "application/json"
    }

    # 1. Fetch existing projects for validation
    $existingProjects = $null
    try {
        $projectsUrl = "$BaseUrl/api/Context/projects"
        $existingProjects = Invoke-RestMethod -Uri $projectsUrl -Headers $headers -Method Get
    } catch {
        Write-Warning "Could not fetch existing projects. Proceeding without live validation."
    }
    
    # 2. Loop until a valid ProjectName is provided
    $validProject = $false
    while (-not $validProject) {
        if ($existingProjects) {
            Write-Host "`nAvailable Projects:" -ForegroundColor Yellow
            $existingProjects.name | ForEach-Object { Write-Host " - $_" -ForegroundColor Gray }
        }
    
        if ([string]::IsNullOrWhiteSpace($ProjectName)) {
            $ProjectName = Read-Host "`nEnter project name to DELETE"
        }
    
        if ([string]::IsNullOrWhiteSpace($ProjectName)) {
            Write-Host "Project Name cannot be empty." -ForegroundColor Red
            continue
        }
    
        # Validate against the list if it was fetched successfully
        if ($existingProjects -and ($existingProjects.name -notcontains $ProjectName)) {
            Write-Host "❌ Error: Project '$ProjectName' not found! Please check for typos." -ForegroundColor Red
            $ProjectName = $null # Reset to allow re-prompting
        } else {
            # If validation passes (or was skipped), exit the loop
            $validProject = $true
        }
    }
    # 2. Confirmation Safety Check
    Write-Host "`nWARNING: You are about to DELETE project '$ProjectName'." -ForegroundColor Red
    Write-Host "This will permanently delete the project and ALL associated files from Cloudinary and the Database." -ForegroundColor Red
    $confirm = Read-Host "Are you sure? Type 'YES' to confirm"

    if ($confirm -ne "YES") {
        Write-Host "Deletion cancelled." -ForegroundColor Yellow
        return
    }

    # 3. Perform Delete
    $encodedProject = [Uri]::EscapeDataString($ProjectName)
    $url = "$BaseUrl/api/Context/projects/$encodedProject"
    Write-Host "`nDeleting project '$ProjectName'..." -ForegroundColor Cyan

    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Delete -ErrorAction Stop
        Write-Host "✅ Project deleted successfully!" -ForegroundColor Green
        $response | ConvertTo-Json
    } catch {
        if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
            # Throw a more specific error message that the outer catch will display
            throw "Project '$ProjectName' not found."
        } else {
            # Re-throw the original exception for the outer catch to handle
            throw $_
        }
    }
} catch {
    # This single catch block now handles all errors consistently
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
