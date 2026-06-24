Set-StrictMode -Version Latest

$script:RunState = [ordered]@{
    Process = $null
    LogFilePath = ''
    LogWriter = $null
    StartTime = $null
    OutputQueue = $null
    StdOutSubscriptionId = $null
    StdErrSubscriptionId = $null
    RootPath = ''

    # ASA-aware progress tracking. Each ASA logs "Testing Service Area X"
    # immediately followed by Get-URLsFromID emitting "URLsToVerify count: N"
    # (emitted natively by the core script). The GUI uses these to reset the
    # per-ASA counter and to know the true total for that ASA.
    MainAsas = @()                 # the top-level ASAs the user selected
    RemainingMainAsas = @()        # main ASAs not yet started
    AsaPath = @()                  # ordered stack of nested ASAs currently in flight
    CurrentAsa = ''                # innermost active ASA
    MainAsa = ''                   # outermost (top-of-stack) ASA that owns the current sub-test
    CurrentAsaTotal = 0            # URL count reported by Get-URLsFromID for CurrentAsa
    CurrentAsaCompleted = 0        # endpoints tested since the last ASA boundary
    AsaStartTime = $null           # when CurrentAsa started (for per-ASA ETA)
}

# Progress markers the GUI parses out of the core script's stdout. The core
# script emits these natively (see Write-Log usages in Get-IntuneNetworkRequirements.ps1):
#   A. "URLsToVerify count: N" from Get-URLsFromID  -> per-ASA total.
#   B. "Testing Service Area X (Function: Test-Name)" -> maps to the GUI ASA name.
#   C. "TestNetworkResult: url:port DNS=.. TCP=.. SSL=.." -> per-endpoint result.
$script:RequiredScriptMarkers = @(
    'URLsToVerify count:',
    '(Function: ',
    'TestNetworkResult:'
)

function Test-INRScriptMarker {
    <#
    .SYNOPSIS
    Verifies that the core script emits the progress markers the GUI relies on.
    .DESCRIPTION
    The GUI tracks per-ASA progress by parsing structured log lines from the
    core script's stdout. Rather than mutate the script on disk (the script
    emits these natively), this performs a read-only check and reports which
    markers, if any, are missing so a run can warn instead of silently showing
    no progress.
    .PARAMETER RootPath
    Repository root containing Get-IntuneNetworkRequirements.ps1.
    .OUTPUTS
    A [pscustomobject] with HasAllMarkers (bool) and MissingMarkers (string[]).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RootPath
    )

    $scriptPath = Join-Path -Path $RootPath -ChildPath 'Get-IntuneNetworkRequirements.ps1'
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        return [pscustomobject]@{
            HasAllMarkers  = $false
            MissingMarkers = @('<script not found>')
        }
    }

    $content = Get-Content -LiteralPath $scriptPath -Raw
    $missing = [System.Collections.Generic.List[string]]::new()
    foreach ($marker in $script:RequiredScriptMarkers) {
        if (-not $content.Contains($marker)) { [void]$missing.Add($marker) }
    }

    return [pscustomobject]@{
        HasAllMarkers  = ($missing.Count -eq 0)
        MissingMarkers = $missing.ToArray()
    }
}

function Resolve-INRCustomCsvArgument {
    <#
    .SYNOPSIS
    Returns a script-relative path for a custom CSV, staging it under
    CustomInput when it lives outside the repository root.
    .PARAMETER CustomCsvPath
    The user-selected CSV path.
    .PARAMETER RootPath
    Repository root the core script runs from.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CustomCsvPath,
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    $resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path
    $resolvedCsv = (Resolve-Path -LiteralPath $CustomCsvPath).Path

    if ($resolvedCsv.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [System.IO.Path]::GetRelativePath($resolvedRoot, $resolvedCsv)
    }

    $stagingDir = Join-Path -Path $resolvedRoot -ChildPath 'CustomInput'
    if (-not (Test-Path -LiteralPath $stagingDir)) {
        New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
    }

    $leafName = [System.IO.Path]::GetFileName($resolvedCsv)
    $stagedPath = Join-Path -Path $stagingDir -ChildPath $leafName
    if ($resolvedCsv -ne $stagedPath) {
        Copy-Item -LiteralPath $resolvedCsv -Destination $stagedPath -Force
    }

    return [System.IO.Path]::GetRelativePath($resolvedRoot, $stagedPath)
}

