param(
    [Parameter(HelpMessage='folder on target host where assets are copied')]
    $targetFolder,
    [Parameter(HelpMessage='Results folder')]
    $resultsFolder="results",
    [Parameter(HelpMessage = 'Podman Download URL')]
    $downloadUrl='https://api.cirrus-ci.com/v1/artifact/github/containers/podman/Artifacts/binary/podman-remote-release-windows_amd64.zip',
    [Parameter(HelpMessage = 'Initialize podman machine, default is 0/false')]
    $initialize='0',
    [Parameter(HelpMessage = 'Start Podman machine, default is 0/false')]
    $start='0',
    [Parameter(HelpMessage = 'Podman machine rootful flag, default 0/false')]
    $rootful='0',
    [Parameter(HelpMessage = 'Podman machine user-mode-networking flag, default 0/false')]
    $userNetworking='0',
    [Parameter(HelpMessage = 'Install WSL, default 0/false')]
    $installWSL='0',
    [Parameter(HelpMessage = 'Run smoke test for podman machine 0/false')]
    $smokeTests='0',
    [Parameter(HelpMessage = 'Environmental variable to define custom podman Provider')]
    [string]$podmanProvider=''
)

write-host "Print out script parameters, usefull for debugging..."
$ParametersList = (Get-Command -Name $MyInvocation.InvocationName).Parameters;
foreach ($key in $ParameterList.keys) {
    $variable = Get-Variable -Name $key -ErrorAction SilentlyContinue;
    if($variable) {
        write-host "$($variable.name) > $($variable.value)"
    }
}

# Function to check if a command is available
function Command-Exists($command) {
    $null = Get-Command -Name $command -ErrorAction SilentlyContinue
    return $?
}

function Invoke-Admin-Command {
    param (
        [string]$Command,            # Command to run (e.g., "pnpm install")
        [string]$WorkingDirectory,   # Working directory where the command should be executed
        [string]$TargetFolder,       # Target directory for storing the output/log files
        [string]$EnvVarName="",      # Environment variable name (optional)
        [string]$EnvVarValue="",     # Environment variable value (optional)
        [string]$Privileged='0',     # Whether to run command with admin rights, defaults to user mode,
        [string]$SetSecrets='0',     # Whether to process secret file and load it as env. vars., only in privileged mode,
        [int]$WaitTimeout=300,     # Default WaitTimeout 300 s, defines the timeout to wait for command execute
        [bool]$WaitForCommand=$true  # Wait for command execution indefinitely, default true, use timeout otherwise
    )

    cd $WorkingDirectory
    # Define file paths to capture output and error
    $outputFile = Join-Path -Path $WorkingDirectory -ChildPath "tmp_stdout_$([System.Datetime]::Now.ToString("yyyymmdd_HHmmss")).txt"
    $errorFile = Join-Path -Path $WorkingDirectory -ChildPath "tmp_stderr_$([System.Datetime]::Now.ToString("yyyymmdd_HHmmss")).txt"
    $tempScriptFile = Join-Path -Path $WorkingDirectory -ChildPath "tmp_script_$([System.Datetime]::Now.ToString("yyyymmdd_HHmmss")).ps1"

    # We need to create a local tmp script in order to execute it with admin rights with a Start-Process
    # We also want a access to the stdout and stderr which is not possible otherwise
    if ($Privileged -eq "1") {
        # Create the temporary script content
        $scriptContent = @"
# Change to the working directory
Set-Location -Path '$WorkingDirectory'

"@
        # If the environment variable name and value are provided, add to script
        if (![string]::IsNullOrWhiteSpace($EnvVarName) -and ![string]::IsNullOrWhiteSpace($EnvVarValue)) {
            $scriptContent += @"
# Set the environment variable
Set-Item -Path Env:\$EnvVarName -Value '$EnvVarValue'
"@
        }
        
        # If we have a set of env. vars. provided, add this code to script
        if (![string]::IsNullOrWhiteSpace($global:envVarDefs)) {
            Write-Host "Parsing Global Input env. vars in inline script: '$global:envVarDefs'"
            foreach ($definition in $global:envVarDefs) {
                # Split each variable definition
                Write-Host "Processing $definition"
                $parts = $definition -split '=', 2

                # Check if the variable assignment is in VAR=Value format
                if ($parts.Count -eq 2) {
                    $name = $parts[0].Trim()
                    $value = $parts[1].Trim('"')

                    # Set and test the environment variable
                    $scriptContent += @"
# Set the environment variable from array
Set-Item -Path Env:\$name -Value '$value'

"@
                } else {
                    Write-Host "Invalid variable assignment: $definition"
                }
            }
        }

        # Add secrets handling into tmp script
        if ($SetSecrets -eq "1") {
            Write-Host "SetSecrets flag is set"
            if ($secretFile) {
                Write-Host "SecretFile is defined and found..."
$scriptContent += @"
`$secretFilePath="$resourcesPath\$secretFile"
if (Test-Path `$secretFilePath) {
    `$properties = Get-Content `$secretFilePath | ForEach-Object {
        # Ignore comments and empty lines
        if (-not `$_.StartsWith("#") -and -not [string]::IsNullOrWhiteSpace(`$_)) {
            # Split each line into key-value pairs
            `$key, `$value = `$_ -split '=', 2

            # Trim leading and trailing whitespaces
            `$key = `$key.Trim()
            `$value = `$value.Trim()

            # Set the environment variable
            Set-Item -Path "env:`$key" -Value `$value
        }
    }
    Write-Host "Secrets loaded from '`$secretFilePath' and set as environment variables."
} else {
    Write-Host "File '`$secretFilePath' not found."
}

"@
            }
        }

        # Add the command execution to the script
        $scriptContent += @"
