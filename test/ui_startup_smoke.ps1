param(
    [int]$TimeoutSeconds = 15
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$entryPoint = Join-Path $projectRoot "bin\batalha-naval.jl"
$runId = [Guid]::NewGuid().ToString("N")
$standardOutput = Join-Path ([IO.Path]::GetTempPath()) "batalha-naval-$runId.out.log"
$standardError = Join-Path ([IO.Path]::GetTempPath()) "batalha-naval-$runId.err.log"
$existingJuliaIds = @(Get-Process julia -ErrorAction SilentlyContinue | ForEach-Object Id)
$existingGdbusIds = @(Get-Process gdbus -ErrorAction SilentlyContinue | ForEach-Object Id)

$startupFailure = $null
try {
    $launcher = Start-Process -FilePath "julia" `
        -ArgumentList "--project=$projectRoot", $entryPoint `
        -WorkingDirectory $projectRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $standardOutput `
        -RedirectStandardError $standardError `
        -PassThru

    $applicationProcess = $null
    $gdbusFailureDetected = $false
    for ($attempt = 0; $attempt -lt $TimeoutSeconds; $attempt++) {
        Start-Sleep -Seconds 1
        $gdbusFailureDetected = $gdbusFailureDetected -or [bool](
            Get-Process gdbus -ErrorAction SilentlyContinue |
                Where-Object { $_.Id -notin $existingGdbusIds } |
                Select-Object -First 1
        )
        $applicationProcess = Get-Process julia -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Id -notin $existingJuliaIds -and
                $_.MainWindowTitle -eq "Batalha Naval"
            } |
            Select-Object -First 1
        if ($applicationProcess) { break }
    }

    if (-not $applicationProcess) {
        throw "O aplicativo não criou a janela Batalha Naval em $TimeoutSeconds segundos."
    }

    Start-Sleep -Seconds 1
    $applicationProcess.Refresh()
    if (-not $applicationProcess.Responding) {
        throw "A janela Batalha Naval abriu, mas o Windows a marcou como não respondendo."
    }

    if ($gdbusFailureDetected) {
        throw "A inicialização deixou um processo gdbus com erro de DLL."
    }

} catch {
    $startupFailure = $_
} finally {
    Get-Process julia -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -notin $existingJuliaIds } |
        Stop-Process -ErrorAction SilentlyContinue
    Get-Process gdbus -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -notin $existingGdbusIds } |
        Stop-Process -ErrorAction SilentlyContinue

    if ($launcher -and -not $launcher.HasExited) {
        [void]$launcher.WaitForExit(5000)
    }
    Start-Sleep -Milliseconds 500
}

try {
    if ($startupFailure) { throw $startupFailure }

    $diagnostics = if (Test-Path -LiteralPath $standardError) {
        Get-Content -Raw -LiteralPath $standardError
    } else {
        ""
    }

    if ($diagnostics -match "gdbus binary failed to launch bus") {
        throw "A inicialização tentou executar o gdbus incompatível: $diagnostics"
    }

    Write-Output "Janela Batalha Naval iniciou sem erros do gdbus."
} finally {
    foreach ($logPath in @($standardOutput, $standardError)) {
        $resolvedLog = [IO.Path]::GetFullPath($logPath)
        if ($resolvedLog.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath())) -and
            (Test-Path -LiteralPath $resolvedLog)) {
            Remove-Item -LiteralPath $resolvedLog -Force
        }
    }
}
