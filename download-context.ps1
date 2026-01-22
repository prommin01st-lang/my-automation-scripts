# Download-Context.ps1 v2.3 - Enhanced with Project Validation
# Combines interactive listing from v1 with smart path selection from v2 and input validation
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

    # 1. Fetch existing projects for validation
    $availableProjects = @()
    try {
        $projectsUrl = "$BaseUrl/api/Context/projects"
        $existingProjects = Invoke-RestMethod -Uri $projectsUrl -Headers $headers -Method Get
        if ($existingProjects.Count -gt 0) {
            $availableProjects = $existingProjects.name
        }
    } catch { 
        Write-Warning "Could not fetch existing projects. Proceeding without validation." 
    }

    # 2. Loop until a valid ProjectName is provided
    $validProject = $false
    while (-not $validProject) {
        if ($availableProjects.Count -gt 0) {
            Write-Host "`nAvailable Projects:" -ForegroundColor Yellow
            $availableProjects | ForEach-Object { Write-Host " - $_" -ForegroundColor Gray }
        }

        if ([string]::IsNullOrWhiteSpace($ProjectName)) {
            $ProjectName = Read-Host "`nEnter project name"
        }

        if ([string]::IsNullOrWhiteSpace($ProjectName)) {
            Write-Host "Project Name cannot be empty." -ForegroundColor Red
            continue
        }

        # Validate against list
        if ($availableProjects.Count -gt 0 -and $availableProjects -notcontains $ProjectName) {
            Write-Host "❌ Error: Project '$ProjectName' not found! Please check for typos." -ForegroundColor Red
            $ProjectName = $null # Reset for re-prompt
        } else {
            $validProject = $true
        }
    }

    # 3. Fetch and show existing files for selected project
    Write-Host "`nExisting files in project '$ProjectName':" -ForegroundColor Yellow
    try {
        $encodedProject = [Uri]::EscapeDataString($ProjectName)
        $filesUrl = "$BaseUrl/api/Context/$encodedProject/files"
        $existingFiles = Invoke-RestMethod -Uri $filesUrl -Headers $headers -Method Get
        if ($existingFiles.Count -gt 0) {
            $existingFiles | ForEach-Object { Write-Host " - $($_.filePath)" -ForegroundColor Gray }
        } else { Write-Host " (None)" -ForegroundColor Gray }
    } catch { 
        Write-Warning "Could not fetch files for project '$ProjectName'." 
    }

    # 4. Prompt for FilePath if missing
    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        $FilePath = Read-Host "`nEnter remote file path to download"
    }
    if ([string]::IsNullOrWhiteSpace($FilePath)) { throw "FilePath is required." }

    # 5. Connect to Server
    $encodedProject = [Uri]::EscapeDataString($ProjectName)
    $encodedPath = [Uri]::EscapeDataString($FilePath)
    $url = "$BaseUrl/api/Context/$encodedProject/$encodedPath"

    Write-Host "`nFetching info from: $url..." -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

    if ($response.url) {
        $downloadUrl = $response.url
        Write-Host "File URL found: $downloadUrl" -ForegroundColor Cyan
        
        $saveChoice = 'Y'
        if ([string]::IsNullOrWhiteSpace($SavePath)) {
            $saveChoice = Read-Host "`nDo you want to save this to a file? (Y/N)"
        }

        if ($saveChoice -eq 'Y' -or $saveChoice -eq 'y') {
            # Determine Path
            $suggestedFileName = Split-Path $FilePath -Leaf
            $finalPath = ""

            if ([string]::IsNullOrWhiteSpace($SavePath)) {
                $finalPath = Select-SavePath -FileName $suggestedFileName
            } else {
                if (Test-Path -Path $SavePath -PathType Container) {
                    $finalPath = Join-Path $SavePath $suggestedFileName
                } else {
                    $finalPath = $SavePath
                }
            }

            # Verify and Save
            if (Confirm-DirectoryWritable -Path $finalPath) {
                Write-Host "Downloading to: $finalPath" -ForegroundColor Green
                Invoke-WebRequest -Uri $downloadUrl -OutFile $finalPath -ErrorAction Stop
                $info = Get-Item $finalPath
                Write-Host "✅ Download successful! ($([math]::Round($info.Length / 1KB, 2)) KB)" -ForegroundColor Green
            } else {
                Write-Error "Cannot write to path: $finalPath"
            }
        } else {
            # Display Content
            try {
                Write-Host "`nFetching content to display..." -ForegroundColor Gray
                $resp = Invoke-WebRequest -Uri $downloadUrl -UseBasicParsing
                $content = [System.Text.Encoding]::UTF8.GetString($resp.Content)
                Write-Host "`n--- Content of $suggestedFileName ---" -ForegroundColor Yellow
                $content
                Write-Host "------------------------------------`n" -ForegroundColor Yellow
            } catch { Write-Warning "Could not display content as text." }
        }
    } else {
        Write-Host "`n--- Direct Response Content ---" -ForegroundColor Yellow
        $response
        Write-Host "-------------------------------`n" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Usage: 
# nx-download-context (Follow prompts)
# nx-download-context -ProjectName "Nx1" -FilePath "test.txt" -SavePath "F:\"
