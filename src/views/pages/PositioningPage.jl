function positioning_page(window, controller::PositioningController)
    initial_state = positioning_state(controller)

    page = GtkBox(:v)
    page.spacing = 14
    page.hexpand = true
    page.vexpand = true
    page.halign = Gtk4.Align_FILL
    page.valign = Gtk4.Align_FILL
    page.margin_top = 20
    page.margin_bottom = 20
    page.margin_start = 24
    page.margin_end = 24
    push!(page, title_label("Posicionamento da frota"))
    push!(
        page,
        subtitle_label(
            "$(initial_state.player_name), escolha uma embarcação e clique na casa inicial. " *
            "Embarcações podem se tocar, mas não podem sair do mapa ou se sobrepor.",
        ),
    )

    content = GtkBox(:h)
    content.spacing = 26
    content.hexpand = true
    content.vexpand = true
    content.halign = Gtk4.Align_FILL
    content.valign = Gtk4.Align_CENTER
    push!(page, content)

    board_column = GtkBox(:v)
    board_column.spacing = 10
    board_column.hexpand = true
    board_column.vexpand = true
    board_scroll = GtkScrolledWindow()
    board_scroll[] = board_column
    board_scroll.hexpand = true
    board_scroll.vexpand = true
    push!(content, board_scroll)

    board_grid = create_board_grid(initial_state.dimension)
    push!(board_column, board_grid.widget)
    cell_buttons = board_grid.buttons

    status_label = styled!(GtkLabel("Escolha uma embarcação para começar."; wrap=true, xalign=0), "placement-status")
    push!(board_column, status_label)
    push!(
        board_column,
        styled!(
            GtkLabel(
                "P = Patrulha   S = Submarino   C = Cruzador   " *
                "$(terrain_symbol(REEF)) = Recife   $(terrain_symbol(SHALLOW_WATER)) = Águas Rasas";
                wrap=true,
                xalign=0,
            ),
            "board-legend",
        ),
    )

    controls = GtkBox(:v)
    controls.spacing = 12
    controls.width_request = 320
    controls.valign = Gtk4.Align_START
    push!(content, controls)

    push!(controls, field_label("Embarcações disponíveis"))
    fleet_buttons = Dict{ShipType, Any}()

    for ship_type in (PATROL, SUBMARINE, CRUISER)
        ship_button = menu_button(ship_label(ship_type); style="secondary-action")
        fleet_buttons[ship_type] = ship_button
        push!(controls, ship_button)
    end

    orientation_button = menu_button("Orientação: Horizontal"; style="secondary-action")
    push!(controls, orientation_button)

    auto_position_button = menu_button("Posicionar Automaticamente"; style="secondary-action")
    push!(controls, auto_position_button)

    confirm_position_button = menu_button("Confirmar Posição"; style="primary-action")
    confirm_position_button.sensitive = false
    push!(controls, confirm_position_button)

    clear_button = menu_button("Limpar Tabuleiro"; style="quiet-action")
    clear_button.halign = Gtk4.Align_START
    push!(controls, clear_button)

    confirm_fleet_button = menu_button("Confirmar Frota"; style="primary-action")
    confirm_fleet_button.sensitive = false
    push!(controls, confirm_fleet_button)

    function set_status!(message; valid=nothing)
        status_label.label = message
        foreach(
            css_class -> remove_css_class(status_label, css_class),
            ("placement-valid", "placement-invalid"),
        )
        if valid === true
            add_css_class(status_label, "placement-valid")
        elseif valid === false
            add_css_class(status_label, "placement-invalid")
        end
        return nothing
    end

    function render_board!(state::PositioningState)
        for row in 1:state.dimension
            for column in 1:state.dimension
                cell_button = cell_buttons[row, column]
                cell = state.cells[row, column]
                terrain = cell.terrain
                reset_board_cell_style!(cell_button)
                if !isnothing(cell.ship_type)
                    cell_button.label = ship_symbol(cell.ship_type)
                    cell_button.tooltip_text = isnothing(terrain) ?
                        "$(Char(Int('A') + column - 1))$row - clique para remover" :
                        "$(terrain_tooltip(terrain)) Clique para remover a embarcação."
                    add_css_class(cell_button, "cell-occupied")
                    if terrain == REEF
                        add_css_class(cell_button, "cell-reef")
                    elseif terrain == SHALLOW_WATER
                        add_css_class(cell_button, "cell-shallow-water")
                    end
                elseif cell.previewed
                    cell_button.label = cell.preview_valid ? "·" : "×"
                    cell_button.tooltip_text = cell.preview_message
                    add_css_class(
                        cell_button,
                        cell.preview_valid ? "cell-preview-valid" : "cell-preview-invalid",
                    )
                else
                    if isnothing(terrain)
                        cell_button.label = "·"
                        cell_button.tooltip_text = "$(Char(Int('A') + column - 1))$row"
                        add_css_class(cell_button, "cell-empty")
                    else
                        cell_button.label = terrain_symbol(terrain)
                        cell_button.tooltip_text = terrain_tooltip(terrain)
                        add_css_class(
                            cell_button,
                            terrain == REEF ? "cell-reef" : "cell-shallow-water",
                        )
                    end
                end
            end
        end
        return nothing
    end

    function refresh_controls!(state::PositioningState)
        available = state.available_ships
        for ship_type in (PATROL, SUBMARINE, CRUISER)
            ship_button = fleet_buttons[ship_type]
            remaining = count(candidate -> candidate == ship_type, available)
            ship_button.label = "$(ship_label(ship_type)) ($remaining)"
            ship_button.sensitive = remaining > 0
            remove_css_class(ship_button, "selected-action")
            if state.selected_ship == ship_type
                add_css_class(ship_button, "selected-action")
            end
        end
        confirm_position_button.sensitive = state.can_confirm
        confirm_fleet_button.sensitive = state.can_start_combat
        return nothing
    end

    function apply_update!(update::PositioningUpdate)
        state = update.state
        orientation_button.label = state.orientation == HORIZONTAL ?
            "Orientação: Horizontal" :
            "Orientação: Vertical"
        if !isempty(update.message)
            set_status!(update.message; valid=update.valid)
        end
        render_board!(state)
        refresh_controls!(state)
        return nothing
    end

    for ship_type in (PATROL, SUBMARINE, CRUISER)
        signal_connect(fleet_buttons[ship_type], "clicked") do _
            apply_update!(select_ship!(controller, ship_type))
            return nothing
        end
    end

    for row in 1:initial_state.dimension
        for column in 1:initial_state.dimension
            let row = row, column = column
                signal_connect(cell_buttons[row, column], "clicked") do _
                    apply_update!(handle_positioning_cell!(controller, row, column))
                    return nothing
                end
            end
        end
    end

    signal_connect(orientation_button, "clicked") do _
        apply_update!(Application.toggle_orientation!(controller))
        return nothing
    end
    signal_connect(confirm_position_button, "clicked") do _
        apply_update!(Application.confirm_position!(controller))
        return nothing
    end
    signal_connect(clear_button, "clicked") do _
        apply_update!(Application.clear_positioning!(controller))
        return nothing
    end
    signal_connect(auto_position_button, "clicked") do _
        apply_update!(auto_position!(controller))
        return nothing
    end
    signal_connect(confirm_fleet_button, "clicked") do _
        combat_controller = start_combat(controller; repository=results_repository())
        window[] = battle_page(window, combat_controller)
        return nothing
    end

    render_board!(initial_state)
    refresh_controls!(initial_state)
    push!(page, navigation_button(window, "Voltar à Configuração", () -> configuration_page(window, initial_state.player_name)))
    return scrollable_page(page)
end
