Set-StrictMode -Version Latest

$script:PamLoggingState = @{
    Initialized = $false
    AppRoot = $null
    LogPath = $null
    FileMinimumLevel = 'Debug'
    ConsoleMinimumLevel = 'Information'
    MirrorToWriteLog = $true
    ExternalLoggerChecked = $false
    ExternalLoggerAvailable = $false
    WriteLogCommand = $null
}

function Get-PamLogLevelRank {
    param(
        [Parameter(Mandatory)]
        [string]$Level
    )

    switch ($Level.ToLowerInvariant()) {
        'debug' { return 10 }
        'information' { return 20 }
        'warning' { return 30 }
        'error' { return 40 }
        default { return 20 }
    }
}

function Normalize-PamLogLevel {
    param(
        [Parameter(Mandatory)]
        [string]$Level
    )

    switch ($Level.ToLowerInvariant()) {
        'debug' { return 'Debug' }
        'information' { return 'Information' }
        'info' { return 'Information' }
        'warning' { return 'Warning' }
        'warn' { return 'Warning' }
        'error' { return 'Error' }
        default { return 'Information' }
    }
}

function Initialize-PamLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppRoot
    )

    $resolvedAppRoot = [System.IO.Path]::GetFullPath($AppRoot)
    $defaultLogPath = Join-Path -Path $resolvedAppRoot -ChildPath 'output\logs\ProxyAddressManager.log'

    $script:PamLoggingState.AppRoot = $resolvedAppRoot
    $script:PamLoggingState.LogPath = $defaultLogPath
    $script:PamLoggingState.Initialized = $true
}

function Set-PamLoggingConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppRoot,

        [psobject]$LoggingConfiguration
    )

    if (-not $script:PamLoggingState.Initialized) {
        Initialize-PamLogging -AppRoot $AppRoot
    }

    if ($null -eq $LoggingConfiguration) {
        return
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$LoggingConfiguration.fileMinimumLevel)) {
        $script:PamLoggingState.FileMinimumLevel = Normalize-PamLogLevel -Level ([string]$LoggingConfiguration.fileMinimumLevel)
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$LoggingConfiguration.consoleMinimumLevel)) {
        $script:PamLoggingState.ConsoleMinimumLevel = Normalize-PamLogLevel -Level ([string]$LoggingConfiguration.consoleMinimumLevel)
    }

    if ($null -ne $LoggingConfiguration.mirrorToWriteLog) {
        $script:PamLoggingState.MirrorToWriteLog = [bool]$LoggingConfiguration.mirrorToWriteLog
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$LoggingConfiguration.path)) {
        if ([System.IO.Path]::IsPathRooted([string]$LoggingConfiguration.path)) {
            $script:PamLoggingState.LogPath = [string]$LoggingConfiguration.path
        }
        else {
            $script:PamLoggingState.LogPath = [System.IO.Path]::GetFullPath((Join-Path -Path $AppRoot -ChildPath ([string]$LoggingConfiguration.path)))
        }
    }
}

function Get-PamLoggingState {
    [CmdletBinding()]
    param()

    return [pscustomobject]$script:PamLoggingState
}

function Test-PamLogShouldWriteToFile {
    param(
        [Parameter(Mandatory)]
        [string]$Level
    )

    return (Get-PamLogLevelRank (Normalize-PamLogLevel -Level $Level)) -ge (Get-PamLogLevelRank $script:PamLoggingState.FileMinimumLevel)
}

function Test-PamLogShouldWriteToConsole {
    param(
        [Parameter(Mandatory)]
        [string]$Level
    )

    return (Get-PamLogLevelRank (Normalize-PamLogLevel -Level $Level)) -ge (Get-PamLogLevelRank $script:PamLoggingState.ConsoleMinimumLevel)
}

function Get-PamExternalWriteLogCommand {
    if (-not $script:PamLoggingState.ExternalLoggerChecked) {
        $script:PamLoggingState.WriteLogCommand = Get-Command -Name 'Write-Log' -ErrorAction SilentlyContinue
        $script:PamLoggingState.ExternalLoggerAvailable = $null -ne $script:PamLoggingState.WriteLogCommand
        $script:PamLoggingState.ExternalLoggerChecked = $true
    }

    return $script:PamLoggingState.WriteLogCommand
}

function Reset-PamExternalWriteLogCache {
    [CmdletBinding()]
    param()

    $script:PamLoggingState.ExternalLoggerChecked = $false
    $script:PamLoggingState.ExternalLoggerAvailable = $false
    $script:PamLoggingState.WriteLogCommand = $null
}

