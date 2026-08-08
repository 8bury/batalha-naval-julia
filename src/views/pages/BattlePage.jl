function combat_cell_appearance(cell::CombatCellState, owner::Participant)
    cell.public_state == WATER && return ("○", "Água", "combat-water")
    cell.public_state == DAMAGED && return ("×", "Embarcação atingida", "combat-damaged")
    if cell.public_state == SUNK
        revealed = isnothing(cell.revealed_ship_type) ? "Embarcação" : ship_label(cell.revealed_ship_type)
        return ("■", "$revealed afundado", "combat-sunk")
    end
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

function fleet_status_text(status::FleetShipStatus)
    state = status.state == FLEET_HIDDEN ? "oculto" :
            status.state == FLEET_INTACT ? "intacto" :
            status.state == FLEET_DAMAGED ? "danificado" : "afundado"
    label = isnothing(status.ship_type) ? "Embarcação inimiga" : ship_label(status.ship_type)
    return "$label: $state"
end

function show_combat_history(window, events)
    dialog = GtkWindow(; modal=true, title="Histórico completo")
    Gtk4.transient_for(dialog, window)
    content = configure_container!(GtkBox(:v); spacing=10)
    content.width_request = 520
    content.height_request = 480
    push!(content, title_label("Histórico completo"))
    list = GtkBox(:v)
    list.spacing = 6
    for event in reverse(events)
        push!(list, GtkLabel(event.message; wrap=true, xalign=0))
    end
    isempty(events) && push!(list, GtkLabel("Nenhum ataque registrado."; xalign=0))
    scroll = GtkScrolledWindow()
    scroll[] = list
    scroll.vexpand = true
    push!(content, scroll)
    close_button = styled!(GtkButton("Fechar"), "secondary-action")
    signal_connect(close_button, "clicked") do _
        close_dialog(dialog)
    end
    push!(content, close_button)
    dialog[] = content
    show(dialog)
    return dialog
end

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

