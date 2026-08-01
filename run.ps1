$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$entryPoint = Join-Path $projectRoot "bin\batalha-naval.jl"

& julia "--project=$projectRoot" -e "using Pkg; Pkg.instantiate()"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& julia "--project=$projectRoot" $entryPoint
exit $LASTEXITCODE
