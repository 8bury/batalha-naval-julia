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
    rejection == WEAPON_UNAVAILABLE && return "A arma selecionada não está disponível no inventário."
    rejection == NO_ATTACKABLE_CELLS && return "A área não contém casas inéditas e atacáveis."
    throw(ArgumentError("Rejeição de ataque sem mensagem: $rejection"))
end

function purchase_rejection_message(rejection::PurchaseRejection)
    rejection == SHOP_CLOSED && return "A loja só abre no início do seu turno."
    rejection == INSUFFICIENT_FUNDS && return "Saldo insuficiente para esta compra."
    rejection == QUOTA_EXHAUSTED && return "A cota desta arma acabou neste mapa."
    throw(ArgumentError("Rejeição de compra sem mensagem: $rejection"))
end

function battle_page(window, controller::CombatController)
    initial_state = combat_state(controller)
    page = configure_container!(GtkBox(:v); spacing=14)
    page.width_request = 1180
    page.height_request = 700
    push!(page, title_label("Batalha naval"))
    battle_bar = GtkBox(:h)
    battle_bar.spacing = 18
    turn_indicator = styled!(GtkLabel(""; xalign=0, hexpand=true), "battle-indicator")
    balance_indicator = styled!(GtkLabel(""; xalign=1), "battle-balance")
    shop_button = styled!(GtkButton("Abrir loja"), "secondary-action")
    missile_button = styled!(GtkButton("Usar Míssil 2×2"), "secondary-action")
    air_strike_button = styled!(GtkButton("Usar Ataque Aéreo"), "secondary-action")
    strike_row_button = styled!(GtkButton("Linha"), "secondary-action")
    strike_column_button = styled!(GtkButton("Coluna"), "secondary-action")
    push!(battle_bar, turn_indicator)
    push!(battle_bar, balance_indicator)
    push!(battle_bar, shop_button)
    push!(battle_bar, missile_button)
    push!(battle_bar, air_strike_button)
    push!(battle_bar, strike_row_button)
    push!(battle_bar, strike_column_button)
    push!(page, battle_bar)
    status = styled!(GtkLabel("Seu turno — escolha uma coordenada no tabuleiro inimigo."; wrap=true, xalign=0), "combat-status")
    push!(page, status)
    shop_panel = styled!(GtkBox(:v), "shop-panel")
    shop_panel.spacing = 8
    shop_panel.visible = false
    push!(shop_panel, field_label("Loja de armas"))
    shop_rows = Dict{WeaponType, Tuple{Any, Any}}()
    for weapon in weapons()
        row = GtkBox(:h)
        row.spacing = 12
        description = GtkLabel(""; xalign=0, hexpand=true)
        buy_button = styled!(GtkButton("Comprar"), "secondary-action")
        push!(row, description)
        push!(row, buy_button)
        push!(shop_panel, row)
        shop_rows[weapon] = (description, buy_button)
        signal_connect(buy_button, "clicked") do _
            purchase = buy_weapon!(controller, weapon)
            status.label = purchase.valid ? "$(weapon_label(weapon)) adicionado ao inventário." :
                purchase_rejection_message(purchase.rejection)
            render_combat!()
        end
    end
    push!(page, shop_panel)
    boards = GtkBox(:h)
    boards.spacing = 28
    boards.hexpand = true
    boards.homogeneous = true
    push!(page, boards)
    buttons = Dict{Participant, Matrix{Any}}()
    board_grids = Dict{Participant, BoardGrid}()
    missile_selected = Ref(false)
    air_strike_axis = Ref{Union{Nothing, AirStrikeAxis}}(nothing)

    for (owner, heading) in ((PLAYER, "Sua frota"), (COMPUTER, "Frota inimiga"))
        box = GtkBox(:v)
        box.spacing = 8
        box.hexpand = true
        push!(box, field_label(heading))
        board_grid = create_board_grid(initial_state.dimension)
        board_grids[owner] = board_grid
        push!(box, board_grid.widget)
        push!(boards, box)
        owner_buttons = board_grid.buttons
        buttons[owner] = owner_buttons
    end

    function render_combat!(state=combat_state(controller))
        turn_indicator.label = state.turn == PLAYER ? "Turno: jogador" : "Turno: computador"
        balance_indicator.label = "Saldo: $(state.player_coins) moedas"
        shop_button.sensitive = state.shop_available
        missile_button.sensitive = state.turn == PLAYER && isnothing(state.winner) && state.player_inventory[MISSILE] > 0
        missile_button.sensitive || (missile_selected[] = false)
        air_strike_button.sensitive = state.turn == PLAYER && isnothing(state.winner) && state.player_inventory[AIR_STRIKE] > 0
        air_strike_button.sensitive || (air_strike_axis[] = nothing)
        choosing_air_strike = air_strike_button.sensitive && !isnothing(air_strike_axis[])
        strike_row_button.visible = choosing_air_strike
        strike_column_button.visible = choosing_air_strike
        for index in 1:state.dimension
            board_grids[COMPUTER].row_headers[index].sensitive = choosing_air_strike && air_strike_axis[] == STRIKE_ROW
            board_grids[COMPUTER].column_headers[index].sensitive = choosing_air_strike && air_strike_axis[] == STRIKE_COLUMN
        end
        if !state.shop_available
            shop_panel.visible = false
        end
        for item in state.shop_items
            description, buy_button = shop_rows[item.weapon]
            description.label = "$(weapon_label(item.weapon)) — $(item.price) moedas | cota: $(item.remaining_quota) | inventário: $(item.inventory_count)"
            buy_button.sensitive = state.shop_available && item.remaining_quota > 0 && state.player_coins >= item.price
        end
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
                    isnothing(air_strike_axis[]) && (missile_selected[] || (cell.public_state == UNKNOWN && cell.terrain != REEF))
            end
        end
    end

    function clear_air_strike_preview!()
        for button in buttons[COMPUTER]
            remove_css_class(button, "missile-preview")
        end
    end

    function show_air_strike_preview!(axis, index)
        clear_air_strike_preview!()
        air_strike_axis[] == axis || return
        state = combat_state(controller)
        for (row, column) in air_strike_preview(initial_state.dimension, axis, index)
            cell = state.computer_cells[row, column]
            if cell.public_state == UNKNOWN && cell.terrain != REEF
                add_css_class(buttons[COMPUTER][row, column], "missile-preview")
            end
        end
    end

    function clear_missile_preview!()
        for button in buttons[COMPUTER]
            remove_css_class(button, "missile-preview")
            remove_css_class(button, "missile-preview-invalid")
        end
    end

    function show_missile_preview!(row, column)
        clear_missile_preview!()
        missile_selected[] || return
        preview = missile_preview(initial_state.dimension, row, column)
        css_class = preview.valid ? "missile-preview" : "missile-preview-invalid"
        for (preview_row, preview_column) in preview.cells
            if 1 <= preview_row <= initial_state.dimension && 1 <= preview_column <= initial_state.dimension
                add_css_class(buttons[COMPUTER][preview_row, preview_column], css_class)
            end
        end
    end


    signal_connect(shop_button, "clicked") do _
        if combat_state(controller).shop_available
            shop_panel.visible = !shop_panel.visible
        end
    end

    signal_connect(missile_button, "clicked") do _
        missile_selected[] = !missile_selected[]
        air_strike_axis[] = nothing
        clear_missile_preview!()
        status.label = missile_selected[] ?
            "Míssil selecionado — escolha o canto superior esquerdo da área 2×2." :
            "Míssil cancelado — escolha uma coordenada para o ataque básico."
        render_combat!()
    end


    signal_connect(air_strike_button, "clicked") do _
        missile_selected[] = false
        air_strike_axis[] = isnothing(air_strike_axis[]) ? STRIKE_ROW : nothing
        clear_missile_preview!()
        status.label = isnothing(air_strike_axis[]) ?
            "Ataque Aéreo cancelado — escolha uma coordenada para o ataque básico." :
            "Ataque Aéreo selecionado — escolha Linha ou Coluna e confirme pelo cabeçalho inimigo."
        render_combat!()
    end

    signal_connect(strike_row_button, "clicked") do _
        air_strike_axis[] = STRIKE_ROW
        status.label = "Ataque Aéreo em linha — passe pelo número e clique para confirmar."
        render_combat!()
    end

    signal_connect(strike_column_button, "clicked") do _
        air_strike_axis[] = STRIKE_COLUMN
        status.label = "Ataque Aéreo em coluna — passe pela letra e clique para confirmar."
        render_combat!()
    end

    function finish_special_attack!(clear_selection!, update, weapon_name)
        if !update.result.valid
            status.label = attack_rejection_message(update.result.rejection)
        elseif update.state.winner == PLAYER
            status.label = "Vitória! A frota inimiga foi destruída."
        elseif update.result.hits > 0
            status.label = "$weapon_name: $(update.result.hits) acerto(s), $(update.result.sunk) afundamento(s). Você continua."
        else
            status.label = "$weapon_name sem acertos. O computador está escolhendo um alvo…"
        end
        update.result.valid && clear_selection!()
        render_combat!(update.state)
        if update.result.valid && update.directive == CONTINUE_COMPUTER_TURN
            schedule_computer_step!()
        end
    end

    function fire_air_strike!(axis, index)
        update = player_air_strike!(controller, axis, index)
        finish_special_attack!(update, "Ataque Aéreo") do
            air_strike_axis[] = nothing
            clear_air_strike_preview!()
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
            motion = GtkEventControllerMotion()
            signal_connect(motion, "enter") do _, _, _
                show_missile_preview!(row, column)
            end
            signal_connect(motion, "leave") do _
                clear_missile_preview!()
            end
            push!(buttons[COMPUTER][row, column], motion)
            signal_connect(buttons[COMPUTER][row, column], "clicked") do _
                update = missile_selected[] ? player_missile!(controller, row, column) : player_attack!(controller, row, column)
                if update isa MissileUpdate
                    finish_special_attack!(update, "Míssil") do
                        missile_selected[] = false
                        clear_missile_preview!()
                    end
                else
                    report_player!(update)
                    render_combat!(update.state)
                    if update.result.valid && update.directive == CONTINUE_COMPUTER_TURN
                        schedule_computer_step!()
                    end
                end
            end
        end
    end
    for index in 1:initial_state.dimension
        let index = index
            for (axis, header) in (
                (STRIKE_ROW, board_grids[COMPUTER].row_headers[index]),
                (STRIKE_COLUMN, board_grids[COMPUTER].column_headers[index]),
            )
                motion = GtkEventControllerMotion()
                signal_connect(motion, "enter") do _, _, _
                    show_air_strike_preview!(axis, index)
                end
                signal_connect(motion, "leave") do _
                    clear_air_strike_preview!()
                end
                push!(header, motion)
                signal_connect(header, "clicked") do _
                    fire_air_strike!(axis, index)
                end
            end
        end
    end
    push!(page, styled!(GtkLabel("○ = água   × = dano   ■ = afundado"; xalign=0), "board-legend"))
    push!(page, navigation_button(window, "Menu Principal", () -> main_menu(window); style="quiet-action", expand=false))
    render_combat!()
    return page
end
