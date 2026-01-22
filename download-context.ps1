# Download-Context.ps1 v2.5 - Ultimate "Bulletproof" Version
# Improved error handling to prevent script exiting on typos
param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectName,
    
    [Parameter(Mandatory=$false)]
    [string]$FilePath,
    
    [Parameter(Mandatory=$false)]
    [string]$SavePath = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ApiKey = $env:CONTEXT_NEXUS_API_KEY
)

# Force UTF-8 for Thai language support
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$BaseUrl = "http://context-nexus.runasp.net"

# --- Helper Functions ---

function Confirm-DirectoryWritable {
    param([string]$Path)
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) {
        try { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        catch { return $false }
    }
    try {
        $testFile = Join-Path $dir "write_test_$(Get-Random).tmp"
        "test" | Out-File -FilePath $testFile -ErrorAction Stop
        Remove-Item $testFile -Force
        return $true
    } catch { return $false }
}

function Select-SavePath {
    param([string]$FileName)
    Write-Host "`n=== Save Location Selection ===" -ForegroundColor Cyan
    Write-Host "1. Current Directory: $(Get-Location)"
    Write-Host "2. Desktop"
    Write-Host "3. Downloads"
    Write-Host "4. Documents"
    Write-Host "5. Custom Path (Folder or Full File Path)"
    Write-Host "6. Quick Drives (C:, D:, F:, etc.)"
    
    $choice = Read-Host "`nSelect option (1-6)"
    switch ($choice) {
        "1" { return Join-Path (Get-Location) $FileName }
        "2" { return Join-Path ([Environment]::GetFolderPath("Desktop")) $FileName }
        "3" { return Join-Path ([Environment]::GetFolderPath("UserProfile")) "Downloads\$FileName" }
        "4" { return Join-Path ([Environment]::GetFolderPath("MyDocuments")) $FileName }
        "5" { 
            $customPath = Read-Host "Enter path (e.g., F:\Data or F:\Data\file.txt)"
            if ([string]::IsNullOrWhiteSpace($customPath)) { return Join-Path (Get-Location) $FileName }
            if (Test-Path -Path $customPath -PathType Container) { return Join-Path $customPath $FileName }
            return $customPath
        }
        "6" {
            Write-Host "`nAvailable Drives:" -ForegroundColor Yellow
            Get-PSDrive -PSProvider FileSystem | Select-Object Name, @{Name="FreeGB";Expression={[math]::Round($_.Free/1GB,2)}} | ForEach-Object {
                Write-Host "$($_.Name): - Free: $($_.FreeGB) GB"
            }
            $driveChoice = Read-Host "Enter drive letter"
            if ([string]::IsNullOrWhiteSpace($driveChoice)) { return Join-Path (Get-Location) $FileName }
            $drivePath = "$($driveChoice.Trim().ToUpper()):\"
            if (Test-Path $drivePath) { return Join-Path $drivePath $FileName }
            return Join-Path (Get-Location) $FileName
        }
        default { return Join-Path (Get-Location) $FileName }
    }
}

# --- Main Logic ---