# Run the command and redirect stdout and stderr
# Try running the command and capture errors
try {
    'Executing Command: $Command' | Out-File '$outputFile' -Append
    $Command >> '$outputFile' 2>> '$errorFile'
    'Command executed successfully.' | Out-File '$outputFile' -Append
} catch {
    'Error occurred while executing command: ' + `$_.Exception.Message | Out-File '$errorFile' -Append
}

"@
        # Write the script content to the temporary script file
        write-host "Creating a content of the script:"
        write-host "$scriptContent"
        write-host "Storing at: $tempScriptFile"
        $scriptContent | Set-Content -Path $tempScriptFile

        # Start the process as admin and run the temporary script file
        $process = Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy Bypass", "-File", $tempScriptFile -Verb RunAs -PassThru
        $waitResult = $null
        if ($WaitForCommand) {
            write-host "Starting process with script awaiting until it is finished..."
            $waitResult = $process.WaitForExit()
        } else {
            write-host "Starting process with script awaiting for $WaitTimeout sec"
            $waitResult = $process.WaitForExit($WaitTimeout * 1000)
        }
        Write-Host "Process ID: $($process.Id)"
        if ($waitResult) {
            Write-Host "Process completed waiting successfully."
        } else {
            Write-Host "Process failed waiting after with exit code: $($process.ExitCode)"
        }

    } else {
        cd $WorkingDirectory
        # Run the command normally without elevated privileges
        if (![string]::IsNullOrWhiteSpace($EnvVarName) -and ![string]::IsNullOrWhiteSpace($EnvVarValue)) {
            "Settings Env. Var.: $EnvVarName = $EnvVarValue" | Out-File $outputFile -Append
            Set-Item -Path Env:\$EnvVarName -Value $EnvVarValue
        }
        Set-Location -Path '$WorkingDirectory'
        "Running the command: '$Command' in non privileged mode" | Out-File $outputFile -Append
        $output = Invoke-Expression $Command >> $outputFile 2>> $errorFile
    }

    # Copying logs and scripts back to the target folder (to get preserved and copied to the host)
    cp $tempScriptFile $TargetFolder
    cp $outputFile $TargetFolder
    cp $errorFile $TargetFolder

    # After the process finishes, read the output and error from the files
    if (Test-Path $outputFile) {
        Write-Output "Standard Output: $(Get-Content -Path $outputFile)"
    } else {
        Write-Output "No standard output..."
    }

    if (Test-Path $errorFile) {
        Write-Output "Standard Error: $(Get-Content -Path $errorFile)"
    } else {
        Write-Output "No standard error..."
    }
}


Write-Host "Podman desktop E2E - podman nightly install script is being run..."

write-host "Switching to a target folder: " $targetFolder
cd $targetFolder
write-host "Create a resultsFolder in targetFolder: $resultsFolder"
mkdir -p $resultsFolder
$workingDir=Get-Location
write-host "Working location: " $workingDir
$targetLocation="$workingDir\$resultsFolder"
write-host "Target Location: $targetLocation"

# Specify the user profile directory
$userProfile = $env:USERPROFILE

# Specify the shared tools directory
$toolsInstallDir = Join-Path $userProfile 'tools'
if (-not(Test-Path -Path $toolsInstallDir)) {
    write-host "Tools directory does not exists, creating..."
    mkdir -p $toolsInstallDir
}

# define targetLocationTmpScp for temporary script files
$targetLocationTmpScp="$targetLocation\scripts"
New-Item -ErrorAction Ignore -ItemType directory -Path $targetLocationTmpScp

# Output file for built podman desktop binary
$outputFile = "podman-location.log"

# Force install of WSL
if ($installWSL -eq "1") {
    wsl -l -v
    $installed=$?

    if (!$installed) {
        Write-Host "installing wsl2"
        wsl --set-default-version 2
        wsl --install --no-distribution
        $distroMissing=$?
        if($distroMissing) {
            write-host "Wsl enabled, but distro is missing, installing default distro..."
            wsl --install --no-launch
        }
    }
}

if (-not (Command-Exists "podman")) {
    write-host "Podman is not installed, installing..."
    # Download and install the (nightly) podman for windows
    # Installation of the zip podman achive
    $extension = [IO.Path]::GetExtension($downloadUrl)
    $podmanProgramFiles="$env:ProgramFiles\RedHat\Podman\"
    $podmanPath=""
    if ($extension -eq '.zip') {
        $podmanFolder="podman-remote-release-windows_amd64"
        write-host "Downloading podman archive from $downloadUrl"
        if (-not (Test-Path -Path "$toolsInstallDir\podman" -PathType Container)) {
            Invoke-WebRequest -Uri $downloadUrl -OutFile "$toolsInstallDir\podman.zip"
            mkdir -p "$toolsInstallDir\podman"
            Expand-Archive -Path "$toolsInstallDir\podman.zip" -DestinationPath "$toolsInstallDir\podman" -Force
        }
        # we need to find out the folder name extracted from archive, could be podman-5.1.0 or podman-5.2.0-dev
        $podmanFolderName=ls "$toolsInstallDir\podman" -Name
        write-host "Extracted Podman Installation folder found: $podmanFolderName"
        $podmanPath="$toolsInstallDir\podman\$podmanFolderName\usr\bin"
        # To use gvproxy from achived installation, Path solution does not exist
        # See , set the helper_binaries_dir key in the `[engine]` section of containers.conf
        # We need to either use podman_helper_dir or place binaries at "C:\Program Files\RedHat\Podman\"
        # For now only for hyperv
        if (-not [string]::IsNullOrWhiteSpace($podmanProvider) -and $podmanProvider -eq "hyperv") {
            if (-not (Test-Path -Path $podmanProgramFiles)) {
                write-host "Copying podman binary helper files into program files..."
                $command="New-Item -ItemType Directory -Path '$podmanProgramFiles'"
                #Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy Bypass", "-Command $command" -Verb RunAs -Wait
                Invoke-Admin-Command -Command $command -WorkingDirectory $(pwd) -Privileged "1" -TargetFolder $targetLocationTmpScp
                $commandCopy="Copy-Item -Path '$podmanPath\*' -Destination '$podmanProgramFiles'"
                #Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy Bypass", "-Command $commandCopy" -Verb RunAs -Wait
                Invoke-Admin-Command -Command $commandCopy -WorkingDirectory $(pwd) -Privileged "1" -TargetFolder $targetLocationTmpScp
            }
        }
    } elseif ($extension -eq '.exe') {
        write-host "Downloading podman setup.exe from $downloadUrl"
        Invoke-WebRequest -Uri $downloadUrl -OutFile "$toolsInstallDir\podman.exe"
        # Install the setup.exe
        write-host "Install Podman from setup.exe silently.."
        $process = Start-Process -FilePath "$toolsInstallDir\podman.exe" -ArgumentList "/S" -PassThru -Wait
        write-host "Install process exit code: " $process.ExitCode
        if ($process.ExitCode -eq 1618) {
            write-host "Re-trying Podman installation later, another installation is in progress"
            Start-Sleep -Seconds 60
            $process = Start-Process -FilePath "$toolsInstallDir\podman.exe" -ArgumentList "/S" -PassThru -Wait
            write-host "Second install process exit code: " $process.ExitCode
        }
        # It seems that we need to put installed podman path on the system PATH in order for podman to be accessible in the session
        $podmanPath=$podmanProgramFiles
    }

    if (Test-Path -Path $podmanPath) {
        write-host "Adding Podman location: $podmanPath, on the User PATH"
        #[System.Environment]::SetEnvironmentVariable('PATH', ([System.Environment]::GetEnvironmentVariable('PATH', 'User') + $podmanPath) -join ';', 'User')
        $env:Path += ";$podmanPath"
        # Make the podman available for the every scope (by using Machine scope)
        write-host "Settings $podmanPath on PATH with Machine scope"
        $command="[Environment]::SetEnvironmentVariable('Path', (`$Env:Path + ';$podmanPath'), 'MACHINE')"
        Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy Bypass", "-Command $command" -Verb RunAs -Wait
        write-host "$([Environment]::GetEnvironmentVariable('Path', 'MACHINE'))"

        # store the podman installation
        cd "$workingDir\$resultsFolder"
        write-host "Podman installation path will be stored in $outputFile"
        "'$podmanPath'" | Out-File -FilePath $outputFile -NoNewline
    } else {
        Write-Host "The path $podmanPath does not exist, verify downloadUrl and version"
        Throw "Expected Podman Path: $podmanPath does not exist"
    }
} else {
    write-host "Podman is installed"
    podman -v
}