function New-INRArgumentList {
    <#
    .SYNOPSIS
    Builds the pwsh.exe argument list that launches the core script for the
    current GUI scan settings.
    .PARAMETER Settings
    The GUI settings object.
    .PARAMETER RootPath
    Repository root containing Get-IntuneNetworkRequirements.ps1.
    .OUTPUTS
    A string[] suitable for ProcessStartInfo.ArgumentList.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Settings,
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    $cliArguments = [System.Collections.Generic.List[string]]::new()
    $scriptPath = Join-Path -Path $RootPath -ChildPath 'Get-IntuneNetworkRequirements.ps1'

    $cliArguments.Add('-NoProfile')
    $cliArguments.Add('-ExecutionPolicy')
    $cliArguments.Add('Bypass')
    $cliArguments.Add('-File')
    $cliArguments.Add($scriptPath)

    $selectedAsas = @($Settings.SelectedASAs)

    if ($Settings.UseCustomCsv -and $Settings.CustomCsvPath) {
        $customCsvArgument = Resolve-INRCustomCsvArgument -CustomCsvPath $Settings.CustomCsvPath -RootPath $RootPath
        $cliArguments.Add('-CustomURLFile')
        $cliArguments.Add($customCsvArgument)
    }
    if ($Settings.UseMSJSON) { $cliArguments.Add('-UseMSJSON') }
    if ($Settings.UseMS365JSON) { $cliArguments.Add('-UseMS365JSON') }
    if ($Settings.AllowBestEffort) { $cliArguments.Add('-AllowBestEffort') }
    if ($Settings.CheckCertRevocation) { $cliArguments.Add('-CheckCertRevocation') }
    if ($Settings.BurstMode) { $cliArguments.Add('-BurstMode') }
    if ($Settings.TenantName) {
        $cliArguments.Add('-TenantName')
        $cliArguments.Add($Settings.TenantName)
    }
    if ($Settings.MaxDelayInMS) {
        $cliArguments.Add('-MaxDelayInMS')
        $cliArguments.Add([string]$Settings.MaxDelayInMS)
    }
    # -ToConsole routes every Write-Log message through Write-Host so the
    # GUI can parse a single stdout stream for progress and live output.
    # We intentionally do NOT pass -NoOutput here because that would
    # suppress those console messages too; instead the GUI captures
    # stdout into its own log file when EnableLogFile is true.
    $cliArguments.Add('-ToConsole')
    if ($selectedAsas.Count -gt 0) {
        foreach ($asa in $selectedAsas) {
            $cliArguments.Add("-$asa")
        }
    } else {
        $cliArguments.Add('-Intune')
    }

    $cliArguments.Add('-OutputCSV')
    return $cliArguments.ToArray()
}

