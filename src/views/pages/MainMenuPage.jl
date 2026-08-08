function close_dialog(dialog)
    Gtk4.transient_for(dialog, nothing)
    destroy(dialog)
    return nothing
end

function confirm_exit(on_confirm::Function, window; match_in_progress=false, intent=:exit)
    abandoning = intent == :abandon
    dialog = GtkWindow(; modal=true, title=abandoning ? "Confirmar abandono" : "Confirmar saída")
    Gtk4.transient_for(dialog, window)

    content = GtkBox(:v)
    content.spacing = 16
    content.width_request = 440
    content.margin_top = 24
    content.margin_bottom = 24
    content.margin_start = 24
    content.margin_end = 24
    message = abandoning ?
        "Deseja abandonar a partida e voltar ao menu? O resultado não será classificado." : match_in_progress ?
        "Há uma partida em andamento. Deseja abandonar a partida e sair do aplicativo? O resultado não será classificado." :
        "Deseja realmente sair do Batalha Naval?"
    push!(content, subtitle_label(message))
    actions = GtkBox(:h)
    actions.spacing = 12
    push!(content, actions)

    cancel_button = styled!(GtkButton("Cancelar"; hexpand=true), "secondary-action")
    signal_connect(cancel_button, "clicked") do _
        close_dialog(dialog)
    end
    push!(actions, cancel_button)

    confirm_label = abandoning ? "Abandonar" : "Sair"
    exit_button = styled!(GtkButton(confirm_label; hexpand=true), "danger-action")
    signal_connect(exit_button, "clicked") do _
        close_dialog(dialog)
        on_confirm()
    end
    push!(actions, exit_button)

    dialog[] = content
    show(dialog)
    return dialog
end

function main_menu(window)
    page = configure_container!(GtkBox(:v); spacing=16)
    push!(page, title_label("Batalha Naval"))
    push!(page, subtitle_label("Escolha uma opção para continuar."))

    start_button = menu_button("Iniciar Jogo"; style="primary-action")
    signal_connect(start_button, "clicked") do _
        window[] = name_page(window)
    end
    push!(page, start_button)

    ranking_button = menu_button("Ranking")
    signal_connect(ranking_button, "clicked") do _
        window[] = ranking_page(window, results_repository())
    end
    push!(page, ranking_button)

    instructions_button = menu_button("Instruções")
    signal_connect(instructions_button, "clicked") do _
        window[] = information_page(window)
    end
    push!(page, instructions_button)

    exit_button = menu_button("Sair"; style="danger-action")
    signal_connect(exit_button, "clicked") do _
        close(window)
    end
    push!(page, exit_button)
    return page
end
