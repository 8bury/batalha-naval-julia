function battle_page(window, controller::CombatController)
    set_match_in_progress!(window, true)
    initial_state = combat_state(controller)
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
    push!(battle_bar, turn_indicator)
    push!(battle_bar, timer_indicator)
    push!(battle_bar, balance_indicator)
    push!(battle_bar, shop_button)
    push!(battle_bar, missile_button)
    push!(battle_bar, air_strike_button)
    push!(battle_bar, sound_button)
    push!(battle_bar, instructions_button)
    push!(page, battle_bar)
    signal_connect(instructions_button, "clicked") do _
        show_battle_instructions(window)
    end
    status = styled!(GtkLabel("Seu turno - escolha uma coordenada no tabuleiro inimigo."; wrap=true, xalign=0), "combat-status")
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
    boards.halign = Gtk4.Align_FILL
    boards.valign = Gtk4.Align_CENTER
    boards_scroll = GtkScrolledWindow()
    boards_scroll[] = boards
    boards_scroll.hexpand = true
    boards_scroll.vexpand = true
    boards_scroll.min_content_height = 460
    push!(page, boards_scroll)
    buttons = Dict{Participant, Matrix{Any}}()
    board_grids = Dict{Participant, BoardGrid}()
    missile_selected = Ref(false)
    air_strike_selected = Ref(false)
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
                page.margin_start = isodd(step[]) ? 32 : 16
                return true
            end
            page.margin_start = 24
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
        air_strike_button.sensitive || (air_strike_selected[] = false)
        choosing_air_strike = air_strike_button.sensitive && air_strike_selected[]
        for index in 1:state.dimension
            board_grids[COMPUTER].row_headers[index].sensitive = choosing_air_strike
            board_grids[COMPUTER].column_headers[index].sensitive = choosing_air_strike
        end
        if !state.shop_available
            shop_panel.visible = false
        end
        for item in state.shop_items
            description, buy_button = shop_rows[item.weapon]
            description.label = "$(weapon_label(item.weapon)) - $(item.price) moedas | cota: $(item.remaining_quota) | inventário: $(item.inventory_count)"
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
                button.tooltip_text = "$(Char(Int('A') + column - 1))$row - $tooltip"
                add_css_class(button, css_class)
                button.sensitive = owner == COMPUTER && isnothing(state.winner) && state.turn == PLAYER &&
                    !air_strike_selected[] &&
                    (missile_selected[] || (cell.public_state == UNKNOWN && cell.terrain != REEF))
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
        air_strike_selected[] || return
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
        air_strike_selected[] = false
        clear_missile_preview!()
        status.label = missile_selected[] ?
            "Míssil selecionado - escolha o canto superior esquerdo da área 2×2." :
            "Míssil cancelado - escolha uma coordenada para o ataque básico."
        render_combat!()
    end


    signal_connect(air_strike_button, "clicked") do _
        missile_selected[] = false
        air_strike_selected[] = !air_strike_selected[]
        clear_missile_preview!()
        clear_air_strike_preview!()
        status.label = !air_strike_selected[] ?
            "Ataque Aéreo cancelado - escolha uma coordenada para o ataque básico." :
            "Ataque Aéreo selecionado - clique em um número para atacar a linha ou em uma letra para atacar a coluna."
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
            status.label = "○ Água - $weapon_name sem acertos. O computador está escolhendo um alvo…"
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
            air_strike_selected[] = false
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
                status.label = "○ Água - o computador errou. Seu turno."
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
                let header_axis = axis, target_header = header
                    motion = GtkEventControllerMotion()
                    signal_connect(motion, "enter") do _, _, _
                        show_air_strike_preview!(header_axis, index)
                    end
                    signal_connect(motion, "leave") do _
                        clear_air_strike_preview!()
                    end
                    push!(target_header, motion)
                    signal_connect(target_header, "clicked") do _
                        air_strike_selected[] || return nothing
                        fire_air_strike!(header_axis, index)
                    end
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
