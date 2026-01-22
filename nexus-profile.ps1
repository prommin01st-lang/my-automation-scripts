# Nexus Profile Setup
# Usage: Dot-source this file in your PowerShell Profile: . "path/to/nexus-profile.ps1"
# Or copy the contents directly to your profile.

$repoBase = "https://raw.githubusercontent.com/prommin01st-lang/my-automation-scripts/main"

Write-Host "Loading Context Nexus Cloud Tools from: $repoBase" -ForegroundColor Cyan

function nx-create-project {
    <#
    .SYNOPSIS
        Creates a new project in Context Nexus.
    #>
    [CmdletBinding()]
    param()
    $scriptUrl = "$repoBase/create-project.ps1"
    Write-Host "Executing from: $scriptUrl" -ForegroundColor DarkGray
    $script = Invoke-RestMethod -Uri $scriptUrl
    & ([scriptblock]::Create($script)) @args
}

function nx-upload-file {
    <#
    .SYNOPSIS
        Uploads a file to a project.
    #>
    [CmdletBinding()]
    param()
    $scriptUrl = "$repoBase/upload-file.ps1"
    Write-Host "Executing from: $scriptUrl" -ForegroundColor DarkGray
    $script = Invoke-RestMethod -Uri $scriptUrl
    & ([scriptblock]::Create($script)) @args
}

function nx-upload-content {
    <#
    .SYNOPSIS
        Uploads text content directly.
    #>
    [CmdletBinding()]
    param()
    $scriptUrl = "$repoBase/upload-content.ps1"
    Write-Host "Executing from: $scriptUrl" -ForegroundColor DarkGray
    $script = Invoke-RestMethod -Uri $scriptUrl
    & ([scriptblock]::Create($script)) @args
}

function nx-list-projects {
    <#
    .SYNOPSIS
        Lists all available projects.
    #>
    [CmdletBinding()]
    param()
    $scriptUrl = "$repoBase/list-projects.ps1"
    Write-Host "Executing from: $scriptUrl" -ForegroundColor DarkGray
    $script = Invoke-RestMethod -Uri $scriptUrl
    & ([scriptblock]::Create($script)) @args
}

function nx-list-files {
    <#
    .SYNOPSIS
        Lists files within a project.
    #>
    [CmdletBinding()]
    param()
    $scriptUrl = "$repoBase/list-files.ps1"
    Write-Host "Executing from: $scriptUrl" -ForegroundColor DarkGray
    $script = Invoke-RestMethod -Uri $scriptUrl
    & ([scriptblock]::Create($script)) @args
}

function nx-download-context {
    <#
    .SYNOPSIS
        Downloads project context to a local file.
    #>
    [CmdletBinding()]
    param()
    $scriptUrl = "$repoBase/download-context.ps1"
    Write-Host "Executing from: $scriptUrl" -ForegroundColor DarkGray
    $script = Invoke-RestMethod -Uri $scriptUrl
    & ([scriptblock]::Create($script)) @args
}

function nx-delete-content {
    <#
    .SYNOPSIS
        Deletes a specific file from a project.
    #>
    [CmdletBinding()]
    param()
    $scriptUrl = "$repoBase/delete-content.ps1"
    Write-Host "Executing from: $scriptUrl" -ForegroundColor DarkGray
    $script = Invoke-RestMethod -Uri $scriptUrl
    & ([scriptblock]::Create($script)) @args
}

function nx-delete-project {
    <#
    .SYNOPSIS
        Deletes an entire project and its resources.
    #>
    [CmdletBinding()]
    param()
    $scriptUrl = "$repoBase/delete-project.ps1"
    Write-Host "Executing from: $scriptUrl" -ForegroundColor DarkGray
    $script = Invoke-RestMethod -Uri $scriptUrl
    & ([scriptblock]::Create($script)) @args
}

function nx-overview {
    <#
    .SYNOPSIS
        Gets a system overview of projects and file counts.
    #>
    [CmdletBinding()]
    param()
    $scriptUrl = "$repoBase/get-overview.ps1"
    Write-Host "Executing from: $scriptUrl" -ForegroundColor DarkGray
    $script = Invoke-RestMethod -Uri $scriptUrl
    & ([scriptblock]::Create($script)) @args
}

Write-Host "Nexus Tools Loaded! Available commands:" -ForegroundColor Green
Write-Host "  nx-create-project"
Write-Host "  nx-upload-file"
Write-Host "  nx-upload-content"
Write-Host "  nx-list-projects"
Write-Host "  nx-list-files"
Write-Host "  nx-download-context"
Write-Host "  nx-delete-content"
Write-Host "  nx-delete-project"
Write-Host "  nx-overview"
