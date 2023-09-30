param(
    [Parameter(HelpMessage = 'Podman Download URL')]
    [string]$downloadUrl = "https://api.cirrus-ci.com/v1/artifact/github/containers/podman/Artifacts/binary/podman-remote-release-windows_amd64.zip",
    [Parameter(HelpMessage = 'Podman version')]
    [string]$version = "4.8.0-dev"
)

# Function to check if a command is available
function Command-Exists($command) {
    $null = Get-Command -Name $command -ErrorAction SilentlyContinue
    return $?
}

Write-Host "Podman desktop E2E podman script is being run..."

# Specify the user profile directory
$userProfile = $env:USERPROFILE

# Specify the shared tools directory
$toolsInstallDir = Join-Path $userProfile 'tools'

# Create the tools directory if it doesn't exist
if (-not (Test-Path -Path $toolsInstallDir -PathType Container)) {
    New-Item -Path $toolsInstallDir -ItemType Directory
}

# Force install of WSL
wsl -l -v
$installed=$?

if (!$installed) {
    Write-Host "installing wsl2"
    wsl --install --no-distribution
    wsl --set-default-version 2
    $distroMissing=$?
    if($distroMissing) {
        write-host "Wsl enabled, but distro missing"
        wsl --install --no-launch
    }
}

if (-not (Command-Exists "podman")) {
    # Download and install the nightly podman for windows
    $podmanFolder="podman-remote-release-windows_amd64"
    write-host "Downloading podman archive from $downloadUrl"
    Invoke-WebRequest -Uri $downloadUrl -OutFile "$toolsInstallDir\podman-nightly.zip"
    if (-not (Test-Path -Path "$toolsInstallDir\podman-nightly" -PathType Container)) {
        Expand-Archive -Path "$toolsInstallDir\podman-nightly.zip" -DestinationPath $toolsInstallDir -Force
    }
    $env:Path += ";$toolsInstallDir\podman-$version\usr\bin"
}

# Setup podman machine in the host system
podman machine init --rootful true
podman machine start
podman machine ls

write-host "Script finished..."
