function match_summary_page(window, controller::CombatController)
    set_match_in_progress!(window, false)
    summary = match_summary(controller)
    score = summary.score
    page = configure_container!(GtkBox(:v); spacing=14)
    push!(page, title_label(summary.won ? "Vitória!" : "Derrota"))
    push!(page, subtitle_label(summary.won ?
        "A frota inimiga foi destruída." : "Sua frota foi destruída."))
    details = [
        "Duração: $(format_duration(summary.duration_seconds))",
        "Acertos em casas inimigas: $(summary.hits)",
        "Navios aliados sobreviventes: $(summary.surviving_ships)",
        "Integridade aliada: $(summary.intact_cells) casa(s) intacta(s)",
        "Moedas restantes: $(summary.remaining_coins) (não alteram a pontuação)",
        "Acertos: 100 × $(summary.hits) = $(score.hit_points)",
        "Sobreviventes: 300 × $(summary.surviving_ships) = $(score.survivor_points)",
        "Integridade: 50 × $(summary.intact_cells) = $(score.integrity_points)",
        "Tempo: max(0, 1000 - $(summary.duration_seconds)) = $(score.time_points)",
        "Bônus de vitória: $(score.victory_points)",
        "Pontuação final: $(score.total)",
    ]
    card = styled!(GtkBox(:v), "info-card")
    card.spacing = 7
    foreach(text -> push!(card, GtkLabel(text; xalign=0)), details)
    push!(page, card)

    again = menu_button("Jogar Novamente"; style="primary-action")
    signal_connect(again, "clicked") do _
        window[] = battle_page(window, play_again(controller))
    end
    push!(page, again)
    ranking = menu_button("Ver Ranking"; style="secondary-action")
    signal_connect(ranking, "clicked") do _
        window[] = ranking_page(window, controller.repository)
    end
    push!(page, ranking)
    push!(page, navigation_button(window, "Menu Principal", () -> main_menu(window)))
    return page
end
