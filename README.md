# Batalha Naval

## Requisitos e instalação

- Julia 1.12.6 disponível no `PATH`.
- Windows 10/11 ou Arch Linux com sessão gráfica.

Baixe o projeto e confirme `julia --version`. Os launchers usam `Project.toml` e
`Manifest.toml`, ignoram o arquivo global `startup.jl` e executam
`Pkg.instantiate()` antes do jogo; assim, as versões Julia e os artefatos Gtk do
projeto são restaurados de maneira reproduzível. A primeira execução requer rede.

## Executar

No Windows, abra o PowerShell na pasta do projeto:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run.ps1
```

O parâmetro `ExecutionPolicy` vale somente para esse processo e não altera a configuração do Windows.

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

No Windows, o smoke test gráfico abre a janela, verifica se ela responde e a fecha:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ui_startup_smoke.ps1
```

## Como jogar

Use **Instruções** no menu para consultar objetivo, posicionamento, terrenos,
economia, armas, pontuação e símbolos. O mesmo guia pode ser aberto durante a
batalha; a janela de instruções não interrompe o cronômetro. Mapas grandes e
janelas próximas do tamanho mínimo oferecem rolagem nos tabuleiros e no guia.

Partidas concluídas aparecem no ranking separado por mapa. Ao abandonar uma
partida ou fechar o aplicativo durante o combate, uma confirmação avisa que o
resultado não será classificado.

## Dados locais

O ranking SQLite fica em `%USERPROFILE%\.batalha-naval\ranking.sqlite3` no
Windows e em `~/.batalha-naval/ranking.sqlite3` no Arch. Defina
`BATALHA_NAVAL_DATA_DIR` antes de iniciar para escolher outro diretório. Excluir
esse arquivo apaga somente o ranking local; não há sincronização em nuvem.

## Arch Linux: escopo da verificação

O launcher POSIX e o ambiente Julia são fornecidos e a suíte de domínio é
portável. No Windows, a suíte e o smoke de abertura foram automatizados; o fluxo
interativo completo permanece no roteiro manual abaixo. No Arch, a aparência,
integração com o gerenciador de janelas, áudio e disponibilidade de uma sessão
gráfica/GPU dependem da instalação local e precisam de conferência manual. Em
sessões mínimas, instale os drivers gráficos e bibliotecas de áudio usuais do
sistema antes do teste.

O roteiro completo de aceite está em
[`docs/manual-validation-windows.md`](docs/manual-validation-windows.md).
