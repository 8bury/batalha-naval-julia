function combat_cell_appearance(cell::CombatCellState, owner::Participant)
    cell.public_state == WATER && return ("○", "Água", "combat-water")
    cell.public_state == DAMAGED && return ("×", "Embarcação atingida", "combat-damaged")
    cell.public_state == SUNK && return ("■", "Embarcação afundada", "combat-sunk")
    cell.public_state == PUBLIC_REEF && return (terrain_symbol(REEF), terrain_tooltip(REEF), "cell-reef")
    if owner == PLAYER && !isnothing(cell.own_ship_type)
        return (ship_symbol(cell.own_ship_type), ship_label(cell.own_ship_type), "cell-occupied")
    end
    cell.terrain == SHALLOW_WATER && return (terrain_symbol(SHALLOW_WATER), terrain_tooltip(SHALLOW_WATER), "cell-shallow-water")
    return ("·", "Casa ainda desconhecida", "cell-empty")
end

function attack_rejection_message(rejection::AttackRejection)
    rejection == MATCH_FINISHED && return "A partida já terminou."
    rejection == WRONG_TURN && return "Não é o seu turno."
    rejection == OUT_OF_BOUNDS && return "A coordenada está fora do tabuleiro."
    rejection == REEF_TARGET && return "Recifes não podem ser atacados."
    rejection == ALREADY_ATTACKED && return "Esta coordenada já foi atacada."
    throw(ArgumentError("Rejeição de ataque sem mensagem: $rejection"))
end

function battle_page(window, controller::CombatController)
    initial_state = combat_state(controller)
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

    for (owner, heading) in ((PLAYER, "Sua frota"), (COMPUTER, "Frota inimiga"))
        box = GtkBox(:v)
        box.spacing = 8
        box.hexpand = true
        push!(box, field_label(heading))
        board_grid = create_board_grid(initial_state.dimension)
        push!(box, board_grid.widget)
        push!(boards, box)
        owner_buttons = board_grid.buttons
        buttons[owner] = owner_buttons
    end

    function render_combat!(state=combat_state(controller))
        for owner in (PLAYER, COMPUTER)
            cells = owner == PLAYER ? state.player_cells : state.computer_cells
            for row in 1:state.dimension, column in 1:state.dimension
                button = buttons[owner][row, column]
                reset_board_cell_style!(button)
                cell = cells[row, column]
                label, tooltip, css_class = combat_cell_appearance(cell, owner)
                button.label = label
                button.tooltip_text = "$(Char(Int('A') + column - 1))$row — $tooltip"
                add_css_class(button, css_class)
                button.sensitive = owner == COMPUTER && isnothing(state.winner) && state.turn == PLAYER &&
                    cell.public_state == UNKNOWN && cell.terrain != REEF
            end
        end
    end

    function report_player!(update::CombatUpdate)
        player_result = update.result
        if !player_result.valid
            status.label = attack_rejection_message(player_result.rejection)
        elseif update.state.winner == PLAYER
            status.label = "Vitória! A frota inimiga foi destruída."
            add_css_class(status, "combat-victory")
        elseif player_result.outcome == ATTACK_MISS
            status.label = "Água. O computador está escolhendo um alvo…"
        elseif player_result.outcome == ATTACK_SUNK
            status.label = "Embarcação inimiga afundada! Você continua no turno."
        else
            status.label = "Acerto! Você continua no turno."
        end
    end

    function schedule_computer_step!()
        Gtk4.GLib.g_timeout_add(600) do
            update = computer_step!(controller)
            result = update.result
            if update.state.winner == COMPUTER
                status.label = "Derrota. Sua frota foi destruída."
                add_css_class(status, "combat-defeat")
            elseif result.outcome == ATTACK_MISS
                status.label = "O computador errou. Seu turno."
            elseif result.outcome == ATTACK_SUNK
                status.label = "O computador afundou uma embarcação e continua atacando…"
            else
                status.label = "O computador acertou e continua atacando…"
            end
            render_combat!(update.state)
            if update.directive == CONTINUE_COMPUTER_TURN
                schedule_computer_step!()
            end
            return false
        end
        return nothing
    end

    for row in 1:initial_state.dimension, column in 1:initial_state.dimension
        let row = row, column = column
            signal_connect(buttons[COMPUTER][row, column], "clicked") do _
                update = player_attack!(controller, row, column)
                report_player!(update)
                render_combat!(update.state)
                if update.result.valid && update.directive == CONTINUE_COMPUTER_TURN
                    schedule_computer_step!()
                end
            end
        end
    end
    push!(page, styled!(GtkLabel("○ = água   × = dano   ■ = afundado"; xalign=0), "board-legend"))
    push!(page, navigation_button(window, "Menu Principal", () -> main_menu(window); style="quiet-action", expand=false))
    render_combat!()
    return page
end
