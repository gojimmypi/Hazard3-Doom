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

function Get-RequiredNodeText {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlNode]$Parent,

        [Parameter(Mandatory = $true)]
        [string]$XPath,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $node = $Parent.SelectSingleNode($XPath)
    Assert-True ($null -ne $node) "$Description is missing."
    return [string]$node.InnerText
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$visualGdbDirectory = Join-Path $repoRoot 'VisualGDB'
$projectPath = Join-Path $visualGdbDirectory 'Hazard3-Doom.vcxproj'
$solutionPath = Join-Path $visualGdbDirectory 'Hazard3-Doom.slnx'
$buildScriptPath = Join-Path $repoRoot 'scripts\build-xpack.cmd'

foreach ($requiredPath in @($projectPath, $solutionPath, $buildScriptPath)) {
    Assert-True (Test-Path -LiteralPath $requiredPath -PathType Leaf) `
        "Required native Windows Visual Studio file is missing: $requiredPath"
}

[xml]$project = Get-Content -LiteralPath $projectPath -Raw

$projectConfigurations = @(
    $project.SelectNodes(
        "/*[local-name()='Project']/*[local-name()='ItemGroup' and @Label='ProjectConfigurations']/*[local-name()='ProjectConfiguration']"
    )
)
$configurationGroups = @(
    $project.SelectNodes(
        "/*[local-name()='Project']/*[local-name()='PropertyGroup' and @Label='Configuration']"
    )
)
$nmakeGroups = @(
    $project.SelectNodes(
        "/*[local-name()='Project']/*[local-name()='PropertyGroup' and not(@Label)]"
    )
)

$expectedNMakeCommands = @{
    NMakeBuildCommandLine = '"$(VISUALGDB_DIR)\VisualGDB.exe" /build "$(ProjectPath)" "/solution:$(SolutionPath)" "/config:$(Configuration)" "/platform:$(Platform)"'
    NMakeCleanCommandLine = '"$(VISUALGDB_DIR)\VisualGDB.exe" /clean "$(ProjectPath)" "/solution:$(SolutionPath)" "/config:$(Configuration)" "/platform:$(Platform)"'
    NMakeReBuildCommandLine = '"$(VISUALGDB_DIR)\VisualGDB.exe" /rebuild "$(ProjectPath)" "/solution:$(SolutionPath)" "/config:$(Configuration)" "/platform:$(Platform)"'
}

$platformToolsets = @()

foreach ($configuration in @('Debug', 'Release')) {
    $configurationName = "$configuration|Win32"
    $condition = "'`$(Configuration)|`$(Platform)'=='$configurationName'"

    Assert-True ([bool]($projectConfigurations | Where-Object {
        $_.GetAttribute('Include') -eq $configurationName
    })) `
        "Native Windows Visual Studio project is missing configuration '$configurationName'."

    $configurationGroup = $configurationGroups |
        Where-Object { $_.GetAttribute('Condition') -eq $condition } |
        Select-Object -First 1
    Assert-True ($null -ne $configurationGroup) `
        "Native Windows Visual Studio project has no Configuration property group for '$configurationName'."

    Assert-Equal `
        (Get-RequiredNodeText $configurationGroup "*[local-name()='ConfigurationType']" "$configuration ConfigurationType") `
        'Makefile' `
        "$configuration ConfigurationType"

    $platformToolset = Get-RequiredNodeText `
        $configurationGroup `
        "*[local-name()='PlatformToolset']" `
        "$configuration PlatformToolset"
    Assert-True (-not [string]::IsNullOrWhiteSpace($platformToolset)) `
        "$configuration PlatformToolset must not be empty."
    $platformToolsets += $platformToolset

    $nmakeGroup = $nmakeGroups |
        Where-Object {
            $_.GetAttribute('Condition') -eq $condition -and
            $null -ne $_.SelectSingleNode("*[local-name()='NMakeBuildCommandLine']")
        } |
        Select-Object -First 1
    Assert-True ($null -ne $nmakeGroup) `
        "Native Windows Visual Studio project has no NMake settings for '$configurationName'."

    foreach ($propertyName in $expectedNMakeCommands.Keys) {
        Assert-Equal `
            (Get-RequiredNodeText $nmakeGroup "*[local-name()='$propertyName']" "$configuration $propertyName") `
            $expectedNMakeCommands[$propertyName] `
            "$configuration $propertyName"
    }

    Assert-Equal `
        (Get-RequiredNodeText $nmakeGroup "*[local-name()='NMakeOutput']" "$configuration NMakeOutput") `
        "`$(ProjectDir)Hazard3-Doom-$configuration.vgdbsettings" `
        "$configuration NMakeOutput"
}

Assert-Equal $platformToolsets[0] $platformToolsets[1] `
    'Debug/Release PlatformToolset'

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
    $_.GetAttribute('Name') -eq 'Win32'
})) `
    'Native Windows solution does not declare the Win32 platform.'
Assert-True ([bool]($solutionProjects | Where-Object {
    $_.GetAttribute('Path') -eq 'Hazard3-Doom.vcxproj'
})) `
    'Native Windows solution does not reference Hazard3-Doom.vcxproj.'

$xsiNamespace = 'http://www.w3.org/2001/XMLSchema-instance'
foreach ($configuration in @('Debug', 'Release')) {
    $settingsPath = Join-Path $visualGdbDirectory `
        "Hazard3-Doom-$configuration.vgdbsettings"
    Assert-True (Test-Path -LiteralPath $settingsPath -PathType Leaf) `
        "VisualGDB settings file is missing: $settingsPath"

    [xml]$settings = Get-Content -LiteralPath $settingsPath -Raw
    $root = $settings.DocumentElement

    Assert-Equal ([string]$root.Name) 'VisualGDBProjectSettings2' `
        "$configuration settings root element"
    Assert-Equal ([string]$root.ConfigurationName) $configuration `
        "$configuration settings ConfigurationName"
    Assert-Equal ([string]$root.Project.GetAttribute('type', $xsiNamespace)) `
        'com.visualgdb.project.windows' `
        "$configuration settings project type"
    Assert-Equal ([string]$root.Build.GetAttribute('type', $xsiNamespace)) `
        'com.visualgdb.build.custom' `
        "$configuration settings build type"

    Assert-Equal ([string]$root.Build.BuildCommand.Command) 'cmd.exe' `
        "$configuration VisualGDB build command"
    Assert-Equal ([string]$root.Build.BuildCommand.Arguments) `
        '/d /c call "$(ProjectDir)\..\scripts\build-xpack.cmd" build 64m 50000000' `
        "$configuration VisualGDB build arguments"
    Assert-Equal ([string]$root.Build.BuildCommand.WorkingDirectory) `
        '$(ProjectDir)\..' `
        "$configuration VisualGDB build working directory"

    Assert-Equal ([string]$root.Build.CleanCommand.Command) 'cmd.exe' `
        "$configuration VisualGDB clean command"
    Assert-Equal ([string]$root.Build.CleanCommand.Arguments) `
        '/d /c call "$(ProjectDir)\..\scripts\build-xpack.cmd" clean 64m 50000000' `
        "$configuration VisualGDB clean arguments"
    Assert-Equal ([string]$root.Build.CleanCommand.WorkingDirectory) `
        '$(ProjectDir)\..' `
        "$configuration VisualGDB clean working directory"

    Assert-Equal ([string]$root.Build.AbsoluteTargetPath) `
        '$(ProjectDir)\..\build\hazard3-boot-monitor.elf' `
        "$configuration AbsoluteTargetPath"
}

Write-Host 'Native Windows Visual Studio/VisualGDB metadata validation passed.'
