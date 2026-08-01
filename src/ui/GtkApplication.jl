module GtkApplication

using Gtk4
using BatalhaNaval

export run_application

const MAPS = map_options()

function configure_container!(widget; spacing=16)
    widget.spacing = spacing
    widget.margin_top = 32
    widget.margin_bottom = 32
    widget.margin_start = 48
    widget.margin_end = 48
    return widget
end

function title_label(text)
    return GtkLabel(text; xalign=0)
end

function menu_button(label)
    button = GtkButton(label)
    button.hexpand = true
    return button
end

function navigation_button(window, label, destination)
    button = menu_button(label)
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
    return "$(fleet.patrols) $patrol  •  $(fleet.submarines) $submarine  •  $(fleet.cruisers) $cruiser"
end

function information_page(window, title, body)
    page = configure_container!(GtkBox(:v))
    push!(page, title_label(title))
    push!(page, GtkLabel(body; wrap=true, xalign=0))

    push!(page, navigation_button(window, "Voltar ao Menu", () -> main_menu(window)))
    return page
end

function ready_page(window, configuration::MatchConfiguration)
    option = only(filter(candidate -> candidate.kind == configuration.map, MAPS))
    terrain = configuration.special_terrain ? "habilitados" : "desabilitados"
    summary = "Jogador: $(configuration.player_name)\n" *
              "Mapa: $(option.name) ($(option.dimension)×$(option.dimension))\n" *
              "Frota: $(fleet_text(option))\n" *
              "Terrenos especiais: $terrain"

    page = configure_container!(GtkBox(:v))
    push!(page, title_label("Configuração pronta"))
    push!(page, GtkLabel(summary; wrap=true, xalign=0))
    push!(page, GtkLabel("O posicionamento da frota será implementado na próxima etapa."; wrap=true, xalign=0))

    push!(
        page,
        navigation_button(
            window,
            "Alterar Configuração",
            () -> configuration_page(window, configuration.player_name),
        ),
    )
    push!(page, navigation_button(window, "Menu Principal", () -> main_menu(window)))
    return page
end

function name_page(window; initial_name="")
    page = configure_container!(GtkBox(:v))
    push!(page, title_label("Identificação do jogador"))

    push!(page, GtkLabel("Nome do jogador (2 a 20 caracteres)"; xalign=0))
    name_entry = GtkEntry()
    name_entry.text = initial_name
    name_entry.placeholder_text = "Digite seu nome"
    push!(page, name_entry)

    error_label = GtkLabel(""; wrap=true, xalign=0)
    push!(page, error_label)

    continue_button = menu_button("Continuar")
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
    push!(page, GtkLabel("Jogador: $player_name"; xalign=0))

    push!(page, GtkLabel("Tamanho do mapa"; xalign=0))
    map_selector = GtkDropDown(["$(option.name) — $(option.dimension)×$(option.dimension)" for option in MAPS])
    push!(page, map_selector)

    fleet_label = GtkLabel("Frota: $(fleet_text(MAPS[1]))"; wrap=true, xalign=0)
    push!(page, fleet_label)
    signal_connect(map_selector, "notify::selected") do selector, _...
        selected_map = MAPS[Int(selector.selected) + 1]
        fleet_label.label = "Frota: $(fleet_text(selected_map))"
    end

    terrain_toggle = GtkCheckButton("Habilitar terrenos especiais")
    terrain_toggle.active = true
    push!(page, terrain_toggle)

    continue_button = menu_button("Continuar")
    signal_connect(continue_button, "clicked") do _
        selected_map = MAPS[Int(map_selector.selected) + 1]
        configuration = create_match_configuration(
            player_name,
            selected_map.kind;
            special_terrain=terrain_toggle.active,
        )
        window[] = ready_page(window, configuration)
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

    content = configure_container!(GtkBox(:v); spacing=12)
    push!(content, GtkLabel("Deseja realmente sair do Batalha Naval?"; wrap=true))
    actions = GtkBox(:h)
    actions.spacing = 12
    push!(content, actions)

    cancel_button = GtkButton("Cancelar"; hexpand=true)
    signal_connect(cancel_button, "clicked") do _
        close_dialog(dialog)
    end
    push!(actions, cancel_button)

    exit_button = GtkButton("Sair"; hexpand=true)
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
    page = configure_container!(GtkBox(:v); spacing=18)
    push!(page, title_label("Batalha Naval"))
    push!(page, GtkLabel("Escolha uma opção para continuar."; xalign=0))

    start_button = menu_button("Iniciar Jogo")
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

    exit_button = menu_button("Sair")
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
