# Batalha Naval

Aplicativo desktop em Julia com interface Gtk4. O projeto usa Julia 1.12.6 e mantém a lógica de domínio independente da interface gráfica.

## Requisitos

- Julia 1.12.6 disponível no `PATH`.
- Windows ou Arch Linux com ambiente gráfico.

As bibliotecas Julia e os binários do Gtk são restaurados automaticamente pelo ambiente do projeto.

## Executar

No Windows, abra o PowerShell na pasta do projeto:

```powershell
.\run.ps1
```

No Arch Linux:

```sh
chmod +x run.sh
./run.sh
```

Também é possível executar diretamente:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. bin/batalha-naval.jl
```

## Testar o domínio

Os testes não carregam Gtk4 nem abrem janelas:

```sh
julia --project=. test/runtests.jl
```
