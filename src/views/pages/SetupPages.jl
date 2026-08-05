function name_page(window; initial_name="")
    controller = SetupController(; initial_name)
    page = configure_container!(GtkBox(:v))
    push!(page, title_label("Identificação do jogador"))
    push!(page, subtitle_label("Informe como seu nome aparecerá no ranking da frota."))

    push!(page, field_label("Nome do jogador (2 a 20 caracteres)"))
    name_entry = GtkEntry()
    name_entry.text = initial_name
    name_entry.placeholder_text = "Digite seu nome"
    push!(page, name_entry)

    error_label = styled!(GtkLabel(""; wrap=true, xalign=0), "error-text")
    push!(page, error_label)

    continue_button = menu_button("Continuar"; style="primary-action")
    signal_connect(continue_button, "clicked") do _
        validation = submit_player_name!(controller, name_entry.text)
        if !validation.valid
            error_label.label = validation.message
            return nothing
        end

        window[] = configuration_page(window, controller)
        return nothing
    end
    push!(page, continue_button)
    push!(page, navigation_button(window, "Cancelar", () -> main_menu(window)))
    return page
end

configuration_page(window, player_name::AbstractString) =
    configuration_page(window, SetupController(; initial_name=player_name))

function configuration_page(window, controller::SetupController)
    player_name = setup_state(controller).player_name
    page = configure_container!(GtkBox(:v))
    push!(page, title_label("Nova partida"))
    push!(page, styled!(GtkLabel("Jogador: $player_name"; xalign=0), "context-line"))

    push!(page, field_label("Tamanho do mapa"))
    map_selector = GtkDropDown(["$(option.name), $(option.dimension) × $(option.dimension)" for option in MAPS])
    push!(page, map_selector)

    fleet_label = styled!(GtkLabel("Frota: $(fleet_text(MAPS[1]))"; wrap=true, xalign=0), "info-card")
    push!(page, fleet_label)
    signal_connect(map_selector, "notify::selected") do selector, _...
        selected_map = MAPS[Int(selector.selected) + 1]
        fleet_label.label = "Frota: $(fleet_text(selected_map))"
    end

    terrain_toggle = GtkCheckButton("Habilitar terrenos especiais")
    terrain_toggle.active = true
    push!(page, terrain_toggle)

    continue_button = menu_button("Confirmar Configuração"; style="primary-action")
    signal_connect(continue_button, "clicked") do _
        selected_map = MAPS[Int(map_selector.selected) + 1]
        positioning = start_positioning!(
            controller,
            selected_map.kind;
            special_terrain=terrain_toggle.active,
        )
        window[] = positioning_page(window, positioning)
        return nothing
    end
    push!(page, continue_button)
    push!(
        page,
        navigation_button(
            window,
            "Alterar Nome",
            () -> name_page(window; initial_name=player_name),
        ),
    )
    push!(page, navigation_button(window, "Cancelar", () -> main_menu(window)))
    return page
end
