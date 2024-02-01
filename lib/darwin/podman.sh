#!/bin/bash

downloadUrl="https://api.cirrus-ci.com/v1/artifact/github/containers/podman/Artifacts/binary/podman-remote-release-darwin_arm64.zip"
targetFolder=""
resultsFolder="results"
version="5.0.0-dev"
initialize=0
start=0
rootful=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --downloadUrl) downloadUrl="$2"; shift ;;
        --targetFolder) targetFolder="$2"; shift ;;
        --resultsFolder) resultsFolder="$2"; shift ;;
        --version) version="$2"; shift ;;
        --initialize) initialize="$2"; shift ;;
        --start) start="$2"; shift ;;
        --rootful) rootful="$2"; shift ;;
        *) ;;
    esac
    shift
done

Download_PD() {
    echo "Downloading Podman Desktop from $pdUrl"
    curl -L "$pdUrl" -o pd.exe
}


echo "Podman desktop E2E Podman script is being run..."

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

# Specify the user profile directory
userProfile="$HOME"

# Specify the shared tools directory
toolsInstallDir="$userProfile/tools"

# Output file for built podman desktop binary
outputFile="podman-location.log"

# Create the tools directory if it doesn't exist
if [ ! -d "$toolsInstallDir" ]; then
    echo "Creating dir: $toolsInstallDir"
    mkdir -p "$toolsInstallDir"
fi

# Get Podman
# Check if podman command exists
if ! command -v podman &> /dev/null; then
    # Download and install the Podman release
    podman_folder="podman-$version"
    echo "Downloading podman archive from $downloadUrl"
    if [ ! -d "$toolsInstallDir/$podman_folder" ]; then
        curl -o "$toolsInstallDir/podman.zip" -L "$downloadUrl"
        unzip -o "$toolsInstallDir/podman.zip" -d "$toolsInstallDir"
    else
        echo "Podman installation in $toolsInstallDir/$podman_folder already exists"
    fi
    podman_path="$toolsInstallDir/$podman_folder/usr/bin"
    echo "Adding Podman location: $podman_path, to the PATH"
    export PATH="$podman_path:$PATH"
    # store the podman installation path to be exported out of a container
    echo "Podman installation path will be stored in $outputFile"
    echo "$podman_path" > "$workingDir/$resultsFolder/$outputFile"
fi


# Configure Podman Machine
if (( initialize == 1 )); then
    flags=""
    if (( rootful == 1 )); then
        flags+="--rootful "
    fi
    if (( userNetworking == 1 )); then
        flags+="--user-mode-networking "
    fi
    flags=$(echo "$flags" | awk '{$1=$1};1')
    flagsArray=($flags)
    echo "Initializing podman machine, command: podman machine init $flags"
    logFile="$workingDir/$resultsFolder/podman-machine-init.log"
    echo "podman machine init $flags" > "$logFile"
    if (( ${#flagsArray[@]} > 0 )); then
        podman machine init "${flagsArray[@]}" >> "$logFile"
    else
        podman machine init >> "$logFile"
    fi
    if (( start == 1 )); then
        echo "Starting podman machine..."
        echo "podman machine start" >> "$logfile"
        podman machine start >> "$logFile"
    fi
    podman machine ls >> "$logFile"
fi

echo "Script finished..."
