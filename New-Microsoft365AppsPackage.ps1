[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$ConfigurationFile,

    [Parameter(Mandatory = $true)]
    [string]$Channel,

    [Parameter(Mandatory = $true)]
    [string]$CompanyName,

    [Parameter(Mandatory = $false)]
    [switch]$UsePsadt,

    [Parameter(Mandatory = $false)]
    [switch]$SkipImport
)

function Write-Msg {
    param([string]$Message)
    $ts = (Get-Date).ToString("dd.MM.yyyy HH:mm:ss")
    Write-Host "[$ts] $Message"
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

Write-Msg "Starting local Microsoft 365 Apps package build."

# Validate paths
if (-not (Test-Path $Path)) { throw "Path not found: $Path" }
if (-not (Test-Path $ConfigurationFile)) { throw "Configuration file not found: $ConfigurationFile" }

# Create structure
$packageRoot = Join-Path $Path "package"
$source = Join-Path $packageRoot "source"
$output = Join-Path $packageRoot "output"

Write-Msg "Creating package structure."
Ensure-Directory $packageRoot
Ensure-Directory $source
Ensure-Directory $output

# Copy setup.exe
Write-Msg "Copying setup.exe"
Copy-Item -Path "$Path\m365\setup.exe" -Destination "$source\setup.exe" -Force

# Copy configuration files
Write-Msg "Copying configuration files"
Copy-Item -Path $ConfigurationFile -Destination "$source\Install-Microsoft365Apps.xml" -Force
Copy-Item -Path "$Path\configs\Uninstall-Microsoft365Apps.xml" -Destination "$source\Uninstall-Microsoft365Apps.xml" -Force

# Update XML (only Channel)
Write-Msg "Updating XML configuration"
[xml]$xml = Get-Content "$source\Install-Microsoft365Apps.xml"

if ($xml.Configuration.Add.Channel) {
    $xml.Configuration.Add.Channel = $Channel
    Write-Msg "Channel updated to $Channel"
} else {
    Write-Msg "Channel element not found — skipping"
}

$xml.Save("$source\Install-Microsoft365Apps.xml")

# Copy PSADT if needed
if ($UsePsadt) {
    Write-Msg "Copying PSADT files"
    Ensure-Directory "$source\SupportFiles"
    Copy-Item -Path "$Path\scrub\*" -Destination "$source\SupportFiles" -Recurse -Force
    Copy-Item -Path "$Path\scripts\Invoke-AppDeployToolkit.ps1" -Destination "$source\Invoke-AppDeployToolkit.ps1" -Force
}

# Create ZIP package
Write-Msg "Creating ZIP package"
$zipPath = Join-Path $output "m365apps.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$source\*" -DestinationPath $zipPath

Write-Msg "Package created successfully:"
Write-Msg $zipPath

Write-Msg "Done."