try {
    if (-not $ApiKey) {
        Write-Error "API Key not found! Set CONTEXT_NEXUS_API_KEY env variable."
        exit 1
    }
    $headers = @{ "x-api-key" = $ApiKey }

    # --- PHASE 1: Project Selection (With Retry) ---
    $validProjectSelected = $false
    while (-not $validProjectSelected) {
        # Fetch projects list
        $availableProjects = @()
        try {
            Write-Host "`nFetching projects from server..." -ForegroundColor DarkGray
            $projectsUrl = "$BaseUrl/api/Context/projects"
            $existingProjects = Invoke-RestMethod -Uri $projectsUrl -Headers $headers -Method Get
            if ($existingProjects.Count -gt 0) {
                $availableProjects = $existingProjects.name
                Write-Host "Available Projects:" -ForegroundColor Yellow
                $availableProjects | ForEach-Object { Write-Host " - $_" -ForegroundColor Gray }
            }
        } catch {
            Write-Warning "Could not fetch projects list. Check your connection/API Key."
        }

        # Get Project Name
        if ([string]::IsNullOrWhiteSpace($ProjectName)) {
            $ProjectName = Read-Host "`nEnter project name (or type 'exit' to quit)"
        }

        if ($ProjectName -eq "exit") { exit 0 }

        if ([string]::IsNullOrWhiteSpace($ProjectName)) {
            Write-Host "Project Name cannot be empty." -ForegroundColor Red
            continue
        }

        # Validation
        if ($availableProjects.Count -gt 0 -and $availableProjects -notcontains $ProjectName) {
            Write-Host "❌ Error: Project '$ProjectName' not found! Please check for typos." -ForegroundColor Red
            $ProjectName = $null # Force re-prompt
        } else {
            $validProjectSelected = $true
        }
    }

    # --- PHASE 2: File Selection (With Retry) ---
    $validFileSelected = $false
    while (-not $validFileSelected) {
        # Fetch files list for the project
        $availableFiles = @()
        try {
            Write-Host "Fetching files for project '$ProjectName'..." -ForegroundColor DarkGray
            $encodedProject = [Uri]::EscapeDataString($ProjectName)
            $filesUrl = "$BaseUrl/api/Context/$encodedProject/files"
            $existingFiles = Invoke-RestMethod -Uri $filesUrl -Headers $headers -Method Get
            
            if ($existingFiles.Count -gt 0) {
                $availableFiles = $existingFiles.filePath
                Write-Host "Existing files in project '$ProjectName':" -ForegroundColor Yellow
                $availableFiles | ForEach-Object { Write-Host " - $_" -ForegroundColor Gray }
            } else {
                Write-Host "No files found in project '$ProjectName'." -ForegroundColor Yellow
                $ProjectName = $null # Go back to project selection
                $validProjectSelected = $false
                break 
            }
        } catch {
            Write-Host "❌ Error: Could not access project '$ProjectName'. It might not exist on the server." -ForegroundColor Red
            $ProjectName = $null
            $validProjectSelected = $false
            break # Break out to re-select project
        }

        # Get File Path
        if ([string]::IsNullOrWhiteSpace($FilePath)) {
            $FilePath = Read-Host "`nEnter remote file path to download (or type 'back' to change project)"
        }

        if ($FilePath -eq "back") {
            $ProjectName = $null
            $FilePath = $null
            $validProjectSelected = $false
            break
        }

        # Validation
        if ($availableFiles.Count -gt 0 -and $availableFiles -notcontains $FilePath) {
            Write-Host "❌ Error: File '$FilePath' not found in project '$ProjectName'!" -ForegroundColor Red
            $FilePath = $null # Force re-prompt
        } else {
            $validFileSelected = $true
        }
    }

    # --- PHASE 3: Download ---
    if ($validProjectSelected -and $validFileSelected) {
        $encodedProject = [Uri]::EscapeDataString($ProjectName)
        $encodedPath = [Uri]::EscapeDataString($FilePath)
        $url = "$BaseUrl/api/Context/$encodedProject/$encodedPath"

        Write-Host "`nFetching download URL..." -ForegroundColor Cyan
        try {
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
            
            if ($response.url) {
                $downloadUrl = $response.url
                Write-Host "File URL found: $downloadUrl" -ForegroundColor Cyan
                
                $saveChoice = 'Y'
                if ([string]::IsNullOrWhiteSpace($SavePath)) {
                    $saveChoice = Read-Host "`nDo you want to save this to a file? (Y/N)"
                }

                if ($saveChoice -eq 'Y' -or $saveChoice -eq 'y') {
                    $suggestedFileName = Split-Path $FilePath -Leaf
                    $finalPath = if ([string]::IsNullOrWhiteSpace($SavePath)) { Select-SavePath -FileName $suggestedFileName } else { if (Test-Path -Path $SavePath -PathType Container) { Join-Path $SavePath $suggestedFileName } else { $SavePath } }

                    if (Confirm-DirectoryWritable -Path $finalPath) {
                        Write-Host "Downloading to: $finalPath" -ForegroundColor Green
                        Invoke-WebRequest -Uri $downloadUrl -OutFile $finalPath -ErrorAction Stop
                        Write-Host "✅ Download successful!" -ForegroundColor Green
                    } else {
                        Write-Error "Cannot write to path: $finalPath"
                    }
                } else {
                    $resp = Invoke-WebRequest -Uri $downloadUrl -UseBasicParsing
                    Write-Host "`n--- Content ---`n$([System.Text.Encoding]::UTF8.GetString($resp.Content))`n---------------" -ForegroundColor Yellow
                }
            }
        } catch {
            Write-Host "❌ Error: Failed to fetch download URL. The server might be down or the path is invalid." -ForegroundColor Red
        }
    }

} catch {
    Write-Host "`n❌ Unexpected Error: $($_.Exception.Message)" -ForegroundColor Red
}