function battle_page(window, controller::CombatController)
    set_match_in_progress!(window, true)
    initial_state = combat_state(controller)
    page = configure_container!(GtkBox(:v); spacing=14)
    page.width_request = 1180
    page.height_request = 700
    root = scrollable_page(page)
    push!(page, title_label("Batalha naval"))
    battle_bar = GtkBox(:h)
    battle_bar.spacing = 18
    turn_indicator = styled!(GtkLabel(""; xalign=0, hexpand=true), "battle-indicator")
    timer_indicator = styled!(GtkLabel("Tempo: 00:00"; xalign=0), "battle-indicator")
    balance_indicator = styled!(GtkLabel(""; xalign=1), "battle-balance")
    shop_button = styled!(GtkButton("Abrir loja"), "secondary-action")
    missile_button = styled!(GtkButton("Usar Míssil 2×2"), "secondary-action")
    air_strike_button = styled!(GtkButton("Usar Ataque Aéreo"), "secondary-action")
    sound_button = styled!(GtkButton("🔊 Sons: ligados"), "secondary-action")
    instructions_button = styled!(GtkButton("Instruções"), "secondary-action")
    sound_button.tooltip_text = "Silenciar todos os sons da partida"
    strike_row_button = styled!(GtkButton("Linha"), "secondary-action")
    strike_column_button = styled!(GtkButton("Coluna"), "secondary-action")
    push!(battle_bar, turn_indicator)
    push!(battle_bar, timer_indicator)
    push!(battle_bar, balance_indicator)
    push!(battle_bar, shop_button)
    push!(battle_bar, missile_button)
    push!(battle_bar, air_strike_button)
    push!(battle_bar, sound_button)
    push!(battle_bar, instructions_button)
    push!(battle_bar, strike_row_button)
    push!(battle_bar, strike_column_button)
    push!(page, battle_bar)
    signal_connect(instructions_button, "clicked") do _
        show_battle_instructions(window)
    end
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
    boards_scroll = GtkScrolledWindow()
    boards_scroll[] = boards
    boards_scroll.hexpand = true
    boards_scroll.vexpand = true
    boards_scroll.min_content_height = 460
    push!(page, boards_scroll)
    buttons = Dict{Participant, Matrix{Any}}()
    board_grids = Dict{Participant, BoardGrid}()
    missile_selected = Ref(false)
    air_strike_axis = Ref{Union{Nothing, AirStrikeAxis}}(nothing)
    fleet_labels = Dict{Participant, Any}()
    summary_shown = Ref(false)
    abandoned = Ref(false)
    audio = CombatAudio()
    delivered_events = Ref(length(initial_state.history))
    shake_generation = Ref(0)

    function shake_content!()
        shake_generation[] += 1
        generation = shake_generation[]
        step = Ref(0)
        Gtk4.GLib.g_timeout_add(50) do
            generation == shake_generation[] || return false
            step[] += 1
            if step[] <= 5
                page.margin_start = isodd(step[]) ? 36 : 20
                return true
            end
            page.margin_start = 28
            return false
        end
        return nothing
    end

    function deliver_feedback!(state)
        pending = pending_feedback_events(state.history, delivered_events[])
        for event in pending.events
            feedback = combat_feedback(event)
            play_audio!(audio, feedback.sound)
            feedback.shake && shake_content!()
        end
        delivered_events[] = pending.delivered
        return nothing
    end

    function finish_if_needed!(state)
        abandoned[] && return true
        if !isnothing(state.winner) && !summary_shown[]
            summary_shown[] = true
            set_match_in_progress!(window, false)
            abandon_button.sensitive = false
            final_event = state.history[end]
            delay_ms = combat_completion_delay_ms(final_event)
            if delay_ms == 0
                window[] = match_summary_page(window, controller)
                # Retém o WAV até o fim máximo da reprodução assíncrona (240 ms).
                Gtk4.GLib.g_timeout_add(260) do
                    stop_audio!(audio)
                    return false
                end
            else
                Gtk4.GLib.g_timeout_add(delay_ms) do
                    # A navegação pode abandonar a batalha antes do callback.
                    if window[] === root
                        stop_audio!(audio)
                        window[] = match_summary_page(window, controller)
                    end
                    return false
                end
            end
            return true
        end
        return false
    end

    for (owner, heading) in ((PLAYER, "Sua frota"), (COMPUTER, "Frota inimiga"))
        box = GtkBox(:v)
        box.spacing = 8
        box.hexpand = true
        push!(box, field_label(heading))
        board_grid = create_board_grid(initial_state.dimension)
        board_grids[owner] = board_grid
        push!(box, board_grid.widget)
        fleet_labels[owner] = GtkLabel(""; wrap=true, xalign=0)
        push!(box, styled!(fleet_labels[owner], "fleet-status"))
        push!(boards, box)
        owner_buttons = board_grid.buttons
        buttons[owner] = owner_buttons
    end
    history_panel = styled!(GtkBox(:v), "history-panel")
    history_panel.spacing = 6
    history_panel.width_request = 260
    push!(history_panel, field_label("Últimos eventos"))
    recent_labels = [GtkLabel(""; wrap=true, xalign=0) for _ in 1:5]
    foreach(label -> push!(history_panel, label), recent_labels)
    history_button = styled!(GtkButton("Ver histórico completo"), "secondary-action")
    signal_connect(history_button, "clicked") do _
        show_combat_history(window, combat_state(controller).history)
    end
    push!(history_panel, history_button)
    push!(boards, history_panel)

    function render_combat!(state=combat_state(controller))
        deliver_feedback!(state)
        timer_indicator.label = "Tempo: $(format_duration(elapsed_seconds(controller)))"
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
            fleet = owner == PLAYER ? state.player_fleet : state.computer_fleet
            fleet_labels[owner].label = join(fleet_status_text.(fleet), "  •  ")
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
        for index in eachindex(recent_labels)
            label = recent_labels[index]
            label.visible = index <= length(state.recent_events)
            label.label = label.visible ? state.recent_events[index].message : ""
        end
        history_button.sensitive = !isempty(state.history)
    end

    Gtk4.GLib.g_timeout_add(250) do
        (summary_shown[] || abandoned[]) && return false
        timer_indicator.label = "Tempo: $(format_duration(elapsed_seconds(controller)))"
        return true
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

    signal_connect(sound_button, "clicked") do _
        set_muted!(audio, !audio.muted)
        sound_button.label = audio.muted ? "🔇 Sons: desligados" : "🔊 Sons: ligados"
        sound_button.tooltip_text = audio.muted ?
            "Reativar os sons da partida" : "Silenciar todos os sons da partida"
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
            symbol = update.result.sunk > 0 ? "■" : "×"
            status.label = "$symbol $weapon_name: $(update.result.hits) acerto(s), $(update.result.sunk) afundamento(s). Você continua."
        else
            status.label = "○ Água — $weapon_name sem acertos. O computador está escolhendo um alvo…"
        end
        update.result.valid && clear_selection!()
        render_combat!(update.state)
        finish_if_needed!(update.state) && return
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
            status.label = "○ Água. O computador está escolhendo um alvo…"
        elseif player_result.outcome == ATTACK_SUNK
            status.label = "■ Embarcação inimiga afundada! Você continua no turno."
        else
            status.label = "× Acerto! Você continua no turno."
        end
    end

    function schedule_computer_step!()
        Gtk4.GLib.g_timeout_add(600) do
            abandoned[] && return false
            update = computer_step!(controller)
            outcome = update.state.history[end].outcome
            if update.state.winner == COMPUTER
                status.label = "Derrota. Sua frota foi destruída."
                add_css_class(status, "combat-defeat")
            elseif outcome == ATTACK_MISS
                status.label = "○ Água — o computador errou. Seu turno."
            elseif outcome == ATTACK_SUNK
                status.label = "■ O computador afundou uma embarcação e continua atacando…"
            else
                status.label = "× O computador acertou e continua atacando…"
            end
            render_combat!(update.state)
            finish_if_needed!(update.state) && return false
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
                    finish_if_needed!(update.state) && return nothing
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
    abandon_button = styled!(GtkButton("Abandonar partida"), "danger-action")
    abandon_button.halign = Gtk4.Align_START
    signal_connect(abandon_button, "clicked") do _
        combat_in_progress(controller) || return nothing
        confirm_exit(window; match_in_progress=true, intent=:abandon) do
            abandoned[] = true
            shake_generation[] += 1
            stop_audio!(audio)
            set_match_in_progress!(window, false)
            window[] = main_menu(window)
        end
    end
    push!(page, abandon_button)
    render_combat!()
    return root
end
