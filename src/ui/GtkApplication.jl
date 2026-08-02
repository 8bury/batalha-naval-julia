module GtkApplication

using Gtk4
using BatalhaNaval

export run_application

const MAPS = map_options()
const THEME_CSS = read(joinpath(@__DIR__, "theme.css"), String)

function styled!(widget, classes...)
    foreach(css_class -> add_css_class(widget, css_class), classes)
    return widget
end

function install_theme!(window)
    provider = GtkCssProvider(THEME_CSS)
    push!(Gtk4.display(window), provider)
    return provider
end

function configure_container!(widget; spacing=16)
    widget.spacing = spacing
    widget.width_request = 660
    widget.halign = Gtk4.Align_CENTER
    widget.valign = Gtk4.Align_CENTER
    widget.vexpand = true
    widget.margin_top = 36
    widget.margin_bottom = 36
    widget.margin_start = 28
    widget.margin_end = 28
    return styled!(widget, "surface")
end

function title_label(text)
    return styled!(GtkLabel(text; xalign=0), "screen-title")
end

function subtitle_label(text)
    return styled!(GtkLabel(text; wrap=true, xalign=0), "subtitle")
end

function field_label(text)
    return styled!(GtkLabel(text; xalign=0), "field-label")
end

function menu_button(label; style="secondary-action")
    button = GtkButton(label)
    button.hexpand = true
    return styled!(button, style)
end

function navigation_button(window, label, destination; style="secondary-action", expand=true)
    button = menu_button(label; style)
    button.hexpand = expand
    if !expand
        button.halign = Gtk4.Align_START
    end
    signal_connect(button, "clicked") do _
        window[] = destination()
    end
    return button
end

function fleet_text(option::MapOption)
    fleet = option.fleet
    patrol = fleet.patrols == 1 ? "Patrulha" : "Patrulhas"
    submarine = fleet.submarines == 1 ? "Submarino" : "Submarinos"
    cruiser = fleet.cruisers == 1 ? "Cruzador" : "Cruzadores"
    return "$(fleet.patrols) $patrol, $(fleet.submarines) $submarine, $(fleet.cruisers) $cruiser"
end

function information_page(window, title, body)
    page = configure_container!(GtkBox(:v))
    push!(page, title_label(title))
    push!(page, subtitle_label(body))
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
    return page
end

function ready_page(
    window,
    configuration::MatchConfiguration,
    player_board::PositioningBoard,
    computer_board::PositioningBoard,
)
    return battle_page(window, configuration, player_board, computer_board)
end

function combat_cell_appearance(match, owner, board, row, column)
    state = public_cell(match, owner, row, column)
    terrain = terrain_at(board, row, column)
    state == WATER && return ("○", "Água", "combat-water")
    state == DAMAGED && return ("×", "Embarcação atingida", "combat-damaged")
    state == SUNK && return ("■", "Embarcação afundada", "combat-sunk")
    state == PUBLIC_REEF && return (terrain_symbol(REEF), terrain_tooltip(REEF), "cell-reef")
    if owner == PLAYER
        placement = ship_at(board, row, column)
        !isnothing(placement) && return (ship_symbol(placement.ship_type), ship_label(placement.ship_type), "cell-occupied")
    end
    terrain == SHALLOW_WATER && return (terrain_symbol(SHALLOW_WATER), terrain_tooltip(SHALLOW_WATER), "cell-shallow-water")
    return ("·", "Casa ainda desconhecida", "cell-empty")
end