function Resolve-PamWriteLogLevelValue {
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.CommandInfo]$Command,

        [Parameter(Mandatory)]
        [string]$Level
    )

    $levelParameterName = @('Level', 'StatusLevel', 'Status', 'Type') | Where-Object { $Command.Parameters.ContainsKey($_) } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($levelParameterName)) {
        return $null
    }

    $parameterMetadata = $Command.Parameters[$levelParameterName]
    $validateSetAttribute = $parameterMetadata.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | Select-Object -First 1
    $candidateValues = switch (Normalize-PamLogLevel -Level $Level) {
        'Debug' { @('debug', 'Debug', 'DEBUG') }
        'Information' { @('information', 'Information', 'info', 'Info', 'INFO') }
        'Warning' { @('warning', 'Warning', 'WARN', 'warn') }
        'Error' { @('error', 'Error', 'ERROR') }
    }

    if ($null -ne $validateSetAttribute) {
        foreach ($candidate in $candidateValues) {
            $match = $validateSetAttribute.ValidValues | Where-Object { $_ -ieq $candidate } | Select-Object -First 1
            if ($null -ne $match) {
                return $match
            }
        }

        return $validateSetAttribute.ValidValues[0]
    }

    return $candidateValues[0]
}

function Invoke-PamExternalWriteLog {
    param(
        [Parameter(Mandatory)]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $script:PamLoggingState.MirrorToWriteLog) {
        return
    }

    $command = Get-PamExternalWriteLogCommand
    if ($null -eq $command) {
        return
    }

    try {
        $splat = @{}
        $messageParameterName = @('Message', 'LogMessage', 'Text') | Where-Object { $command.Parameters.ContainsKey($_) } | Select-Object -First 1
        if (-not [string]::IsNullOrWhiteSpace($messageParameterName)) {
            $splat[$messageParameterName] = $Message
        }

        $levelParameterName = @('Level', 'StatusLevel', 'Status', 'Type') | Where-Object { $command.Parameters.ContainsKey($_) } | Select-Object -First 1
        if (-not [string]::IsNullOrWhiteSpace($levelParameterName)) {
            $splat[$levelParameterName] = Resolve-PamWriteLogLevelValue -Command $command -Level $Level
        }

        $consoleParameterName = @('Console', 'console') | Where-Object { $command.Parameters.ContainsKey($_) } | Select-Object -First 1
        if (-not [string]::IsNullOrWhiteSpace($consoleParameterName)) {
            $splat[$consoleParameterName] = $false
        }

        & $command @splat | Out-Null
    }
    catch {
        # Logging must never break the app flow.
    }
}

function Write-PamLocalLogFile {
    param(
        [Parameter(Mandatory)]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $script:PamLoggingState.Initialized) {
        return
    }

    $logDirectory = Split-Path -Path $script:PamLoggingState.LogPath -Parent
    if (-not (Test-Path -Path $logDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    Add-Content -Path $script:PamLoggingState.LogPath -Value "[$timestamp][$Level] $Message"
}

function Write-PamConsoleLog {
    param(
        [Parameter(Mandatory)]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $foregroundColor = switch (Normalize-PamLogLevel -Level $Level) {
        'Debug' { 'DarkGray' }
        'Information' { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
    }

    Write-Host "[$Level] $Message" -ForegroundColor $foregroundColor
}

function Write-PamLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$ConsoleMessage
    )

    $normalizedLevel = Normalize-PamLogLevel -Level $Level
    $resolvedConsoleMessage = if ([string]::IsNullOrWhiteSpace($ConsoleMessage)) { $Message } else { $ConsoleMessage }

    if (Test-PamLogShouldWriteToFile -Level $normalizedLevel) {
        Write-PamLocalLogFile -Level $normalizedLevel -Message $Message
        Invoke-PamExternalWriteLog -Level $normalizedLevel -Message $Message
    }

    if (Test-PamLogShouldWriteToConsole -Level $normalizedLevel) {
        Write-PamConsoleLog -Level $normalizedLevel -Message $resolvedConsoleMessage
    }
}

function Stop-PamExecution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [string]$ConsoleMessage
    )

    Write-PamLog -Level 'Error' -Message $Message -ConsoleMessage $ConsoleMessage
    throw $Message
}

Export-ModuleMember -Function @(
    'Get-PamLoggingState',
    'Initialize-PamLogging',
    'Reset-PamExternalWriteLogCache',
    'Set-PamLoggingConfiguration',
    'Stop-PamExecution',
    'Write-PamLog'
)
