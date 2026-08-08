const INSTRUCTIONS = [
    ("Objetivo", "Afunde toda a frota inimiga antes que o computador destrua a sua. Acertos mantêm o turno; água passa a vez."),
    ("Configuração e posicionamento", "Informe um nome, escolha o mapa e os terrenos. Selecione Patrulha (1 casa), Submarino (2) ou Cruzador (3), altere a orientação e confirme cada posição; também há posicionamento automático."),
    ("Turnos e terrenos", "Ataque casas inéditas da frota inimiga. Recife (▲) bloqueia posicionamento e ataques. Águas Rasas (≈) aceitam apenas Patrulhas e permanecem visíveis."),
    ("Economia e loja", "Cada casa atingida rende 10 moedas e cada navio afundado rende mais 10. A loja abre somente no início do seu turno. O Míssil custa 30 e o Ataque Aéreo, 50. Cotas Míssil/Aéreo: Poça 1/1, Lago 2/1 e Oceano 3/2. Moedas restantes não pontuam."),
    ("Armas", "O Míssil ataca uma área 2×2 a partir da casa escolhida. O Ataque Aéreo varre uma linha ou coluna; escolha o eixo e depois o cabeçalho do tabuleiro inimigo. Casas já atacadas e recifes são ignorados."),
    ("Pontuação e ranking", "Total = 100 por casa inimiga atingida + 300 por navio aliado sobrevivente + 50 por casa aliada intacta + max(0, 1000 − segundos) + 500 pela vitória. Só partidas concluídas entram no ranking; abandonar ou fechar descarta o resultado."),
    ("Símbolos", "· = casa desconhecida  •  ○ = água  •  × = dano  •  ■ = navio afundado  •  P = Patrulha  •  S = Submarino  •  C = Cruzador  •  ▲ = Recife  •  ≈ = Águas Rasas"),
]

function instructions_content()
    content = configure_container!(GtkBox(:v); spacing=14)
    content.valign = Gtk4.Align_START
    content.width_request = 760
    push!(content, title_label("Instruções"))
    push!(content, subtitle_label("Guia completo para preparar, jogar e encerrar uma partida."))
    for (heading, body) in INSTRUCTIONS
        card = styled!(GtkBox(:v), "info-card")
        card.spacing = 6
        push!(card, field_label(heading))
        push!(card, GtkLabel(body; wrap=true, xalign=0))
        push!(content, card)
    end
    return content
end

function information_page(window)
    page = instructions_content()
    push!(
        page,
        navigation_button(
            window,
            "Voltar ao Menu",
            () -> main_menu(window);
            style="quiet-action",
            expand=false,
        ),
    )
    return scrollable_page(page)
end

function show_battle_instructions(window)
    dialog = GtkWindow(; modal=false, title="Instruções — batalha em andamento")
    Gtk4.transient_for(dialog, window)
    dialog.default_width = 820
    dialog.default_height = 650
    content = instructions_content()
    close_button = styled!(GtkButton("Voltar à batalha"), "primary-action")
    signal_connect(close_button, "clicked") do _
        close_dialog(dialog)
    end
    push!(content, close_button)
    dialog[] = scrollable_page(content)
    show(dialog)
    return dialog
end
