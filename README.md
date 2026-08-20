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

## Organização do código

O ponto de entrada do pacote é `src/BatalhaNaval.jl`. A implementação está
separada pelas responsabilidades do jogo:

```text
src/
├── models/
│   ├── configuration/  # mapas, frotas, armas e configuração da partida
│   ├── positioning/    # terreno, validação e posicionamento das embarcações
│   ├── combat/         # ataques, loja, estado do combate e computador
│   └── scoring/        # resumo, duração e pontuação
├── controllers/        # coordenação entre domínio e interface
├── persistence/        # armazenamento do ranking
└── views/
    ├── battle/         # tela, histórico e resumo do combate
    ├── pages/          # demais páginas da aplicação
    └── widgets/        # componentes Gtk reutilizados
```

`src/models/GameModel.jl` compõe os arquivos do domínio na ordem das
dependências. `src/views/GtkApplication.jl` faz o mesmo para a interface Gtk.

## Como jogar

Use **Instruções** no menu para consultar objetivo, posicionamento, terrenos,
economia, armas, pontuação e símbolos. O mesmo guia pode ser aberto durante a
batalha; a janela de instruções não interrompe o cronômetro. Mapas grandes e
janelas próximas do tamanho mínimo oferecem rolagem nos tabuleiros e no guia.

Partidas concluídas aparecem no ranking separado por mapa. Ao abandonar uma
partida ou fechar o aplicativo durante o combate, uma confirmação avisa que o
resultado não será classificado.

## Dados locais

O ranking SQLite fica em `data/ranking.sqlite3`, dentro do projeto. Defina
`BATALHA_NAVAL_DATA_DIR` antes de iniciar para escolher outro diretório. Excluir
esse arquivo apaga somente o ranking local; não há sincronização em nuvem.

## Arch Linux: escopo da verificação

O launcher POSIX e o ambiente Julia são fornecidos e a suíte de domínio é
portável. No Arch, o áudio usa o primeiro reprodutor disponível entre `pw-play`
(PipeWire), `aplay` (ALSA) e `ffplay` (FFmpeg). A aparência, a integração com o
gerenciador de janelas e a disponibilidade de uma sessão gráfica/GPU dependem da
instalação local e precisam de conferência manual. Em sessões mínimas, instale os
drivers gráficos e as bibliotecas de áudio usuais do sistema antes do teste.
