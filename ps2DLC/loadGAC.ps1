# loadGAC.ps1


# Check if running as Administrator
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Warning "This script must be run as Administrator. Exiting..."
    exit 1
}


# Your script logic goes here
Write-Host "Running with Administrator privileges." -ForegroundColor Green

# Load the required assembly for GAC operations
[System.Reflection.Assembly]::Load("System.EnterpriseServices, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a") | Out-Null

# Create the Publish object
$publish = New-Object System.EnterpriseServices.Internal.Publish

# Get the directory where the script is located
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "Script is running from: $scriptDirectory"

$languageName = (Get-WinSystemLocale).Name
Write-Host "System locale is set to: $languageName"

$systemArchitecture = $env:PROCESSOR_ARCHITECTURE
Write-Host "System architecture is set to: $systemArchitecture"


if ($systemArchitecture -eq "AMD64" -or $systemArchitecture -eq "x86") {
    Write-Output "This is an AMD64 or x86 system."
    # Install each DLL in the Binaries directory
    $BinariesPath = $scriptDirectory + '/Binaries/' + $systemArchitecture
    Write-Host "Looking for DLLs in $BinariesPath..."
    Get-ChildItem -Path $BinariesPath -Filter *.dll | ForEach-Object {
        $dllPath = $_.FullName
        Write-Host "Installing $dllPath into GAC..."
        $publish.GacInstall($dllPath)
    }

    # Install each DLL in the ResourceBinaries directory
    $ResourceBinariesPath = $scriptDirectory + '/ResourceBinaries/' + $systemArchitecture + '/' + $languageName + '/'
    Write-Host "Looking for DLLs in $ResourceBinariesPath..."
    Get-ChildItem -Path $ResourceBinariesPath -Filter *.dll | ForEach-Object {
        $dllPath = $_.FullName
        Write-Host "Installing $dllPath into GAC..."
        $publish.GacInstall($dllPath)
    }
} else {
 Write-Output "This is not an AMD64 or x86 system. Architecture: $systemArchitecture. Aborting."
    exit
}

$regKey1= $scriptDirectory + '/regkeysNew/regkeyPowerShell.reg'
$regKey2 = $scriptDirectory + '/regkeysNew/regkeyPowerShellEngine.reg'

Write-Output "Installing Registry Keys..."

reg import $regKey1
reg import $regKey2

if ($LASTEXITCODE -eq 0) {
    Write-Host "Registry import succeeded." -ForegroundColor Green
} else {
    Write-Output "Registry import failed with exit code $LASTEXITCODE. Please run the script as PowerShell Administrator." -ForegroundColor Red
}
