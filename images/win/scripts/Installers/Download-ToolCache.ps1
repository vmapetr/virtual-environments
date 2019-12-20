################################################################################
##  File:  Download-ToolCache.ps1
##  Team:  CI-Build
##  Desc:  Download tool cache
################################################################################

Function Install-NpmPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.String]
        $Name,
        [Parameter(Mandatory=$true)]
        [System.String]
        $NpmRegistry
    )

    Write-Host "Installing npm '$Name' package from '$NpmRegistry'"

    npm install $Name --registry=$NpmRegistry
}

Function InstallTool {
    [CmdletBinding()]
    param(
        [System.IO.FileInfo]$ExecutablePath
    )

    Set-Location -Path $ExecutablePath.DirectoryName -PassThru | Write-Host
    if (Test-Path 'tool.zip') {
        Expand-Archive 'tool.zip' -DestinationPath '.'
    }
    cmd.exe /c 'install_to_tools_cache.bat'
}

# Define AGENT_TOOLSDIRECTORY environment variable
$env:AGENT_TOOLSDIRECTORY = $ToolsDirectory
setx AGENT_TOOLSDIRECTORY $ToolsDirectory /M

# Install tools form NPM

$ToolVersionsFileContent = Get-Content -Path "$env:ROOT_FOLDER/toolcache.json" -Raw
$ToolVersions = ConvertFrom-Json -InputObject $ToolVersionsFileContent

$ToolVersions.PSObject.Properties | ForEach-Object {
    $PackageName = $_.Name
    $PackageVersions = $_.Value
    $NpmPackages = $PackageVersions | ForEach-Object { "$PackageName@$_" }
    foreach($NpmPackage in $NpmPackages) {
        Install-NpmPackage -Name $NpmPackage -NpmRegistry $env:TOOLCACHE_REGISTRY
    }
}

#junction point from the previous Python2 directory to the toolcache Python2
$python2Dir = (Get-Item -Path ($ToolsDirectory + '/Python/2.7*/x64')).FullName
cmd.exe /c mklink /d "C:\Python27amd64" "$python2Dir"
