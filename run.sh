#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

julia --project="$project_root" -e 'using Pkg; Pkg.instantiate()'
exec julia --project="$project_root" "$project_root/bin/batalha-naval.jl"
