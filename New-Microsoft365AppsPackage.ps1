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

function Log {
    param([string]$Text)
    $ts = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
    Write-Host "[" + $ts + "] " + $Text
}

function EnsureDir {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) {
        New-Item -Path $Dir -ItemType Directory -Force | Out-Null
    }
}

Log "Starting build"

if (-not (Test-Path $Path)) { throw "Path not found: $Path" }
if (-not (Test-Path $ConfigurationFile)) { throw "Config not found: $ConfigurationFile" }

$packageRoot = Join-Path $Path "package"
$source = Join-Path $packageRoot "source"
$output = Join-Path $packageRoot "output"

EnsureDir $packageRoot
EnsureDir $source
EnsureDir $output

Log "Copying setup.exe"
Copy-Item "$Path\m365\setup.exe" "$source\setup.exe" -Force

Log "Copying XML"
Copy-Item $ConfigurationFile "$source\Install-Microsoft365Apps.xml" -Force
Copy-Item "$Path\configs\Uninstall-Microsoft365Apps.xml" "$source\Uninstall-Microsoft365Apps.xml" -Force

Log "Updating XML"
[xml]$xml = Get-Content "$source\Install-Microsoft365Apps.xml"

if ($xml.Configuration.Add.Channel) {
    $xml.Configuration.Add.Channel = $Channel
}

$xml.Save("$source\Install-Microsoft365Apps.xml")

if ($UsePsadt) {
    Log "Copying PSADT"
    EnsureDir "$source\SupportFiles"
    Copy-Item "$Path\scrub\*" "$source\SupportFiles" -Recurse -Force
    Copy-Item "$Path\scripts\Invoke-AppDeployToolkit.ps1" "$source\Invoke-AppDeployToolkit.ps1" -Force
}

# NEW: copy XML to output so YAML can find it
Copy-Item "$source\Install-Microsoft365Apps.xml" "$output\Install-Microsoft365Apps.xml" -Force

Log "Creating ZIP"
$zip = Join-Path $output "m365apps.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path "$source\*" -DestinationPath $zip

Log "Package ready"
Log $zip

Log "Build complete"
