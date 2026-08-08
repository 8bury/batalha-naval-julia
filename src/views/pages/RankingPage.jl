map_ranking_name(map::MapKind) = map == PUDDLE ? "Poça" : map == LAKE ? "Lago" : "Oceano"

function ranking_page(window, repository::AbstractResultRepository; selected=PUDDLE)
    page = configure_container!(GtkBox(:v); spacing=12)
    push!(page, title_label("Ranking por mapa"))
    tabs = GtkBox(:h)
    tabs.spacing = 8
    for map in (PUDDLE, LAKE, OCEAN)
        button = styled!(GtkButton(map_ranking_name(map)), map == selected ? "primary-action" : "secondary-action")
        signal_connect(button, "clicked") do _
            window[] = ranking_page(window, repository; selected=map)
        end
        push!(tabs, button)
    end
    push!(page, tabs)
    results = top_results(repository, selected)
    list = styled!(GtkBox(:v), "info-card")
    list.spacing = 8
    push!(list, GtkLabel("#   Nome   Pontos   Tempo   Resultado   Data   Terrenos"; xalign=0))
    for (position, result) in enumerate(results)
        outcome = result.won ? "Vitória" : "Derrota"
        terrain = result.special_terrain ? "Sim" : "Não"
        line = "$(position)   $(result.player_name)   $(result.score)   $(format_duration(result.duration_seconds))   $outcome   $(result.completed_at)   $terrain"
        label = GtkLabel(line; xalign=0, selectable=true)
        label.tooltip_text = "Acertos: $(result.hits) | Sobreviventes: $(result.surviving_ships) | Casas intactas: $(result.intact_cells)"
        push!(list, label)
    end
    isempty(results) && push!(list, GtkLabel("Nenhuma partida concluída neste mapa."; xalign=0))
    scroll = GtkScrolledWindow()
    scroll.vexpand = true
    scroll[] = list
    push!(page, scroll)
    push!(page, navigation_button(window, "Voltar ao Menu", () -> main_menu(window); style="quiet-action", expand=false))
    return page
end
