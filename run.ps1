$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$entryPoint = Join-Path $projectRoot "bin\batalha-naval.jl"

if (-not (Get-Command julia -ErrorAction SilentlyContinue)) {
    throw "Julia 1.12.6 não foi encontrada no PATH. Instale-a antes de executar o jogo."
}

& julia "--project=$projectRoot" "--startup-file=no" -e "using Pkg; Pkg.instantiate()"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& julia "--project=$projectRoot" "--startup-file=no" $entryPoint
exit $LASTEXITCODE
