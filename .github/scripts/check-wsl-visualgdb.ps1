Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Actual,

        [Parameter(Mandatory = $true)]
        [string]$Expected,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if ($Actual -ne $Expected) {
        throw "$Description mismatch. Expected '$Expected', got '$Actual'."
    }
}

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not $Condition) {
        throw $Description
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$visualGdbDirectory = Join-Path $repoRoot 'VisualGDB'
$projectPath = Join-Path $visualGdbDirectory 'WSL-Hazard3-Doom.vcxproj'
$solutionPath = Join-Path $visualGdbDirectory 'WSL-Hazard3-Doom.slnx'
$buildScriptPath = Join-Path $visualGdbDirectory 'build-wsl.cmd'

foreach ($requiredPath in @($projectPath, $solutionPath, $buildScriptPath)) {
    Assert-True (Test-Path -LiteralPath $requiredPath -PathType Leaf) `
        "Required WSL Visual Studio file is missing: $requiredPath"
}

[xml]$project = Get-Content -LiteralPath $projectPath -Raw

# MSBuild project files use a default XML namespace. Avoid PowerShell's XML
# property adapter here: under StrictMode, probing an optional/missing XML
# attribute such as .Label or .Condition throws before the predicate can
# simply evaluate to $false. XPath + GetAttribute() is explicit and robust.
$projectConfigurations = @(
    $project.SelectNodes(
        "/*[local-name()='Project']/*[local-name()='ItemGroup' and @Label='ProjectConfigurations']/*[local-name()='ProjectConfiguration']"
    )
)
$propertyGroups = @(
    $project.SelectNodes(
        "/*[local-name()='Project']/*[local-name()='PropertyGroup']"
    )
)

$expectedCommands = @{
    NMakeBuildCommandLine = 'cmd.exe /d /c call "$(ProjectDir)build-wsl.cmd" build'
    NMakeCleanCommandLine = 'cmd.exe /d /c call "$(ProjectDir)build-wsl.cmd" clean'
    NMakeReBuildCommandLine = 'cmd.exe /d /c call "$(ProjectDir)build-wsl.cmd" rebuild'
    NMakeOutput = '$(ProjectDir)..\build\hazard3-test.elf'
}

foreach ($configuration in @('Debug', 'Release')) {
    $configurationName = "$configuration|VisualGDB"
    Assert-True ([bool]($projectConfigurations | Where-Object {
        $_.GetAttribute('Include') -eq $configurationName
    })) `
        "WSL VisualGDB project is missing configuration '$configurationName'."

    $condition = "'`$(Configuration)|`$(Platform)'=='$configurationName'"
    $nmakeGroup = $propertyGroups |
        Where-Object {
            $_.GetAttribute('Condition') -eq $condition -and
            $null -ne $_.SelectSingleNode("*[local-name()='NMakeBuildCommandLine']")
        } |
        Select-Object -First 1

    Assert-True ($null -ne $nmakeGroup) `
        "WSL VisualGDB project has no NMake build settings for '$configurationName'."

    $configurationTypeNode = $nmakeGroup.SelectSingleNode("*[local-name()='ConfigurationType']")
    Assert-True ($null -ne $configurationTypeNode) `
        "$configuration ConfigurationType is missing."
    Assert-Equal ([string]$configurationTypeNode.InnerText) 'Makefile' `
        "$configuration ConfigurationType"

    foreach ($propertyName in $expectedCommands.Keys) {
        $propertyNode = $nmakeGroup.SelectSingleNode("*[local-name()='$propertyName']")
        Assert-True ($null -ne $propertyNode) `
            "$configuration $propertyName is missing."
        Assert-Equal ([string]$propertyNode.InnerText) $expectedCommands[$propertyName] `
            "$configuration $propertyName"
    }
}

[xml]$solution = Get-Content -LiteralPath $solutionPath -Raw
$solutionPlatforms = @(
    $solution.SelectNodes(
        "/*[local-name()='Solution']/*[local-name()='Configurations']/*[local-name()='Platform']"
    )
)
$solutionProjects = @(
    $solution.SelectNodes(
        "/*[local-name()='Solution']/*[local-name()='Project']"
    )
)
Assert-True ([bool]($solutionPlatforms | Where-Object {
    $_.GetAttribute('Name') -eq 'VisualGDB'
})) `
    'WSL solution does not declare the VisualGDB platform.'
Assert-True ([bool]($solutionProjects | Where-Object {
    $_.GetAttribute('Path') -eq 'WSL-Hazard3-Doom.vcxproj'
})) `
    'WSL solution does not reference WSL-Hazard3-Doom.vcxproj.'

$xsiNamespace = 'http://www.w3.org/2001/XMLSchema-instance'
foreach ($configuration in @('Debug', 'Release')) {
    $settingsPath = Join-Path $visualGdbDirectory "WSL-Hazard3-Doom-$configuration.vgdbsettings"
    Assert-True (Test-Path -LiteralPath $settingsPath -PathType Leaf) `
        "VisualGDB settings file is missing: $settingsPath"

    [xml]$settings = Get-Content -LiteralPath $settingsPath -Raw
    $root = $settings.VisualGDBProjectSettings2

    Assert-Equal ([string]$root.ConfigurationName) $configuration `
        "$configuration settings ConfigurationName"
    Assert-Equal ([string]$root.Project.GetAttribute('type', $xsiNamespace)) `
        'com.visualgdb.project.linux' "$configuration settings project type"
    Assert-Equal ([string]$root.Project.BuildHost.HostName) 'localhost-lxss' `
        "$configuration BuildHost HostName"
    Assert-Equal ([string]$root.Project.BuildHost.Transport) 'LinuxSubsystem' `
        "$configuration BuildHost Transport"
    Assert-Equal ([string]$root.Project.MountInfo.RemoteHost.HostName) 'localhost-lxss' `
        "$configuration MountInfo HostName"
    Assert-Equal ([string]$root.Project.MountInfo.RemoteHost.Transport) 'LinuxSubsystem' `
        "$configuration MountInfo Transport"
    Assert-Equal ([string]$root.Build.AbsoluteTargetPath) '$(SourceDir)/../build/hazard3-test.elf' `
        "$configuration AbsoluteTargetPath"
    Assert-Equal ([string]$root.Debug.LaunchGDBSettings.GDBExe) `
        '/opt/riscv/bin/riscv32-unknown-elf-gdb' "$configuration GDB executable"

    if ([string]$root.Build.BuildCommand.Command -eq '/bin/true' -or
        [string]$root.Build.CleanCommand.Command -eq '/bin/true') {
        Write-Warning (
            "$configuration VisualGDB Build/Clean command is still /bin/true. " +
            'The NMake WSL bridge is tested by CI, but the VisualGDB-internal build remains a no-op.'
        )
    }

    $settingsText = Get-Content -LiteralPath $settingsPath -Raw
    Assert-True (-not $settingsText.Contains('C:\workspace\Hazard3-Doom')) `
        "$configuration settings contain a hard-coded C:\workspace\Hazard3-Doom path."
}

Write-Host 'WSL Visual Studio/VisualGDB project metadata validation passed.'