function battle_page(window, configuration, player_board, computer_board)
    match = create_combat_match(player_board, computer_board)
    page = configure_container!(GtkBox(:v); spacing=14)
    page.width_request = 1180
    page.height_request = 700
    push!(page, title_label("Batalha naval"))
    status = styled!(GtkLabel("Seu turno — escolha uma coordenada no tabuleiro inimigo."; wrap=true, xalign=0), "combat-status")
    push!(page, status)
    boards = GtkBox(:h)
    boards.spacing = 28
    boards.hexpand = true
    boards.homogeneous = true
    push!(page, boards)
    buttons = Dict{Participant, Matrix{Any}}()

    for (owner, heading, board) in ((PLAYER, "Sua frota", player_board), (COMPUTER, "Frota inimiga", computer_board))
        box = GtkBox(:v)
        box.spacing = 8
        box.hexpand = true
        push!(box, field_label(heading))
        grid = GtkGrid()
        grid.row_spacing = 3
        grid.column_spacing = 3
        grid.halign = Gtk4.Align_CENTER
        push!(box, grid)
        push!(boards, box)
        grid[1, 1] = styled!(GtkLabel(""), "board-header")
        for column in 1:board.dimension
            grid[column + 1, 1] = styled!(GtkLabel(string(Char(Int('A') + column - 1))), "board-header")
        end
        owner_buttons = Matrix{Any}(undef, board.dimension, board.dimension)
        buttons[owner] = owner_buttons
        for row in 1:board.dimension
            grid[1, row + 1] = styled!(GtkLabel(string(row)), "board-header")
            for column in 1:board.dimension
                button = styled!(GtkButton("·"), "board-cell", "cell-empty")
                button.width_request = 42
                button.height_request = 42
                owner_buttons[row, column] = button
                grid[column + 1, row + 1] = button
            end
        end
    end

    function render_combat!()
        for (owner, board) in ((PLAYER, player_board), (COMPUTER, computer_board))
            for row in 1:board.dimension, column in 1:board.dimension
                button = buttons[owner][row, column]
                reset_board_cell_style!(button)
                label, tooltip, css_class = combat_cell_appearance(match, owner, board, row, column)
                button.label = label
                button.tooltip_text = "$(Char(Int('A') + column - 1))$row — $tooltip"
                add_css_class(button, css_class)
                button.sensitive = owner == COMPUTER && isnothing(match.winner) && match.turn == PLAYER &&
                    public_cell(match, COMPUTER, row, column) == UNKNOWN && terrain_at(computer_board, row, column) != REEF
            end
        end
    end

    function report!(player_result, computer_results)
        if match.winner == PLAYER
            status.label = "Vitória! A frota inimiga foi destruída."
            add_css_class(status, "combat-victory")
        elseif match.winner == COMPUTER
            status.label = "Derrota. Sua frota foi destruída."
            add_css_class(status, "combat-defeat")
        elseif player_result.outcome == ATTACK_MISS
            hits = count(result -> result.outcome != ATTACK_MISS, computer_results)
            status.label = hits == 0 ? "Água dos dois lados. Seu turno." : "O computador acertou $hits vez(es) e então errou. Seu turno."
        elseif player_result.outcome == ATTACK_SUNK
            status.label = "Embarcação inimiga afundada! Você continua no turno."
        else
            status.label = "Acerto! Você continua no turno."
        end
    end

    for row in 1:computer_board.dimension, column in 1:computer_board.dimension
        let row = row, column = column
            signal_connect(buttons[COMPUTER][row, column], "clicked") do _
                result = attack!(match, PLAYER, row, column)
                if result.valid
                    computer_results = result.outcome == ATTACK_MISS ? computer_turn!(match) : AttackResult[]
                    report!(result, computer_results)
                    render_combat!()
                else
                    status.label = result.message
                end
            end
        end
    end
    push!(page, styled!(GtkLabel("○ = água   × = dano   ■ = afundado"; xalign=0), "board-legend"))
    push!(page, navigation_button(window, "Menu Principal", () -> main_menu(window); style="quiet-action", expand=false))
    render_combat!()
    return page
end

function reset_board_cell_style!(button)
    foreach(
        css_class -> remove_css_class(button, css_class),
        (
            "cell-empty",
            "cell-occupied",
            "cell-preview-valid",
            "cell-preview-invalid",
            "cell-reef",
            "cell-shallow-water",
            "combat-water",
            "combat-damaged",
            "combat-sunk",
        ),
    )
    return button
