################################################################################
##  File:  Validate-ToolCache.ps1
##  Desc:  Validate Tool Cache
################################################################################

# Helpers
function GetChildFolders {
    param (
        [Parameter(Mandatory = $True)]
        [string]$Path
    )
    return Get-ChildItem -Path $Path -Directory -Name
}

function Get-ToolcachePackages {
    $toolcachePath = Join-Path $env:ROOT_FOLDER "toolcache.json"
    return Get-Content -Raw $toolcachePath | ConvertFrom-Json
}

$toolcachePackages = (Get-ToolcachePackages).PSObject.Properties | ForEach-Object {
    $packageNameParts = $_.Name.Split("-")
    $toolName = $packageNameParts[1]
    return [PSCustomObject] @{
        ToolName = $packageNameParts[1]
        Versions = $_.Value
        Arch = $packageNameParts[3]
    }
}

function GetSoftwarePagesByName {
    param (
        [Parameter(Mandatory = $True)]
        [string]$SoftwareName
    )
    return $toolcachePackages | Where-Object { $_.ToolName -eq $SoftwareName }
}

function RunTestsByPath {
    param (
        [Parameter(Mandatory = $True)]
        [string[]]$ExecTests,
        [Parameter(Mandatory = $True)]
        [string]$Path,
        [Parameter(Mandatory = $True)]
        [string]$SoftwareName,
        [Parameter(Mandatory = $True)]
        [string]$SoftwareVer,
        [Parameter(Mandatory = $True)]
        [string]$SoftwareArch
    )

    foreach ($test in $ExecTests)
    {
        if (Test-Path "$Path\$test")
        {
            Write-Host "$SoftwareName($test) $SoftwareVer($SoftwareArch) is successfully installed:"
            Write-Host (& "$Path\$test" --version)
        }
        else
        {
            Write-Host "$SoftwareName($test) $SoftwareVer($SoftwareArch) is not installed"
            exit 1
        }
    }
}

function UpdateMarkdownDescription {
    param (
        [string]$Description,
        [Parameter(Mandatory = $True)]
        [string]$SoftwareVer,
        [Parameter(Mandatory = $True)]
        [string]$SoftwareArch
    )
    return $Description += "_Version:_ $SoftwareVer ($SoftwareArch)<br/>"
}

function ToolcacheTest {
    param (
        [Parameter(Mandatory = $True)]
        [string]$SoftwareName,
        [Parameter(Mandatory = $True)]
        [string[]]$ExecTests
    )

    $markdownDescription = ""
    $softwarePath = "$env:AGENT_TOOLSDIRECTORY\$SoftwareName"

    if (-Not (Test-Path $softwarePath))
    {
        Write-Host "$softwarePath does not exist"
        exit 1
    }

    [array]$installedVersions = GetChildFolders -Path $softwarePath
    if ($installedVersions.count -eq 0)
    {
        Write-Host "$softwarePath does not include any folders"
        exit 1
    }

    $softwarePackages = GetSoftwarePagesByName -SoftwareName $SoftwareName
    foreach($softwarePackage in $softwarePackages)
    {
        foreach ($version in $softwarePackage.Versions)
        {
            $foundVersion = $installedVersions | where { $_.StartsWith($version) }
            if ($foundVersion -eq $null)
            {
                Write-Host "$softwarePath\$version.* was not found"
                exit 1
            }

            $installedArch = GetChildFolders -Path "$softwarePath\$foundVersion"
            $requiredArch = $softwarePackage.Arch
            if (-Not ($installedArch -Contains $requiredArch))
            {
                Write-Host "$softwarePath\$foundVersion does not include required architecture"
                exit 1
            }

            $path = "$softwarePath\$foundVersion\$requiredArch"
            RunTestsByPath -ExecTests $ExecTests -Path $path -SoftwareName $SoftwareName -SoftwareVer $foundVersion -SoftwareArch $requiredArch

            $markdownDescription = UpdateMarkdownDescription -Description $markdownDescription -SoftwareVer $foundVersion -SoftwareArch $requiredArch
        }
        Add-SoftwareDetailsToMarkdown -SoftwareName $SoftwareName -DescriptionMarkdown $markdownDescription
    }
}

# Python test
$PythonTests = @("python.exe", "Scripts\pip.exe")
ToolcacheTest -SoftwareName "Python" -ExecTests $PythonTests

# PyPy test
$PyPyTests = @("python.exe", "bin\pip.exe")
ToolcacheTest -SoftwareName "PyPy" -ExecTests $PyPyTests

# Ruby test
$RubyTests = @("bin\ruby.exe")
ToolcacheTest -SoftwareName "Ruby" -ExecTests $RubyTests