# Set custom podman provider (wsl vs. hyperv)
if (-not [string]::IsNullOrWhiteSpace($podmanProvider)) {
    Write-Host "Setting CONTAINERS_MACHINE_PROVIDER: '$podmanProvider'"
    Set-Item -Path "env:CONTAINERS_MACHINE_PROVIDER" -Value $podmanProvider
    $global:scriptEnvVars += "CONTAINERS_MACHINE_PROVIDER"
}

# If the provider is hyperv, we need to allow podman in defender's firewall
if (-not [string]::IsNullOrWhiteSpace($podmanProvider) -and $podmanProvider -eq "hyperv") {
    write-host "Enable podman (with hyperv) to send and receive requests through the firewall"
    $commandPath=$(get-command podman).Path
    $inbound="New-NetFirewallRule -DisplayName 'podman' -Direction Inbound -Program $commandPath -Action Allow -Profile Private"
    $outbound="New-NetFirewallRule -DisplayName 'podman' -Direction Outbound -Program $commandPath -Action Allow -Profile Private"
    Start-Process powershell -verb runas -ArgumentList $inbound -wait
    Start-Process powershell -verb runas -ArgumentList $outbound -wait
}
# Setup podman machine in the host system
if ($initialize -eq "1") {
    $thisDir=$(pwd)
    $flags = ""
    if ($rootful -eq "1") {
        $flags += "--rootful "
    }
    if ($userNetworking -eq "1") {
        $flags += "--user-mode-networking "
    }
    $flags = $flags.Trim()
    $flagsArray = $flags -split ' '
    write-host "Initializing podman machine, command: podman machine init $flags"
    $logFile = "$workingDir\$resultsFolder\podman-machine-init.log"
    "podman machine init $flags" > $logFile
    if($flags) {
        # If more flag will be necessary, we have to consider composing the command other way
        # ie. https://stackoverflow.com/questions/6604089/dynamically-generate-command-line-command-then-invoke-using-powershell
        if (-not [string]::IsNullOrWhiteSpace($podmanProvider) -and $podmanProvider -eq "hyperv") {
            Write-Host "Initialize HyperV podman machine with flags ..."
            Invoke-Admin-Command -Command "podman machine init $flags" -WorkingDirectory $thisDir -EnvVarName "CONTAINERS_MACHINE_PROVIDER" -EnvVarValue "hyperv" -Privileged "1" -TargetFolder $targetLocationTmpScp
        } else {
            podman machine init $flagsArray >> $logFile
        }
    } else {
        if (-not [string]::IsNullOrWhiteSpace($podmanProvider) -and $podmanProvider -eq "hyperv") {
            Write-Host "Initialize HyperV podman machine ..."
            Invoke-Admin-Command -Command "podman machine init" -WorkingDirectory $thisDir -EnvVarName "CONTAINERS_MACHINE_PROVIDER" -EnvVarValue "hyperv" -Privileged "1" -TargetFolder $targetLocationTmpScp
        } else {
            podman machine init >> $logFile
        }
    }
    if ($start -eq "1") {
        if (-not [string]::IsNullOrWhiteSpace($podmanProvider) -and $podmanProvider -eq "hyperv") {
            Write-Host "Starting HyperV Podman Machine ..."
            Invoke-Admin-Command -Command "podman machine start" -WorkingDirectory $thisDir -EnvVarName "CONTAINERS_MACHINE_PROVIDER" -EnvVarValue "hyperv" -Privileged "1" -TargetFolder $targetLocationTmpScp -WaitForCommand $false
        } else {
            write-host "Starting podman machine..."
            "podman machine start" >> $logFile
            podman machine start >> $logFile
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($podmanProvider) -and $podmanProvider -eq "hyperv") {
        Write-Host "List HyperV Podman Machine ..."
        Invoke-Admin-Command -Command "podman machine ls" -WorkingDirectory $thisDir -EnvVarName "CONTAINERS_MACHINE_PROVIDER" -EnvVarValue "hyperv" -Privileged "1" -TargetFolder $targetLocationTmpScp
    } else {
        podman machine ls >> $logFile
    }

    ## Podman Machine smoke tests
    # the tests expect podman machine to be up
    if ($smokeTests -eq "1") {
        $testsLogFile = "$workingDir\$resultsFolder\podman-machine-tests.log"
        # TODO: include basic tests for podman machine verification 
    }
}

write-host "Script finished..."
