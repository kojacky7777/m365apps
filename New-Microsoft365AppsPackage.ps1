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
    [switch]$SkipImport  # игнорируется, оставлено для совместимости с YAML
)

# -----------------------------
# Вспомогательные функции
# -----------------------------

function Write-Msg($msg) {
    $ts = (Get-Date).ToString("dd.MM.yyyy HH:mm:ss")
    Write-Host "[$ts] $msg"
}

function Ensure-Directory($path) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}

# -----------------------------
# Начало работы
# -----------------------------

Write-Msg "Starting local Microsoft 365 Apps package build."

# Проверка путей
if (-not (Test-Path $Path)) {
    throw "Path not found: $Path"
}

if (-not (Test-Path $ConfigurationFile)) {
    throw "Configuration file not found: $ConfigurationFile"
}

# Создаём структуру
$packageRoot = Join-Path $Path "package"
$source = Join-Path $packageRoot "source"
$output = Join-Path $packageRoot "output"

Write-Msg "Creating package structure."
Ensure-Directory $packageRoot
Ensure-Directory $source
Ensure-Directory $output

# Копируем setup.exe
Write-Msg "Copying setup.exe"
Copy-Item -Path "$Path\m365\setup.exe" -Destination "$source\setup.exe" -Force

# Копируем конфиги
Write-Msg "Copying configuration files"
Copy-Item -Path $ConfigurationFile -Destination "$source\Install-Microsoft365Apps.xml" -Force
Copy-Item -Path "$Path\configs\Uninstall-Microsoft365Apps.xml" -Destination "$source\Uninstall-Microsoft365Apps.xml" -Force

# Обновляем XML (без TenantId)
Write-Msg "Updating XML configuration"
[xml]$xml = Get-Content "$source\Install-Microsoft365Apps.xml"

$xml.Configuration.Add.Channel = $Channel
$xml.Configuration.AppSettings.Setup.Value = $CompanyName

$xml.Save("$source\Install-Microsoft365Apps.xml")

# Копируем PSADT при необходимости
if ($UsePsadt) {
    Write-Msg "Copying PSADT files"
    Ensure-Directory "$source\SupportFiles"
    Copy-Item -Path "$Path\scrub\*" -Destination "$source\SupportFiles" -Recurse -Force
    Copy-Item -Path "$Path\scripts\Invoke-AppDeployToolkit.ps1" -Destination "$source\Invoke-AppDeployToolkit.ps1" -Force
}

# Создаём ZIP‑пакет
Write-Msg "Creating ZIP package"
$zipPath = Join-Path $output "m365apps.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $source\* -DestinationPath $zipPath

Write-Msg "Package created successfully:"
Write-Msg $zipPath

Write-Msg "Done."