function Start-INRRun {
    <#
    .SYNOPSIS
    Launches the core script as a child pwsh.exe process and wires up async
    stdout/stderr capture and per-ASA progress tracking.
    .PARAMETER RootPath
    Repository root containing Get-IntuneNetworkRequirements.ps1.
    .PARAMETER Settings
    The GUI settings object driving the run.
    .OUTPUTS
    The child process id.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath,
        [Parameter(Mandatory)]
        [psobject]$Settings
    )

    if ($script:RunState.Process -and -not $script:RunState.Process.HasExited) {
        throw 'A run is already active.'
    }

    # Verify (read-only) that the core script emits the progress markers the GUI
    # parses. The script emits them natively; we no longer mutate it on disk.
    $markerCheck = Test-INRScriptMarker -RootPath $RootPath

    $argList = New-INRArgumentList -Settings $Settings -RootPath $RootPath

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $process.StartInfo.FileName = 'pwsh.exe'
    # Use ArgumentList instead of Arguments to avoid shell parsing of quotes/commas
    # This preserves array syntax for parameters like -MergeCSVs "path1","path2"
    $process.StartInfo.ArgumentList.Clear()
    foreach ($arg in $argList) {
        $process.StartInfo.ArgumentList.Add($arg)
    }
    $process.StartInfo.WorkingDirectory = $RootPath
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.CreateNoWindow = $true
    $process.EnableRaisingEvents = $true

    # Thread-safe queue populated by async OutputDataReceived/ErrorDataReceived
    # events. Register-ObjectEvent marshals the callback through the PowerShell
    # event subsystem so we avoid the ScriptBlock-as-delegate trap that crashes
    # WPF when the child exits.
    $outputQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()

    $null = $process.Start()

    $stdOutSub = Register-ObjectEvent -InputObject $process -EventName 'OutputDataReceived' -MessageData $outputQueue -Action {
        try {
            $data = $EventArgs.Data
            if ($null -ne $data) { [void]$Event.MessageData.Enqueue($data) }
        } catch { }
    }
    $stdErrSub = Register-ObjectEvent -InputObject $process -EventName 'ErrorDataReceived' -MessageData $outputQueue -Action {
        try {
            $data = $EventArgs.Data
            if ($null -ne $data) { [void]$Event.MessageData.Enqueue('ERROR: ' + $data) }
        } catch { }
    }

    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()

    # When EnableLogFile is on, capture the -ToConsole stream into our own
    # GUI-side log file. -ToConsole disables the script's built-in file
    # logger, so this preserves on-disk logging through the GUI path.
    $guiLogPath = $null
    $guiLogWriter = $null
    if ($Settings.EnableLogFile) {
        $logDir = Join-Path -Path $RootPath -ChildPath 'Logs'
        if (-not (Test-Path -LiteralPath $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $guiLogPath = Join-Path -Path $logDir -ChildPath ("INR_GUI_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        $guiLogWriter = [System.IO.StreamWriter]::new($guiLogPath, $false, [System.Text.Encoding]::UTF8)
        $guiLogWriter.AutoFlush = $true
        $guiLogWriter.WriteLine(("=== GUI run started {0} ===" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
        # Reconstruct command from ArgumentList for logging
        $commandLog = "pwsh.exe " + (($process.StartInfo.ArgumentList | ForEach-Object { if ($_ -match '\s') { """$_""" } else { $_ } }) -join ' ')
        $guiLogWriter.WriteLine("Command: $commandLog")
        if (-not $markerCheck.HasAllMarkers) {
            $guiLogWriter.WriteLine("WARNING: Core script is missing progress markers ($($markerCheck.MissingMarkers -join ', ')). Live progress may be limited.")
        }
    }

    $script:RunState.Process = $process
    $script:RunState.StartTime = Get-Date
    $script:RunState.LogFilePath = $guiLogPath
    $script:RunState.LogWriter = $guiLogWriter
    $script:RunState.OutputQueue = $outputQueue
    $script:RunState.StdOutSubscriptionId = $stdOutSub.Id
    $script:RunState.StdErrSubscriptionId = $stdErrSub.Id
    $script:RunState.RootPath = $RootPath

    $selectedAsas = @($Settings.SelectedASAs)
    if ($selectedAsas.Count -eq 0) { $selectedAsas = @('Intune') }
    $script:RunState.MainAsas = $selectedAsas
    $script:RunState.RemainingMainAsas = [System.Collections.Generic.List[string]]::new()
    foreach ($a in $selectedAsas) { [void]$script:RunState.RemainingMainAsas.Add($a) }
    $script:RunState.AsaPath = [System.Collections.Generic.List[string]]::new()
    $script:RunState.CurrentAsa = ''
    $script:RunState.MainAsa = ''
    $script:RunState.CurrentAsaTotal = 0
    $script:RunState.CurrentAsaCompleted = 0
    $script:RunState.AsaStartTime = $null

    return $process.Id
}

function Stop-INRRun {
    <#
    .SYNOPSIS
    Stops the active run, attempting a graceful close before escalating to a
    forced process-tree kill, and tears down async subscriptions.
    .PARAMETER GracefulTimeoutMs
    How long to wait for a graceful exit before forcing termination.
    .PARAMETER KillTimeoutMs
    How long to wait for the forced kill to complete.
    .PARAMETER Reason
    Reason recorded in the GUI log.
    .OUTPUTS
    A [pscustomobject] describing how the run ended.
    #>
    [CmdletBinding()]
    param(
        [int]$GracefulTimeoutMs = 4000,
        [int]$KillTimeoutMs = 2000,
        [string]$Reason = 'User requested stop via GUI'
    )

    $result = [pscustomobject]@{
        WasRunning = $false
        Method = 'none'
        ExitCode = $null
        Error = $null
        LogFilePath = $script:RunState.LogFilePath
    }

    if (-not $script:RunState.Process) {
        # Still close any leftover writer.
        if ($script:RunState.LogWriter) {
            try { $script:RunState.LogWriter.Dispose() } catch { }
            $script:RunState.LogWriter = $null
        }
        return $result
    }

    # Write the stop marker to the GUI log before terminating, so the reason
    # is captured even if forced-kill takes a moment.
    if ($script:RunState.LogWriter) {
        try {
            $script:RunState.LogWriter.WriteLine(
                ("=== {0}: {1} ===" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Reason))
        } catch { }
    }

    $proc = $script:RunState.Process
    try {
        if ($proc.HasExited) {
            $result.ExitCode = $proc.ExitCode
            return $result
        }

        $result.WasRunning = $true

        # Step 1: attempt graceful close. Console processes typically have no
        # main window; CloseMainWindow returns false, so we fall through.
        $closeRequested = $false
        try { $closeRequested = $proc.CloseMainWindow() } catch { }

        if ($closeRequested) {
            if ($proc.WaitForExit($GracefulTimeoutMs)) {
                $result.Method = 'graceful'
                $result.ExitCode = $proc.ExitCode
                return $result
            }
        }

        # Step 2: escalate to forced termination of the process tree.
        try {
            $proc.Kill($true)
        } catch {
            $result.Error = $_.Exception.Message
        }

        if ($proc.WaitForExit($KillTimeoutMs)) {
            $result.Method = 'killed'
            $result.ExitCode = $proc.ExitCode
        } else {
            $result.Method = 'kill-timeout'
        }
    } catch {
        $result.Error = $_.Exception.Message
    }

    # Detach async output subscriptions so the process object can be GC'd
    # cleanly and the next run starts with a fresh queue.
    foreach ($subIdProp in @('StdOutSubscriptionId','StdErrSubscriptionId')) {
        $subId = $script:RunState.$subIdProp
        if ($subId) {
            try { Unregister-Event -SubscriptionId $subId -ErrorAction SilentlyContinue } catch { }
            try { Remove-Job -Id $subId -Force -ErrorAction SilentlyContinue } catch { }
        }
        $script:RunState.$subIdProp = $null
    }

    # Final flush + close of the GUI log writer.
    if ($script:RunState.LogWriter) {
        try {
            $script:RunState.LogWriter.WriteLine(
                ("=== {0}: Run ended (method={1}, exit={2}) ===" -f
                    (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),
                    $result.Method,
                    $result.ExitCode))
        } catch { }
        try { $script:RunState.LogWriter.Dispose() } catch { }
        $script:RunState.LogWriter = $null
    }

    return $result
}

function Get-INRRunStatus {
    <#
    .SYNOPSIS
    Returns a snapshot of the current run state (running flag, process id,
    per-ASA progress counters) for the GUI poll loop.
    #>
    [CmdletBinding()]
    param()

    $isRunning = $false
    if ($script:RunState.Process -and -not $script:RunState.Process.HasExited) {
        $isRunning = $true
    }

    return [pscustomobject]@{
        IsRunning = $isRunning
        ProcessId = if ($script:RunState.Process) { $script:RunState.Process.Id } else { $null }
        StartTime = $script:RunState.StartTime
        LogFilePath = $script:RunState.LogFilePath
        MainAsa = $script:RunState.MainAsa
        CurrentAsa = $script:RunState.CurrentAsa
        AsaPath = @($script:RunState.AsaPath)
        CurrentAsaTotal = $script:RunState.CurrentAsaTotal
        CurrentAsaCompleted = $script:RunState.CurrentAsaCompleted
        MainAsaCount = @($script:RunState.MainAsas).Count
        RemainingMainAsaCount = @($script:RunState.RemainingMainAsas).Count
    }
}

function Reset-INRRunState {
    <#
    .SYNOPSIS
    Clears counters and the output queue so the next run (or a UI reset after
    Stop) starts from a clean baseline. Does not touch the disposed Process.
    #>
    [CmdletBinding()]
    param()

    # Clear counters/queue so a subsequent run (or a UI status reset after
    # Stop) starts from a known clean baseline. Does not touch the Process
    # field - Stop-INRRun has already disposed of it.
    $script:RunState.StartTime = $null
    $script:RunState.OutputQueue = $null
    $script:RunState.LogFilePath = ''
    $script:RunState.MainAsas = @()
    $script:RunState.RemainingMainAsas = @()
    $script:RunState.AsaPath = @()
    $script:RunState.CurrentAsa = ''
    $script:RunState.MainAsa = ''
    $script:RunState.CurrentAsaTotal = 0
    $script:RunState.CurrentAsaCompleted = 0
    $script:RunState.AsaStartTime = $null
}

function Get-INRNewOutput {
    <#
    .SYNOPSIS
    Drains queued child-process output lines, mirrors them to the GUI log, and
    updates per-ASA progress counters from the embedded markers.
    .OUTPUTS
    The drained lines as a string[].
    #>
    [CmdletBinding()]
    param()

    if (-not $script:RunState.Process -or -not $script:RunState.OutputQueue) {
        return @()
    }

    $queue = $script:RunState.OutputQueue
    $writer = $script:RunState.LogWriter
    $lines = [System.Collections.Generic.List[string]]::new()
    $line = $null
    while ($queue.TryDequeue([ref]$line)) {
        $lines.Add($line)

        # Mirror to our GUI log file when EnableLogFile is on.
        if ($writer) {
            try { $writer.WriteLine($line) } catch { }
        }

        # ASA boundary. Patched script emits the function name in parens,
        # which matches MainAsas; fall back to the short $ServiceArea code
        # on an unpatched script (won't match MainAsas, but at least the
        # CurrentAsa label updates).
        $asa = $null
        if ($line -match 'M:Testing Service Area \S+ \(Function: Test-(\S+)\)') {
            $asa = $matches[1]
        } elseif ($line -match 'C:Test\S+\s+M:Testing Service Area\s+(\S+)') {
            $asa = $matches[1]
        }
        if ($asa) {
            $script:RunState.CurrentAsa = $asa
            $script:RunState.CurrentAsaTotal = 0
            $script:RunState.CurrentAsaCompleted = 0
            $script:RunState.AsaStartTime = Get-Date

            $isMain = ($script:RunState.MainAsas -contains $asa) -and
                      ($script:RunState.RemainingMainAsas -contains $asa)

            if ($isMain) {
                $script:RunState.AsaPath = [System.Collections.Generic.List[string]]::new()
                [void]$script:RunState.AsaPath.Add($asa)
                $script:RunState.MainAsa = $asa
                $remaining = [System.Collections.Generic.List[string]]::new()
                foreach ($a in $script:RunState.RemainingMainAsas) {
                    if ($a -ne $asa) { [void]$remaining.Add($a) }
                }
                $script:RunState.RemainingMainAsas = $remaining
            } else {
                if (-not $script:RunState.MainAsa) {
                    $script:RunState.MainAsa = $asa
                    [void]$script:RunState.AsaPath.Add($asa)
                } else {
                    [void]$script:RunState.AsaPath.Add($asa)
                }
            }
            continue
        }

        # URL count emitted by the patched Get-URLsFromID.
        if ($line -match 'C:GetURLsFromID\s+M:URLsToVerify count:\s*(\d+)') {
            $script:RunState.CurrentAsaTotal = [int]$matches[1]
            continue
        }

        # Per-endpoint progress within the current ASA.
        if ($line -like '*C:TestNetwork*M:Testing*on port*') {
            $script:RunState.CurrentAsaCompleted++
        }
    }

    return $lines.ToArray()
}

function Get-INREta {
    <#
    .SYNOPSIS
    Estimates remaining time for the current ASA based on elapsed time and
    endpoints completed so far.
    .OUTPUTS
    An hh:mm:ss string, or 'Calculating...' when not enough data exists.
    #>
    [CmdletBinding()]
    param()

    if ($script:RunState.CurrentAsaTotal -le 0 -or
        $script:RunState.CurrentAsaCompleted -le 0 -or
        -not $script:RunState.AsaStartTime) {
        return 'Calculating...'
    }

    # Live per-ASA ETA. We project only the remaining endpoints in the
    # CURRENT ASA because future ASAs have unknown URL counts and cannot
    # be predicted from a heuristic anymore.
    $elapsedSeconds = ((Get-Date) - $script:RunState.AsaStartTime).TotalSeconds
    $liveAverageSeconds = $elapsedSeconds / $script:RunState.CurrentAsaCompleted
    $remainingEndpoints = [Math]::Max(
        0,
        $script:RunState.CurrentAsaTotal - $script:RunState.CurrentAsaCompleted)
    $remainingSeconds = [int]($remainingEndpoints * $liveAverageSeconds)

    return ([TimeSpan]::FromSeconds($remainingSeconds)).ToString('hh\:mm\:ss')
}

Export-ModuleMember -Function @(
    'Test-INRScriptMarker',
    'Resolve-INRCustomCsvArgument',
    'New-INRArgumentList',
    'Start-INRRun',
    'Stop-INRRun',
    'Get-INRRunStatus',
    'Reset-INRRunState',
    'Get-INRNewOutput',
    'Get-INREta'
)
