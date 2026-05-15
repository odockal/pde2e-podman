#!/bin/bash

targetFolder=""
resultsFolder="results"
version=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --targetFolder) targetFolder="$2"; shift ;;
        --resultsFolder) resultsFolder="$2"; shift ;;
        --version) version="$2"; shift ;;
        --downloadUrl) shift ;; # accepted for compatibility, ignored on RHEL
        *) ;;
    esac
    shift
done

echo "Podman desktop E2E Podman script is being run on RHEL..."

if [ -z "$targetFolder" ]; then
    echo "Error: targetFolder is required"
    exit 1
fi

echo "Switching to a target folder: $targetFolder"
cd "$targetFolder" || exit
echo "Create a resultsFolder in targetFolder: $resultsFolder"
mkdir -p "$resultsFolder"
workingDir=$(pwd)
echo "Working location: $workingDir"

# Output file for podman path
outputFile="podman-location.log"

# Get Podman
if ! command -v podman &> /dev/null; then
    echo "Podman not found, installing via dnf..."
    sudo dnf install -y podman
elif [[ "$version" == "latest" ]]; then
    echo "Podman is already installed, upgrading to latest version..."
    sudo dnf upgrade -y podman
else
    echo "Podman is already installed, skipping upgrade"
fi

podmanPath=$(dirname "$(which podman)")
echo "Podman location: $podmanPath"
which podman
podman -v
echo "Podman installation path $podmanPath will be stored in $outputFile"
echo "$podmanPath" > "$workingDir/$resultsFolder/$outputFile"

echo "Script finished..."
