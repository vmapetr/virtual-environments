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
    $toolcachePath = Join-Path $env:installer_script_folder "toolcache.json"
    return Get-Content -Raw $toolcachePath | ConvertFrom-Json
}

$SoftwareArch = [pscustomobject]@{
python = @()
pypy = @()
ruby = @()
boost = @()
}

$packages = (Get-ToolcachePackages).PSObject.Properties | ForEach-Object {
    $packageNameParts = $_.Name.Split("-")
    $toolName = $packageNameParts[1]
    $SoftwareArch.$toolName = $SoftwareArch.$toolName + $packageNameParts[3]
    return [PSCustomObject] @{
        ToolName = $packageNameParts[1]
        Versions = $_.Value
    }
}

function ToolcacheTest {
    param (
        [Parameter(Mandatory = $True)]
        [string]$SoftwareName,
        [Parameter(Mandatory = $True)]
        [string[]]$ExecTests
    )
    if (Test-Path "$env:AGENT_TOOLSDIRECTORY\$SoftwareName")
    {
        $softwarePackage = $packages | Where-Object { $_.ToolName -eq $SoftwareName } | Select-Object -First 1
        $description = ""
        [array]$instaledVersions = GetChildFolders -Path "$env:AGENT_TOOLSDIRECTORY\$SoftwareName"
        if ($instaledVersions.count -gt 0){
            foreach ($version in $softwarePackage.Versions)
            {
                $foundVersion = $instaledVersions | where { $_.StartsWith($version) }

                if ($foundVersion -ne $null){

                    $architectures = GetChildFolders -Path "$env:AGENT_TOOLSDIRECTORY\$SoftwareName\$foundVersion"

                    Write-Host "$SoftwareName version - $foundVersion : $([system.String]::Join(",", $architectures))"

                    if (@(Compare-Object $SoftwareArch.$SoftwareName $architectures -SyncWindow 0).Length -eq 0) {

                        foreach ($arch in $architectures)
                        {
                            $path = "$env:AGENT_TOOLSDIRECTORY\$SoftwareName\$foundVersion\$arch"
                            foreach ($test in $ExecTests)
                            {
                                if (Test-Path "$path\$test")
                                {
                                    Write-Host "$SoftwareName($test) $foundVersion($arch) is successfully installed:"
                                    Write-Host (& "$path\$test" --version)
                                }
                                else
                                {
                                    Write-Host "$SoftwareName($test) $foundVersion ($arch) is not installed"
                                    exit 1
                                }
                            }

                            $description += "_Version:_ $foundVersion ($arch)<br/>"
                        }
                    }
                    else
                    {
                        Write-Host "$env:AGENT_TOOLSDIRECTORY\$SoftwareName\$foundVersion does not include required architecture"
                        exit 1
                    }
                }
                else
                {
                    Write-Host "$env:AGENT_TOOLSDIRECTORY\$SoftwareName\$version.* was not found"
                    exit 1
                }
            }

            Add-SoftwareDetailsToMarkdown -SoftwareName $SoftwareName -DescriptionMarkdown $description
        }
        else
        {
            Write-Host "$env:AGENT_TOOLSDIRECTORY\$SoftwareName does not include any folders"
            exit 1
        }
    }
    else
    {
        Write-Host "$env:AGENT_TOOLSDIRECTORY\$SoftwareName does not exist"
        exit 1
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