end

function positioning_page(window, configuration::MatchConfiguration)
    player_board, computer_board = create_match_boards(configuration)
    return positioning_page(window, configuration, player_board, computer_board)
end

function positioning_page(
    window,
    configuration::MatchConfiguration,
    board::PositioningBoard,
    computer_board::PositioningBoard,
)
    selected_ship = Ref{Union{Nothing, ShipType}}(nothing)
    orientation = Ref(HORIZONTAL)
    preview = Ref{Union{Nothing, PlacementPreview}}(nothing)
    preview_start = Ref{Union{Nothing, Tuple{Int, Int}}}(nothing)

    page = configure_container!(GtkBox(:v); spacing=14)
    page.width_request = 1180
    page.height_request = 680
    push!(page, title_label("Posicionamento da frota"))
    push!(
        page,
        subtitle_label(
            "$(configuration.player_name), escolha uma embarcação e clique na casa inicial. " *
            "Embarcações podem se tocar, mas não podem sair do mapa ou se sobrepor.",
        ),
    )

    content = GtkBox(:h)
    content.spacing = 26
    content.hexpand = true
    content.vexpand = true
    push!(page, content)

    board_column = GtkBox(:v)
    board_column.spacing = 10
    board_column.hexpand = true
    board_column.vexpand = true
    push!(content, board_column)

    board_grid = GtkGrid()
    board_grid.row_spacing = 3
    board_grid.column_spacing = 3
    board_grid.halign = Gtk4.Align_CENTER
    board_grid.valign = Gtk4.Align_CENTER
    push!(board_column, board_grid)

    board_grid[1, 1] = styled!(GtkLabel(""), "board-header")
    for column in 1:board.dimension
        column_label = styled!(GtkLabel(string(Char(Int('A') + column - 1))), "board-header")
        board_grid[column + 1, 1] = column_label
    end

    cell_buttons = Matrix{Any}(undef, board.dimension, board.dimension)
    for row in 1:board.dimension
        row_label = styled!(GtkLabel(string(row)), "board-header")
        board_grid[1, row + 1] = row_label
        for column in 1:board.dimension
            cell_button = styled!(GtkButton("·"), "board-cell", "cell-empty")
            cell_button.width_request = 42
            cell_button.height_request = 42
            cell_button.tooltip_text = "$(Char(Int('A') + column - 1))$row"
            cell_buttons[row, column] = cell_button
            board_grid[column + 1, row + 1] = cell_button
        end
    end

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
    controls.width_request = 300
    controls.valign = Gtk4.Align_START
    push!(content, controls)

    push!(controls, field_label("Embarcações disponíveis"))
    fleet_buttons = Dict{ShipType, Any}()
    function auto_positioning!()
        result = auto_place_ships!(board)
        selected_ship[] = nothing
        preview[] = nothing
        preview_start[] = nothing
        set_status!(result.message; valid=result.success)
        render_board!()
        refresh_controls!()
        return nothing
    end

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

    function render_board!()
        current_preview = preview[]
        preview_cells = isnothing(current_preview) ? Set{Tuple{Int, Int}}() : Set(current_preview.cells)
        for row in 1:board.dimension
            for column in 1:board.dimension
                cell_button = cell_buttons[row, column]
                placement = ship_at(board, row, column)
                terrain = terrain_at(board, row, column)
                reset_board_cell_style!(cell_button)
                if !isnothing(placement)
                    cell_button.label = ship_symbol(placement.ship_type)
                    cell_button.tooltip_text = isnothing(terrain) ?
                        "$(Char(Int('A') + column - 1))$row — clique para remover" :
                        "$(terrain_tooltip(terrain)) Clique para remover a embarcação."
                    add_css_class(cell_button, "cell-occupied")
                    if terrain == REEF
                        add_css_class(cell_button, "cell-reef")
                    elseif terrain == SHALLOW_WATER
                        add_css_class(cell_button, "cell-shallow-water")
                    end
                elseif (row, column) in preview_cells
                    cell_button.label = current_preview.valid ? "·" : "×"
                    cell_button.tooltip_text = current_preview.message
                    add_css_class(
                        cell_button,
                        current_preview.valid ? "cell-preview-valid" : "cell-preview-invalid",
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

    function refresh_controls!()
        available = available_ships(board)
        for ship_type in (PATROL, SUBMARINE, CRUISER)
            ship_button = fleet_buttons[ship_type]
            remaining = count(candidate -> candidate == ship_type, available)
            ship_button.label = "$(ship_label(ship_type)) ($remaining)"
            ship_button.sensitive = remaining > 0
            remove_css_class(ship_button, "selected-action")
            if selected_ship[] == ship_type
                add_css_class(ship_button, "selected-action")
            end
        end
        confirm_position_button.sensitive = !isnothing(preview[]) && preview[].valid
        confirm_fleet_button.sensitive = battle_ready(board, computer_board)
        return nothing
    end

    function show_preview!(row, column)
        ship_type = selected_ship[]
        if isnothing(ship_type)
            set_status!("Escolha uma embarcação antes de selecionar a casa inicial.")
            return nothing
        end

        preview_start[] = (row, column)
        preview[] = preview_placement(board, ship_type, row, column, orientation[])
        set_status!(preview[].message; valid=preview[].valid)
        render_board!()
        refresh_controls!()
        return nothing
    end

    function handle_cell_click!(row, column)
        if !isnothing(ship_at(board, row, column))
            remove_ship_at!(board, row, column)
            selected_ship[] = nothing
            preview[] = nothing
            preview_start[] = nothing
            set_status!("Embarcação removida e devolvida à lista.")
            render_board!()
            refresh_controls!()
            return nothing
        end
        return show_preview!(row, column)
    end

    function toggle_orientation!()
        orientation[] = orientation[] == HORIZONTAL ? VERTICAL : HORIZONTAL
        orientation_button.label = orientation[] == HORIZONTAL ?
            "Orientação: Horizontal" :
            "Orientação: Vertical"
        if !isnothing(preview_start[])
            start_row, start_column = preview_start[]
            show_preview!(start_row, start_column)
        end
        return nothing
    end

    function confirm_position!()
        ship_type = selected_ship[]
        start = preview_start[]
        current_preview = preview[]
        if isnothing(ship_type) || isnothing(start) || isnothing(current_preview) || !current_preview.valid
            return nothing
        end

        start_row, start_column = start
        if place_ship!(board, ship_type, start_row, start_column, orientation[])
            remaining = available_ships(board)
            selected_ship[] = ship_type in remaining ? ship_type : nothing
            preview[] = nothing
            preview_start[] = nothing
            set_status!("$(ship_label(ship_type)) posicionado. Escolha a próxima embarcação.")
            render_board!()
            refresh_controls!()
        end
        return nothing
    end

    function clear_positioning!()
        clear_board!(board)
        selected_ship[] = nothing
        preview[] = nothing
        preview_start[] = nothing
        set_status!("Tabuleiro limpo. A configuração do mapa foi preservada.")
        render_board!()
        refresh_controls!()
        return nothing
    end

    for ship_type in (PATROL, SUBMARINE, CRUISER)
        signal_connect(fleet_buttons[ship_type], "clicked") do _
            selected_ship[] = ship_type
            preview[] = nothing
            preview_start[] = nothing
            set_status!("$(ship_label(ship_type)) selecionado. Clique na casa inicial.")
            render_board!()
            refresh_controls!()
            return nothing
        end
    end

    for row in 1:board.dimension
        for column in 1:board.dimension
            let row = row, column = column
                signal_connect(cell_buttons[row, column], "clicked") do _
                    handle_cell_click!(row, column)
                    return nothing
                end
            end
        end
    end

    signal_connect(orientation_button, "clicked") do _
        toggle_orientation!()
        return nothing
    end
    signal_connect(confirm_position_button, "clicked") do _
        confirm_position!()
        return nothing
    end
    signal_connect(clear_button, "clicked") do _
        clear_positioning!()
        return nothing
    end
    signal_connect(auto_position_button, "clicked") do _
        auto_positioning!()
        return nothing
    end
    signal_connect(confirm_fleet_button, "clicked") do _
        if battle_ready(board, computer_board)
            window[] = ready_page(window, configuration, board, computer_board)
        end
        return nothing
    end

    render_board!()
    refresh_controls!()
    push!(page, navigation_button(window, "Voltar à Configuração", () -> configuration_page(window, configuration.player_name)))
    return page
end

function name_page(window; initial_name="")
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
        validation = validate_player_name(name_entry.text)
        if !validation.valid
            error_label.label = validation.message
            return nothing
        end

        window[] = configuration_page(window, validation.normalized)
        return nothing
    end
    push!(page, continue_button)
    push!(page, navigation_button(window, "Cancelar", () -> main_menu(window)))
    return page
end

function configuration_page(window, player_name)
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
        configuration = create_match_configuration(
            player_name,
            selected_map.kind;
            special_terrain=terrain_toggle.active,
        )
        window[] = positioning_page(window, configuration)
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

function close_dialog(dialog)
    Gtk4.transient_for(dialog, nothing)
    destroy(dialog)
    return nothing
end

function confirm_exit(on_confirm::Function, window)
    dialog = GtkWindow(; modal=true, title="Confirmar saída")
    Gtk4.transient_for(dialog, window)

    content = GtkBox(:v)
    content.spacing = 16
    content.width_request = 440
    content.margin_top = 24
    content.margin_bottom = 24
    content.margin_start = 24
    content.margin_end = 24
    push!(content, subtitle_label("Deseja realmente sair do Batalha Naval?"))
    actions = GtkBox(:h)
    actions.spacing = 12
    push!(content, actions)

    cancel_button = styled!(GtkButton("Cancelar"; hexpand=true), "secondary-action")
    signal_connect(cancel_button, "clicked") do _
        close_dialog(dialog)
    end
    push!(actions, cancel_button)

    exit_button = styled!(GtkButton("Sair"; hexpand=true), "danger-action")
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
        window[] = information_page(
            window,
            "Ranking",
            "O ranking será disponibilizado em uma etapa posterior.",
        )
    end
    push!(page, ranking_button)

    instructions_button = menu_button("Instruções")
    signal_connect(instructions_button, "clicked") do _
        window[] = information_page(
            window,
            "Instruções",
            "Configure seu nome, escolha um mapa e decida se a partida terá terrenos especiais.",
        )
    end
    push!(page, instructions_button)

    exit_button = menu_button("Sair"; style="danger-action")
    signal_connect(exit_button, "clicked") do _
        close(window)
    end
    push!(page, exit_button)
    return page
end

function create_window(on_closed::Function=() -> nothing)
    window = GtkWindow("Batalha Naval", 1280, 800)
    window.resizable = true
    window.width_request = 1000
    window.height_request = 650
    install_theme!(window)
    window[] = main_menu(window)

    close_confirmed = Ref(false)
    signal_connect(window, :close_request) do _
        if close_confirmed[]
            on_closed()
            return false
        end

        confirm_exit(window) do
            close_confirmed[] = true
            close(window)
        end
        return true
    end

    show(window)
    return window
end

function run_application()
    if isinteractive()
        return create_window()
    end

    closed = Condition()
    window = create_window(() -> notify(closed))
    Gtk4.GLib.start_main_loop(true)
    try
        wait(closed)
    finally
        Gtk4.GLib.stop_main_loop(true)
    end
    return window
end

end
