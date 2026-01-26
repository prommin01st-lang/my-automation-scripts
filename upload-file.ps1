param (
    [string]$ProjectName,
    [string]$LocalFile,

    [string]$RemotePath = "",
    [string]$BaseUrl = "http://context-nexus.runasp.net",
    [string]$ApiKey = $env:CONTEXT_NEXUS_API_KEY
)

# Force UTF-8 Encoding for Console Output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        throw "API Key is missing! Please set environment variable 'CONTEXT_NEXUS_API_KEY' or pass '-ApiKey' parameter."
    }

    # Ensure System.Net.Http is loaded for Windows PowerShell 5.1
    Add-Type -AssemblyName System.Net.Http

    # Headers for project listing, not for HttpClient
    $listHeaders = @{ "x-api-key" = $ApiKey }

    # 1. Fetch existing projects for validation
    $existingProjects = $null
    try {
        $projectsUrl = "$BaseUrl/api/Context/projects"
        $existingProjects = Invoke-RestMethod -Uri $projectsUrl -Headers $listHeaders -Method Get
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
            $ProjectName = Read-Host "`nEnter project name"
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

    # 3. Loop until a valid LocalFile is provided
    while ($true) {
        # Prompt for input if the variable is currently empty.
        # This allows passing the parameter directly or entering it interactively.
        if ([string]::IsNullOrWhiteSpace($LocalFile)) {
            $LocalFile = Read-Host "`nEnter local file path to upload"
        }

        # After getting input, check if the file exists.
        if (Test-Path $LocalFile -PathType Leaf) {
            break # File found, exit the loop.
        }
        else {
            # If the file doesn't exist, show an error and clear the variable
            # to ensure the user is prompted again in the next loop iteration.
            Write-Host "❌ Error: File not found at '$LocalFile'. Please provide a valid path." -ForegroundColor Red
            $LocalFile = $null
        }
    }
    # 4. Determine Remote Path
    if ([string]::IsNullOrWhiteSpace($RemotePath)) {
        $filename = Split-Path $LocalFile -Leaf
        Write-Host "`nDefault remote path: $filename" -ForegroundColor Yellow
        $userInput = Read-Host "Enter remote path (press Enter to use default)"

        if ([string]::IsNullOrWhiteSpace($userInput)) {
            $RemotePath = $filename
        } else {
            $RemotePath = $userInput
        }
    }

    # 5. Safety Check for file extension
    $RestrictedExtensions = @(".config", ".exe", ".dll", ".bin", ".msi", ".php", ".jsp", ".asp", ".aspx", ".sh", ".bat")
    $currentExtension = [System.IO.Path]::GetExtension($RemotePath)

    if ($RestrictedExtensions -contains $currentExtension.ToLower()) {
        $RemotePath = "$RemotePath.txt"
        Write-Host "Safety Note: Renamed restricted file to '$RemotePath' for secure storage." -ForegroundColor Yellow
    }

    $url = "$BaseUrl/api/Context/upload"
    Write-Host "Uploading to: $ProjectName/$RemotePath..." -ForegroundColor Cyan

    $client = $null
    $fileStream = $null
    try {
        $client = New-Object System.Net.Http.HttpClient
        $client.DefaultRequestHeaders.Add("x-api-key", $ApiKey)

        $content = New-Object System.Net.Http.MultipartFormDataContent

        $fileStream = [System.IO.File]::OpenRead((Resolve-Path $LocalFile))
        $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
        $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/octet-stream")

        $content.Add([System.Net.Http.StringContent]::new($ProjectName), "projectName")
        $content.Add([System.Net.Http.StringContent]::new($RemotePath), "filePath")
        $content.Add($fileContent, "file", (Split-Path $LocalFile -Leaf))

        $response = $client.PostAsync($url, $content).Result

        if ($response.IsSuccessStatusCode) {
            $responseBody = $response.Content.ReadAsStringAsync().Result
            Write-Host "✅ File uploaded successfully!" -ForegroundColor Green
            $responseBody | ConvertFrom-Json | ConvertTo-Json
        } else {
            $errorBody = $response.Content.ReadAsStringAsync().Result
            # Throw a detailed error message for the outer catch
            throw "Failed to upload file. StatusCode: $($response.StatusCode). Details: $errorBody"
        }
    } finally {
        # Ensure disposable resources are always cleaned up
        if ($fileStream -ne $null) { $fileStream.Dispose() }
        if ($client -ne $null) { $client.Dispose() }
    }

} catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
