#!/bin/bash

declare -a script_env_vars

downloadUrl="https://api.cirrus-ci.com/v1/artifact/github/containers/podman/Artifacts/binary/podman-remote-release-darwin_arm64.zip"
version="5.2.0-dev"
targetFolder=""
resultsFolder="results"
initialize=0
start=0
rootful=0
podmanProvider=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --downloadUrl) downloadUrl="$2"; shift ;;
        --targetFolder) targetFolder="$2"; shift ;;
        --resultsFolder) resultsFolder="$2"; shift ;;
        --version) version="$2"; shift ;;
        --initialize) initialize="$2"; shift ;;
        --start) start="$2"; shift ;;
        --rootful) rootful="$2"; shift ;;
        --podmanProvider) podmanProvider="$2"; shift ;;
        *) ;;
    esac
    shift
done

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

# check if we have explicit podman provider env. var. added
if [ -n "$podmanProvider" ]; then
    echo "Settings CONTAINERS_MACHINE_PROVIDER: $podmanProvider"
    export CONTAINERS_MACHINE_PROVIDER=$podmanProvider
    script_env_vars+=("CONTAINERS_MACHINE_PROVIDER")
fi

# Get Podman
# Check if podman command exists
if ! command -v podman &> /dev/null; then
    # Download and install Podman
    # Archive zip only contains podman client, not a qemu binary
    echo "Downloading podman archive from $downloadUrl"
    curl -o "$toolsInstallDir/podman-archive" -L $downloadUrl
    podmanPath=''
    fileType=$(file -b --mime-type "$toolsInstallDir/podman-archive")
    echo "Archive file type is: $fileType"
    if [ $fileType == "application/zip" ]; then
        if [ -d "$toolsInstallDir/podman" ]; then
            rm -rf "$toolsInstallDir/podman"
        fi
        mkdir -p $toolsInstallDir/podman
        mv $toolsInstallDir/podman-archive $toolsInstallDir/podman.zip
        unzip -o "$toolsInstallDir/podman.zip" -d "$toolsInstallDir/podman"
        podmanFolder=$(ls $toolsInstallDir/podman)
        podmanPath="$toolsInstallDir/podman/$podmanFolder/usr/bin"
    elif [ $fileType == "application/x-xar" ]; then
        # use pkg installer
        mv $toolsInstallDir/podman-archive $toolsInstallDir/podman.pkg
        sudo installer -pkg $toolsInstallDir/podman.pkg -target /opt
        podmanPath=/opt/podman/bin
    else
        echo "The file type is neither ZIP or PKG, exiting"
        exit 1
    fi
    if [ -e $podmanPath ]; then
        echo "Adding Podman location: $podmanPath, to the PATH"
        export PATH="$podmanPath:$PATH"
        # store the podman installation path to be exported out of a container
        echo "Podman installation path $podmanPath will be stored in $outputFile"
        echo "$podmanPath" > "$workingDir/$resultsFolder/$outputFile"
    fi
    # test podman on the PATH and do not throw error
    which podman
    podman version
else
    echo "Podman is already installed on the system"
    which podman
    podman version
fi


# Configure Podman Machine
if (( initialize == 1 )); then
    flags=""
    if (( rootful == 1 )); then
        flags+="--rootful "
    fi
    flags=$(echo "$flags" | awk '{$1=$1};1')
    flagsArray=($flags)
    echo "Initializing podman machine, command: podman machine init $flags"
    logFile="$workingDir/$resultsFolder/podman-machine-init.log"
    echo "podman machine init $flags" > "$logFile"
    if (( ${#flagsArray[@]} > 0 )); then
        podman machine init "${flagsArray[@]}" 2>&1 | tee -a "$logFile"
    else
        podman machine init 2>&1 | tee -a "$logFile"
    fi
    if (( start == 1 )); then
        echo "Starting podman machine..."
        echo "podman machine start" >> "$logFile"
        podman machine start 2>&1 | tee -a "$logFile"
    fi
    podman machine ls 2>&1 | tee -a "$logFile"
fi

echo "Script finished..."
