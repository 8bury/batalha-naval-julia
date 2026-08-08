#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if ! command -v julia >/dev/null 2>&1; then
    printf '%s\n' 'Julia 1.12.6 não foi encontrada no PATH. Instale-a antes de executar o jogo.' >&2
    exit 127
fi

julia --project="$project_root" --startup-file=no -e 'using Pkg; Pkg.instantiate()'
exec julia --project="$project_root" --startup-file=no "$project_root/bin/batalha-naval.jl"
